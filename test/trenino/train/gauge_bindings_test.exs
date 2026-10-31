defmodule Trenino.Train.GaugeBindingsTest do
  use Trenino.DataCase, async: true
  alias Trenino.{Hardware, Train}

  test "two trains share the axis dial; binding round trips disabled and mode edits invalidate it" do
    {:ok, train} =
      Train.create_train(%{name: "Class 323", identifiers: [%{identifier: "Class323"}]})

    {:ok, other} =
      Train.create_train(%{name: "Class 378", identifiers: [%{identifier: "Class378"}]})

    {:ok, device} = Hardware.create_device(%{name: "Speedometer"})
    {:ok, axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})
    {:ok, axis} = Hardware.commission_stepper_axis(axis)

    attrs = %{name: "Speed", endpoint: "Speed", stepper_axis_id: axis.id}

    assert {:ok, binding} = Train.create_gauge_binding(train.id, attrs)
    assert {:ok, _} = Train.create_gauge_binding(other.id, attrs)
    refute binding.enabled
    assert length(Train.list_gauge_bindings(train.id)) == 1
    # No dial recorded yet: nothing can be enabled.
    assert {:error, _} = Train.update_gauge_binding(binding, %{enabled: true})

    points = [%{value: 0, position: 0}, %{value: 100, position: 720}]
    assert {:ok, _} = Hardware.save_dial_calibration(axis, %{points: points, reviewed: true})
    assert {:ok, enabled} = Train.update_gauge_binding(binding, %{enabled: true})
    assert enabled.enabled

    assert {:ok, _} = Hardware.update_stepper_axis(axis, %{mode: :half_step})
    assert {:ok, %{enabled: false} = updated} = Train.get_gauge_binding(binding.id)
    refute updated.stepper_axis.dial_calibration.valid
    assert {:error, _} = Train.update_gauge_binding(updated, %{enabled: true})

    # The mode change also cleared commissioning; both must be redone.
    assert {:ok, axis} = Hardware.get_stepper_axis(axis.id)
    refute axis.commissioned
    assert {:ok, axis} = Hardware.commission_stepper_axis(axis)
    assert {:ok, _} = Hardware.save_dial_calibration(axis, %{points: points, reviewed: true})
    assert {:ok, %{enabled: true}} = Train.update_gauge_binding(updated, %{enabled: true})
  end

  test "lists the gauge bindings that drive one axis, with their trains" do
    {:ok, train} =
      Train.create_train(%{name: "Class 323", identifiers: [%{identifier: "Class323"}]})

    {:ok, device} = Hardware.create_device(%{name: "Speedometer"})
    {:ok, axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})

    {:ok, other} =
      Hardware.create_stepper_axis(device.id, %{name: "Other", axis_index: 1, motor_port: 2})

    assert Train.list_gauge_bindings_for_axis(axis.id) == []

    attrs = %{name: "Speed", endpoint: "Speed", stepper_axis_id: axis.id}
    assert {:ok, _} = Train.create_gauge_binding(train.id, attrs)

    assert [%{train: %{name: "Class 323"}}] = Train.list_gauge_bindings_for_axis(axis.id)
    assert Train.list_gauge_bindings_for_axis(other.id) == []
  end
end
