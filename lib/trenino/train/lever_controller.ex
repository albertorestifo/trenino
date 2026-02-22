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
  5. Send value to simulator via Client
  """

  use GenServer
  require Logger

  alias Trenino.Hardware
  alias Trenino.Hardware.BLDCProfileBuilder
  alias Trenino.Hardware.Calibration.Calculator
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Hardware.Input.Calibration
  alias Trenino.Serial.Connection, as: SerialConnection
  alias Trenino.Serial.Protocol.{DeactivateBLDCProfile, LoadBLDCProfile}
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
              input_type: :analog | :button | :bldc_lever,
              calibration: Calibration.t() | nil
            }
          }

    @type binding_lookup :: %{
            (input_id :: integer()) => %{
              lever_config: LeverConfig.t(),
              binding: LeverInputBinding.t()
            }
          }

    @type t :: %__MODULE__{
            active_train: Train.Train.t() | nil,
            input_lookup: input_lookup(),
            binding_lookup: binding_lookup(),
            subscribed_ports: MapSet.t(String.t()),
            last_sent_values: %{integer() => float()}
          }

    defstruct active_train: nil,
              input_lookup: %{},
              binding_lookup: %{},
              subscribed_ports: MapSet.new(),
              last_sent_values: %{}
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
    GenServer.cast(__MODULE__, :reload_bindings)
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
  def handle_info({:train_changed, nil}, %State{active_train: active_train} = state) do
    Logger.info("[LeverController] Train deactivated, clearing bindings")

    if active_train do
      deactivate_bldc_profiles_for_train(active_train)
    end

    {:noreply, %{state | active_train: nil, binding_lookup: %{}, last_sent_values: %{}}}
  end

  def handle_info({:train_changed, train}, %State{} = state) do
    Logger.info("[LeverController] Train activated: #{train.name}")
    new_state = load_bindings_for_train(state, train)
    {:noreply, new_state}
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
    case handle_input_update(state, port, pin, raw_value) do
      {:ok, new_state} -> {:noreply, new_state}
      :skip -> {:noreply, state}
    end
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
      |> Enum.map(fn binding ->
        {binding.input_id, %{lever_config: binding.lever_config, binding: binding}}
      end)
      |> Map.new()

    Logger.info(
      "[LeverController] Loaded #{map_size(binding_lookup)} enabled bindings for train #{train.name}"
    )

    load_bldc_profiles_for_train(train)

    %{state | active_train: train, binding_lookup: binding_lookup, last_sent_values: %{}}
  end

  defp handle_input_update(%State{active_train: nil}, _port, _pin, _raw_value) do
    :skip
  end

  defp handle_input_update(%State{} = state, port, pin, raw_value) do
    with {:ok, input_info} <- Map.fetch(state.input_lookup, {port, pin}),
         {:ok, binding_info} <- Map.fetch(state.binding_lookup, input_info.input_id) do
      case input_info.input_type do
        :bldc_lever ->
          handle_bldc_input(state, binding_info, raw_value)

        _analog ->
          handle_analog_input(state, input_info, binding_info, raw_value)
      end
    else
      :error -> :skip
    end
  end

  defp handle_bldc_input(%State{} = state, binding_info, detent_index) do
    case LeverMapper.map_detent(binding_info.lever_config, detent_index) do
      {:ok, sim_value} ->
        maybe_send_value(state, binding_info.lever_config, sim_value)

      {:error, _reason} ->
        :skip
    end
  end

  defp handle_analog_input(%State{} = state, input_info, binding_info, raw_value) do
    with {:ok, normalized} <- normalize_value(raw_value, input_info.calibration),
         {:ok, sim_value} <- LeverMapper.map_input(binding_info.lever_config, normalized) do
      maybe_send_value(state, binding_info.lever_config, sim_value)
    else
      {:error, _reason} -> :skip
    end
  end

  defp maybe_send_value(%State{} = state, %LeverConfig{} = lever_config, sim_value) do
    if Map.get(state.last_sent_values, lever_config.id) != sim_value do
      send_to_simulator(lever_config, sim_value)

      {:ok,
       %{state | last_sent_values: Map.put(state.last_sent_values, lever_config.id, sim_value)}}
    else
      :skip
    end
  end

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
    case get_simulator_client() do
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

  defp get_simulator_client do
    case SimulatorConnection.get_status() do
      %ConnectionState{status: :connected, client: client} when client != nil ->
        {:ok, client}

      _ ->
        :error
    end
  end

  # Loads BLDC profiles for all BLDC levers in the train
  defp load_bldc_profiles_for_train(%Train.Train{} = train) do
    with {:ok, elements} <- Train.list_elements(train.id),
         lever_configs <- get_lever_configs_from_elements(elements),
         bldc_configs <- Enum.filter(lever_configs, &(&1.lever_type == :bldc)),
         {:ok, port} <- find_device_port_for_lever() do
      Enum.each(bldc_configs, fn %LeverConfig{} = config ->
        load_bldc_profile(port, config)
      end)
    else
      {:error, :no_device_connected} ->
        Logger.warning("[LeverController] No device connected, skipping BLDC profile loading")

      {:error, reason} ->
        Logger.error("[LeverController] Failed to load BLDC profiles: #{inspect(reason)}")
    end
  end

  # Extracts lever configs from elements, filtering out those without configs
  defp get_lever_configs_from_elements(elements) do
    elements
    |> Enum.map(& &1.lever_config)
    |> Enum.reject(&(is_nil(&1) or match?(%Ecto.Association.NotLoaded{}, &1)))
  end

  # Loads a single BLDC profile to the device
  defp load_bldc_profile(port, %LeverConfig{} = config) do
    case BLDCProfileBuilder.build_profile(config) do
      {:ok, %LoadBLDCProfile{} = profile} ->
        case SerialConnection.send_message(port, profile) do
          :ok ->
            Logger.info(
              "[LeverController] Loaded BLDC profile for lever config #{config.id} on port #{port}"
            )

            :ok

          {:error, reason} ->
            Logger.error(
              "[LeverController] Failed to send BLDC profile for config #{config.id}: #{inspect(reason)}"
            )

            {:error, reason}
        end

      {:error, reason} ->
        Logger.error(
          "[LeverController] Failed to build BLDC profile for config #{config.id}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  # Finds the first connected device port
  defp find_device_port_for_lever do
    case SerialConnection.connected_devices() do
      [device | _] -> {:ok, device.port}
      [] -> {:error, :no_device_connected}
    end
  end

  # Deactivates BLDC profiles for all BLDC levers in the train
  defp deactivate_bldc_profiles_for_train(%Train.Train{} = train) do
    with {:ok, elements} <- Train.list_elements(train.id),
         lever_configs <- get_lever_configs_from_elements(elements),
         bldc_configs <- Enum.filter(lever_configs, &(&1.lever_type == :bldc)),
         {:ok, port} <- find_device_port_for_lever() do
      Enum.each(bldc_configs, fn _config ->
        deactivate_bldc_profile(port)
      end)
    else
      {:error, :no_device_connected} ->
        Logger.warning(
          "[LeverController] No device connected, skipping BLDC profile deactivation"
        )

      {:error, reason} ->
        Logger.error("[LeverController] Failed to deactivate BLDC profiles: #{inspect(reason)}")
    end
  end

  # Deactivates a BLDC profile on the device
  defp deactivate_bldc_profile(port) do
    profile = %DeactivateBLDCProfile{pin: 0}

    case SerialConnection.send_message(port, profile) do
      :ok ->
        Logger.info("[LeverController] Deactivated BLDC profile on port #{port}")
        :ok

      {:error, reason} ->
        Logger.error("[LeverController] Failed to deactivate BLDC profile: #{inspect(reason)}")

        {:error, reason}
    end
  end
end
