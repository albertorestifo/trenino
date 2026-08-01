defmodule Trenino.VirtualJoystick.MapperTest do
  use ExUnit.Case, async: true

  alias Trenino.Hardware.Input.Calibration
  alias Trenino.VirtualJoystick.Mapper

  @calibration %Calibration{
    min_value: 0,
    max_value: 1024,
    max_hardware_value: 1024,
    is_inverted: false,
    has_rollover: false
  }

  describe "axis_value/4" do
    test "maps calibrated minimum, midpoint, and maximum into the target range" do
      assert {:ok, 0} = Mapper.axis_value(0, @calibration, false, {0, 32_768})
      assert {:ok, 16_384} = Mapper.axis_value(512, @calibration, false, {0, 32_768})
      assert {:ok, 32_768} = Mapper.axis_value(1024, @calibration, false, {0, 32_768})
    end

    test "clamps values beyond the calibrated range" do
      assert {:ok, 0} = Mapper.axis_value(-50, @calibration, false, {0, 32_768})
      assert {:ok, 32_768} = Mapper.axis_value(2000, @calibration, false, {0, 32_768})
    end

    test "inverts the normalized axis value when requested" do
      assert {:ok, 24_576} = Mapper.axis_value(768, @calibration, false, {0, 32_768})
      assert {:ok, 8_192} = Mapper.axis_value(768, @calibration, true, {0, 32_768})
    end

    test "uses calibration direction when raw bounds are reversed" do
      calibration = %Calibration{@calibration | min_value: 1024, max_value: 0, is_inverted: true}

      assert {:ok, 24_576} = Mapper.axis_value(256, calibration, false, {0, 32_768})
    end

    test "returns uncalibrated when no calibration is available" do
      assert {:error, :uncalibrated} = Mapper.axis_value(512, nil, false, {0, 32_768})
    end

    test "returns uncalibrated for a persisted calibration with no travel" do
      calibration = %Calibration{@calibration | max_value: 0}

      assert {:error, :uncalibrated} = Mapper.axis_value(0, calibration, false, {0, 32_768})
    end

    test "supports discovered vJoy ranges other than the common default" do
      assert {:ok, 7_500} = Mapper.axis_value(768, @calibration, false, {0, 10_000})
    end

    test "rejects non-increasing target ranges" do
      assert {:error, :invalid_range} = Mapper.axis_value(512, @calibration, false, {10, 10})
      assert {:error, :invalid_range} = Mapper.axis_value(512, @calibration, false, {10, 0})
    end
  end
end
