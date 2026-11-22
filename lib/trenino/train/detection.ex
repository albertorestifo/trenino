defmodule Trenino.Train.Detection do
  @moduledoc """
  Monitors the simulator for train changes and manages the active train configuration.

  Responsibilities:
  - Poll the connected simulator's vehicle id (`Trenino.Simulator.vehicle_id/0`)
    periodically; TSW derives it from the formation, SimRail reports the
    vehicle name (`"4e/eu07-193"`)
  - Match the vehicle id to stored train configurations made for the connected
    simulator (`Trenino.Simulator.current/0`), by identifier prefix
  - Broadcast train change events via PubSub

  Simulator requests run in a task under `Trenino.TaskSupervisor`, one at a time, so a
  slow or hung simulator never blocks reads such as `get_active_train/0`. Results are
  applied by the GenServer; results of a task cancelled by a connection change are dropped.

  ## Vehicle events

  Backends with `:vehicle_events` report vehicle changes as
  `{:simulator_vehicle, vehicle_id | nil}`. Whoever receives them from the
  backend (the simulator watcher) forwards them with `vehicle_changed/1` (or
  sends the message to this process) to apply the change without waiting for
  the next poll. Polling continues either way.

  ## Events

  Subscribers receive messages on "train:detection":
  - `{:train_detected, %{identifier: String.t(), train: Train.t() | nil}}`
  - `{:train_changed, Train.t() | nil}`
  - `{:multiple_trains_match, %{identifier: String.t(), trains: [Train.t()]}}`
  - `{:detection_error, term()}`
  """

  use GenServer
  require Logger

  alias Trenino.Simulator
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train

  @poll_interval_ms 5_000
  @grace_period_ms 30_000
  @grace_poll_interval_ms 200
  @pubsub_topic "train:detection"

  defmodule State do
    @moduledoc false

    @type detection_error :: {:multiple_matches, [Train.Train.t()]} | nil

    @typedoc """
    Simulator work running in a task:
    - `:detect` - regular poll or sync, through the `Trenino.Simulator` facade
    - `:grace_detect` - sync during the grace period, using the grace connection
    - `:grace_poll` - grace period liveness check
    """
    @type task_kind :: :detect | :grace_detect | :grace_poll

    @typedoc """
    A backend module and its opaque handle, remembered from the last detection
    so the grace period can keep asking the simulator after
    `Simulator.Connection` reports it gone.
    """
    @type connection :: {module(), term()}

    @type t :: %__MODULE__{
            active_train: Train.Train.t() | nil,
            current_identifier: String.t() | nil,
            simulator: Trenino.Simulator.simulator() | nil,
            last_check: DateTime.t() | nil,
            polling_enabled: boolean(),
            detection_error: detection_error(),
            last_successful_contact: integer() | nil,
            last_connection: connection() | nil,
            grace_connection: connection() | nil,
            grace_timer: reference() | nil,
            task: Task.t() | nil,
            task_kind: task_kind() | nil,
            sync_pending: boolean()
          }

    defstruct active_train: nil,
              current_identifier: nil,
              simulator: nil,
              last_check: nil,
              polling_enabled: false,
              detection_error: nil,
              last_successful_contact: nil,
              last_connection: nil,
              grace_connection: nil,
              grace_timer: nil,
              task: nil,
              task_kind: nil,
              sync_pending: false
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

  @doc """
  Apply a vehicle change pushed by a backend with `:vehicle_events`
  (`{:simulator_vehicle, vehicle_id | nil}`). `nil` means the player left
  the vehicle.
  """
  @spec vehicle_changed(String.t() | nil) :: :ok
  def vehicle_changed(vehicle_id) when is_binary(vehicle_id) or is_nil(vehicle_id) do
    send(__MODULE__, {:simulator_vehicle, vehicle_id})
    :ok
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
    state = %{state | current_identifier: nil}

    new_state =
      case state do
        # A running detection applies its result against the cleared identifier,
        # so it already performs the full re-detection.
        %State{task_kind: kind} when kind in [:detect, :grace_detect] -> state
        # A grace poll doesn't detect; run the sync once it completes.
        %State{task_kind: :grace_poll} -> %{state | sync_pending: true}
        %State{task: nil} -> start_sync(state)
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
    new_state = if state.task, do: state, else: start_task(state, :detect)
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
    state = state |> cancel_task() |> exit_grace_period()
    schedule_poll()
    new_state = %{state | polling_enabled: true}
    # Trigger immediate detection
    send(self(), :poll)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:simulator_status_changed, %ConnectionState{}}, %State{} = state) do
    Logger.info("Simulator disconnected, disabling train detection polling")

    # A detection cancelled here may have absorbed a sync (the sync cleared
    # current_identifier while a train was active); redo it in the grace period.
    sync_lost? =
      state.task_kind in [:detect, :grace_detect] and state.current_identifier == nil and
        state.active_train != nil

    # A grace poll in flight keeps running; anything else used the full-timeout
    # handle and may be hung on the simulator that just went away.
    state = if state.task_kind == :grace_poll, do: state, else: cancel_task(state)
    new_state = %{state | polling_enabled: false}

    cond do
      in_grace_period?(new_state) ->
        # Already in grace period, don't re-enter
        {:noreply, new_state}

      new_state.active_train != nil ->
        # Active train exists — enter grace period instead of deactivating
        grace_state = enter_grace_period(new_state)

        grace_state =
          if sync_lost? and in_grace_period?(grace_state),
            do: run_pending_sync(%{grace_state | sync_pending: true}),
            else: grace_state

        {:noreply, grace_state}

      true ->
        # No active train — deactivate as before
        {:noreply, deactivate_train(new_state)}
    end
  end

  @impl true
  def handle_info(:grace_poll, %State{grace_connection: nil} = state) do
    # Grace period was exited (e.g., connection recovered), ignore late message
    {:noreply, state}
  end

  @impl true
  def handle_info(:grace_poll, %State{task: %Task{}} = state) do
    # Another simulator request is running: no contact this tick. Check again
    # on the next one, unless the grace period has run out meanwhile.
    {:noreply, handle_grace_poll_failure(state)}
  end

  @impl true
  def handle_info(:grace_poll, %State{} = state) do
    {:noreply, start_task(state, :grace_poll)}
  end

  @impl true
  def handle_info({:simulator_vehicle, vehicle_id}, %State{} = state) do
    {:noreply, apply_vehicle_event(state, vehicle_id)}
  end

  @impl true
  def handle_info({ref, result}, %State{task: %Task{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])
    kind = state.task_kind
    state = %{state | task: nil, task_kind: nil}

    {:noreply, state |> handle_task_result(kind, result) |> run_pending_sync()}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %State{task: %Task{ref: ref}} = state) do
    Logger.warning("Train detection task crashed: #{inspect(reason)}")
    kind = state.task_kind
    state = %{state | task: nil, task_kind: nil}

    state =
      if kind == :grace_poll and in_grace_period?(state),
        do: handle_grace_poll_failure(state),
        else: state

    {:noreply, run_pending_sync(state)}
  end

  # Replies and exits of tasks that were cancelled or dropped by a state reset
  @impl true
  def handle_info({ref, _result}, %State{} = state) when is_reference(ref) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %State{} = state) do
    {:noreply, state}
  end

  # Private Functions

  # Simulator work runs in a task so a slow simulator never blocks reads.
  defp start_task(%State{} = state, kind) do
    work = task_work(state, kind)
    task = Task.Supervisor.async_nolink(Trenino.TaskSupervisor, work)
    %{state | task: task, task_kind: kind}
  end

  defp task_work(%State{}, :detect) do
    fn ->
      case connected() do
        {:ok, backend, handle} -> {:detected, {backend, handle}, Simulator.vehicle_id()}
        {:error, :not_connected} -> :not_connected
      end
    end
  end

  # The facade reports "not connected" during the grace period, so grace work
  # asks the remembered backend directly.
  defp task_work(%State{grace_connection: {backend, handle}}, :grace_detect) do
    fn -> {:detected, nil, backend.vehicle_id(handle)} end
  end

  defp task_work(%State{grace_connection: {backend, handle}}, :grace_poll) do
    fn -> {:grace_polled, backend.vehicle_id(handle)} end
  end

  defp cancel_task(%State{task: nil} = state), do: %{state | sync_pending: false}

  defp cancel_task(%State{task: %Task{} = task} = state) do
    Task.shutdown(task, :brutal_kill)
    %{state | task: nil, task_kind: nil, sync_pending: false}
  end

  defp start_sync(%State{} = state) do
    if in_grace_period?(state),
      do: start_task(state, :grace_detect),
      else: start_task(state, :detect)
  end

  defp run_pending_sync(%State{sync_pending: true, task: nil} = state) do
    start_sync(%{state | sync_pending: false})
  end

  defp run_pending_sync(%State{} = state), do: state

  defp handle_task_result(%State{} = state, _kind, :not_connected), do: state

  defp handle_task_result(%State{} = state, _kind, {:detected, connection, result}) do
    state
    |> remember_connection(connection)
    |> apply_detection(result)
  end

  defp handle_task_result(%State{} = state, :grace_poll, {:grace_polled, result}) do
    if in_grace_period?(state), do: apply_grace_poll(state, result), else: state
  end

  defp remember_connection(%State{} = state, nil), do: state

  defp remember_connection(%State{} = state, {backend, _handle} = connection) do
    simulator = backend.id()

    # Profiles are per simulator: the same vehicle id from another simulator
    # must be looked up again.
    state =
      if state.simulator != simulator, do: %{state | current_identifier: nil}, else: state

    %{state | last_connection: connection, simulator: simulator}
  end

  defp apply_detection(%State{} = state, {:ok, identifier}) do
    state = %{state | last_successful_contact: System.monotonic_time(:millisecond)}
    handle_identifier_detected(state, identifier)
  end

  defp apply_detection(%State{} = state, {:error, reason}) do
    Logger.warning("Failed to detect train: #{inspect(reason)}")
    broadcast({:detection_error, reason})
    state
  end

  # Pushed vehicle changes are applied only while connected and idle; anything
  # skipped is picked up by the next poll.
  defp apply_vehicle_event(%State{polling_enabled: false} = state, _vehicle_id), do: state
  defp apply_vehicle_event(%State{task: %Task{}} = state, _vehicle_id), do: state
  defp apply_vehicle_event(%State{simulator: nil} = state, _vehicle_id), do: state

  defp apply_vehicle_event(%State{} = state, nil) do
    if state.active_train != nil or state.current_identifier != nil,
      do: deactivate_train(state),
      else: state
  end

  defp apply_vehicle_event(%State{} = state, vehicle_id) when is_binary(vehicle_id) do
    apply_detection(state, {:ok, vehicle_id})
  end

  defp handle_identifier_detected(%State{current_identifier: identifier} = state, identifier) do
    # Same train, no change - just update last_check
    %{state | last_check: DateTime.utc_now()}
  end

  defp handle_identifier_detected(%State{} = state, identifier) do
    # Different train detected
    Logger.info("Train identifier changed: #{identifier}")

    case Train.get_train_by_identifier(identifier, state.simulator) do
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

  defp apply_grace_poll(%State{} = state, {:ok, _identifier}) do
    schedule_grace_poll()
    %{state | last_successful_contact: System.monotonic_time(:millisecond)}
  end

  defp apply_grace_poll(%State{} = state, {:error, _reason}) do
    handle_grace_poll_failure(state)
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

  # The facade asks SimulatorConnection, which is not running in tests.
  defp connected do
    if Process.whereis(SimulatorConnection),
      do: Simulator.connected(),
      else: {:error, :not_connected}
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

  defp in_grace_period?(%State{grace_connection: nil}), do: false
  defp in_grace_period?(%State{grace_connection: {_backend, _handle}}), do: true

  defp enter_grace_period(%State{last_connection: {backend, handle}} = state) do
    Logger.info(
      "Entering grace period (#{grace_period_ms()}ms) for train: #{inspect(state.active_train && state.active_train.name)}"
    )

    now = System.monotonic_time(:millisecond)

    new_state = %{
      state
      | grace_connection: {backend, fast_timeouts(handle)},
        last_successful_contact: state.last_successful_contact || now
    }

    schedule_grace_poll()
    new_state
  end

  defp enter_grace_period(%State{} = state) do
    Logger.warning("No connection available for grace period, deactivating train immediately")
    deactivate_train(state)
  end

  # Grace requests must fail fast; only TSW's HTTP client has tunable timeouts.
  defp fast_timeouts(%Client{} = client), do: Client.with_fast_timeouts(client)
  defp fast_timeouts(handle), do: handle

  defp exit_grace_period(%State{} = state) do
    state =
      if state.task_kind in [:grace_poll, :grace_detect], do: cancel_task(state), else: state

    if state.grace_timer, do: Process.cancel_timer(state.grace_timer)
    %{state | grace_connection: nil, grace_timer: nil}
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
