defmodule Trenino.MCP.Tools.GaugeBindingToolsTest do
  use Trenino.DataCase, async: true
  alias Trenino.{Hardware, Train}
  alias Trenino.MCP.Tools.{DialCalibrationTools, GaugeBindingTools}

  @points [%{"value" => 0, "position" => 0}, %{"value" => 100, "position" => 720}]

  setup do
    {:ok, device} = Hardware.create_device(%{name: "Gauge"})
    {:ok, axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})
    {:ok, axis} = Hardware.commission_stepper_axis(axis)

    {:ok, train} =
      Train.create_train(%{name: "Class 323", identifiers: [%{identifier: "Class323"}]})

    %{axis: axis, train: train}
  end

  test "dial calibration is read and written per axis, never through the binding", %{axis: axis} do
    assert {:ok, %{calibration: nil}} =
             DialCalibrationTools.execute("get_dial_calibration", %{"stepper_axis_id" => axis.id})

    assert {:ok, %{calibration: %{reviewed: false, points: [_, _]}}} =
             DialCalibrationTools.execute("update_dial_calibration", %{
               "stepper_axis_id" => axis.id,
               "points" => @points
             })

    assert {:ok, %{calibration: %{reviewed: true, valid: true, output_unit: :mph}}} =
             DialCalibrationTools.execute("update_dial_calibration", %{
               "stepper_axis_id" => axis.id,
               "points" => @points,
               "output_unit" => "mph",
               "reviewed" => true
             })

    assert {:ok, %{calibration: %{reviewed: true}}} =
             DialCalibrationTools.execute("get_dial_calibration", %{"stepper_axis_id" => axis.id})

    assert {:error, _} =
             DialCalibrationTools.execute("update_dial_calibration", %{
               "stepper_axis_id" => axis.id,
               "points" => [%{"value" => 0, "position" => 0}]
             })

    assert {:error, _} =
             DialCalibrationTools.execute("get_dial_calibration", %{"stepper_axis_id" => 0})
  end

  test "gauge CRUD and preview share mapper without movement", %{axis: axis, train: train} do
    attrs = %{
      "train_id" => train.id,
      "stepper_axis_id" => axis.id,
      "name" => "Speed",
      "endpoint" => "Speed"
    }

    assert {:ok, %{binding: b}} = GaugeBindingTools.execute("create_gauge_binding", attrs)
    refute b.enabled
    assert b.dial == nil
    refute Map.has_key?(b, :points)

    assert {:error, _} =
             GaugeBindingTools.execute("preview_gauge_binding", %{"id" => b.id, "value" => 50})

    assert {:error, _} =
             GaugeBindingTools.execute("update_gauge_binding", %{"id" => b.id, "enabled" => true})

    {:ok, _} =
      DialCalibrationTools.execute("update_dial_calibration", %{
        "stepper_axis_id" => axis.id,
        "points" => @points,
        "reviewed" => true
      })

    assert {:ok, %{target: 360}} =
             GaugeBindingTools.execute("preview_gauge_binding", %{"id" => b.id, "value" => 50})

    assert {:ok, %{binding: %{enabled: true, dial: %{reviewed: true}}}} =
             GaugeBindingTools.execute("update_gauge_binding", %{"id" => b.id, "enabled" => true})

    assert {:error, _} = GaugeBindingTools.execute("create_gauge_binding", %{})
  end

  test "create_gauge_binding no longer takes points" do
    tool = Enum.find(GaugeBindingTools.tools(), &(&1.name == "create_gauge_binding"))
    refute "points" in tool.input_schema.required
    refute Map.has_key?(tool.input_schema.properties, :points)
  end
end
