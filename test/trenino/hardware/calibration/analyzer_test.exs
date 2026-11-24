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

  describe "circular_calibration/3" do
    @n 16_384

    test "a plain travel" do
      assert {:ok, result} = Analyzer.circular_calibration([4000, 4001, 3999], [9000, 9002], @n)

      assert result == %{
               min_value: 4000,
               max_value: 9001,
               is_inverted: false,
               has_rollover: false
             }
    end

    test "unwrapped positions past the top wrap back into range and flag the rollover" do
      # The lever went from 15000 up through 16383 to 2000 (unwrapped 18384).
      assert {:ok, result} = Analyzer.circular_calibration([15_000], [18_384], @n)

      assert result == %{
               min_value: 15_000,
               max_value: 2000,
               is_inverted: false,
               has_rollover: true
             }
    end

    test "a min end held right on the wrap point" do
      # Held readings 16382, 16383, 0, 1 unwrap to 16382..16385.
      assert {:ok, result} =
               Analyzer.circular_calibration([16_382, 16_383, 16_384, 16_385], [20_000], @n)

      assert result.min_value == 16_383
      assert result.max_value == 20_000 - @n
      refute result.is_inverted
    end

    test "inverted travel below zero" do
      # From 1000 down through 0 to 14000 (unwrapped -2384).
      assert {:ok, result} = Analyzer.circular_calibration([1000], [-2384], @n)

      assert result == %{
               min_value: 1000,
               max_value: 14_000,
               is_inverted: true,
               has_rollover: true
             }
    end

    test "travel near half a turn keeps its direction" do
      assert {:ok, %{is_inverted: false}} = Analyzer.circular_calibration([0], [8300], @n)
      assert {:ok, %{is_inverted: true}} = Analyzer.circular_calibration([0], [-8300], @n)
    end

    test "one glitch in a hold does not move the end" do
      assert {:ok, %{min_value: 4000}} =
               Analyzer.circular_calibration([4000, 4000, 12_000, 4001, 3999], [9000], @n)
    end

    test "refuses a travel under 5 degrees" do
      assert {:error, :range_too_small} = Analyzer.circular_calibration([4000], [4200], @n)
    end

    test "refuses a travel close to a full turn, or more" do
      assert {:error, :range_too_large} = Analyzer.circular_calibration([0], [15_500], @n)
      assert {:error, :range_too_large} = Analyzer.circular_calibration([0], [20_000], @n)
    end
  end
end
