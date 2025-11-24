defmodule TswIo.Serial.FramingTest do
  use ExUnit.Case, async: true

  alias TswIo.Serial.Framing

  test "COBS encoding examples from Wikipedia" do
    examples = [
      {<<0x00>>, <<0x01, 0x01, 0x00>>},
      {<<0x00, 0x00>>, <<0x01, 0x01, 0x01, 0x00>>},
      {<<0x00, 0x11, 0x00>>, <<0x01, 0x02, 0x11, 0x01, 0x00>>},
      {<<0x11, 0x22, 0x00, 0x33>>, <<0x03, 0x11, 0x22, 0x02, 0x33, 0x00>>},
      {<<0x11, 0x22, 0x33, 0x44>>, <<0x05, 0x11, 0x22, 0x33, 0x44, 0x00>>},
      {<<0x11, 0x00, 0x00, 0x00>>, <<0x02, 0x11, 0x01, 0x01, 0x01, 0x00>>}
    ]

    state = %Framing.State{}

    for {input, expected} <- examples do
      {:ok, encoded, _} = Framing.add_framing(input, state)
      assert encoded == expected, "Failed encoding #{inspect(input)}"

      {:ok, [decoded], _} = Framing.remove_framing(encoded, state)
      assert decoded == input, "Failed decoding #{inspect(encoded)}"
    end
  end

  test "COBS 254 non-zero bytes" do
    input = :binary.copy(<<0xAA>>, 254)
    {:ok, encoded, state} = Framing.add_framing(input, %Framing.State{})

    # With "append zero" strategy:
    # Input: D...D254 00
    # Block 1: D...D254 (254 bytes). Code FF.
    # Block 2: 00 (0 non-zero bytes). Code 01.
    # Delimiter: 00
    # Total: 1 (FF) + 254 + 1 (01) + 1 (00) = 257
    assert byte_size(encoded) == 1 + 254 + 1 + 1
    assert encoded == <<0xFF>> <> input <> <<0x01, 0x00>>

    {:ok, [decoded], _} = Framing.remove_framing(encoded, state)
    assert decoded == input
  end

  test "COBS 255 non-zero bytes" do
    input = :binary.copy(<<0xAA>>, 255)
    {:ok, encoded, state} = Framing.add_framing(input, %Framing.State{})

    # With "append zero" strategy:
    # Input: D...D255 00
    # Block 1: D...D254 (254 bytes). Code FF.
    # Block 2: D (1 byte) 00. Code 02.
    # Delimiter: 00
    # Total: 1 (FF) + 254 + 1 (02) + 1 (D) + 1 (00) = 258
    assert byte_size(encoded) == 1 + 254 + 1 + 1 + 1

    {:ok, [decoded], _} = Framing.remove_framing(encoded, state)
    assert decoded == input
  end

  test "Partial frames" do
    state = %Framing.State{}
    input = <<0x11, 0x22, 0x00, 0x33>>
    {:ok, encoded, _} = Framing.add_framing(input, state)

    <<part1::binary-size(3), part2::binary>> = encoded

    # Part 1 is incomplete, so we expect :in_frame
    {:in_frame, [], state1} = Framing.remove_framing(part1, state)

    # Part 2 completes it, buffer clears, so we expect :ok
    {:ok, [decoded], _state2} = Framing.remove_framing(part2, state1)

    assert decoded == input
  end

  test "returns :in_frame when partial data is buffered" do
    state = %Framing.State{}
    input = <<1, 2, 3>>
    {:ok, framed, _} = Framing.add_framing(input, state)

    # Send all but the last byte (the 0 delimiter)
    partial_len = byte_size(framed) - 1
    <<partial::binary-size(partial_len), _::binary>> = framed

    assert {:in_frame, [], %Framing.State{buffer: ^partial}} =
             Framing.remove_framing(partial, state)
  end

  test "returns :ok when frame is complete" do
    state = %Framing.State{}
    input = <<1, 2, 3>>
    {:ok, framed, _} = Framing.add_framing(input, state)

    assert {:ok, [^input], %Framing.State{buffer: <<>>}} = Framing.remove_framing(framed, state)
  end
end
