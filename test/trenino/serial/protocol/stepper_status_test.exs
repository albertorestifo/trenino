defmodule Trenino.Serial.Protocol.StepperStatusTest do
  use ExUnit.Case, async: true
  alias Trenino.Serial.Protocol.{Message, StepperConfiguration, StepperStatus}

  test "all result/state/fault enums and reference flags" do
    for result <- 0..9, state <- 0..4, fault <- 0..3, reference <- 0..2 do
      flags = 7 + reference * 8

      bytes =
        <<17, 1, 6, 0, 0x34, 0x12, result, state, flags, fault, -1::little-signed-32,
          720::little-signed-32, 5, 2, 129, 135, 129>>

      assert byte_size(bytes) == 23

      assert {:ok,
              %StepperStatus{known: true, configured: true, energized: true, position: -1} =
                status} = Message.decode(bytes)

      assert StepperStatus.supports?(status, %StepperConfiguration{})
      assert status.reference_kind in [:unknown, :assumed_stop, :host_assigned]
    end
  end

  test "strict size revision and enum validation" do
    for bytes <- [
          <<17, 2, 0::size(168)>>,
          <<17, 1, 99, 0::size(160)>>,
          <<17, 1>>,
          <<17, 1, 0::size(176)>>
        ] do
      assert {:error, _} = Message.decode(bytes)
    end
  end
end
