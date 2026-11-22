defmodule Trenino.Simulator.Watcher do
  @moduledoc """
  The one place that watches simulator values for the rest of the app.

  A process calls `watch/1` with the paths it needs and then receives
  `{:simulator_values, %{path => value}}` messages (see
  `Trenino.Simulator.Backend.watch/3`). Watches belong to the calling process
  and end with `unwatch/1`, `unwatch_all/0` or when it exits.

  How values arrive depends on the connected backend:

    * with `:push_values` the backend's `watch/3` pushes changes here and they
      are forwarded at once;
    * otherwise the watched paths are read with `Trenino.Simulator.read/1`
      every 200 ms, all of them in one poll however many processes watch
      them.

  Either way every watched path with a known value is delivered every
  200 ms, so a consumer can treat a path that stops arriving as stale. A
  path the simulator cannot read is left out until it can.

  Watches survive reconnects: the watched set is handed to the newly
  connected backend, and again after `{:simulator_vehicle, _}`. Vehicle
  changes and a restart of the watcher itself (`:simulator_watcher_started`,
  after which watches must be made again) are broadcast to `subscribe/0`.
  """

  use GenServer
  require Logger

  alias Trenino.Simulator
  alias Trenino.Simulator.Backend
  alias Trenino.Simulator.Connection
  alias Trenino.Simulator.ConnectionState

  @interval_ms 200
  @poll_timeout_ms 5000
  @topic "simulator:watcher"

  defmodule State do
    @moduledoc false

    alias Trenino.Simulator.Backend

    @type watcher :: %{ref: reference(), paths: MapSet.t(Backend.path())}

    @type t :: %__MODULE__{
            watchers: %{pid() => watcher()},
            backend: module() | nil,
            handle: Backend.handle() | nil,
            mode: :push | :poll | nil,
            pushed: [Backend.path()] | nil,
            values: %{Backend.path() => Backend.value()},
            timer: reference() | nil,
            task: Task.t() | nil
          }

    # `mode` is nil while disconnected. `pushed` is the path list the push
    # backend last accepted (nil: not yet, or it failed and is retried on the
    # next tick). `values` caches the latest value of every watched path.
    defstruct watchers: %{},
              backend: nil,
              handle: nil,
              mode: nil,
              pushed: nil,
              values: %{},
              timer: nil,
              task: nil
  end

  # Client API

  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Watch `paths` for the calling process, in addition to what it already watches."
  @spec watch([Backend.path()]) :: :ok
  def watch(paths) when is_list(paths), do: call_if_running({:watch, self(), paths})

  @doc "Stop watching `paths` for the calling process."
  @spec unwatch([Backend.path()]) :: :ok
  def unwatch(paths) when is_list(paths), do: call_if_running({:unwatch, self(), paths})

  @doc "Stop every watch of the calling process."
  @spec unwatch_all() :: :ok
  def unwatch_all, do: call_if_running({:unwatch_all, self()})

  @doc """
  Subscribe to watcher events: `:simulator_watcher_started` (watches were
  lost and must be made again) and `{:simulator_vehicle, vehicle_id | nil}`.
  """
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe, do: Phoenix.PubSub.subscribe(Trenino.PubSub, @topic)

  # Callers keep working when the watcher is not running (tests) or restarting.
  defp call_if_running(message) do
    if Process.whereis(__MODULE__), do: GenServer.call(__MODULE__, message)
    :ok
  catch
    :exit, _reason -> :ok
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Connection.subscribe()
    {:ok, %State{}, {:continue, :start}}
  end

  @impl true
  def handle_continue(:start, %State{} = state) do
    state = apply_status(state, Connection.get_status())
    Phoenix.PubSub.broadcast(Trenino.PubSub, @topic, :simulator_watcher_started)
    {:noreply, schedule_tick(state)}
  end

  @impl true
  def handle_call({:watch, pid, paths}, _from, %State{} = state) do
    current = watched_paths(state, pid)
    added = paths |> MapSet.new() |> MapSet.difference(current)
    state = put_paths(state, pid, MapSet.union(current, added))

    deliver(pid, Map.take(state.values, MapSet.to_list(added)))
    state = sync_push(state)
    state = if MapSet.size(added) > 0, do: maybe_poll(state), else: state
    {:reply, :ok, state}
  end

  def handle_call({:unwatch, pid, paths}, _from, %State{} = state) do
    remaining = MapSet.difference(watched_paths(state, pid), MapSet.new(paths))
    {:reply, :ok, state |> put_paths(pid, remaining) |> forget_unwatched() |> sync_push()}
  end

  def handle_call({:unwatch_all, pid}, _from, %State{} = state) do
    {:reply, :ok, state |> put_paths(pid, MapSet.new()) |> forget_unwatched() |> sync_push()}
  end

  @impl true
  def handle_info(:tick, %State{} = state) do
    state =
      case state.mode do
        :poll -> maybe_poll(state)
        :push -> state |> sync_push() |> deliver_all(state.values)
        nil -> state
      end

    {:noreply, schedule_tick(state)}
  end

  def handle_info({:simulator_status_changed, %ConnectionState{} = status}, %State{} = state) do
    {:noreply, apply_status(state, status)}
  end

  # Pushed by the backend.
  def handle_info({:simulator_values, values}, %State{mode: :push} = state) when is_map(values) do
    values = Map.take(values, all_paths(state))
    {:noreply, %{state | values: Map.merge(state.values, values)} |> deliver_all(values)}
  end

  def handle_info({:simulator_values, _values}, %State{} = state), do: {:noreply, state}

  # A new vehicle has different controls: start from scratch and hand the
  # watched paths to the backend again.
  def handle_info({:simulator_vehicle, vehicle_id}, %State{} = state) do
    Phoenix.PubSub.broadcast(Trenino.PubSub, @topic, {:simulator_vehicle, vehicle_id})
    {:noreply, sync_push(%{state | values: %{}, pushed: nil})}
  end

  def handle_info({ref, {:polled, result}}, %State{task: %Task{ref: ref}} = state) do
    Process.demonitor(ref, [:flush])
    state = %{state | task: nil}

    case result do
      {:ok, values} when is_map(values) ->
        values = Map.take(values, all_paths(state))
        {:noreply, %{state | values: Map.merge(state.values, values)} |> deliver_all(values)}

      {:error, reason} ->
        Logger.debug("[Simulator.Watcher] Poll failed: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  def handle_info({:poll_timeout, ref}, %State{task: %Task{ref: ref} = task} = state) do
    Logger.warning("[Simulator.Watcher] Poll timed out")
    Task.shutdown(task, :brutal_kill)
    {:noreply, %{state | task: nil}}
  end

  def handle_info({:DOWN, ref, :process, _, reason}, %State{task: %Task{ref: ref}} = state) do
    Logger.warning("[Simulator.Watcher] Poll crashed: #{inspect(reason)}")
    {:noreply, %{state | task: nil}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %State{} = state) do
    state = %{state | watchers: Map.delete(state.watchers, pid)}
    {:noreply, state |> forget_unwatched() |> sync_push()}
  end

  def handle_info(_msg, %State{} = state), do: {:noreply, state}

  # Connection

  defp apply_status(
         %State{backend: backend, handle: handle, mode: mode} = state,
         %ConnectionState{status: :connected, backend: backend, client: handle}
       )
       when not is_nil(mode),
       do: state

  defp apply_status(%State{} = state, %ConnectionState{
         status: :connected,
         backend: backend,
         client: handle
       })
       when not is_nil(handle) do
    mode = if :push_values in backend.capabilities(), do: :push, else: :poll
    Logger.info("[Simulator.Watcher] Watching #{inspect(backend)} by #{mode}")

    state = stop_poll(state)

    %{state | backend: backend, handle: handle, mode: mode, pushed: nil, values: %{}}
    |> sync_push()
    |> maybe_poll()
  end

  defp apply_status(%State{} = state, %ConnectionState{}) do
    state = stop_poll(state)
    %{state | backend: nil, handle: nil, mode: nil, pushed: nil, values: %{}}
  end

  # Push

  # Hands the watched set to a push backend whenever it differs from what the
  # backend last accepted; a failure is retried on the next tick.
  defp sync_push(%State{mode: :push} = state) do
    paths = all_paths(state)

    cond do
      paths == state.pushed ->
        state

      # A fresh handle watches nothing yet.
      paths == [] and is_nil(state.pushed) ->
        %{state | pushed: []}

      true ->
        push_paths(state, paths)
    end
  end

  defp sync_push(%State{} = state), do: state

  defp push_paths(%State{} = state, paths) do
    case state.backend.watch(state.handle, paths, self()) do
      :ok ->
        %{state | pushed: paths}

      {:error, reason} ->
        Logger.warning("[Simulator.Watcher] Backend watch failed: #{inspect(reason)}")
        %{state | pushed: nil}
    end
  end

  # Poll

  defp maybe_poll(%State{mode: :poll, task: nil} = state) do
    case all_paths(state) do
      [] ->
        state

      paths ->
        task =
          Task.Supervisor.async_nolink(Trenino.TaskSupervisor, fn ->
            {:polled, Simulator.read(paths)}
          end)

        Process.send_after(self(), {:poll_timeout, task.ref}, @poll_timeout_ms)
        %{state | task: task}
    end
  end

  defp maybe_poll(%State{} = state), do: state

  defp stop_poll(%State{task: nil} = state), do: state

  defp stop_poll(%State{task: task} = state) do
    Task.shutdown(task, :brutal_kill)
    %{state | task: nil}
  end

  defp schedule_tick(%State{} = state),
    do: %{state | timer: Process.send_after(self(), :tick, @interval_ms)}

  # Watchers

  defp watched_paths(%State{watchers: watchers}, pid) do
    case Map.fetch(watchers, pid) do
      {:ok, %{paths: paths}} -> paths
      :error -> MapSet.new()
    end
  end

  defp put_paths(%State{watchers: watchers} = state, pid, paths) do
    case {Map.fetch(watchers, pid), MapSet.size(paths)} do
      {{:ok, %{ref: ref}}, 0} ->
        Process.demonitor(ref, [:flush])
        %{state | watchers: Map.delete(watchers, pid)}

      {:error, 0} ->
        state

      {{:ok, watcher}, _} ->
        %{state | watchers: Map.put(watchers, pid, %{watcher | paths: paths})}

      {:error, _} ->
        watcher = %{ref: Process.monitor(pid), paths: paths}
        %{state | watchers: Map.put(watchers, pid, watcher)}
    end
  end

  defp all_paths(%State{watchers: watchers}) do
    watchers
    |> Map.values()
    |> Enum.reduce(MapSet.new(), &MapSet.union(&1.paths, &2))
    |> Enum.sort()
  end

  defp forget_unwatched(%State{} = state),
    do: %{state | values: Map.take(state.values, all_paths(state))}

  defp deliver_all(%State{} = state, values) when map_size(values) == 0, do: state

  defp deliver_all(%State{watchers: watchers} = state, values) do
    Enum.each(watchers, fn {pid, %{paths: paths}} ->
      deliver(pid, Map.take(values, MapSet.to_list(paths)))
    end)

    state
  end

  defp deliver(_pid, values) when map_size(values) == 0, do: :ok
  defp deliver(pid, values), do: send(pid, {:simulator_values, values})
end
