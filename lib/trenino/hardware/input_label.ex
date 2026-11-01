defmodule Trenino.Hardware.InputLabel do
  @moduledoc """
  Human-readable pin labels for inputs.

  A pin on the board reads `"Pin 3"`. A chip input reads with its chip and
  channel instead, for example `"MCP 0x20 GPA3"`, `"MCP 0x20 R0C1"` or
  `"ADS 0x48 AIN2"`. Chip inputs need `:i2c_module` preloaded; without it the
  label falls back to the virtual pin number.
  """

  alias Trenino.Hardware.I2cInputs
  alias Trenino.Hardware.I2cModule
  alias Trenino.Hardware.Input

  @doc "The pin label for an input."
  @spec pin(Input.t()) :: String.t()
  def pin(%Input{i2c_module: %I2cModule{} = mod, i2c_channel: channel} = input)
      when is_integer(channel) do
    case channel_name(mod, channel) do
      nil -> "Pin #{input.pin}"
      name -> "#{module(mod)} #{name}"
    end
  end

  def pin(%Input{pin: pin}), do: "Pin #{pin}"

  @doc "The chip and address of a module, for example MCP 0x20."
  @spec module(I2cModule.t()) :: String.t()
  def module(%I2cModule{} = mod), do: "#{chip_prefix(mod.module_chip)} #{hex(mod.i2c_address)}"

  @doc "MCP23017 pin names for the set bits of a mask, in order (GPA0 to GPB7)."
  @spec gpio_names(non_neg_integer()) :: [String.t()]
  def gpio_names(mask) when is_integer(mask) do
    for bit <- 0..15, Bitwise.band(mask, Bitwise.bsl(1, bit)) != 0, do: gpio(bit)
  end

  defp gpio(bit) when bit < 8, do: "GPA#{bit}"
  defp gpio(bit), do: "GPB#{bit - 8}"

  defp channel_name(%I2cModule{} = mod, channel) do
    mod
    |> I2cInputs.children()
    |> Enum.find_value(fn child -> child.i2c_channel == channel && child.name end)
  end

  defp chip_prefix(:mcp23017), do: "MCP"
  defp chip_prefix(:ads1115), do: "ADS"
  defp chip_prefix(chip), do: chip |> Atom.to_string() |> String.upcase()

  defp hex(address), do: "0x" <> String.upcase(Integer.to_string(address, 16))
end
