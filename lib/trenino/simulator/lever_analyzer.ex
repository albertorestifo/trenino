defmodule Trenino.Simulator.LeverAnalyzer do
  @moduledoc """
  Analyzes lever behavior by sweeping through the input range and detecting
  actual notch positions, snap zones, and output behavior.

  Uses the simulator's GetCurrentNotchIndex as the primary signal for zone
  boundaries, then verifies if boundaries have snap behavior (gates) or are
  continuous (linear zones that should be merged).

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
      # - zones: detected zones
  """

  require Logger

  alias Trenino.Simulator.Client

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
  @gate_range_threshold 0.15

  # Number of rapid commands to push past snap points when initializing
  @push_attempts 5
  # Short delay between push attempts (ms)
  @push_delay_ms 30

  defmodule Sample do
    @moduledoc "A single sample from the lever sweep"
    @type t :: %__MODULE__{
            set_input: float(),
            actual_input: float(),
            output: float(),
            notch_index: integer(),
            snapped: boolean()
          }

    defstruct [:set_input, :actual_input, :output, :notch_index, :snapped]
  end

  defmodule Zone do
    @moduledoc """
    A detected output zone with its associated input range.
    """
    @type zone_type :: :gate | :linear

    @type t :: %__MODULE__{
            type: zone_type(),
            # For gates: the single output value
            value: float() | nil,
            # Output value range in this zone
            output_min: float(),
            output_max: float(),
            # The set_input range that produces this zone
            set_input_min: float(),
            set_input_max: float(),
            # The actual_input range observed in this zone
            actual_input_min: float(),
            actual_input_max: float(),
            # The notch indices that were merged into this zone
            notch_indices: [integer()]
          }

    defstruct [
      :type,
      :value,
      :output_min,
      :output_max,
      :set_input_min,
      :set_input_max,
      :actual_input_min,
      :actual_input_max,
      :notch_indices
    ]
  end

  defmodule AnalysisResult do
    @moduledoc "The result of lever analysis"
    @type lever_type :: :discrete | :continuous | :hybrid

    @type t :: %__MODULE__{
            lever_type: lever_type(),
            samples: [Sample.t()],
            zones: [Zone.t()],
            suggested_notches: [map()],
            min_output: float(),
            max_output: float(),
            unique_output_count: integer(),
            all_outputs_integers: boolean()
          }

    defstruct [
      :lever_type,
      :samples,
      :zones,
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
          "zones=#{length(result.zones)}, " <>
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
             :ok <- Process.sleep(100) do
          Client.get_float(client, "#{control_path}.Function.GetCurrentOutputValue")
        end
      end)

    if Enum.any?(results, &match?({:error, _}, &1)) do
      {:error, :sample_failed}
    else
      outputs = Enum.map(results, fn {:ok, v} -> v end)
      all_integers = Enum.all?(outputs, &integer_value?/1)

      cond do
        all_integers and length(Enum.uniq(outputs)) <= 5 -> {:ok, :discrete}
        not all_integers -> {:ok, :continuous}
        true -> {:ok, :unknown}
      end
    end
  end

  # ===========================================================================
  # Sweep and Sampling
  # ===========================================================================

  # Sweep the lever from 0.0 to 1.0 and collect samples with notch index
  defp sweep_lever(%Client{} = client, control_path, step, settling_time) do
    input_values = generate_sweep_values(step)
    value_endpoint = "#{control_path}.InputValue"
    output_endpoint = "#{control_path}.Function.GetCurrentOutputValue"
    notch_endpoint = "#{control_path}.Function.GetCurrentNotchIndex"

    # Initialize lever to 0.0, pushing past any snap points
    initialize_lever_position(client, value_endpoint, settling_time)

    Logger.debug("[LeverAnalyzer] Sweeping #{length(input_values)} positions...")

    samples =
      Enum.reduce_while(input_values, {:ok, []}, fn set_input, {:ok, acc} ->
        case sample_position(
               client,
               value_endpoint,
               output_endpoint,
               notch_endpoint,
               set_input,
               settling_time
             ) do
          {:ok, sample} ->
            {:cont, {:ok, [sample | acc]}}

          {:error, reason} ->
            Logger.warning("[LeverAnalyzer] Sample failed at #{set_input}: #{inspect(reason)}")
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

  defp initialize_lever_position(%Client{} = client, value_endpoint, settling_time) do
    Logger.debug("[LeverAnalyzer] Initializing lever to 0.0 position...")

    for _ <- 1..@push_attempts do
      Client.set(client, value_endpoint, 0.0)
      Process.sleep(@push_delay_ms)
    end

    Process.sleep(settling_time)
  end

  defp sample_position(
         client,
         value_endpoint,
         output_endpoint,
         notch_endpoint,
         set_input,
         settling_time
       ) do
    with {:ok, _} <- Client.set(client, value_endpoint, set_input),
         :ok <- Process.sleep(settling_time),
         {:ok, actual_input} <- Client.get_float(client, value_endpoint),
         {:ok, output} <- Client.get_float(client, output_endpoint),
         {:ok, notch_index} <- Client.get_float(client, notch_endpoint) do
      snapped = abs(actual_input - set_input) > @snap_threshold

      {:ok,
       %Sample{
         set_input: Float.round(set_input, 2),
         actual_input: Float.round(actual_input, 2),
         output: Float.round(output, 2),
         notch_index: round(notch_index),
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

  # ===========================================================================
  # Sample Analysis - Notch-Based Zone Detection
  # ===========================================================================

  @doc """
  Analyzes pre-collected samples to determine lever type and zones.

  This function is useful for testing the analysis logic directly without
  performing I/O operations (HTTP requests and sleeps).

  Returns `{:ok, AnalysisResult.t()}`.

  ## Parameters

  - `samples` - List of `Sample.t()` structs representing lever positions

  ## Examples

      samples = [
        %Sample{set_input: 0.0, actual_input: 0.0, output: -1.0, notch_index: 0, snapped: true},
        %Sample{set_input: 0.5, actual_input: 0.5, output: 0.0, notch_index: 1, snapped: true},
        %Sample{set_input: 1.0, actual_input: 1.0, output: 1.0, notch_index: 2, snapped: true}
      ]
      {:ok, result} = LeverAnalyzer.analyze_samples(samples)
  """
  @spec analyze_samples([Sample.t()]) :: {:ok, AnalysisResult.t()}
  def analyze_samples(samples) when is_list(samples) do
    outputs = Enum.map(samples, & &1.output)
    unique_outputs = Enum.uniq(outputs) |> Enum.sort()

    all_integers = Enum.all?(unique_outputs, &integer_value?/1)
    unique_count = length(unique_outputs)

    min_output = Enum.min(outputs)
    max_output = Enum.max(outputs)

    # Group samples by notch_index (the API's zone boundaries)
    notch_groups = group_by_notch_index(samples)

    Logger.debug("[LeverAnalyzer] API reports #{map_size(notch_groups)} notch groups")

    # Merge continuous notch groups (no snap at boundary)
    zones = merge_continuous_notches(notch_groups)

    Logger.debug("[LeverAnalyzer] After merging: #{length(zones)} zones")

    lever_type = classify_lever_type(unique_count, all_integers, zones)

    suggested_notches = build_notches_from_zones(zones)

    {:ok,
     %AnalysisResult{
       lever_type: lever_type,
       samples: samples,
       zones: zones,
       suggested_notches: suggested_notches,
       min_output: min_output,
       max_output: max_output,
       unique_output_count: unique_count,
       all_outputs_integers: all_integers
     }}
  end

  defp group_by_notch_index(samples) do
    samples
    |> Enum.group_by(& &1.notch_index)
    |> Enum.map(fn {notch_index, group} ->
      {notch_index, Enum.sort_by(group, & &1.set_input)}
    end)
    |> Enum.into(%{})
  end

  # Merge adjacent notch groups that don't have snap behavior at their boundary
  defp merge_continuous_notches(notch_groups) do
    # Sort by the minimum set_input in each group
    sorted_notches =
      notch_groups
      |> Enum.map(fn {notch_index, samples} ->
        {notch_index, samples, Enum.min_by(samples, & &1.set_input).set_input}
      end)
      |> Enum.sort_by(fn {_idx, _samples, min_input} -> min_input end)

    # Process notches, merging those without snap boundaries
    sorted_notches
    |> Enum.reduce([], fn {notch_index, samples, _min_input}, acc ->
      case acc do
        [] ->
          [create_zone_from_samples(samples, [notch_index])]

        [current_zone | rest] ->
          # Check if there's a snap boundary between current zone and this notch
          if has_snap_boundary?(current_zone, samples) do
            # Real boundary - create new zone
            [create_zone_from_samples(samples, [notch_index]), current_zone | rest]
          else
            # No snap - merge into current zone
            merged = merge_zone_with_samples(current_zone, samples, notch_index)
            [merged | rest]
          end
      end
    end)
    |> Enum.reverse()
  end

  # Check if there's a snap boundary between a zone and the next samples
  defp has_snap_boundary?(%Zone{} = zone, next_samples) do
    # Get the last actual_input in the current zone
    zone_end_actual = zone.actual_input_max

    # Get the first actual_input in the next samples
    first_next = Enum.min_by(next_samples, & &1.set_input)
    next_start_actual = first_next.actual_input

    # If actual_input jumps significantly, there's a snap boundary
    # This indicates a gate transition
    actual_diff = abs(next_start_actual - zone_end_actual)

    has_snap = actual_diff > @snap_threshold

    if has_snap do
      Logger.debug(
        "[LeverAnalyzer] Snap boundary detected: actual_diff=#{Float.round(actual_diff, 2)}"
      )
    end

    has_snap
  end

  defp create_zone_from_samples(samples, notch_indices) do
    outputs = Enum.map(samples, & &1.output)
    set_inputs = Enum.map(samples, & &1.set_input)
    actual_inputs = Enum.map(samples, & &1.actual_input)

    output_min = Enum.min(outputs)
    output_max = Enum.max(outputs)

    zone_type = determine_zone_type(output_min, output_max)

    %Zone{
      type: zone_type,
      value: if(zone_type == :gate, do: Float.round((output_min + output_max) / 2, 2), else: nil),
      output_min: output_min,
      output_max: output_max,
      set_input_min: Enum.min(set_inputs),
      set_input_max: Enum.max(set_inputs),
      actual_input_min: Enum.min(actual_inputs),
      actual_input_max: Enum.max(actual_inputs),
      notch_indices: notch_indices
    }
  end

  defp merge_zone_with_samples(%Zone{} = zone, samples, notch_index) do
    outputs = Enum.map(samples, & &1.output)
    set_inputs = Enum.map(samples, & &1.set_input)
    actual_inputs = Enum.map(samples, & &1.actual_input)

    output_min = min(zone.output_min, Enum.min(outputs))
    output_max = max(zone.output_max, Enum.max(outputs))

    zone_type = determine_zone_type(output_min, output_max)

    %Zone{
      type: zone_type,
      value: if(zone_type == :gate, do: Float.round((output_min + output_max) / 2, 2), else: nil),
      output_min: output_min,
      output_max: output_max,
      set_input_min: min(zone.set_input_min, Enum.min(set_inputs)),
      set_input_max: max(zone.set_input_max, Enum.max(set_inputs)),
      actual_input_min: min(zone.actual_input_min, Enum.min(actual_inputs)),
      actual_input_max: max(zone.actual_input_max, Enum.max(actual_inputs)),
      notch_indices: zone.notch_indices ++ [notch_index]
    }
  end

  defp determine_zone_type(min_value, max_value) do
    rounded_min = Float.round(min_value, 1)
    rounded_max = Float.round(max_value, 1)

    if abs(rounded_max - rounded_min) < @gate_range_threshold do
      :gate
    else
      :linear
    end
  end

  defp classify_lever_type(unique_count, all_integers, zones) do
    has_snap_zones = Enum.any?(zones, fn z -> z.type == :gate end)
    has_linear_zones = Enum.any?(zones, fn z -> z.type == :linear end)

    cond do
      # Discrete: few unique integer outputs, all gates
      all_integers and unique_count <= @max_discrete_outputs and not has_linear_zones ->
        :discrete

      # Continuous: many unique outputs, no gates
      unique_count >= @min_continuous_unique_outputs and not has_snap_zones ->
        :continuous

      # Hybrid: mix of gates and linear zones
      has_snap_zones and has_linear_zones ->
        :hybrid

      # Default to continuous if many unique values
      unique_count >= @min_continuous_unique_outputs ->
        :continuous

      # Otherwise treat as discrete
      true ->
        :discrete
    end
  end

  defp integer_value?(value) do
    rounded = Float.round(value, 0)
    abs(value - rounded) < @output_integer_tolerance
  end

  # Build notch suggestions from the detected zones
  defp build_notches_from_zones(zones) do
    zones
    |> Enum.sort_by(& &1.set_input_min)
    |> Enum.with_index()
    |> Enum.map(fn {zone, idx} ->
      case zone.type do
        :gate ->
          %{
            type: :gate,
            index: idx,
            value: zone.value,
            input_min: zone.set_input_min,
            input_max: zone.set_input_max,
            actual_input_min: zone.actual_input_min,
            actual_input_max: zone.actual_input_max,
            description: "Gate at output #{zone.value}"
          }

        :linear ->
          %{
            type: :linear,
            index: idx,
            min_value: zone.output_min,
            max_value: zone.output_max,
            input_min: zone.set_input_min,
            input_max: zone.set_input_max,
            actual_input_min: zone.actual_input_min,
            actual_input_max: zone.actual_input_max,
            description: "Linear #{zone.output_min} to #{zone.output_max}"
          }
      end
    end)
  end
end
