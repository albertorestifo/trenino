defmodule Trenino.Serial.Protocol.Configure do
  @moduledoc """
  Configuration message sent to device to configure an input.

  Protocol v2.0.0 - Discriminated union format:
  - Common header: [type=0x02][config_id:u32][total_parts:u8][part_number:u8][input_type:u8]
  - Analog payload (0x00): [pin:u8][sensitivity:u8]
  - Button payload (0x01): [pin:u8][debounce:u8]
  - Matrix payload (0x02): [num_row_pins:u8][num_col_pins:u8][row_pins...][col_pins...]
  - HT16K33 payload (0x04): [i2c_address:u8][brightness:u8][num_digits:u8]
  - MCP23017 payload (0x05): [i2c_address:u8][direct_base:u8][matrix_base:u8][debounce:u8]
    [direct_mask:u16le][row_mask:u16le][col_mask:u16le]
  - ADS1115 payload (0x06): [i2c_address:u8][pin_base:u8][channel_mask:u8][gain:u8]
    [ref_channel:u8][sensitivity:u8 x4]; ref_channel is 0xFF on the wire for none (nil in the struct)
  - Note: type ID 0x03 is reserved (BLDC, removed)
  """

  alias Trenino.Serial.Protocol.Message

  @behaviour Message

  @type input_type :: :analog | :button | :matrix | :ht16k33 | :mcp23017 | :ads1115 | :empty

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
          col_pins: [integer()] | nil,
          # HT16K33 fields
          i2c_address: integer() | nil,
          brightness: integer() | nil,
          num_digits: integer() | nil,
          # MCP23017 fields (also uses i2c_address, debounce)
          direct_base: integer() | nil,
          matrix_base: integer() | nil,
          direct_mask: integer() | nil,
          row_mask: integer() | nil,
          col_mask: integer() | nil,
          # ADS1115 fields (also uses i2c_address)
          pin_base: integer() | nil,
          channel_mask: integer() | nil,
          gain: integer() | nil,
          ref_channel: integer() | nil,
          sensitivities: [integer()] | nil
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
    :col_pins,
    :i2c_address,
    :brightness,
    :num_digits,
    :direct_base,
    :matrix_base,
    :direct_mask,
    :row_mask,
    :col_mask,
    :pin_base,
    :channel_mask,
    :gain,
    :ref_channel,
    :sensitivities
  ]

  # Encode - Analog (input_type = 0x00)
  @impl Message
  def encode(%__MODULE__{input_type: :empty, config_id: id, total_parts: 0, part_number: 0})
      when is_integer(id) and id in 0..0xFFFFFFFF,
      do: {:ok, <<2, id::little-32, 0, 0, 255>>}

  def encode(%__MODULE__{input_type: :empty}), do: {:error, :invalid_empty_configuration}

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

  # Encode - HT16K33 (input_type = 0x04)
  def encode(%__MODULE__{
        config_id: config_id,
        total_parts: total_parts,
        part_number: part_number,
        input_type: :ht16k33,
        i2c_address: i2c_address,
        brightness: brightness,
        num_digits: num_digits
      }) do
    {:ok,
     <<0x02, config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned,
       0x04::8-unsigned, i2c_address::8-unsigned, brightness::8-unsigned, num_digits::8-unsigned>>}
  end

  # Encode - MCP23017 (input_type = 0x05)
  def encode(%__MODULE__{
        config_id: config_id,
        total_parts: total_parts,
        part_number: part_number,
        input_type: :mcp23017,
        i2c_address: i2c_address,
        direct_base: direct_base,
        matrix_base: matrix_base,
        debounce: debounce,
        direct_mask: direct_mask,
        row_mask: row_mask,
        col_mask: col_mask
      }) do
    {:ok,
     <<0x02, config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned,
       0x05::8-unsigned, i2c_address::8-unsigned, direct_base::8-unsigned,
       matrix_base::8-unsigned, debounce::8-unsigned, direct_mask::little-16-unsigned,
       row_mask::little-16-unsigned, col_mask::little-16-unsigned>>}
  end

  # Encode - ADS1115 (input_type = 0x06)
  def encode(%__MODULE__{
        config_id: config_id,
        total_parts: total_parts,
        part_number: part_number,
        input_type: :ads1115,
        i2c_address: i2c_address,
        pin_base: pin_base,
        channel_mask: channel_mask,
        gain: gain,
        ref_channel: ref_channel,
        sensitivities: [s0, s1, s2, s3]
      }) do
    ref = if is_nil(ref_channel), do: 0xFF, else: ref_channel

    {:ok,
     <<0x02, config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned,
       0x06::8-unsigned, i2c_address::8-unsigned, pin_base::8-unsigned, channel_mask::8-unsigned,
       gain::8-unsigned, ref::8-unsigned, s0::8-unsigned, s1::8-unsigned, s2::8-unsigned,
       s3::8-unsigned>>}
  end

  # Decode body - Analog (input_type = 0x00)
  @impl Message
  def decode_body(<<id::little-32, 0, 0, 255>>),
    do: {:ok, %__MODULE__{config_id: id, total_parts: 0, part_number: 0, input_type: :empty}}

  def decode_body(
        <<config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned, 0x00,
          pin::8-unsigned, sensitivity::8-unsigned>>
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

  # Decode body - Button (input_type = 0x01)
  def decode_body(
        <<config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned, 0x01,
          pin::8-unsigned, debounce::8-unsigned>>
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

  # Decode body - Matrix (input_type = 0x02)
  def decode_body(
        <<config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned, 0x02,
          num_row_pins::8-unsigned, num_col_pins::8-unsigned, rest::binary>>
      ) do
    expected_size = num_row_pins + num_col_pins

    if byte_size(rest) == expected_size do
      <<row_pins_binary::binary-size(^num_row_pins), col_pins_binary::binary-size(^num_col_pins)>> =
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

  # Decode body - MCP23017 (input_type = 0x05)
  def decode_body(
        <<config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned, 0x05,
          i2c_address::8-unsigned, direct_base::8-unsigned, matrix_base::8-unsigned,
          debounce::8-unsigned, direct_mask::little-16-unsigned, row_mask::little-16-unsigned,
          col_mask::little-16-unsigned>>
      ) do
    {:ok,
     %__MODULE__{
       config_id: config_id,
       total_parts: total_parts,
       part_number: part_number,
       input_type: :mcp23017,
       i2c_address: i2c_address,
       direct_base: direct_base,
       matrix_base: matrix_base,
       debounce: debounce,
       direct_mask: direct_mask,
       row_mask: row_mask,
       col_mask: col_mask
     }}
  end

  # Decode body - ADS1115 (input_type = 0x06)
  def decode_body(
        <<config_id::little-32-unsigned, total_parts::8-unsigned, part_number::8-unsigned, 0x06,
          i2c_address::8-unsigned, pin_base::8-unsigned, channel_mask::8-unsigned,
          gain::8-unsigned, ref::8-unsigned, s0::8-unsigned, s1::8-unsigned, s2::8-unsigned,
          s3::8-unsigned>>
      ) do
    {:ok,
     %__MODULE__{
       config_id: config_id,
       total_parts: total_parts,
       part_number: part_number,
       input_type: :ads1115,
       i2c_address: i2c_address,
       pin_base: pin_base,
       channel_mask: channel_mask,
       gain: gain,
       ref_channel: if(ref == 0xFF, do: nil, else: ref),
       sensitivities: [s0, s1, s2, s3]
     }}
  end

  def decode_body(_), do: {:error, :invalid_message}
end
