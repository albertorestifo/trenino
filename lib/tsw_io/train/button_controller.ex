defmodule TswIo.Train.ButtonController do
  @moduledoc """
  Controls button values based on hardware input.

  This GenServer:
  - Subscribes to train detection events to know which train is active
  - Subscribes to hardware input events
  - Maps button press/release to simulator ON/OFF values
  - Sends values to the simulator when an enabled binding exists

  ## Architecture

  The controller maintains:
  - Active train and its enabled button bindings
  - Mapping from (port, pin) → input_id for quick lookup
  - Last sent values to avoid redundant simulator calls

  When a button input value changes:
  1. Look up the input_id from (port, pin)
  2. Check if there's an enabled binding for this input on the active train
  3. Determine value based on button state (1 → on_value, 0 → off_value)
  4. Send value to simulator via Client

  Unlike LeverController, no calibration or notch mapping is needed since
  buttons are already binary (0/1) from the hardware.
  """

  use GenServer
  require Logger

  alias TswIo.Hardware
  alias TswIo.Hardware.ConfigurationManager
  alias TswIo.Serial.Connection, as: SerialConnection
  alias TswIo.Simulator.Connection, as: SimulatorConnection
  alias TswIo.Simulator.ConnectionState
  alias TswIo.Train
  alias TswIo.Train.ButtonInputBinding

  defmodule State do
    @moduledoc false

    @type input_lookup :: %{
            {port :: String.t(), pin :: integer()} => integer()
          }

    @type binding_lookup :: %{
            (input_id :: integer()) => %{
              element_id: integer(),
              endpoint: String.t(),
              on_value: float(),
              off_value: float()
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
  def handle_info({:train_changed, nil}, %State{} = state) do
    Logger.info("[ButtonController] Train deactivated, clearing bindings")
    {:noreply, %{state | active_train: nil, binding_lookup: %{}, last_sent_values: %{}}}
  end

  def handle_info({:train_changed, train}, %State{} = state) do
    Logger.info("[ButtonController] Train activated: #{train.name}")
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
    # Get all connected devices
    devices = SerialConnection.list_devices()

    # Build mapping from (port, pin) -> input_id for button inputs only
    {input_lookup, new_ports} =
      devices
      |> Enum.filter(&(&1.status == :connected and &1.device_config_id != nil))
      |> Enum.reduce({%{}, MapSet.new()}, fn device_conn, {lookup, ports} ->
        case find_device_by_config_id(device_conn.device_config_id) do
          nil ->
            {lookup, ports}

          device ->
            {:ok, inputs} = Hardware.list_inputs(device.id)

            # Only include button inputs
            button_inputs = Enum.filter(inputs, &(&1.input_type == :button))

            updated_lookup =
              Enum.reduce(button_inputs, lookup, fn input, acc ->
                Map.put(acc, {device_conn.port, input.pin}, input.id)
              end)

            {updated_lookup, MapSet.put(ports, device_conn.port)}
        end
      end)

    # Subscribe to new ports
    new_ports
    |> MapSet.difference(old_ports)
    |> Enum.each(&ConfigurationManager.subscribe_input_values/1)

    %{state | input_lookup: input_lookup, subscribed_ports: new_ports}
  end

  defp find_device_by_config_id(config_id) do
    case Hardware.get_device_by_config_id(config_id) do
      {:ok, device} -> device
      {:error, :not_found} -> nil
    end
  end

  defp load_bindings_for_train(%State{} = state, train) do
    bindings = Train.list_button_bindings_for_train(train.id)

    binding_lookup =
      bindings
      |> Enum.filter(& &1.enabled)
      |> Enum.map(fn %ButtonInputBinding{} = binding ->
        {binding.input_id,
         %{
           element_id: binding.element_id,
           endpoint: binding.endpoint,
           on_value: binding.on_value,
           off_value: binding.off_value
         }}
      end)
      |> Map.new()

    Logger.info(
      "[ButtonController] Loaded #{map_size(binding_lookup)} enabled bindings for train #{train.name}"
    )

    %{state | active_train: train, binding_lookup: binding_lookup, last_sent_values: %{}}
  end

  defp handle_input_update(%State{active_train: nil}, _port, _pin, _raw_value) do
    :skip
  end

  defp handle_input_update(%State{} = state, port, pin, raw_value) do
    with {:ok, input_id} <- Map.fetch(state.input_lookup, {port, pin}),
         {:ok, binding_info} <- Map.fetch(state.binding_lookup, input_id) do
      # Button value: 1 = pressed (on_value), 0 = released (off_value)
      sim_value =
        if raw_value == 1 do
          binding_info.on_value
        else
          binding_info.off_value
        end

      # Only send if value changed (avoid flooding simulator)
      element_id = binding_info.element_id

      if Map.get(state.last_sent_values, element_id) != sim_value do
        send_to_simulator(binding_info.endpoint, sim_value)

        # Broadcast button state update for UI
        broadcast_button_update(element_id, sim_value, raw_value == 1)

        {:ok, %{state | last_sent_values: Map.put(state.last_sent_values, element_id, sim_value)}}
      else
        :skip
      end
    else
      :error -> :skip
    end
  end

  defp send_to_simulator(endpoint, value) do
    case get_simulator_client() do
      {:ok, client} ->
        case TswIo.Simulator.Client.set(client, endpoint, value) do
          {:ok, _response} ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "[ButtonController] Failed to send value to simulator: #{inspect(reason)}"
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

  defp broadcast_button_update(element_id, value_sent, pressed?) do
    Phoenix.PubSub.broadcast(
      TswIo.PubSub,
      "train:button_values",
      {:button_state_changed, element_id, %{value: value_sent, pressed: pressed?}}
    )
  end
end
