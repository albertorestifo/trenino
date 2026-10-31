defmodule Trenino.Hardware.StepperSessionTest do
  use ExUnit.Case, async: true
  alias Trenino.Hardware.{StepperAxis, StepperSession}
  alias Trenino.Serial.Protocol.{StepperCommand, StepperStatus}

  setup context do
    owner = self()

    axis = %StepperAxis{
      id: 1,
      device_id: 1,
      name: "Speed",
      watchdog_ms: Map.get(context, :watchdog, 1000)
    }

    axes =
      if context[:two_axes],
        do: [axis, %{axis | id: 2, axis_index: 1, motor_port: 2}],
        else: [axis]

    {:ok, pid} =
      StepperSession.start_link(
        port: "fake",
        generation: make_ref(),
        device_id: 1,
        axes: axes,
        send_fun: fn _, msg ->
          send(owner, {:sent, msg})
          :ok
        end,
        ack_timeout: 30,
        idle_poll: 10_000
      )

    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    %{pid: pid}
  end

  defp reply(pid, %StepperCommand{} = cmd, attrs \\ %{}) do
    base = %StepperStatus{
      operation: cmd.operation,
      axis: cmd.axis,
      request_id: cmd.request_id,
      result: :ok,
      state: :disabled,
      configured: false,
      known: false,
      energized: false,
      reference_kind: :unknown,
      fault: :none,
      position: 0,
      target: 0,
      phase: 0,
      max_axes: 2,
      drivers: 1,
      modes: 7,
      homing: 1
    }

    send(pid, {:serial_message, "fake", struct(base, attrs)})
    StepperSession.snapshot(pid)
  end

  test "stationary Stop preserves reference through its next status poll", %{pid: pid} do
    setup_axis(pid)
    StepperSession.command(pid, 1, :reference, %{position: 0}, :manual)
    assert_receive {:sent, %StepperCommand{operation: :reference} = ref}
    reply(pid, ref, %{configured: true, known: true, state: :idle})
    assert_receive {:sent, %StepperCommand{operation: :get_status} = poll}
    reply(pid, poll, %{configured: true, known: true, state: :idle})
    StepperSession.command(pid, 1, :stop, %{}, :manual)
    assert_receive {:sent, %StepperCommand{operation: :stop} = stop}
    reply(pid, stop, %{configured: true, known: true, state: :idle})
    send(pid, {:tick, StepperSession.snapshot(pid).timer_epoch, :poll})
    assert_receive {:sent, %StepperCommand{operation: :get_status} = poll}
    reply(pid, poll, %{configured: true, known: true, state: :idle})
    assert :ok = StepperSession.set_target(pid, 1, 100, :train)
  end

  test "poll-only counter rollover restarts acknowledged setup and a fresh poll timer", %{
    pid: pid
  } do
    setup_axis(pid)
    old_epoch = StepperSession.snapshot(pid).timer_epoch
    :sys.replace_state(pid, &%{&1 | next_id: 65_535})
    send(pid, {:tick, old_epoch, :poll})
    assert_receive {:sent, %StepperCommand{operation: :reset} = reset}
    reply(pid, reset)
    assert_receive {:sent, %StepperCommand{operation: :configure} = configure}
    reply(pid, configure, %{configured: true})
    refute StepperSession.snapshot(pid).timer_epoch == old_epoch
    assert StepperSession.snapshot(pid).lifecycle == :awaiting_reference
    send(pid, {:tick, StepperSession.snapshot(pid).timer_epoch, :poll})
    assert_receive {:sent, %StepperCommand{operation: :get_status}}
  end

  @tag :two_axes
  test "rollover on the first axis's poll stops polling the remaining axes", %{pid: pid} do
    setup_axis(pid)
    assert_receive {:sent, %StepperCommand{operation: :configure, axis: 1} = configure}
    reply(pid, configure, %{configured: true})
    assert StepperSession.snapshot(pid).lifecycle == :awaiting_reference
    :sys.replace_state(pid, &%{&1 | next_id: 65_535})
    send(pid, {:tick, StepperSession.snapshot(pid).timer_epoch, :poll})
    assert_receive {:sent, %StepperCommand{operation: :reset} = reset}
    refute_receive {:sent, %StepperCommand{operation: :get_status}}, 15
    snapshot = StepperSession.snapshot(pid)
    assert snapshot.lifecycle == :resetting
    assert Enum.all?(snapshot.axes, fn {_, a} -> a.reference_poll == nil end)
    assert snapshot.next_id == 2
    reply(pid, reset)
  end

  test "complete_reference never changes lifecycle outside ready/awaiting_reference", %{pid: pid} do
    setup_axis(pid)

    :sys.replace_state(pid, fn s ->
      %{s | lifecycle: :configuring, axes: Map.update!(s.axes, 1, &%{&1 | reference_poll: 7})}
    end)

    reply(pid, %StepperCommand{operation: :get_status, axis: 0, request_id: 7}, %{
      configured: true,
      known: true,
      state: :idle
    })

    assert StepperSession.snapshot(pid).lifecycle == :configuring
  end

  test "tick rollover does not start a second poll chain", %{pid: pid} do
    setup_axis(pid)
    :sys.replace_state(pid, &%{&1 | next_id: 65_535, idle_poll: 40})
    send(pid, {:tick, StepperSession.snapshot(pid).timer_epoch, :poll})
    assert_receive {:sent, %StepperCommand{operation: :reset} = reset}
    reply(pid, reset)
    assert_receive {:sent, %StepperCommand{operation: :configure} = configure}
    reply(pid, configure, %{configured: true})
    polls = count_polls(0, System.monotonic_time(:millisecond) + 400)
    assert polls <= 14, "expected a single poll chain, saw #{polls} polls in 400ms"
  end

  defp count_polls(n, deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)

    receive do
      {:sent, %StepperCommand{operation: :get_status}} -> count_polls(n + 1, deadline)
      {:sent, _} -> count_polls(n, deadline)
    after
      max(remaining, 0) -> n
    end
  end

  test "reload_axes preserves manual pause", %{pid: pid} do
    setup_axis(pid)
    :ok = StepperSession.pause(pid, 1, true)
    waiter = Task.async(fn -> StepperSession.begin_deployment(pid) end)
    assert_receive {:sent, %StepperCommand{operation: :reset} = reset}
    reply(pid, reset)
    assert {:ok, token} = Task.await(waiter)
    axis = StepperSession.snapshot(pid).axes[1].config
    assert :ok = StepperSession.reload_axes(pid, [axis], token)
    assert StepperSession.snapshot(pid).axes[1].paused
  end

  test "deployment reload recalculates minimum watchdog before configure", %{pid: pid} do
    setup_axis(pid)
    waiter = Task.async(fn -> StepperSession.begin_deployment(pid) end)
    assert_receive {:sent, %StepperCommand{operation: :reset} = reset}
    reply(pid, reset)
    assert {:ok, token} = Task.await(waiter)
    axis = %{StepperSession.snapshot(pid).axes[1].config | watchdog_ms: 100}
    assert :ok = StepperSession.reload_axes(pid, [axis], token)
    assert StepperSession.snapshot(pid).watchdog_interval == 25
    assert :ok = StepperSession.finish_deployment(pid, token, :ok)
    setup_axis(pid)
    assert_receive {:sent, %StepperCommand{operation: :keep_alive}}, 50
  end

  defp setup_axis(pid) do
    assert_receive {:sent, %StepperCommand{operation: :get_status, axis: 0} = probe}
    reply(pid, probe)
    assert_receive {:sent, %StepperCommand{operation: :reset, axis: 255} = reset}
    reply(pid, reset)
    assert_receive {:sent, %StepperCommand{operation: :configure, axis: 0} = configure}
    reply(pid, configure, %{configured: true})
  end

  test "failed deployment Reset replies immediately with unconfirmed power failure", %{pid: pid} do
    setup_axis(pid)
    owner = self()
    spawn(fn -> send(owner, {:deployment_result, StepperSession.begin_deployment(pid)}) end)
    assert_receive {:sent, %StepperCommand{operation: :reset} = reset}
    reply(pid, reset, %{result: :io_error, fault: :driver_i2c})
    assert_receive {:deployment_result, {:error, {:reset_failed, :io_error}}}, 100
    assert StepperSession.snapshot(pid).lifecycle == :fault
  end

  test "deployment can begin again after a failed Reset fault", %{pid: pid} do
    setup_axis(pid)
    owner = self()
    spawn(fn -> send(owner, {:first, StepperSession.begin_deployment(pid)}) end)
    assert_receive {:sent, %StepperCommand{operation: :reset} = reset}
    reply(pid, reset, %{result: :io_error, fault: :driver_i2c})
    assert_receive {:first, {:error, {:reset_failed, :io_error}}}, 100
    refute StepperSession.snapshot(pid).deployment_token

    waiter = Task.async(fn -> StepperSession.begin_deployment(pid) end)
    assert_receive {:sent, %StepperCommand{operation: :reset} = reset2}, 100
    reply(pid, reset2)
    assert {:ok, _token} = Task.await(waiter)
  end

  test "a fault mid-deployment invalidates the old token for a new deployment", %{pid: pid} do
    setup_axis(pid)
    waiter = Task.async(fn -> StepperSession.begin_deployment(pid) end)
    assert_receive {:sent, %StepperCommand{operation: :reset} = reset}
    reply(pid, reset)
    assert {:ok, old} = Task.await(waiter)

    # forget_driver is never acknowledged, so the ack timeout faults the session
    assert {:error, :outcome_unknown} = StepperSession.forget_driver(pid, old)
    assert StepperSession.snapshot(pid).lifecycle == :fault

    waiter = Task.async(fn -> StepperSession.begin_deployment(pid) end)
    assert_receive {:sent, %StepperCommand{operation: :reset} = reset2}, 100
    reply(pid, reset2)
    assert {:ok, new} = Task.await(waiter)
    refute new == old

    assert {:error, :stale_token} = StepperSession.finish_deployment(pid, old, :ok)
    assert {:error, :invalid_deployment_token} = StepperSession.forget_driver(pid, old)
    snapshot = StepperSession.snapshot(pid)
    assert snapshot.deployment_token == new
    assert snapshot.lifecycle == :deploying
    assert :ok = StepperSession.finish_deployment(pid, new, :ok)
  end

  test "I2C fault during deletion Release replies instead of orphaning caller", %{pid: pid} do
    setup_axis(pid)
    owner = self()
    spawn(fn -> send(owner, {:release_result, StepperSession.release_for_delete(pid, 1)}) end)
    assert_receive {:sent, %StepperCommand{operation: :release} = release}
    reply(pid, release, %{configured: true, result: :io_error, fault: :driver_i2c})
    assert_receive {:release_result, {:error, :driver_i2c}}, 100
    assert StepperSession.snapshot(pid).lifecycle == :fault
  end

  test "capability probe, acknowledged reset and configure never references automatically", %{
    pid: pid
  } do
    setup_axis(pid)
    assert StepperSession.snapshot(pid).lifecycle == :awaiting_reference
    assert {:error, :needs_reference} = StepperSession.set_target(pid, 1, 100, :train)
    refute_receive {:sent, %StepperCommand{operation: :home}}, 40
  end

  test "reference acceptance requires fresh correlated poll before targets", %{pid: pid} do
    setup_axis(pid)
    assert {:ok, _} = StepperSession.command(pid, 1, :reference, %{position: 0}, :manual)
    assert_receive {:sent, %StepperCommand{operation: :reference} = reference}
    reply(pid, reference, %{configured: true, known: true, state: :idle})
    assert {:error, :needs_reference} = StepperSession.set_target(pid, 1, 100, :train)
    assert_receive {:sent, %StepperCommand{operation: :get_status} = poll}

    reply(pid, poll, %{
      configured: true,
      known: true,
      state: :idle,
      energized: true,
      reference_kind: :host_assigned
    })

    assert :ok = StepperSession.set_target(pid, 1, 100, :train)
    assert_receive {:sent, %StepperCommand{operation: :move_to, position: 100}}
  end

  test "retries retain exact request then suspend uncertain outcome", %{pid: pid} do
    setup_axis(pid)
    assert {:ok, _} = StepperSession.command(pid, 1, :reference, %{position: 0}, :manual)
    assert_receive {:sent, %StepperCommand{operation: :reference} = cmd}
    assert_receive {:sent, ^cmd}, 100
    assert_receive {:sent, ^cmd}, 100
    Process.sleep(45)
    assert StepperSession.snapshot(pid).axes[1].error == :outcome_unknown
    assert {:error, _} = StepperSession.set_target(pid, 1, 20, :train)
  end

  test "stop cancels pending reference and stale ack cannot restore readiness", %{pid: pid} do
    setup_axis(pid)
    assert {:ok, _} = StepperSession.command(pid, 1, :reference, %{position: 0}, :manual)
    assert_receive {:sent, %StepperCommand{operation: :reference} = reference}
    assert {:ok, _} = StepperSession.command(pid, 1, :stop, %{}, :manual)
    assert_receive {:sent, %StepperCommand{operation: :stop} = stop}
    reply(pid, reference, %{known: true, configured: true, state: :idle})
    reply(pid, stop, %{known: false, configured: true, state: :idle})
    refute_receive {:sent, ^reference}, 80
    assert {:error, _} = StepperSession.set_target(pid, 1, 20, :train)
  end

  test "manual pause blocks telemetry but permits deliberate referenced manual target", %{
    pid: pid
  } do
    setup_axis(pid)
    {:ok, _} = StepperSession.command(pid, 1, :reference, %{position: 0}, :manual)
    assert_receive {:sent, %StepperCommand{operation: :reference} = reference}
    reply(pid, reference, %{configured: true, known: true, state: :idle})
    assert_receive {:sent, %StepperCommand{operation: :get_status} = poll}
    reply(pid, poll, %{configured: true, known: true, state: :idle})
    :ok = StepperSession.pause(pid, 1, true)
    assert {:error, :manual_pause} = StepperSession.set_target(pid, 1, 10, :train)
    assert {:ok, _} = StepperSession.command(pid, 1, :move_to, %{position: 10}, :manual)
  end

  test "rejected configuration faults the complete shared session", %{pid: pid} do
    assert_receive {:sent, %StepperCommand{operation: :get_status} = probe}
    reply(pid, probe)
    assert_receive {:sent, %StepperCommand{operation: :reset} = reset}
    reply(pid, reset)
    assert_receive {:sent, %StepperCommand{operation: :configure} = configure}
    reply(pid, configure, %{result: :resource_conflict})
    assert StepperSession.snapshot(pid).lifecycle == :fault
  end

  @tag watchdog: 100, two_axes: true
  test "watchdog starts while second axis configure is still awaiting ACK", %{pid: pid} do
    assert_receive {:sent, %StepperCommand{operation: :get_status} = probe}
    reply(pid, probe)
    assert_receive {:sent, %StepperCommand{operation: :reset} = reset}
    reply(pid, reset)
    assert_receive {:sent, %StepperCommand{operation: :configure, axis: 0} = configure}
    reply(pid, configure, %{configured: true})
    assert_receive {:sent, %StepperCommand{operation: :configure, axis: 1}}
    assert StepperSession.snapshot(pid).watchdog_interval == 25
    assert_receive {:sent, %StepperCommand{operation: :keep_alive}}, 50
  end

  test "request exhaustion performs reset before reuse and discards reference", %{pid: pid} do
    setup_axis(pid)
    :sys.replace_state(pid, &%{&1 | next_id: 65_535})

    assert {:error, :reference_epoch_changed} =
             StepperSession.command(pid, 1, :reference, %{position: 0}, :manual)

    assert_receive {:sent, %StepperCommand{operation: :reset} = reset}
    reply(pid, reset)
    assert_receive {:sent, %StepperCommand{operation: :configure} = configure}
    reply(pid, configure, %{configured: true})
    assert StepperSession.snapshot(pid).lifecycle == :awaiting_reference
  end

  test "unsolicited known status after reset never restores readiness", %{pid: pid} do
    setup_axis(pid)
    async = %StepperCommand{operation: :get_status, axis: 0, request_id: 0}
    reply(pid, async, %{configured: true, known: true, energized: true, state: :idle})
    assert {:error, :needs_reference} = StepperSession.set_target(pid, 1, 100, :train)
  end

  test "realistic Home preserves acceptance through unknown homing updates and known moving polls",
       %{pid: pid} do
    setup_axis(pid)

    :sys.replace_state(pid, fn s ->
      put_in(s.axes[1].config.reference_strategy, :internal_stop)
    end)

    assert {:ok, _} = StepperSession.command(pid, 1, :home, %{}, :manual)
    assert_receive {:sent, %StepperCommand{operation: :home} = home}
    reply(pid, home, %{configured: true, state: :homing})
    assert_receive {:sent, %StepperCommand{operation: :get_status} = poll}
    async = %StepperCommand{operation: :get_status, axis: 0, request_id: 0}
    reply(pid, async, %{configured: true, state: :homing})
    reply(pid, poll, %{configured: true, state: :homing})
    send(pid, {:tick, StepperSession.snapshot(pid).timer_epoch, :poll})
    assert_receive {:sent, %StepperCommand{operation: :get_status} = poll}

    reply(pid, poll, %{
      configured: true,
      known: true,
      energized: true,
      state: :idle,
      reference_kind: :assumed_stop
    })

    assert :ok = StepperSession.set_target(pid, 1, 100, :train)
    assert_receive {:sent, %StepperCommand{operation: :move_to} = move}
    reply(pid, move, %{configured: true, known: true, state: :moving})
    send(pid, {:tick, StepperSession.snapshot(pid).timer_epoch, :poll})
    assert_receive {:sent, %StepperCommand{operation: :get_status} = poll}
    reply(pid, poll, %{configured: true, known: true, state: :moving})
    assert :ok = StepperSession.set_target(pid, 1, 150, :train)
  end

  defp referenced(pid) do
    setup_axis(pid)
    {:ok, _} = StepperSession.command(pid, 1, :reference, %{position: 0}, :manual)
    assert_receive {:sent, %StepperCommand{operation: :reference} = ref}
    reply(pid, ref, %{configured: true, known: true, state: :idle})
    assert_receive {:sent, %StepperCommand{operation: :get_status} = poll}
    reply(pid, poll, %{configured: true, known: true, state: :idle})
  end

  defp move_acked(pid, position) do
    assert :ok = StepperSession.set_target(pid, 1, position, :train)
    assert_receive {:sent, %StepperCommand{operation: :move_to, position: ^position} = move}
    reply(pid, move, %{configured: true, known: true, state: :idle})
  end

  test "A then B then A before B is acknowledged ends at A", %{pid: pid} do
    referenced(pid)
    move_acked(pid, 100)
    assert :ok = StepperSession.set_target(pid, 1, 200, :train)
    assert_receive {:sent, %StepperCommand{operation: :move_to, position: 200} = b}
    assert :ok = StepperSession.set_target(pid, 1, 100, :train)
    reply(pid, b, %{configured: true, known: true, state: :idle})
    assert_receive {:sent, %StepperCommand{operation: :move_to, position: 100}}
  end

  test "a target equal to the pre-Home target is sent again after Home", %{pid: pid} do
    referenced(pid)

    :sys.replace_state(pid, fn s ->
      put_in(s.axes[1].config.reference_strategy, :internal_stop)
    end)

    move_acked(pid, 100)
    {:ok, _} = StepperSession.command(pid, 1, :home, %{}, :manual)
    assert_receive {:sent, %StepperCommand{operation: :home} = home}
    reply(pid, home, %{configured: true, state: :homing})
    assert_receive {:sent, %StepperCommand{operation: :get_status} = poll}
    reply(pid, poll, %{configured: true, known: true, state: :idle})
    assert :ok = StepperSession.set_target(pid, 1, 100, :train)
    assert_receive {:sent, %StepperCommand{operation: :move_to, position: 100}}
  end

  test "a timed-out move forgets the last target", %{pid: pid} do
    referenced(pid)
    move_acked(pid, 100)
    assert :ok = StepperSession.set_target(pid, 1, 200, :train)
    assert StepperSession.snapshot(pid).axes[1].last_target == 100
    Process.sleep(120)
    assert StepperSession.snapshot(pid).axes[1].last_target == nil
  end

  test "a lost Configure ack faults instead of continuing", %{pid: pid} do
    assert_receive {:sent, %StepperCommand{operation: :get_status} = probe}
    reply(pid, probe)
    assert_receive {:sent, %StepperCommand{operation: :reset} = reset}
    reply(pid, reset)
    assert_receive {:sent, %StepperCommand{operation: :configure}}
    Process.sleep(150)
    snapshot = StepperSession.snapshot(pid)
    assert snapshot.lifecycle == :fault
    assert snapshot.error == :outcome_unknown
  end

  test "rollover is counted and never leaves a deployment token behind", %{pid: pid} do
    setup_axis(pid)
    waiter = Task.async(fn -> StepperSession.begin_deployment(pid) end)
    assert_receive {:sent, %StepperCommand{operation: :reset} = reset}
    reply(pid, reset)
    assert {:ok, _token} = Task.await(waiter)
    :sys.replace_state(pid, &%{&1 | next_id: 65_535})

    token = StepperSession.snapshot(pid).deployment_token
    assert {:error, :request_ids_exhausted} = StepperSession.forget_driver(pid, token)
    snapshot = StepperSession.snapshot(pid)
    assert snapshot.deployment_token == nil
    assert snapshot.lifecycle == :fault
  end

  test "rollover increments the counter the manager uses to re-home", %{pid: pid} do
    setup_axis(pid)
    :sys.replace_state(pid, &%{&1 | next_id: 65_535})

    assert {:error, :reference_epoch_changed} =
             StepperSession.command(pid, 1, :enable, %{}, :manual)

    assert StepperSession.snapshot(pid).rollovers == 1
  end
end
