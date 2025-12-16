defmodule TswIo.Serial.Protocol.Configure do
  @moduledoc """
  Configuration message sent to device to configure an input.

  Protocol v2.0.0 - Discriminated union format:
  - Common header: [type=0x02][config_id:u32][total_parts:u8][part_number:u8][input_type:u8]
  - Analog payload: [pin:u8][sensitivity:u8]
  - Button payload: [pin:u8][debounce:u8]
  - Matrix payload: [num_row_pins:u8][num_col_pins:u8][row_pins...][col_pins...]
  """

  alias TswIo.Serial.Protocol.Message

  @behaviour Message

  @type input_type :: :analog | :button | :matrix

  @type t() :: %__MODULE__{
          config_id: integer(),
          total_parts: integer(),
          part_number: integer(),
          input_type: input_type(),
          # Analog/Button fields
          pin: integer() | nil,
          sensitivity: integer() | nil,
          debounce: integer() | nil,
          # Matrix fields
          row_pins: [integer()] | nil,
          col_pins: [integer()] | nil
        }

  defstruct [
    :config_id,
    :total_parts,
    :part_number,
    :input_type,
    :pin,
    :sensitivity,
    :debounce,
    :row_pins,
    :col_pins
  ]

  @impl Message
  def type(), do: 0x02

  # Encode - Analog (input_type = 0x00)
  @impl Message
  def encode(%__MODULE__{
        config_id: config_id,
        total_parts: total_parts,
        part_number: part_number,
        input_type: :analog,
        pin: pin,
        sensitivity: sensitivity
      }) do
    {:ok,
     <<0x02, config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned,
       0x00::8-unsigned, pin::8-unsigned, sensitivity::8-unsigned>>}
  end

  # Encode - Button (input_type = 0x01)
  def encode(%__MODULE__{
        config_id: config_id,
        total_parts: total_parts,
        part_number: part_number,
        input_type: :button,
        pin: pin,
        debounce: debounce
      }) do
    {:ok,
     <<0x02, config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned,
       0x01::8-unsigned, pin::8-unsigned, debounce::8-unsigned>>}
  end

  # Encode - Matrix (input_type = 0x02)
  def encode(%__MODULE__{
        config_id: config_id,
        total_parts: total_parts,
        part_number: part_number,
        input_type: :matrix,
        row_pins: row_pins,
        col_pins: col_pins
      })
      when is_list(row_pins) and is_list(col_pins) do
    num_row_pins = length(row_pins)
    num_col_pins = length(col_pins)
    row_pins_binary = :binary.list_to_bin(row_pins)
    col_pins_binary = :binary.list_to_bin(col_pins)

    {:ok,
     <<0x02, config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned,
       0x02::8-unsigned, num_row_pins::8-unsigned, num_col_pins::8-unsigned,
       row_pins_binary::binary, col_pins_binary::binary>>}
  end

  # Decode - Analog (input_type = 0x00)
  @impl Message
  def decode(
        <<0x02, config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned,
          0x00, pin::8-unsigned, sensitivity::8-unsigned>>
      ) do
    {:ok,
     %__MODULE__{
       config_id: config_id,
       total_parts: total_parts,
       part_number: part_number,
       input_type: :analog,
       pin: pin,
       sensitivity: sensitivity
     }}
  end

  # Decode - Button (input_type = 0x01)
  def decode(
        <<0x02, config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned,
          0x01, pin::8-unsigned, debounce::8-unsigned>>
      ) do
    {:ok,
     %__MODULE__{
       config_id: config_id,
       total_parts: total_parts,
       part_number: part_number,
       input_type: :button,
       pin: pin,
       debounce: debounce
     }}
  end

  # Decode - Matrix (input_type = 0x02)
  def decode(
        <<0x02, config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned,
          0x02, num_row_pins::8-unsigned, num_col_pins::8-unsigned, rest::binary>>
      ) do
    expected_size = num_row_pins + num_col_pins

    if byte_size(rest) == expected_size do
      <<row_pins_binary::binary-size(num_row_pins), col_pins_binary::binary-size(num_col_pins)>> =
        rest

      row_pins = :binary.bin_to_list(row_pins_binary)
      col_pins = :binary.bin_to_list(col_pins_binary)

      {:ok,
       %__MODULE__{
         config_id: config_id,
         total_parts: total_parts,
         part_number: part_number,
         input_type: :matrix,
         row_pins: row_pins,
         col_pins: col_pins
       }}
    else
      {:error, :invalid_message}
    end
  end

  @impl Message
  def decode(_) do
    {:error, :invalid_message}
  end
end
