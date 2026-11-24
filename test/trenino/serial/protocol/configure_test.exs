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

  describe "MT6701 (0x08)" do
    test "encodes and decodes the 3-byte payload" do
      msg = %Configure{
        config_id: 7,
        total_parts: 2,
        part_number: 1,
        input_type: :mt6701,
        i2c_address: 0x46,
        pin: 241,
        sensitivity: 6
      }

      assert {:ok, <<0x02, 7::little-32, 2, 1, 0x08, 0x46, 241, 6>> = bin} = Configure.encode(msg)
      <<0x02, body::binary>> = bin
      assert {:ok, ^msg} = Configure.decode_body(body)
    end

    test "refuses an out-of-range field" do
      msg = %Configure{
        config_id: 7,
        total_parts: 1,
        part_number: 0,
        input_type: :mt6701,
        i2c_address: 0x46,
        pin: 241,
        sensitivity: 11
      }

      assert {:error, :invalid_mt6701_configuration} = Configure.encode(msg)
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
