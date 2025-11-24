defmodule TswIo.Serial.Protocol.IdentityResponse do
  alias TswIo.Serial.Protocol.Message

  @behaviour Message

  @type t() :: %__MODULE__{
          request_id: integer(),
          version: integer(),
          device_id: integer(),
          config_id: integer()
        }

  defstruct [:request_id, :version, :device_id, :config_id]

  @impl Message
  def type(), do: 0x01

  @impl Message
  def encode(%__MODULE__{
        request_id: request_id,
        version: version,
        device_id: device_id,
        config_id: config_id
      }) do
    {:ok,
     <<0x01, request_id::little-32-unsigned, version::8-unsigned, device_id::8-unsigned,
       config_id::little-32-unsigned>>}
  end

  @impl Message
  def decode(
        <<0x01, request_id::little-32-unsigned, version::8-unsigned, device_id::8-unsigned,
          config_id::little-32-unsigned>>
      ) do
    {:ok,
     %__MODULE__{
       request_id: request_id,
       version: version,
       device_id: device_id,
       config_id: config_id
     }}
  end

  @impl Message
  def decode(_) do
    {:error, :invalid_message}
  end
end
