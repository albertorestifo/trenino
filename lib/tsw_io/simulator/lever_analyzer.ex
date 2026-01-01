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
  # Threshold for rough detection of output discontinuities (jumps between zones)
  # Use lower value (0.4) to over-detect boundaries, then verify with snap-back testing
  @output_discontinuity_threshold 0.4
  # Threshold for merging adjacent gates with similar output values
  @gate_merge_threshold 0.2
  # Boundary verification: step size for testing snap-back
  @boundary_test_step 0.01
  # Boundary verification: number of steps to test around boundary
  @boundary_test_range 3

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

  defmodule Zone do
    @moduledoc """
    A detected output zone with its associated input range.

    Zones are detected by output discontinuities, not by input snapping.
    This properly handles snap-back artifacts where the lever briefly visits
    an intermediate position before snapping to the target.
    """
    @type zone_type :: :gate | :linear

    @type t :: %__MODULE__{
            type: zone_type(),
            # For gates: the single output value
            # For linear: ignored (use output_min/output_max)
            value: float() | nil,
            # Output value range in this zone
            output_min: float(),
            output_max: float(),
            # The set_input range that reliably produces this zone
            set_input_min: float(),
            set_input_max: float(),
            # The actual_input range observed in this zone
            actual_input_min: float(),
            actual_input_max: float()
          }

    defstruct [
      :type,
      :value,
      :output_min,
      :output_max,
      :set_input_min,
      :set_input_max,
      :actual_input_min,
      :actual_input_max
    ]
  end

  defmodule AnalysisResult do
    @moduledoc "The result of lever analysis"
    @type lever_type :: :discrete | :continuous | :hybrid

    @type t :: %__MODULE__{
            lever_type: lever_type(),
            samples: [Sample.t()],
            snap_zones: [SnapZone.t()],
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
      :snap_zones,
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
    value_endpoint = "#{control_path}.InputValue"

    with {:ok, samples} <- sweep_lever(client, control_path, sweep_step, settling_time),
         {:ok, result} <- analyze_samples_with_verification(client, value_endpoint, samples, settling_time) do
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

  # Number of rapid commands to push past snap points when initializing
  @push_attempts 5
  # Short delay between push attempts (ms)
  @push_delay_ms 30

  # Sweep the lever from 0.0 to 1.0 and collect samples
  defp sweep_lever(%Client{} = client, control_path, step, settling_time) do
    input_values = generate_sweep_values(step)
    value_endpoint = "#{control_path}.InputValue"
    output_endpoint = "#{control_path}.Function.GetCurrentOutputValue"

    # Initialize lever to 0.0, pushing past any snap points
    initialize_lever_position(client, value_endpoint, settling_time)

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

  # Push the lever to 0.0 position, using rapid commands to overcome snap points.
  # Some levers (like the BR430 MasterController) have snap zones that "catch" the
  # lever when moving smoothly from neutral. Rapid-fire commands can push past these.
  defp initialize_lever_position(%Client{} = client, value_endpoint, settling_time) do
    Logger.debug("[LeverAnalyzer] Initializing lever to 0.0 position...")

    # Send multiple rapid commands to push past snap points
    for _ <- 1..@push_attempts do
      Client.set(client, value_endpoint, 0.0)
      Process.sleep(@push_delay_ms)
    end

    # Wait for lever to fully settle
    Process.sleep(settling_time)
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

  # Analyze collected samples with boundary verification using snap-back testing
  defp analyze_samples_with_verification(client, value_endpoint, samples, settling_time) do
    outputs = Enum.map(samples, & &1.output)
    unique_outputs = Enum.uniq(outputs) |> Enum.sort()

    all_integers = Enum.all?(unique_outputs, &is_integer_value?/1)
    unique_count = length(unique_outputs)

    min_output = Enum.min(outputs)
    max_output = Enum.max(outputs)

    snap_zones = detect_snap_zones(samples)

    lever_type = classify_lever_type(unique_count, all_integers, snap_zones)

    # Step 1: Rough detection with low threshold (over-detect boundaries)
    initial_zones = detect_output_zones(samples)

    Logger.debug("[LeverAnalyzer] Initial detection found #{length(initial_zones)} zones")

    # Step 2: Verify boundaries using snap-back testing and merge false boundaries
    zones = verify_and_merge_zones(client, value_endpoint, initial_zones, settling_time)

    Logger.debug("[LeverAnalyzer] After verification: #{length(zones)} zones")

    # Build notch suggestions from zones (with proper input mappings)
    suggested_notches = build_notches_from_zones(zones)

    {:ok,
     %AnalysisResult{
       lever_type: lever_type,
       samples: samples,
       snap_zones: snap_zones,
       zones: zones,
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

  # NOTE: The old build_notch_suggestions functions have been replaced by
  # the output-based zone detection below. Keeping is_integer_value? and
  # determine_notch_type as they are still used.

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

  # ============================================================================
  # Output-based zone detection
  #
  # This approach detects zones by looking at output value discontinuities,
  # not by input snapping. This properly handles:
  # - Snap-back artifacts (lever briefly visits intermediate position)
  # - Adjacent gates with similar values that should be merged
  # ============================================================================

  @doc false
  # Detect zones by finding output discontinuities in the sweep samples.
  # Returns a list of Zone structs with proper input mappings.
  defp detect_output_zones(samples) do
    samples
    |> group_by_output_continuity()
    |> merge_similar_gates()
    |> convert_to_zones()
    |> Enum.sort_by(& &1.set_input_min)
  end

  # Group consecutive samples that have continuous output values (no jumps)
  defp group_by_output_continuity(samples) do
    samples
    |> Enum.reduce([], fn sample, acc ->
      case acc do
        [] ->
          [[sample]]

        [current_group | rest] ->
          # Get the most recent sample (head since we prepend)
          last_sample = hd(current_group)

          # Check if this sample is continuous with the previous one
          if continuous_output?(last_sample, sample) do
            [[sample | current_group] | rest]
          else
            # Start a new group
            [[sample], current_group | rest]
          end
      end
    end)
    |> Enum.map(&Enum.reverse/1)
    |> Enum.reverse()
  end

  # Two samples are continuous if their outputs don't jump significantly
  defp continuous_output?(sample1, sample2) do
    abs(sample2.output - sample1.output) < @output_discontinuity_threshold
  end

  # Merge adjacent groups that are both gates with similar output values.
  # This handles the snap-back artifact where we get two tiny groups
  # around a gate position.
  defp merge_similar_gates(groups) do
    groups
    |> Enum.reduce([], fn group, acc ->
      case acc do
        [] ->
          [group]

        [prev_group | rest] ->
          prev_outputs = Enum.map(prev_group, & &1.output)
          curr_outputs = Enum.map(group, & &1.output)

          prev_min = Enum.min(prev_outputs)
          prev_max = Enum.max(prev_outputs)
          curr_min = Enum.min(curr_outputs)
          curr_max = Enum.max(curr_outputs)

          prev_is_gate = abs(prev_max - prev_min) < @gate_range_threshold
          curr_is_gate = abs(curr_max - curr_min) < @gate_range_threshold

          # Merge if both are gates with similar values
          if prev_is_gate and curr_is_gate and
               abs(prev_min - curr_min) < @gate_merge_threshold do
            [prev_group ++ group | rest]
          else
            [group, prev_group | rest]
          end
      end
    end)
    |> Enum.reverse()
  end

  # Convert sample groups to Zone structs
  defp convert_to_zones(groups) do
    Enum.map(groups, fn samples ->
      outputs = Enum.map(samples, & &1.output)
      set_inputs = Enum.map(samples, & &1.set_input)
      actual_inputs = Enum.map(samples, & &1.actual_input)

      output_min = Enum.min(outputs)
      output_max = Enum.max(outputs)

      zone_type = determine_notch_type(output_min, output_max)

      %Zone{
        type: zone_type,
        value: if(zone_type == :gate, do: Float.round((output_min + output_max) / 2, 2), else: nil),
        output_min: output_min,
        output_max: output_max,
        set_input_min: Enum.min(set_inputs),
        set_input_max: Enum.max(set_inputs),
        actual_input_min: Enum.min(actual_inputs),
        actual_input_max: Enum.max(actual_inputs)
      }
    end)
  end

  # ============================================================================
  # Boundary verification using snap-back testing
  #
  # After rough zone detection, we verify each boundary by testing snap-back
  # behavior. At a real boundary (e.g., gate→linear), the actual_input will
  # snap back when we try to cross. At a false boundary (artifact from rough
  # detection), the transition is continuous.
  # ============================================================================

  # Verify zone boundaries and merge zones that don't have real snap-back behavior
  defp verify_and_merge_zones(_client, _value_endpoint, zones, _settling_time)
       when length(zones) <= 1 do
    zones
  end

  defp verify_and_merge_zones(client, value_endpoint, zones, settling_time) do
    sorted_zones = Enum.sort_by(zones, & &1.set_input_min)

    # Test each boundary between adjacent zones
    sorted_zones
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce([hd(sorted_zones)], fn [_zone1, zone2], acc ->
      current_zone = hd(acc)

      # Get the boundary point between zones
      boundary_input = (current_zone.set_input_max + zone2.set_input_min) / 2

      # Test if there's snap-back at this boundary
      if has_snap_back?(client, value_endpoint, boundary_input, settling_time) do
        # Real boundary - keep zones separate
        [zone2 | acc]
      else
        # False boundary - merge zones
        merged = merge_two_zones(current_zone, zone2)
        [merged | tl(acc)]
      end
    end)
    |> Enum.reverse()
  end

  # Test if there's a real boundary at a point.
  # A real boundary exists if:
  # 1. There's snap-back behavior (actual_input differs when approaching from different sides)
  # 2. OR outputs differ significantly (even without snap-back, like discrete levers)
  defp has_snap_back?(client, value_endpoint, boundary_input, settling_time) do
    output_endpoint = String.replace(value_endpoint, ".InputValue", ".Function.GetCurrentOutputValue")

    # Test approaching from below (lower input value moving up)
    below_result = test_boundary_from_direction(client, value_endpoint, output_endpoint, boundary_input, settling_time, :below)

    # Test approaching from above (higher input value moving down)
    above_result = test_boundary_from_direction(client, value_endpoint, output_endpoint, boundary_input, settling_time, :above)

    case {below_result, above_result} do
      {{:ok, below_actual, below_output}, {:ok, above_actual, above_output}} ->
        # Check for snap-back (actual_input differs significantly)
        snap_detected = abs(below_actual - above_actual) > @snap_threshold

        # Only use output difference as fallback for discrete levers (no snap zones)
        # Use a high threshold (0.8) to avoid false positives in linear zones
        output_diff = abs(below_output - above_output)
        large_output_boundary = output_diff > 0.8

        # A boundary is real if:
        # 1. There's snap-back (primary detection for hybrid levers with snap zones)
        # 2. OR there's a large output jump (fallback for discrete levers without snap zones)
        is_real_boundary = snap_detected or large_output_boundary

        Logger.debug(
          "[LeverAnalyzer] Boundary at #{Float.round(boundary_input, 2)}: " <>
            "snap=#{snap_detected}, output_diff=#{Float.round(output_diff, 2)}, real=#{is_real_boundary}"
        )

        is_real_boundary

      _ ->
        # If we can't test, assume it's a real boundary to be safe
        Logger.warning("[LeverAnalyzer] Could not test boundary at #{boundary_input}, assuming real")
        true
    end
  end

  # Test boundary from a specific direction, returning both actual_input and output
  defp test_boundary_from_direction(client, value_endpoint, output_endpoint, boundary_input, settling_time, direction) do
    {start_input, test_input} =
      case direction do
        :below ->
          # Start well below boundary, test just past
          {max(0.0, boundary_input - @boundary_test_range * @boundary_test_step),
           min(1.0, boundary_input + @boundary_test_step)}

        :above ->
          # Start well above boundary, test just before
          {min(1.0, boundary_input + @boundary_test_range * @boundary_test_step),
           max(0.0, boundary_input - @boundary_test_step)}
      end

    # First, position lever at starting point
    Client.set(client, value_endpoint, start_input)
    Process.sleep(settling_time)

    # Now move to test position and read both actual_input and output
    with {:ok, _} <- Client.set(client, value_endpoint, test_input),
         :ok <- Process.sleep(settling_time),
         {:ok, actual} <- Client.get_float(client, value_endpoint),
         {:ok, output} <- Client.get_float(client, output_endpoint) do
      {:ok, actual, output}
    else
      _ -> :error
    end
  end

  # Merge two adjacent zones into one
  defp merge_two_zones(%Zone{} = zone1, %Zone{} = zone2) do
    output_min = min(zone1.output_min, zone2.output_min)
    output_max = max(zone1.output_max, zone2.output_max)
    zone_type = determine_notch_type(output_min, output_max)

    %Zone{
      type: zone_type,
      value: if(zone_type == :gate, do: Float.round((output_min + output_max) / 2, 2), else: nil),
      output_min: output_min,
      output_max: output_max,
      set_input_min: min(zone1.set_input_min, zone2.set_input_min),
      set_input_max: max(zone1.set_input_max, zone2.set_input_max),
      actual_input_min: min(zone1.actual_input_min, zone2.actual_input_min),
      actual_input_max: max(zone1.actual_input_max, zone2.actual_input_max)
    }
  end

  # Build notch suggestions from the detected zones.
  # This provides the legacy format expected by the calibration system.
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
