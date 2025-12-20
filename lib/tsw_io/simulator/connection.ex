defmodule TswIo.Simulator.Connection do
  @moduledoc """
  Manages the connection to the Train Sim World API.

  Handles:
  - Periodic health checks (every 30s when connected)
  - Connection retry logic (every 30s on failure)
  - PubSub broadcasts for state changes
  """

  use GenServer
  require Logger

  alias TswIo.Simulator.AutoConfig
  alias TswIo.Simulator.Client
  alias TswIo.Simulator.Config
  alias TswIo.Simulator.ConnectionState

  @health_check_interval_ms 30_000
  @retry_interval_ms 30_000
  @pubsub_topic "simulator:connection"

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
    Phoenix.PubSub.subscribe(TswIo.PubSub, @pubsub_topic)
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

  # Server callbacks

  @impl true
  def init(:ok) do
    # Attempt initial connection after a short delay
    schedule_connect(1_000)
    {:ok, ConnectionState.new()}
  end

  @impl true
  def handle_call(:get_status, _from, %ConnectionState{} = state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast(:connect, %ConnectionState{} = state) do
    new_state = attempt_connection(state)
    broadcast_state_change(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:reconfigure, %ConnectionState{} = state) do
    # Disconnect existing connection and reconnect with new config
    new_state = ConnectionState.mark_disconnected(state)
    schedule_connect(500)
    {:noreply, new_state}
  end

  @impl true
  def handle_cast(:disconnect, %ConnectionState{} = state) do
    new_state = ConnectionState.mark_disconnected(state)
    broadcast_state_change(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:connect, %ConnectionState{} = state) do
    new_state = attempt_connection(state)
    broadcast_state_change(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:health_check, %ConnectionState{status: :connected} = state) do
    new_state = perform_health_check(state)

    if new_state.status != state.status do
      broadcast_state_change(new_state)
    end

    schedule_health_check()
    {:noreply, new_state}
  end

  @impl true
  def handle_info(:health_check, %ConnectionState{} = state) do
    # Not connected, skip health check but keep scheduling
    schedule_health_check()
    {:noreply, state}
  end

  @impl true
  def handle_info(:retry, %ConnectionState{} = state) do
    new_state = attempt_connection(state)
    broadcast_state_change(new_state)
    {:noreply, new_state}
  end

  # Handle async connection task result
  @impl true
  def handle_info({ref, result}, %ConnectionState{} = state) when is_reference(ref) do
    # Flush the DOWN message from the task
    Process.demonitor(ref, [:flush])

    new_state = handle_connection_result(state, result)
    broadcast_state_change(new_state)
    {:noreply, new_state}
  end

  # Handle async task crash
  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, %ConnectionState{} = state) do
    Logger.warning("Connection task crashed: #{inspect(reason)}")
    schedule_retry()
    new_state = ConnectionState.mark_error(state, :connection_failed)
    broadcast_state_change(new_state)
    {:noreply, new_state}
  end

  # Private functions

  defp handle_connection_result(%ConnectionState{} = state, {:ok, info}) do
    Logger.info("Successfully connected to TSW API")
    schedule_health_check()
    ConnectionState.mark_connected(state, info)
  end

  defp handle_connection_result(%ConnectionState{} = state, {:error, {:invalid_key, _}}) do
    Logger.warning("Failed to connect to TSW API: invalid API key")
    schedule_retry()
    ConnectionState.mark_error(state, :invalid_key)
  end

  defp handle_connection_result(%ConnectionState{} = state, {:error, reason}) do
    Logger.warning("Failed to connect to TSW API: #{inspect(reason)}")
    schedule_retry()
    ConnectionState.mark_error(state, :connection_failed)
  end

  defp attempt_connection(%ConnectionState{} = state) do
    case AutoConfig.ensure_config() do
      {:ok, %Config{url: url, api_key: api_key}} ->
        do_connect(state, url, api_key)

      {:error, _reason} ->
        ConnectionState.mark_needs_config(state)
    end
  end

  defp do_connect(%ConnectionState{} = state, url, api_key) do
    Logger.debug("Attempting to connect to TSW API at #{url}")

    client = Client.new(url, api_key)
    state_connecting = ConnectionState.mark_connecting(state, client)

    # Start async connection - don't block the GenServer
    Task.Supervisor.async_nolink(TswIo.TaskSupervisor, fn ->
      Client.info(client)
    end)

    # Return immediately in connecting state
    # Result will be handled in handle_info({ref, result}, ...)
    state_connecting
  end

  defp perform_health_check(%ConnectionState{client: nil} = state) do
    ConnectionState.mark_error(state, :no_client)
  end

  defp perform_health_check(%ConnectionState{client: %Client{} = client} = state) do
    case Client.info(client) do
      {:ok, info} ->
        ConnectionState.mark_connected(state, info)

      {:error, {:invalid_key, _}} ->
        Logger.warning("Health check failed: invalid API key")
        schedule_retry()
        ConnectionState.mark_error(state, :invalid_key)

      {:error, reason} ->
        Logger.warning("Health check failed: #{inspect(reason)}")
        schedule_retry()
        ConnectionState.mark_error(state, :connection_failed)
    end
  end

  defp schedule_connect(delay_ms) do
    Process.send_after(self(), :connect, delay_ms)
  end

  defp schedule_health_check do
    Process.send_after(self(), :health_check, @health_check_interval_ms)
  end

  defp schedule_retry do
    Process.send_after(self(), :retry, @retry_interval_ms)
  end

  defp broadcast_state_change(%ConnectionState{} = state) do
    Phoenix.PubSub.broadcast(
      TswIo.PubSub,
      @pubsub_topic,
      {:simulator_status_changed, state}
    )
  end
end
