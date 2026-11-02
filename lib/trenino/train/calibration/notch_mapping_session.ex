defmodule Trenino.Train.Calibration.NotchMappingSession do
  @moduledoc """
  Manages a guided session for mapping physical lever positions to notch input ranges.

  This session helps users define input ranges for each notch by tracking the
  min/max values as they move the physical lever.

  ## Workflow

  1. Start session with lever config and bound input info
  2. For each notch:
     - User positions lever at the notch (samples NOT collected yet)
     - User clicks "Start Capturing" to begin sample collection
     - Gate: User wiggles the lever within the detent position
     - Linear: User sweeps the lever through the full notch range
     - System tracks min/max of all samples collected
     - User confirms to capture the range
  3. Preview all mapped ranges
  4. Save notch input ranges to database

  ## Value Types

  During mapping, we work with **calibrated values** (integers from 0 to total_travel).
  These provide full hardware precision. When saving, values are normalized to 0.0-1.0
  for storage in the database.

  ## Events

  Broadcasts events to `train:notch_mapping:{lever_config_id}`:

  - `{:session_started, public_state}` - Session began
  - `{:step_changed, public_state}` - Advanced to next step
  - `{:sample_updated, public_state}` - Current value/range updated
  - `{:mapping_result, {:ok, lever_config}}` - Success
  - `{:mapping_result, {:error, reason}}` - Failure
  """

  use GenServer

  alias Trenino.Hardware
  alias Trenino.Hardware.Calibration.Calculator
  alias Trenino.Hardware.Input.Calibration
  alias Trenino.Train
  alias Trenino.Train.LeverConfig
  alias Trenino.Train.LeverMapper
  alias Trenino.Train.Notch

  require Logger

  @mapping_topic "train:notch_mapping"
  @min_sample_count 10

  # The runtime (LeverController) feeds LeverMapper hardware values rounded to
  # 2 decimals, and the mapper re-rounds `1.0 - value` to 2 decimals for
  # inverted levers. Edge probes therefore step in this quantum: a smaller
  # epsilon (e.g. 0.0001) would be rounded away and land on the exclusive
  # `input_max` of the half-open notch interval.
  @probe_step 0.01

  @typedoc "What the lever sends to the simulator at a single hardware position."
  @type end_info :: %{
          notch_index: non_neg_integer(),
          description: String.t() | nil,
          type: :gate | :linear,
          hardware_pct: float(),
          sim_input: float()
        }

  @typedoc """
  A captured notch in physical order.

  `min_pct`/`max_pct` are hardware percent (0..100). `sim_at_min`/`sim_at_max`
  are the sim_input the mapper yields at that physical end of the range (nil if
  the mapper can't reach that notch there, e.g. a zero-width gate capture).
  `sim_output_min`/`sim_output_max` are the notch's min_value/max_value (linear)
  or value/value (gate), informational only.
  """
  @type hardware_range :: %{
          notch_index: non_neg_integer(),
          description: String.t() | nil,
          type: :gate | :linear,
          min_pct: float(),
          max_pct: float(),
          sim_at_min: float() | nil,
          sim_at_max: float() | nil,
          sim_output_min: float() | nil,
          sim_output_max: float() | nil
        }

  @typedoc """
  Live preview of what the captured mapping will send to the simulator.

  Computed by running `LeverMapper.resolve_input/2` (the runtime code path) on a
  virtual `LeverConfig` built from the captured notches only.

    * `status` - `:none` (nothing captured), `:partial`, `:ready` (all captured)
    * `direction_known` - at least 2 captured notches have sim_input ranges, so
      inversion can be detected
    * `inverted` - detected inversion (false when direction is unknown)
    * `low_end`/`high_end` - physical lever at hardware 0% / 100%. If that point
      falls in a gap, the nearest captured range's edge is used (hardware_pct
      stays 0.0 / 100.0)
    * `live` - at `current_value`; nil if no value or it falls in a gap
    * `hardware_ranges` - captured notches sorted by `min_pct` (physical order)
  """
  @type preview :: %{
          status: :none | :partial | :ready,
          direction_known: boolean(),
          inverted: boolean(),
          low_end: end_info() | nil,
          high_end: end_info() | nil,
          live: end_info() | nil,
          hardware_ranges: [hardware_range()]
        }

  @typep normalized_range :: %{
           notch_index: non_neg_integer(),
           id: integer(),
           input_min: float(),
           input_max: float()
         }

  defmodule State do
    @moduledoc false

    @type step ::
            :ready
            | {:mapping_notch, non_neg_integer()}
            | :preview
            | :saving
            | :complete

    @type notch_range :: %{min: integer(), max: integer()} | nil

    @type t :: %__MODULE__{
            lever_config_id: integer(),
            lever_config: LeverConfig.t(),
            port: String.t(),
            pin: integer(),
            calibration: Calibration.t(),
            total_travel: integer(),
            notches: [map()],
            current_step: step(),
            is_capturing: boolean(),
            captured_ranges: [notch_range()],
            current_samples: [integer()],
            current_value: integer() | nil,
            current_min: integer() | nil,
            current_max: integer() | nil,
            result: {:ok, LeverConfig.t()} | {:error, term()} | nil
          }

    defstruct [
      :lever_config_id,
      :lever_config,
      :port,
      :pin,
      :calibration,
      :total_travel,
      notches: [],
      current_step: :ready,
      is_capturing: false,
      captured_ranges: [],
      current_samples: [],
      current_value: nil,
      current_min: nil,
      current_max: nil,
      result: nil
    ]
  end

  # Client API

  @doc """
  Start a notch mapping session.

  ## Options

    * `:lever_config` - Required. The lever config with preloaded notches.
    * `:port` - Required. The serial port of the bound device.
    * `:pin` - Required. The pin number of the bound input.
    * `:calibration` - Required. The input's calibration data.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    lever_config = Keyword.fetch!(opts, :lever_config)
    GenServer.start_link(__MODULE__, opts, name: via_tuple(lever_config.id))
  end

  @doc """
  Get the registry name for a session.
  """
  @spec whereis(integer()) :: pid() | nil
  def whereis(lever_config_id) do
    # Registry unregistration lags process death: after a session is stopped,
    # lookup can briefly return the dead pid. Treat dead pids as absent so
    # stop-then-restart (e.g. wizard re-entry) can't observe a stale session.
    case Registry.lookup(Trenino.Registry, {__MODULE__, lever_config_id}) do
      [{pid, _}] -> if Process.alive?(pid), do: pid
      [] -> nil
    end
  end

  @doc """
  Get the current state of the mapping session.
  """
  @spec get_state(pid()) :: State.t()
  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  @doc """
  Get the public state suitable for UI display.
  """
  @spec get_public_state(pid()) :: map()
  def get_public_state(pid) do
    GenServer.call(pid, :get_public_state)
  end

  @doc """
  Start the mapping process (move from :ready to first notch).
  """
  @spec start_mapping(pid()) :: :ok | {:error, term()}
  def start_mapping(pid) do
    GenServer.call(pid, :start_mapping)
  end

  @doc """
  Capture the current min/max range for the current notch.
  """
  @spec capture_range(pid()) :: :ok | {:error, term()}
  def capture_range(pid) do
    GenServer.call(pid, :capture_range)
  end

  @doc """
  Clear current samples and start fresh for the current notch.
  """
  @spec reset_samples(pid()) :: :ok | {:error, term()}
  def reset_samples(pid) do
    GenServer.call(pid, :reset_samples)
  end

  @doc """
  Begin capturing samples for the current notch.
  Call this after the user has positioned the lever.
  """
  @spec start_capturing(pid()) :: :ok | {:error, term()}
  def start_capturing(pid) do
    GenServer.call(pid, :start_capturing)
  end

  @doc """
  Stop capturing samples (returns to positioning state).
  """
  @spec stop_capturing(pid()) :: :ok | {:error, term()}
  def stop_capturing(pid) do
    GenServer.call(pid, :stop_capturing)
  end

  @doc """
  Skip to a specific notch (for editing).
  """
  @spec go_to_notch(pid(), non_neg_integer()) :: :ok | {:error, term()}
  def go_to_notch(pid, notch_index) do
    GenServer.call(pid, {:go_to_notch, notch_index})
  end

  @doc """
  Move to preview step.
  """
  @spec go_to_preview(pid()) :: :ok | {:error, term()}
  def go_to_preview(pid) do
    GenServer.call(pid, :go_to_preview)
  end

  @doc """
  Save the mapped notch ranges.
  """
  @spec save_mapping(pid()) :: :ok | {:error, term()}
  def save_mapping(pid) do
    GenServer.call(pid, :save_mapping)
  end

  @doc """
  Cancel the mapping session.
  """
  @spec cancel(pid()) :: :ok
  def cancel(pid) do
    GenServer.cast(pid, :cancel)
  end

  @doc """
  Subscribe to mapping events for a specific lever config.
  """
  @spec subscribe(integer()) :: :ok | {:error, term()}
  def subscribe(lever_config_id) do
    Phoenix.PubSub.subscribe(Trenino.PubSub, "#{@mapping_topic}:#{lever_config_id}")
  end

  # Keep old API for compatibility
  @doc false
  def capture_boundary(pid), do: capture_range(pid)

  @doc false
  def go_to_boundary(pid, idx), do: go_to_notch(pid, idx)

  # Server callbacks

  @impl true
  def init(opts) do
    lever_config = Keyword.fetch!(opts, :lever_config)
    port = Keyword.fetch!(opts, :port)
    pin = Keyword.fetch!(opts, :pin)
    calibration = Keyword.fetch!(opts, :calibration)

    total_travel = Calculator.total_travel(calibration)

    notches =
      lever_config.notches
      |> Enum.sort_by(& &1.index)
      |> Enum.map(fn notch ->
        %{
          id: notch.id,
          index: notch.index,
          type: notch.type,
          description: notch.description || "Notch #{notch.index}",
          # Include sim_input ranges for inversion auto-detection
          sim_input_min: notch.sim_input_min,
          sim_input_max: notch.sim_input_max,
          # Simulator output values (informational, shown in the preview)
          value: notch.value,
          min_value: notch.min_value,
          max_value: notch.max_value
        }
      end)

    Logger.debug(
      "NotchMappingSession starting for lever_config #{lever_config.id}, " <>
        "#{length(notches)} notches, total_travel #{total_travel}"
    )

    # Subscribe to input values for this port
    Hardware.subscribe_input_values(port)

    state = %State{
      lever_config_id: lever_config.id,
      lever_config: lever_config,
      port: port,
      pin: pin,
      calibration: calibration,
      total_travel: total_travel,
      notches: notches,
      captured_ranges: List.duplicate(nil, length(notches))
    }

    broadcast_event(state, :session_started)

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, %State{} = state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:get_public_state, _from, %State{} = state) do
    {:reply, build_public_state(state), state}
  end

  @impl true
  def handle_call(:start_mapping, _from, %State{current_step: :ready} = state) do
    new_state = %{
      state
      | current_step: {:mapping_notch, 0},
        is_capturing: false,
        current_samples: [],
        current_min: nil,
        current_max: nil
    }

    broadcast_event(new_state, :step_changed)
    {:reply, :ok, new_state}
  end

  def handle_call(:start_mapping, _from, %State{} = state) do
    {:reply, {:error, :invalid_step}, state}
  end

  @impl true
  def handle_call(:capture_range, _from, %State{current_step: {:mapping_notch, idx}} = state) do
    case validate_capture(state) do
      :ok ->
        range = %{min: state.current_min, max: state.current_max}
        new_ranges = List.replace_at(state.captured_ranges, idx, range)

        next_step = next_step_after_capture(new_ranges, idx)

        new_state = %{
          state
          | captured_ranges: new_ranges,
            current_step: next_step,
            is_capturing: false,
            current_samples: [],
            current_min: nil,
            current_max: nil
        }

        broadcast_event(new_state, :step_changed)
        {:reply, :ok, new_state}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  def handle_call(:capture_range, _from, %State{} = state) do
    {:reply, {:error, :invalid_step}, state}
  end

  # Alias for compatibility
  def handle_call(:capture_boundary, from, state) do
    handle_call(:capture_range, from, state)
  end

  @impl true
  def handle_call(:reset_samples, _from, %State{current_step: {:mapping_notch, _}} = state) do
    new_state = %{
      state
      | is_capturing: false,
        current_samples: [],
        current_min: nil,
        current_max: nil
    }

    broadcast_event(new_state, :sample_updated)
    {:reply, :ok, new_state}
  end

  def handle_call(:reset_samples, _from, %State{} = state) do
    {:reply, {:error, :invalid_step}, state}
  end

  @impl true
  def handle_call(:start_capturing, _from, %State{current_step: {:mapping_notch, _}} = state) do
    new_state = %{
      state
      | is_capturing: true,
        current_samples: [],
        current_min: nil,
        current_max: nil
    }

    broadcast_event(new_state, :capture_started)
    {:reply, :ok, new_state}
  end

  def handle_call(:start_capturing, _from, %State{} = state) do
    {:reply, {:error, :invalid_step}, state}
  end

  @impl true
  def handle_call(:stop_capturing, _from, %State{current_step: {:mapping_notch, _}} = state) do
    new_state = %{
      state
      | is_capturing: false,
        current_samples: [],
        current_min: nil,
        current_max: nil
    }

    broadcast_event(new_state, :capture_stopped)
    {:reply, :ok, new_state}
  end

  def handle_call(:stop_capturing, _from, %State{} = state) do
    {:reply, {:error, :invalid_step}, state}
  end

  @impl true
  def handle_call({:go_to_notch, idx}, _from, %State{} = state)
      when idx >= 0 and idx < length(state.notches) do
    new_state = %{
      state
      | current_step: {:mapping_notch, idx},
        is_capturing: false,
        current_samples: [],
        current_min: nil,
        current_max: nil
    }

    broadcast_event(new_state, :step_changed)
    {:reply, :ok, new_state}
  end

  def handle_call({:go_to_notch, _idx}, _from, %State{} = state) do
    {:reply, {:error, :invalid_notch_index}, state}
  end

  # Alias for compatibility
  def handle_call({:go_to_boundary, idx}, from, state) do
    handle_call({:go_to_notch, idx}, from, state)
  end

  @impl true
  def handle_call(:go_to_preview, _from, %State{} = state) do
    if all_ranges_captured?(state) do
      new_state = %{state | current_step: :preview}
      broadcast_event(new_state, :step_changed)
      {:reply, :ok, new_state}
    else
      {:reply, {:error, :incomplete_ranges}, state}
    end
  end

  @impl true
  def handle_call(:save_mapping, _from, %State{current_step: :preview} = state) do
    new_state = %{state | current_step: :saving}
    broadcast_event(new_state, :step_changed)

    case save_notch_ranges(state) do
      {:ok, updated_config} ->
        final_state = %{new_state | current_step: :complete, result: {:ok, updated_config}}
        broadcast_event(final_state, :step_changed)
        broadcast_result(final_state, {:ok, updated_config})
        {:reply, :ok, final_state}

      {:error, _reason} = error ->
        final_state = %{new_state | current_step: :complete, result: error}
        broadcast_event(final_state, :step_changed)
        broadcast_result(final_state, error)
        {:reply, error, final_state}
    end
  end

  def handle_call(:save_mapping, _from, %State{} = state) do
    {:reply, {:error, :invalid_step}, state}
  end

  @impl true
  def handle_cast(:cancel, %State{} = state) do
    Logger.info("NotchMappingSession cancelled for lever_config #{state.lever_config_id}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:input_value_updated, _port, pin, raw_value}, %State{pin: pin} = state) do
    case state.current_step do
      {:mapping_notch, _idx} ->
        calibrated = Calculator.normalize(raw_value, state.calibration)
        new_state = update_mapping_sample(state, calibrated)
        broadcast_event(new_state, :sample_updated)
        {:noreply, new_state}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:input_value_updated, _port, _other_pin, _value}, %State{} = state) do
    {:noreply, state}
  end

  defp update_mapping_sample(%State{is_capturing: true} = state, calibrated) do
    %{
      state
      | current_samples: [calibrated | state.current_samples],
        current_value: calibrated,
        current_min: min_value(state.current_min, calibrated),
        current_max: max_value(state.current_max, calibrated)
    }
  end

  defp update_mapping_sample(%State{is_capturing: false} = state, calibrated) do
    %{state | current_value: calibrated}
  end

  defp min_value(nil, value), do: value
  defp min_value(current, value), do: min(current, value)

  defp max_value(nil, value), do: value
  defp max_value(current, value), do: max(current, value)

  # Private helpers

  defp via_tuple(lever_config_id) do
    {:via, Registry, {Trenino.Registry, {__MODULE__, lever_config_id}}}
  end

  defp validate_capture(%State{current_samples: samples, current_min: min, current_max: max}) do
    cond do
      samples == [] ->
        {:error, :no_samples}

      is_nil(min) or is_nil(max) ->
        {:error, :no_range_detected}

      # Allow single-point captures (min == max) for gate notches
      true ->
        :ok
    end
  end

  # Advance to the next uncaptured notch (wrapping around, since users can jump
  # ahead with go_to_notch); only enter preview once every notch has a range
  defp next_step_after_capture(ranges, idx) do
    indexed = Enum.with_index(ranges)
    {after_current, up_to_current} = Enum.split(indexed, idx + 1)

    case Enum.find(after_current ++ up_to_current, fn {range, _i} -> is_nil(range) end) do
      nil -> :preview
      {_range, next_idx} -> {:mapping_notch, next_idx}
    end
  end

  defp all_ranges_captured?(%State{captured_ranges: ranges}) do
    Enum.all?(ranges, &(&1 != nil))
  end

  # Auto-detect if lever inversion is needed by comparing captured hardware ranges
  # with the expected sim_input ranges.
  #
  # If the notch at the lowest hardware position has a higher sim_input than the
  # notch at the highest hardware position, then inversion is needed.
  #
  # Example (no inversion): hardware 0→100% maps to sim 0→1
  # Example (inversion needed - M9-A style): hardware 0→100% maps to sim 1→0
  defp detect_inversion(notches, captured_ranges, _total_travel) do
    valid_pairs = direction_pairs(notches, captured_ranges)

    # Need at least 2 notches to determine orientation
    if length(valid_pairs) < 2 do
      false
    else
      # Helper to get center of a range
      hw_center = fn {_notch, range} -> (range.min + range.max) / 2 end
      sim_center = fn {notch, _range} -> (notch.sim_input_min + notch.sim_input_max) / 2 end

      # Find notches at hardware extremes
      {first_notch, _} = Enum.min_by(valid_pairs, hw_center)
      {last_notch, _} = Enum.max_by(valid_pairs, hw_center)

      # Inverted if low hardware → high sim
      sim_center.({first_notch, nil}) > sim_center.({last_notch, nil})
    end
  end

  # Captured notches that have a sim_input range: the only ones that can tell
  # us the lever's direction. Shared by detect_inversion/3 and the preview's
  # `direction_known` so the two can never disagree.
  defp direction_pairs(notches, captured_ranges) do
    notches
    |> Enum.zip(captured_ranges)
    |> Enum.filter(fn {notch, range} ->
      range != nil and notch.sim_input_min != nil and notch.sim_input_max != nil
    end)
  end

  # Pure normalization/inversion step shared by save and preview: detects
  # inversion and converts each captured calibrated range to normalized
  # 0.0-1.0 (flipped when inverted). Uncaptured notches are excluded.
  @spec normalize_captured_ranges([map()], [State.notch_range()], integer()) ::
          {boolean(), [normalized_range()]}
  defp normalize_captured_ranges(notches, captured_ranges, total_travel) do
    inverted = detect_inversion(notches, captured_ranges, total_travel)

    ranges =
      notches
      |> Enum.zip(captured_ranges)
      |> Enum.with_index()
      |> Enum.flat_map(fn
        {{_notch, nil}, _idx} ->
          []

        {{notch, range}, idx} ->
          {norm_min, norm_max} =
            calibrated_to_normalized(range.min, range.max, total_travel, inverted)

          [%{notch_index: idx, id: notch.id, input_min: norm_min, input_max: norm_max}]
      end)

    {inverted, ranges}
  end

  # The LeverConfig the runtime would use if the captured ranges were saved now.
  # Notch input ranges go through Notch.changeset/2 exactly like
  # Train.update_notch_input_ranges/3 does, so they carry the same rounding as
  # the persisted values.
  @spec virtual_lever_config(State.t(), boolean(), [normalized_range()]) :: LeverConfig.t()
  defp virtual_lever_config(%State{lever_config: %LeverConfig{} = config}, inverted, ranges) do
    notches_by_id = Map.new(config.notches, &{&1.id, &1})

    notches =
      Enum.map(ranges, fn %{id: id, input_min: input_min, input_max: input_max} ->
        %Notch{} = notch = Map.fetch!(notches_by_id, id)

        notch
        |> Notch.changeset(%{input_min: input_min, input_max: input_max})
        |> Ecto.Changeset.apply_changes()
      end)

    %LeverConfig{config | inverted: inverted, notches: notches}
  end

  defp save_notch_ranges(%State{} = state) do
    if all_ranges_captured?(state) do
      # Auto-detect inversion and convert calibrated values to normalized 0.0-1.0
      {inverted, ranges} =
        normalize_captured_ranges(state.notches, state.captured_ranges, state.total_travel)

      Logger.debug("Auto-detected inversion: #{inverted}")

      notch_updates =
        Enum.map(ranges, fn range -> Map.take(range, [:id, :input_min, :input_max]) end)

      # Save the auto-detected inverted flag along with notch ranges
      Train.update_notch_input_ranges(state.lever_config_id, notch_updates, inverted: inverted)
    else
      {:error, :incomplete_ranges}
    end
  end

  defp calibrated_to_normalized(min_cal, max_cal, total_travel, inverted)
       when total_travel > 0 do
    norm_min = Float.round(min_cal / total_travel, 4)
    norm_max = Float.round(max_cal / total_travel, 4)

    if inverted do
      # Invert: 0.0 becomes 1.0 and vice versa
      # Also swap min/max since inversion reverses the order
      inv_min = Float.round(1.0 - norm_max, 4)
      inv_max = Float.round(1.0 - norm_min, 4)
      {inv_min, inv_max}
    else
      {norm_min, norm_max}
    end
  end

  defp calibrated_to_normalized(_min, _max, _total_travel, _inverted), do: {0.0, 0.0}

  defp broadcast_event(%State{} = state, event) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      "#{@mapping_topic}:#{state.lever_config_id}",
      {event, build_public_state(state)}
    )
  end

  defp broadcast_result(%State{} = state, result) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      "#{@mapping_topic}:#{state.lever_config_id}",
      {:mapping_result, result}
    )
  end

  defp build_public_state(%State{} = state) do
    current_notch_idx = current_notch_index(state.current_step)

    current_notch =
      if current_notch_idx do
        Enum.at(state.notches, current_notch_idx)
      else
        nil
      end

    %{
      lever_config_id: state.lever_config_id,
      notch_count: length(state.notches),
      notches: state.notches,
      total_travel: state.total_travel,
      current_step: state.current_step,
      current_notch_index: current_notch_idx,
      current_notch: current_notch,
      is_capturing: state.is_capturing,
      captured_ranges: state.captured_ranges,
      current_value: state.current_value,
      current_min: state.current_min,
      current_max: state.current_max,
      sample_count: length(state.current_samples),
      can_capture: can_capture?(state),
      all_captured: all_ranges_captured?(state),
      preview: build_preview(state),
      result: state.result,
      # Legacy fields for compatibility
      boundary_count: length(state.notches) + 1,
      current_boundary_index: current_notch_idx,
      captured_boundaries: state.captured_ranges,
      notch_descriptions: Enum.map(state.notches, & &1.description),
      is_stable: length(state.current_samples) >= @min_sample_count
    }
  end

  # Preview

  @spec build_preview(State.t()) :: preview()
  defp build_preview(%State{} = state) do
    captured_count = Enum.count(state.captured_ranges, &(&1 != nil))

    status =
      cond do
        captured_count == 0 -> :none
        captured_count == length(state.notches) -> :ready
        true -> :partial
      end

    if status == :none or state.total_travel <= 0 do
      %{
        status: status,
        direction_known: false,
        inverted: false,
        low_end: nil,
        high_end: nil,
        live: nil,
        hardware_ranges: []
      }
    else
      build_captured_preview(state, status)
    end
  end

  defp build_captured_preview(%State{} = state, status) do
    {inverted, ranges} =
      normalize_captured_ranges(state.notches, state.captured_ranges, state.total_travel)

    config = virtual_lever_config(state, inverted, ranges)
    index_by_id = Map.new(ranges, &{&1.id, &1.notch_index})
    hardware_ranges = build_hardware_ranges(state, config, index_by_id)

    %{
      status: status,
      direction_known: length(direction_pairs(state.notches, state.captured_ranges)) >= 2,
      inverted: inverted,
      low_end: extreme_end(state, config, index_by_id, hardware_ranges, :low),
      high_end: extreme_end(state, config, index_by_id, hardware_ranges, :high),
      live: live_end(state, config, index_by_id),
      hardware_ranges: hardware_ranges
    }
  end

  defp build_hardware_ranges(%State{} = state, %LeverConfig{} = config, index_by_id) do
    config.notches
    |> Enum.map(fn %Notch{} = virtual_notch ->
      idx = Map.fetch!(index_by_id, virtual_notch.id)
      notch = Enum.at(state.notches, idx)
      range = Enum.at(state.captured_ranges, idx)
      {sim_at_min, sim_at_max} = probe_range_ends(config, virtual_notch, idx, index_by_id)
      {output_min, output_max} = sim_outputs(notch)

      %{
        notch_index: idx,
        description: notch.description,
        type: notch.type,
        min_pct: Float.round(range.min / state.total_travel * 100, 2),
        max_pct: Float.round(range.max / state.total_travel * 100, 2),
        sim_at_min: sim_at_min,
        sim_at_max: sim_at_max,
        sim_output_min: output_min,
        sim_output_max: output_max
      }
    end)
    |> Enum.sort_by(&{&1.min_pct, &1.max_pct})
  end

  # Probe the mapper at both physical ends of a captured range.
  #
  # Probes are chosen in the mapper's *effective* space (the stored input
  # range, already flipped for inverted levers) and converted back to raw
  # hardware, so the mapper's own inversion reproduces them exactly. The
  # notch interval is half-open, so the upper end is probed at input_max
  # (only reachable when it is exactly 1.0) and then one quantum inside.
  # A probe only counts if the mapper resolves it to this very notch;
  # zero-width captures (input_min == input_max) are unreachable at runtime
  # and yield nil.
  defp probe_range_ends(%LeverConfig{} = config, %Notch{} = notch, idx, index_by_id) do
    lower = probe_effective(config, [notch.input_min], idx, index_by_id)

    upper =
      probe_effective(
        config,
        [notch.input_max, Float.round(max(notch.input_min, notch.input_max - @probe_step), 2)],
        idx,
        index_by_id
      )

    # Not inverted: physical min = effective min. Inverted: physical min is the
    # effective max side.
    if config.inverted, do: {upper, lower}, else: {lower, upper}
  end

  defp probe_effective(%LeverConfig{} = config, effective_values, idx, index_by_id) do
    Enum.find_value(effective_values, fn effective ->
      raw = if config.inverted, do: Float.round(1.0 - effective, 2), else: effective

      case resolve(config, raw, index_by_id) do
        {:ok, ^idx, sim_input} -> sim_input
        _ -> nil
      end
    end)
  end

  defp resolve(%LeverConfig{} = config, hardware, index_by_id) do
    case LeverMapper.resolve_input(config, hardware) do
      {:ok, %Notch{id: id}, sim_input} -> {:ok, Map.fetch!(index_by_id, id), sim_input}
      {:error, _reason} -> :error
    end
  end

  defp extreme_end(%State{} = state, config, index_by_id, hardware_ranges, side) do
    hardware = if side == :low, do: 0.0, else: 1.0

    case resolve(config, hardware, index_by_id) do
      {:ok, idx, sim_input} ->
        end_info(state, idx, hardware, sim_input)

      :error ->
        # Gap at this end: fall back to the nearest captured range's edge
        nearest_range_end(state, hardware_ranges, hardware, side)
    end
  end

  defp nearest_range_end(%State{} = state, hardware_ranges, hardware, :low) do
    hardware_ranges
    |> Enum.reject(&is_nil(&1.sim_at_min))
    |> Enum.min_by(& &1.min_pct, fn -> nil end)
    |> case do
      nil -> nil
      range -> end_info(state, range.notch_index, hardware, range.sim_at_min)
    end
  end

  defp nearest_range_end(%State{} = state, hardware_ranges, hardware, :high) do
    hardware_ranges
    |> Enum.reject(&is_nil(&1.sim_at_max))
    |> Enum.max_by(& &1.max_pct, fn -> nil end)
    |> case do
      nil -> nil
      range -> end_info(state, range.notch_index, hardware, range.sim_at_max)
    end
  end

  defp live_end(%State{current_value: nil}, _config, _index_by_id), do: nil

  defp live_end(%State{} = state, config, index_by_id) do
    # Same normalization LeverController applies before calling the mapper
    hardware =
      (state.current_value / state.total_travel)
      |> max(0.0)
      |> min(1.0)
      |> Float.round(2)

    case resolve(config, hardware, index_by_id) do
      {:ok, idx, sim_input} -> end_info(state, idx, hardware, sim_input)
      :error -> nil
    end
  end

  defp end_info(%State{} = state, idx, hardware, sim_input) do
    notch = Enum.at(state.notches, idx)

    %{
      notch_index: idx,
      description: notch.description,
      type: notch.type,
      hardware_pct: Float.round(hardware * 100, 2),
      sim_input: sim_input
    }
  end

  defp sim_outputs(%{type: :gate, value: value}), do: {round2(value), round2(value)}

  defp sim_outputs(%{min_value: min_value, max_value: max_value}),
    do: {round2(min_value), round2(max_value)}

  defp round2(value) when is_float(value), do: Float.round(value, 2)
  defp round2(value) when is_integer(value), do: Float.round(value / 1, 2)
  defp round2(nil), do: nil

  defp current_notch_index({:mapping_notch, idx}), do: idx
  defp current_notch_index(_), do: nil

  defp can_capture?(%State{current_step: {:mapping_notch, _}} = state) do
    # Allow capture as soon as we have at least one sample
    # Single-point captures (min == max) are valid for gate notches
    state.current_samples != [] and
      state.current_min != nil and
      state.current_max != nil
  end

  defp can_capture?(_state), do: false
end
