defmodule Trenino.Hardware.AngleSensorTest do
  use ExUnit.Case, async: true

  alias Trenino.Hardware.AngleSensor

  test "the MT6701 spec: 14-bit, two addresses with fixed report pins, firmware 3.4.0" do
    spec = AngleSensor.get(:mt6701)

    assert spec.max_raw == 16_383
    assert spec.firmware == "3.4.0"
    assert AngleSensor.addresses(spec) == [0x06, 0x46]
    assert AngleSensor.report_pin(spec, 0x06) == 240
    assert AngleSensor.report_pin(spec, 0x46) == 241
    assert AngleSensor.report_pin(spec, 0x40) == nil
  end

  test "looks sensors up by atom or string, and the ADC is not one" do
    assert AngleSensor.get("mt6701") == AngleSensor.get(:mt6701)
    assert AngleSensor.get(:adc) == nil
    assert AngleSensor.get("adc") == nil
    assert AngleSensor.get(nil) == nil
    assert AngleSensor.angle_sensor?(:mt6701)
    refute AngleSensor.angle_sensor?(:adc)
  end

  test "report pins stay out of physical and matrix pins" do
    for id <- AngleSensor.ids(), %{pin: pin} <- AngleSensor.get(id).addresses do
      assert pin in 240..247
    end
  end

  test "formats addresses and angles" do
    spec = AngleSensor.get(:mt6701)

    assert AngleSensor.format_address(0x06) == "0x06"
    assert AngleSensor.format_address(0x46) == "0x46"
    assert AngleSensor.degrees(spec, 8192) == 180.0
    assert AngleSensor.format_degrees(spec, 4096) == "90.00°"
    assert AngleSensor.counts(spec, 3) == 137
  end

  test "shortest_delta goes the short way round" do
    assert AngleSensor.shortest_delta(16_383, 1, 16_384) == 2
    assert AngleSensor.shortest_delta(1, 16_383, 16_384) == -2
    assert AngleSensor.shortest_delta(100, 200, 16_384) == 100
    assert AngleSensor.shortest_delta(200, 100, 16_384) == -100
  end

  test "a half-turn step and its way back cancel" do
    there = AngleSensor.shortest_delta(100, 8292, 16_384)
    back = AngleSensor.shortest_delta(8292, 100, 16_384)

    assert abs(there) == 8192
    assert there + back == 0
  end

  test "firmware_version is the lowest any sensor needs" do
    assert AngleSensor.firmware_version() == "3.4.0"
  end
end
