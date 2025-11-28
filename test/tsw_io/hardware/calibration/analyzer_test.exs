defmodule TswIo.Hardware.Calibration.AnalyzerTest do
  use ExUnit.Case, async: true

  alias TswIo.Hardware.Calibration.Analyzer
  alias TswIo.Hardware.Calibration.Analyzer.Analysis

  describe "analyze_sweep/2" do
    test "returns false flags for normal increasing sweep" do
      sweep_samples = [10, 30, 50, 70, 90, 110, 130, 150]

      assert {:ok, %Analysis{inverted: false, rollover: false}} =
               Analyzer.analyze_sweep(sweep_samples, 1023)
    end

    test "detects inverted input from decreasing sweep" do
      sweep_samples = [150, 130, 110, 90, 70, 50, 30, 10]

      assert {:ok, %Analysis{inverted: true, rollover: false}} =
               Analyzer.analyze_sweep(sweep_samples, 1023)
    end

    test "detects rollover from large delta" do
      sweep_samples = [1010, 1015, 1020, 1023, 0, 5, 10, 15]

      assert {:ok, %Analysis{inverted: false, rollover: true}} =
               Analyzer.analyze_sweep(sweep_samples, 1023)
    end

    test "detects both inverted and rollover" do
      # Decreasing values that wrap around
      sweep_samples = [15, 10, 5, 0, 1023, 1020, 1015, 1010]

      assert {:ok, %Analysis{inverted: true, rollover: true}} =
               Analyzer.analyze_sweep(sweep_samples, 1023)
    end

    test "returns false flags for insufficient samples" do
      assert {:ok, %Analysis{inverted: false, rollover: false}} =
               Analyzer.analyze_sweep([100], 1023)

      assert {:ok, %Analysis{inverted: false, rollover: false}} =
               Analyzer.analyze_sweep([], 1023)
    end

    test "handles noisy but increasing data" do
      # Mostly increasing with some noise
      sweep_samples = [10, 15, 12, 20, 25, 22, 30, 35, 40, 50]

      assert {:ok, %Analysis{inverted: false, rollover: false}} =
               Analyzer.analyze_sweep(sweep_samples, 1023)
    end

    test "handles noisy but decreasing data" do
      # Mostly decreasing with some noise
      sweep_samples = [50, 45, 48, 40, 35, 38, 30, 25, 20, 10]

      assert {:ok, %Analysis{inverted: true, rollover: false}} =
               Analyzer.analyze_sweep(sweep_samples, 1023)
    end
  end

  describe "calculate_min/3" do
    test "returns min for normal input" do
      # For normal inputs, we take min(samples) for conservative boundary
      min_samples = [10, 12, 11, 9, 10, 11, 10, 12, 9, 10]

      result =
        Analyzer.calculate_min(min_samples, %Analysis{inverted: false, rollover: false}, 1023)

      # min(samples) = 9
      assert result == 9
    end

    test "returns inverted max for inverted input" do
      # For inverted, raw is HIGH at min position (e.g., 902)
      # We take max(raw) = 902 for conservative boundary
      # Then invert: 1023 - 902 = 121
      min_samples = [898, 900, 902, 899, 901, 900, 899, 901, 900, 902]

      result =
        Analyzer.calculate_min(min_samples, %Analysis{inverted: true, rollover: false}, 1023)

      # max(samples) = 902, inverted = 1023 - 902 = 121
      assert result == 1023 - 902
      assert result == 121
    end
  end

  describe "calculate_max/4" do
    test "returns max for normal input" do
      # For normal inputs, we take max(max_samples) for conservative boundary
      min_samples = [10, 12, 11, 9, 10]
      max_samples = [150, 152, 148, 151, 149]

      result =
        Analyzer.calculate_max(
          max_samples,
          min_samples,
          %Analysis{inverted: false, rollover: false},
          1023
        )

      # max(max_samples) = 152
      assert result == 152
    end

    test "returns inverted min for inverted input" do
      # For inverted: min position has high raw, max position has low raw
      # We take min(max_samples) = 98 for conservative max boundary
      # Then invert: 1023 - 98 = 925
      min_samples = [898, 900, 902, 899, 901]
      max_samples = [98, 100, 102, 99, 101]

      result =
        Analyzer.calculate_max(
          max_samples,
          min_samples,
          %Analysis{inverted: true, rollover: false},
          1023
        )

      # min(max_samples) = 98, inverted = 1023 - 98 = 925
      assert result == 925
    end

    test "accounts for rollover in normal direction" do
      # For normal rollover: min(min_samples)=1009, max(max_samples)=17
      min_samples = [1010, 1012, 1011, 1009, 1010]
      max_samples = [15, 17, 16, 14, 15]

      result =
        Analyzer.calculate_max(
          max_samples,
          min_samples,
          %Analysis{inverted: false, rollover: true},
          1023
        )

      # effective_max = max(max_samples) = 17
      # With rollover: 17 + 1023 + 1 = 1041
      assert result == 1041
    end

    test "accounts for rollover in inverted direction" do
      # Inverted with rollover: values decrease and wrap
      # At physical min: raw is HIGH (e.g., 100), inverted = 923
      # At physical max: raw is LOW after wrap (e.g., 900), inverted = 123
      min_samples = [98, 100, 102, 99, 101]
      max_samples = [898, 900, 902, 899, 901]

      result =
        Analyzer.calculate_max(
          max_samples,
          min_samples,
          %Analysis{inverted: true, rollover: true},
          1023
        )

      # effective_max = 1023 - min(max_samples) = 1023 - 898 = 125
      # With rollover: 125 + 1023 + 1 = 1149
      assert result == 1149
    end
  end
end
