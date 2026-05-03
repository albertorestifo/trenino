defmodule Trenino.Hardware.HT16K33 do
  @moduledoc """
  Segment encoder for the Holtek HT16K33 LED display driver.

  Supports both 14-segment and 7-segment displays. `encode_string/2` converts a
  UTF-8 string into raw segment bytes suitable for WriteSegments. Unknown
  characters are rendered as blank (all segments off).
  """

  alias Trenino.Hardware.HT16K33.Params
  import Bitwise

  # {low_byte, high_byte} per ASCII codepoint.
  # Source: Adafruit alphafonttable in Adafruit_LEDBackpack.cpp
  @seg14_table %{
    0x20 => <<0x00, 0x00>>,
    # space
    0x21 => <<0x06, 0x20>>,
    # !
    0x22 => <<0x20, 0x20>>,
    # "
    0x23 => <<0xCE, 0x12>>,
    # #
    0x24 => <<0xED, 0x12>>,
    # $
    0x25 => <<0x24, 0x0C>>,
    # %
    0x26 => <<0x9B, 0x01>>,
    # &
    0x27 => <<0x00, 0x02>>,
    # '
    0x28 => <<0x00, 0x0C>>,
    # (
    0x29 => <<0x00, 0x21>>,
    # )
    0x2A => <<0xC0, 0x3F>>,
    # *
    0x2B => <<0xC0, 0x12>>,
    # +
    0x2C => <<0x00, 0x20>>,
    # ,
    0x2D => <<0xC0, 0x00>>,
    # -
    0x2E => <<0x00, 0x40>>,
    # .
    0x2F => <<0x00, 0x0C>>,
    # /
    0x30 => <<0x3F, 0x12>>,
    # 0
    0x31 => <<0x06, 0x00>>,
    # 1
    0x32 => <<0xDB, 0x00>>,
    # 2
    0x33 => <<0xCF, 0x00>>,
    # 3
    0x34 => <<0xE6, 0x00>>,
    # 4
    0x35 => <<0xED, 0x00>>,
    # 5
    0x36 => <<0xFD, 0x00>>,
    # 6
    0x37 => <<0x07, 0x12>>,
    # 7
    0x38 => <<0xFF, 0x00>>,
    # 8
    0x39 => <<0xEF, 0x00>>,
    # 9
    0x3A => <<0x00, 0x12>>,
    # :
    0x3B => <<0x00, 0x22>>,
    # ;
    0x3C => <<0x00, 0x0C>>,
    # <
    0x3D => <<0xC8, 0x00>>,
    # =
    0x3E => <<0x00, 0x21>>,
    # >
    0x3F => <<0x83, 0x10>>,
    # ?
    0x40 => <<0xBB, 0x02>>,
    # @
    0x41 => <<0xF7, 0x00>>,
    # A
    0x42 => <<0x8F, 0x12>>,
    # B
    0x43 => <<0x39, 0x00>>,
    # C
    0x44 => <<0x0F, 0x12>>,
    # D
    0x45 => <<0xF9, 0x00>>,
    # E
    0x46 => <<0xF1, 0x00>>,
    # F
    0x47 => <<0xBD, 0x00>>,
    # G
    0x48 => <<0xF6, 0x00>>,
    # H
    0x49 => <<0x00, 0x12>>,
    # I
    0x4A => <<0x1E, 0x00>>,
    # J
    0x4B => <<0x70, 0x0C>>,
    # K
    0x4C => <<0x38, 0x00>>,
    # L
    0x4D => <<0x36, 0x05>>,
    # M
    0x4E => <<0x36, 0x09>>,
    # N
    0x4F => <<0x3F, 0x00>>,
    # O
    0x50 => <<0xF3, 0x00>>,
    # P
    0x51 => <<0x3F, 0x08>>,
    # Q
    0x52 => <<0xF3, 0x08>>,
    # R
    0x53 => <<0xED, 0x00>>,
    # S
    0x54 => <<0x01, 0x12>>,
    # T
    0x55 => <<0x3E, 0x00>>,
    # U
    0x56 => <<0x30, 0x06>>,
    # V
    0x57 => <<0x36, 0x28>>,
    # W
    0x58 => <<0x00, 0x2D>>,
    # X
    0x59 => <<0x00, 0x15>>,
    # Y
    0x5A => <<0x09, 0x0C>>,
    # Z
    0x5B => <<0x39, 0x00>>,
    # [
    0x5C => <<0x00, 0x09>>,
    # \
    0x5D => <<0x0F, 0x00>>,
    # ]
    0x5E => <<0x00, 0x06>>,
    # ^
    0x5F => <<0x08, 0x00>>,
    # _
    0x60 => <<0x00, 0x02>>,
    # `
    0x61 => <<0xFB, 0x00>>,
    # a
    0x62 => <<0xF8, 0x00>>,
    # b
    0x63 => <<0xD8, 0x00>>,
    # c
    0x64 => <<0xDE, 0x00>>,
    # d
    0x65 => <<0xFB, 0x00>>,
    # e
    0x66 => <<0xF1, 0x00>>,
    # f
    0x67 => <<0xEF, 0x00>>,
    # g
    0x68 => <<0xF4, 0x00>>,
    # h
    0x69 => <<0x00, 0x10>>,
    # i
    0x6A => <<0x0E, 0x00>>,
    # j
    0x6B => <<0x70, 0x0C>>,
    # k
    0x6C => <<0x30, 0x00>>,
    # l
    0x6D => <<0xD4, 0x00>>,
    # m
    0x6E => <<0xD4, 0x00>>,
    # n
    0x6F => <<0xDC, 0x00>>,
    # o
    0x70 => <<0xF3, 0x00>>,
    # p
    0x71 => <<0xE7, 0x00>>,
    # q
    0x72 => <<0xD0, 0x00>>,
    # r
    0x73 => <<0xED, 0x00>>,
    # s
    0x74 => <<0xF8, 0x00>>,
    # t
    0x75 => <<0x1C, 0x00>>,
    # u
    0x76 => <<0x30, 0x06>>,
    # v
    0x77 => <<0x36, 0x28>>,
    # w
    0x78 => <<0x00, 0x2D>>,
    # x
    0x79 => <<0x00, 0x15>>,
    # y
    0x7A => <<0x09, 0x0C>>
    # z
  }

  @blank_14 <<0x00, 0x00>>

  # 7-segment font table. Bits 0–6 = segments A–G, bit 7 = decimal point (DP).
  @seg7_table %{
    0x20 => 0x00,
    # space
    0x2D => 0x40,
    # -
    0x30 => 0x3F,
    # 0
    0x31 => 0x06,
    # 1
    0x32 => 0x5B,
    # 2
    0x33 => 0x4F,
    # 3
    0x34 => 0x66,
    # 4
    0x35 => 0x6D,
    # 5
    0x36 => 0x7D,
    # 6
    0x37 => 0x07,
    # 7
    0x38 => 0x7F,
    # 8
    0x39 => 0x6F,
    # 9
    0x41 => 0x77,
    # A
    0x42 => 0x7C,
    # b
    0x43 => 0x39,
    # C
    0x44 => 0x5E,
    # d
    0x45 => 0x79,
    # E
    0x46 => 0x71,
    # F
    0x48 => 0x76,
    # H
    0x4C => 0x38,
    # L
    0x4F => 0x3F,
    # O
    0x50 => 0x73,
    # P
    0x55 => 0x3E,
    # U
    0x61 => 0x77,
    # a
    0x62 => 0x7C,
    # b
    0x63 => 0x58,
    # c
    0x64 => 0x5E,
    # d
    0x65 => 0x7B,
    # e
    0x66 => 0x71,
    # f
    0x68 => 0x74,
    # h
    0x6C => 0x30,
    # l
    0x6E => 0x54,
    # n
    0x6F => 0x5C,
    # o
    0x72 => 0x50,
    # r
    0x74 => 0x78,
    # t
    0x75 => 0x1C
    # u
  }

  @blank_7 0x00

  @doc """
  Encode a string into raw HT16K33 segment bytes.

  For 14-segment displays, returns exactly `params.num_digits * 2` bytes.
  For 7-segment displays, returns exactly `params.num_digits` bytes.

  The string is truncated if too long and padded with blanks if too short.
  Characters not in the font table render as blank (all segments off).
  """
  @spec encode_string(String.t(), Params.t()) :: binary()
  def encode_string(text, %Params{display_type: :fourteen_segment} = params)
      when is_binary(text) do
    aligned = maybe_align_right(text, params.num_digits, params.align_right, params.has_dot)
    encode_14seg(aligned, params.num_digits)
  end

  def encode_string(text, %Params{display_type: :seven_segment} = params) when is_binary(text) do
    aligned = maybe_align_right(text, params.num_digits, params.align_right, params.has_dot)
    encode_7seg(aligned, params.num_digits, params.has_dot)
  end

  defp maybe_align_right(text, _num_digits, false, _has_dot), do: text

  defp maybe_align_right(text, num_digits, true, has_dot) do
    dot_count = if has_dot, do: text |> String.graphemes() |> Enum.count(&(&1 == ".")), else: 0
    effective_len = String.length(text) - dot_count

    if effective_len < num_digits do
      String.duplicate(" ", num_digits - effective_len) <> text
    else
      text
    end
  end

  defp encode_14seg(text, num_digits) do
    text
    |> String.to_charlist()
    |> Enum.take(num_digits)
    |> Enum.map(&Map.get(@seg14_table, &1, @blank_14))
    |> then(fn chars ->
      padding = List.duplicate(@blank_14, num_digits - length(chars))
      chars ++ padding
    end)
    |> IO.iodata_to_binary()
  end

  defp encode_7seg(text, num_digits, has_dot) do
    chars = String.to_charlist(text)

    {bytes, _} =
      Enum.reduce(chars, {[], num_digits}, fn char, {acc, remaining} ->
        accumulate_7seg_char(char, acc, remaining, has_dot)
      end)

    digit_bytes = Enum.reverse(bytes)
    padding = List.duplicate(@blank_7, num_digits - length(digit_bytes))
    :binary.list_to_bin(digit_bytes ++ padding)
  end

  defp accumulate_7seg_char(_char, acc, 0, _has_dot), do: {acc, 0}

  defp accumulate_7seg_char(0x2E, acc, remaining, true) do
    case acc do
      [] -> {[@blank_7 ||| 0x80], remaining - 1}
      [last | rest] -> {[last ||| 0x80 | rest], remaining}
    end
  end

  defp accumulate_7seg_char(0x2E, acc, remaining, false), do: {acc, remaining}

  defp accumulate_7seg_char(char, acc, remaining, _has_dot) do
    byte = Map.get(@seg7_table, char, @blank_7)
    {[byte | acc], remaining - 1}
  end
end
