defmodule Trenino.Hardware.InputLabelTest do
  use Trenino.DataCase, async: true

  alias Trenino.Hardware
  alias Trenino.Hardware.InputLabel

  setup do
    {:ok, device} = Hardware.create_device(%{name: "Label device"})
    %{device: device}
  end

  defp chip_inputs(mod) do
    mod |> Hardware.list_i2c_module_inputs() |> Enum.map(&Map.put(&1, :i2c_module, mod))
  end

  test "a board pin reads Pin N", %{device: device} do
    {:ok, input} = Hardware.create_input(device.id, %{pin: 3, input_type: :button, debounce: 5})
    assert InputLabel.pin(input) == "Pin 3"
  end

  test "MCP direct inputs and matrix cells carry the chip, address and channel", %{device: device} do
    {:ok, mod} =
      Hardware.create_i2c_module(device.id, %{
        module_chip: :mcp23017,
        i2c_address: 0x20,
        params: %{direct_mask: 0b1000, row_mask: 0x0100, col_mask: 0b11}
      })

    labels = mod |> chip_inputs() |> Enum.map(&InputLabel.pin/1)

    assert "MCP 0x20 GPA3" in labels
    assert "MCP 0x20 R0C0" in labels
    assert "MCP 0x20 R0C1" in labels
  end

  test "ADS inputs read ADS address AINn", %{device: device} do
    {:ok, mod} =
      Hardware.create_i2c_module(device.id, %{
        module_chip: :ads1115,
        i2c_address: 0x48,
        params: %{channel_mask: 0b0100, gain: 1, ref_channel: nil}
      })

    assert [label] = mod |> chip_inputs() |> Enum.map(&InputLabel.pin/1)
    assert label == "ADS 0x48 AIN2"
  end

  test "a chip input without its module loaded falls back to the virtual pin", %{device: device} do
    {:ok, mod} =
      Hardware.create_i2c_module(device.id, %{
        module_chip: :ads1115,
        i2c_address: 0x48,
        params: %{channel_mask: 0b0001, gain: 1, ref_channel: nil}
      })

    [input] = Hardware.list_i2c_module_inputs(mod)
    assert InputLabel.pin(input) == "Pin #{input.pin}"
  end
end
