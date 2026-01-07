defmodule Trenino.Serial.Protocol.ConfigurationStored do
  @moduledoc false

  alias Trenino.Serial.Protocol.Message

  @behaviour Message

  @type t() :: %__MODULE__{
          config_id: integer()
        }

  defstruct [:config_id]

  @impl Message
  def encode(%__MODULE__{config_id: config_id}) do
    {:ok, <<0x03, config_id::little-32-unsigned>>}
  end

  @impl Message
  def decode_body(<<config_id::little-32-unsigned>>) do
    {:ok, %__MODULE__{config_id: config_id}}
  end

  def decode_body(_), do: {:error, :invalid_message}
end
