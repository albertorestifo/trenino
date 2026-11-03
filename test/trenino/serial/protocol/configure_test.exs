defmodule Trenino.Serial.Protocol.ConfigureTest do
  use ExUnit.Case, async: true
  alias Trenino.Serial.Protocol.Configure

  describe "encode/1 - analog" do
    test "encodes correctly" do
      msg = %Configure{
        config_id: 1,
        total_parts: 1,
        part_number: 0,
        input_type: :analog,
        pin: 3,
        sensitivity: 10
      }

      assert {:ok, <<0x02, 1::little-32, 1, 0, 0x00, 3, 10>>} = Configure.encode(msg)
    end
  end

  describe "encode/1 - button" do
    test "encodes correctly" do
      msg = %Configure{
        config_id: 2,
        total_parts: 1,
        part_number: 0,
        input_type: :button,
        pin: 5,
        debounce: 20
      }

      assert {:ok, <<0x02, 2::little-32, 1, 0, 0x01, 5, 20>>} = Configure.encode(msg)
    end
  end

  describe "encode/1 - matrix" do
    test "encodes correctly" do
      msg = %Configure{
        config_id: 3,
        total_parts: 1,
        part_number: 0,
        input_type: :matrix,
        row_pins: [2, 3],
        col_pins: [4, 5, 6]
      }

      assert {:ok, <<0x02, 3::little-32, 1, 0, 0x02, 2, 3, 2, 3, 4, 5, 6>>} =
               Configure.encode(msg)
    end
  end

  describe "encode/1 - ht16k33" do
    test "encodes correctly" do
      msg = %Configure{
        config_id: 42,
        total_parts: 1,
        part_number: 0,
        input_type: :ht16k33,
        i2c_address: 0x70,
        brightness: 8,
        num_digits: 4
      }

      assert {:ok, <<0x02, 42::little-32, 1, 0, 0x04, 0x70, 8, 4>>} =
               Configure.encode(msg)
    end

    test "encodes with different i2c address" do
      msg = %Configure{
        config_id: 1,
        total_parts: 2,
        part_number: 1,
        input_type: :ht16k33,
        i2c_address: 0x71,
        brightness: 15,
        num_digits: 6
      }

      assert {:ok, <<0x02, 1::little-32, 2, 1, 0x04, 0x71, 15, 6>>} =
               Configure.encode(msg)
    end
  end
end
