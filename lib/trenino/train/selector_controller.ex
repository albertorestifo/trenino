defmodule Trenino.Train.SelectorController do
  @moduledoc """
  Runs selector actions as a potentiometer moves between positions.

  A selector splits an analog input's calibrated range into positions (see
  `Trenino.Train.SelectorBinding`). This GenServer:

  - loads the enabled selector bindings of the active train
  - normalizes each analog reading (`Trenino.Hardware.InputNormalizer`) and
    resolves it to a position (`Trenino.Train.SelectorMapper`)
  - when the position changes, runs the old position's exit action and then
    the new position's enter action

  ## Dead zones

  A reading between two positions resolves to no position and is ignored, so
  the selector keeps its last position. A reading that resolves to the
  current position is ignored too. Jitter therefore never re-fires actions.

  ## Ordering

  Each selector has at most one runner task. Exit and enter run in order
  inside it, so a long exit sequence finishes before the enter action starts.
  A new transition kills the selector's running task first, so actions from
  two transitions never interleave: the knob's latest position wins, and an
  interrupted enter action does not resume. Each exit is confirmed as it
  finishes; exits the killed task had not finished run first in the next
  transition, so a fast sweep still runs every exit (one that was cut short
  runs again from the start). Carried exits keep one per position, and the
  exit of the position the knob returns to is dropped, so the queue never
  grows past the number of positions. A reload, a train change or a
  simulator disconnect discards them.

  ## Simulator connection

  While the simulator is disconnected the selector still tracks and
  broadcasts its position, but runs no actions, so keystrokes never reach
  another application. Running tasks stop when the simulator disconnects.

  ## Sync

  The simulator should match the physical knob without the user touching it.
  A sync runs the current position's enter action only (the previous position
  is unknown), and only its `:set_value` and `:sequence` actions: keystrokes
  are usually toggles, and tapping one again would flip the state instead of
  restoring it. A sync happens:

  - for every selector when a train activates and when the simulator connects
  - for selectors without a known position when bindings reload or a device
    connects (a reload keeps the position of selectors whose configuration
    did not change)

  The reading comes from the last value `ConfigurationManager` received for
  the input. A reading in a dead zone keeps the known position, if any. A
  selector with no reading and no position waits for the first live update.
  """

  use GenServer
  require Logger

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Hardware.Input.Calibration
  alias Trenino.Hardware.InputNormalizer
  alias Trenino.Serial.Connection, as: SerialConnection
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train
  alias Trenino.Train.{Action, ActionExecutor, SelectorBinding, SelectorMapper, SelectorPosition}

  @topic "train:selector_positions"

  # Fields that define what a position does. A reload keeps the current
  # position of a selector only when these are unchanged; a new label alone
  # keeps it.
  @position_config_fields [
    :index,
    :input_min,
    :input_max,
    :enter_kind,
    :enter_endpoint,
    :enter_value,
    :enter_sequence_id,
    :enter_keystroke,
    :exit_kind,
    :exit_endpoint,
    :exit_value,
    :exit_sequence_id,
    :exit_keystroke
  ]

  defmodule State do
    @moduledoc false

    alias Trenino.Hardware.Input.Calibration
    alias Trenino.Train.SelectorPosition

    @type input_info :: %{input_id: integer(), calibration: Calibration.t() | nil}

    @type binding_info :: %{element_id: integer(), positions: [SelectorPosition.t()]}

    @typedoc "An exit action tagged with the index of the position it leaves."
    @type exit_action :: {non_neg_integer(), Trenino.Train.Action.t()}

    @typedoc "A running task and the exit actions it has not confirmed yet."
    @type runner :: %{task: Task.t(), token: reference(), exits: [exit_action()]}

    @type t :: %__MODULE__{
            active_train: Trenino.Train.Train.t() | nil,
            input_lookup: %{{port :: String.t(), pin :: integer()} => input_info()},
            binding_lookup: %{(input_id :: integer()) => binding_info()},
            subscribed_ports: MapSet.t(String.t()),
            current: %{(element_id :: integer()) => SelectorPosition.t()},
            runners: %{(element_id :: integer()) => runner()},
            sim_connected: boolean()
          }

    defstruct active_train: nil,
              input_lookup: %{},
              binding_lookup: %{},
              subscribed_ports: MapSet.new(),
              current: %{},
              runners: %{},
              sim_connected: false
  end

  @typedoc "A selector's position as reported to subscribers."
  @type position_info :: %{index: non_neg_integer(), label: String.t() | nil}

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "Get the current state of the controller."
  @spec get_state() :: State.t()
  def get_state, do: GenServer.call(__MODULE__, :get_state)

  @doc """
  Get the current position of a selector element.

  Returns `:none` when the selector has no known position, or when the
  controller is not running. Subscribe with `subscribe/0` before calling this
  so no change is missed in between.
  """
  @spec get_position(integer()) :: {:ok, position_info()} | :none
  def get_position(element_id) do
    if Process.whereis(__MODULE__),
      do: GenServer.call(__MODULE__, {:get_position, element_id}),
      else: :none
  catch
    :exit, _reason -> :none
  end

  @doc """
  Reload the active train's selector bindings.

  Selectors whose configuration is unchanged keep their position; the others
  are synced to the current reading. Call this when bindings, or sequences
  they run, change. A no-op when the controller is not running.
  """
  @spec reload_bindings() :: :ok
  def reload_bindings do
    if Process.whereis(__MODULE__), do: GenServer.cast(__MODULE__, :reload_bindings)

    :ok
  end

  @doc """
  Subscribe to selector position changes.

  Subscribers receive `{:selector_position_changed, element_id, info}`, where
  `info` is a `t:position_info/0`, or `nil` when the selector's position
  became unknown (its binding was removed or changed, or the train changed).
  """
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe, do: Phoenix.PubSub.subscribe(Trenino.PubSub, @topic)

  # Server callbacks

  @impl true
  def init(:ok) do
    Train.subscribe()
    SimulatorConnection.subscribe()
    SerialConnection.subscribe()

    {:ok, %State{}, {:continue, :load}}
  end

  @impl true
  def handle_continue(:load, %State{} = state) do
    state =
      %{state | sim_connected: sim_connected?(SimulatorConnection.get_status())}
      |> rebuild_input_lookup()

    case Train.get_active_train() do
      nil -> {:noreply, state}
      train -> {:noreply, activate(state, train)}
    end
  end

  @impl true
  def handle_call(:get_state, _from, %State{} = state), do: {:reply, state, state}

  def handle_call({:get_position, element_id}, _from, %State{} = state) do
    case Map.fetch(state.current, element_id) do
      {:ok, %SelectorPosition{} = position} -> {:reply, {:ok, position_info(position)}, state}
      :error -> {:reply, :none, state}
    end
  end

  @impl true
  def handle_cast(:reload_bindings, %State{active_train: nil} = state), do: {:noreply, state}

  def handle_cast(:reload_bindings, %State{active_train: train} = state) do
    state =
      state
      |> rebuild_input_lookup()
      |> stop_runners()
      |> load_bindings(train)
      |> sync_unpositioned()

    {:noreply, state}
  end

  @impl true
  def handle_info({:train_changed, nil}, %State{} = state) do
    Logger.info("[SelectorController] Train deactivated, clearing selectors")

    state = state |> stop_runners() |> clear_positions()
    {:noreply, %{state | active_train: nil, binding_lookup: %{}}}
  end

  def handle_info({:train_changed, train}, %State{} = state) do
    {:noreply, activate(state, train)}
  end

  def handle_info({:simulator_status_changed, %ConnectionState{} = status}, %State{} = state) do
    connected = sim_connected?(status)
    was_connected = state.sim_connected
    state = %{state | sim_connected: connected}

    # Act only on edges: the connection may broadcast the same status twice.
    cond do
      connected and not was_connected -> {:noreply, sync_all(state)}
      was_connected and not connected -> {:noreply, stop_runners(state)}
      true -> {:noreply, state}
    end
  end

  def handle_info({:devices_updated, _devices}, %State{} = state) do
    {:noreply, state |> rebuild_input_lookup() |> sync_unpositioned()}
  end

  def handle_info({:input_value_updated, port, pin, raw_value}, %State{} = state) do
    {:noreply, apply_reading(state, port, pin, raw_value)}
  end

  # A runner finished one of its exit actions, the first one still listed
  def handle_info({:selector_exit_done, element_id, token}, %State{} = state) do
    case Map.fetch(state.runners, element_id) do
      {:ok, %{token: ^token, exits: [_done | rest]} = runner} ->
        {:noreply, put_in(state.runners[element_id], %{runner | exits: rest})}

      _stale ->
        {:noreply, state}
    end
  end

  # Runner finished
  def handle_info({ref, _result}, %State{} = state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, drop_runner(state, ref)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %State{} = state) do
    Logger.warning("[SelectorController] Action runner crashed: #{inspect(reason)}")
    {:noreply, drop_runner(state, ref)}
  end

  def handle_info(_msg, %State{} = state), do: {:noreply, state}

  # Bindings and inputs

  defp activate(%State{} = state, train) do
    Logger.info("[SelectorController] Train activated: #{train.name}")

    state
    |> stop_runners()
    |> clear_positions()
    |> load_bindings(train)
    |> sync_all()
  end

  # Loads the train's enabled bindings. A current position survives only when
  # its selector is still bound and the position's configuration is unchanged;
  # it is then swapped for the fresh struct so edited sequence commands apply.
  defp load_bindings(%State{} = state, train) do
    binding_lookup =
      train.id
      |> Train.list_selector_bindings_for_train()
      |> Enum.filter(& &1.enabled)
      |> Map.new(fn %SelectorBinding{} = binding ->
        {binding.input_id, %{element_id: binding.element_id, positions: binding.positions}}
      end)

    positions_by_element =
      Map.new(binding_lookup, fn {_input_id, info} -> {info.element_id, info.positions} end)

    {kept, dropped} =
      Enum.reduce(state.current, {%{}, []}, fn {element_id, position}, {kept, dropped} ->
        case find_unchanged(Map.get(positions_by_element, element_id, []), position) do
          nil -> {kept, [element_id | dropped]}
          fresh -> {Map.put(kept, element_id, fresh), dropped}
        end
      end)

    Enum.each(dropped, &broadcast(&1, nil))
    # A kept position may have a new label
    Enum.each(kept, fn {element_id, position} ->
      broadcast(element_id, position_info(position))
    end)

    warn_uncalibrated(state, binding_lookup)

    Logger.info(
      "[SelectorController] Loaded #{map_size(binding_lookup)} selectors for train #{train.name}"
    )

    %{state | active_train: train, binding_lookup: binding_lookup, current: kept}
  end

  defp find_unchanged(positions, %SelectorPosition{} = current) do
    config = Map.take(current, @position_config_fields)
    Enum.find(positions, &(Map.take(&1, @position_config_fields) == config))
  end

  defp warn_uncalibrated(%State{} = state, binding_lookup) do
    for {_port_pin, %{input_id: input_id, calibration: nil}} <- state.input_lookup,
        Map.has_key?(binding_lookup, input_id) do
      Logger.warning(
        "[SelectorController] Input #{input_id} has no calibration; its selector will not move"
      )
    end
  end

  defp clear_positions(%State{} = state) do
    Enum.each(Map.keys(state.current), &broadcast(&1, nil))
    %{state | current: %{}}
  end

  defp rebuild_input_lookup(%State{subscribed_ports: subscribed} = state) do
    {input_lookup, ports} =
      SerialConnection.list_devices()
      |> Enum.filter(&(&1.status == :connected and &1.device_config_id != nil))
      |> Enum.reduce({%{}, MapSet.new()}, &add_device_inputs/2)

    # PubSub subscriptions outlive a device disconnect, so a port that comes
    # back must not be subscribed a second time.
    ports
    |> MapSet.difference(subscribed)
    |> Enum.each(&ConfigurationManager.subscribe_input_values/1)

    %{state | input_lookup: input_lookup, subscribed_ports: MapSet.union(subscribed, ports)}
  end

  defp add_device_inputs(device_conn, {lookup, ports}) do
    case Hardware.get_device_by_config_id(device_conn.device_config_id) do
      {:ok, device} ->
        {:ok, inputs} = Hardware.list_inputs(device.id)

        lookup =
          inputs
          |> Enum.filter(&(&1.input_type == :analog))
          |> Enum.reduce(lookup, fn input, acc ->
            Map.put(acc, {device_conn.port, input.pin}, %{
              input_id: input.id,
              calibration: loaded_calibration(input.calibration)
            })
          end)

        {lookup, MapSet.put(ports, device_conn.port)}

      {:error, :not_found} ->
        {lookup, ports}
    end
  end

  defp loaded_calibration(%Calibration{} = calibration), do: calibration
  defp loaded_calibration(_not_loaded), do: nil

  # Readings

  defp apply_reading(%State{active_train: nil} = state, _port, _pin, _raw), do: state

  defp apply_reading(%State{} = state, port, pin, raw_value) do
    with {:ok, element_id, positions} <- binding_for(state, port, pin),
         %SelectorPosition{} = position <- resolve(state, port, pin, raw_value, positions) do
      move_to(state, element_id, position)
    else
      _no_position -> state
    end
  end

  defp binding_for(%State{} = state, port, pin) do
    with {:ok, %{input_id: input_id}} <- Map.fetch(state.input_lookup, {port, pin}),
         {:ok, %{element_id: element_id, positions: positions}} <-
           Map.fetch(state.binding_lookup, input_id) do
      {:ok, element_id, positions}
    end
  end

  defp resolve(%State{} = state, port, pin, raw_value, positions) do
    %{calibration: calibration} = Map.fetch!(state.input_lookup, {port, pin})

    case InputNormalizer.normalize(raw_value, calibration) do
      {:ok, value} -> SelectorMapper.find_position(positions, value)
      {:error, _reason} -> nil
    end
  end

  defp move_to(%State{} = state, element_id, %SelectorPosition{index: index} = position) do
    case Map.fetch(state.current, element_id) do
      {:ok, %SelectorPosition{index: ^index}} ->
        state

      {:ok, %SelectorPosition{} = previous} ->
        Logger.debug("[SelectorController] Element #{element_id}: #{previous.index} -> #{index}")

        exits = [{previous.index, Action.from_position(previous, :exit)}]
        transition(state, element_id, position, exits, [Action.from_position(position, :enter)])

      :error ->
        Logger.debug("[SelectorController] Element #{element_id}: entered #{index}")
        transition(state, element_id, position, [], [Action.from_position(position, :enter)])
    end
  end

  # Records and broadcasts the new position. Actions run only while the
  # simulator is connected, after any exits an interrupted runner left.
  defp transition(%State{} = state, element_id, %SelectorPosition{} = position, exits, enters) do
    {leftover_exits, state} = stop_runner(state, element_id)

    exits =
      (leftover_exits ++ exits)
      |> Enum.reject(fn {index, action} -> is_nil(action) or index == position.index end)
      |> Enum.uniq_by(fn {index, _action} -> index end)

    enters = Enum.reject(enters, &is_nil/1)

    state =
      if state.sim_connected,
        do: start_runner(state, element_id, exits, enters),
        else: state

    broadcast(element_id, position_info(position))
    %{state | current: Map.put(state.current, element_id, position)}
  end

  # Sync

  defp sync_all(%State{} = state), do: sync(state, fn _element_id -> true end)

  defp sync_unpositioned(%State{} = state),
    do: sync(state, &(not Map.has_key?(state.current, &1)))

  defp sync(%State{active_train: nil} = state, _select?), do: state

  defp sync(%State{} = state, select?) do
    readings = current_readings(state)

    Enum.reduce(state.input_lookup, state, fn {{port, pin}, %{input_id: input_id}}, acc ->
      with {:ok, %{element_id: element_id, positions: positions}} <-
             Map.fetch(acc.binding_lookup, input_id),
           true <- select?.(element_id),
           %SelectorPosition{} = position <-
             sync_target(acc, element_id, {port, pin}, positions, readings) do
        sync_element(acc, element_id, position)
      else
        _skip -> acc
      end
    end)
  end

  # The position the reading is in, or the known position when the knob
  # rests in a dead zone or has no cached reading.
  defp sync_target(%State{} = state, element_id, {port, pin}, positions, readings) do
    reading_position =
      case Map.fetch(readings, {port, pin}) do
        {:ok, raw_value} -> resolve(state, port, pin, raw_value, positions)
        :error -> nil
      end

    reading_position || Map.get(state.current, element_id)
  end

  defp sync_element(%State{} = state, element_id, %SelectorPosition{} = position) do
    enter =
      case Action.from_position(position, :enter) do
        %Action{kind: :keystroke} -> nil
        action -> action
      end

    Logger.debug("[SelectorController] Element #{element_id}: synced to #{position.index}")
    transition(state, element_id, position, [], [enter])
  end

  defp current_readings(%State{} = state) do
    bound_ports =
      for {{port, _pin}, %{input_id: input_id}} <- state.input_lookup,
          Map.has_key?(state.binding_lookup, input_id),
          uniq: true,
          do: port

    for port <- bound_ports,
        {pin, value} <- cached_input_values(port),
        into: %{},
        do: {{port, pin}, value}
  end

  defp cached_input_values(port) do
    ConfigurationManager.get_input_values(port)
  catch
    :exit, reason ->
      Logger.warning("[SelectorController] No cached readings for #{port}: #{inspect(reason)}")
      %{}
  end

  # Runners

  defp start_runner(%State{} = state, _element_id, [], []), do: state

  defp start_runner(%State{} = state, element_id, exits, enters) do
    owner = self()
    token = make_ref()

    task =
      Task.Supervisor.async_nolink(Trenino.TaskSupervisor, fn ->
        with :ok <- run_exits(exits, element_id, owner, token) do
          ActionExecutor.run_all(enters, owner: owner)
        end
      end)

    runner = %{task: task, token: token, exits: exits}
    %{state | runners: Map.put(state.runners, element_id, runner)}
  end

  # Runs exits one at a time, confirming each to the owner so a killed runner
  # hands over only the ones that did not finish.
  defp run_exits(exits, element_id, owner, token) do
    Enum.reduce_while(exits, :ok, fn {_index, action}, acc ->
      case ActionExecutor.run(action, owner: owner) do
        {:error, :owner_down} = error ->
          {:halt, error}

        # A failed exit is logged by the executor; the enter actions still run
        _result ->
          send(owner, {:selector_exit_done, element_id, token})
          {:cont, acc}
      end
    end)
  end

  # Kills the element's runner and returns the exit actions it had not
  # confirmed, so the next transition can run them.
  defp stop_runner(%State{} = state, element_id) do
    case Map.pop(state.runners, element_id) do
      {nil, _runners} ->
        {[], state}

      {%{task: task, exits: exits}, runners} ->
        Task.shutdown(task, :brutal_kill)
        {exits, %{state | runners: runners}}
    end
  end

  defp stop_runners(%State{} = state) do
    Enum.each(state.runners, fn {_element_id, %{task: task}} ->
      Task.shutdown(task, :brutal_kill)
    end)

    %{state | runners: %{}}
  end

  defp drop_runner(%State{} = state, ref) do
    runners = Map.reject(state.runners, fn {_element_id, %{task: %Task{ref: r}}} -> r == ref end)
    %{state | runners: runners}
  end

  defp position_info(%SelectorPosition{index: index, label: label}),
    do: %{index: index, label: label}

  defp broadcast(element_id, info) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      @topic,
      {:selector_position_changed, element_id, info}
    )
  end

  defp sim_connected?(%ConnectionState{status: :connected, client: client}) when client != nil,
    do: true

  defp sim_connected?(_status), do: false
end
