defmodule Trenino.Serial.Protocol.SetModuleBrightnessTest do
  use ExUnit.Case, async: true
  alias Trenino.Serial.Protocol.SetModuleBrightness

  test "encodes correctly" do
    msg = %SetModuleBrightness{i2c_address: 0x70, brightness: 8}
    assert {:ok, <<0x0E, 0x70, 8>>} = SetModuleBrightness.encode(msg)
  end

  test "encodes correctly at brightness boundary values" do
    assert {:ok, <<0x0E, 0x70, 0>>} =
             SetModuleBrightness.encode(%SetModuleBrightness{i2c_address: 0x70, brightness: 0})

    assert {:ok, <<0x0E, 0x70, 15>>} =
             SetModuleBrightness.encode(%SetModuleBrightness{i2c_address: 0x70, brightness: 15})
  end

  test "returns error when brightness exceeds 15" do
    msg = %SetModuleBrightness{i2c_address: 0x70, brightness: 16}
    assert {:error, :invalid_brightness} = SetModuleBrightness.encode(msg)
  end

  test "returns error when brightness is nil" do
    msg = %SetModuleBrightness{i2c_address: 0x70, brightness: nil}
    assert {:error, :invalid_brightness} = SetModuleBrightness.encode(msg)
  end

  test "decodes correctly" do
    assert {:ok, %SetModuleBrightness{i2c_address: 0x70, brightness: 8}} =
             SetModuleBrightness.decode_body(<<0x70, 8>>)
  end

  test "returns error when decoded brightness exceeds 15" do
    assert {:error, :invalid_message} = SetModuleBrightness.decode_body(<<0x70, 16>>)
  end
end
