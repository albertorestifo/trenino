defmodule Trenino.Serial.Protocol.IdentityRequest do
  alias Trenino.Serial.Protocol.Message

  @behaviour Message

  @type t() :: %__MODULE__{
          request_id: integer()
        }

  defstruct [:request_id]

  @impl Message
  def type(), do: 0x00

  @impl Message
  def encode(%__MODULE__{request_id: request_id}) do
    {:ok, <<0x00, request_id::little-32-unsigned>>}
  end

  @impl Message
  def decode(<<0x00, request_id::little-32-unsigned>>) do
    {:ok, %__MODULE__{request_id: request_id}}
  end

  @impl Message
  def decode(_) do
    {:error, :invalid_message}
  end
end
