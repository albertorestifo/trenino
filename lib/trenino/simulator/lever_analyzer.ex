defmodule Trenino.Simulator.LeverAnalyzer do
  @moduledoc """
  Analyzes lever behavior by sweeping through the input range and detecting
  actual notch positions, snap zones, and output behavior.

  Uses the simulator's GetCurrentNotchIndex as the first signal for zone
  boundaries, then decides which boundaries are real:

  - The simulator gives the ends of a linear range their own notch index and
    snaps nearby inputs onto them (for example "Max Brake" and "Min Brake").
    These are merged into the linear zone when the output carries on from it,
    or when they produce the same output as the end of the range.
  - A gate keeps its own notch when the output jumps, or when the inputs
    between it and its neighbour cannot be reached.
  - One notch index can hold several output steps while the input moves freely
    (for example power notches 1-4). These are split into one gate per step.

  Notches are named from the lever's in-game labels when they are available
  (see `Trenino.Simulator.LeverMetadata`).

  ## Lever Types Detected

  - `:discrete` - True notched lever with fixed integer output values
    (e.g., Reverser with outputs -2, -1, 0, 1)
  - `:continuous` - Smooth lever with fractional output values across the range
    (e.g., throttle with outputs 0.0 to 1.0 with many intermediate values)
  - `:hybrid` - Lever with snap zones and continuous zones
    (e.g., BR430 MasterController: Emergency, Brake range, Off, Power range)

  ## Safety

  A sweep moves the lever in the simulator, so it can apply power and move the
  train. `analyze/3` refuses to start when the train is moving, stops when the
  train speeds up past `:max_speed`, and always puts the lever back where it
  was. Only one sweep per control runs at a time.

  ## Usage

      {:ok, result} = LeverAnalyzer.analyze(client, "CurrentDrivableActor/MasterController")

      # result contains:
      # - lever_type: :discrete | :continuous | :hybrid
      # - suggested_notches: list of notch configurations
      # - samples: raw sample data
      # - zones: detected zones
      # - warnings: things the driver should know (blocked ranges, spring-loaded positions)
  """

  require Logger

  alias Trenino.Simulator.Client
  alias Trenino.Simulator.LeverMetadata
  alias Trenino.Simulator.LeverMetadata.Label

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
  # Two outputs closer than this are the same position
  @same_output_tolerance 0.02
  # Inputs further apart than max(this, 1.5 × sweep step) cannot be reached between them
  @min_merge_gap 0.03
  # A labelled output range missed by more than this means part of the lever was blocked
  @coverage_tolerance 0.5

  # Gates often need several rapid sets before the lever enters them
  @push_attempts 5
  # Fewer during the sweep, where it runs for every sample that stops short
  @sweep_push_attempts 3
  @push_delay_ms 30

  # Safety
  @speed_endpoint "CurrentDrivableActor.Function.HUD_GetSpeed"
  @stopped_speed 0.5
  @default_max_speed 2.0

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
    alias Trenino.Simulator.LeverAnalyzer.Sample

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
            # The actual_input range observed in this zone. This is what gets
            # sent to the simulator: a gate's position, or a linear zone's
            # reachable range.
            actual_input_min: float(),
            actual_input_max: float(),
            # The notch indices that were merged into this zone
            notch_indices: [integer()],
            samples: [Sample.t()]
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
      :notch_indices,
      samples: []
    ]
  end

  defmodule AnalysisResult do
    @moduledoc "The result of lever analysis"
    alias Trenino.Simulator.LeverAnalyzer
    alias Trenino.Simulator.LeverMetadata

    @type lever_type :: :discrete | :continuous | :hybrid

    @type t :: %__MODULE__{
            lever_type: lever_type(),
            samples: [LeverAnalyzer.Sample.t()],
            zones: [LeverAnalyzer.Zone.t()],
            suggested_notches: [LeverAnalyzer.suggested_notch()],
            min_output: float(),
            max_output: float(),
            unique_output_count: integer(),
            all_outputs_integers: boolean(),
            warnings: [String.t()],
            metadata: LeverMetadata.t() | nil
          }

    defstruct [
      :lever_type,
      :samples,
      :zones,
      :suggested_notches,
      :min_output,
      :max_output,
      :unique_output_count,
      :all_outputs_integers,
      :metadata,
      warnings: []
    ]
  end

  @typedoc """
  A notch suggestion. `input_min`/`input_max` are simulator InputValues
  (saved as the notch's `sim_input_min`/`sim_input_max`).
  """
  @type suggested_notch :: %{
          required(:type) => :gate | :linear,
          required(:index) => non_neg_integer(),
          required(:input_min) => float(),
          required(:input_max) => float(),
          required(:actual_input_min) => float(),
          required(:actual_input_max) => float(),
          required(:description) => String.t(),
          optional(:value) => float(),
          optional(:min_value) => float(),
          optional(:max_value) => float()
        }

  @doc """
  Analyzes a lever by sweeping through input values and observing behavior.

  Returns `{:ok, AnalysisResult.t()}` on success, or `{:error, reason}`:

  - `:train_not_stopped` - the train was moving before the sweep started
  - `:train_moving` - the train sped up past `:max_speed` during the sweep
  - `:calibration_running` - another sweep of this control is running
  - `:insufficient_samples` - the simulator answered too few samples
  - `:position_unreadable` - the lever's position could not be read, so it could not be restored
  - `:speed_unavailable` - the speed could not be read and `:require_speed_guard` is set

  ## Options

    - `:sweep_step` - Step size for sweep (default: #{@sweep_step})
    - `:settling_time_ms` - Time to wait after setting value (default: #{@settling_time_ms})
    - `:push_delay_ms` - Delay between repeated sets into a gate (default: #{@push_delay_ms})
    - `:restore_position` - `:original` (default) puts the lever back where it was,
      a number moves it there, `nil` leaves it at the end of the sweep
    - `:max_speed` - Speed in m/s that stops the sweep (default: #{@default_max_speed})
    - `:require_speed_guard` - refuse with `:speed_unavailable` when the speed
      cannot be read (default: false, which sweeps with a warning)
  """
  @spec analyze(Client.t(), String.t(), keyword()) :: {:ok, AnalysisResult.t()} | {:error, term()}
  def analyze(%Client{} = client, control_path, opts \\ []) when is_binary(control_path) do
    # `config :trenino, :lever_analyzer, settling_time_ms: 0` speeds up tests
    opts = Keyword.merge(Application.get_env(:trenino, :lever_analyzer, []), opts)
    lock = {{__MODULE__, control_path}, self()}

    if :global.set_lock(lock, [node()], 0) do
      try do
        do_analyze(client, control_path, opts)
      after
        :global.del_lock(lock, [node()])
      end
    else
      {:error, :calibration_running}
    end
  end

  defp do_analyze(client, control_path, opts) do
    Logger.info("[LeverAnalyzer] Starting analysis of #{control_path}")

    metadata =
      case LeverMetadata.read(client, control_path) do
        {:ok, metadata} -> metadata
        _ -> nil
      end

    restore_position = Keyword.get(opts, :restore_position, :original)

    result =
      with {:ok, speed_check} <- check_stopped(client),
           :ok <- check_speed_guard(speed_check, opts),
           ctx = build_context(client, control_path, opts, speed_check),
           {:ok, original} <- read_original(client, ctx.value_endpoint, restore_position) do
        try do
          with {:ok, samples} <- sweep_lever(ctx) do
            analyze_samples(samples,
              metadata: metadata,
              sweep_step: ctx.step,
              warnings: speed_warnings(speed_check)
            )
          end
        after
          restore(ctx, restore_position, original)
        end
      end

    log_result(result)
  end

  defp build_context(client, control_path, opts, speed_check) do
    %{
      client: client,
      control_path: control_path,
      value_endpoint: "#{control_path}.InputValue",
      output_endpoint: "#{control_path}.Function.GetCurrentOutputValue",
      notch_endpoint: "#{control_path}.Function.GetCurrentNotchIndex",
      step: Keyword.get(opts, :sweep_step, @sweep_step),
      settling: Keyword.get(opts, :settling_time_ms, @settling_time_ms),
      push_delay: Keyword.get(opts, :push_delay_ms, @push_delay_ms),
      max_speed: Keyword.get(opts, :max_speed, @default_max_speed),
      speed_guard?: speed_check == :stopped
    }
  end

  defp log_result({:ok, %AnalysisResult{} = result} = ok) do
    Logger.info(
      "[LeverAnalyzer] Analysis complete: type=#{result.lever_type}, " <>
        "zones=#{length(result.zones)}, unique_outputs=#{result.unique_output_count}, " <>
        "warnings=#{length(result.warnings)}"
    )

    ok
  end

  defp log_result(error), do: error

  @quick_check_delay_ms 100

  @doc """
  Quick check to determine if a lever appears to be discrete or continuous
  without doing a full sweep. Samples at strategic positions.

  Returns `{:ok, :discrete | :continuous | :unknown}` or `{:error, reason}`.

  ## Options

    * `:delay_ms` - Delay between setting input and reading output (default: #{@quick_check_delay_ms}ms).
      Use 0 in tests to speed up execution.
  """
  @spec quick_check(Client.t(), String.t(), keyword()) :: {:ok, atom()} | {:error, term()}
  def quick_check(%Client{} = client, control_path, opts \\ []) do
    delay_ms = Keyword.get(opts, :delay_ms, @quick_check_delay_ms)

    # Sample at strategic positions
    test_points = [0.0, 0.25, 0.5, 0.75, 1.0]

    results =
      Enum.map(test_points, fn input ->
        with {:ok, _} <- Client.set(client, "#{control_path}.InputValue", input),
             :ok <- sleep(delay_ms) do
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
  # Safety
  # ===========================================================================

  # Returns {:ok, :stopped} when the speed reads as stopped, {:ok, :unknown}
  # when the simulator does not expose a speed, and an error when moving.
  defp check_stopped(client) do
    case read_speed(client) do
      {:ok, speed} when abs(speed) > @stopped_speed -> {:error, :train_not_stopped}
      {:ok, _speed} -> {:ok, :stopped}
      :unknown -> {:ok, :unknown}
    end
  end

  # MCP sweeps must not run without the speed guard
  defp check_speed_guard(:unknown, opts) do
    if Keyword.get(opts, :require_speed_guard, false),
      do: {:error, :speed_unavailable},
      else: :ok
  end

  defp check_speed_guard(_speed_check, _opts), do: :ok

  # Without the starting position the lever cannot be put back, and it would be
  # left at the end of the sweep (full power on many levers), so do not sweep.
  defp read_original(client, value_endpoint, :original) do
    case read_input(client, value_endpoint) do
      nil -> {:error, :position_unreadable}
      value -> {:ok, value}
    end
  end

  defp read_original(_client, _value_endpoint, _restore_position), do: {:ok, nil}

  defp speed_warnings(:stopped), do: []

  defp speed_warnings(:unknown) do
    ["The train's speed could not be read, so the sweep ran without the speed guard."]
  end

  defp read_speed(client) do
    case Client.get_float(client, @speed_endpoint) do
      {:ok, speed} when is_number(speed) -> {:ok, speed}
      _ -> :unknown
    end
  end

  defp train_too_fast?(%{speed_guard?: false}), do: false

  defp train_too_fast?(%{client: client, max_speed: max_speed}) do
    case read_speed(client) do
      {:ok, speed} -> abs(speed) > max_speed
      :unknown -> false
    end
  end

  defp read_input(client, value_endpoint) do
    case Client.get_float(client, value_endpoint) do
      {:ok, value} -> value
      _ -> nil
    end
  end

  defp restore(_ctx, nil, _original), do: :ok
  defp restore(_ctx, :original, nil), do: :ok
  defp restore(ctx, :original, original), do: push(ctx, original)
  defp restore(ctx, position, _original) when is_number(position), do: push(ctx, position)

  defp push(ctx, value, attempts \\ @push_attempts)

  defp push(%{client: client, value_endpoint: endpoint, push_delay: delay}, value, attempts) do
    for _ <- 1..attempts do
      Client.set(client, endpoint, value)
      sleep(delay)
    end

    :ok
  end

  # ===========================================================================
  # Sweep and Sampling
  # ===========================================================================

  defp sweep_lever(ctx) do
    {min_input, max_input} = read_input_range(ctx.client, ctx.control_path)
    input_values = generate_sweep_values(min_input, max_input, ctx.step)

    # Start at the minimum, pushing past any snap points
    push(ctx, min_input)
    sleep(ctx.settling)

    Logger.debug("[LeverAnalyzer] Sweeping #{length(input_values)} positions...")

    input_values
    |> Enum.reduce_while({:ok, []}, fn set_input, {:ok, acc} ->
      sweep_step(ctx, set_input, acc)
    end)
    |> case do
      {:ok, samples} when length(samples) >= 10 -> {:ok, Enum.reverse(samples)}
      {:ok, _} -> {:error, :insufficient_samples}
      error -> error
    end
  end

  defp sweep_step(ctx, set_input, acc) do
    case sample_position(ctx, set_input, List.first(acc)) do
      {:ok, sample} ->
        if train_too_fast?(ctx) do
          Logger.warning("[LeverAnalyzer] Train is moving, stopping the sweep")
          {:halt, {:error, :train_moving}}
        else
          {:cont, {:ok, [sample | acc]}}
        end

      {:error, reason} ->
        Logger.warning("[LeverAnalyzer] Sample failed at #{set_input}: #{inspect(reason)}")
        {:cont, {:ok, acc}}
    end
  end

  defp read_input_range(%Client{} = client, control_path) do
    min_endpoint = "#{control_path}.Function.GetMinimumInputValue"
    max_endpoint = "#{control_path}.Function.GetMaximumInputValue"

    with {:ok, min_val} <- Client.get_float(client, min_endpoint),
         {:ok, max_val} <- Client.get_float(client, max_endpoint),
         true <- min_val < max_val do
      min_input = Float.round(min_val, 2)
      max_input = Float.round(max_val, 2)

      Logger.debug("[LeverAnalyzer] Input range: #{min_input} to #{max_input}")

      {min_input, max_input}
    else
      _ ->
        Logger.debug("[LeverAnalyzer] Could not read input range, using default 0.0 to 1.0")
        {0.0, 1.0}
    end
  end

  # Set the input once; when the lever stopped short of it, push it a few more
  # times so it can enter a gate (a single set often stops at the gate before).
  # The sweep goes upwards, so a lever that snapped past the target is already
  # in the next gate and pushing again would only cost time.
  defp sample_position(ctx, set_input, previous) do
    with {:ok, _} <- Client.set(ctx.client, ctx.value_endpoint, set_input),
         :ok <- sleep(ctx.settling),
         {:ok, actual_input} <- settle_input(ctx, set_input, previous),
         {:ok, output} <- Client.get_float(ctx.client, ctx.output_endpoint),
         {:ok, notch_index} <- Client.get_float(ctx.client, ctx.notch_endpoint) do
      {:ok,
       %Sample{
         set_input: Float.round(set_input, 2),
         actual_input: Float.round(actual_input, 2),
         output: Float.round(output, 2),
         notch_index: round(notch_index),
         snapped: abs(actual_input - set_input) > @snap_threshold
       }}
    end
  end

  defp settle_input(ctx, set_input, previous) do
    with {:ok, actual} <- Client.get_float(ctx.client, ctx.value_endpoint) do
      if actual < set_input - @snap_threshold and not push_failed_here?(previous, actual) do
        push(ctx, set_input, @sweep_push_attempts)
        sleep(ctx.settling)
        Client.get_float(ctx.client, ctx.value_endpoint)
      else
        {:ok, actual}
      end
    end
  end

  # The previous sample already stopped short at this same position after
  # being pushed, so pushing again will not move it (a lever that does not
  # respond, or the far side of an interlock). Skip it to keep sweeps short.
  defp push_failed_here?(%Sample{} = previous, actual) do
    previous.actual_input < previous.set_input - @snap_threshold and
      abs(previous.actual_input - actual) < 0.005
  end

  defp push_failed_here?(nil, _actual), do: false

  defp generate_sweep_values(min_input, max_input, step) do
    range = max_input - min_input
    count = round(range / step)

    0..count
    |> Enum.map(fn i -> Float.round(min_input + i * step, 2) end)
    |> Enum.filter(&(&1 <= max_input))
  end

  # ===========================================================================
  # Sample Analysis
  # ===========================================================================

  @doc """
  Analyzes pre-collected samples to determine lever type and zones.

  This function is useful for testing the analysis logic directly without
  performing I/O operations (HTTP requests and sleeps).

  Returns `{:ok, AnalysisResult.t()}`.

  ## Options

  - `:metadata` - `LeverMetadata.t()` used to name notches and check coverage
  - `:sweep_step` - the sweep's step; inferred from the samples when missing
  - `:warnings` - warnings to include in the result

  ## Examples

      samples = [
        %Sample{set_input: 0.0, actual_input: 0.0, output: -1.0, notch_index: 0, snapped: true},
        %Sample{set_input: 0.5, actual_input: 0.5, output: 0.0, notch_index: 1, snapped: true},
        %Sample{set_input: 1.0, actual_input: 1.0, output: 1.0, notch_index: 2, snapped: true}
      ]
      {:ok, result} = LeverAnalyzer.analyze_samples(samples)
  """
  @spec analyze_samples([Sample.t()], keyword()) ::
          {:ok, AnalysisResult.t()} | {:error, :insufficient_samples}
  def analyze_samples(samples, opts \\ [])

  def analyze_samples([], _opts), do: {:error, :insufficient_samples}

  def analyze_samples(samples, opts) when is_list(samples) do
    metadata = Keyword.get(opts, :metadata)
    step = Keyword.get(opts, :sweep_step) || infer_step(samples)

    outputs = Enum.map(samples, & &1.output)
    unique_outputs = Enum.uniq(outputs) |> Enum.sort()

    all_integers = Enum.all?(unique_outputs, &integer_value?/1)
    unique_count = length(unique_outputs)

    min_output = Enum.min(outputs)
    max_output = Enum.max(outputs)

    zones =
      samples
      |> group_by_notch_index()
      |> Enum.flat_map(&split_stepped_group/1)
      |> drop_transient_groups()
      |> merge_zones(step)
      |> fold_repeated_gates()

    Logger.debug("[LeverAnalyzer] #{length(zones)} zones after merging")

    lever_type = classify_lever_type(unique_count, all_integers, zones)

    {:ok,
     %AnalysisResult{
       lever_type: lever_type,
       samples: samples,
       zones: zones,
       suggested_notches: build_notches_from_zones(zones, metadata),
       min_output: min_output,
       max_output: max_output,
       unique_output_count: unique_count,
       all_outputs_integers: all_integers,
       metadata: metadata,
       warnings: Keyword.get(opts, :warnings, []) ++ coverage_warnings(samples, metadata)
     }}
  end

  defp infer_step(samples) do
    diffs =
      samples
      |> Enum.map(& &1.set_input)
      |> Enum.sort()
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> b - a end)
      |> Enum.filter(&(&1 > 0))
      |> Enum.sort()

    case diffs do
      [] -> @sweep_step
      _ -> Enum.at(diffs, div(length(diffs), 2))
    end
  end

  # Groups consecutive samples (in sweep order) that share a notch index. A
  # notch index seen again later in the sweep starts a new group, so it can
  # never swallow the zones between.
  defp group_by_notch_index(samples) do
    samples
    |> Enum.sort_by(& &1.set_input)
    |> Enum.chunk_by(& &1.notch_index)
    |> Enum.map(fn [first | _] = group -> {first.notch_index, group} end)
  end

  # A single sample between two gates, with an output between theirs, is the
  # lever passing through while it settled, not a notch.
  defp drop_transient_groups(groups) do
    zones = Enum.map(groups, fn {_idx, samples} -> create_zone_from_samples(samples, []) end)

    groups
    |> Enum.with_index()
    |> Enum.reject(fn {{_idx, samples}, i} ->
      i > 0 and i < length(groups) - 1 and length(samples) == 1 and
        transient?(Enum.at(zones, i - 1), hd(samples), Enum.at(zones, i + 1))
    end)
    |> Enum.map(&elem(&1, 0))
  end

  defp transient?(%Zone{type: :gate} = before, %Sample{output: output}, %Zone{type: :gate} = next) do
    low = min(before.value, next.value)
    high = max(before.value, next.value)
    output > low + @same_output_tolerance and output < high - @same_output_tolerance
  end

  defp transient?(_before, _sample, _next), do: false

  # One notch index can hold several output steps while the input moves freely
  # (Class 802 power: notch 5 outputs 1, 2, 3, 4). Split such a group into one
  # group per step. Only when every output is an integer, there are at least two
  # distinct values, and each step holds for at least two samples.
  defp split_stepped_group({notch_index, samples} = group) do
    runs = Enum.chunk_by(samples, & &1.output)
    distinct = samples |> Enum.map(& &1.output) |> Enum.uniq()

    if length(distinct) >= 2 and length(distinct) <= @max_discrete_outputs and
         length(runs) == length(distinct) and
         Enum.all?(distinct, &integer_value?/1) and
         Enum.all?(runs, &(length(&1) >= 2)) do
      Enum.map(runs, &{notch_index, &1})
    else
      [group]
    end
  end

  defp merge_zones(groups, step) do
    max_gap = max(@min_merge_gap, 1.5 * step)

    groups
    |> Enum.reduce([], fn {notch_index, samples}, acc ->
      add_zone(acc, create_zone_from_samples(samples, [notch_index]), step, max_gap)
    end)
    |> Enum.reverse()
  end

  defp add_zone([current | rest] = zones, next, step, max_gap) do
    if mergeable?(current, next, step, max_gap),
      do: [combine_zones(current, next) | rest],
      else: [next | zones]
  end

  defp add_zone([], next, _step, _max_gap), do: [next]

  # Some levers come back to an earlier gate later in the sweep (the Class 142
  # reverser snaps to Off above 0.86). The same gate at the same position is
  # one notch.
  defp fold_repeated_gates(zones) do
    zones
    |> Enum.reduce([], fn zone, acc ->
      case Enum.find_index(acc, &same_gate?(&1, zone)) do
        nil -> [zone | acc]
        index -> List.update_at(acc, index, &combine_zones(&1, zone))
      end
    end)
    |> Enum.reverse()
  end

  defp same_gate?(%Zone{type: :gate} = a, %Zone{type: :gate} = b) do
    same_output?(a.value, b.value) and
      abs(a.actual_input_min - b.actual_input_min) <= @snap_threshold and
      abs(a.actual_input_max - b.actual_input_max) <= @snap_threshold
  end

  defp same_gate?(_a, _b), do: false

  defp combine_zones(%Zone{} = a, %Zone{} = b) do
    create_zone_from_samples(a.samples ++ b.samples, a.notch_indices ++ b.notch_indices)
  end

  # Two gates merge only when they are the same position.
  defp mergeable?(%Zone{type: :gate} = a, %Zone{type: :gate} = b, _step, max_gap) do
    input_gap(a, b) <= max_gap and same_output?(a.value, b.value)
  end

  # A snap point next to a linear zone is the end of that zone when the output
  # carries on from it, or when it produces the same output as the zone's end.
  defp mergeable?(%Zone{} = a, %Zone{} = b, step, max_gap) do
    linear = if a.type == :linear, do: a, else: b
    a_end = Enum.max_by(a.samples, & &1.actual_input)
    b_start = Enum.min_by(b.samples, & &1.actual_input)

    gap = input_gap(a, b)

    # An equal-output snap point may sit a little further out (AC4400 Full
    # Service, 0.05 from the range end); a gate past a wide unreachable band
    # (an Emergency) stays a gate.
    (same_output?(a_end.output, b_start.output) and gap <= 2 * max_gap) or
      (gap <= max_gap and continuous?(a_end, b_start, slope(linear), step))
  end

  defp input_gap(%Zone{} = a, %Zone{} = b), do: max(b.actual_input_min - a.actual_input_max, 0.0)

  defp same_output?(a, b), do: abs(a - b) <= @same_output_tolerance

  defp continuous?(%Sample{} = a, %Sample{} = b, slope, step) do
    dx = b.actual_input - a.actual_input
    expected = slope * dx
    tolerance = max(0.05, 0.5 * abs(slope) * max(dx, step))
    abs(b.output - a.output - expected) <= tolerance
  end

  # Output change per unit of input across a linear zone
  defp slope(%Zone{samples: samples}) do
    first = Enum.min_by(samples, & &1.actual_input)
    last = Enum.max_by(samples, & &1.actual_input)
    dx = last.actual_input - first.actual_input

    if dx > 0, do: (last.output - first.output) / dx, else: 0.0
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
      notch_indices: notch_indices,
      samples: Enum.sort_by(samples, & &1.set_input)
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

    do_classify_lever_type(unique_count, all_integers, has_snap_zones, has_linear_zones)
  end

  defp do_classify_lever_type(unique_count, all_integers, _has_snap, has_linear)
       when all_integers and unique_count <= @max_discrete_outputs and not has_linear,
       do: :discrete

  defp do_classify_lever_type(unique_count, _all_integers, has_snap, _has_linear)
       when unique_count >= @min_continuous_unique_outputs and not has_snap,
       do: :continuous

  defp do_classify_lever_type(_unique_count, _all_integers, true, true), do: :hybrid

  defp do_classify_lever_type(unique_count, _all_integers, _has_snap, _has_linear)
       when unique_count >= @min_continuous_unique_outputs,
       do: :continuous

  defp do_classify_lever_type(_unique_count, _all_integers, _has_snap, _has_linear), do: :discrete

  defp integer_value?(value) do
    rounded = Float.round(value, 0)
    abs(value - rounded) < @output_integer_tolerance
  end

  # ===========================================================================
  # Notches and Names
  # ===========================================================================

  defp build_notches_from_zones(zones, metadata) do
    labels = if metadata, do: metadata.labels, else: []
    source = LeverMetadata.label_source(labels)

    zones
    |> Enum.sort_by(& &1.actual_input_min)
    |> Enum.with_index()
    |> Enum.map(fn {zone, idx} -> build_base_notch(zone, idx, labels, source) end)
  end

  defp build_base_notch(%Zone{type: :gate} = zone, idx, labels, source) do
    %{
      type: :gate,
      index: idx,
      value: zone.value,
      input_min: zone.actual_input_min,
      input_max: zone.actual_input_max,
      actual_input_min: zone.actual_input_min,
      actual_input_max: zone.actual_input_max,
      description: gate_name(zone, labels, source)
    }
  end

  defp build_base_notch(%Zone{type: :linear} = zone, idx, labels, source) do
    %{
      type: :linear,
      index: idx,
      min_value: zone.output_min,
      max_value: zone.output_max,
      input_min: zone.actual_input_min,
      input_max: zone.actual_input_max,
      actual_input_min: zone.actual_input_min,
      actual_input_max: zone.actual_input_max,
      description: linear_name(zone, labels, source)
    }
  end

  defp gate_name(%Zone{} = zone, labels, source) do
    key = if source == :input, do: zone_center(zone), else: zone.value

    case labels != [] && LeverMetadata.label_for(labels, source, key) do
      %Label{} = label -> LeverMetadata.display_name(label, zone.value)
      _ -> default_gate_name(zone.value)
    end
  end

  # Unlabelled gates on whole outputs are the lever's numbered notches
  defp default_gate_name(value) do
    if integer_value?(value),
      do: "Notch #{round(value)}",
      else: "Gate at output #{value}"
  end

  # A linear zone takes the name of the template label covering its middle
  # ("{BrakePercent} Brake" → "Brake"); a range of plain labels becomes
  # "first – last" ("B8 – B1").
  defp linear_name(%Zone{} = zone, labels, source) when labels != [] do
    {low, high} = zone_bounds(zone, source)
    middle = (low + high) / 2

    template = Enum.find(labels, &template_at?(&1, source, middle))

    covered =
      labels
      |> Enum.filter(&plain_within?(&1, source, low, high))
      |> Enum.sort_by(&(&1.min + &1.max))

    cond do
      template ->
        LeverMetadata.display_name(template, nil)

      length(covered) >= 2 ->
        span_name(zone, covered, source)

      label = LeverMetadata.label_for(labels, source, middle) ->
        LeverMetadata.display_name(label, nil)

      true ->
        default_linear_name(zone)
    end
  end

  defp linear_name(zone, _labels, _source), do: default_linear_name(zone)

  defp template_at?(%Label{} = label, source, value),
    do: label.source == source and label.template? and contains?(label, value)

  defp plain_within?(%Label{} = label, source, low, high),
    do: label.source == source and not label.template? and within?(label, low, high)

  defp span_name(zone, covered, source) do
    names = Enum.map(covered, & &1.name)
    ordered = if zone_ascending?(zone, source), do: names, else: Enum.reverse(names)
    "#{List.first(ordered)} – #{List.last(ordered)}"
  end

  defp default_linear_name(zone), do: "Linear #{zone.output_min} to #{zone.output_max}"

  defp zone_bounds(zone, :input), do: {zone.actual_input_min, zone.actual_input_max}
  defp zone_bounds(zone, _output), do: {zone.output_min, zone.output_max}

  # Names read in the order the lever moves through them (lowest input first)
  defp zone_ascending?(_zone, :input), do: true

  defp zone_ascending?(%Zone{samples: samples}, _output) do
    first = Enum.min_by(samples, & &1.actual_input)
    last = Enum.max_by(samples, & &1.actual_input)
    last.output >= first.output
  end

  defp zone_center(zone), do: (zone.actual_input_min + zone.actual_input_max) / 2

  defp contains?(%Label{min: min, max: max}, value),
    do: value >= min - 0.01 and value <= max + 0.01

  defp within?(%Label{min: min, max: max}, low, high) do
    center = (min + max) / 2
    center >= low - 0.01 and center <= high + 0.01
  end

  # ===========================================================================
  # Warnings
  # ===========================================================================

  defp coverage_warnings(_samples, nil), do: []

  defp coverage_warnings(samples, metadata) do
    blocked_range_warning(samples, metadata) ++ spring_loaded_warnings(samples, metadata)
  end

  defp blocked_range_warning(samples, %LeverMetadata{output_min: lo, output_max: hi})
       when is_number(lo) and is_number(hi) do
    outputs = Enum.map(samples, & &1.output)
    {seen_lo, seen_hi} = Enum.min_max(outputs)

    if seen_lo - lo > @coverage_tolerance or hi - seen_hi > @coverage_tolerance do
      [
        "The sweep reached outputs #{fmt(seen_lo)} to #{fmt(seen_hi)}, but this lever goes " <>
          "from #{fmt(lo)} to #{fmt(hi)}. Part of its range was blocked, for example power " <>
          "while the reverser is in neutral. Set the train up as if to drive and calibrate again."
      ]
    else
      []
    end
  end

  defp blocked_range_warning(_samples, _metadata), do: []

  # An input label inside the lever's range that the lever never stayed in is
  # a position that springs back (for example a brake "Release").
  defp spring_loaded_warnings(samples, %LeverMetadata{input_min: lo, input_max: hi} = metadata)
       when is_number(lo) and is_number(hi) do
    reached = Enum.map(samples, & &1.actual_input)

    metadata.labels
    |> Enum.filter(fn %Label{} = label ->
      label.source == :input and min(label.max, hi) - max(label.min, lo) >= 0.02 and
        not Enum.any?(reached, &contains?(label, &1))
    end)
    |> Enum.map(fn label ->
      "'#{LeverMetadata.display_name(label, nil)}' could not be held, so it is probably " <>
        "spring-loaded. It has no notch."
    end)
  end

  defp spring_loaded_warnings(_samples, _metadata), do: []

  defp fmt(value), do: :erlang.float_to_binary(value * 1.0, decimals: 2)

  # Conditionally sleep - allows tests to use delay_ms: 0 for fast execution
  defp sleep(0), do: :ok
  defp sleep(ms), do: Process.sleep(ms)
end
