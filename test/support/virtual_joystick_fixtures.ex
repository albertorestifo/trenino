defmodule Trenino.VirtualJoystickFixtures do
  @moduledoc false

  alias Trenino.Hardware

  def device_fixture(attrs \\ %{}) do
    attrs = Enum.into(attrs, %{name: "Virtual joystick test device"})
    {:ok, device} = Hardware.create_device(attrs)
    device
  end

  def analog_input_fixture(attrs \\ %{}) do
    device = Map.get(attrs, :device) || device_fixture()

    input_attrs =
      attrs
      |> Map.drop([:device])
      |> Enum.into(%{pin: 1, input_type: :analog, sensitivity: 5})

    {:ok, input} = Hardware.create_input(device.id, input_attrs)

    {:ok, _calibration} =
      Hardware.save_calibration(input.id, %{
        min_value: 0,
        max_value: 1023,
        max_hardware_value: 1023
      })

    input
  end

  def button_input_fixture(attrs \\ %{}) do
    device = Map.get(attrs, :device) || device_fixture()

    input_attrs =
      attrs
      |> Map.drop([:device])
      |> Enum.into(%{pin: 2, input_type: :button, debounce: 50})

    {:ok, input} = Hardware.create_input(device.id, input_attrs)
    input
  end
end
