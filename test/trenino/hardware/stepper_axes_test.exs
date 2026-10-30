defmodule Trenino.Hardware.StepperAxesTest do
  use Trenino.DataCase, async: true
  alias Trenino.Hardware

  test "persistent two axes share one shield and distinct ports" do
    {:ok, device} = Hardware.create_device(%{name: "Gauge"})

    assert {:ok, a} =
             Hardware.create_stepper_axis(device.id, %{name: "Speed", shield_address: "0x60"})

    assert a.shield_address == 96

    assert {:ok, _} =
             Hardware.create_stepper_axis(device.id, %{
               name: "Current",
               axis_index: 1,
               motor_port: 2
             })

    assert {:error, _} = Hardware.create_stepper_axis(device.id, %{name: "Third", axis_index: 2})

    assert {:error, _} =
             Hardware.create_stepper_axis(device.id, %{
               name: "Duplicate",
               axis_index: 1,
               motor_port: 1
             })

    assert {:error, _} = Hardware.update_stepper_axis(a, %{shield_address: 97})
    assert length(Hardware.list_stepper_axes(device.id)) == 2
    assert {:ok, _} = Hardware.delete_stepper_axis(a)
    assert {:error, :not_found} = Hardware.get_stepper_axis(a.id)
  end

  test "foreign device rejected" do
    assert {:error, _} = Hardware.create_stepper_axis(-1, %{name: "Unknown"})
  end

  test "a display cannot later claim the shield address" do
    {:ok, device} = Hardware.create_device(%{name: "Shared bus"})
    {:ok, _} = Hardware.create_stepper_axis(device.id, %{name: "Speed", shield_address: 112})

    assert {:error, cs} =
             Hardware.create_i2c_module(device.id, %{
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

    assert Keyword.has_key?(cs.errors, :i2c_address)
  end
end
