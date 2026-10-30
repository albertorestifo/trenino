defmodule Trenino.Hardware.StepperSessionTest do
  use ExUnit.Case, async: true
  alias Trenino.Hardware.{StepperAxis, StepperSession}
  alias Trenino.Serial.Protocol.{StepperCommand, StepperStatus}

  setup do
    owner = self()
    axis = %StepperAxis{id: 1, device_id: 1, name: "Speed"}

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

  defp setup_axis(pid) do
    assert_receive {:sent, %StepperCommand{operation: :get_status, axis: 0} = probe}
    reply(pid, probe)
    assert_receive {:sent, %StepperCommand{operation: :reset, axis: 255} = reset}
    reply(pid, reset)
    assert_receive {:sent, %StepperCommand{operation: :configure, axis: 0} = configure}
    reply(pid, configure, %{configured: true})
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
end
