defmodule Trenino.Serial.Protocol.ModuleError do
  @moduledoc "ModuleError (0x0F) — Device → Host. Sent after ConfigurationStored for each I2C module that failed init."

  alias Trenino.Serial.Protocol.Message

  @behaviour Message

  @type t :: %__MODULE__{i2c_address: integer(), error_code: integer()}
  defstruct [:i2c_address, :error_code]

  @impl Message
  def encode(%__MODULE__{i2c_address: addr, error_code: code}) do
    {:ok, <<0x0F, addr::8-unsigned, code::8-unsigned>>}
  end

  @impl Message
  def decode_body(<<addr::8-unsigned, code::8-unsigned>>) do
    {:ok, %__MODULE__{i2c_address: addr, error_code: code}}
  end

  def decode_body(_), do: {:error, :invalid_message}
end
