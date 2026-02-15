defmodule Trenino.Serial.Protocol.LoadBLDCProfile do
  @moduledoc """
  LoadBLDCProfile message sent to device to configure a haptic profile for a BLDC motor.

  Protocol format:
  [type=0x0B][pin:u8][num_detents:u8][num_ranges:u8][snap_point:u8][endstop_strength:u8]
  [detent_data: 2 bytes × num_detents]
  [range_data: 3 bytes × num_ranges]

  Detent structure (2 bytes):
  - position: u8 (0-100, percentage of full rotation)
  - detent_strength: u8 (0-255, strength of detent)

  Range structure (3 bytes):
  - start_detent: u8 (index of starting detent)
  - end_detent: u8 (index of ending detent)
  - damping: u8 (0-255, damping strength between detents)
  """

  alias Trenino.Serial.Protocol.Message

  @behaviour Message

  @type detent :: %{
          position: integer(),
          detent_strength: integer()
        }

  @type range :: %{
          start_detent: integer(),
          end_detent: integer(),
          damping: integer()
        }

  @type t() :: %__MODULE__{
          pin: integer(),
          snap_point: integer(),
          endstop_strength: integer(),
          detents: [detent()],
          ranges: [range()]
        }

  defstruct [:pin, :snap_point, :endstop_strength, :detents, :ranges]

  @impl Message
  def encode(%__MODULE__{
        pin: pin,
        snap_point: snap_point,
        endstop_strength: endstop_strength,
        detents: detents,
        ranges: ranges
      })
      when is_integer(pin) and pin >= 0 and pin <= 255 and
             is_integer(snap_point) and snap_point >= 50 and snap_point <= 150 and
             is_integer(endstop_strength) and endstop_strength >= 0 and endstop_strength <= 255 and
             is_list(detents) and is_list(ranges) do
    with :ok <- validate_counts(detents, ranges),
         :ok <- validate_detents(detents),
         :ok <- validate_ranges(ranges) do
      num_detents = length(detents)
      num_ranges = length(ranges)

      detent_data = encode_detents(detents)
      range_data = encode_ranges(ranges)

      {:ok,
       <<0x0B, pin::8-unsigned, num_detents::8-unsigned, num_ranges::8-unsigned,
         snap_point::8-unsigned, endstop_strength::8-unsigned, detent_data::binary,
         range_data::binary>>}
    end
  end

  def encode(%__MODULE__{snap_point: sp, endstop_strength: es})
      when not is_integer(sp) or sp < 50 or sp > 150 or
             not is_integer(es) or es < 0 or es > 255 do
    {:error, :invalid_profile_params}
  end

  def encode(%__MODULE__{}), do: {:error, :invalid_pin}

  @impl Message
  def decode_body(
        <<pin::8-unsigned, num_detents::8-unsigned, num_ranges::8-unsigned,
          snap_point::8-unsigned, endstop_strength::8-unsigned, rest::binary>>
      ) do
    detent_bytes = num_detents * 2
    range_bytes = num_ranges * 3
    expected_size = detent_bytes + range_bytes

    if byte_size(rest) == expected_size do
      <<detent_data::binary-size(detent_bytes), range_data::binary-size(range_bytes)>> = rest

      detents = decode_detents(detent_data, num_detents, [])
      ranges = decode_ranges(range_data, num_ranges, [])

      {:ok,
       %__MODULE__{
         pin: pin,
         snap_point: snap_point,
         endstop_strength: endstop_strength,
         detents: detents,
         ranges: ranges
       }}
    else
      {:error, :invalid_message}
    end
  end

  def decode_body(_), do: {:error, :invalid_message}

  # Private functions

  defguardp is_byte(v) when is_integer(v) and v >= 0 and v <= 255

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

  defp valid_detent?(%{position: pos, detent_strength: ds})
       when is_integer(pos) and pos >= 0 and pos <= 100 and is_byte(ds) do
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
    |> Enum.map(fn %{position: pos, detent_strength: ds} ->
      <<pos::8-unsigned, ds::8-unsigned>>
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
         <<pos::8-unsigned, ds::8-unsigned, rest::binary>>,
         count,
         acc
       )
       when count > 0 do
    detent = %{
      position: pos,
      detent_strength: ds
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
