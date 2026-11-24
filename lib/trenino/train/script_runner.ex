defmodule Trenino.Train.ScriptRunner do
  @moduledoc """
  Executes Lua scripts in response to simulator API value changes.

  This GenServer:
  - Subscribes to train detection events to know which train is active
  - Watches each script's trigger endpoints through `Trenino.Simulator.Watcher`
  - Detects value changes and calls `on_change(event)` in the script's Lua VM
  - Handles side effects: API calls, output commands, scheduling
  """

  use GenServer
  require Logger

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Hardware.HT16K33
  alias Trenino.Hardware.I2cModule
  alias Trenino.Hardware.Output
  alias Trenino.Simulator
  alias Trenino.Simulator.Watcher
  alias Trenino.Train
  alias Trenino.Train.Script
  alias Trenino.Train.ScriptEngine

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
            endpoint_to_scripts: %{String.t() => [integer()]},
            outputs: %{integer() => Output.t()},
            i2c_modules: [I2cModule.t()] | nil
          }

    # `outputs` and `i2c_modules` cache the hardware that script effects drive, filled on
    # first use and dropped when a configuration is applied or the scripts reload.
    defstruct active_train: nil,
              scripts: %{},
              endpoint_to_scripts: %{},
              outputs: %{},
              i2c_modules: nil
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
    ConfigurationManager.subscribe_configuration()
    Watcher.subscribe()

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

  def handle_info({:configuration_applied, _port, _device, _config_id}, %State{} = state),
    do: {:noreply, forget_hardware(state)}

  def handle_info(:simulator_watcher_started, %State{} = state) do
    Watcher.watch(Map.keys(state.endpoint_to_scripts))
    {:noreply, state}
  end

  def handle_info({:simulator_values, values}, %State{} = state) when is_map(values) do
    state =
      Enum.reduce(values, state, fn {endpoint, raw}, acc ->
        {value, data} = event_value(raw)
        check_and_fire(acc, endpoint, value, data)
      end)

    {:noreply, state}
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
      %{state | active_train: train, scripts: %{}, endpoint_to_scripts: %{}}
    else
      script_states = compile_scripts(scripts)
      endpoint_to_scripts = endpoint_to_scripts(scripts)
      Watcher.watch(Map.keys(endpoint_to_scripts))

      Logger.info(
        "[ScriptRunner] Loaded #{map_size(script_states)} scripts for train #{train.name}"
      )

      %{
        state
        | active_train: train,
          scripts: script_states,
          endpoint_to_scripts: endpoint_to_scripts
      }
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

  # Every unique trigger endpoint, mapped to the scripts it triggers.
  defp endpoint_to_scripts(scripts) do
    scripts
    |> Enum.flat_map(fn %Script{} = script ->
      Enum.map(script.triggers, &{&1, script.id})
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  # An endpoint returning several values (a map) triggers with the first as `value`
  # and all of them as `data`.
  defp event_value(values) when is_map(values) do
    case Map.values(values) do
      [value | _] -> {value, values}
      [] -> {nil, values}
    end
  end

  defp event_value(value), do: {value, nil}

  defp check_and_fire(%State{} = state, endpoint, value, data) do
    script_ids = Map.get(state.endpoint_to_scripts, endpoint, [])

    Enum.reduce(script_ids, state, fn script_id, acc ->
      maybe_fire_script(acc, script_id, endpoint, value, data)
    end)
  end

  defp maybe_fire_script(%State{} = state, script_id, endpoint, value, data) do
    case Map.get(state.scripts, script_id) do
      nil ->
        state

      %ScriptState{lua: nil} ->
        state

      %ScriptState{last_values: last_values} = script_state ->
        last = Map.get(last_values, endpoint)

        if last != value do
          fire_script(state, script_id, script_state, endpoint, value, data)
        else
          state
        end
    end
  end

  defp fire_script(
         %State{} = state,
         script_id,
         %ScriptState{} = script_state,
         endpoint,
         value,
         data
       ) do
    script_state = %{
      script_state
      | last_values: Map.put(script_state.last_values, endpoint, value)
    }

    state = put_in(state.scripts[script_id], script_state)

    event = %{
      "source" => endpoint,
      "value" => value,
      "data" => data
    }

    execute_script(state, script_id, script_state, event)
  end

  defp execute_script(%State{} = state, _script_id, %ScriptState{lua: nil}, _event) do
    state
  end

  defp execute_script(%State{} = state, script_id, %ScriptState{lua: lua} = script_state, event) do
    task = Task.async(fn -> ScriptEngine.execute(lua, event) end)

    case Task.yield(task, @execution_timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, new_lua, effects}} ->
        script_state = %{script_state | lua: new_lua}
        {state, script_state} = process_effects(state, script_id, script_state, effects)
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
    Enum.reduce(effects, {state, script_state}, fn
      {:output_set, output_id, on?}, {acc_state, acc_script} ->
        {apply_output_set(acc_state, output_id, on?), acc_script}

      {:display_set, addr, text}, {acc_state, acc_script} ->
        {apply_display_set(acc_state, addr, text), acc_script}

      effect, {acc_state, acc_script} ->
        {acc_state, process_effect(acc_state, script_id, acc_script, effect)}
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

  defp process_effect(_state, _script_id, %ScriptState{} = script_state, {:api_get, _path}) do
    # API get results are handled via side effects; for now we just log the intent
    script_state
  end

  defp process_effect(_state, _script_id, %ScriptState{} = script_state, {:api_set, path, value}) do
    case Simulator.set(path, value) do
      :ok -> :ok
      {:error, reason} -> Logger.warning("[ScriptRunner] api.set failed: #{inspect(reason)}")
    end

    script_state
  end

  defp apply_output_set(%State{} = state, output_id, on?) do
    case cached_output(state, output_id) do
      {:ok, output, state} ->
        set_hardware_output(output, on?)
        state

      :error ->
        Logger.warning("[ScriptRunner] Unknown output ID: #{output_id}")
        state
    end
  end

  # Unknown ids are not cached, so an output created later is found on the next call.
  defp cached_output(%State{outputs: outputs} = state, output_id) do
    case Map.fetch(outputs, output_id) do
      {:ok, output} ->
        {:ok, output, state}

      :error ->
        case Train.get_output_by_id(output_id) do
          {:ok, output} -> {:ok, output, %{state | outputs: Map.put(outputs, output_id, output)}}
          {:error, _} -> :error
        end
    end
  end

  defp set_hardware_output(output, on?) do
    port = ConfigurationManager.config_id_to_port(output.device.config_id)

    if port do
      value = if on?, do: :high, else: :low
      Hardware.set_output(port, output.pin, value)
    end
  end

  defp apply_display_set(%State{} = state, i2c_address, text) do
    state = %{state | i2c_modules: state.i2c_modules || Hardware.list_all_i2c_modules()}
    write_display(state.i2c_modules, i2c_address, text)
    state
  end

  defp write_display(modules, i2c_address, text) do
    case Enum.find(modules, &(&1.i2c_address == i2c_address)) do
      nil ->
        Logger.warning("[ScriptRunner] No i2c module found at address #{i2c_address}")

      mod ->
        port = ConfigurationManager.config_id_to_port(mod.device.config_id)

        if port do
          chip_mod = chip_module(mod.module_chip)
          bytes = chip_mod.encode_string(text, mod.params)
          Hardware.write_segments(port, i2c_address, bytes)
        end
    end
  end

  defp chip_module(:ht16k33), do: HT16K33

  defp append_log(%ScriptState{} = script_state, message) do
    # Keep last 100 log entries
    log = Enum.take([message | script_state.log], 100)
    %{script_state | log: log}
  end

  defp cleanup(%State{} = state) do
    Enum.each(state.scripts, fn {_id, %ScriptState{scheduled_timer: timer}} ->
      if timer, do: Process.cancel_timer(timer)
    end)

    Watcher.unwatch_all()

    %{state | scripts: %{}, endpoint_to_scripts: %{}}
    |> forget_hardware()
  end

  defp forget_hardware(%State{} = state), do: %{state | outputs: %{}, i2c_modules: nil}
end
