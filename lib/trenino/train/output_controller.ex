defmodule Trenino.Train.OutputController do
  @moduledoc """
  Controls hardware outputs based on simulator values.

  This GenServer:
  - Subscribes to train detection events to know which train is active
  - Watches the endpoints of the active train's enabled output bindings
    through `Trenino.Simulator.Watcher`
  - Evaluates conditions on every value received and sets hardware output
    states when they change

  Outputs are switched off when the train changes or the simulator
  disconnects, since they no longer reflect anything.
  """

  use GenServer
  require Logger

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Simulator.Watcher
  alias Trenino.Train
  alias Trenino.Train.OutputBinding

  defmodule State do
    @moduledoc false

    @type binding_info :: %{
            binding: OutputBinding.t(),
            current_state: boolean()
          }

    @type t :: %__MODULE__{
            active_train: Train.Train.t() | nil,
            bindings: %{integer() => binding_info()},
            endpoints: [String.t()]
          }

    defstruct active_train: nil, bindings: %{}, endpoints: []
  end

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Reload bindings for the active train.

  Call this when output bindings are modified to pick up changes.
  """
  @spec reload_bindings() :: :ok
  def reload_bindings do
    GenServer.cast(__MODULE__, :reload_bindings)
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    Train.subscribe()
    SimulatorConnection.subscribe()
    Watcher.subscribe()

    state = %State{}

    state =
      case Train.get_active_train() do
        nil -> state
        train -> load_bindings_for_train(state, train)
      end

    {:ok, state}
  end

  @impl true
  def handle_cast(:reload_bindings, %State{active_train: nil} = state) do
    {:noreply, state}
  end

  def handle_cast(:reload_bindings, %State{active_train: train} = state) do
    state = cleanup(state)
    {:noreply, load_bindings_for_train(state, train)}
  end

  @impl true
  def handle_info({:train_changed, nil}, %State{} = state) do
    Logger.info("[OutputController] Train deactivated, cleaning up")
    state = cleanup(state)
    {:noreply, %{state | active_train: nil, bindings: %{}, endpoints: []}}
  end

  def handle_info({:train_changed, train}, %State{} = state) do
    Logger.info("[OutputController] Train activated: #{train.name}")
    state = cleanup(state)
    {:noreply, load_bindings_for_train(state, train)}
  end

  def handle_info({:train_detected, _}, %State{} = state), do: {:noreply, state}
  def handle_info({:detection_error, _}, %State{} = state), do: {:noreply, state}

  # The watcher re-watches on reconnect; values resume by themselves.
  def handle_info({:simulator_status_changed, %ConnectionState{status: :connected}}, state) do
    {:noreply, state}
  end

  # Without a simulator the outputs no longer reflect anything, so they are switched off.
  def handle_info({:simulator_status_changed, %ConnectionState{}}, %State{} = state) do
    {:noreply, all_outputs_off(state)}
  end

  def handle_info(:simulator_watcher_started, %State{endpoints: endpoints} = state) do
    Watcher.watch(endpoints)
    {:noreply, state}
  end

  def handle_info({:simulator_values, values}, %State{} = state) when is_map(values) do
    {:noreply, Enum.reduce(values, state, &update_endpoint/2)}
  end

  def handle_info(_msg, %State{} = state), do: {:noreply, state}

  # Private Functions

  # Bindings load whether or not the simulator is reachable right now; values
  # arrive from the watcher once it is.
  defp load_bindings_for_train(%State{} = state, train) do
    bindings = Train.list_enabled_output_bindings(train.id)

    binding_map =
      Map.new(bindings, fn %OutputBinding{} = binding ->
        {binding.id, %{binding: binding, current_state: false}}
      end)

    endpoints = bindings |> Enum.map(& &1.endpoint) |> Enum.uniq() |> Enum.sort()

    if map_size(binding_map) == 0 do
      Logger.info("[OutputController] No output bindings for train #{train.name}")
    else
      Logger.info(
        "[OutputController] Loaded #{map_size(binding_map)} bindings for train #{train.name}"
      )
    end

    Watcher.watch(endpoints)
    %{state | active_train: train, bindings: binding_map, endpoints: endpoints}
  end

  defp cleanup(%State{} = state) do
    Watcher.unwatch_all()
    all_outputs_off(state)
  end

  defp all_outputs_off(%State{} = state) do
    bindings =
      Map.new(state.bindings, fn {id, info} ->
        set_output_state(info.binding, false)
        {id, %{info | current_state: false}}
      end)

    %{state | bindings: bindings}
  end

  defp update_endpoint({endpoint, raw_value}, %State{} = state) do
    value = normalize_value(raw_value)

    state.bindings
    |> Enum.filter(fn {_id, info} -> info.binding.endpoint == endpoint end)
    |> then(&update_bindings_with_value(state, &1, value))
  end

  # Normalize values: round floats to 2 decimals, pass booleans through
  defp normalize_value(value) when is_boolean(value), do: value
  defp normalize_value(value) when is_number(value), do: Float.round(value * 1.0, 2)
  defp normalize_value(value), do: value

  defp update_bindings_with_value(state, binding_entries, value) do
    Enum.reduce(binding_entries, state, fn {id, info}, acc ->
      new_state = condition_met?(info.binding, value)

      if new_state != info.current_state do
        Logger.debug(
          "[OutputController] #{info.binding.name}: value=#{value}, state=#{new_state}"
        )

        set_output_state(info.binding, new_state)

        updated_info = %{info | current_state: new_state}
        %{acc | bindings: Map.put(acc.bindings, id, updated_info)}
      else
        acc
      end
    end)
  end

  @doc """
  Whether a binding's condition holds for a simulator value: the LED is on when it does.

  Numeric operators compare numbers. `:eq_true` and `:eq_false` take booleans, and also
  numbers for simulators without booleans (SimRail), where a positive number is true.
  Any other pairing is false.
  """
  @spec condition_met?(OutputBinding.t(), term()) :: boolean()
  # Numeric operators
  def condition_met?(%OutputBinding{operator: :gt, value_a: threshold}, value)
      when is_number(value) do
    value > threshold
  end

  def condition_met?(%OutputBinding{operator: :gte, value_a: threshold}, value)
      when is_number(value) do
    value >= threshold
  end

  def condition_met?(%OutputBinding{operator: :lt, value_a: threshold}, value)
      when is_number(value) do
    value < threshold
  end

  def condition_met?(%OutputBinding{operator: :lte, value_a: threshold}, value)
      when is_number(value) do
    value <= threshold
  end

  def condition_met?(
        %OutputBinding{operator: :between, value_a: min, value_b: max},
        value
      )
      when is_number(value) do
    value >= min and value <= max
  end

  # Boolean operators. SimRail sends lamps and flags as numbers, usually 0/1 with
  # negative rest values such as -1, so a number counts as true when it is positive.
  def condition_met?(%OutputBinding{operator: :eq_true}, value)
      when is_boolean(value) or is_number(value) do
    truthy?(value)
  end

  def condition_met?(%OutputBinding{operator: :eq_false}, value)
      when is_boolean(value) or is_number(value) do
    not truthy?(value)
  end

  # Fallback for type mismatches (e.g., boolean value with numeric operator)
  def condition_met?(_binding, _value), do: false

  defp truthy?(value) when is_boolean(value), do: value
  defp truthy?(value) when is_number(value), do: value > 0

  defp set_output_state(%OutputBinding{output: output}, state) do
    port = ConfigurationManager.config_id_to_port(output.device.config_id)

    if port do
      value = if state, do: :high, else: :low
      Hardware.set_output(port, output.pin, value)
    end
  end
end
