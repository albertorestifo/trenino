defmodule Trenino.Train.LeverController do
  @moduledoc """
  Controls lever values based on hardware input.

  This GenServer:
  - Subscribes to train detection events to know which train is active
  - Subscribes to hardware input events
  - Maps calibrated input values to simulator values via LeverMapper
  - Sends values to the simulator when an enabled binding exists

  ## Architecture

  The controller maintains:
  - Active train and its enabled bindings
  - Mapping from (port, pin) → input_id for quick lookup
  - Device calibrations for normalizing raw input values

  When an input value changes:
  1. Look up the input_id from (port, pin)
  2. Check if there's an enabled binding for this input on the active train
  3. Normalize the raw value using calibration (0.0-1.0)
  4. Map through LeverMapper to get simulator value
  5. Send the latest value to the simulator

  Smooth levers jitter many times per second. Each simulator write is a blocking
  HTTP request, so doing it in this process would queue every intermediate sample
  and replay them FIFO. The write runs under `Task.Supervisor`. While it is in
  flight, a newer sample replaces that lever's pending value. Only the latest
  value is sent. Other levers are not blocked by it.
  """

  use GenServer
  require Logger

  alias Trenino.Hardware
  alias Trenino.Hardware.Calibration.Calculator
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Hardware.Input.Calibration
  alias Trenino.Serial.Connection, as: SerialConnection
  alias Trenino.Simulator.Client, as: SimulatorClient
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train
  alias Trenino.Train.{LeverConfig, LeverInputBinding, LeverMapper}

  defmodule State do
    @moduledoc false

    @type input_lookup :: %{
            {port :: String.t(), pin :: integer()} => %{
              input_id: integer(),
              input_type: :analog | :button,
              calibration: Calibration.t() | nil
            }
          }

    @type binding_lookup :: %{
            (input_id :: integer()) => %{
              lever_config: LeverConfig.t(),
              binding: LeverInputBinding.t()
            }
          }

    @type pending_write :: {LeverConfig.t(), float(), Task.t()}

    @type t :: %__MODULE__{
            active_train: Train.Train.t() | nil,
            input_lookup: input_lookup(),
            binding_lookup: binding_lookup(),
            subscribed_ports: MapSet.t(String.t()),
            pending: %{integer() => pending_write()}
          }

    defstruct active_train: nil,
              input_lookup: %{},
              binding_lookup: %{},
              subscribed_ports: MapSet.new(),
              pending: %{}
  end

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Get the current state of the controller.
  """
  @spec get_state() :: State.t()
  def get_state do
    GenServer.call(__MODULE__, :get_state)
  end

  @doc """
  Reload bindings for the active train.

  Call this when bindings are modified to pick up changes.
  """
  @spec reload_bindings() :: :ok
  def reload_bindings do
    if Process.whereis(__MODULE__), do: GenServer.cast(__MODULE__, :reload_bindings)

    :ok
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    # Subscribe to train detection
    Train.subscribe()

    # Subscribe to device connection updates
    SerialConnection.subscribe()

    # Build initial input lookup from connected devices
    state = %State{}
    state = rebuild_input_lookup(state)

    # Load bindings if there's already an active train
    state =
      case Train.get_active_train() do
        nil -> state
        train -> load_bindings_for_train(state, train)
      end

    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, %State{} = state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast(:reload_bindings, %State{active_train: nil} = state) do
    {:noreply, state}
  end

  def handle_cast(:reload_bindings, %State{active_train: train} = state) do
    {:noreply, load_bindings_for_train(state, train)}
  end

  # Train detection events
  @impl true
  def handle_info({:train_changed, nil}, %State{} = state) do
    Logger.info("[LeverController] Train deactivated, clearing bindings")
    {:noreply, %{state | active_train: nil, binding_lookup: %{}, pending: %{}}}
  end

  def handle_info({:train_changed, train}, %State{} = state) do
    Logger.info("[LeverController] Train activated: #{train.name}")
    {:noreply, load_bindings_for_train(state, train)}
  end

  def handle_info({:train_detected, _}, %State{} = state) do
    # Handled by :train_changed
    {:noreply, state}
  end

  def handle_info({:detection_error, _reason}, %State{} = state) do
    {:noreply, state}
  end

  # Device connection events
  @impl true
  def handle_info({:devices_updated, _devices}, %State{} = state) do
    # Rebuild input lookup when devices change
    {:noreply, rebuild_input_lookup(state)}
  end

  # Input value updates
  @impl true
  def handle_info({:input_value_updated, port, pin, raw_value}, %State{} = state) do
    {:noreply, apply_input_update(state, port, pin, raw_value)}
  end

  def handle_info({ref, result}, %State{} = state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, finish_write(state, ref, result)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %State{} = state) do
    Logger.warning("[LeverController] Simulator write crashed: #{inspect(reason)}")
    {:noreply, finish_write(state, ref, :error)}
  end

  # Catch-all for unknown messages
  def handle_info(_msg, %State{} = state) do
    {:noreply, state}
  end

  # Private Functions

  defp rebuild_input_lookup(%State{subscribed_ports: old_ports} = state) do
    devices = SerialConnection.list_devices()

    {input_lookup, new_ports} =
      devices
      |> Enum.filter(&(&1.status == :connected and &1.device_config_id != nil))
      |> Enum.reduce({%{}, MapSet.new()}, fn device_conn, acc ->
        add_device_inputs(device_conn, acc)
      end)

    new_ports
    |> MapSet.difference(old_ports)
    |> Enum.each(&ConfigurationManager.subscribe_input_values/1)

    %{state | input_lookup: input_lookup, subscribed_ports: new_ports}
  end

  defp add_device_inputs(device_conn, {lookup, ports}) do
    case find_device_by_config_id(device_conn.device_config_id) do
      nil ->
        {lookup, ports}

      device ->
        {:ok, inputs} = Hardware.list_inputs(device.id)

        updated_lookup =
          Enum.reduce(inputs, lookup, fn input, acc ->
            Map.put(acc, {device_conn.port, input.pin}, %{
              input_id: input.id,
              input_type: input.input_type,
              calibration: input.calibration
            })
          end)

        {updated_lookup, MapSet.put(ports, device_conn.port)}
    end
  end

  defp find_device_by_config_id(config_id) do
    case Hardware.get_device_by_config_id(config_id) do
      {:ok, device} -> device
      {:error, :not_found} -> nil
    end
  end

  defp load_bindings_for_train(%State{} = state, train) do
    bindings = Train.list_bindings_for_train(train.id)

    binding_lookup =
      bindings
      |> Enum.filter(& &1.enabled)
      |> Map.new(fn binding ->
        {binding.input_id, %{lever_config: binding.lever_config, binding: binding}}
      end)

    Logger.info(
      "[LeverController] Loaded #{map_size(binding_lookup)} enabled bindings for train #{train.name}"
    )

    %{state | active_train: train, binding_lookup: binding_lookup, pending: %{}}
  end

  defp apply_input_update(%State{} = state, port, pin, raw_value) do
    case resolve_simulator_value(state, port, pin, raw_value) do
      {:ok, lever_config, sim_value} -> enqueue_value(state, lever_config, sim_value)
      :skip -> state
    end
  end

  defp resolve_simulator_value(%State{active_train: nil}, _port, _pin, _raw_value), do: :skip

  defp resolve_simulator_value(%State{} = state, port, pin, raw_value) do
    with {:ok, input_info} <- Map.fetch(state.input_lookup, {port, pin}),
         {:ok, binding_info} <- Map.fetch(state.binding_lookup, input_info.input_id),
         {:ok, normalized} <- normalize_value(raw_value, input_info.calibration),
         {:ok, sim_value} <- LeverMapper.map_input(binding_info.lever_config, normalized) do
      {:ok, binding_info.lever_config, sim_value}
    else
      :error -> :skip
      {:error, _reason} -> :skip
    end
  end

  # One in-flight write per lever. A newer sample replaces the pending value so
  # a slow simulator response cannot replay a FIFO of jitter.
  defp enqueue_value(%State{} = state, %LeverConfig{id: id} = lever_config, sim_value) do
    case Map.get(state.pending, id) do
      nil ->
        start_write(state, lever_config, sim_value)

      {_config, _value, task} ->
        %{state | pending: Map.put(state.pending, id, {lever_config, sim_value, task})}
    end
  end

  defp start_write(%State{} = state, %LeverConfig{id: id} = lever_config, sim_value) do
    task =
      Task.Supervisor.async_nolink(Trenino.TaskSupervisor, fn ->
        case send_to_simulator(lever_config, sim_value) do
          :ok -> {:ok, id, sim_value}
          error -> {error, id, sim_value}
        end
      end)

    put_in(state.pending[id], {lever_config, sim_value, task})
  end

  defp finish_write(%State{} = state, ref, {:ok, id, written}) do
    case Map.get(state.pending, id) do
      {%LeverConfig{}, latest, %Task{ref: ^ref}} when latest == written ->
        %{state | pending: Map.delete(state.pending, id)}

      {%LeverConfig{} = lever_config, latest, %Task{ref: ^ref}} ->
        start_write(%{state | pending: Map.delete(state.pending, id)}, lever_config, latest)

      _ ->
        state
    end
  end

  defp finish_write(%State{} = state, ref, {_error, id, _written}) do
    case Map.pop(state.pending, id) do
      {{%LeverConfig{} = lever_config, latest, %Task{ref: ^ref}}, pending} ->
        start_write(%{state | pending: pending}, lever_config, latest)

      {_, _} ->
        state
    end
  end

  defp finish_write(%State{} = state, _ref, _result), do: state

  # Normalizes a raw hardware value to a 0.0-1.0 float for lever mapping.
  #
  # The calibration system works in two stages:
  # 1. Calculator.normalize/2 converts raw ADC value to calibrated integer (0 to total_travel)
  # 2. This function divides by total_travel to get a 0.0-1.0 normalized float
  #
  # Example:
  #   Raw value: 512 (from 10-bit ADC)
  #   Calibration: min=100, max=900 (total_travel = 800)
  #   Normalized integer: 512 - 100 = 412
  #   Normalized float: 412 / 800 = 0.515 (51.5% of travel)
  defp normalize_value(_raw_value, nil) do
    {:error, :no_calibration}
  end

  defp normalize_value(raw_value, %Calibration{} = calibration) do
    normalized = Calculator.normalize(raw_value, calibration)
    total = Calculator.total_travel(calibration)

    if total > 0 do
      {:ok, Float.round(normalized / total, 2)}
    else
      {:error, :invalid_calibration}
    end
  end

  defp send_to_simulator(%LeverConfig{value_endpoint: endpoint}, value) do
    case simulator_client() do
      {:ok, client} ->
        case SimulatorClient.set(client, endpoint, value) do
          {:ok, _response} ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "[LeverController] Failed to send value to simulator: #{inspect(reason)}"
            )

            :error
        end

      :error ->
        :skip
    end
  end

  defp simulator_client do
    case SimulatorConnection.get_status() do
      %ConnectionState{status: :connected, client: client} when client != nil ->
        {:ok, client}

      _ ->
        :error
    end
  end
end
