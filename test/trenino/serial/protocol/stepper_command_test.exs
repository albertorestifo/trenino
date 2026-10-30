defmodule Trenino.Serial.Protocol.StepperCommandTest do
  use ExUnit.Case, async: true
  alias Trenino.Serial.Protocol.{Configure, Message, StepperCommand, StepperConfiguration}

  test "exact canonical empty configuration" do
    message = %Configure{
      config_id: 0x12345678,
      total_parts: 0,
      part_number: 0,
      input_type: :empty
    }

    assert {:ok, <<2, 0x78, 0x56, 0x34, 0x12, 0, 0, 255>> = bytes} = Configure.encode(message)
    assert {:ok, ^message} = Message.decode(bytes)
    assert {:error, _} = Configure.encode(%{message | total_parts: 1})
    assert {:error, _} = Message.decode(bytes <> <<0>>)
  end

  test "signed target and exact configure layout round trip" do
    config = %StepperConfiguration{min_position: -1000, max_position: 720, home_direction: -1}

    message = %StepperCommand{
      operation: :configure,
      axis: 0,
      request_id: 0x1234,
      configuration: config
    }

    assert {:ok, bytes} = StepperCommand.encode(message)
    assert byte_size(bytes) == 41

    assert <<16, 1, 0, 0, 0x34, 0x12, 1, 1, 96, 1, 0, 1, 0, 0, -1000::little-signed-32,
             720::little-signed-32, _::binary>> = bytes

    assert {:ok, ^message} = Message.decode(bytes)
    move = %StepperCommand{operation: :move_to, axis: 1, request_id: 1, position: -1}
    assert {:ok, <<16, 1, 1, 1, 1, 0, 255, 255, 255, 255>>} = StepperCommand.encode(move)
    assert {:ok, home} = StepperCommand.encode(%{move | operation: :home, position: nil})
    assert byte_size(home) == 6
  end

  test "rejects malformed values without truncation" do
    for attrs <- [%{request_id: 0}, %{request_id: 65_536}, %{axis: 255}, %{operation: :unknown}] do
      msg = struct(StepperCommand, Map.merge(%{operation: :home, axis: 0, request_id: 1}, attrs))
      assert {:error, _} = StepperCommand.encode(msg)
    end

    for bytes <- [<<16, 2, 2, 0, 1, 0>>, <<16, 1, 11, 0, 1, 0>>, <<16, 1, 2, 0, 1, 0, 0>>] do
      assert {:error, _} = Message.decode(bytes)
    end

    assert {:error, _} =
             StepperCommand.encode(%StepperCommand{
               operation: :configure,
               axis: 0,
               request_id: 1,
               configuration: %StepperConfiguration{max_speed: 201}
             })
  end
end
