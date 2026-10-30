defmodule Trenino.Train.GaugeBindingsTest do
  use Trenino.DataCase, async: true
  alias Trenino.{Hardware, Train}

  test "binding round trips disabled and mode edits invalidate it" do
    {:ok, train} =
      Train.create_train(%{name: "Class 323", identifiers: [%{identifier: "Class323"}]})

    {:ok, device} = Hardware.create_device(%{name: "Speedometer"})
    {:ok, axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})

    attrs = %{
      name: "Speed",
      endpoint: "Speed",
      stepper_axis_id: axis.id,
      points: [%{value: 0, position: 0}, %{value: 100, position: 720}]
    }

    assert {:ok, binding} = Train.create_gauge_binding(train.id, attrs)
    refute binding.enabled
    assert length(Train.list_gauge_bindings(train.id)) == 1
    assert {:error, _} = Train.update_gauge_binding(binding, %{enabled: true})
    assert {:ok, _} = Hardware.update_stepper_axis(axis, %{mode: :half_step})
    assert {:ok, updated} = Train.get_gauge_binding(binding.id)
    refute updated.calibration_valid

    assert {:ok, recalibrated} =
             Train.update_gauge_binding(updated, %{
               points: attrs.points,
               calibration_reviewed: true
             })

    assert recalibrated.calibration_valid
  end
end
