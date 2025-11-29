defmodule TswIo.Hardware.Calibration.CalculatorTest do
  use ExUnit.Case, async: true

  alias TswIo.Hardware.Calibration.Calculator
  alias TswIo.Hardware.Input.Calibration

  describe "normalize/2 - simple case (not inverted, no rollover)" do
    # Scenario: Linear potentiometer, raw values increase as physical position increases
    # min_value = 100 (raw value at physical minimum)
    # max_value = 900 (raw value at physical maximum)
    # total_travel = 800
    setup do
      calibration = %Calibration{
        min_value: 100,
        max_value: 900,
        is_inverted: false,
        has_rollover: false,
        max_hardware_value: 1023
      }

      {:ok, calibration: calibration}
    end

    test "at minimum returns 0", %{calibration: calibration} do
      assert Calculator.normalize(100, calibration) == 0
    end

    test "at maximum returns total_travel", %{calibration: calibration} do
      assert Calculator.normalize(900, calibration) == 800
    end

    test "in middle returns proportional value", %{calibration: calibration} do
      # raw 500 is 400 steps from min (100)
      assert Calculator.normalize(500, calibration) == 400
    end

    test "below minimum clamps to 0", %{calibration: calibration} do
      assert Calculator.normalize(50, calibration) == 0
      assert Calculator.normalize(99, calibration) == 0
    end

    test "above maximum clamps to total_travel", %{calibration: calibration} do
      assert Calculator.normalize(901, calibration) == 800
      assert Calculator.normalize(1023, calibration) == 800
    end
  end

  describe "normalize/2 - inverted (no rollover)" do
    # Scenario: Inverted potentiometer, raw values DECREASE as physical position increases
    # At physical min: raw = 900 (high)
    # At physical max: raw = 100 (low)
    # min_value = 900, max_value = 100
    # total_travel = 800
    setup do
      calibration = %Calibration{
        min_value: 900,
        max_value: 100,
        is_inverted: true,
        has_rollover: false,
        max_hardware_value: 1023
      }

      {:ok, calibration: calibration}
    end

    test "at minimum (high raw) returns 0", %{calibration: calibration} do
      assert Calculator.normalize(900, calibration) == 0
    end

    test "at maximum (low raw) returns total_travel", %{calibration: calibration} do
      assert Calculator.normalize(100, calibration) == 800
    end

    test "in middle returns proportional value", %{calibration: calibration} do
      # raw 500 is 400 steps from min (900) going toward max (100)
      assert Calculator.normalize(500, calibration) == 400
    end

    test "above minimum (before min in inverted direction) clamps to 0", %{
      calibration: calibration
    } do
      assert Calculator.normalize(901, calibration) == 0
      assert Calculator.normalize(1023, calibration) == 0
    end

    test "below maximum (past max in inverted direction) clamps to total_travel", %{
      calibration: calibration
    } do
      assert Calculator.normalize(99, calibration) == 800
      assert Calculator.normalize(0, calibration) == 800
    end
  end

  describe "normalize/2 - rollover (not inverted)" do
    # Scenario: Potentiometer where calibrated range crosses 0/1023 boundary
    # Physical sweep: 900 → 950 → 1000 → 1023 → 0 → 50 → 100
    # min_value = 900, max_value = 100
    # total_travel = (1023 - 900 + 1) + 100 = 124 + 100 = 224
    setup do
      calibration = %Calibration{
        min_value: 900,
        max_value: 100,
        is_inverted: false,
        has_rollover: true,
        max_hardware_value: 1023
      }

      {:ok, calibration: calibration}
    end

    test "at minimum returns 0", %{calibration: calibration} do
      assert Calculator.normalize(900, calibration) == 0
    end

    test "approaching rollover boundary", %{calibration: calibration} do
      # raw 1000: 100 steps from min
      assert Calculator.normalize(1000, calibration) == 100
      # raw 1023: 123 steps from min
      assert Calculator.normalize(1023, calibration) == 123
    end

    test "after rollover (raw wrapped to 0)", %{calibration: calibration} do
      # raw 0: 124 steps from min (crossed the boundary)
      assert Calculator.normalize(0, calibration) == 124
    end

    test "at maximum (after rollover)", %{calibration: calibration} do
      # raw 100: total travel = 224
      assert Calculator.normalize(100, calibration) == 224
    end

    test "below minimum clamps to 0", %{calibration: calibration} do
      assert Calculator.normalize(899, calibration) == 0
    end

    test "above maximum clamps to total_travel", %{calibration: calibration} do
      assert Calculator.normalize(101, calibration) == 224
    end
  end

  describe "normalize/2 - inverted with rollover (your example)" do
    # Scenario from user:
    # inverted: true, rollover: true
    # min: 550, max: 735
    # max_hardware_value: 1023
    #
    # Physical sweep direction: raw decreases (inverted), then wraps 0→1023
    # At physical min: raw = 550
    # Sweep: 550 → 540 → ... → 0 → (wrap) → 1023 → ... → 735
    #
    # Expected mappings:
    # 555 -> 0 (clamped, above min in raw terms)
    # 550 -> 0 (at min)
    # 540 -> 10
    # 30 -> 520
    # 0 -> 550
    # 1023 -> 551 (rollover happened)
    # 1022 -> 552
    # 1000 -> 574
    # 735 -> 838 (at max: min + (max_hw - max + 1) = 550 + 288 = 838)
    # 730 -> 838 (clamped, past max)
    #
    # Total travel = 550 + (1023 - 735 + 1) = 550 + 289 = 839
    setup do
      calibration = %Calibration{
        min_value: 550,
        max_value: 735,
        is_inverted: true,
        has_rollover: true,
        max_hardware_value: 1023
      }

      {:ok, calibration: calibration}
    end

    test "at minimum returns 0", %{calibration: calibration} do
      assert Calculator.normalize(550, calibration) == 0
    end

    test "above minimum (in raw terms) clamps to 0", %{calibration: calibration} do
      assert Calculator.normalize(555, calibration) == 0
      assert Calculator.normalize(560, calibration) == 0
    end

    test "below minimum (moving toward 0)", %{calibration: calibration} do
      assert Calculator.normalize(540, calibration) == 10
      assert Calculator.normalize(500, calibration) == 50
      assert Calculator.normalize(30, calibration) == 520
    end

    test "at raw 0 (just before rollover)", %{calibration: calibration} do
      assert Calculator.normalize(0, calibration) == 550
    end

    test "at raw 1023 (just after rollover)", %{calibration: calibration} do
      assert Calculator.normalize(1023, calibration) == 551
    end

    test "after rollover continuing toward max", %{calibration: calibration} do
      assert Calculator.normalize(1022, calibration) == 552
      assert Calculator.normalize(1000, calibration) == 574
      # 550 + (1023 - 800 + 1) = 550 + 224 = 774
      assert Calculator.normalize(800, calibration) == 774
    end

    test "at maximum returns total_travel", %{calibration: calibration} do
      # At max (735): 550 + (1023 - 735 + 1) = 550 + 289 = 839
      assert Calculator.normalize(735, calibration) == 839
    end

    test "past maximum (below max in raw terms) clamps to total_travel", %{
      calibration: calibration
    } do
      assert Calculator.normalize(730, calibration) == 839
      assert Calculator.normalize(700, calibration) == 839
    end
  end

  describe "total_travel/1" do
    test "simple case" do
      calibration = %Calibration{
        min_value: 100,
        max_value: 900,
        is_inverted: false,
        has_rollover: false,
        max_hardware_value: 1023
      }

      assert Calculator.total_travel(calibration) == 800
    end

    test "inverted case" do
      calibration = %Calibration{
        min_value: 900,
        max_value: 100,
        is_inverted: true,
        has_rollover: false,
        max_hardware_value: 1023
      }

      assert Calculator.total_travel(calibration) == 800
    end

    test "rollover case" do
      calibration = %Calibration{
        min_value: 900,
        max_value: 100,
        is_inverted: false,
        has_rollover: true,
        max_hardware_value: 1023
      }

      # (1023 - 900 + 1) + 100 = 124 + 100 = 224
      assert Calculator.total_travel(calibration) == 224
    end

    test "inverted rollover case" do
      calibration = %Calibration{
        min_value: 550,
        max_value: 735,
        is_inverted: true,
        has_rollover: true,
        max_hardware_value: 1023
      }

      # 550 + (1023 - 735 + 1) = 550 + 289 = 839
      assert Calculator.total_travel(calibration) == 839
    end
  end
end
