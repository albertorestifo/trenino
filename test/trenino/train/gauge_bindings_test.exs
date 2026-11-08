defmodule Trenino.Train.GaugeBindingsTest do
  use Trenino.DataCase, async: true
  import Trenino.GaugeFixtures
  alias Trenino.{Hardware, Train}

  @points [%{value: 0, position: 0}, %{value: 100, position: 1890}]

  setup do
    {:ok, train} =
      Train.create_train(%{name: "Class 323", identifiers: [%{identifier: "Class323"}]})

    {:ok, device} = Hardware.create_device(%{name: "Speedometer"})
    %{train: train, device: device}
  end

  test "two trains share the gauge dial; enabling needs a reviewed dial", %{
    train: train,
    device: device
  } do
    {:ok, other} =
      Train.create_train(%{name: "Class 378", identifiers: [%{identifier: "Class378"}]})

    gauge = gauge_fixture(device.id)
    attrs = %{name: "Speed", endpoint: "Speed", gauge_id: gauge.id}

    assert {:ok, binding} = Train.create_gauge_binding(train.id, attrs)
    assert {:ok, _} = Train.create_gauge_binding(other.id, attrs)
    refute binding.enabled
    assert %{gauge: %{device: %{id: device_id}}} = binding
    assert device_id == device.id
    assert length(Train.list_gauge_bindings(train.id)) == 1
    # No dial recorded yet: nothing can be enabled.
    assert {:error, _} = Train.update_gauge_binding(binding, %{enabled: true})

    assert {:ok, _} = Hardware.save_dial_calibration(gauge, %{points: @points, reviewed: false})
    assert {:error, _} = Train.update_gauge_binding(binding, %{enabled: true})

    assert {:ok, _} = Hardware.save_dial_calibration(gauge, %{points: @points, reviewed: true})
    assert {:ok, enabled} = Train.update_gauge_binding(binding, %{enabled: true})
    assert enabled.enabled
    assert [%{id: id}] = Train.list_enabled_gauge_bindings(train.id)
    assert id == binding.id
    assert Train.list_enabled_gauge_bindings(other.id) == []
  end

  test "one binding per gauge per train", %{train: train, device: device} do
    gauge = gauge_fixture(device.id)
    attrs = %{name: "Speed", endpoint: "Speed", gauge_id: gauge.id}
    assert {:ok, _} = Train.create_gauge_binding(train.id, attrs)
    assert {:error, %Ecto.Changeset{}} = Train.create_gauge_binding(train.id, attrs)
  end

  test "saving an unreviewed dial disables the gauge's bindings", %{train: train, device: device} do
    gauge = calibrated_gauge_fixture(device.id)

    {:ok, binding} =
      Train.create_gauge_binding(train.id, %{
        name: "Speed",
        endpoint: "Speed",
        gauge_id: gauge.id,
        enabled: true
      })

    assert binding.enabled
    assert {:ok, _} = Hardware.save_dial_calibration(gauge, %{points: @points, reviewed: false})
    assert {:ok, %{enabled: false}} = Train.get_gauge_binding(binding.id)
  end

  test "changing what a step means clears the dial and disables bindings", %{
    train: train,
    device: device
  } do
    gauge = calibrated_gauge_fixture(device.id)

    {:ok, binding} =
      Train.create_gauge_binding(train.id, %{
        name: "Speed",
        endpoint: "Speed",
        gauge_id: gauge.id,
        enabled: true
      })

    # A rename keeps the dial and the binding.
    assert {:ok, gauge} = Hardware.update_gauge(gauge, %{name: "Speed dial"})
    assert {:ok, %{enabled: true}} = Train.get_gauge_binding(binding.id)

    assert {:ok, gauge} = Hardware.update_gauge(gauge, %{reverse: true})
    assert {:ok, %{enabled: false} = updated} = Train.get_gauge_binding(binding.id)
    assert updated.gauge.dial_calibration == nil
    assert {:error, _} = Train.update_gauge_binding(updated, %{enabled: true})

    assert {:ok, _} = Hardware.save_dial_calibration(gauge, %{points: @points, reviewed: true})
    assert {:ok, %{enabled: true}} = Train.update_gauge_binding(updated, %{enabled: true})
  end

  test "a travel too short for the dial clears it; one that still fits keeps it", %{
    train: train,
    device: device
  } do
    gauge = calibrated_gauge_fixture(device.id)

    {:ok, binding} =
      Train.create_gauge_binding(train.id, %{
        name: "Speed",
        endpoint: "Speed",
        gauge_id: gauge.id,
        enabled: true
      })

    assert {:ok, gauge} = Hardware.update_gauge(gauge, %{travel: 2000})
    assert {:ok, %{enabled: true}} = Train.get_gauge_binding(binding.id)

    assert {:ok, _} = Hardware.update_gauge(gauge, %{travel: 1000})
    assert {:ok, %{enabled: false} = updated} = Train.get_gauge_binding(binding.id)
    assert updated.gauge.dial_calibration == nil
  end

  test "lists the gauge bindings that drive one gauge, with their trains", %{
    train: train,
    device: device
  } do
    gauge = gauge_fixture(device.id)
    other = gauge_fixture(device.id, %{name: "Brake", pins: [5, 4, 6, 255]})

    assert Train.list_gauge_bindings_for_gauge(gauge.id) == []

    attrs = %{name: "Speed", endpoint: "Speed", gauge_id: gauge.id}
    assert {:ok, _} = Train.create_gauge_binding(train.id, attrs)

    assert [%{train: %{name: "Class 323"}}] = Train.list_gauge_bindings_for_gauge(gauge.id)
    assert Train.list_gauge_bindings_for_gauge(other.id) == []
  end
end
