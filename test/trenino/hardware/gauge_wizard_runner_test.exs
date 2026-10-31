defmodule Trenino.Hardware.GaugeWizardRunnerTest do
  @moduledoc """
  Runs the wizard and its Runner against the real StepperManager and the firmware fixture,
  so lease handling (tokens, release, resume) is exercised rather than stubbed.
  """
  use Trenino.DataCase, async: false

  alias Trenino.Hardware
  alias Trenino.Hardware.GaugeWizard
  alias Trenino.Hardware.GaugeWizard.Runner
  alias Trenino.Hardware.StepperManager
  alias Trenino.Serial.Connection
  alias Trenino.Serial.Connection.DeviceConnection
  alias Trenino.Serial.Protocol.StepperCommand
  alias Trenino.Test.StepperFirmware

  setup :set_mimic_global

  setup do
    {:ok, device} = Hardware.create_device(%{name: "Physical speedometer"})

    connection = %DeviceConnection{
      port: "wizard-mock",
      status: :connected,
      pid: self(),
      device_config_id: 0,
      device_version: "3.1.0"
    }

    firmware = start_supervised!({StepperFirmware, owner: self(), connection: connection})
    Mimic.stub(Connection, :connected_devices, fn -> StepperFirmware.connections(firmware) end)

    Mimic.stub(Connection, :send_message, fn port, message ->
      StepperFirmware.send_message(firmware, port, message)
    end)

    Mimic.stub(Connection, :update_device_config_id, fn _, id ->
      StepperFirmware.identity(firmware, id)

      Phoenix.PubSub.broadcast(
        Trenino.PubSub,
        "device_updates",
        {:devices_updated, StepperFirmware.connections(firmware)}
      )

      :ok
    end)

    start_supervised!({StepperManager, devices: []})
    {:ok, axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})
    {:ok, _} = Hardware.apply_configuration(connection.port, device.id)
    eventually(fn -> StepperManager.snapshot(device.id).lifecycle == :awaiting_reference end)
    %{device: device, axis: axis, firmware: firmware}
  end

  defp runtime(axis), do: StepperManager.snapshot(axis.device_id).axes[axis.id]

  defp commission(axis) do
    {:ok, token} = StepperManager.claim_manual(axis.id, self())
    eventually(fn -> runtime(axis).pending == nil end)
    {:ok, _} = StepperManager.command(axis.id, :reference, %{position: 0}, token)
    eventually(fn -> runtime(axis).ready end)
    {:ok, _} = StepperManager.complete_commissioning(axis.id, token)
    :ok = StepperManager.release_manual(axis.id, token)
    eventually(fn -> runtime(axis).pending == nil end)
    :ok = StepperManager.resume(axis.id)
    {:ok, fresh} = Hardware.get_stepper_axis(axis.id)
    fresh
  end

  # Mirrors the LiveView component: apply the event, run the requested effects through the
  # Runner, feed results back and observe the real manager.
  defp dispatch(wizard, event) do
    {wizard, effects} = GaugeWizard.update(wizard, event)
    wizard |> run(effects) |> observe()
  end

  defp run(wizard, []), do: wizard

  defp run(wizard, effects) do
    {wizard, more} =
      Enum.reduce(effects, {wizard, []}, fn effect, {w, acc} ->
        {w, next} = GaugeWizard.update(w, Runner.run(effect, w))
        {w, acc ++ next}
      end)

    run(wizard, more)
  end

  defp observe(wizard) do
    {wizard, effects} = GaugeWizard.update(wizard, {:observed, Runner.observe(wizard)})
    run(wizard, effects)
  end

  defp open_and_claim(axis) do
    wizard = axis |> GaugeWizard.new() |> observe()
    wizard |> dispatch({:confirm_wiring, true}) |> dispatch(:continue)
  end

  defp flush_wire do
    receive do
      {:wire, _} -> flush_wire()
    after
      50 -> :ok
    end
  end

  test "Close releases the real lease and gives a commissioned axis back to train control",
       %{axis: axis} do
    axis = commission(axis)
    wizard = open_and_claim(axis)
    assert wizard.step == :align
    assert wizard.token != nil
    assert runtime(axis).lease != nil

    wizard = dispatch(wizard, :close)

    assert wizard.closed
    assert wizard.error == nil
    assert runtime(axis).lease == nil
    refute runtime(axis).paused
  end

  test "Close while the needle is moving stops the axis and releases control",
       %{axis: axis, firmware: firmware} do
    axis = commission(axis)
    wizard = open_and_claim(axis)
    wizard = dispatch(wizard, :set_reference)
    eventually(fn -> runtime(axis).ready end)
    wizard = observe(wizard)
    assert wizard.step == :jog_test

    StepperFirmware.set_flag(firmware, :hold_move_ack, true)
    wizard = dispatch(wizard, :jog_up)
    assert_receive {:wire, %StepperCommand{operation: :move_to, position: 20}}, 500
    assert GaugeWizard.moving?(wizard)
    flush_wire()

    wizard = dispatch(wizard, :close)

    assert wizard.closed
    assert_receive {:wire, %StepperCommand{operation: :stop}}, 500
    assert runtime(axis).lease == nil
  end

  defp eventually(check, attempts \\ 100)
  defp eventually(check, 0), do: assert(check.())

  defp eventually(check, attempts) do
    if check.() do
      :ok
    else
      Process.sleep(10)
      eventually(check, attempts - 1)
    end
  end
end
