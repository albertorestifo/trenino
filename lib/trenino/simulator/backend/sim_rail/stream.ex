defmodule Trenino.Simulator.Backend.SimRail.Stream do
  @moduledoc """
  One WebSocket connection to the bridge's `/api/v1/stream` per SimRail
  handle, shared by every process watching through that handle.

  * Each watcher pid has its own set of paths (exact `Group.field`,
    `Group.*` or `*`). The bridge is subscribed to the union; a path is
    unsubscribed once no watcher wants it. Watchers are monitored.
  * `{:simulator_values, %{path => value}}` goes to each watcher with only
    its paths: the current values when it subscribes (and after reconnects
    and vehicle changes), then the changes the bridge pushes.
  * `{:simulator_vehicle, name | nil}` goes to all watchers when the
    player's vehicle changes, and to a new watcher when the vehicle is known.
  * Connection loss reconnects with exponential backoff and resubscribes.

  Started under `StreamSupervisor`, registered in `Trenino.Registry` by the
  handle's ref.
  """

  use GenServer, restart: :transient

  require Logger

  alias Trenino.Simulator.Backend.SimRail
  alias Trenino.Simulator.Backend.SimRail.Schema

  @supervisor Trenino.Simulator.Backend.SimRail.StreamSupervisor
  @stream_path "/api/v1/stream"
  @default_backoff_ms 500
  @max_backoff_ms 10_000
  @connect_timeout_ms 1_000
  @upgrade_timeout_ms 5_000

  defmodule State do
    @moduledoc false

    @type status :: :disconnected | :upgrading | :connected

    @type t :: %__MODULE__{
            uri: URI.t(),
            token: String.t() | nil,
            max_hz: pos_integer(),
            min_backoff_ms: pos_integer(),
            max_backoff_ms: pos_integer(),
            backoff_ms: pos_integer(),
            upgrade_timeout_ms: pos_integer(),
            status: status(),
            conn: Mint.HTTP.t() | nil,
            websocket: Mint.WebSocket.t() | nil,
            request_ref: Mint.Types.request_ref() | nil,
            upgrade_status: non_neg_integer() | nil,
            upgrade_headers: Mint.Types.headers(),
            vehicle: {String.t() | nil, term()} | nil,
            watchers: %{pid() => MapSet.t(String.t())},
            monitors: %{pid() => reference()},
            pending: %{pos_integer() => pid()},
            next_id: pos_integer()
          }

    # Keep the bridge token out of crash reports and logs.
    @derive {Inspect, except: [:token]}
    @enforce_keys [
      :uri,
      :max_hz,
      :min_backoff_ms,
      :max_backoff_ms,
      :backoff_ms,
      :upgrade_timeout_ms
    ]
    defstruct [
      :uri,
      :token,
      :max_hz,
      :min_backoff_ms,
      :max_backoff_ms,
      :backoff_ms,
      :upgrade_timeout_ms,
      :conn,
      :websocket,
      :request_ref,
      :upgrade_status,
      :vehicle,
      status: :disconnected,
      upgrade_headers: [],
      watchers: %{},
      monitors: %{},
      pending: %{},
      next_id: 1
    ]
  end

  # Client API

  @doc """
  Replace `pid`'s watched paths, starting the stream if needed.

  Asynchronous: the stream may be busy connecting, so callers never wait
  on it. The stream keeps its watchers only in memory; a watcher that must
  survive a stream crash monitors `whereis/1` (or `SimRail.watch_process/1`) and
  calls `watch/3` again when it goes down.
  """
  @spec watch(SimRail.t(), [String.t()], pid()) :: :ok | {:error, term()}
  def watch(%SimRail{} = handle, paths, pid) do
    case whereis(handle.ref) do
      nil when paths == [] -> :ok
      nil -> with {:ok, stream} <- start(handle), do: cast_watch(stream, paths, pid)
      stream -> cast_watch(stream, paths, pid)
    end
  end

  @doc "Stop the handle's stream, if running."
  @spec stop(reference()) :: :ok
  def stop(ref) do
    case whereis(ref) do
      nil ->
        :ok

      pid ->
        _ = DynamicSupervisor.terminate_child(@supervisor, pid)
        :ok
    end
  end

  @doc "The stream process for a handle ref, or nil."
  @spec whereis(reference()) :: pid() | nil
  def whereis(ref) do
    case Registry.lookup(Trenino.Registry, {__MODULE__, ref}) do
      # The registry drops a stopped stream asynchronously.
      [{pid, _}] -> if Process.alive?(pid), do: pid
      [] -> nil
    end
  end

  @doc false
  def start_link(%SimRail{} = handle) do
    GenServer.start_link(__MODULE__, handle,
      name: {:via, Registry, {Trenino.Registry, {__MODULE__, handle.ref}}}
    )
  end

  defp start(handle) do
    case DynamicSupervisor.start_child(@supervisor, {__MODULE__, handle}) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, _} = error -> error
    end
  end

  defp cast_watch(stream, paths, pid), do: GenServer.cast(stream, {:watch, pid, paths})

  # Server

  @impl true
  def init(%SimRail{} = handle) do
    backoff = Keyword.get(handle.stream_opts, :backoff_ms, @default_backoff_ms)

    state = %State{
      uri: URI.parse(handle.url),
      token: handle.api_key,
      max_hz: handle.max_hz,
      min_backoff_ms: backoff,
      max_backoff_ms: Keyword.get(handle.stream_opts, :max_backoff_ms, @max_backoff_ms),
      backoff_ms: backoff,
      upgrade_timeout_ms:
        Keyword.get(handle.stream_opts, :upgrade_timeout_ms, @upgrade_timeout_ms)
    }

    send(self(), :connect)
    {:ok, state}
  end

  @impl true
  def handle_cast({:watch, pid, paths}, %State{} = state) do
    {:noreply, set_watch(state, pid, MapSet.new(paths))}
  end

  @impl true
  def handle_info(:connect, %State{status: :disconnected} = state) do
    case open(state) do
      {:ok, conn, ref} ->
        # A bridge that accepts the socket but never answers the upgrade.
        Process.send_after(self(), {:upgrade_timeout, ref}, state.upgrade_timeout_ms)
        {:noreply, %{state | conn: conn, request_ref: ref, status: :upgrading}}

      {:error, reason} ->
        Logger.debug("SimRail stream connect failed: #{inspect(reason)}")
        {:noreply, schedule_reconnect(state)}
    end
  end

  def handle_info(:connect, %State{} = state), do: {:noreply, state}

  def handle_info({:upgrade_timeout, ref}, %State{status: :upgrading, request_ref: ref} = state) do
    {:noreply, reconnect(state, :upgrade_timeout)}
  end

  def handle_info({:upgrade_timeout, _ref}, %State{} = state), do: {:noreply, state}

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %State{} = state) do
    {:noreply, set_watch(state, pid, MapSet.new())}
  end

  def handle_info(message, %State{conn: conn} = state) when not is_nil(conn) do
    case Mint.WebSocket.stream(conn, message) do
      {:ok, conn, responses} ->
        {:noreply, Enum.reduce(responses, %{state | conn: conn}, &handle_response/2)}

      {:error, conn, reason, _responses} ->
        {:noreply, reconnect(%{state | conn: conn}, reason)}

      :unknown ->
        {:noreply, state}
    end
  end

  def handle_info(_message, %State{} = state), do: {:noreply, state}

  @impl true
  def terminate(_reason, %State{conn: conn}) do
    if conn, do: Mint.HTTP.close(conn)
    :ok
  end

  # Connection

  defp open(%State{uri: uri} = state) do
    {http_scheme, ws_scheme} = if uri.scheme == "https", do: {:https, :wss}, else: {:http, :ws}

    with {:ok, conn} <-
           Mint.HTTP.connect(http_scheme, uri.host, uri.port,
             protocols: [:http1],
             transport_opts: [timeout: @connect_timeout_ms]
           ) do
      case Mint.WebSocket.upgrade(
             ws_scheme,
             conn,
             @stream_path,
             SimRail.auth_headers(state.token)
           ) do
        {:ok, conn, ref} ->
          {:ok, conn, ref}

        {:error, conn, reason} ->
          Mint.HTTP.close(conn)
          {:error, reason}
      end
    end
  end

  defp handle_response(_response, %State{status: :disconnected} = state), do: state

  defp handle_response({:status, ref, status}, %State{request_ref: ref} = state),
    do: %{state | upgrade_status: status}

  defp handle_response({:headers, ref, headers}, %State{request_ref: ref} = state),
    do: %{state | upgrade_headers: state.upgrade_headers ++ headers}

  defp handle_response({:done, ref}, %State{request_ref: ref, status: :upgrading} = state) do
    case Mint.WebSocket.new(state.conn, ref, state.upgrade_status, state.upgrade_headers) do
      {:ok, conn, websocket} ->
        Logger.info("SimRail stream connected to #{URI.to_string(state.uri)}")

        %{state | conn: conn, websocket: websocket, status: :connected}
        |> Map.put(:backoff_ms, state.min_backoff_ms)
        |> subscribe_all()

      {:error, conn, reason} ->
        reconnect(%{state | conn: conn}, reason)
    end
  end

  defp handle_response({:data, ref, data}, %State{request_ref: ref, websocket: ws} = state)
       when not is_nil(ws) do
    case Mint.WebSocket.decode(ws, data) do
      {:ok, ws, frames} -> Enum.reduce(frames, %{state | websocket: ws}, &handle_frame/2)
      {:error, ws, reason} -> reconnect(%{state | websocket: ws}, reason)
    end
  end

  defp handle_response({:error, ref, reason}, %State{request_ref: ref} = state),
    do: reconnect(state, reason)

  defp handle_response(_response, %State{} = state), do: state

  defp handle_frame(_frame, %State{status: :disconnected} = state), do: state

  defp handle_frame({:text, text}, %State{} = state) do
    case Jason.decode(text) do
      {:ok, message} when is_map(message) -> handle_message(message, state)
      _ -> state
    end
  end

  defp handle_frame({:ping, data}, %State{} = state), do: send_frame(state, {:pong, data})

  defp handle_frame({:close, code, reason}, %State{} = state),
    do: reconnect(state, {:closed, code, reason})

  defp handle_frame(_frame, %State{} = state), do: state

  defp reconnect(%State{} = state, reason) do
    Logger.debug("SimRail stream disconnected: #{inspect(reason)}")
    if state.conn, do: Mint.HTTP.close(state.conn)

    state =
      %{
        state
        | conn: nil,
          websocket: nil,
          request_ref: nil,
          upgrade_status: nil,
          upgrade_headers: [],
          pending: %{},
          status: :disconnected
      }

    schedule_reconnect(state)
  end

  defp schedule_reconnect(%State{backoff_ms: backoff} = state) do
    Process.send_after(self(), :connect, backoff)
    %{state | backoff_ms: min(backoff * 2, state.max_backoff_ms)}
  end

  # Messages from the bridge

  defp handle_message(%{"op" => "vehicle"} = message, %State{} = state) do
    schema = message["vehicle"]
    vehicle = {Schema.vehicle_name(schema), schema && schema["generation"]}

    if vehicle == state.vehicle do
      state
    else
      # Watchers reset on a vehicle message and the bridge pushes only
      # changes, so resubscribe to have the current values sent again.
      %{state | vehicle: vehicle} |> broadcast_vehicle() |> subscribe_all()
    end
  end

  defp handle_message(%{"op" => "values", "values" => values}, %State{} = state)
       when is_map(values) do
    values = SimRail.normalize_values(values)
    Enum.each(state.watchers, fn {pid, paths} -> deliver(pid, paths, values) end)
    state
  end

  defp handle_message(%{"id" => id, "ok" => true} = reply, %State{} = state) do
    {pid, pending} = Map.pop(state.pending, id)

    with pid when is_pid(pid) <- pid,
         %{} = values <- reply["values"],
         %MapSet{} = paths <- Map.get(state.watchers, pid) do
      deliver(pid, paths, SimRail.normalize_values(values))
    end

    %{state | pending: pending}
  end

  defp handle_message(%{"id" => id, "ok" => false} = reply, %State{} = state) do
    Logger.warning("SimRail stream request failed: #{inspect(reply["error"])}")
    %{state | pending: Map.delete(state.pending, id)}
  end

  defp handle_message(_message, %State{} = state), do: state

  defp broadcast_vehicle(%State{vehicle: {name, _generation}} = state) do
    Enum.each(Map.keys(state.watchers), &send(&1, {:simulator_vehicle, name}))
    state
  end

  defp deliver(pid, paths, values) do
    matching = Map.filter(values, fn {path, _value} -> watched?(paths, path) end)
    if map_size(matching) > 0, do: send(pid, {:simulator_values, matching})
  end

  defp watched?(paths, path) do
    MapSet.member?(paths, path) or Enum.any?(paths, &pattern_match?(&1, path))
  end

  defp pattern_match?("*", _path), do: true

  defp pattern_match?(pattern, path) do
    String.ends_with?(pattern, ".*") and
      String.starts_with?(path, String.trim_trailing(pattern, "*"))
  end

  # Watchers

  defp set_watch(%State{} = state, pid, new_paths) do
    old_union = all_paths(state)
    old_paths = Map.get(state.watchers, pid, MapSet.new())
    new_watcher? = not Map.has_key?(state.watchers, pid)

    state =
      if MapSet.size(new_paths) == 0,
        do: remove_watcher(state, pid),
        else: put_watcher(state, pid, new_paths, new_watcher?)

    removed = MapSet.difference(old_union, all_paths(state))
    added = MapSet.difference(new_paths, old_paths)

    state
    |> unsubscribe(removed)
    |> subscribe(pid, added)
  end

  defp put_watcher(state, pid, paths, new_watcher?) do
    state =
      if new_watcher?,
        do: %{state | monitors: Map.put(state.monitors, pid, Process.monitor(pid))},
        else: state

    if new_watcher? and match?({_name, _generation}, state.vehicle) do
      {name, _generation} = state.vehicle
      send(pid, {:simulator_vehicle, name})
    end

    %{state | watchers: Map.put(state.watchers, pid, paths)}
  end

  defp remove_watcher(state, pid) do
    {monitor, monitors} = Map.pop(state.monitors, pid)
    if monitor, do: Process.demonitor(monitor, [:flush])

    %{state | watchers: Map.delete(state.watchers, pid), monitors: monitors}
  end

  defp all_paths(%State{watchers: watchers}) do
    watchers |> Map.values() |> Enum.reduce(MapSet.new(), &MapSet.union/2)
  end

  # Requests to the bridge

  defp subscribe_all(%State{} = state) do
    Enum.reduce(state.watchers, state, fn {pid, paths}, acc -> subscribe(acc, pid, paths) end)
  end

  defp subscribe(%State{status: :connected} = state, pid, paths) do
    if MapSet.size(paths) == 0 do
      state
    else
      id = state.next_id
      state = %{state | next_id: id + 1, pending: Map.put(state.pending, id, pid)}

      send_json(state, %{
        id: id,
        op: "subscribe",
        paths: MapSet.to_list(paths),
        maxHz: state.max_hz
      })
    end
  end

  defp subscribe(%State{} = state, _pid, _paths), do: state

  defp unsubscribe(%State{status: :connected} = state, paths) do
    if MapSet.size(paths) == 0,
      do: state,
      else: send_json(state, %{op: "unsubscribe", paths: MapSet.to_list(paths)})
  end

  defp unsubscribe(%State{} = state, _paths), do: state

  defp send_json(state, message), do: send_frame(state, {:text, Jason.encode!(message)})

  defp send_frame(%State{status: :connected, websocket: ws, conn: conn} = state, frame) do
    with {:ok, ws, data} <- Mint.WebSocket.encode(ws, frame),
         {:ok, conn} <- Mint.WebSocket.stream_request_body(conn, state.request_ref, data) do
      %{state | websocket: ws, conn: conn}
    else
      {:error, %Mint.WebSocket{} = ws, reason} -> reconnect(%{state | websocket: ws}, reason)
      {:error, conn, reason} -> reconnect(%{state | conn: conn}, reason)
    end
  end

  defp send_frame(%State{} = state, _frame), do: state
end
