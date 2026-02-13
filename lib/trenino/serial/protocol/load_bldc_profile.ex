defmodule Trenino.Serial.Protocol.LoadBLDCProfile do
  @moduledoc """
  LoadBLDCProfile message sent to device to configure a haptic profile for a BLDC motor.

  Protocol format:
  [type=0x0B][pin:u8][num_detents:u8][num_ranges:u8]
  [detent_data: 5 bytes × num_detents]
  [range_data: 3 bytes × num_ranges]

  Detent structure (5 bytes):
  - position: u8 (0-100, percentage of full rotation)
  - engagement: u8 (0-255, strength when entering detent)
  - hold: u8 (0-255, strength when in detent)
  - exit: u8 (0-255, strength when exiting detent)
  - spring_back: u8 (0-255, strength of spring-back to detent)

  Range structure (3 bytes):
  - start_detent: u8 (index of starting detent)
  - end_detent: u8 (index of ending detent)
  - damping: u8 (0-255, damping strength between detents)
  """

  alias Trenino.Serial.Protocol.Message

  @behaviour Message

  @type detent :: %{
          position: integer(),
          engagement: integer(),
          hold: integer(),
          exit: integer(),
          spring_back: integer()
        }

  @type range :: %{
          start_detent: integer(),
          end_detent: integer(),
          damping: integer()
        }

  @type t() :: %__MODULE__{
          pin: integer(),
          detents: [detent()],
          ranges: [range()]
        }

  defstruct [:pin, :detents, :ranges]

  @impl Message
  def encode(%__MODULE__{pin: pin, detents: detents, ranges: ranges})
      when is_integer(pin) and pin >= 0 and pin <= 255 and is_list(detents) and
             is_list(ranges) do
    with :ok <- validate_counts(detents, ranges),
         :ok <- validate_detents(detents),
         :ok <- validate_ranges(ranges) do
      num_detents = length(detents)
      num_ranges = length(ranges)

      detent_data = encode_detents(detents)
      range_data = encode_ranges(ranges)

      {:ok,
       <<0x0B, pin::8-unsigned, num_detents::8-unsigned, num_ranges::8-unsigned,
         detent_data::binary, range_data::binary>>}
    end
  end

  def encode(%__MODULE__{}), do: {:error, :invalid_pin}

  @impl Message
  def decode_body(<<pin::8-unsigned, num_detents::8-unsigned, num_ranges::8-unsigned, rest::binary>>) do
    detent_bytes = num_detents * 5
    range_bytes = num_ranges * 3
    expected_size = detent_bytes + range_bytes

    if byte_size(rest) == expected_size do
      <<detent_data::binary-size(detent_bytes), range_data::binary-size(range_bytes)>> = rest

      detents = decode_detents(detent_data, num_detents, [])
      ranges = decode_ranges(range_data, num_ranges, [])

      {:ok, %__MODULE__{pin: pin, detents: detents, ranges: ranges}}
    else
      {:error, :invalid_message}
    end
  end

  def decode_body(_), do: {:error, :invalid_message}

  # Private functions

  defp validate_counts(detents, ranges) do
    cond do
      length(detents) > 255 -> {:error, :too_many_detents}
      length(ranges) > 255 -> {:error, :too_many_ranges}
      true -> :ok
    end
  end

  defp validate_detents(detents) do
    Enum.reduce_while(detents, :ok, fn detent, :ok ->
      if valid_detent?(detent) do
        {:cont, :ok}
      else
        {:halt, {:error, :invalid_detent}}
      end
    end)
  end

  defp valid_detent?(%{
         position: pos,
         engagement: eng,
         hold: hold,
         exit: exit,
         spring_back: sb
       })
       when is_integer(pos) and pos >= 0 and pos <= 100 and is_integer(eng) and eng >= 0 and
              eng <= 255 and is_integer(hold) and hold >= 0 and hold <= 255 and is_integer(exit) and
              exit >= 0 and exit <= 255 and is_integer(sb) and sb >= 0 and sb <= 255 do
    true
  end

  defp valid_detent?(_), do: false

  defp validate_ranges(ranges) do
    Enum.reduce_while(ranges, :ok, fn range, :ok ->
      if valid_range?(range) do
        {:cont, :ok}
      else
        {:halt, {:error, :invalid_range}}
      end
    end)
  end

  defp valid_range?(%{start_detent: start, end_detent: end_d, damping: damp})
       when is_integer(start) and start >= 0 and start <= 255 and is_integer(end_d) and
              end_d >= 0 and end_d <= 255 and is_integer(damp) and damp >= 0 and damp <= 255 do
    true
  end

  defp valid_range?(_), do: false

  defp encode_detents(detents) do
    detents
    |> Enum.map(fn %{
                     position: pos,
                     engagement: eng,
                     hold: hold,
                     exit: exit,
                     spring_back: sb
                   } ->
      <<pos::8-unsigned, eng::8-unsigned, hold::8-unsigned, exit::8-unsigned,
        sb::8-unsigned>>
    end)
    |> IO.iodata_to_binary()
  end

  defp encode_ranges(ranges) do
    ranges
    |> Enum.map(fn %{start_detent: start, end_detent: end_d, damping: damp} ->
      <<start::8-unsigned, end_d::8-unsigned, damp::8-unsigned>>
    end)
    |> IO.iodata_to_binary()
  end

  defp decode_detents(<<>>, 0, acc), do: Enum.reverse(acc)

  defp decode_detents(
         <<pos::8-unsigned, eng::8-unsigned, hold::8-unsigned, exit::8-unsigned,
           sb::8-unsigned, rest::binary>>,
         count,
         acc
       )
       when count > 0 do
    detent = %{
      position: pos,
      engagement: eng,
      hold: hold,
      exit: exit,
      spring_back: sb
    }

    decode_detents(rest, count - 1, [detent | acc])
  end

  defp decode_ranges(<<>>, 0, acc), do: Enum.reverse(acc)

  defp decode_ranges(
         <<start::8-unsigned, end_d::8-unsigned, damp::8-unsigned, rest::binary>>,
         count,
         acc
       )
       when count > 0 do
    range = %{
      start_detent: start,
      end_detent: end_d,
      damping: damp
    }

    decode_ranges(rest, count - 1, [range | acc])
  end
end
