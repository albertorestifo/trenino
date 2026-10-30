defmodule Trenino.MCP.Tools.GaugeBindingToolsTest do
  use Trenino.DataCase, async: true
  alias Trenino.{Hardware, Train}
  alias Trenino.MCP.Tools.GaugeBindingTools

  test "gauge CRUD and preview share mapper without movement" do
    {:ok, device} = Hardware.create_device(%{name: "Gauge"})
    {:ok, axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})

    {:ok, train} =
      Train.create_train(%{name: "Class 323", identifiers: [%{identifier: "Class323"}]})

    attrs = %{
      "train_id" => train.id,
      "stepper_axis_id" => axis.id,
      "name" => "Speed",
      "endpoint" => "Speed",
      "points" => [%{"value" => 0, "position" => 0}, %{"value" => 100, "position" => 720}]
    }

    assert {:ok, %{binding: b}} = GaugeBindingTools.execute("create_gauge_binding", attrs)
    refute b.enabled

    assert {:ok, %{target: 360}} =
             GaugeBindingTools.execute("preview_gauge_binding", %{"id" => b.id, "value" => 50})

    assert {:error, _} =
             GaugeBindingTools.execute("update_gauge_binding", %{"id" => b.id, "enabled" => true})

    assert {:error, _} = GaugeBindingTools.execute("create_gauge_binding", %{})
  end
end
