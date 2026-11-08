defmodule Trenino.Serial.Protocol.GaugeMessagesTest do
  use ExUnit.Case, async: true

  alias Trenino.Serial.Protocol.{Configure, Message, SetGaugePosition, ZeroGauge}

  # Byte vectors from the firmware's docs/GAUGE_WIRING.md (3.3.0).
  @vid6606_channel_a <<0x02, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x07, 0x00, 0x08, 0x07, 0x06,
                       0xFF, 0xC4, 0x0E, 0x88, 0x13, 0x50, 0xC3, 0x00>>
  @direct_pro_micro <<0x02, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x07, 0x01, 0x12, 0x13, 0x0A,
                      0x0F, 0xB1, 0x03, 0x08, 0x07, 0xDC, 0x05, 0x00>>

  defp gauge(attrs) do
    struct(
      %Configure{config_id: 1, total_parts: 1, part_number: 0, input_type: :gauge},
      attrs
    )
  end

  describe "Configure gauge (type 7)" do
    test "encodes the firmware's VID6606 example" do
      msg =
        gauge(
          driver: :vid6606,
          pins: [8, 7, 6, 0xFF],
          travel: 3780,
          max_speed: 5000,
          acceleration: 50_000,
          reverse: false
        )

      assert {:ok, @vid6606_channel_a} = Configure.encode(msg)
      assert {:ok, ^msg} = Message.decode(@vid6606_channel_a)
    end

    test "encodes the firmware's direct-drive example" do
      msg =
        gauge(
          driver: :direct,
          pins: [18, 19, 10, 15],
          travel: 945,
          max_speed: 1800,
          acceleration: 1500,
          reverse: false
        )

      assert {:ok, @direct_pro_micro} = Configure.encode(msg)
      assert {:ok, ^msg} = Message.decode(@direct_pro_micro)
    end

    test "reverse sets flags bit 0" do
      msg =
        gauge(
          driver: :vid6606,
          pins: [8, 7, 6, 0xFF],
          travel: 3780,
          max_speed: 5000,
          acceleration: 50_000,
          reverse: true
        )

      assert {:ok, bin} = Configure.encode(msg)
      assert :binary.last(bin) == 1
    end

    test "rejects an unknown driver or wrong pin count" do
      assert {:error, :invalid_gauge_configuration} =
               Configure.encode(gauge(driver: :pca9685, pins: [1, 2, 3, 4], reverse: false))

      assert {:error, :invalid_gauge_configuration} =
               Configure.encode(gauge(driver: :direct, pins: [1, 2, 3], reverse: false))
    end

    test "decode requires the exact 12-byte payload" do
      assert {:error, :invalid_message} = Message.decode(@vid6606_channel_a <> <<0>>)
      assert {:error, :invalid_message} = Message.decode(binary_part(@vid6606_channel_a, 0, 19))
    end
  end

  describe "SetGaugePosition (18)" do
    test "round-trips" do
      msg = %SetGaugePosition{pin: 8, position: 1890}
      assert {:ok, <<0x12, 8, 0x62, 0x07>> = bin} = SetGaugePosition.encode(msg)
      assert {:ok, ^msg} = Message.decode(bin)
    end

    test "rejects positions that do not fit in u16" do
      assert {:error, :invalid_gauge_position} =
               SetGaugePosition.encode(%SetGaugePosition{pin: 8, position: 70_000})
    end
  end

  describe "ZeroGauge (19)" do
    test "round-trips" do
      msg = %ZeroGauge{pin: 21}
      assert {:ok, <<0x13, 21>> = bin} = ZeroGauge.encode(msg)
      assert {:ok, ^msg} = Message.decode(bin)
    end
  end

  test "the removed stepper axis messages decode as unknown" do
    assert {:error, :unknown_message_type} = Message.decode(<<0x10, 1, 2, 3>>)
    assert {:error, :unknown_message_type} = Message.decode(<<0x11, 1, 2, 3>>)
  end
end
