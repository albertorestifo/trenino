defmodule Trenino.StepperGaugeIntegrationTest do
  use Trenino.DataCase, async: false
  alias Trenino.Hardware
  alias Trenino.Hardware.StepperManager
  alias Trenino.Serial.Connection
  alias Trenino.Serial.Connection.DeviceConnection
  alias Trenino.Serial.Protocol.{Configure, StepperCommand}
  alias Trenino.Simulator.{Client, ConnectionState}
  alias Trenino.Test.StepperFirmware
  alias Trenino.Train
  alias Trenino.Train.GaugeController
  setup :set_mimic_global

  setup do
    {:ok, device} = Hardware.create_device(%{name: "Physical speedometer"})

    connection = %DeviceConnection{
      port: "integration-mock",
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

    manager = start_supervised!({StepperManager, devices: []})
    %{device: device, firmware: firmware, manager: manager, connection: connection}
  end

  test "axis-only deployment through actual mapper/controller drives only after explicit reference/resume",
       ctx do
    {:ok, axis} = Hardware.create_stepper_axis(ctx.device.id, %{name: "Speed"})
    assert {:ok, _} = Hardware.apply_configuration(ctx.connection.port, ctx.device.id)
    assert_receive {:wire, %Configure{input_type: :empty} = empty}, 200
    assert {:ok, <<2, _::little-32, 0, 0, 255>>} = Configure.encode(empty)
    eventually(fn -> StepperManager.snapshot(ctx.device.id).lifecycle == :awaiting_reference end)
    refute_receive {:wire, %StepperCommand{operation: :home}}, 30
    assert {:ok, token} = StepperManager.claim_manual(axis.id, self())
    eventually(fn -> StepperManager.snapshot(ctx.device.id).axes[axis.id].pending == nil end)
    assert {:ok, _} = StepperManager.command(axis.id, :reference, %{position: 0}, token)
    eventually(fn -> StepperManager.snapshot(ctx.device.id).axes[axis.id].ready end)
    assert {:ok, _} = StepperManager.complete_commissioning(axis.id, token)

    {:ok, train} =
      Train.create_train(%{
        name: "Class 323",
        identifiers: [%{identifier: "Class323Integration"}]
      })

    {:ok, _} =
      Train.create_gauge_binding(train.id, %{
        name: "Speed",
        stepper_axis_id: axis.id,
        endpoint: "VerifiedSpeed",
        input_unit: :mps,
        output_unit: :mph,
        enabled: true,
        calibration_reviewed: true,
        points: [%{value: 0, position: 0}, %{value: 100, position: 720}]
      })

    assert :ok = StepperManager.release_manual(axis.id, token)
    eventually(fn -> StepperManager.snapshot(ctx.device.id).axes[axis.id].pending == nil end)
    assert :ok = StepperManager.resume(axis.id)
    client = %Client{base_url: "http://mock", api_key: "mock"}

    Mimic.stub(Trenino.Simulator.Connection, :get_status, fn ->
      %ConnectionState{status: :connected, client: client}
    end)

    Mimic.stub(Client, :subscribe, fn _, "VerifiedSpeed", 4000 -> {:ok, %{}} end)
    Mimic.stub(Client, :unsubscribe, fn _, _ -> {:ok, %{}} end)

    Mimic.stub(Client, :get_subscription, fn _, 4000 ->
      {:ok, %{"Entries" => [%{"NodeValid" => true, "Values" => %{"Speed" => 44.704}}]}}
    end)

    controller = start_supervised!(GaugeController)
    send(controller, {:train_changed, train})
    assert_receive {:wire, %StepperCommand{operation: :move_to, position: 720}}, 700
    assert {:ok, token} = StepperManager.claim_manual(axis.id, self())
    eventually(fn -> StepperManager.snapshot(ctx.device.id).axes[axis.id].pending == nil end)
    refute_receive {:wire, %StepperCommand{operation: :move_to}}, 250
    assert :ok = StepperManager.release_manual(axis.id, token)
    StepperFirmware.connect(ctx.firmware, %{ctx.connection | status: :uploading})
    send(ctx.manager, {:devices_updated, [%{ctx.connection | status: :uploading}]})
    eventually(fn -> StepperManager.snapshot(ctx.device.id).lifecycle == :disconnected end)
    reconnected = %{ctx.connection | device_config_id: ctx.device.config_id, pid: controller}
    StepperFirmware.connect(ctx.firmware, reconnected)
    send(ctx.manager, {:devices_updated, [reconnected]})
    eventually(fn -> StepperManager.snapshot(ctx.device.id).lifecycle == :awaiting_reference end)
    refute_receive {:wire, %StepperCommand{operation: :home}}, 100
    refute_receive {:wire, %StepperCommand{operation: :move_to}}, 250
    assert {:ok, fresh_token} = StepperManager.claim_manual(axis.id, self())
    eventually(fn -> StepperManager.snapshot(ctx.device.id).axes[axis.id].pending == nil end)
    assert {:ok, _} = StepperManager.command(axis.id, :reference, %{position: 0}, fresh_token)
    eventually(fn -> StepperManager.snapshot(ctx.device.id).axes[axis.id].ready end)
    StepperManager.release_manual(axis.id, fresh_token)
    eventually(fn -> StepperManager.snapshot(ctx.device.id).axes[axis.id].pending == nil end)
    StepperManager.resume(axis.id)
    assert_receive {:wire, %StepperCommand{operation: :move_to, position: 720}}, 700
    stop_supervised!(GaugeController)
    stop_supervised!(StepperManager)
  end

  test "commissioned opt-in Home is once per genuine new connection, never duplicate or recovery",
       ctx do
    {:ok, _axis} =
      Hardware.create_stepper_axis(ctx.device.id, %{
        name: "Speed",
        reference_strategy: :internal_stop,
        commissioned: true,
        startup_reference: :home_on_connect
      })

    connected = %{ctx.connection | device_config_id: ctx.device.config_id}
    StepperFirmware.connect(ctx.firmware, connected)
    send(ctx.manager, {:devices_updated, [connected]})
    assert_receive {:wire, %StepperCommand{operation: :home}}, 500
    eventually(fn -> StepperManager.snapshot(ctx.device.id).lifecycle == :ready end)
    send(ctx.manager, {:devices_updated, [connected]})
    refute_receive {:wire, %StepperCommand{operation: :home}}, 100
    assert :ok = StepperManager.recover(ctx.device.id)
    eventually(fn -> StepperManager.snapshot(ctx.device.id).lifecycle == :awaiting_reference end)
    refute_receive {:wire, %StepperCommand{operation: :home}}, 100
    stop_supervised!(StepperManager)
  end

  test "address recommission uses explicit reset/forget/configure and online delete acknowledges release",
       ctx do
    {:ok, axis} = Hardware.create_stepper_axis(ctx.device.id, %{name: "Speed"})

    {:ok, other} =
      Hardware.create_stepper_axis(ctx.device.id, %{name: "Current", axis_index: 1, motor_port: 2})

    connected = %{ctx.connection | device_config_id: ctx.device.config_id}
    StepperFirmware.connect(ctx.firmware, connected)
    send(ctx.manager, {:devices_updated, [connected]})
    eventually(fn -> StepperManager.snapshot(ctx.device.id).lifecycle == :awaiting_reference end)

    assert {:error, :registration_acknowledgement_required} =
             StepperManager.recommission_address(ctx.device.id, 97, false)

    assert :ok = StepperManager.recommission_address(ctx.device.id, 97, true)
    assert_receive {:wire, %StepperCommand{operation: :forget_driver}}, 200
    eventually(fn -> StepperManager.snapshot(ctx.device.id).lifecycle == :awaiting_reference end)

    assert Enum.all?(
             Hardware.list_stepper_axes(ctx.device.id),
             &(&1.shield_address == 97 and not &1.commissioned)
           )

    {:ok, current} = Hardware.get_stepper_axis(axis.id)
    assert {:ok, _} = Hardware.delete_stepper_axis(current)
    assert_receive {:wire, %StepperCommand{operation: :release, axis: 0}}, 200
    assert [remaining] = Hardware.list_stepper_axes(ctx.device.id)
    assert remaining.id == other.id
    stop_supervised!(StepperManager)
  end

  test "legacy input/display/two-axis deployment cancels buffered targets and faults both axes",
       ctx do
    {:ok, _} =
      Hardware.create_input(ctx.device.id, %{input_type: :analog, pin: 3, sensitivity: 5})

    {:ok, _} =
      Hardware.create_i2c_module(ctx.device.id, %{
        module_chip: :ht16k33,
        i2c_address: 112,
        params: %{
          brightness: 8,
          num_digits: 4,
          display_type: :fourteen_segment,
          has_dot: false,
          align_right: true,
          min_value: 0.0
        }
      })

    {:ok, a} = Hardware.create_stepper_axis(ctx.device.id, %{name: "Speed"})

    {:ok, b} =
      Hardware.create_stepper_axis(ctx.device.id, %{name: "Current", axis_index: 1, motor_port: 2})

    connected = %{ctx.connection | device_config_id: ctx.device.config_id}
    StepperFirmware.connect(ctx.firmware, connected)
    send(ctx.manager, {:devices_updated, [connected]})
    eventually(fn -> StepperManager.snapshot(ctx.device.id).lifecycle == :awaiting_reference end)

    for axis <- [a, b] do
      {:ok, token} = StepperManager.claim_manual(axis.id, self())
      eventually(fn -> StepperManager.snapshot(ctx.device.id).axes[axis.id].pending == nil end)
      {:ok, _} = StepperManager.command(axis.id, :reference, %{position: 0}, token)
      eventually(fn -> StepperManager.snapshot(ctx.device.id).axes[axis.id].ready end)
      {:ok, _} = StepperManager.complete_commissioning(axis.id, token)
      StepperManager.release_manual(axis.id, token)
      eventually(fn -> StepperManager.snapshot(ctx.device.id).axes[axis.id].pending == nil end)
      StepperManager.resume(axis.id)
    end

    StepperFirmware.set_flag(ctx.firmware, :hold_move_ack, true)
    assert :ok = StepperManager.set_target(a.id, 100, 1)
    assert :ok = StepperManager.set_target(a.id, 200, 1)
    assert :ok = StepperManager.set_target(a.id, 300, 1)
    assert {:ok, _} = Hardware.apply_configuration(ctx.connection.port, ctx.device.id)
    assert_receive {:wire, %Configure{input_type: :analog}}, 300
    assert_receive {:wire, %Configure{input_type: :ht16k33}}, 300
    eventually(fn -> StepperManager.snapshot(ctx.device.id).lifecycle == :awaiting_reference end)
    refute_receive {:wire, %StepperCommand{operation: :move_to, position: 300}}, 50
    assert {:error, _} = StepperManager.set_target(a.id, 300, 1)

    fault = %Trenino.Serial.Protocol.StepperStatus{
      operation: :get_status,
      axis: 0,
      request_id: 0,
      result: :io_error,
      fault: :driver_i2c,
      state: :fault,
      configured: true,
      known: false
    }

    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      "serial:messages:#{ctx.connection.port}",
      {:serial_message, ctx.connection.port, fault}
    )

    eventually(fn -> StepperManager.snapshot(ctx.device.id).lifecycle == :fault end)

    assert Enum.all?(StepperManager.snapshot(ctx.device.id).axes, fn {_, axis} ->
             not axis.ready
           end)

    assert {:error, _} = StepperManager.set_target(b.id, 100, 1)
    stop_supervised!(StepperManager)
  end

  test "shield address and axis deletion notify train consumers after domain mutation", ctx do
    {:ok, axis} = Hardware.create_stepper_axis(ctx.device.id, %{name: "Speed"})
    Phoenix.PubSub.subscribe(Trenino.PubSub, "train:gauges:configuration")
    assert {:ok, [updated]} = Hardware.update_stepper_shield_address(ctx.device.id, 97)
    assert_receive {:gauge_bindings_changed, :all}, 100
    assert updated.shield_address == 97
    assert {:ok, _} = Hardware.delete_stepper_axis(%{axis | shield_address: 97})
    assert_receive {:gauge_bindings_changed, :all}, 100
    stop_supervised!(StepperManager)
  end

  defp eventually(check, attempts \\ 100)
  defp eventually(check, 0), do: assert(check.())

  defp eventually(check, attempts) do
    if check.(),
      do: :ok,
      else:
        (
          Process.sleep(10)
          eventually(check, attempts - 1)
        )
  end
end
