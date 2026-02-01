defmodule Trenino.Train.ScriptRunner do
  @moduledoc """
  Executes Lua scripts in response to simulator API value changes.

  This GenServer:
  - Subscribes to train detection events to know which train is active
  - Creates API subscriptions for each script's trigger endpoints
  - Polls subscription values every 200ms
  - Detects value changes and calls `on_change(event)` in the script's Lua VM
  - Handles side effects: API calls, output commands, scheduling

  Uses subscription ID range 2000-2999 to avoid conflicts with
  OutputController (1000-1999) and other subscription users.
  """

  use GenServer
  require Logger

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Simulator.Client, as: SimulatorClient
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train
  alias Trenino.Train.Script
  alias Trenino.Train.ScriptEngine

  @poll_interval_ms 200
  @subscription_id_base 2000
  @execution_timeout_ms 200

  defmodule ScriptState do
    @moduledoc false

    @type t :: %__MODULE__{
            script: Script.t(),
            lua: Lua.t() | nil,
            last_values: %{String.t() => term()},
            scheduled_timer: reference() | nil,
            compile_error: String.t() | nil,
            log: [String.t()]
          }

    defstruct script: nil,
              lua: nil,
              last_values: %{},
              scheduled_timer: nil,
              compile_error: nil,
              log: []
  end

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{
            active_train: Train.Train.t() | nil,
            scripts: %{integer() => ScriptState.t()},
            subscriptions: %{String.t() => integer()},
            endpoint_to_scripts: %{String.t() => [integer()]},
            poll_timer: reference() | nil
          }

    defstruct active_train: nil,
              scripts: %{},
              subscriptions: %{},
              endpoint_to_scripts: %{},
              poll_timer: nil
  end

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Reload scripts for the active train.

  Call this when scripts are created, updated, or deleted.
  """
  @spec reload_scripts() :: :ok
  def reload_scripts do
    GenServer.cast(__MODULE__, :reload_scripts)
  end

  @doc """
  Manually trigger a script with source = "manual".
  """
  @spec run_script(integer()) :: :ok
  def run_script(script_id) do
    GenServer.cast(__MODULE__, {:run_script, script_id})
  end

  @doc """
  Get the current log entries for a script.
  """
  @spec get_script_log(integer()) :: [String.t()]
  def get_script_log(script_id) do
    GenServer.call(__MODULE__, {:get_script_log, script_id})
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    Train.subscribe()

    state = %State{}

    state =
      case Train.get_active_train() do
        nil -> state
        train -> load_scripts_for_train(state, train)
      end

    {:ok, state}
  end

  @impl true
  def handle_cast(:reload_scripts, %State{active_train: nil} = state) do
    {:noreply, state}
  end

  def handle_cast(:reload_scripts, %State{active_train: train} = state) do
    state = cleanup(state)
    {:noreply, load_scripts_for_train(state, train)}
  end

  def handle_cast({:run_script, script_id}, %State{} = state) do
    case Map.get(state.scripts, script_id) do
      nil ->
        {:noreply, state}

      %ScriptState{} = script_state ->
        event = %{"source" => "manual", "value" => nil, "data" => nil}
        state = execute_script(state, script_id, script_state, event)
        {:noreply, state}
    end
  end

  @impl true
  def handle_call({:get_script_log, script_id}, _from, %State{} = state) do
    log =
      case Map.get(state.scripts, script_id) do
        nil -> []
        %ScriptState{log: log} -> log
      end

    {:reply, log, state}
  end

  @impl true
  def handle_info({:train_changed, nil}, %State{} = state) do
    Logger.info("[ScriptRunner] Train deactivated, cleaning up")
    state = cleanup(state)
    {:noreply, %{state | active_train: nil}}
  end

  def handle_info({:train_changed, train}, %State{} = state) do
    Logger.info("[ScriptRunner] Train activated: #{train.name}")
    state = cleanup(state)
    {:noreply, load_scripts_for_train(state, train)}
  end

  def handle_info({:train_detected, _}, %State{} = state), do: {:noreply, state}
  def handle_info({:detection_error, _}, %State{} = state), do: {:noreply, state}

  def handle_info(:poll_subscriptions, %State{} = state) do
    state = poll_and_execute(state)
    {:noreply, schedule_poll(state)}
  end

  def handle_info({:scheduled_run, script_id}, %State{} = state) do
    case Map.get(state.scripts, script_id) do
      nil ->
        {:noreply, state}

      %ScriptState{} = script_state ->
        script_state = %{script_state | scheduled_timer: nil}
        state = put_in(state.scripts[script_id], script_state)
        event = %{"source" => "scheduled", "value" => nil, "data" => nil}
        state = execute_script(state, script_id, script_state, event)
        {:noreply, state}
    end
  end

  def handle_info(_msg, %State{} = state), do: {:noreply, state}

  # Private Functions

  defp load_scripts_for_train(%State{} = state, train) do
    scripts = Train.list_enabled_scripts(train.id)

    if Enum.empty?(scripts) do
      Logger.info("[ScriptRunner] No scripts for train #{train.name}")
      %{state | active_train: train, scripts: %{}, subscriptions: %{}, endpoint_to_scripts: %{}}
    else
      script_states = compile_scripts(scripts)
      {subscriptions, endpoint_to_scripts} = setup_subscriptions(scripts)

      state = %{
        state
        | active_train: train,
          scripts: script_states,
          subscriptions: subscriptions,
          endpoint_to_scripts: endpoint_to_scripts
      }

      Logger.info("[ScriptRunner] Loaded #{map_size(script_states)} scripts for train #{train.name}")
      schedule_poll(state)
    end
  end

  defp compile_scripts(scripts) do
    Map.new(scripts, fn %Script{} = script ->
      script_state =
        case ScriptEngine.new(script.code) do
          {:ok, lua} ->
            %ScriptState{script: script, lua: lua}

          {:error, reason} ->
            Logger.warning("[ScriptRunner] Compile error in script '#{script.name}': #{reason}")
            %ScriptState{script: script, compile_error: reason}
        end

      {script.id, script_state}
    end)
  end

  defp setup_subscriptions(scripts) do
    # Collect all unique trigger endpoints and map them to script IDs
    endpoint_to_scripts =
      scripts
      |> Enum.flat_map(fn %Script{} = script ->
        Enum.map(script.triggers, &{&1, script.id})
      end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))

    # Create simulator subscriptions for each unique endpoint
    subscriptions =
      case get_simulator_client() do
        {:ok, client} ->
          subscribe_to_endpoints(client, Map.keys(endpoint_to_scripts))

        :error ->
          Logger.warning("[ScriptRunner] Simulator not connected, cannot set up subscriptions")
          %{}
      end

    {subscriptions, endpoint_to_scripts}
  end

  defp subscribe_to_endpoints(client, endpoints) do
    endpoints
    |> Enum.with_index()
    |> Map.new(fn {endpoint, index} ->
      sub_id = @subscription_id_base + index
      subscribe_single(client, endpoint, sub_id)
      {endpoint, sub_id}
    end)
  end

  defp subscribe_single(client, endpoint, sub_id) do
    case SimulatorClient.subscribe(client, endpoint, sub_id) do
      {:ok, _} ->
        Logger.debug("[ScriptRunner] Subscribed to #{endpoint} (sub_id: #{sub_id})")

      {:error, reason} ->
        Logger.warning(
          "[ScriptRunner] Failed to subscribe to #{endpoint}: #{inspect(reason)}"
        )
    end
  end

  defp poll_and_execute(%State{subscriptions: subs} = state) when map_size(subs) == 0, do: state

  defp poll_and_execute(%State{} = state) do
    case get_simulator_client() do
      {:ok, client} ->
        Enum.reduce(state.subscriptions, state, fn {endpoint, sub_id}, acc ->
          poll_endpoint(client, endpoint, sub_id, acc)
        end)

      :error ->
        state
    end
  end

  defp poll_endpoint(client, endpoint, sub_id, %State{} = state) do
    case SimulatorClient.get_subscription(client, sub_id) do
      {:ok, %{"Entries" => entries}} when is_list(entries) and entries != [] ->
        value = extract_subscription_value(entries)
        check_and_fire(state, endpoint, value, entries)

      _ ->
        state
    end
  end

  defp extract_subscription_value(entries) do
    case entries do
      [%{"Values" => values} | _] when is_map(values) ->
        case Map.values(values) do
          [value | _] -> value
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp check_and_fire(%State{} = state, endpoint, value, entries) do
    script_ids = Map.get(state.endpoint_to_scripts, endpoint, [])

    Enum.reduce(script_ids, state, fn script_id, acc ->
      maybe_fire_script(acc, script_id, endpoint, value, entries)
    end)
  end

  defp maybe_fire_script(%State{} = state, script_id, endpoint, value, entries) do
    case Map.get(state.scripts, script_id) do
      nil ->
        state

      %ScriptState{lua: nil} ->
        state

      %ScriptState{last_values: last_values} = script_state ->
        last = Map.get(last_values, endpoint)

        if last != value do
          fire_script(state, script_id, script_state, endpoint, value, entries)
        else
          state
        end
    end
  end

  defp fire_script(%State{} = state, script_id, %ScriptState{} = script_state, endpoint, value, entries) do
    script_state = %{script_state | last_values: Map.put(script_state.last_values, endpoint, value)}
    state = put_in(state.scripts[script_id], script_state)

    event = %{
      "source" => endpoint,
      "value" => value,
      "data" => build_data(entries)
    }

    execute_script(state, script_id, script_state, event)
  end

  defp build_data(entries) do
    case entries do
      [%{"Values" => values} | _] -> values
      _ -> nil
    end
  end

  defp execute_script(%State{} = state, _script_id, %ScriptState{lua: nil}, _event) do
    state
  end

  defp execute_script(%State{} = state, script_id, %ScriptState{lua: lua} = script_state, event) do
    task = Task.async(fn -> ScriptEngine.execute(lua, event) end)

    case Task.yield(task, @execution_timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, new_lua, effects}} ->
        script_state = %{script_state | lua: new_lua}
        script_state = process_effects(state, script_id, script_state, effects)
        put_in(state.scripts[script_id], script_state)

      {:ok, {:error, reason}} ->
        log_entry = "[error] #{reason}"
        Logger.warning("[ScriptRunner] Script '#{script_state.script.name}' error: #{reason}")
        script_state = append_log(script_state, log_entry)
        put_in(state.scripts[script_id], script_state)

      nil ->
        log_entry = "[error] Script execution timed out (#{@execution_timeout_ms}ms)"
        Logger.warning("[ScriptRunner] Script '#{script_state.script.name}' timed out")
        script_state = append_log(script_state, log_entry)
        put_in(state.scripts[script_id], script_state)
    end
  end

  defp process_effects(%State{} = state, script_id, %ScriptState{} = script_state, effects) do
    Enum.reduce(effects, script_state, fn effect, acc ->
      process_effect(state, script_id, acc, effect)
    end)
  end

  defp process_effect(_state, _script_id, %ScriptState{} = script_state, {:log, message}) do
    append_log(script_state, message)
  end

  defp process_effect(_state, script_id, %ScriptState{} = script_state, {:schedule, ms}) do
    # Cancel existing timer if any
    if script_state.scheduled_timer do
      Process.cancel_timer(script_state.scheduled_timer)
    end

    timer = Process.send_after(self(), {:scheduled_run, script_id}, ms)
    %{script_state | scheduled_timer: timer}
  end

  defp process_effect(
         _state,
         _script_id,
         %ScriptState{} = script_state,
         {:output_set, output_id, on?}
       ) do
    apply_output_set(output_id, on?)
    script_state
  end

  defp process_effect(_state, _script_id, %ScriptState{} = script_state, {:api_get, _path}) do
    # API get results are handled via side effects; for now we just log the intent
    script_state
  end

  defp process_effect(_state, _script_id, %ScriptState{} = script_state, {:api_set, path, value}) do
    case get_simulator_client() do
      {:ok, client} ->
        case SimulatorClient.set(client, path, value) do
          {:ok, _} -> :ok
          {:error, reason} -> Logger.warning("[ScriptRunner] api.set failed: #{inspect(reason)}")
        end

      :error ->
        Logger.warning("[ScriptRunner] Simulator not connected for api.set")
    end

    script_state
  end

  defp apply_output_set(output_id, on?) do
    case Train.get_output_by_id(output_id) do
      {:ok, output} ->
        set_hardware_output(output, on?)

      {:error, _} ->
        Logger.warning("[ScriptRunner] Unknown output ID: #{output_id}")
    end
  end

  defp set_hardware_output(output, on?) do
    port = ConfigurationManager.config_id_to_port(output.device.config_id)

    if port do
      value = if on?, do: :high, else: :low
      Hardware.set_output(port, output.pin, value)
    end
  end

  defp append_log(%ScriptState{} = script_state, message) do
    # Keep last 100 log entries
    log = Enum.take([message | script_state.log], 100)
    %{script_state | log: log}
  end

  defp schedule_poll(%State{poll_timer: old_timer} = state) do
    if old_timer, do: Process.cancel_timer(old_timer)
    timer = Process.send_after(self(), :poll_subscriptions, @poll_interval_ms)
    %{state | poll_timer: timer}
  end

  defp cleanup(%State{} = state) do
    # Cancel poll timer
    if state.poll_timer, do: Process.cancel_timer(state.poll_timer)

    # Cancel all scheduled timers
    Enum.each(state.scripts, fn {_id, %ScriptState{scheduled_timer: timer}} ->
      if timer, do: Process.cancel_timer(timer)
    end)

    # Unsubscribe from simulator
    case get_simulator_client() do
      {:ok, client} ->
        Enum.each(state.subscriptions, fn {_endpoint, sub_id} ->
          SimulatorClient.unsubscribe(client, sub_id)
        end)

      :error ->
        :ok
    end

    %{state | scripts: %{}, subscriptions: %{}, endpoint_to_scripts: %{}, poll_timer: nil}
  end

  defp get_simulator_client do
    case SimulatorConnection.get_status() do
      %ConnectionState{status: :connected, client: client} when client != nil ->
        {:ok, client}

      _ ->
        :error
    end
  end
end
