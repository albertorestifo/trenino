defmodule Trenino.Serial.Protocol.RetryCalibrationTest do
  use ExUnit.Case, async: true

  alias Trenino.Serial.Protocol.RetryCalibration

  describe "encode/1" do
    test "encodes valid message correctly" do
      message = %RetryCalibration{pin: 5}
      {:ok, encoded} = RetryCalibration.encode(message)

      # Type (0x08) + pin (5)
      assert encoded == <<0x08, 0x05>>
    end

    test "encodes with pin 0" do
      message = %RetryCalibration{pin: 0}
      {:ok, encoded} = RetryCalibration.encode(message)

      assert encoded == <<0x08, 0x00>>
    end

    test "encodes with pin 255" do
      message = %RetryCalibration{pin: 255}
      {:ok, encoded} = RetryCalibration.encode(message)

      assert encoded == <<0x08, 0xFF>>
    end

    test "returns error for invalid pin (negative)" do
      message = %RetryCalibration{pin: -1}
      assert {:error, :invalid_pin} = RetryCalibration.encode(message)
    end

    test "returns error for invalid pin (too large)" do
      message = %RetryCalibration{pin: 256}
      assert {:error, :invalid_pin} = RetryCalibration.encode(message)
    end

    test "returns error for nil pin" do
      message = %RetryCalibration{pin: nil}
      assert {:error, :invalid_pin} = RetryCalibration.encode(message)
    end
  end

  describe "decode_body/1" do
    test "decodes valid message body" do
      body = <<0x05>>
      {:ok, decoded} = RetryCalibration.decode_body(body)

      assert decoded == %RetryCalibration{pin: 5}
    end

    test "decodes pin 0" do
      body = <<0x00>>
      {:ok, decoded} = RetryCalibration.decode_body(body)

      assert decoded == %RetryCalibration{pin: 0}
    end

    test "decodes pin 255" do
      body = <<0xFF>>
      {:ok, decoded} = RetryCalibration.decode_body(body)

      assert decoded == %RetryCalibration{pin: 255}
    end

    test "returns error for incomplete message" do
      assert RetryCalibration.decode_body(<<>>) == {:error, :invalid_message}
    end

    test "returns error for message with extra bytes" do
      assert RetryCalibration.decode_body(<<0x05, 0xFF>>) == {:error, :invalid_message}
    end
  end
end
