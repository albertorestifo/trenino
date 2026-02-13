defmodule Trenino.Serial.Protocol.DeactivateBLDCProfileTest do
  use ExUnit.Case, async: true

  alias Trenino.Serial.Protocol.DeactivateBLDCProfile

  describe "encode/1" do
    test "encodes valid message correctly" do
      message = %DeactivateBLDCProfile{pin: 10}
      {:ok, encoded} = DeactivateBLDCProfile.encode(message)

      # Type (0x0C) + pin (10)
      assert encoded == <<0x0C, 0x0A>>
    end

    test "encodes with pin 0" do
      message = %DeactivateBLDCProfile{pin: 0}
      {:ok, encoded} = DeactivateBLDCProfile.encode(message)

      assert encoded == <<0x0C, 0x00>>
    end

    test "encodes with pin 255" do
      message = %DeactivateBLDCProfile{pin: 255}
      {:ok, encoded} = DeactivateBLDCProfile.encode(message)

      assert encoded == <<0x0C, 0xFF>>
    end

    test "returns error for invalid pin (negative)" do
      message = %DeactivateBLDCProfile{pin: -1}
      assert {:error, :invalid_pin} = DeactivateBLDCProfile.encode(message)
    end

    test "returns error for invalid pin (too large)" do
      message = %DeactivateBLDCProfile{pin: 256}
      assert {:error, :invalid_pin} = DeactivateBLDCProfile.encode(message)
    end

    test "returns error for nil pin" do
      message = %DeactivateBLDCProfile{pin: nil}
      assert {:error, :invalid_pin} = DeactivateBLDCProfile.encode(message)
    end
  end

  describe "decode_body/1" do
    test "decodes valid message body" do
      body = <<0x0A>>
      {:ok, decoded} = DeactivateBLDCProfile.decode_body(body)

      assert decoded == %DeactivateBLDCProfile{pin: 10}
    end

    test "decodes pin 0" do
      body = <<0x00>>
      {:ok, decoded} = DeactivateBLDCProfile.decode_body(body)

      assert decoded == %DeactivateBLDCProfile{pin: 0}
    end

    test "decodes pin 255" do
      body = <<0xFF>>
      {:ok, decoded} = DeactivateBLDCProfile.decode_body(body)

      assert decoded == %DeactivateBLDCProfile{pin: 255}
    end

    test "returns error for incomplete message" do
      assert DeactivateBLDCProfile.decode_body(<<>>) == {:error, :invalid_message}
    end

    test "returns error for message with extra bytes" do
      assert DeactivateBLDCProfile.decode_body(<<0x0A, 0xFF>>) == {:error, :invalid_message}
    end
  end
end
