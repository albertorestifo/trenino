defmodule TswIo.Serial.Protocol.InputValue do
  alias TswIo.Serial.Protocol.Message

  @behaviour Message

  @type t() :: %__MODULE__{
          pin: integer(),
          value: integer()
        }

  defstruct [:pin, :value]

  @impl Message
  def type(), do: 0x05

  @impl Message
  def encode(%__MODULE__{pin: pin, value: value}) do
    {:ok, <<0x05, pin::8-unsigned, value::little-16-signed>>}
  end

  @impl Message
  def decode(<<0x05, pin::8-unsigned, value::little-16-signed>>) do
    {:ok, %__MODULE__{pin: pin, value: value}}
  end

  @impl Message
  def decode(_) do
    {:error, :invalid_message}
  end
end
