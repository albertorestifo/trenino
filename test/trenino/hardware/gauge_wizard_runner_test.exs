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

  test "Close while unplugged lets the user leave even though train control cannot resume",
       %{axis: axis, device: device} do
    axis = commission(axis)
    wizard = open_and_claim(axis)
    assert wizard.paused

    Phoenix.PubSub.broadcast(Trenino.PubSub, "device_updates", {:devices_updated, []})
    eventually(fn -> StepperManager.snapshot(device.id).lifecycle == :disconnected end)
    wizard = observe(wizard)
    assert wizard.interrupted

    wizard = dispatch(wizard, :close)

    assert wizard.closed
    assert wizard.error == nil
    refute wizard.paused
  end

  describe "closing during the homing tuning" do
    @dial [%{value: 0.0, position: 0}, %{value: 100.0, position: 680}]

    @home_keys [
      :reference_strategy,
      :idle_behavior,
      :home_speed,
      :home_steps,
      :home_backoff,
      :home_timeout_ms
    ]

    setup %{firmware: firmware} do
      Mimic.stub(Connection, :list_devices, fn -> StepperFirmware.connections(firmware) end)
      :ok
    end

    defp tuning(axis) do
      wizard = open_and_claim(axis)
      previous = Map.take(axis, @home_keys)
      {:ok, attrs, _} = GaugeWizard.home_plan(axis, 680, 0, 400)
      {:ok, tuned} = Hardware.update_stepper_axis(axis, attrs, dial_valid: false)
      home = %{previous: previous, backoff: 0, warnings: [], top: 680, phase: :first}
      {%{wizard | axis: tuned, step: :home_nudge, home: home, home_provisional: true}, previous}
    end

    test "puts the previous settings back, sends them and releases the lease", %{axis: axis} do
      axis = commission(axis)
      {:ok, _} = Hardware.save_dial_calibration(axis, %{points: @dial, reviewed: true})
      {wizard, previous} = tuning(axis)
      assert {:ok, %{valid: false, reviewed: true}} = Hardware.get_dial_calibration(axis.id)
      assert wizard.axis.home_backoff == 0
      refute wizard.axis.commissioned
      flush_wire()

      wizard = dispatch(wizard, :close)

      assert wizard.closed
      assert wizard.error == nil
      assert wizard.notice == :recommission
      assert {:ok, restored} = Hardware.get_stepper_axis(axis.id)
      assert Map.take(restored, @home_keys) == previous
      assert {:ok, %{valid: true, reviewed: true}} = Hardware.get_dial_calibration(axis.id)
      refute restored.commissioned
      assert_receive {:wire, %StepperCommand{operation: :stop}}, 500
      assert runtime(axis).lease == nil
      eventually(fn -> runtime(axis).config.home_backoff == previous.home_backoff end)
    end
  end

  describe "confirming homing with the zero mark off the home position" do
    @off_zero [%{value: 0.0, position: 15}, %{value: 100.0, position: 705}]

    defp at_home_confirm(axis, points) do
      {:ok, _} = Hardware.save_dial_calibration(axis, %{points: points, reviewed: true})
      wizard = open_and_claim(axis)

      %{
        wizard
        | step: :home_confirm,
          points: points,
          range: %{min: 0.0, max: 100.0, unit: :raw, count: 1},
          dial_reviewed: true
      }
    end

    test "moves the saved dial in one save and keeps it reviewed", %{axis: axis} do
      axis = commission(axis)
      {:ok, train} = Trenino.Train.create_train(%{name: "A", identifiers: [%{identifier: "A"}]})
      wizard = at_home_confirm(axis, @off_zero)

      {:ok, binding} =
        Trenino.Train.create_gauge_binding(train.id, %{
          name: "S",
          endpoint: "S",
          stepper_axis_id: axis.id,
          enabled: true
        })

      wizard = dispatch(wizard, {:answer, :yes})

      assert wizard.step == :finish

      assert {:ok, %{reviewed: true, valid: true, points: points}} =
               Hardware.get_dial_calibration(axis.id)

      assert Enum.map(points, & &1.position) == [0, 690]
      assert {:ok, %{enabled: true}} = Trenino.Train.get_gauge_binding(binding.id)
    end

    test "refuses a shift past the travel limits and saves nothing", %{axis: axis} do
      axis = commission(axis)
      points = [%{value: 0.0, position: 0}, %{value: 100.0, position: 715}]
      wizard = at_home_confirm(axis, points)
      wizard = %{wizard | axis: %{wizard.axis | home_position: 20}}

      wizard = dispatch(wizard, {:answer, :yes})

      assert wizard.step == :home_confirm
      assert wizard.error == :dial_shift_outside_limits
      assert {:ok, %{points: saved}} = Hardware.get_dial_calibration(axis.id)
      assert Enum.map(saved, & &1.position) == [0, 715]
    end
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
