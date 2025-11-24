defmodule TswIo.Serial.Protocol.Heartbeat do
  alias TswIo.Serial.Protocol.Message

  @behaviour Message

  defstruct []

  @impl Message
  def type(), do: 0x06

  @impl Message
  def encode(%__MODULE__{}) do
    {:ok, <<0x06>>}
  end

  @impl Message
  def decode(<<0x06>>) do
    {:ok, %__MODULE__{}}
  end

  @impl Message
  def decode(_) do
    {:error, :invalid_message}
  end
end
