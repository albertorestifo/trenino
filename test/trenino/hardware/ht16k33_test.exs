defmodule Trenino.Hardware.HT16K33Test do
  use ExUnit.Case, async: true
  alias Trenino.Hardware.HT16K33

  test "encodes a single known digit" do
    # '0' = low:0x3F high:0x12, padded to 4 digits
    result = HT16K33.encode_string("0", 4)
    assert byte_size(result) == 8
    assert <<0x3F, 0x12, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>> = result
  end

  test "pads with spaces to num_digits" do
    # "1" on a 4-digit display: '1' then 3 spaces
    result = HT16K33.encode_string("1", 4)
    assert byte_size(result) == 8
    assert <<0x06, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>> = result
  end

  test "truncates to num_digits" do
    result = HT16K33.encode_string("12345", 4)
    assert byte_size(result) == 8
    # First 4 chars: '1','2','3','4'
    assert <<0x06, 0x10, 0xDB, 0x00, _::binary>> = result
  end

  test "unknown character renders as space" do
    result = HT16K33.encode_string("~", 4)
    assert <<0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>> = result
  end

  test "encodes '-'" do
    result = HT16K33.encode_string("-", 4)
    assert <<0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>> = result
  end

  test "output is always num_digits * 2 bytes" do
    for n <- [4, 8] do
      result = HT16K33.encode_string("", n)
      assert byte_size(result) == n * 2
    end
  end
end
