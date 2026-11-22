defmodule Trenino.Simulator.Connection do
  @moduledoc """
  Manages the connection to the simulator chosen in `Trenino.Settings`
  (Train Sim World or SimRail).

  The backend (`Trenino.Simulator.Backend` implementation) creates the
  handle with `connect/1` and is reached with `check/1` for the initial
  connection test and health checks; `disconnect/1` releases the handle on
  disconnect, reconfiguration and reconnects.

  Handles:
  - Periodic health checks (every 30s when connected)
  - Connection retry logic (every 30s on failure)
  - PubSub broadcasts for state changes
  """

  use GenServer
  require Logger

  alias Trenino.Settings
  alias Trenino.Simulator.Backend
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.ConnectionState

  @health_check_interval_ms 30_000
  @fast_health_check_interval_ms 2_000
  @max_health_failures 3
  @retry_interval_ms 30_000
  @pubsub_topic "simulator:connection"

  @default_backends %{tsw: Backend.TSW, simrail: Backend.SimRail}

  defmodule State do
    @moduledoc false

    alias Trenino.Simulator.ConnectionState

    @type t :: %__MODULE__{
            connection: ConnectionState.t(),
            check_ref: reference() | nil
          }

    defstruct connection: ConnectionState.new(), check_ref: nil
  end

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Get the current connection status.

  Returns a default disconnected state if the GenServer is not running
  (e.g., in test environment where it's disabled).
  """
  @spec get_status() :: ConnectionState.t()
  def get_status do
    if Process.whereis(__MODULE__) do
      GenServer.call(__MODULE__, :get_status)
    else
      ConnectionState.new()
    end
  end

  @doc """
  Subscribe to connection state change events.

  Subscribers receive `{:simulator_status_changed, ConnectionState.t()}` messages.
  """
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe do
    Phoenix.PubSub.subscribe(Trenino.PubSub, @pubsub_topic)
  end

  @doc """
  Manually trigger a connection retry.

  No-op if the GenServer is not running (e.g., in test environment).
  """
  @spec retry_connection() :: :ok
  def retry_connection do
    if Process.whereis(__MODULE__) do
      GenServer.cast(__MODULE__, :connect)
    end

    :ok
  end

  @doc """
  Reconfigure the connection with updated settings.

  Called automatically when configuration changes.
  No-op if the GenServer is not running (e.g., in test environment).
  """
  @spec reconfigure() :: :ok
  def reconfigure do
    if Process.whereis(__MODULE__) do
      GenServer.cast(__MODULE__, :reconfigure)
    end

    :ok
  end

  @doc """
  Disconnect from the simulator.

  No-op if the GenServer is not running (e.g., in test environment).
  """
  @spec disconnect() :: :ok
  def disconnect do
    if Process.whereis(__MODULE__) do
      GenServer.cast(__MODULE__, :disconnect)
    end

    :ok
  end

  @doc """
  The backend module for a simulator. Overridable per simulator with the
  `:simulator_backends` application env (a map of simulator to module).
  """
  @spec backend_for(Trenino.Simulator.simulator()) :: module()
  def backend_for(simulator) do
    :trenino
    |> Application.get_env(:simulator_backends, %{})
    |> Map.get_lazy(simulator, fn -> Map.fetch!(@default_backends, simulator) end)
  end

  # Server callbacks

  @impl true
  def init(:ok) do
    # Attempt initial connection after a short delay
    delay = Application.get_env(:trenino, :connection_initial_delay_ms, 1_000)
    schedule_connect(delay)
    {:ok, %State{}}
  end

  @impl true
  def handle_call(:get_status, _from, %State{connection: connection} = state) do
    {:reply, connection, state}
  end

  @impl true
  def handle_cast(:connect, %State{} = state) do
    {:noreply, state |> attempt_connection() |> broadcast()}
  end

  @impl true
  def handle_cast(:reconfigure, %State{} = state) do
    # Disconnect existing connection and reconnect with new config
    new_state = release(state)
    schedule_connect(500)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:disconnect, %State{} = state) do
    {:noreply, state |> release() |> broadcast()}
  end

  @impl true
  def handle_info(:connect, %State{} = state) do
    {:noreply, state |> attempt_connection() |> broadcast()}
  end

  @impl true
  def handle_info(:health_check, %State{connection: %ConnectionState{status: :connected}} = state) do
    new_state = perform_health_check(state)

    case new_state.connection do
      %ConnectionState{status: :connected, health_failures: 0} ->
        # Healthy — resume normal interval
        schedule_health_check()
        {:noreply, new_state}

      %ConnectionState{status: :connected, health_failures: failures}
      when failures < @max_health_failures ->
        # Transient failure — fast retry, no broadcast
        schedule_fast_health_check()
        {:noreply, new_state}

      _ ->
        # Status changed to :error (permanent error or max failures exceeded)
        schedule_retry()
        {:noreply, broadcast(new_state)}
    end
  end

  @impl true
  def handle_info(:health_check, %State{} = state) do
    # Not connected, skip health check but keep scheduling
    schedule_health_check()
    {:noreply, state}
  end

  @impl true
  def handle_info(:retry, %State{} = state) do
    {:noreply, state |> attempt_connection() |> broadcast()}
  end

  # Result of the current connection check
  @impl true
  def handle_info({ref, result}, %State{check_ref: ref} = state) when is_reference(ref) do
    # Flush the DOWN message from the task
    Process.demonitor(ref, [:flush])

    new_state = handle_connection_result(%{state | check_ref: nil}, result)
    {:noreply, broadcast(new_state)}
  end

  # Result of a check superseded by a reconnect or reconfiguration
  @impl true
  def handle_info({ref, _result}, %State{} = state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, state}
  end

  # The current connection check crashed
  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, %State{check_ref: ref} = state) do
    Logger.warning("Connection task crashed: #{inspect(reason)}")
    schedule_retry()

    new_state = %{
      state
      | check_ref: nil,
        connection: ConnectionState.mark_error(state.connection, :connection_failed)
    }

    {:noreply, broadcast(new_state)}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %State{} = state) do
    {:noreply, state}
  end

  # Private functions

  defp handle_connection_result(%State{connection: connection} = state, {:ok, info})
       when is_map(info) do
    Logger.info("Successfully connected to #{simulator_name(connection.backend)}")
    schedule_health_check()
    %{state | connection: ConnectionState.mark_connected(connection, info)}
  end

  defp handle_connection_result(%State{connection: connection} = state, {:error, reason}) do
    name = simulator_name(connection.backend)
    schedule_retry()

    case error_reason(reason) do
      :invalid_key ->
        Logger.warning("Failed to connect to #{name}: invalid API key")
        %{state | connection: ConnectionState.mark_error(connection, :invalid_key)}

      error ->
        Logger.warning("Failed to connect to #{name}: #{inspect(reason)}")
        %{state | connection: ConnectionState.mark_error(connection, error)}
    end
  end

  defp handle_connection_result(%State{} = state, other),
    do: handle_connection_result(state, {:error, {:unexpected_result, other}})

  defp attempt_connection(%State{} = state) do
    state = release_handle(state)
    simulator = Settings.simulator()
    backend = backend_for(simulator)

    with {:ok, config} <- backend_config(simulator),
         {:ok, handle} <- backend.connect(config) do
      start_check(state, backend, handle)
    else
      {:error, :needs_config} ->
        %{state | connection: ConnectionState.mark_needs_config(state.connection)}

      {:error, reason} ->
        Logger.warning("Failed to connect to #{simulator_name(backend)}: #{inspect(reason)}")
        schedule_retry()
        connecting = ConnectionState.mark_connecting(state.connection, backend, nil)
        %{state | connection: ConnectionState.mark_error(connecting, :connection_failed)}
    end
  end

  defp backend_config(:tsw) do
    case Settings.api_key() do
      {:ok, api_key} -> {:ok, %{url: Settings.simulator_url(), api_key: api_key}}
      {:error, _reason} -> {:error, :needs_config}
    end
  end

  defp backend_config(:simrail) do
    case String.trim(Settings.simrail_url()) do
      "" -> {:error, :needs_config}
      url -> {:ok, %{url: url, api_key: Settings.simrail_token()}}
    end
  end

  defp start_check(%State{} = state, backend, handle) do
    Logger.debug("Attempting to connect to #{simulator_name(backend)}")

    # Check asynchronously so the GenServer doesn't block. The result is
    # handled in handle_info({ref, result}, ...).
    task =
      Task.Supervisor.async_nolink(Trenino.TaskSupervisor, fn -> backend.check(handle) end)

    %{
      state
      | connection: ConnectionState.mark_connecting(state.connection, backend, handle),
        check_ref: task.ref
    }
  end

  defp perform_health_check(%State{connection: %ConnectionState{client: nil}} = state) do
    %{state | connection: ConnectionState.mark_error(state.connection, :no_client)}
  end

  defp perform_health_check(%State{connection: connection} = state) do
    %ConnectionState{backend: backend, client: handle} = connection

    new_connection =
      case backend.check(health_check_handle(backend, handle)) do
        {:ok, info} ->
          ConnectionState.mark_connected(connection, info)

        {:error, reason} ->
          case error_reason(reason) do
            :invalid_key ->
              # Permanent error — immediately broadcast
              Logger.warning("Health check failed: invalid API key")
              ConnectionState.mark_error(connection, :invalid_key)

            _ ->
              handle_transient_health_failure(connection, reason)
          end
      end

    %{state | connection: new_connection}
  end

  # TSW health checks use short timeouts so a hung game is noticed quickly.
  defp health_check_handle(Backend.TSW, %Client{} = client), do: Client.with_fast_timeouts(client)
  defp health_check_handle(_backend, handle), do: handle

  defp handle_transient_health_failure(%ConnectionState{} = connection, reason) do
    new_connection = ConnectionState.record_health_failure(connection, :connection_failed)

    if new_connection.health_failures >= @max_health_failures do
      Logger.warning(
        "Health check failed #{new_connection.health_failures} consecutive times: #{inspect(reason)}"
      )

      ConnectionState.mark_error(new_connection, :connection_failed)
    else
      Logger.debug(
        "Transient health check failure (#{new_connection.health_failures}/#{@max_health_failures}): #{inspect(reason)}"
      )

      new_connection
    end
  end

  # A rejected key (TSW) or token (SimRail bridge, HTTP 401) is permanent.
  defp error_reason({:invalid_key, _}), do: :invalid_key
  defp error_reason(:invalid_key), do: :invalid_key
  defp error_reason(:unauthorized), do: :invalid_key
  defp error_reason({:unauthorized, _}), do: :invalid_key
  defp error_reason(_reason), do: :connection_failed

  # Disconnects the handle and marks the connection disconnected.
  defp release(%State{} = state) do
    state = release_handle(state)
    %{state | connection: ConnectionState.mark_disconnected(state.connection)}
  end

  # Releases the backend handle, if any, and forgets the pending check.
  defp release_handle(%State{connection: %ConnectionState{client: nil}} = state),
    do: %{state | check_ref: nil}

  defp release_handle(%State{connection: connection} = state) do
    %ConnectionState{backend: backend, client: handle} = connection

    try do
      backend.disconnect(handle)
    rescue
      error -> Logger.warning("Disconnecting the simulator failed: #{inspect(error)}")
    end

    %{state | check_ref: nil, connection: %{connection | client: nil}}
  end

  defp simulator_name(backend) do
    case backend do
      Backend.TSW -> "TSW API"
      _ -> "simulator (#{inspect(backend)})"
    end
  end

  defp schedule_connect(delay_ms) do
    Process.send_after(self(), :connect, delay_ms)
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @health_check_interval_ms)
  end

  defp schedule_fast_health_check do
    Process.send_after(self(), :health_check, @fast_health_check_interval_ms)
  end

  defp schedule_retry do
    Process.send_after(self(), :retry, @retry_interval_ms)
  end

  defp broadcast(%State{connection: connection} = state) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      @pubsub_topic,
      {:simulator_status_changed, connection}
    )

    state
  end
end
