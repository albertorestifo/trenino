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

  describe "mcp23017" do
    @mcp %Configure{
      config_id: 7,
      total_parts: 1,
      part_number: 0,
      input_type: :mcp23017,
      i2c_address: 0x20,
      direct_base: 128,
      matrix_base: 160,
      debounce: 5,
      direct_mask: 0x0103,
      row_mask: 0x0C00,
      col_mask: 0x3000
    }

    test "encodes mcp23017" do
      assert {:ok,
              <<0x02, 7::little-32, 1, 0, 0x05, 0x20, 128, 160, 5, 0x03, 0x01, 0x00, 0x0C, 0x00,
                0x30>>} = Configure.encode(@mcp)
    end

    test "round trips" do
      {:ok, <<0x02, body::binary>>} = Configure.encode(@mcp)
      assert {:ok, @mcp} = Configure.decode_body(body)
    end

    test "rejects a truncated mcp23017 body" do
      {:ok, <<0x02, body::binary>>} = Configure.encode(@mcp)
      truncated = binary_part(body, 0, byte_size(body) - 1)
      assert {:error, :invalid_message} = Configure.decode_body(truncated)
    end
  end

  describe "ads1115" do
    @ads %Configure{
      config_id: 9,
      total_parts: 1,
      part_number: 0,
      input_type: :ads1115,
      i2c_address: 0x48,
      pin_base: 192,
      channel_mask: 0b0111,
      gain: 1,
      ref_channel: 3,
      sensitivities: [1, 2, 3, 4]
    }

    test "encodes ads1115" do
      assert {:ok, <<0x02, 9::little-32, 1, 0, 0x06, 0x48, 192, 7, 1, 3, 1, 2, 3, 4>>} =
               Configure.encode(@ads)
    end

    test "nil ref_channel encodes as 0xFF" do
      assert {:ok, <<0x02, 9::little-32, 1, 0, 0x06, 0x48, 192, 7, 1, 0xFF, 1, 2, 3, 4>>} =
               Configure.encode(%{@ads | ref_channel: nil})
    end

    test "round trips" do
      {:ok, <<0x02, body::binary>>} = Configure.encode(@ads)
      assert {:ok, @ads} = Configure.decode_body(body)

      {:ok, <<0x02, body::binary>>} = Configure.encode(%{@ads | ref_channel: nil})
      assert {:ok, %Configure{ref_channel: nil}} = Configure.decode_body(body)
    end
  end
end
