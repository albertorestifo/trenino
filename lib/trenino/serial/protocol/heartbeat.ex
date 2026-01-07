defmodule Trenino.Serial.Protocol.Heartbeat do
  @moduledoc false

  alias Trenino.Serial.Protocol.Message

  @behaviour Message

  defstruct []

  @impl Message
  def encode(%__MODULE__{}) do
    {:ok, <<0x06>>}
  end

  @impl Message
  def decode_body(<<>>) do
    {:ok, %__MODULE__{}}
  end

  def decode_body(_), do: {:error, :invalid_message}
end
