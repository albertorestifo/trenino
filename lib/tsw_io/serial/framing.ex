defmodule TswIo.Serial.Framing do
  @moduledoc """
  Framing for the serial port, using COBS (Consistent Overhead Byte Stuffing)
  """

  @behaviour Circuits.UART.Framing

  defmodule State do
    @moduledoc false
    defstruct buffer: <<>>, max_length: nil
  end

  @impl true
  def init(args) do
    max_length = Keyword.get(args, :max_length)
    {:ok, %State{max_length: max_length}}
  end

  @impl true
  def add_framing(data, state) do
    # Append a zero byte to the data before encoding to ensure proper COBS framing
    encoded = encode(data <> <<0>>)
    {:ok, encoded <> <<0>>, state}
  end

  @impl true
  def remove_framing(new_data, %State{buffer: buffer} = state) do
    combined = buffer <> new_data

    {frames, new_buffer} = process_buffer(combined, [])

    status = if byte_size(new_buffer) > 0, do: :in_frame, else: :ok
    {status, frames, %State{state | buffer: new_buffer}}
  end

  @impl true
  def flush(_direction, %State{} = state) do
    %State{state | buffer: <<>>}
  end

  @impl true
  def frame_timeout(state) do
    {:ok, [], state}
  end

  defp process_buffer(data, acc) do
    case :binary.split(data, <<0>>) do
      [rest] ->
        {Enum.reverse(acc), rest}

      [frame, rest] ->
        decoded =
          if frame == <<>> do
            nil
          else
            try do
              decoded_frame = decode(frame)
              # Remove the trailing zero that was added during encoding
              if byte_size(decoded_frame) > 0 do
                binary_part(decoded_frame, 0, byte_size(decoded_frame) - 1)
              else
                <<>>
              end
            rescue
              # Drop invalid frames
              _ -> nil
            end
          end

        new_acc = if decoded, do: [decoded | acc], else: acc
        process_buffer(rest, new_acc)
    end
  end

  # COBS Encoding
  defp encode(data) do
    encode_chunk(data, <<>>)
  end

  defp encode_chunk(<<>>, acc), do: acc

  defp encode_chunk(data, acc) do
    {block, rest, code} = find_zero_or_max(data, 0, 254, <<>>)
    new_acc = acc <> <<code, block::binary>>
    encode_chunk(rest, new_acc)
  end

  # Finds the next zero or consumes up to 254 bytes
  # Returns {block_data, remaining_data, code}
  defp find_zero_or_max(rest, count, max, acc) when count == max do
    # Code 255 (0xFF)
    {acc, rest, max + 1}
  end

  defp find_zero_or_max(<<0, rest::binary>>, count, _max, acc) do
    {acc, rest, count + 1}
  end

  defp find_zero_or_max(<<byte, rest::binary>>, count, max, acc) do
    find_zero_or_max(rest, count + 1, max, acc <> <<byte>>)
  end

  defp find_zero_or_max(<<>>, count, _max, acc) do
    {acc, <<>>, count + 1}
  end

  # COBS Decoding
  defp decode(data) do
    decode_chunk(data, <<>>)
  end

  defp decode_chunk(<<>>, acc), do: acc

  defp decode_chunk(<<code, rest::binary>>, acc) do
    if code == 0, do: raise(ArgumentError, "Invalid COBS code 0")

    len = code - 1

    if byte_size(rest) < len do
      raise ArgumentError, "Incomplete COBS frame"
    end

    <<block::binary-size(len), remaining::binary>> = rest

    new_acc = acc <> block

    # If code < 0xFF, it implies a zero, UNLESS it's the end of the packet
    # We simplified this to always append zero if code < 0xFF
    # because we rely on stripping the final zero at the top level.
    if code < 0xFF do
      decode_chunk(remaining, new_acc <> <<0>>)
    else
      decode_chunk(remaining, new_acc)
    end
  end
end
