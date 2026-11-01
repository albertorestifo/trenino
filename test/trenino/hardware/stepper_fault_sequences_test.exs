defmodule Trenino.Hardware.StepperFaultSequencesTest do
  @moduledoc "Whole fault -> recovery sequences driven through a real StepperSession."
  use ExUnit.Case, async: true
  alias Trenino.Hardware.{StepperAxis, StepperSession}
  alias Trenino.Serial.Protocol.{StepperCommand, StepperStatus}

  setup context do
    owner = self()

    axis = %StepperAxis{
      id: 1,
      device_id: 1,
      name: "Speed",
      reference_strategy: Map.get(context, :strategy, :host_reference)
    }

    {:ok, pid} =
      StepperSession.start_link(
        port: "fake",
        generation: make_ref(),
        device_id: 1,
        axes: [axis],
        send_fun: fn _, msg ->
          send(owner, {:sent, msg})
          :ok
        end,
        ack_timeout: 30,
        idle_poll: 10_000
      )

    on_exit(fn -> if Process.alive?(pid), do: GenServer.stop(pid) end)
    setup_axis(pid)
    %{pid: pid}
  end

  defp reply(pid, %StepperCommand{} = cmd, attrs \\ %{}) do
    base = %StepperStatus{
      operation: cmd.operation,
      axis: cmd.axis,
      request_id: cmd.request_id,
      result: :ok,
      state: :idle,
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

  defp async_status(pid, attrs),
    do: reply(pid, %StepperCommand{operation: :get_status, axis: 0, request_id: 0}, attrs)

  defp setup_axis(pid) do
    assert_receive {:sent, %StepperCommand{operation: :get_status, axis: 0} = probe}
    reply(pid, probe)
    assert_receive {:sent, %StepperCommand{operation: :reset, axis: 255} = reset}
    reply(pid, reset)
    assert_receive {:sent, %StepperCommand{operation: :configure, axis: 0} = configure}
    reply(pid, configure, %{configured: true})
  end

  # Mirrors StepperManager's recovery: deployment Reset, reload, finish, then re-probe.
  defp recover(pid) do
    flush_sent()
    waiter = Task.async(fn -> StepperSession.begin_deployment(pid) end)
    assert_receive {:sent, %StepperCommand{operation: :reset} = reset}
    reply(pid, reset)
    assert {:ok, token} = Task.await(waiter)
    axes = [StepperSession.snapshot(pid).axes[1].config]
    assert :ok = StepperSession.reload_axes(pid, axes, token)
    assert :ok = StepperSession.finish_deployment(pid, token, :ok)
    setup_axis(pid)
    assert StepperSession.snapshot(pid).lifecycle == :awaiting_reference
  end

  defp flush_sent do
    receive do
      {:sent, _} -> flush_sent()
    after
      0 -> :ok
    end
  end

  defp assert_clean_after_recovery(pid) do
    snapshot = StepperSession.snapshot(pid)
    assert snapshot.error == nil
    assert snapshot.axes[1].error == nil
    refute snapshot.axes[1].ready
    refute snapshot.axes[1].reference_accepted
    assert snapshot.axes[1].pending == nil
    assert snapshot.axes[1].desired_target == nil
  end

  defp reference(pid) do
    assert {:ok, _} = StepperSession.command(pid, 1, :reference, %{position: 0}, :manual)
    assert_receive {:sent, %StepperCommand{operation: :reference} = ref}
    reply(pid, ref, %{configured: true, known: true, state: :idle})
    assert_receive {:sent, %StepperCommand{operation: :get_status} = poll}
    reply(pid, poll, %{configured: true, known: true, state: :idle, energized: true})
    assert StepperSession.snapshot(pid).axes[1].ready
  end

  @tag strategy: :internal_stop
  test "fault during homing, recover, then home again", %{pid: pid} do
    assert {:ok, _} = StepperSession.command(pid, 1, :home, %{}, :manual)
    assert_receive {:sent, %StepperCommand{operation: :home} = home}
    reply(pid, home, %{configured: true, state: :homing})
    assert_receive {:sent, %StepperCommand{operation: :get_status} = poll}
    reply(pid, poll, %{configured: true, state: :homing})

    async_status(pid, %{configured: true, state: :fault, fault: :home_timeout})

    faulted = StepperSession.snapshot(pid)
    assert faulted.lifecycle == :fault
    assert faulted.error == :home_timeout
    refute faulted.axes[1].reference_accepted

    assert {:error, :fault} = StepperSession.command(pid, 1, :home, %{}, :manual)
    assert {:error, :fault} = StepperSession.set_target(pid, 1, 100, :train)

    recover(pid)
    assert_clean_after_recovery(pid)
    assert {:error, :needs_reference} = StepperSession.set_target(pid, 1, 100, :train)

    assert {:ok, _} = StepperSession.command(pid, 1, :home, %{}, :manual)
    assert_receive {:sent, %StepperCommand{operation: :home} = home2}
    refute home2.request_id == home.request_id
    reply(pid, home2, %{configured: true, state: :homing})
    assert_receive {:sent, %StepperCommand{operation: :get_status} = poll2}

    reply(pid, poll2, %{
      configured: true,
      known: true,
      energized: true,
      state: :idle,
      reference_kind: :assumed_stop
    })

    assert :ok = StepperSession.set_target(pid, 1, 100, :train)
  end

  test "fault during train-driven motion drops targets and never replays the move", %{pid: pid} do
    reference(pid)
    assert :ok = StepperSession.set_target(pid, 1, 100, :train)
    assert_receive {:sent, %StepperCommand{operation: :move_to, position: 100} = move}
    # a newer target is buffered behind the pending move
    assert :ok = StepperSession.set_target(pid, 1, 200, :train)
    assert StepperSession.snapshot(pid).axes[1].desired_target == 200

    reply(pid, move, %{configured: true, known: true, state: :fault, fault: :driver_i2c})

    faulted = StepperSession.snapshot(pid)
    assert faulted.lifecycle == :fault
    assert faulted.error == :driver_i2c
    assert faulted.axes[1].desired_target == nil
    refute faulted.axes[1].ready
    assert {:error, :fault} = StepperSession.set_target(pid, 1, 300, :train)

    recover(pid)
    assert_clean_after_recovery(pid)
    assert {:error, :needs_reference} = StepperSession.set_target(pid, 1, 100, :train)
    refute_receive {:sent, %StepperCommand{operation: :move_to}}, 100

    reference(pid)
    assert :ok = StepperSession.set_target(pid, 1, 150, :train)
    assert_receive {:sent, %StepperCommand{operation: :move_to, position: 150}}
  end

  test "reset_failed during recovery faults again, then a further recovery succeeds", %{pid: pid} do
    async_status(pid, %{configured: true, fault: :driver_i2c, state: :fault})
    assert StepperSession.snapshot(pid).lifecycle == :fault

    caller = self()
    spawn(fn -> send(caller, {:attempt, StepperSession.begin_deployment(pid)}) end)
    assert_receive {:sent, %StepperCommand{operation: :reset} = reset}
    reply(pid, reset, %{result: :io_error})
    assert_receive {:attempt, {:error, {:reset_failed, :io_error}}}, 200

    failed = StepperSession.snapshot(pid)
    assert failed.lifecycle == :fault
    assert failed.error == {:reset_failed, :io_error}
    assert failed.deployment_token == nil

    recover(pid)
    assert_clean_after_recovery(pid)
    reference(pid)
    assert :ok = StepperSession.set_target(pid, 1, 50, :train)
  end

  test "an unconfirmed outcome error is cleared by a clean reconfigure", %{pid: pid} do
    assert {:ok, _} = StepperSession.command(pid, 1, :reference, %{position: 0}, :manual)
    assert_receive {:sent, %StepperCommand{operation: :reference}}
    # never acknowledged: retries are exhausted
    Process.sleep(120)
    assert StepperSession.snapshot(pid).axes[1].error == :outcome_unknown

    recover(pid)
    assert_clean_after_recovery(pid)
  end

  test "session fault error is cleared by the probe that starts the next configuration", %{
    pid: pid
  } do
    async_status(pid, %{configured: false})
    assert StepperSession.snapshot(pid).error == :unexpected_reset
    recover(pid)
    assert_clean_after_recovery(pid)
  end

  test "a rejected mutation records the error and the next accepted one clears it", %{pid: pid} do
    assert {:ok, _} = StepperSession.command(pid, 1, :reference, %{position: 0}, :manual)
    assert_receive {:sent, %StepperCommand{operation: :reference} = ref}
    reply(pid, ref, %{configured: true, result: :not_configured})
    rejected = StepperSession.snapshot(pid).axes[1]
    assert rejected.error == :not_configured
    refute rejected.ready
    assert rejected.pending == nil

    reference(pid)
    snapshot = StepperSession.snapshot(pid)
    assert snapshot.axes[1].error == nil
    assert snapshot.error == nil
  end
end
