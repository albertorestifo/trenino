defmodule Trenino.Serial.Protocol.ModuleErrorTest do
  use ExUnit.Case, async: true
  alias Trenino.Serial.Protocol.ModuleError

  test "encodes correctly" do
    msg = %ModuleError{i2c_address: 0x70, error_code: 0x01}
    assert {:ok, <<0x0F, 0x70, 0x01>>} = ModuleError.encode(msg)
  end

  test "returns error when fields are nil" do
    assert {:error, :invalid_fields} =
             ModuleError.encode(%ModuleError{i2c_address: nil, error_code: 1})

    assert {:error, :invalid_fields} =
             ModuleError.encode(%ModuleError{i2c_address: 0x70, error_code: nil})

    assert {:error, :invalid_fields} = ModuleError.encode(%ModuleError{})
  end

  test "decodes correctly" do
    assert {:ok, %ModuleError{i2c_address: 0x70, error_code: 0x01}} =
             ModuleError.decode_body(<<0x70, 0x01>>)
  end

  test "returns error for invalid body" do
    assert {:error, :invalid_message} = ModuleError.decode_body(<<0x70>>)
    assert {:error, :invalid_message} = ModuleError.decode_body(<<>>)
  end
end
