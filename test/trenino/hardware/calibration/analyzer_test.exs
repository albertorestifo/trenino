defmodule Trenino.Hardware.Calibration.AnalyzerTest do
  use ExUnit.Case, async: true

  alias Trenino.Hardware.Calibration.Analyzer
  alias Trenino.Hardware.Calibration.Analyzer.Analysis

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

  describe "calculate_min/2" do
    test "returns min sample for normal input" do
      min_samples = [10, 12, 11, 9, 10, 11, 10, 12, 9, 10]

      result = Analyzer.calculate_min(min_samples, %Analysis{inverted: false, rollover: false})

      # min(samples) = 9
      assert result == 9
    end

    test "returns max sample for inverted input" do
      # For inverted, raw is HIGH at min position
      # We take max(raw) for conservative boundary
      min_samples = [898, 900, 902, 899, 901, 900, 899, 901, 900, 902]

      result = Analyzer.calculate_min(min_samples, %Analysis{inverted: true, rollover: false})

      # max(samples) = 902
      assert result == 902
    end
  end

  describe "calculate_max/2" do
    test "returns max sample for normal input" do
      max_samples = [150, 152, 148, 151, 149]

      result = Analyzer.calculate_max(max_samples, %Analysis{inverted: false, rollover: false})

      # max(max_samples) = 152
      assert result == 152
    end

    test "returns min sample for inverted input" do
      # For inverted: max position has low raw
      # We take min(max_samples) for conservative max boundary
      max_samples = [98, 100, 102, 99, 101]

      result = Analyzer.calculate_max(max_samples, %Analysis{inverted: true, rollover: false})

      # min(max_samples) = 98
      assert result == 98
    end
  end
end
