defmodule TswIo.Simulator.LeverAnalyzer do
  @moduledoc """
  Analyzes lever behavior by sweeping through the input range and detecting
  actual notch positions, snap zones, and output behavior.

  This module provides empirical detection of lever characteristics, ignoring
  the API's reported notch count/index which can be misleading for "hybrid"
  levers like the German S-Bahn MasterController.

  ## Lever Types Detected

  - `:discrete` - True notched lever with fixed integer output values
    (e.g., Reverser with outputs -2, -1, 0, 1)
  - `:continuous` - Smooth lever with fractional output values across the range
    (e.g., throttle with outputs 0.0 to 1.0 with many intermediate values)
  - `:hybrid` - Lever with snap zones but continuous output within zones
    (e.g., BR430 MasterController with 7 "notches" but 21 output positions)

  ## Usage

      {:ok, client} = get_simulator_client()
      {:ok, result} = LeverAnalyzer.analyze(client, "CurrentDrivableActor/MasterController")

      # result contains:
      # - lever_type: :discrete | :continuous | :hybrid
      # - suggested_notches: list of notch configurations
      # - samples: raw sample data
      # - snap_zones: detected snap zones
  """

  require Logger

  alias TswIo.Simulator.Client

  # Sweep configuration
  @sweep_step 0.02
  @settling_time_ms 150
  @snap_threshold 0.03
  @output_integer_tolerance 0.05

  # Analysis thresholds
  @max_discrete_outputs 15
  @min_continuous_unique_outputs 20
  # Threshold for determining if an output range represents a gate (single value)
  # vs linear (range of values). Values rounded to 1 decimal place for comparison.
  @gate_range_threshold 0.1

  defmodule Sample do
    @moduledoc "A single sample from the lever sweep"
    @type t :: %__MODULE__{
            set_input: float(),
            actual_input: float(),
            output: float(),
            snapped: boolean()
          }

    defstruct [:set_input, :actual_input, :output, :snapped]
  end

  defmodule SnapZone do
    @moduledoc "A detected snap zone where input values jump to a fixed position"
    @type t :: %__MODULE__{
            snap_to: float(),
            input_min: float(),
            input_max: float()
          }

    defstruct [:snap_to, :input_min, :input_max]
  end

  defmodule AnalysisResult do
    @moduledoc "The result of lever analysis"
    @type lever_type :: :discrete | :continuous | :hybrid

    @type t :: %__MODULE__{
            lever_type: lever_type(),
            samples: [Sample.t()],
            snap_zones: [SnapZone.t()],
            suggested_notches: [map()],
            min_output: float(),
            max_output: float(),
            unique_output_count: integer(),
            all_outputs_integers: boolean()
          }

    defstruct [
      :lever_type,
      :samples,
      :snap_zones,
      :suggested_notches,
      :min_output,
      :max_output,
      :unique_output_count,
      :all_outputs_integers
    ]
  end

  @doc """
  Analyzes a lever by sweeping through input values and observing behavior.

  Returns `{:ok, AnalysisResult.t()}` on success, or `{:error, reason}` on failure.

  ## Parameters

  - `client` - The simulator client
  - `control_path` - Path to the control (e.g., "CurrentDrivableActor/MasterController")
  - `opts` - Optional configuration:
    - `:sweep_step` - Step size for sweep (default: 0.02)
    - `:settling_time_ms` - Time to wait after setting value (default: 150)
    - `:restore_position` - Input value to restore after analysis (default: nil, keeps last position)

  ## Examples

      {:ok, result} = LeverAnalyzer.analyze(client, "CurrentDrivableActor/MasterController")
      IO.puts("Lever type: \#{result.lever_type}")
      IO.puts("Suggested notches: \#{length(result.suggested_notches)}")
  """
  @spec analyze(Client.t(), String.t(), keyword()) :: {:ok, AnalysisResult.t()} | {:error, term()}
  def analyze(%Client{} = client, control_path, opts \\ []) when is_binary(control_path) do
    sweep_step = Keyword.get(opts, :sweep_step, @sweep_step)
    settling_time = Keyword.get(opts, :settling_time_ms, @settling_time_ms)
    restore_position = Keyword.get(opts, :restore_position, nil)

    Logger.info("[LeverAnalyzer] Starting analysis of #{control_path}")

    with {:ok, samples} <- sweep_lever(client, control_path, sweep_step, settling_time),
         {:ok, result} <- analyze_samples(samples) do
      # Restore lever position if requested
      if restore_position do
        Client.set(client, "#{control_path}.InputValue", restore_position)
      end

      Logger.info(
        "[LeverAnalyzer] Analysis complete: type=#{result.lever_type}, " <>
          "notches=#{length(result.suggested_notches)}, " <>
          "unique_outputs=#{result.unique_output_count}"
      )

      {:ok, result}
    end
  end

  @doc """
  Quick check to determine if a lever appears to be discrete or continuous
  without doing a full sweep. Samples at strategic positions.

  Returns `{:ok, :discrete | :continuous | :unknown}` or `{:error, reason}`.
  """
  @spec quick_check(Client.t(), String.t()) :: {:ok, atom()} | {:error, term()}
  def quick_check(%Client{} = client, control_path) do
    # Sample at strategic positions
    test_points = [0.0, 0.25, 0.5, 0.75, 1.0]

    results =
      Enum.map(test_points, fn input ->
        with {:ok, _} <- Client.set(client, "#{control_path}.InputValue", input),
             :ok <- Process.sleep(100),
             {:ok, output} <-
               Client.get_float(client, "#{control_path}.Function.GetCurrentOutputValue") do
          {:ok, output}
        end
      end)

    if Enum.any?(results, &match?({:error, _}, &1)) do
      {:error, :sample_failed}
    else
      outputs = Enum.map(results, fn {:ok, v} -> v end)
      all_integers = Enum.all?(outputs, &is_integer_value?/1)

      cond do
        all_integers and length(Enum.uniq(outputs)) <= 5 -> {:ok, :discrete}
        not all_integers -> {:ok, :continuous}
        true -> {:ok, :unknown}
      end
    end
  end

  # Sweep the lever from 0.0 to 1.0 and collect samples
  defp sweep_lever(%Client{} = client, control_path, step, settling_time) do
    input_values = generate_sweep_values(step)
    value_endpoint = "#{control_path}.InputValue"
    output_endpoint = "#{control_path}.Function.GetCurrentOutputValue"

    Logger.debug("[LeverAnalyzer] Sweeping #{length(input_values)} positions...")

    samples =
      Enum.reduce_while(input_values, {:ok, []}, fn set_input, {:ok, acc} ->
        case sample_position(client, value_endpoint, output_endpoint, set_input, settling_time) do
          {:ok, sample} ->
            {:cont, {:ok, [sample | acc]}}

          {:error, reason} ->
            Logger.warning("[LeverAnalyzer] Sample failed at #{set_input}: #{inspect(reason)}")
            # Continue despite errors, we may have enough samples
            {:cont, {:ok, acc}}
        end
      end)

    case samples do
      {:ok, sample_list} when length(sample_list) >= 10 ->
        {:ok, Enum.reverse(sample_list)}

      {:ok, _} ->
        {:error, :insufficient_samples}

      error ->
        error
    end
  end

  defp sample_position(client, value_endpoint, output_endpoint, set_input, settling_time) do
    with {:ok, _} <- Client.set(client, value_endpoint, set_input),
         :ok <- Process.sleep(settling_time),
         {:ok, actual_input} <- Client.get_float(client, value_endpoint),
         {:ok, output} <- Client.get_float(client, output_endpoint) do
      snapped = abs(actual_input - set_input) > @snap_threshold

      {:ok,
       %Sample{
         set_input: Float.round(set_input, 2),
         actual_input: Float.round(actual_input, 2),
         output: Float.round(output, 2),
         snapped: snapped
       }}
    end
  end

  defp generate_sweep_values(step) do
    count = round(1.0 / step)

    0..count
    |> Enum.map(fn i -> Float.round(i * step, 2) end)
    |> Enum.filter(&(&1 <= 1.0))
  end

  # Analyze collected samples to determine lever type and generate notch suggestions
  defp analyze_samples(samples) do
    outputs = Enum.map(samples, & &1.output)
    unique_outputs = Enum.uniq(outputs) |> Enum.sort()

    all_integers = Enum.all?(unique_outputs, &is_integer_value?/1)
    unique_count = length(unique_outputs)

    min_output = Enum.min(outputs)
    max_output = Enum.max(outputs)

    snap_zones = detect_snap_zones(samples)

    lever_type = classify_lever_type(unique_count, all_integers, snap_zones)

    suggested_notches = build_notch_suggestions(samples, lever_type, snap_zones)

    {:ok,
     %AnalysisResult{
       lever_type: lever_type,
       samples: samples,
       snap_zones: snap_zones,
       suggested_notches: suggested_notches,
       min_output: min_output,
       max_output: max_output,
       unique_output_count: unique_count,
       all_outputs_integers: all_integers
     }}
  end

  defp classify_lever_type(unique_count, all_integers, snap_zones) do
    has_snap_zones = length(snap_zones) > 1

    cond do
      # Discrete: few unique integer outputs
      all_integers and unique_count <= @max_discrete_outputs ->
        :discrete

      # Continuous: many unique outputs, no significant snapping
      unique_count >= @min_continuous_unique_outputs and not has_snap_zones ->
        :continuous

      # Hybrid: has snap zones but continuous output within zones
      has_snap_zones ->
        :hybrid

      # Default to continuous if many unique values
      unique_count >= @min_continuous_unique_outputs ->
        :continuous

      # Otherwise treat as discrete
      true ->
        :discrete
    end
  end

  defp detect_snap_zones(samples) do
    # Group samples by their actual input value (snapped position)
    samples
    |> Enum.group_by(& &1.actual_input)
    |> Enum.filter(fn {_actual, group} ->
      # A snap zone has multiple set_input values mapping to same actual
      length(group) >= 2
    end)
    |> Enum.map(fn {snap_to, group} ->
      set_inputs = Enum.map(group, & &1.set_input)

      %SnapZone{
        snap_to: snap_to,
        input_min: Enum.min(set_inputs),
        input_max: Enum.max(set_inputs)
      }
    end)
    |> Enum.sort_by(& &1.snap_to)
  end

  defp build_notch_suggestions(samples, :discrete, _snap_zones) do
    # For discrete levers, each unique output is a gate notch
    samples
    |> Enum.group_by(& &1.output)
    |> Enum.map(fn {output, group} ->
      inputs = Enum.map(group, & &1.actual_input)

      %{
        type: :gate,
        value: output,
        input_min: Enum.min(inputs),
        input_max: Enum.max(inputs),
        description: "Output #{output}"
      }
    end)
    |> Enum.sort_by(& &1.input_min)
    |> Enum.with_index()
    |> Enum.map(fn {notch, idx} -> Map.put(notch, :index, idx) end)
  end

  defp build_notch_suggestions(samples, :continuous, _snap_zones) do
    # For continuous levers, create a single linear notch
    outputs = Enum.map(samples, & &1.output)

    [
      %{
        type: :linear,
        index: 0,
        min_value: Enum.min(outputs),
        max_value: Enum.max(outputs),
        input_min: 0.0,
        input_max: 1.0,
        description: "Full range"
      }
    ]
  end

  defp build_notch_suggestions(samples, :hybrid, snap_zones) do
    # For hybrid levers, create linear zones based on snap boundaries
    # or output discontinuities

    if length(snap_zones) >= 2 do
      build_notches_from_snap_zones(samples, snap_zones)
    else
      build_notches_from_output_changes(samples)
    end
  end

  defp build_notches_from_snap_zones(samples, snap_zones) do
    # Sort snap zones by input position
    sorted_zones = Enum.sort_by(snap_zones, & &1.snap_to)

    # Create zones between snap points, determining type based on output range
    sorted_zones
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.with_index()
    |> Enum.map(fn {[zone1, zone2], idx} ->
      # Find samples in this zone
      zone_samples =
        Enum.filter(samples, fn s ->
          s.actual_input >= zone1.snap_to and s.actual_input < zone2.snap_to
        end)

      outputs = Enum.map(zone_samples, & &1.output)

      if length(outputs) > 0 do
        build_notch(outputs, zone1.snap_to, zone2.snap_to, idx, "Zone #{idx}")
      else
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> add_boundary_notches(samples, sorted_zones)
  end

  defp add_boundary_notches(notches, samples, snap_zones) do
    first_zone = List.first(snap_zones)
    last_zone = List.last(snap_zones)

    # Add notch before first snap zone if there's range
    before_first =
      if first_zone && first_zone.snap_to > 0.02 do
        before_samples = Enum.filter(samples, &(&1.actual_input < first_zone.snap_to))
        outputs = Enum.map(before_samples, & &1.output)

        if length(outputs) > 0 do
          [build_notch(outputs, 0.0, first_zone.snap_to, -1, "Before first zone")]
        else
          []
        end
      else
        []
      end

    # Add notch after last snap zone if there's range
    after_last =
      if last_zone && last_zone.snap_to < 0.98 do
        after_samples = Enum.filter(samples, &(&1.actual_input >= last_zone.snap_to))
        outputs = Enum.map(after_samples, & &1.output)

        if length(outputs) > 0 do
          [build_notch(outputs, last_zone.snap_to, 1.0, 999, "After last zone")]
        else
          []
        end
      else
        []
      end

    (before_first ++ notches ++ after_last)
    |> Enum.sort_by(& &1.input_min)
    |> Enum.with_index()
    |> Enum.map(fn {notch, idx} -> %{notch | index: idx} end)
  end

  defp build_notches_from_output_changes(samples) do
    # Detect significant output changes to find zone boundaries
    samples
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce({[], nil}, fn [s1, s2], {boundaries, _prev} ->
      output_change = abs(s2.output - s1.output)

      # Significant change threshold - depends on output range
      if output_change > 1.0 do
        {[s1.actual_input | boundaries], s2}
      else
        {boundaries, s2}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
    |> case do
      [] ->
        # No significant boundaries found, treat as continuous
        build_notch_suggestions(samples, :continuous, [])

      boundaries ->
        # Create zones from boundaries
        all_boundaries = [0.0 | boundaries] ++ [1.0]

        all_boundaries
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.with_index()
        |> Enum.map(fn {[start_input, end_input], idx} ->
          zone_samples =
            Enum.filter(samples, fn s ->
              s.actual_input >= start_input and s.actual_input < end_input
            end)

          outputs = Enum.map(zone_samples, & &1.output)

          if length(outputs) > 0 do
            build_notch(outputs, start_input, end_input, idx, "Zone #{idx}")
          else
            nil
          end
        end)
        |> Enum.reject(&is_nil/1)
    end
  end

  defp is_integer_value?(value) do
    rounded = Float.round(value, 0)
    abs(value - rounded) < @output_integer_tolerance
  end

  # Determines if an output range represents a gate (single value) or linear (range).
  # Rounds to 1 decimal place for comparison to handle floating-point precision issues.
  defp determine_notch_type(min_value, max_value) do
    rounded_min = Float.round(min_value, 1)
    rounded_max = Float.round(max_value, 1)

    if abs(rounded_max - rounded_min) < @gate_range_threshold do
      :gate
    else
      :linear
    end
  end

  # Builds a notch map with the appropriate type based on output range
  defp build_notch(outputs, input_min, input_max, index, description) do
    min_value = Enum.min(outputs)
    max_value = Enum.max(outputs)
    notch_type = determine_notch_type(min_value, max_value)

    case notch_type do
      :gate ->
        # For gates, use the average value as the single "value"
        avg_value = Float.round((min_value + max_value) / 2, 2)

        %{
          type: :gate,
          index: index,
          value: avg_value,
          input_min: input_min,
          input_max: input_max,
          description: description
        }

      :linear ->
        %{
          type: :linear,
          index: index,
          min_value: min_value,
          max_value: max_value,
          input_min: input_min,
          input_max: input_max,
          description: description
        }
    end
  end
end
