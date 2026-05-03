defmodule Trenino.Serial.Protocol.WriteSegments do
  @moduledoc "WriteSegments (0x0D) — Host → Device. Write raw segment bytes to an I2C display."

  alias Trenino.Serial.Protocol.Message

  @behaviour Message

  @type t :: %__MODULE__{i2c_address: integer(), data: binary()}
  defstruct [:i2c_address, :data]

  @impl Message
  def encode(%__MODULE__{i2c_address: addr, data: data}) when byte_size(data) <= 16 do
    {:ok, <<0x0D, addr::8-unsigned, byte_size(data)::8-unsigned, data::binary>>}
  end

  def encode(%__MODULE__{}), do: {:error, :data_too_long}

  @impl Message
  def decode_body(<<addr::8-unsigned, num_bytes::8-unsigned, data::binary-size(num_bytes)>>) do
    {:ok, %__MODULE__{i2c_address: addr, data: data}}
  end

  def decode_body(_), do: {:error, :invalid_message}
end
