defmodule TswIo.Hardware.Calibration.CalculatorTest do
  use ExUnit.Case, async: true

  alias TswIo.Hardware.Calibration.Calculator
  alias TswIo.Hardware.Input.Calibration

  describe "normalize/2" do
    test "normalizes normal input at minimum" do
      calibration = %Calibration{
        min_value: 10,
        max_value: 150,
        is_inverted: false,
        has_rollover: false,
        max_hardware_value: 1023
      }

      assert Calculator.normalize(10, calibration) == 0.0
    end

    test "normalizes normal input at maximum" do
      calibration = %Calibration{
        min_value: 10,
        max_value: 150,
        is_inverted: false,
        has_rollover: false,
        max_hardware_value: 1023
      }

      assert Calculator.normalize(150, calibration) == 1.0
    end

    test "normalizes normal input in middle" do
      calibration = %Calibration{
        min_value: 10,
        max_value: 150,
        is_inverted: false,
        has_rollover: false,
        max_hardware_value: 1023
      }

      # 80 is 70 units from min (10), total travel is 140
      # 70/140 = 0.5
      assert Calculator.normalize(80, calibration) == 0.5
    end

    test "clamps values below minimum" do
      calibration = %Calibration{
        min_value: 10,
        max_value: 150,
        is_inverted: false,
        has_rollover: false,
        max_hardware_value: 1023
      }

      assert Calculator.normalize(5, calibration) == 0.0
    end

    test "clamps values above maximum" do
      calibration = %Calibration{
        min_value: 10,
        max_value: 150,
        is_inverted: false,
        has_rollover: false,
        max_hardware_value: 1023
      }

      assert Calculator.normalize(200, calibration) == 1.0
    end

    test "normalizes inverted input" do
      # For an inverted potentiometer:
      # - Physical minimum position reads raw HIGH value (e.g., 900)
      # - Physical maximum position reads raw LOW value (e.g., 100)
      #
      # Analyzer stores INVERTED values:
      # - min_value = 1023 - 900 = 123 (inverted value at physical min)
      # - max_value = 1023 - 100 = 923 (inverted value at physical max)
      # - is_inverted = true
      # - total_travel = 923 - 123 = 800
      calibration = %Calibration{
        min_value: 123,
        max_value: 923,
        is_inverted: true,
        has_rollover: false,
        max_hardware_value: 1023
      }

      # At physical min (raw 900): inverted = 123 = min_value → 0.0
      assert Calculator.normalize(900, calibration) == 0.0

      # At physical max (raw 100): inverted = 923 = max_value → 1.0
      assert Calculator.normalize(100, calibration) == 1.0

      # In the middle (raw 500): inverted = 523, (523-123)/800 = 0.5
      assert Calculator.normalize(500, calibration) == 0.5
    end

    test "normalizes with rollover (non-inverted)" do
      # Potentiometer where the calibrated range crosses 0/1023 boundary.
      # Physical sweep: 1010 → 1015 → 1020 → 1023 → 0 → 5 → 10
      #
      # Analyzer stores:
      # - min_value = 1010
      # - max_value = 10 + 1024 = 1034 (extended past hardware max)
      # - total_travel = 1034 - 1010 = 24
      calibration = %Calibration{
        min_value: 1010,
        max_value: 1034,
        is_inverted: false,
        has_rollover: true,
        max_hardware_value: 1023
      }

      assert Calculator.total_travel(calibration) == 24

      # At min (raw 1010): normalized = 0.0
      assert Calculator.normalize(1010, calibration) == 0.0

      # Before rollover (raw 1020): (1020-1010)/24 = 10/24 ≈ 0.42
      assert Calculator.normalize(1020, calibration) == 0.42

      # At hardware max (raw 1023): (1023-1010)/24 = 13/24 ≈ 0.54
      assert Calculator.normalize(1023, calibration) == 0.54

      # After rollover (raw 5): 5 < 1010, so adjusted = 5 + 1024 = 1029
      # (1029-1010)/24 = 19/24 ≈ 0.79
      assert Calculator.normalize(5, calibration) == 0.79

      # At max (raw 10): adjusted = 10 + 1024 = 1034 = max_value → 1.0
      assert Calculator.normalize(10, calibration) == 1.0
    end

    test "normalizes inverted input without rollover" do
      # Inverted potentiometer where calibrated range does NOT cross 0/1023.
      # Raw values DECREASE as physical position increases.
      #
      # Physical sweep: raw 541 → 400 → 300 → 197
      # Inverted values: 482 → 623 → 723 → 826
      #
      # Analyzer stores:
      # - min_value = 482
      # - max_value = 826
      # - total_travel = 344
      calibration = %Calibration{
        min_value: 482,
        max_value: 826,
        is_inverted: true,
        has_rollover: false,
        max_hardware_value: 1023
      }

      assert Calculator.total_travel(calibration) == 344

      # At physical min (raw 541): inverted = 482 = min_value → 0.0
      assert Calculator.normalize(541, calibration) == 0.0

      # Middle of range (raw 369): inverted = 654, (654-482)/344 = 0.5
      assert Calculator.normalize(369, calibration) == 0.5

      # At physical max (raw 197): inverted = 826 = max_value → 1.0
      assert Calculator.normalize(197, calibration) == 1.0

      # Past physical min (raw 542): inverted = 481 < min_value → clamps to 0.0
      assert Calculator.normalize(542, calibration) == 0.0

      # Past physical max (raw 100): inverted = 923 > max_value → clamps to 1.0
      assert Calculator.normalize(100, calibration) == 1.0
    end

    test "normalizes inverted input with rollover" do
      # Inverted potentiometer where calibrated range CROSSES 0/1023 boundary.
      # Raw values DECREASE as physical position increases, wrapping 0→1023.
      #
      # Physical sweep: raw 100 → 50 → 0 → (wrap) → 1023 → 950 → 900
      # Inverted values: 923 → 973 → 1023 → (wrap) → 0 → 73 → 123
      #
      # The inverted values wrap from 1023 to 0, so Analyzer extends max_value:
      # - min_value = 923 (inverted value at physical min)
      # - max_value = 123 + 1024 = 1147 (extended inverted value at physical max)
      # - total_travel = 1147 - 923 = 224
      calibration = %Calibration{
        min_value: 923,
        max_value: 1147,
        is_inverted: true,
        has_rollover: true,
        max_hardware_value: 1023
      }

      assert Calculator.total_travel(calibration) == 224

      # At physical min (raw 100): inverted = 923 = min_value → 0.0
      assert Calculator.normalize(100, calibration) == 0.0

      # Moving toward rollover (raw 50): inverted = 973, (973-923)/224 ≈ 0.22
      assert Calculator.normalize(50, calibration) == 0.22

      # At inverted max before wrap (raw 0): inverted = 1023, (1023-923)/224 ≈ 0.45
      assert Calculator.normalize(0, calibration) == 0.45

      # Just after wrap (raw 1023): inverted = 0, adjusted = 0 + 1024 = 1024
      # (1024-923)/224 ≈ 0.45
      assert Calculator.normalize(1023, calibration) == 0.45

      # Continuing after wrap (raw 950): inverted = 73, adjusted = 73 + 1024 = 1097
      # (1097-923)/224 ≈ 0.78
      assert Calculator.normalize(950, calibration) == 0.78

      # At physical max (raw 900): inverted = 123, adjusted = 123 + 1024 = 1147 → 1.0
      assert Calculator.normalize(900, calibration) == 1.0

      # Past physical max (raw 850): inverted = 173, in dead zone → clamps to 0.0
      # Dead zone values clamp to min_value (0.0) since we can't know which
      # direction the user came from
      assert Calculator.normalize(850, calibration) == 0.0

      # Past physical min (raw 150): inverted = 873, in dead zone → clamps to 0.0
      assert Calculator.normalize(150, calibration) == 0.0
    end
  end

  describe "total_travel/1" do
    test "returns difference between max and min" do
      calibration = %Calibration{
        min_value: 10,
        max_value: 150,
        is_inverted: false,
        has_rollover: false,
        max_hardware_value: 1023
      }

      assert Calculator.total_travel(calibration) == 140
    end

    test "works with rollover values" do
      calibration = %Calibration{
        min_value: 1010,
        max_value: 1034,
        is_inverted: false,
        has_rollover: true,
        max_hardware_value: 1023
      }

      assert Calculator.total_travel(calibration) == 24
    end
  end
end
