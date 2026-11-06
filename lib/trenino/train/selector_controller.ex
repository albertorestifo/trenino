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
  two transitions never interleave.

  ## Sync

  The simulator should match the physical knob without the user touching it.
  The current position's enter action (enter only, since the previous
  position is unknown) runs:

  - when a train activates or its bindings reload
  - when the simulator connects
  - when a device connects and a selector has no position yet

  The reading comes from the last value `ConfigurationManager` received for
  the input. A selector with no reading yet waits for the first live update.
  Sync runs only while the simulator is connected, so keystrokes never go to
  another application.
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

  defmodule State do
    @moduledoc false

    alias Trenino.Hardware.Input.Calibration
    alias Trenino.Train.SelectorPosition

    @type input_info :: %{input_id: integer(), calibration: Calibration.t() | nil}

    @type binding_info :: %{element_id: integer(), positions: [SelectorPosition.t()]}

    @type t :: %__MODULE__{
            active_train: Trenino.Train.Train.t() | nil,
            input_lookup: %{{port :: String.t(), pin :: integer()} => input_info()},
            binding_lookup: %{(input_id :: integer()) => binding_info()},
            subscribed_ports: MapSet.t(String.t()),
            current: %{(element_id :: integer()) => non_neg_integer()},
            runners: %{(element_id :: integer()) => Task.t()},
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

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc "Get the current state of the controller."
  @spec get_state() :: State.t()
  def get_state, do: GenServer.call(__MODULE__, :get_state)

  @doc """
  Reload bindings for the active train and re-sync every selector.

  Call this when selector bindings are modified.
  """
  @spec reload_bindings() :: :ok
  def reload_bindings do
    if Process.whereis(__MODULE__), do: GenServer.cast(__MODULE__, :reload_bindings)

    :ok
  end

  @doc """
  Subscribe to selector position changes.

  Subscribers receive
  `{:selector_position_changed, element_id, %{index: integer(), label: String.t() | nil}}`.
  """
  @spec subscribe() :: :ok | {:error, term()}
  def subscribe, do: Phoenix.PubSub.subscribe(Trenino.PubSub, @topic)

  # Server callbacks

  @impl true
  def init(:ok) do
    Train.subscribe()
    SimulatorConnection.subscribe()
    SerialConnection.subscribe()

    state =
      %State{sim_connected: sim_connected?(SimulatorConnection.get_status())}
      |> rebuild_input_lookup()

    state =
      case Train.get_active_train() do
        nil -> state
        train -> state |> load_bindings(train) |> sync_all()
      end

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, %State{} = state), do: {:reply, state, state}

  @impl true
  def handle_cast(:reload_bindings, %State{active_train: nil} = state), do: {:noreply, state}

  def handle_cast(:reload_bindings, %State{active_train: train} = state) do
    {:noreply, state |> load_bindings(train) |> sync_all()}
  end

  @impl true
  def handle_info({:train_changed, nil}, %State{} = state) do
    {:noreply, %{stop_runners(state) | active_train: nil, binding_lookup: %{}, current: %{}}}
  end

  def handle_info({:train_changed, train}, %State{} = state) do
    {:noreply, state |> load_bindings(train) |> sync_all()}
  end

  def handle_info({:simulator_status_changed, %ConnectionState{} = status}, %State{} = state) do
    connected = sim_connected?(status)
    was_connected = state.sim_connected
    state = %{state | sim_connected: connected}

    # Only the disconnected -> connected edge re-syncs; the connection may
    # broadcast :connected more than once.
    if connected and not was_connected,
      do: {:noreply, sync_all(state)},
      else: {:noreply, state}
  end

  def handle_info({:devices_updated, _devices}, %State{} = state) do
    {:noreply, state |> rebuild_input_lookup() |> sync_unpositioned()}
  end

  def handle_info({:input_value_updated, port, pin, raw_value}, %State{} = state) do
    {:noreply, apply_reading(state, port, pin, raw_value)}
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

  defp load_bindings(%State{} = state, train) do
    state = stop_runners(state)

    binding_lookup =
      train.id
      |> Train.list_selector_bindings_for_train()
      |> Enum.filter(& &1.enabled)
      |> Map.new(fn %SelectorBinding{} = binding ->
        {binding.input_id, %{element_id: binding.element_id, positions: binding.positions}}
      end)

    Logger.info(
      "[SelectorController] Loaded #{map_size(binding_lookup)} selectors for train #{train.name}"
    )

    %{state | active_train: train, binding_lookup: binding_lookup, current: %{}}
  end

  defp rebuild_input_lookup(%State{subscribed_ports: old_ports} = state) do
    {input_lookup, ports} =
      SerialConnection.list_devices()
      |> Enum.filter(&(&1.status == :connected and &1.device_config_id != nil))
      |> Enum.reduce({%{}, MapSet.new()}, &add_device_inputs/2)

    ports
    |> MapSet.difference(old_ports)
    |> Enum.each(&ConfigurationManager.subscribe_input_values/1)

    %{state | input_lookup: input_lookup, subscribed_ports: ports}
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
    case resolve(state, port, pin, raw_value) do
      {:ok, element_id, position} -> move_to(state, element_id, position)
      :skip -> state
    end
  end

  defp resolve(%State{} = state, port, pin, raw_value) do
    with {:ok, %{input_id: input_id, calibration: calibration}} <-
           Map.fetch(state.input_lookup, {port, pin}),
         {:ok, %{element_id: element_id, positions: positions}} <-
           Map.fetch(state.binding_lookup, input_id),
         {:ok, value} <- InputNormalizer.normalize(raw_value, calibration),
         %SelectorPosition{} = position <- SelectorMapper.find_position(positions, value) do
      {:ok, element_id, position}
    else
      _no_position -> :skip
    end
  end

  defp move_to(%State{} = state, element_id, %SelectorPosition{index: index} = position) do
    case Map.fetch(state.current, element_id) do
      {:ok, ^index} ->
        state

      {:ok, previous_index} ->
        previous = find_by_index(state, element_id, previous_index)
        exit_action = previous && Action.from_position(previous, :exit)
        enter_action = Action.from_position(position, :enter)
        transition(state, element_id, position, [exit_action, enter_action])

      :error ->
        transition(state, element_id, position, [Action.from_position(position, :enter)])
    end
  end

  defp find_by_index(%State{} = state, element_id, index) do
    state.binding_lookup
    |> Map.values()
    |> Enum.find_value(fn
      %{element_id: ^element_id, positions: positions} ->
        Enum.find(positions, &(&1.index == index))

      _other ->
        nil
    end)
  end

  defp transition(%State{} = state, element_id, %SelectorPosition{} = position, actions) do
    state =
      state
      |> stop_runner(element_id)
      |> start_runner(element_id, Enum.reject(actions, &is_nil/1))

    broadcast(element_id, position)
    %{state | current: Map.put(state.current, element_id, position.index)}
  end

  # Sync

  defp sync_all(%State{} = state), do: sync(state, fn _element_id -> true end)

  defp sync_unpositioned(%State{} = state),
    do: sync(state, &(not Map.has_key?(state.current, &1)))

  defp sync(%State{active_train: nil} = state, _select?), do: state
  defp sync(%State{sim_connected: false} = state, _select?), do: state

  defp sync(%State{} = state, select?) do
    readings = current_readings(state)

    Enum.reduce(state.input_lookup, state, fn {{port, pin}, %{input_id: input_id}}, acc ->
      with {:ok, %{element_id: element_id}} <- Map.fetch(acc.binding_lookup, input_id),
           true <- select?.(element_id),
           {:ok, raw_value} <- Map.fetch(readings, {port, pin}),
           {:ok, ^element_id, position} <- resolve(acc, port, pin, raw_value) do
        current = Map.delete(acc.current, element_id)

        transition(%{acc | current: current}, element_id, position, [
          Action.from_position(position, :enter)
        ])
      else
        _ -> acc
      end
    end)
  end

  defp current_readings(%State{} = state) do
    bound_ports =
      for {{port, _pin}, %{input_id: input_id}} <- state.input_lookup,
          Map.has_key?(state.binding_lookup, input_id),
          uniq: true,
          do: port

    Map.new(bound_ports, fn port -> {port, ConfigurationManager.get_input_values(port)} end)
    |> Enum.flat_map(fn {port, values} ->
      Enum.map(values, fn {pin, v} -> {{port, pin}, v} end)
    end)
    |> Map.new()
  end

  # Runners

  defp start_runner(%State{} = state, _element_id, []), do: state

  defp start_runner(%State{} = state, element_id, actions) do
    owner = self()

    task =
      Task.Supervisor.async_nolink(Trenino.TaskSupervisor, fn ->
        ActionExecutor.run_all(actions, owner: owner)
      end)

    %{state | runners: Map.put(state.runners, element_id, task)}
  end

  defp stop_runner(%State{} = state, element_id) do
    case Map.pop(state.runners, element_id) do
      {nil, _runners} ->
        state

      {%Task{} = task, runners} ->
        Task.shutdown(task, :brutal_kill)
        %{state | runners: runners}
    end
  end

  defp stop_runners(%State{} = state) do
    Enum.each(state.runners, fn {_element_id, task} -> Task.shutdown(task, :brutal_kill) end)
    %{state | runners: %{}}
  end

  defp drop_runner(%State{} = state, ref) do
    runners = Map.reject(state.runners, fn {_element_id, %Task{ref: r}} -> r == ref end)
    %{state | runners: runners}
  end

  defp broadcast(element_id, %SelectorPosition{index: index, label: label}) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      @topic,
      {:selector_position_changed, element_id, %{index: index, label: label}}
    )
  end

  defp sim_connected?(%ConnectionState{status: :connected, client: client}) when client != nil,
    do: true

  defp sim_connected?(_status), do: false
end
