defmodule Trenino.Simulator.LeverAnalyzer.AnalysisTest do
  @moduledoc """
  Fast unit tests for LeverAnalyzer's analysis logic.

  These tests operate directly on sample data without any I/O operations,
  making them execute instantly compared to integration tests.
  """
  use ExUnit.Case, async: true

  alias Trenino.Simulator.LeverAnalyzer
  alias Trenino.Simulator.LeverAnalyzer.AnalysisResult
  alias Trenino.Simulator.LeverAnalyzer.Sample

  describe "analyze_samples/1 - discrete levers" do
    test "detects discrete lever with integer outputs and snap zones" do
      samples = build_discrete_lever_samples()

      assert {:ok, %AnalysisResult{} = result} = LeverAnalyzer.analyze_samples(samples)

      assert result.lever_type == :discrete
      assert result.all_outputs_integers == true
      assert result.unique_output_count == 3
      assert Enum.all?(result.suggested_notches, &(&1[:type] == :gate))
    end

    test "detects all gates have correct values for discrete lever" do
      samples = build_discrete_lever_samples()

      {:ok, result} = LeverAnalyzer.analyze_samples(samples)

      values = Enum.map(result.suggested_notches, & &1[:value]) |> Enum.sort()
      assert values == [-1.0, 0.0, 1.0]
    end

    test "detects discrete lever with 5 positions" do
      # Simulate a 5-position reverser: -2, -1, 0, 1, 2
      samples = build_five_position_discrete_samples()

      {:ok, result} = LeverAnalyzer.analyze_samples(samples)

      assert result.lever_type == :discrete
      assert result.unique_output_count == 5
      assert length(result.suggested_notches) == 5
    end
  end

  describe "analyze_samples/1 - continuous levers" do
    test "detects continuous lever with many fractional outputs" do
      samples = build_continuous_lever_samples()

      assert {:ok, %AnalysisResult{} = result} = LeverAnalyzer.analyze_samples(samples)

      assert result.lever_type == :continuous
      assert result.all_outputs_integers == false
      assert result.unique_output_count >= 20
    end

    test "continuous lever produces single linear notch" do
      samples = build_continuous_lever_samples()

      {:ok, result} = LeverAnalyzer.analyze_samples(samples)

      assert length(result.suggested_notches) == 1
      assert hd(result.suggested_notches)[:type] == :linear
    end

    test "linear notch spans full output range" do
      samples = build_continuous_lever_samples()

      {:ok, result} = LeverAnalyzer.analyze_samples(samples)

      [notch] = result.suggested_notches
      assert notch[:min_value] == 0.0
      assert notch[:max_value] == 1.0
    end
  end

  describe "analyze_samples/1 - hybrid levers" do
    test "detects hybrid lever with both gate and linear zones" do
      samples = build_hybrid_lever_samples()

      assert {:ok, %AnalysisResult{} = result} = LeverAnalyzer.analyze_samples(samples)

      assert result.lever_type == :hybrid

      gates = Enum.filter(result.suggested_notches, &(&1[:type] == :gate))
      linears = Enum.filter(result.suggested_notches, &(&1[:type] == :linear))

      assert gates != []
      assert linears != []
    end

    test "gates have :value field, linears have :min_value and :max_value" do
      samples = build_hybrid_lever_samples()

      {:ok, result} = LeverAnalyzer.analyze_samples(samples)

      Enum.each(result.suggested_notches, fn notch ->
        case notch[:type] do
          :gate ->
            assert Map.has_key?(notch, :value)
            assert is_number(notch[:value])

          :linear ->
            assert Map.has_key?(notch, :min_value)
            assert Map.has_key?(notch, :max_value)
            assert is_number(notch[:min_value])
            assert is_number(notch[:max_value])
        end
      end)
    end
  end

  describe "analyze_samples/1 - zone merging" do
    test "merges continuous notch groups without snap boundaries" do
      # Samples with 3 different notch_indices but no snap between them
      samples = build_samples_with_continuous_notches()

      {:ok, result} = LeverAnalyzer.analyze_samples(samples)

      # Should have merged into a single zone
      assert length(result.zones) == 1
      assert hd(result.zones).type == :linear

      # The zone should contain all 3 notch indices
      assert length(hd(result.zones).notch_indices) == 3
    end

    test "does not merge zones with snap boundaries" do
      # Samples where actual_input jumps (snap boundary)
      samples = build_samples_with_snap_boundaries()

      {:ok, result} = LeverAnalyzer.analyze_samples(samples)

      # Should detect separate zones due to snap
      assert length(result.zones) >= 2
    end
  end

  describe "analyze_samples/1 - edge cases" do
    test "correctly identifies gate when min and max outputs are identical" do
      samples = build_single_output_gate_samples()

      {:ok, result} = LeverAnalyzer.analyze_samples(samples)

      gate = Enum.find(result.suggested_notches, &(&1[:type] == :gate))
      assert gate != nil
      assert gate[:value] == -5.0
    end

    test "correctly identifies gate when outputs differ by less than threshold" do
      # Outputs vary between -0.91 and -0.93 (same when considering threshold)
      samples = build_near_identical_output_samples()

      {:ok, result} = LeverAnalyzer.analyze_samples(samples)

      # First zone should be detected as a gate
      first_notch = hd(result.suggested_notches)
      assert first_notch[:type] == :gate
    end

    test "handles single sample per notch index" do
      samples = [
        %Sample{set_input: 0.0, actual_input: 0.0, output: 0.0, notch_index: 0, snapped: false},
        %Sample{set_input: 0.5, actual_input: 0.5, output: 0.5, notch_index: 1, snapped: false},
        %Sample{set_input: 1.0, actual_input: 1.0, output: 1.0, notch_index: 2, snapped: false}
      ]

      {:ok, result} = LeverAnalyzer.analyze_samples(samples)

      assert result.lever_type in [:discrete, :continuous, :hybrid]
    end
  end

  # ===========================================================================
  # Sample Builders
  # ===========================================================================

  defp build_discrete_lever_samples do
    # Reverser: -1, 0, 1 with snap zones
    # Zone 0: input 0.0-0.32 snaps to 0.0, output -1
    # Zone 1: input 0.33-0.65 snaps to 0.5, output 0
    # Zone 2: input 0.66-1.0 snaps to 1.0, output 1
    for i <- 0..50 do
      input = Float.round(i * 0.02, 2)

      {actual_input, output, notch_index} =
        cond do
          input < 0.33 -> {0.0, -1.0, 0}
          input < 0.66 -> {0.5, 0.0, 1}
          true -> {1.0, 1.0, 2}
        end

      %Sample{
        set_input: input,
        actual_input: actual_input,
        output: output,
        notch_index: notch_index,
        snapped: actual_input != input
      }
    end
  end

  defp build_five_position_discrete_samples do
    # 5-position lever with outputs -2, -1, 0, 1, 2
    for i <- 0..50 do
      input = Float.round(i * 0.02, 2)

      {actual_input, output, notch_index} =
        cond do
          input < 0.2 -> {0.0, -2.0, 0}
          input < 0.4 -> {0.25, -1.0, 1}
          input < 0.6 -> {0.5, 0.0, 2}
          input < 0.8 -> {0.75, 1.0, 3}
          true -> {1.0, 2.0, 4}
        end

      %Sample{
        set_input: input,
        actual_input: actual_input,
        output: output,
        notch_index: notch_index,
        snapped: actual_input != input
      }
    end
  end

  defp build_continuous_lever_samples do
    # Throttle: continuous 0.0 to 1.0
    for i <- 0..50 do
      input = Float.round(i * 0.02, 2)

      %Sample{
        set_input: input,
        actual_input: input,
        output: input,
        notch_index: 0,
        snapped: false
      }
    end
  end

  defp build_hybrid_lever_samples do
    # Hybrid: gate at 0, linear zone, gate at end
    # Zone 0: snap to 0.0, output -11 (gate)
    # Zone 1: linear 0.1-0.8, outputs vary
    # Zone 2: snap to 1.0, output 10 (gate)
    for i <- 0..50 do
      input = Float.round(i * 0.02, 2)

      {actual_input, output, notch_index} =
        cond do
          # Gate zone at start (snaps to 0.0)
          input < 0.1 ->
            {0.0, -11.0, 0}

          # Linear zone in middle
          input < 0.9 ->
            {input, Float.round(-10.0 + input * 20, 2), 1}

          # Gate zone at end (snaps to 1.0)
          true ->
            {1.0, 10.0, 2}
        end

      %Sample{
        set_input: input,
        actual_input: actual_input,
        output: output,
        notch_index: notch_index,
        snapped: abs(actual_input - input) > 0.03
      }
    end
  end

  defp build_samples_with_continuous_notches do
    # 3 notch indices but no snap between them (should merge)
    for i <- 0..50 do
      input = Float.round(i * 0.02, 2)

      notch_index =
        cond do
          input < 0.33 -> 0
          input < 0.66 -> 1
          true -> 2
        end

      %Sample{
        set_input: input,
        actual_input: input,
        output: input,
        notch_index: notch_index,
        snapped: false
      }
    end
  end

  defp build_samples_with_snap_boundaries do
    # Two zones with a snap boundary between them
    for i <- 0..50 do
      input = Float.round(i * 0.02, 2)

      {actual_input, output, notch_index} =
        if input < 0.5 do
          # First zone: snaps to 0.0
          {0.0, -5.0, 0}
        else
          # Second zone: snaps to 1.0 (big jump = snap boundary)
          {1.0, 5.0, 1}
        end

      %Sample{
        set_input: input,
        actual_input: actual_input,
        output: output,
        notch_index: notch_index,
        snapped: true
      }
    end
  end

  defp build_single_output_gate_samples do
    # Zone with identical outputs followed by linear zone
    for i <- 0..50 do
      input = Float.round(i * 0.02, 2)

      {actual_input, output, notch_index} =
        if input < 0.5 do
          {0.0, -5.0, 0}
        else
          {input, input * 10, 1}
        end

      %Sample{
        set_input: input,
        actual_input: actual_input,
        output: Float.round(output, 2),
        notch_index: notch_index,
        snapped: input < 0.5
      }
    end
  end

  defp build_near_identical_output_samples do
    # First zone: outputs between -0.91 and -0.93 (nearly identical)
    # Second zone: linear
    for i <- 0..50 do
      input = Float.round(i * 0.02, 2)

      {actual_input, output, notch_index} =
        if input < 0.5 do
          # Outputs vary slightly but should be treated as gate
          {0.0, Float.round(-0.91 - input * 0.04, 2), 0}
        else
          {input, input * 10, 1}
        end

      %Sample{
        set_input: input,
        actual_input: actual_input,
        output: output,
        notch_index: notch_index,
        snapped: input < 0.5
      }
    end
  end
end
