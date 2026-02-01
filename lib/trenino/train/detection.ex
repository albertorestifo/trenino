defmodule Trenino.Train.Detection do
  @moduledoc """
  Monitors the simulator for train changes and manages the active train configuration.

  Responsibilities:
  - Poll formation data periodically when connected to simulator
  - Derive train identifier from formation
  - Match identifier to stored train configurations
  - Broadcast train change events via PubSub

  ## Events

  Subscribers receive messages on "train:detection":
  - `{:train_detected, %{identifier: String.t(), train: Train.t() | nil}}`
  - `{:train_changed, Train.t() | nil}`
  - `{:multiple_trains_match, %{identifier: String.t(), trains: [Train.t()]}}`
  - `{:detection_error, term()}`
  """

  use GenServer
  require Logger

  alias Trenino.Simulator.Client
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train
  alias Trenino.Train.Identifier

  @poll_interval_ms 5_000
  @grace_period_ms 30_000
  @grace_poll_interval_ms 200
  @pubsub_topic "train:detection"

  defmodule State do
    @moduledoc false

    @type detection_error :: {:multiple_matches, [Train.Train.t()]} | nil

    @type t :: %__MODULE__{
            active_train: Train.Train.t() | nil,
            current_identifier: String.t() | nil,
            last_check: DateTime.t() | nil,
            polling_enabled: boolean(),
            detection_error: detection_error(),
            last_successful_contact: integer() | nil,
            last_client: Client.t() | nil,
            grace_client: Client.t() | nil,
            grace_timer: reference() | nil
          }

    defstruct active_train: nil,
              current_identifier: nil,
              last_check: nil,
              polling_enabled: false,
              detection_error: nil,
              last_successful_contact: nil,
              last_client: nil,
              grace_client: nil,
              grace_timer: nil
  end

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Subscribe to train detection events.
  """
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe do
    Phoenix.PubSub.subscribe(Trenino.PubSub, @pubsub_topic)
  end

  @doc """
  Get the currently active train.
  """
  @spec get_active_train() :: Train.Train.t() | nil
  def get_active_train do
    GenServer.call(__MODULE__, :get_active_train)
  end

  @doc """
  Get the current train identifier.
  """
  @spec get_current_identifier() :: String.t() | nil
  def get_current_identifier do
    GenServer.call(__MODULE__, :get_current_identifier)
  end

  @doc """
  Get the current detection state.
  """
  @spec get_state() :: State.t()
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Manually trigger train detection sync.
  """
  @spec sync() :: :ok
  def sync do
    GenServer.cast(__MODULE__, :sync)
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    # Subscribe to simulator connection changes
    SimulatorConnection.subscribe()

    # Check initial connection status
    send(self(), :check_connection)

    {:ok, %State{}}
  end

  @impl true
  def handle_call(:get_active_train, _from, %State{} = state) do
    {:reply, state.active_train, state}
  end

  @impl true
  def handle_call(:get_current_identifier, _from, %State{} = state) do
    {:reply, state.current_identifier, state}
  end

  @impl true
  def handle_call(:get_state, _from, %State{} = state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast(:sync, %State{} = state) do
    # Clear current_identifier to force a full re-detection with database lookup
    new_state =
      if in_grace_period?(state) do
        do_detect_train(%{state | current_identifier: nil}, state.grace_client)
      else
        detect_train(%{state | current_identifier: nil})
      end

    {:noreply, new_state}
  end

  @impl true
  def handle_info(:check_connection, %State{} = state) do
    case get_simulator_status() do
      %ConnectionState{status: :connected} ->
        schedule_poll()
        {:noreply, %{state | polling_enabled: true}}

      _ ->
        {:noreply, %{state | polling_enabled: false}}
    end
  end

  @impl true
  def handle_info(:poll, %State{polling_enabled: true} = state) do
    new_state = detect_train(state)
    schedule_poll()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:poll, %State{polling_enabled: false} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:simulator_status_changed, %ConnectionState{status: :connected}},
        %State{} = state
      ) do
    Logger.info("Simulator connected, enabling train detection polling")
    state = exit_grace_period(state)
    schedule_poll()
    new_state = %{state | polling_enabled: true}
    # Trigger immediate detection
    send(self(), :poll)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:simulator_status_changed, %ConnectionState{}}, %State{} = state) do
    Logger.info("Simulator disconnected, disabling train detection polling")
    new_state = %{state | polling_enabled: false}

    cond do
      in_grace_period?(new_state) ->
        # Already in grace period, don't re-enter
        {:noreply, new_state}

      new_state.active_train != nil ->
        # Active train exists — enter grace period instead of deactivating
        {:noreply, enter_grace_period(new_state)}

      true ->
        # No active train — deactivate as before
        {:noreply, deactivate_train(new_state)}
    end
  end

  @impl true
  def handle_info(:grace_poll, %State{grace_client: nil} = state) do
    # Grace period was exited (e.g., connection recovered), ignore late message
    {:noreply, state}
  end

  @impl true
  def handle_info(:grace_poll, %State{grace_client: %Client{}} = state) do
    {:noreply, perform_grace_poll(state)}
  end

  # Private Functions

  defp detect_train(%State{} = state) do
    case get_simulator_status() do
      %ConnectionState{status: :connected, client: %Client{} = client} ->
        do_detect_train(%{state | last_client: client}, client)

      _ ->
        state
    end
  end

  defp do_detect_train(%State{} = state, %Client{} = client) do
    case Identifier.derive_from_formation(client) do
      {:ok, identifier} ->
        state = %{state | last_successful_contact: System.monotonic_time(:millisecond)}
        handle_identifier_detected(state, identifier)

      {:error, reason} ->
        Logger.warning("Failed to detect train: #{inspect(reason)}")
        broadcast({:detection_error, reason})
        state
    end
  end

  defp handle_identifier_detected(%State{current_identifier: identifier} = state, identifier) do
    # Same train, no change - just update last_check
    %{state | last_check: DateTime.utc_now()}
  end

  defp handle_identifier_detected(%State{} = state, identifier) do
    # Different train detected
    Logger.info("Train identifier changed: #{identifier}")

    case Train.get_train_by_identifier(identifier) do
      {:ok, train} ->
        broadcast({:train_detected, %{identifier: identifier, train: train}})

        if state.active_train != train do
          broadcast({:train_changed, train})
        end

        %{
          state
          | current_identifier: identifier,
            active_train: train,
            detection_error: nil,
            last_check: DateTime.utc_now()
        }

      {:error, :not_found} ->
        broadcast({:train_detected, %{identifier: identifier, train: nil}})

        if state.active_train != nil do
          broadcast({:train_changed, nil})
        end

        %{
          state
          | current_identifier: identifier,
            active_train: nil,
            detection_error: nil,
            last_check: DateTime.utc_now()
        }

      {:error, {:multiple_matches, trains}} ->
        Logger.warning(
          "Multiple trains match identifier #{identifier}: #{Enum.map_join(trains, ", ", & &1.name)}"
        )

        broadcast({:train_detected, %{identifier: identifier, train: nil}})
        broadcast({:multiple_trains_match, %{identifier: identifier, trains: trains}})

        if state.active_train != nil do
          broadcast({:train_changed, nil})
        end

        %{
          state
          | current_identifier: identifier,
            active_train: nil,
            detection_error: {:multiple_matches, trains},
            last_check: DateTime.utc_now()
        }
    end
  end

  defp perform_grace_poll(%State{} = state) do
    case Identifier.derive_from_formation(state.grace_client) do
      {:ok, _identifier} ->
        new_state = %{state | last_successful_contact: System.monotonic_time(:millisecond)}
        schedule_grace_poll()
        new_state

      {:error, _reason} ->
        handle_grace_poll_failure(state)
    end
  end

  defp handle_grace_poll_failure(%State{} = state) do
    elapsed = System.monotonic_time(:millisecond) - state.last_successful_contact

    if elapsed >= grace_period_ms() do
      Logger.warning("Grace period expired after #{elapsed}ms, deactivating train")
      deactivate_train(exit_grace_period(state))
    else
      schedule_grace_poll()
      state
    end
  end

  defp schedule_poll do
    Process.send_after(self(), :poll, @poll_interval_ms)
  end

  defp schedule_grace_poll do
    Process.send_after(self(), :grace_poll, @grace_poll_interval_ms)
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(Trenino.PubSub, @pubsub_topic, message)
  end

  # Safely get simulator status, handling the case where SimulatorConnection
  # is not running (e.g., in test environment)
  defp get_simulator_status do
    if Process.whereis(SimulatorConnection) do
      SimulatorConnection.get_status()
    else
      %ConnectionState{status: :disconnected}
    end
  end

  # Grace period helpers

  defp grace_period_ms do
    Application.get_env(:trenino, :detection_grace_period_ms, @grace_period_ms)
  end

  defp in_grace_period?(%State{grace_client: nil}), do: false
  defp in_grace_period?(%State{grace_client: %Client{}}), do: true

  defp enter_grace_period(%State{last_client: %Client{} = client} = state) do
    grace_client = Client.with_fast_timeouts(client)

    Logger.info(
      "Entering grace period (#{grace_period_ms()}ms) for train: #{inspect(state.active_train && state.active_train.name)}"
    )

    now = System.monotonic_time(:millisecond)

    new_state = %{
      state
      | grace_client: grace_client,
        last_successful_contact: state.last_successful_contact || now
    }

    schedule_grace_poll()
    new_state
  end

  defp enter_grace_period(%State{} = state) do
    Logger.warning("No client available for grace period, deactivating train immediately")
    deactivate_train(state)
  end

  defp exit_grace_period(%State{grace_timer: nil} = state) do
    %{state | grace_client: nil, grace_timer: nil}
  end

  defp exit_grace_period(%State{grace_timer: timer} = state) do
    Process.cancel_timer(timer)
    %{state | grace_client: nil, grace_timer: nil}
  end

  defp deactivate_train(%State{} = state) do
    new_state = %{
      state
      | active_train: nil,
        current_identifier: nil,
        detection_error: nil,
        last_successful_contact: nil
    }

    broadcast({:train_changed, nil})
    new_state
  end
end
