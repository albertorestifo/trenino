defmodule Trenino.Serial.ProtocolTest do
  use ExUnit.Case, async: true

  alias Trenino.Serial.Protocol.{
    IdentityRequest,
    IdentityResponse,
    Configure,
    ConfigurationStored,
    ConfigurationError,
    InputValue,
    Heartbeat,
    SetOutput
  }

  describe "IdentityRequest" do
    test "type returns 0x00" do
      assert IdentityRequest.type() == 0x00
    end

    test "encode encodes request_id correctly" do
      request = %IdentityRequest{request_id: 0x12345678}
      {:ok, encoded} = IdentityRequest.encode(request)

      # Type (0x00) + request_id (0x12345678 little endian)
      assert encoded == <<0x00, 0x78, 0x56, 0x34, 0x12>>
    end

    test "decode decodes valid message" do
      # Type (0x00) + request_id (0x12345678 little endian)
      binary = <<0x00, 0x78, 0x56, 0x34, 0x12>>
      {:ok, decoded} = IdentityRequest.decode(binary)

      assert decoded == %IdentityRequest{request_id: 0x12345678}
    end

    test "decode returns error for invalid message type" do
      assert IdentityRequest.decode(<<0x01, 0x78, 0x56, 0x34, 0x12>>) ==
               {:error, :invalid_message}
    end

    test "decode returns error for incomplete message" do
      assert IdentityRequest.decode(<<0x00, 0x78, 0x56>>) == {:error, :invalid_message}
    end

    test "roundtrip encode/decode" do
      original = %IdentityRequest{request_id: 0xDEADBEEF}
      {:ok, encoded} = IdentityRequest.encode(original)
      {:ok, decoded} = IdentityRequest.decode(encoded)

      assert decoded == original
    end
  end

  describe "IdentityResponse" do
    test "type returns 0x01" do
      assert IdentityResponse.type() == 0x01
    end

    test "encode encodes all fields correctly" do
      response = %IdentityResponse{
        request_id: 0x12345678,
        version: "1.2.3",
        config_id: 0xDEADBEEF
      }

      {:ok, encoded} = IdentityResponse.encode(response)

      # Type (0x01) + request_id (little endian) + major + minor + patch + config_id (little endian)
      assert encoded == <<0x01, 0x78, 0x56, 0x34, 0x12, 0x01, 0x02, 0x03, 0xEF, 0xBE, 0xAD, 0xDE>>
    end

    test "decode decodes valid message" do
      binary = <<0x01, 0x78, 0x56, 0x34, 0x12, 0x01, 0x02, 0x03, 0xEF, 0xBE, 0xAD, 0xDE>>
      {:ok, decoded} = IdentityResponse.decode(binary)

      assert decoded == %IdentityResponse{
               request_id: 0x12345678,
               version: "1.2.3",
               config_id: 0xDEADBEEF
             }
    end

    test "decode returns error for invalid message type" do
      assert IdentityResponse.decode(
               <<0x00, 0x78, 0x56, 0x34, 0x12, 0x01, 0x02, 0x03, 0xEF, 0xBE, 0xAD, 0xDE>>
             ) == {:error, :invalid_message}
    end

    test "decode returns error for incomplete message" do
      assert IdentityResponse.decode(<<0x01, 0x78, 0x56>>) == {:error, :invalid_message}
    end

    test "roundtrip encode/decode" do
      original = %IdentityResponse{
        request_id: 0x12345678,
        version: "1.2.3",
        config_id: 0xDEADBEEF
      }

      {:ok, encoded} = IdentityResponse.encode(original)
      {:ok, decoded} = IdentityResponse.decode(encoded)

      assert decoded == original
    end
  end

  describe "Configure" do
    test "type returns 0x02" do
      assert Configure.type() == 0x02
    end

    test "encode encodes all fields correctly" do
      configure = %Configure{
        config_id: 0x12345678,
        total_parts: 0x05,
        part_number: 0x02,
        input_type: :analog,
        pin: 0x0A,
        sensitivity: 0x64
      }

      {:ok, encoded} = Configure.encode(configure)

      # Type (0x02) + config_id (little endian) + total_parts + part_number + input_type (0x00 = analog) + pin + sensitivity
      assert encoded == <<0x02, 0x78, 0x56, 0x34, 0x12, 0x05, 0x02, 0x00, 0x0A, 0x64>>
    end

    test "decode decodes valid message" do
      binary = <<0x02, 0x78, 0x56, 0x34, 0x12, 0x05, 0x02, 0x00, 0x0A, 0x64>>
      {:ok, decoded} = Configure.decode(binary)

      assert decoded == %Configure{
               config_id: 0x12345678,
               total_parts: 0x05,
               part_number: 0x02,
               input_type: :analog,
               pin: 0x0A,
               sensitivity: 0x64
             }
    end

    test "decode returns error for invalid message type" do
      assert Configure.decode(<<0x01, 0x78, 0x56, 0x34, 0x12, 0x05, 0x02, 0x01, 0x0A, 0x64>>) ==
               {:error, :invalid_message}
    end

    test "decode returns error for incomplete message" do
      assert Configure.decode(<<0x02, 0x78, 0x56>>) == {:error, :invalid_message}
    end

    test "roundtrip encode/decode" do
      original = %Configure{
        config_id: 0x12345678,
        total_parts: 0x05,
        part_number: 0x02,
        input_type: :analog,
        pin: 0x0A,
        sensitivity: 0x64
      }

      {:ok, encoded} = Configure.encode(original)
      {:ok, decoded} = Configure.decode(encoded)

      assert decoded == original
    end
  end

  describe "Configure - Button type" do
    test "encode encodes button configuration correctly" do
      configure = %Configure{
        config_id: 0x12345678,
        total_parts: 0x05,
        part_number: 0x02,
        input_type: :button,
        pin: 0x0A,
        debounce: 0x32
      }

      {:ok, encoded} = Configure.encode(configure)

      # Type (0x02) + config_id + total_parts + part_number + input_type (0x01 = button) + pin + debounce
      assert encoded == <<0x02, 0x78, 0x56, 0x34, 0x12, 0x05, 0x02, 0x01, 0x0A, 0x32>>
    end

    test "decode decodes button configuration" do
      binary = <<0x02, 0x78, 0x56, 0x34, 0x12, 0x05, 0x02, 0x01, 0x0A, 0x32>>
      {:ok, decoded} = Configure.decode(binary)

      assert decoded == %Configure{
               config_id: 0x12345678,
               total_parts: 0x05,
               part_number: 0x02,
               input_type: :button,
               pin: 0x0A,
               debounce: 0x32
             }
    end

    test "roundtrip encode/decode button" do
      original = %Configure{
        config_id: 0x12345678,
        total_parts: 0x05,
        part_number: 0x02,
        input_type: :button,
        pin: 0x0A,
        debounce: 0x32
      }

      {:ok, encoded} = Configure.encode(original)
      {:ok, decoded} = Configure.decode(encoded)

      assert decoded == original
    end
  end

  describe "Configure - Matrix type" do
    test "encode encodes matrix configuration correctly" do
      configure = %Configure{
        config_id: 0x12345678,
        total_parts: 0x03,
        part_number: 0x01,
        input_type: :matrix,
        row_pins: [2, 3, 4],
        col_pins: [5, 6]
      }

      {:ok, encoded} = Configure.encode(configure)

      # Header + input_type (0x02) + num_rows (3) + num_cols (2) + row_pins + col_pins
      assert encoded ==
               <<0x02, 0x78, 0x56, 0x34, 0x12, 0x03, 0x01, 0x02, 0x03, 0x02, 2, 3, 4, 5, 6>>
    end

    test "decode decodes matrix configuration" do
      binary = <<0x02, 0x78, 0x56, 0x34, 0x12, 0x03, 0x01, 0x02, 0x03, 0x02, 2, 3, 4, 5, 6>>
      {:ok, decoded} = Configure.decode(binary)

      assert decoded == %Configure{
               config_id: 0x12345678,
               total_parts: 0x03,
               part_number: 0x01,
               input_type: :matrix,
               row_pins: [2, 3, 4],
               col_pins: [5, 6]
             }
    end

    test "decode returns error for matrix with incorrect pin count" do
      # Says 3 rows + 2 cols = 5 pins, but only provides 4 bytes of pin data
      binary = <<0x02, 0x78, 0x56, 0x34, 0x12, 0x03, 0x01, 0x02, 0x03, 0x02, 2, 3, 4, 5>>
      assert Configure.decode(binary) == {:error, :invalid_message}
    end

    test "roundtrip encode/decode matrix" do
      original = %Configure{
        config_id: 0x12345678,
        total_parts: 0x03,
        part_number: 0x01,
        input_type: :matrix,
        row_pins: [2, 3, 4, 5],
        col_pins: [6, 7, 8]
      }

      {:ok, encoded} = Configure.encode(original)
      {:ok, decoded} = Configure.decode(encoded)

      assert decoded == original
    end

    test "roundtrip encode/decode empty matrix" do
      original = %Configure{
        config_id: 0x12345678,
        total_parts: 0x01,
        part_number: 0x00,
        input_type: :matrix,
        row_pins: [],
        col_pins: []
      }

      {:ok, encoded} = Configure.encode(original)
      {:ok, decoded} = Configure.decode(encoded)

      assert decoded == original
    end
  end

  describe "ConfigurationStored" do
    test "type returns 0x03" do
      assert ConfigurationStored.type() == 0x03
    end

    test "encode encodes config_id correctly" do
      stored = %ConfigurationStored{config_id: 0x12345678}
      {:ok, encoded} = ConfigurationStored.encode(stored)

      # Type (0x03) + config_id (little endian)
      assert encoded == <<0x03, 0x78, 0x56, 0x34, 0x12>>
    end

    test "decode decodes valid message" do
      binary = <<0x03, 0x78, 0x56, 0x34, 0x12>>
      {:ok, decoded} = ConfigurationStored.decode(binary)

      assert decoded == %ConfigurationStored{config_id: 0x12345678}
    end

    test "decode returns error for invalid message type" do
      assert ConfigurationStored.decode(<<0x02, 0x78, 0x56, 0x34, 0x12>>) ==
               {:error, :invalid_message}
    end

    test "decode returns error for incomplete message" do
      assert ConfigurationStored.decode(<<0x03, 0x78, 0x56>>) == {:error, :invalid_message}
    end

    test "roundtrip encode/decode" do
      original = %ConfigurationStored{config_id: 0xDEADBEEF}
      {:ok, encoded} = ConfigurationStored.encode(original)
      {:ok, decoded} = ConfigurationStored.decode(encoded)

      assert decoded == original
    end
  end

  describe "ConfigurationError" do
    test "type returns 0x04" do
      assert ConfigurationError.type() == 0x04
    end

    test "encode encodes config_id correctly" do
      error = %ConfigurationError{config_id: 0x12345678}
      {:ok, encoded} = ConfigurationError.encode(error)

      # Type (0x04) + config_id (little endian)
      assert encoded == <<0x04, 0x78, 0x56, 0x34, 0x12>>
    end

    test "decode decodes valid message" do
      binary = <<0x04, 0x78, 0x56, 0x34, 0x12>>
      {:ok, decoded} = ConfigurationError.decode(binary)

      assert decoded == %ConfigurationError{config_id: 0x12345678}
    end

    test "decode returns error for invalid message type" do
      assert ConfigurationError.decode(<<0x03, 0x78, 0x56, 0x34, 0x12>>) ==
               {:error, :invalid_message}
    end

    test "decode returns error for incomplete message" do
      assert ConfigurationError.decode(<<0x04, 0x78, 0x56>>) == {:error, :invalid_message}
    end

    test "roundtrip encode/decode" do
      original = %ConfigurationError{config_id: 0xDEADBEEF}
      {:ok, encoded} = ConfigurationError.encode(original)
      {:ok, decoded} = ConfigurationError.decode(encoded)

      assert decoded == original
    end
  end

  describe "InputValue" do
    test "type returns 0x05" do
      assert InputValue.type() == 0x05
    end

    test "encode encodes positive value correctly" do
      input = %InputValue{pin: 0x0A, value: 0x1234}
      {:ok, encoded} = InputValue.encode(input)

      # Type (0x05) + pin + value (little endian signed)
      assert encoded == <<0x05, 0x0A, 0x34, 0x12>>
    end

    test "encode encodes negative value correctly" do
      input = %InputValue{pin: 0x0A, value: -1}
      {:ok, encoded} = InputValue.encode(input)

      # -1 in two's complement little endian: 0xFF, 0xFF
      assert encoded == <<0x05, 0x0A, 0xFF, 0xFF>>
    end

    test "decode decodes positive value" do
      binary = <<0x05, 0x0A, 0x34, 0x12>>
      {:ok, decoded} = InputValue.decode(binary)

      assert decoded == %InputValue{pin: 0x0A, value: 0x1234}
    end

    test "decode decodes negative value" do
      # -1 in two's complement little endian: 0xFF, 0xFF
      binary = <<0x05, 0x0A, 0xFF, 0xFF>>
      {:ok, decoded} = InputValue.decode(binary)

      assert decoded == %InputValue{pin: 0x0A, value: -1}
    end

    test "decode returns error for invalid message type" do
      assert InputValue.decode(<<0x04, 0x0A, 0x34, 0x12>>) == {:error, :invalid_message}
    end

    test "decode returns error for incomplete message" do
      assert InputValue.decode(<<0x05, 0x0A>>) == {:error, :invalid_message}
    end

    test "roundtrip encode/decode with positive value" do
      original = %InputValue{pin: 0x0A, value: 0x1234}
      {:ok, encoded} = InputValue.encode(original)
      {:ok, decoded} = InputValue.decode(encoded)

      assert decoded == original
    end

    test "roundtrip encode/decode with negative value" do
      original = %InputValue{pin: 0x0A, value: -32768}
      {:ok, encoded} = InputValue.encode(original)
      {:ok, decoded} = InputValue.decode(encoded)

      assert decoded == original
    end
  end

  describe "Heartbeat" do
    test "type returns 0x06" do
      assert Heartbeat.type() == 0x06
    end

    test "encode encodes message correctly" do
      heartbeat = %Heartbeat{}
      {:ok, encoded} = Heartbeat.encode(heartbeat)

      assert encoded == <<0x06>>
    end

    test "decode decodes valid message" do
      binary = <<0x06>>
      {:ok, decoded} = Heartbeat.decode(binary)

      assert decoded == %Heartbeat{}
    end

    test "decode returns error for invalid message type" do
      assert Heartbeat.decode(<<0x05>>) == {:error, :invalid_message}
    end

    test "decode returns error for empty message" do
      assert Heartbeat.decode(<<>>) == {:error, :invalid_message}
    end

    test "roundtrip encode/decode" do
      original = %Heartbeat{}
      {:ok, encoded} = Heartbeat.encode(original)
      {:ok, decoded} = Heartbeat.decode(encoded)

      assert decoded == original
    end
  end

  describe "SetOutput" do
    test "type returns 0x07" do
      assert SetOutput.type() == 0x07
    end

    test "encode encodes :high value correctly" do
      output = %SetOutput{pin: 0x05, value: :high}
      {:ok, encoded} = SetOutput.encode(output)

      assert encoded == <<0x07, 0x05, 0x01>>
    end

    test "encode encodes :low value correctly" do
      output = %SetOutput{pin: 0x05, value: :low}
      {:ok, encoded} = SetOutput.encode(output)

      assert encoded == <<0x07, 0x05, 0x00>>
    end

    test "encode returns error for invalid value" do
      output = %SetOutput{pin: 0x05, value: :invalid}
      assert {:error, :invalid_value} = SetOutput.encode(output)
    end

    test "decode decodes valid :high message" do
      binary = <<0x07, 0x05, 0x01>>
      {:ok, decoded} = SetOutput.decode(binary)

      assert decoded == %SetOutput{pin: 0x05, value: :high}
    end

    test "decode decodes valid :low message" do
      binary = <<0x07, 0x05, 0x00>>
      {:ok, decoded} = SetOutput.decode(binary)

      assert decoded == %SetOutput{pin: 0x05, value: :low}
    end

    test "decode returns error for invalid value" do
      binary = <<0x07, 0x05, 0x02>>
      assert {:error, :invalid_message} = SetOutput.decode(binary)
    end

    test "decode returns error for invalid message type" do
      binary = <<0x06, 0x05, 0x01>>
      assert {:error, :invalid_message} = SetOutput.decode(binary)
    end

    test "decode returns error for incomplete message" do
      assert SetOutput.decode(<<0x07, 0x05>>) == {:error, :invalid_message}
    end

    test "roundtrip encode/decode :high" do
      original = %SetOutput{pin: 0x10, value: :high}
      {:ok, encoded} = SetOutput.encode(original)
      {:ok, decoded} = SetOutput.decode(encoded)

      assert decoded == original
    end

    test "roundtrip encode/decode :low" do
      original = %SetOutput{pin: 0xFF, value: :low}
      {:ok, encoded} = SetOutput.encode(original)
      {:ok, decoded} = SetOutput.decode(encoded)

      assert decoded == original
    end
  end

  describe "Message.decode/1" do
    alias Trenino.Serial.Protocol.Message

    test "decodes IdentityRequest" do
      binary = <<0x00, 0x78, 0x56, 0x34, 0x12>>
      {:ok, decoded} = Message.decode(binary)

      assert decoded == %IdentityRequest{request_id: 0x12345678}
    end

    test "decodes IdentityResponse" do
      binary = <<0x01, 0x78, 0x56, 0x34, 0x12, 0x01, 0x02, 0x03, 0xEF, 0xBE, 0xAD, 0xDE>>
      {:ok, decoded} = Message.decode(binary)

      assert decoded == %IdentityResponse{
               request_id: 0x12345678,
               version: "1.2.3",
               config_id: 0xDEADBEEF
             }
    end

    test "decodes Configure" do
      binary = <<0x02, 0x78, 0x56, 0x34, 0x12, 0x05, 0x02, 0x00, 0x0A, 0x64>>
      {:ok, decoded} = Message.decode(binary)

      assert decoded == %Configure{
               config_id: 0x12345678,
               total_parts: 0x05,
               part_number: 0x02,
               input_type: :analog,
               pin: 0x0A,
               sensitivity: 0x64
             }
    end

    test "decodes ConfigurationStored" do
      binary = <<0x03, 0x78, 0x56, 0x34, 0x12>>
      {:ok, decoded} = Message.decode(binary)

      assert decoded == %ConfigurationStored{config_id: 0x12345678}
    end

    test "decodes ConfigurationError" do
      binary = <<0x04, 0x78, 0x56, 0x34, 0x12>>
      {:ok, decoded} = Message.decode(binary)

      assert decoded == %ConfigurationError{config_id: 0x12345678}
    end

    test "decodes InputValue" do
      binary = <<0x05, 0x0A, 0x34, 0x12>>
      {:ok, decoded} = Message.decode(binary)

      assert decoded == %InputValue{pin: 0x0A, value: 0x1234}
    end

    test "decodes InputValue with negative value" do
      binary = <<0x05, 0x0A, 0xFF, 0xFF>>
      {:ok, decoded} = Message.decode(binary)

      assert decoded == %InputValue{pin: 0x0A, value: -1}
    end

    test "decodes Heartbeat" do
      binary = <<0x06>>
      {:ok, decoded} = Message.decode(binary)

      assert decoded == %Heartbeat{}
    end

    test "decodes SetOutput" do
      binary = <<0x07, 0x05, 0x01>>
      {:ok, decoded} = Message.decode(binary)

      assert decoded == %SetOutput{pin: 0x05, value: :high}
    end

    test "decodes Configure with button type" do
      binary = <<0x02, 0x78, 0x56, 0x34, 0x12, 0x05, 0x02, 0x01, 0x0A, 0x32>>
      {:ok, decoded} = Message.decode(binary)

      assert decoded == %Configure{
               config_id: 0x12345678,
               total_parts: 0x05,
               part_number: 0x02,
               input_type: :button,
               pin: 0x0A,
               debounce: 0x32
             }
    end

    test "decodes Configure with matrix type" do
      binary = <<0x02, 0x78, 0x56, 0x34, 0x12, 0x03, 0x01, 0x02, 0x02, 0x02, 2, 3, 5, 6>>
      {:ok, decoded} = Message.decode(binary)

      assert decoded == %Configure{
               config_id: 0x12345678,
               total_parts: 0x03,
               part_number: 0x01,
               input_type: :matrix,
               row_pins: [2, 3],
               col_pins: [5, 6]
             }
    end

    test "returns error for unknown message type" do
      binary = <<0xFF>>
      assert Message.decode(binary) == {:error, :unknown_message_type}
    end

    test "returns error for insufficient data" do
      assert Message.decode(<<>>) == {:error, :insufficient_data}
    end

    test "returns error for invalid input" do
      assert Message.decode(nil) == {:error, :invalid_input}
      assert Message.decode(123) == {:error, :invalid_input}
    end

    test "roundtrip through Message.decode for all message types" do
      messages = [
        %IdentityRequest{request_id: 0x12345678},
        %IdentityResponse{
          request_id: 0x12345678,
          version: "1.2.3",
          config_id: 0xDEADBEEF
        },
        %Configure{
          config_id: 0x12345678,
          total_parts: 0x05,
          part_number: 0x02,
          input_type: :analog,
          pin: 0x0A,
          sensitivity: 0x64
        },
        %Configure{
          config_id: 0x12345678,
          total_parts: 0x05,
          part_number: 0x02,
          input_type: :button,
          pin: 0x0A,
          debounce: 0x32
        },
        %Configure{
          config_id: 0x12345678,
          total_parts: 0x03,
          part_number: 0x01,
          input_type: :matrix,
          row_pins: [2, 3, 4],
          col_pins: [5, 6]
        },
        %ConfigurationStored{config_id: 0x12345678},
        %ConfigurationError{config_id: 0x12345678},
        %InputValue{pin: 0x0A, value: 0x1234},
        %Heartbeat{},
        %SetOutput{pin: 0x10, value: :high}
      ]

      for message <- messages do
        module = message.__struct__
        {:ok, encoded} = module.encode(message)
        {:ok, decoded} = Message.decode(encoded)

        assert decoded == message
      end
    end
  end
end
