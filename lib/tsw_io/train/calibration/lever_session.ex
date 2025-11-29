defmodule TswIo.Train.Calibration.LeverSession do
  @moduledoc """
  GenServer for automated lever calibration.

  This process calibrates a lever by stepping through its full range of values,
  detecting notch boundaries and types (gate vs linear). Progress updates are
  broadcast via PubSub.

  ## Algorithm

  1. Start at min value
  2. Increment value by small steps (0.01)
  3. After each increment, set the value and read it back
  4. Detect notch type:
     - If we set a value and read back a different value → :gate notch
     - If we set a value and read back the same value → :linear notch
  5. When notch index changes → record previous notch, start new one
  6. Continue until max value reached
  7. Save calibration data to LeverConfig

  ## PubSub

  Subscribe to `"train:calibration:{lever_config_id}"` to receive:
  - `{:calibration_progress, state}` - Progress updates during calibration
  - `{:calibration_result, {:ok, LeverConfig.t()} | {:error, reason}}` - Final result
  """

  use GenServer, restart: :temporary

  require Logger

  alias TswIo.Simulator.Client
  alias TswIo.Train.LeverConfig
  alias TswIo.Train.Notch
  alias TswIo.Train

  @step 0.01
  @tolerance 0.001
  @step_delay_ms 10

  defmodule State do
    @moduledoc false

    @type step :: :initializing | :calibrating | :saving | :complete | :error

    @type t :: %__MODULE__{
            lever_config: LeverConfig.t(),
            client: Client.t(),
            step: step(),
            min_value: float() | nil,
            max_value: float() | nil,
            current_value: float(),
            current_notch_index: integer(),
            current_notch_start: float(),
            current_notch_type: :gate | :linear | nil,
            notches: [Notch.t()],
            progress: float(),
            error: term() | nil
          }

    defstruct [
      :lever_config,
      :client,
      :min_value,
      :max_value,
      :error,
      step: :initializing,
      current_value: 0.0,
      current_notch_index: 0,
      current_notch_start: 0.0,
      current_notch_type: nil,
      notches: [],
      progress: 0.0
    ]
  end

  # ===================
  # Client API
  # ===================

  @doc """
  Start a calibration session.
  """
  def start_link({%Client{} = client, %LeverConfig{} = lever_config}) do
    GenServer.start_link(__MODULE__, {client, lever_config}, name: via_tuple(lever_config.id))
  end

  @doc """
  Get the current state of a calibration session.
  """
  @spec get_state(integer()) :: State.t() | nil
  def get_state(lever_config_id) do
    case whereis(lever_config_id) do
      nil -> nil
      pid -> GenServer.call(pid, :get_state)
    end
  end

  @doc """
  Subscribe to calibration events for a lever config.
  """
  @spec subscribe(integer()) :: :ok
  def subscribe(lever_config_id) do
    Phoenix.PubSub.subscribe(TswIo.PubSub, topic(lever_config_id))
  end

  @doc """
  Find the PID of a running calibration session.
  """
  @spec whereis(integer()) :: pid() | nil
  def whereis(lever_config_id) do
    case Registry.lookup(TswIo.Registry, {__MODULE__, lever_config_id}) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end

  # ===================
  # Server Callbacks
  # ===================

  @impl true
  def init({client, lever_config}) do
    state = %State{
      lever_config: lever_config,
      client: client
    }

    # Start the calibration process
    send(self(), :initialize)

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_info(:initialize, state) do
    Logger.info("Starting calibration for lever config #{state.lever_config.id}")

    case initialize_calibration(state) do
      {:ok, new_state} ->
        broadcast_progress(new_state)
        send(self(), :calibrate_step)
        {:noreply, new_state}

      {:error, reason} ->
        new_state = %{state | step: :error, error: reason}
        broadcast_result(new_state, {:error, reason})
        {:stop, :normal, new_state}
    end
  end

  def handle_info(:calibrate_step, state) do
    case calibrate_step(state) do
      {:continue, new_state} ->
        broadcast_progress(new_state)
        # Small delay to not overwhelm the simulator
        Process.send_after(self(), :calibrate_step, @step_delay_ms)
        {:noreply, new_state}

      {:done, new_state} ->
        # Finalize and save
        send(self(), :save)
        {:noreply, %{new_state | step: :saving}}

      {:error, reason, new_state} ->
        error_state = %{new_state | step: :error, error: reason}
        broadcast_result(error_state, {:error, reason})
        {:stop, :normal, error_state}
    end
  end

  def handle_info(:save, state) do
    Logger.info("Saving calibration for lever config #{state.lever_config.id}")

    # Finalize the last notch
    final_notches = finalize_notches(state)

    # Convert Notch structs to attribute maps for saving
    notch_attrs =
      Enum.map(final_notches, fn notch ->
        %{
          index: notch.index,
          type: notch.type,
          value: notch.value,
          min_value: notch.min_value,
          max_value: notch.max_value,
          description: notch.description
        }
      end)

    case Train.save_calibration(state.lever_config, notch_attrs) do
      {:ok, updated_config} ->
        new_state = %{state | step: :complete, progress: 1.0}
        broadcast_result(new_state, {:ok, updated_config})
        {:stop, :normal, new_state}

      {:error, reason} ->
        error_state = %{state | step: :error, error: reason}
        broadcast_result(error_state, {:error, reason})
        {:stop, :normal, error_state}
    end
  end

  # ===================
  # Private Functions
  # ===================

  defp via_tuple(lever_config_id) do
    {:via, Registry, {TswIo.Registry, {__MODULE__, lever_config_id}}}
  end

  defp topic(lever_config_id) do
    "train:calibration:#{lever_config_id}"
  end

  defp initialize_calibration(state) do
    %{client: client, lever_config: config} = state

    with {:ok, min_value} <- Client.get_float(client, config.min_endpoint),
         {:ok, max_value} <- Client.get_float(client, config.max_endpoint),
         {:ok, notch_count} <- Client.get_int(client, config.notch_count_endpoint) do
      # Handle single notch case - it's a linear spanning full range
      if notch_count == 1 do
        single_notch = %Notch{
          index: 0,
          type: :linear,
          value: nil,
          min_value: min_value,
          max_value: max_value,
          description: nil
        }

        {:ok,
         %{
           state
           | step: :saving,
             min_value: min_value,
             max_value: max_value,
             notches: [single_notch],
             progress: 1.0
         }}
      else
        # Set initial value and get starting notch index
        with {:ok, _} <- Client.set(client, config.value_endpoint, min_value),
             {:ok, notch_index} <- Client.get_int(client, config.notch_index_endpoint) do
          {:ok,
           %{
             state
             | step: :calibrating,
               min_value: min_value,
               max_value: max_value,
               current_value: min_value,
               current_notch_index: notch_index,
               current_notch_start: min_value
           }}
        end
      end
    end
  end

  defp calibrate_step(state) do
    next_value = state.current_value + @step

    # Check if we've reached the end
    if next_value > state.max_value do
      {:done, state}
    else
      do_calibrate_step(state, next_value)
    end
  end

  defp do_calibrate_step(state, next_value) do
    %{client: client, lever_config: config} = state

    with {:ok, _} <- Client.set(client, config.value_endpoint, next_value),
         {:ok, read_value} <- Client.get_float(client, config.value_endpoint),
         {:ok, notch_index} <- Client.get_int(client, config.notch_index_endpoint) do
      # Detect notch type based on value behavior
      notch_type = detect_notch_type(next_value, read_value)

      # Calculate progress
      progress = (next_value - state.min_value) / (state.max_value - state.min_value)

      # Check if notch index changed
      new_state =
        if notch_index != state.current_notch_index do
          # Notch changed - record the previous notch and start a new one
          record_notch_and_start_new(state, next_value, notch_index)
        else
          # Same notch - update type if we detect it
          update_notch_type(state, notch_type)
        end

      {:continue, %{new_state | current_value: next_value, progress: progress}}
    else
      {:error, reason} ->
        {:error, reason, state}
    end
  end

  defp detect_notch_type(set_value, read_value) do
    if abs(set_value - read_value) < @tolerance do
      # Value was accepted as-is → linear notch
      :linear
    else
      # Value was snapped to a different position → gate notch
      :gate
    end
  end

  defp record_notch_and_start_new(state, boundary_value, new_notch_index) do
    # Build the completed notch
    notch = build_notch_from_state(state, boundary_value)

    %{
      state
      | current_notch_index: new_notch_index,
        current_notch_start: boundary_value,
        current_notch_type: nil,
        notches: state.notches ++ [notch]
    }
  end

  defp update_notch_type(state, detected_type) do
    # If we haven't determined the type yet, or if we detect linear (takes precedence),
    # update the type
    new_type =
      case {state.current_notch_type, detected_type} do
        {nil, type} -> type
        {_, :linear} -> :linear
        {existing, _} -> existing
      end

    %{state | current_notch_type: new_type}
  end

  defp build_notch_from_state(state, end_value) do
    index = length(state.notches)

    case state.current_notch_type || :gate do
      :gate ->
        # Gate notch - use the midpoint as the value
        midpoint = (state.current_notch_start + end_value) / 2

        %Notch{
          index: index,
          type: :gate,
          value: midpoint,
          min_value: nil,
          max_value: nil,
          description: nil
        }

      :linear ->
        %Notch{
          index: index,
          type: :linear,
          value: nil,
          min_value: state.current_notch_start,
          max_value: end_value,
          description: nil
        }
    end
  end

  defp finalize_notches(state) do
    # Build the final notch
    final_notch = build_notch_from_state(state, state.max_value)
    state.notches ++ [final_notch]
  end

  defp broadcast_progress(state) do
    # Build a simplified state for broadcasting (exclude client)
    broadcast_state = %{
      lever_config_id: state.lever_config.id,
      step: state.step,
      progress: state.progress,
      current_value: state.current_value,
      notch_count: length(state.notches)
    }

    Phoenix.PubSub.broadcast(
      TswIo.PubSub,
      topic(state.lever_config.id),
      {:calibration_progress, broadcast_state}
    )
  end

  defp broadcast_result(state, result) do
    Phoenix.PubSub.broadcast(
      TswIo.PubSub,
      topic(state.lever_config.id),
      {:calibration_result, result}
    )
  end
end
