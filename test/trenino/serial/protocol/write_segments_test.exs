defmodule Trenino.Serial.Protocol.WriteSegmentsTest do
  use ExUnit.Case, async: true
  alias Trenino.Serial.Protocol.WriteSegments

  test "encodes correctly" do
    msg = %WriteSegments{i2c_address: 0x70, data: <<0x3F, 0x12, 0x06, 0x10>>}
    assert {:ok, <<0x0D, 0x70, 4, 0x3F, 0x12, 0x06, 0x10>>} = WriteSegments.encode(msg)
  end

  test "returns error for data longer than 16 bytes" do
    msg = %WriteSegments{i2c_address: 0x70, data: :binary.copy(<<0>>, 17)}
    assert {:error, :data_too_long} = WriteSegments.encode(msg)
  end

  test "decodes correctly" do
    assert {:ok, %WriteSegments{i2c_address: 0x70, data: <<0x3F, 0x12>>}} =
             WriteSegments.decode_body(<<0x70, 2, 0x3F, 0x12>>)
  end
end
