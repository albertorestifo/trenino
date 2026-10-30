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
end
