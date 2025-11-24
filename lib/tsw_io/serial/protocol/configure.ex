defmodule TswIo.Serial.Protocol.Configure do
  alias TswIo.Serial.Protocol.Message

  @behaviour Message

  @type t() :: %__MODULE__{
          config_id: integer(),
          total_parts: integer(),
          part_number: integer(),
          input_type: integer(),
          pin: integer(),
          sensitivity: integer()
        }

  defstruct [:config_id, :total_parts, :part_number, :input_type, :pin, :sensitivity]

  @impl Message
  def type(), do: 0x02

  @impl Message
  def encode(%__MODULE__{
        config_id: config_id,
        total_parts: total_parts,
        part_number: part_number,
        input_type: input_type,
        pin: pin,
        sensitivity: sensitivity
      }) do
    {:ok,
     <<0x02, config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned,
       input_type::8-unsigned, pin::8-unsigned, sensitivity::8-unsigned>>}
  end

  @impl Message
  def decode(
        <<0x02, config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned,
          input_type::8-unsigned, pin::8-unsigned, sensitivity::8-unsigned>>
      ) do
    {:ok,
     %__MODULE__{
       config_id: config_id,
       total_parts: total_parts,
       part_number: part_number,
       input_type: input_type,
       pin: pin,
       sensitivity: sensitivity
     }}
  end

  @impl Message
  def decode(_) do
    {:error, :invalid_message}
  end
end
