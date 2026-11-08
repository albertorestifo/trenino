defmodule Trenino.Simulator.LeverAnalyzer.RecordedTrainsTest do
  @moduledoc """
  Runs the analyzer on sweeps recorded from real trains and checks the notch
  tables a driver confirmed against the in-game levers.
  """
  use ExUnit.Case, async: true

  alias Trenino.LeverSweepFixtures, as: Fixtures
  alias Trenino.Simulator.LeverAnalyzer
  alias Trenino.Simulator.LeverMetadata

  defp metadata(fixture, opts \\ []) do
    raw = %{
      "namedValues" =>
        Enum.map(Fixtures.labels(fixture), fn {source, min, max, name} ->
          %{
            "valueSource" => source,
            "valueRange" => %{"min" => min, "max" => max},
            "displayName" => name,
            "bDisplayNameIsFormatString" => String.contains?(name, "{")
          }
        end)
    }

    struct!(
      %LeverMetadata{
        control_path: "CurrentDrivableActor/Test",
        labels: LeverMetadata.parse_labels(raw)
      },
      opts
    )
  end

  defp analyze(fixture, opts \\ []) do
    {:ok, result} =
      fixture
      |> then(&apply(Fixtures, &1, []))
      |> Fixtures.samples()
      |> LeverAnalyzer.analyze_samples(Keyword.merge([sweep_step: 0.025], opts))

    result
  end

  # Compact {type, name, output, sim_input} rows for readable assertions
  defp table(result) do
    Enum.map(result.suggested_notches, fn
      %{type: :gate} = n ->
        {:gate, n.description, n.value, n.input_min}

      %{type: :linear} = n ->
        {:linear, n.description, {n.min_value, n.max_value}, {n.input_min, n.input_max}}
    end)
  end

  describe "BR430 MasterController" do
    test "Emergency gate, Brake range, Off gate, Power range" do
      result = analyze(:br430_master_controller, metadata: metadata(:br430_master_controller))

      assert table(result) == [
               {:gate, "Emergency Brake", -11.0, 0.0},
               {:linear, "Brake", {-10.0, -0.91}, {0.1, 0.41}},
               {:gate, "0", 0.0, 0.5},
               {:linear, "Power", {1.0, 6.71}, {0.59, 0.85}}
             ]

      assert result.lever_type == :hybrid
    end
  end

  describe "LIRR M9 MasterController" do
    test "Max/Min Brake and Min/Max Power are the ends of their ranges" do
      result = analyze(:m9_master_controller, metadata: metadata(:m9_master_controller))

      assert table(result) == [
               {:gate, "Emergency", -2.0, 0.0},
               {:linear, "Brake", {-1.0, -0.25}, {0.1, 0.4}},
               {:gate, "Coast", 0.0, 0.5},
               {:linear, "Power", {0.25, 1.0}, {0.6, 1.0}}
             ]
    end
  end

  describe "ÖBB 1116" do
    test "Throttle: Off gate and Power range, named from input labels" do
      result = analyze(:obb1116_throttle, metadata: metadata(:obb1116_throttle))

      assert table(result) == [
               {:gate, "Off", -1.0, 0.0},
               {:linear, "Power", {0.0, 1.0}, {0.1, 1.0}}
             ]
    end

    test "TrainBrake: 11 gates and a spring-loaded Release" do
      meta = metadata(:obb1116_train_brake, input_min: 0.0, input_max: 1.0)
      result = analyze(:obb1116_train_brake, metadata: meta)

      assert Enum.map(table(result), fn {type, name, _value, input} -> {type, name, input} end) ==
               [
                 {:gate, "Running", 0.1},
                 {:gate, "1A", 0.2},
                 {:gate, "1B", 0.28},
                 {:gate, "2", 0.35},
                 {:gate, "3", 0.42},
                 {:gate, "4", 0.5},
                 {:gate, "5", 0.57},
                 {:gate, "6", 0.65},
                 {:gate, "7", 0.72},
                 {:gate, "Full Service", 0.8},
                 {:gate, "Emergency", 1.0}
               ]

      assert [warning] = result.warnings
      assert warning =~ "'Release' could not be held"
    end
  end

  describe "AC4400CW" do
    test "ThrottleAndBrake: dynamic brake range, Set-up and Idle gates, 8 run notches" do
      result =
        analyze(:ac4400_throttle_and_brake, metadata: metadata(:ac4400_throttle_and_brake))

      assert table(result) == [
               {:linear, "B8 – B1", {-9.0, -2.0}, {-1.0, -0.3}},
               {:gate, "Set-up", -1.0, -0.2},
               {:gate, "Idle", 0.0, 0.2},
               {:gate, "N1", 1.0, 0.3},
               {:gate, "N2", 2.0, 0.4},
               {:gate, "N3", 3.0, 0.5},
               {:gate, "N4", 4.0, 0.6},
               {:gate, "N5", 5.0, 0.7},
               {:gate, "N6", 6.0, 0.8},
               {:gate, "N7", 7.0, 0.9},
               {:gate, "N8", 8.0, 1.0}
             ]
    end

    test "AutomaticBrake: Full Service merges into Service because its output is the same" do
      result = analyze(:ac4400_automatic_brake, metadata: metadata(:ac4400_automatic_brake))

      assert table(result) == [
               {:gate, "Release", -1.0, 0.0},
               {:linear, "Service", {0.0, 1.0}, {0.2, 0.65}},
               {:gate, "Suppression", 2.0, 0.7},
               {:gate, "Handle Off", 3.0, 0.8},
               {:gate, "Emergency", 4.0, 1.0}
             ]
    end
  end

  describe "Class 802 PowerHandle" do
    test "power steps inside one sim notch become four gates" do
      result =
        analyze(:class802_power_side,
          sweep_step: 0.05,
          metadata: metadata(:class802_power_side)
        )

      assert Enum.map(table(result), fn {type, name, value, _input} -> {type, name, value} end) ==
               [
                 {:gate, "Off", 0.0},
                 {:gate, "Power 1", 1.0},
                 {:gate, "Power 2", 2.0},
                 {:gate, "Power 3", 3.0},
                 {:gate, "Power 4", 4.0}
               ]

      # Each step keeps the input run where it holds, so the mapper sends its centre
      power_1 = Enum.at(result.suggested_notches, 1)
      assert {power_1.input_min, power_1.input_max} == {0.25, 0.35}
    end
  end

  describe "without metadata" do
    test "notches fall back to output-based names" do
      result = analyze(:m9_master_controller)

      assert [
               %{description: "Notch -2"},
               %{description: "Linear -1.0 to -0.25"} | _
             ] = result.suggested_notches

      assert result.warnings == []
    end
  end

  describe "coverage warnings" do
    test "warns when part of the output range was never reached" do
      meta = metadata(:class802_power_side, output_min: -2.0, output_max: 4.0)
      result = analyze(:class802_power_side, sweep_step: 0.05, metadata: meta)

      assert [warning] = result.warnings
      assert warning =~ "Part of its range was blocked"
    end
  end

  describe "edge cases" do
    defp rows(rows),
      do: rows |> Fixtures.samples() |> LeverAnalyzer.analyze_samples(sweep_step: 0.05)

    test "a gate past an unreachable band keeps its notch, even with the same output" do
      linear = for i <- 0..16, do: {i * 0.05, i * 0.05, i * 0.0625, 0}
      snapping = [{0.85, 0.8, 1.0, 0}, {0.9, 0.8, 1.0, 0}]
      gate = [{0.95, 1.0, 1.0, 1}, {1.0, 1.0, 1.0, 1}]

      {:ok, result} = rows(linear ++ snapping ++ gate)

      assert [%{type: :linear}, %{type: :gate, value: 1.0, input_min: 1.0}] =
               result.suggested_notches
    end

    test "a notch index seen again later does not swallow the notch between" do
      first = for i <- 0..8, do: {i * 0.05, i * 0.05, i * 0.05, 0}
      gate = [{0.45, 0.5, 2.0, 1}, {0.5, 0.5, 2.0, 1}, {0.55, 0.5, 2.0, 1}]
      second = for i <- 12..20, do: {i * 0.05, i * 0.05, 3.0 + i * 0.05, 0}

      {:ok, result} = rows(first ++ gate ++ second)

      assert Enum.map(result.suggested_notches, & &1.type) == [:linear, :gate, :linear]
    end

    test "a single sample passing between two gates is not a notch" do
      {:ok, result} =
        rows([
          {0.0, 0.0, 0.0, 0},
          {0.05, 0.0, 0.0, 0},
          {0.1, 0.1, 0.37, 1},
          {0.15, 0.2, 1.0, 2},
          {0.2, 0.2, 1.0, 2}
        ])

      assert Enum.map(result.suggested_notches, & &1.value) == [0.0, 1.0]
    end

    test "no samples is an error, not a crash" do
      assert LeverAnalyzer.analyze_samples([]) == {:error, :insufficient_samples}
    end
  end
end
