defmodule Trenino.Hardware.Calibration.Session do
  @moduledoc """
  Manages a single calibration session for an input.

  Collects samples during each calibration step, analyzes the data,
  and saves the calibration when complete. The session is a temporary
  process that lives for the duration of the calibration workflow.

  ## Workflow

  1. Start session with `start_link/1`
  2. Subscribe to events with `subscribe/1`
  3. Samples are collected automatically via PubSub
  4. Advance through steps with `advance_step/1`
  5. Session broadcasts result and terminates

  ## Circular sensors

  With `circular: true` (magnetic angle sensors) the session follows the lever as one
  unwrapped position from the first reading of the min step to the last of the max
  step, so the sensor's 0/max point can lie anywhere in the travel. These sensors only
  send when the angle moves or every ~2 s, so a hold step needs one fresh reading rather
  than 10 readings with 3 distinct values; each end is the median of the readings held
  there. The `:ready` step waits for a first reading, which shows the sensor answers.

  ## Events

  The session broadcasts events to `hardware:calibration:{input_id}`:

  - `{:session_started, public_state}` - Session began
  - `{:step_changed, public_state}` - Advanced to next step
  - `{:sample_collected, public_state}` - Sample was collected
  - `{:calibration_result, {:ok, calibration}}` - Success
  - `{:calibration_result, {:error, reason}}` - Failure
  """

  use GenServer

  alias Trenino.Hardware
  alias Trenino.Hardware.AngleSensor
  alias Trenino.Hardware.Calibration.Analyzer
  alias Trenino.Hardware.Input.Calibration

  require Logger

  @calibration_topic "hardware:calibration"
  @min_sample_count 10
  @min_unique_samples 3
  @settle_ms 500

  defmodule State do
    @moduledoc false

    @type step :: :ready | :collecting_min | :sweeping | :collecting_max | :analyzing | :complete

    @type t :: %__MODULE__{
            input_id: integer(),
            port: String.t(),
            pin: integer(),
            max_hardware_value: integer(),
            circular: boolean(),
            current_step: step(),
            current_value: integer() | nil,
            last_raw: integer() | nil,
            position: integer() | nil,
            min_samples: [integer()],
            sweep_samples: [integer()],
            max_samples: [integer()],
            result: {:ok, Calibration.t()} | {:error, term()} | nil
          }

    defstruct [
      :input_id,
      :port,
      :pin,
      :max_hardware_value,
      circular: false,
      current_step: :ready,
      current_value: nil,
      last_raw: nil,
      position: nil,
      min_samples: [],
      sweep_samples: [],
      max_samples: [],
      result: nil
    ]
  end

  # Client API

  @doc """
  Start a calibration session for an input.

  ## Options

    * `:input_id` - Required. The input ID being calibrated.
    * `:port` - Required. The serial port of the device.
    * `:pin` - Required. The pin number of the input.
    * `:max_hardware_value` - Optional. Hardware max value (default: 1023).
    * `:circular` - Optional. Calibrate as a circular angle sensor (default: false).
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Get the current state of the calibration session.
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
  Advance to the next step in calibration.

  Called when user confirms they're ready for the next step.
  Returns `:ok` on success, `{:error, reason}` if validation fails.
  """
  @spec advance_step(pid()) :: :ok | {:error, term()}
  def advance_step(pid) do
    GenServer.call(pid, :advance_step)
  end

  @doc """
  Cancel the calibration session.
  """
  @spec cancel(pid()) :: :ok
  def cancel(pid) do
    GenServer.cast(pid, :cancel)
  end

  @doc """
  Subscribe to calibration events for a specific input.
  """
  @spec subscribe(integer()) :: :ok | {:error, term()}
  def subscribe(input_id) do
    Phoenix.PubSub.subscribe(Trenino.PubSub, "#{@calibration_topic}:#{input_id}")
  end

  # Server callbacks

  @impl true
  def init(opts) do
    input_id = Keyword.fetch!(opts, :input_id)
    port = Keyword.fetch!(opts, :port)
    pin = Keyword.fetch!(opts, :pin)
    max_hardware_value = Keyword.get(opts, :max_hardware_value, 1023)
    circular = Keyword.get(opts, :circular, false)

    Logger.debug("Calibration session starting for input #{input_id}, port #{port}, pin #{pin}")

    # Subscribe to input values for this port
    Hardware.subscribe_input_values(port)

    state = %State{
      input_id: input_id,
      port: port,
      pin: pin,
      max_hardware_value: max_hardware_value,
      circular: circular
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
  def handle_call(:advance_step, _from, %State{} = state) do
    case validate_and_advance(state) do
      {:ok, %State{} = new_state} ->
        broadcast_event(new_state, :step_changed)

        # If we just moved to analyzing, start the analysis
        if new_state.current_step == :analyzing do
          send(self(), :analyze_and_save)
        end

        {:reply, :ok, new_state}

      {:error, _reason} = error ->
        {:reply, error, state}
    end
  end

  @impl true
  def handle_cast(:cancel, %State{} = state) do
    Logger.info("Calibration session cancelled for input #{state.input_id}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:input_value_updated, _port, pin, value}, %State{pin: pin} = state) do
    new_state = collect_sample(state, value)

    # Only broadcast if we actually collected a sample (not in :ready step)
    if new_state != state do
      Logger.debug("Calibration sample collected: #{value} (step: #{state.current_step})")
      broadcast_event(new_state, :sample_collected)
    end

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:input_value_updated, _port, _other_pin, _value}, %State{} = state) do
    # Ignore values from other pins
    {:noreply, state}
  end

  @impl true
  def handle_info(:analyze_and_save, %State{} = state) do
    case analyze_and_save_calibration(state) do
      {:ok, %Calibration{} = calibration} ->
        new_state = %{state | current_step: :complete, result: {:ok, calibration}}
        broadcast_result(new_state, {:ok, calibration})
        {:stop, :normal, new_state}

      {:error, _reason} = error ->
        new_state = %{state | current_step: :complete, result: error}
        broadcast_result(new_state, error)
        {:stop, :normal, new_state}
    end
  end

  # Private helpers

  # Circular sensors keep unwrapped positions in the min and max samples; ADC inputs keep
  # raw values. Sweep samples are raw in both (circular only counts them).
  defp collect_sample(%State{} = state, value) do
    state = %{state | current_value: value}

    if state.current_step in [:collecting_min, :sweeping, :collecting_max] do
      state |> track_position(value) |> store_sample(value)
    else
      state
    end
  end

  defp track_position(%State{circular: true, last_raw: nil} = state, value),
    do: %{state | last_raw: value, position: value}

  defp track_position(%State{circular: true} = state, value) do
    n = state.max_hardware_value + 1
    delta = AngleSensor.shortest_delta(state.last_raw, value, n)
    %{state | last_raw: value, position: state.position + delta}
  end

  defp track_position(%State{} = state, _value), do: state

  defp store_sample(%State{current_step: :collecting_min} = state, value) do
    %{state | min_samples: [held_value(state, value) | state.min_samples]}
  end

  defp store_sample(%State{current_step: :sweeping} = state, value) do
    %{state | sweep_samples: [value | state.sweep_samples]}
  end

  defp store_sample(%State{current_step: :collecting_max} = state, value) do
    %{state | max_samples: [held_value(state, value) | state.max_samples]}
  end

  # A circular hold keeps `{monotonic ms, position}`: only the readings that settled before
  # Next count for the end (see `settled_positions/1`).
  defp held_value(%State{circular: true, position: position}, _value),
    do: {System.monotonic_time(:millisecond), position}

  defp held_value(%State{}, value), do: value

  defp validate_and_advance(%State{current_step: :ready} = state) do
    if can_advance?(state) do
      Logger.debug("Advancing from :ready to :collecting_min")
      {:ok, %{state | current_step: :collecting_min}}
    else
      {:error, :no_reading}
    end
  end

  defp validate_and_advance(%State{current_step: :collecting_min} = state) do
    if valid_samples?(state, state.min_samples) do
      {:ok, %{state | current_step: :sweeping}}
    else
      {:error, :insufficient_samples}
    end
  end

  defp validate_and_advance(%State{current_step: :sweeping} = state) do
    if length(state.sweep_samples) >= @min_sample_count do
      {:ok, %{state | current_step: :collecting_max}}
    else
      {:error, :insufficient_sweep_samples}
    end
  end

  defp validate_and_advance(%State{current_step: :collecting_max} = state) do
    if valid_samples?(state, state.max_samples) do
      {:ok, %{state | current_step: :analyzing}}
    else
      {:error, :insufficient_samples}
    end
  end

  defp validate_and_advance(%State{}) do
    {:error, :invalid_step}
  end

  # A held angle sensor may send one reading in 2 s; one fresh reading shows it is there.
  defp valid_samples?(%State{circular: true}, samples), do: samples != []

  defp valid_samples?(%State{}, samples) do
    length(samples) >= @min_sample_count and
      length(Enum.uniq(samples)) >= @min_unique_samples
  end

  # The end is where the lever was when the user pressed Next: the readings in the last
  # 500 ms before the newest one. A user who presses Next while still moving
  # into place would otherwise pull the median toward the middle of the travel. A
  # sensor at rest sends once in 2 s, so that is often a single reading.
  defp settled_positions([{newest, _} | _] = samples) do
    for {at, position} <- samples, newest - at <= @settle_ms, do: position
  end

  defp analyze_and_save_calibration(%State{circular: true} = state) do
    with {:ok, attrs} <-
           Analyzer.circular_calibration(
             settled_positions(state.min_samples),
             settled_positions(state.max_samples),
             state.max_hardware_value + 1
           ) do
      attrs = Map.merge(attrs, %{max_hardware_value: state.max_hardware_value, circular: true})

      Hardware.save_calibration(state.input_id, attrs)
    end
  end

  defp analyze_and_save_calibration(%State{} = state) do
    # Reverse samples to get chronological order
    min_samples = Enum.reverse(state.min_samples)
    sweep_samples = Enum.reverse(state.sweep_samples)
    max_samples = Enum.reverse(state.max_samples)

    {:ok, analysis} = Analyzer.analyze_sweep(sweep_samples, state.max_hardware_value)

    min_value = Analyzer.calculate_min(min_samples, analysis)
    max_value = Analyzer.calculate_max(max_samples, analysis)

    attrs = %{
      min_value: min_value,
      max_value: max_value,
      max_hardware_value: state.max_hardware_value,
      is_inverted: analysis.inverted,
      has_rollover: analysis.rollover
    }

    Hardware.save_calibration(state.input_id, attrs)
  end

  defp broadcast_event(%State{} = state, event) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      "#{@calibration_topic}:#{state.input_id}",
      {event, build_public_state(state)}
    )
  end

  defp broadcast_result(%State{} = state, result) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      "#{@calibration_topic}:#{state.input_id}",
      {:calibration_result, result}
    )
  end

  defp build_public_state(%State{} = state) do
    %{
      input_id: state.input_id,
      pin: state.pin,
      circular: state.circular,
      current_step: state.current_step,
      current_value: state.current_value,
      min_sample_count: length(state.min_samples),
      min_unique_count: length(Enum.uniq(state.min_samples)),
      sweep_sample_count: length(state.sweep_samples),
      max_sample_count: length(state.max_samples),
      max_unique_count: length(Enum.uniq(state.max_samples)),
      can_advance: can_advance?(state),
      result: state.result
    }
  end

  defp can_advance?(%State{current_step: :ready, circular: true} = state),
    do: state.current_value != nil

  defp can_advance?(%State{current_step: :ready}), do: true

  defp can_advance?(%State{current_step: :collecting_min, min_samples: samples} = state) do
    valid_samples?(state, samples)
  end

  defp can_advance?(%State{current_step: :sweeping, sweep_samples: samples}) do
    length(samples) >= @min_sample_count
  end

  defp can_advance?(%State{current_step: :collecting_max, max_samples: samples} = state) do
    valid_samples?(state, samples)
  end

  defp can_advance?(%State{}), do: false
end
