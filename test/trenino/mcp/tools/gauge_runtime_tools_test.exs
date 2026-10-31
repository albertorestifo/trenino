defmodule Trenino.MCP.Tools.GaugeRuntimeToolsTest do
  use Trenino.DataCase, async: false
  alias Trenino.{Hardware, Train}
  alias Trenino.MCP.Tools.GaugeRuntimeTools
  alias Trenino.Simulator.{Client, ConnectionState}
  alias Trenino.Train.GaugeController
  setup :set_mimic_global

  setup do
    client = %Client{base_url: "http://fake", api_key: "fake"}

    Mimic.stub(Trenino.Simulator.Connection, :get_status, fn ->
      %ConnectionState{status: :connected, client: client}
    end)

    Mimic.stub(Client, :subscribe, fn _, _, _ -> {:ok, %{}} end)
    Mimic.stub(Client, :unsubscribe, fn _, _ -> {:ok, %{}} end)

    Mimic.stub(Client, :get_subscription, fn _, _ ->
      {:error, {:http_error, 500, %{"x" => 1}}}
    end)

    Mimic.stub(Trenino.Hardware.StepperManager, :set_target, fn _, _, _ -> :ok end)
    Mimic.stub(Trenino.Hardware.StepperManager, :inactive, fn _, _ -> :ok end)

    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})
    {:ok, axis} = Hardware.commission_stepper_axis(axis)
    {:ok, train} = Train.create_train(%{name: "T", identifiers: [%{identifier: "GRT"}]})

    {:ok, _} =
      Hardware.save_dial_calibration(axis, %{
        points: [%{value: 0, position: 0}, %{value: 100, position: 720}],
        reviewed: true
      })

    {:ok, binding} =
      Train.create_gauge_binding(train.id, %{
        stepper_axis_id: axis.id,
        name: "Speed",
        endpoint: "Speed",
        enabled: true
      })

    %{train: train, binding: binding}
  end

  test "reports inactive when the controller does not run the train", %{train: train} do
    assert {:ok, %{active: false, bindings: []}} =
             GaugeRuntimeTools.execute("get_gauge_runtime", %{"train_id" => train.id})
  end

  test "errors without train_id and without an active train" do
    assert {:error, _} = GaugeRuntimeTools.execute("get_gauge_runtime", %{})
  end

  test "result is JSON-encodable even with failures", %{train: train, binding: b} do
    pid = start_supervised!(GaugeController)
    send(pid, {:train_changed, train})
    Process.sleep(150)

    assert {:ok, result} =
             GaugeRuntimeTools.execute("get_gauge_runtime", %{"train_id" => train.id})

    assert result.active
    assert [%{id: id, failure: failure}] = result.bindings
    assert id == b.id and is_binary(failure)
    assert is_boolean(result.controller.simulator_connected)
    assert {:ok, _} = Jason.encode(result)
  end
end
