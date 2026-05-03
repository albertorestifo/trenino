defmodule Trenino.Serial.Protocol.SetModuleBrightness do
  @moduledoc "SetModuleBrightness (0x0E) — Host → Device. Set brightness on an I2C display module."

  alias Trenino.Serial.Protocol.Message

  @behaviour Message

  @type t :: %__MODULE__{i2c_address: integer(), brightness: integer()}
  defstruct [:i2c_address, :brightness]

  @impl Message
  def encode(%__MODULE__{i2c_address: addr, brightness: b}) when b in 0..15 do
    {:ok, <<0x0E, addr::8-unsigned, b::8-unsigned>>}
  end

  def encode(%__MODULE__{}), do: {:error, :invalid_brightness}

  @impl Message
  def decode_body(<<addr::8-unsigned, b::8-unsigned>>) when b in 0..15 do
    {:ok, %__MODULE__{i2c_address: addr, brightness: b}}
  end

  def decode_body(_), do: {:error, :invalid_message}
end
