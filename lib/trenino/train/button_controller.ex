defmodule Trenino.Train.ButtonController do
  @moduledoc """
  Controls button values based on hardware input.

  This GenServer:
  - Subscribes to train detection events to know which train is active
  - Subscribes to hardware input events
  - Maps button press/release to simulator ON/OFF values
  - Sends values to the simulator when an enabled binding exists
  - Manages momentary mode (repeat commands while held)

  ## Architecture

  The controller maintains:
  - Active train and its enabled button bindings
  - Mapping from (port, pin) → input_id for quick lookup
  - Last sent values to avoid redundant simulator calls
  - Active buttons with timers for momentary mode

  When a button input value changes:
  1. Look up the input_id from (port, pin)
  2. Check if there's an enabled binding for this input on the active train
  3. Handle based on mode:
     - Simple: Send on_value when pressed, off_value when released
     - Momentary: Repeat on_value at interval while held, off_value on release
     - Sequence: Execute command sequence

  Unlike LeverController, no calibration or notch mapping is needed since
  buttons are already binary (0/1) from the hardware.
  """

  use GenServer
  require Logger

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Hardware.Input
  alias Trenino.Keyboard
  alias Trenino.Serial.Connection, as: SerialConnection
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train
  alias Trenino.Train.ButtonInputBinding

  defmodule State do
    @moduledoc false

    @type input_lookup :: %{
            {port :: String.t(), pin :: integer()} => integer()
          }

    @type sequence_info :: %{
            id: integer(),
            commands: [%{endpoint: String.t(), value: float(), delay_ms: integer()}]
          }

    @type binding_info :: %{
            element_id: integer(),
            endpoint: String.t() | nil,
            on_value: float(),
            off_value: float(),
            mode: ButtonInputBinding.mode(),
            hardware_type: ButtonInputBinding.hardware_type(),
            repeat_interval_ms: integer(),
            keystroke: String.t() | nil,
            on_sequence: sequence_info() | nil,
            off_sequence: sequence_info() | nil
          }

    @type binding_lookup :: %{
            (input_id :: integer()) => binding_info()
          }

    @type active_button :: %{
            element_id: integer(),
            binding_info: binding_info(),
            timer_ref: reference() | nil,
            sequence_task: pid() | nil
          }

    @type t :: %__MODULE__{
            active_train: Train.Train.t() | nil,
            input_lookup: input_lookup(),
            binding_lookup: binding_lookup(),
            subscribed_ports: MapSet.t(String.t()),
            last_sent_values: %{integer() => float()},
            active_buttons: %{integer() => active_button()}
          }

    defstruct active_train: nil,
              input_lookup: %{},
              binding_lookup: %{},
              subscribed_ports: MapSet.new(),
              last_sent_values: %{},
              active_buttons: %{}
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
    # Cancel all active buttons before reloading
    state = cancel_all_active_buttons(state)
    {:noreply, load_bindings_for_train(state, train)}
  end

  # Train detection events
  @impl true
  def handle_info({:train_changed, nil}, %State{} = state) do
    Logger.info("[ButtonController] Train deactivated, clearing bindings")
    state = cancel_all_active_buttons(state)

    {:noreply,
     %{state | active_train: nil, binding_lookup: %{}, last_sent_values: %{}, active_buttons: %{}}}
  end

  def handle_info({:train_changed, train}, %State{} = state) do
    Logger.info("[ButtonController] Train activated: #{train.name}")
    # Cancel active buttons from previous train
    state = cancel_all_active_buttons(state)
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

  # Momentary repeat - keeps sending InputValue while button is held
  # Sends as fast as possible (no delay between sends)
  def handle_info({:momentary_repeat, element_id}, %State{} = state) do
    case Map.get(state.active_buttons, element_id) do
      nil ->
        # Button was released, stop
        {:noreply, state}

      %{binding_info: binding_info} = _active_button ->
        # Send the on_value again
        send_to_simulator(binding_info.endpoint, binding_info.on_value)

        # Immediately queue next send (no delay)
        send(self(), {:momentary_repeat, element_id})

        {:noreply, state}
    end
  end

  # Sequence execution complete
  def handle_info({:sequence_complete, element_id}, %State{} = state) do
    # Clean up the active button entry
    state = %{state | active_buttons: Map.delete(state.active_buttons, element_id)}
    {:noreply, state}
  end

  # Catch-all for unknown messages
  def handle_info(_msg, %State{} = state) do
    {:noreply, state}
  end

  # Private Functions

  defp rebuild_input_lookup(%State{subscribed_ports: old_ports} = state) do
    # Get all connected devices
    devices = SerialConnection.list_devices()

    # Build mapping from (port, pin) -> input_id for button inputs
    # This includes both physical buttons and virtual buttons from matrices
    {input_lookup, new_ports} =
      devices
      |> Enum.filter(&(&1.status == :connected and &1.device_config_id != nil))
      |> Enum.reduce({%{}, MapSet.new()}, fn device_conn, {lookup, ports} ->
        case find_device_by_config_id(device_conn.device_config_id) do
          nil ->
            {lookup, ports}

          device ->
            # Get all button inputs including virtual buttons from matrices
            {:ok, inputs} = Hardware.list_inputs(device.id, include_virtual_buttons: true)

            button_inputs = Enum.filter(inputs, &(&1.input_type == :button))

            updated_lookup =
              Enum.reduce(button_inputs, lookup, fn %Input{} = input, acc ->
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

    # Build lookup with simple input_id key
    binding_lookup =
      bindings
      |> Enum.filter(& &1.enabled)
      |> Enum.map(fn %ButtonInputBinding{} = binding ->
        Logger.info(
          "[ButtonController] Binding: element=#{binding.element_id}, mode=#{inspect(binding.mode)}, " <>
            "interval=#{binding.repeat_interval_ms}ms"
        )

        {binding.input_id, build_binding_info(binding)}
      end)
      |> Map.new()

    Logger.info(
      "[ButtonController] Loaded #{map_size(binding_lookup)} enabled bindings for train #{train.name}"
    )

    %{state | active_train: train, binding_lookup: binding_lookup, last_sent_values: %{}}
  end

  defp build_binding_info(%ButtonInputBinding{} = binding) do
    %{
      element_id: binding.element_id,
      endpoint: binding.endpoint,
      on_value: binding.on_value,
      off_value: binding.off_value,
      mode: binding.mode,
      hardware_type: binding.hardware_type,
      repeat_interval_ms: binding.repeat_interval_ms,
      keystroke: binding.keystroke,
      on_sequence: load_sequence_info(binding.on_sequence_id),
      off_sequence: load_sequence_info(binding.off_sequence_id)
    }
  end

  defp load_sequence_info(nil), do: nil

  defp load_sequence_info(sequence_id) do
    case Train.get_sequence(sequence_id) do
      {:ok, sequence} ->
        commands =
          Enum.map(sequence.commands, fn cmd ->
            %{endpoint: cmd.endpoint, value: cmd.value, delay_ms: cmd.delay_ms}
          end)

        %{id: sequence.id, commands: commands}

      {:error, _} ->
        nil
    end
  end

  defp handle_input_update(%State{active_train: nil}, _port, _pin, _raw_value) do
    :skip
  end

  defp handle_input_update(%State{} = state, port, pin, raw_value) do
    with {:ok, input_id} <- Map.fetch(state.input_lookup, {port, pin}),
         {:ok, binding_info} <- Map.fetch(state.binding_lookup, input_id) do
      element_id = binding_info.element_id

      case raw_value do
        1 -> handle_button_press(state, element_id, binding_info)
        0 -> handle_button_release(state, element_id, binding_info)
        _ -> :skip
      end
    else
      :error -> :skip
    end
  end

  # Handle button press based on mode
  defp handle_button_press(%State{} = state, element_id, %{mode: :simple} = binding_info) do
    sim_value = binding_info.on_value

    if Map.get(state.last_sent_values, element_id) != sim_value do
      send_to_simulator(binding_info.endpoint, sim_value)
      broadcast_button_update(element_id, sim_value, true)

      {:ok, %{state | last_sent_values: Map.put(state.last_sent_values, element_id, sim_value)}}
    else
      :skip
    end
  end

  defp handle_button_press(%State{} = state, element_id, %{mode: :momentary} = binding_info) do
    # Set Interacting=true and InputValue=on_value, then keep sending InputValue
    sim_value = binding_info.on_value

    # Set Interacting=true first, then InputValue
    send_to_simulator_with_interacting(binding_info.endpoint, sim_value, true)
    broadcast_button_update(element_id, sim_value, true)

    # Start continuous sending loop (no delay)
    send(self(), {:momentary_repeat, element_id})

    # Track active button
    active_button = %{
      element_id: element_id,
      binding_info: binding_info,
      timer_ref: nil
    }

    state = %{
      state
      | last_sent_values: Map.put(state.last_sent_values, element_id, sim_value),
        active_buttons: Map.put(state.active_buttons, element_id, active_button)
    }

    {:ok, state}
  end

  defp handle_button_press(%State{} = state, element_id, %{mode: :sequence} = binding_info) do
    case binding_info.on_sequence do
      nil ->
        # No sequence configured, skip
        Logger.warning("[ButtonController] Sequence mode button has no on_sequence configured")
        :skip

      %{commands: commands} when commands == [] ->
        # Empty sequence, skip
        :skip

      %{commands: commands} ->
        # Spawn a task to execute the sequence
        controller_pid = self()

        task_pid =
          spawn(fn ->
            execute_sequence_commands(commands, controller_pid, element_id)
          end)

        broadcast_button_update(element_id, binding_info.on_value, true)

        # Track active button for momentary hardware (to cancel on release)
        active_button = %{
          element_id: element_id,
          binding_info: binding_info,
          timer_ref: nil,
          sequence_task: task_pid
        }

        state = %{
          state
          | last_sent_values: Map.put(state.last_sent_values, element_id, binding_info.on_value),
            active_buttons: Map.put(state.active_buttons, element_id, active_button)
        }

        {:ok, state}
    end
  end

  defp handle_button_press(%State{} = state, element_id, %{mode: :keystroke} = binding_info) do
    keystroke = binding_info.keystroke

    case Keyboard.key_down(keystroke) do
      :ok ->
        Logger.debug("[ButtonController] Keystroke down: #{keystroke}")
        broadcast_button_update(element_id, 1.0, true)
        {:ok, %{state | last_sent_values: Map.put(state.last_sent_values, element_id, 1.0)}}

      {:error, reason} ->
        Logger.warning("[ButtonController] Keystroke failed: #{inspect(reason)}")
        :skip
    end
  end

  # Catch-all for unexpected modes (should never happen, but helps debug)
  defp handle_button_press(%State{} = _state, element_id, binding_info) do
    Logger.warning(
      "[ButtonController] Unknown button mode: element=#{element_id}, mode=#{inspect(binding_info.mode)}"
    )

    :skip
  end

  # Handle button release based on mode
  defp handle_button_release(%State{} = state, element_id, %{mode: :simple} = binding_info) do
    sim_value = binding_info.off_value

    if Map.get(state.last_sent_values, element_id) != sim_value do
      send_to_simulator(binding_info.endpoint, sim_value)
      broadcast_button_update(element_id, sim_value, false)

      {:ok, %{state | last_sent_values: Map.put(state.last_sent_values, element_id, sim_value)}}
    else
      :skip
    end
  end

  defp handle_button_release(%State{} = state, element_id, %{mode: :momentary} = binding_info) do
    # Cancel the repeat loop
    state = cancel_active_button(state, element_id)

    # Send off_value with Interacting=false
    sim_value = binding_info.off_value
    send_to_simulator_with_interacting(binding_info.endpoint, sim_value, false)
    broadcast_button_update(element_id, sim_value, false)

    state = %{state | last_sent_values: Map.put(state.last_sent_values, element_id, sim_value)}

    {:ok, state}
  end

  defp handle_button_release(%State{} = state, element_id, %{mode: :sequence} = binding_info) do
    # Cancel any running sequence for momentary hardware
    state = cancel_active_button(state, element_id)

    case binding_info.hardware_type do
      :momentary ->
        # For momentary hardware, just cancel the running sequence (done above)
        broadcast_button_update(element_id, binding_info.off_value, false)

        state = %{
          state
          | last_sent_values: Map.put(state.last_sent_values, element_id, binding_info.off_value)
        }

        {:ok, state}

      :latching ->
        # For latching hardware, execute off_sequence if defined
        case binding_info.off_sequence do
          nil ->
            # No off_sequence, just update state
            broadcast_button_update(element_id, binding_info.off_value, false)

            state = %{
              state
              | last_sent_values:
                  Map.put(state.last_sent_values, element_id, binding_info.off_value)
            }

            {:ok, state}

          %{commands: commands} when commands == [] ->
            broadcast_button_update(element_id, binding_info.off_value, false)

            state = %{
              state
              | last_sent_values:
                  Map.put(state.last_sent_values, element_id, binding_info.off_value)
            }

            {:ok, state}

          %{commands: commands} ->
            # Execute off_sequence
            controller_pid = self()

            task_pid =
              spawn(fn ->
                execute_sequence_commands(commands, controller_pid, element_id)
              end)

            broadcast_button_update(element_id, binding_info.off_value, false)

            # Track for potential future cancellation
            active_button = %{
              element_id: element_id,
              binding_info: binding_info,
              timer_ref: nil,
              sequence_task: task_pid
            }

            state = %{
              state
              | last_sent_values:
                  Map.put(state.last_sent_values, element_id, binding_info.off_value),
                active_buttons: Map.put(state.active_buttons, element_id, active_button)
            }

            {:ok, state}
        end
    end
  end

  defp handle_button_release(%State{} = state, element_id, %{mode: :keystroke} = binding_info) do
    keystroke = binding_info.keystroke

    case Keyboard.key_up(keystroke) do
      :ok ->
        Logger.debug("[ButtonController] Keystroke up: #{keystroke}")
        broadcast_button_update(element_id, 0.0, false)
        {:ok, %{state | last_sent_values: Map.put(state.last_sent_values, element_id, 0.0)}}

      {:error, reason} ->
        Logger.warning("[ButtonController] Keystroke release failed: #{inspect(reason)}")
        :skip
    end
  end

  defp cancel_active_button(%State{} = state, element_id) do
    case Map.pop(state.active_buttons, element_id) do
      {nil, _} ->
        state

      {active_button, new_active_buttons} ->
        if active_button.timer_ref, do: Process.cancel_timer(active_button.timer_ref)

        sequence_task = Map.get(active_button, :sequence_task)

        if sequence_task && Process.alive?(sequence_task),
          do: Process.exit(sequence_task, :kill)

        %{state | active_buttons: new_active_buttons}
    end
  end

  defp cancel_all_active_buttons(%State{active_buttons: active_buttons} = state) do
    Enum.each(active_buttons, fn {_element_id, button} ->
      if button.timer_ref, do: Process.cancel_timer(button.timer_ref)

      if button[:sequence_task] && Process.alive?(button.sequence_task),
        do: Process.exit(button.sequence_task, :kill)
    end)

    %{state | active_buttons: %{}}
  end

  defp send_to_simulator(endpoint, value) do
    case get_simulator_client() do
      {:ok, client} ->
        case Trenino.Simulator.Client.set(client, endpoint, value) do
          {:ok, _response} -> :ok
          {:error, _reason} -> :error
        end

      :error ->
        :skip
    end
  end

  # For momentary mode, we also need to set the Interacting property
  # This tells the simulator the button is being held
  defp send_to_simulator_with_interacting(endpoint, value, interacting) do
    case get_simulator_client() do
      {:ok, client} ->
        # Derive the Interacting endpoint from the InputValue endpoint
        interacting_endpoint = derive_interacting_endpoint(endpoint)

        # Set Interacting first (before setting value for press, after for release)
        if interacting do
          # Press: set Interacting=true first, then InputValue
          set_interacting(client, interacting_endpoint, true)
          send_value(client, endpoint, value)
        else
          # Release: set InputValue first, then Interacting=false
          send_value(client, endpoint, value)
          set_interacting(client, interacting_endpoint, false)
        end

        :ok

      :error ->
        :skip
    end
  end

  defp derive_interacting_endpoint(endpoint) do
    # Convert "Path/Control.InputValue" to "Path/Control.Interacting"
    endpoint
    |> String.replace(~r/\.InputValue$/, ".Interacting")
    |> then(fn ep ->
      # If no .InputValue suffix, append .Interacting to the control path
      if ep == endpoint do
        String.replace(endpoint, ~r/\.[^.]+$/, ".Interacting")
      else
        ep
      end
    end)
  end

  defp set_interacting(client, endpoint, value) do
    case Trenino.Simulator.Client.set(client, endpoint, value) do
      {:ok, _response} -> :ok
      {:error, _reason} -> :error
    end
  end

  defp send_value(client, endpoint, value) do
    case Trenino.Simulator.Client.set(client, endpoint, value) do
      {:ok, _response} -> :ok
      {:error, _reason} -> :error
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
      Trenino.PubSub,
      "train:button_values",
      {:button_state_changed, element_id, %{value: value_sent, pressed: pressed?}}
    )
  end

  # Execute sequence commands with delays between them
  # This runs in a spawned process and sends commands directly to the simulator
  # The process monitors the controller and exits if the controller dies
  defp execute_sequence_commands(commands, controller_pid, element_id) do
    # Monitor the controller so we die if it dies
    controller_ref = Process.monitor(controller_pid)

    try do
      execute_sequence_loop(commands, controller_pid, element_id, controller_ref)
    catch
      :exit, :controller_died ->
        Logger.debug("[ButtonController] Sequence cancelled: controller died")
        :ok

      :exit, :killed ->
        Logger.debug("[ButtonController] Sequence cancelled: task killed")
        :ok
    end
  end

  defp execute_sequence_loop([], controller_pid, element_id, controller_ref) do
    # All commands executed, notify controller
    Process.demonitor(controller_ref, [:flush])
    send(controller_pid, {:sequence_complete, element_id})
  end

  defp execute_sequence_loop(
         [%{endpoint: endpoint, value: value, delay_ms: delay_ms} | rest],
         controller_pid,
         element_id,
         controller_ref
       ) do
    # Check if controller is still alive before sending command
    receive do
      {:DOWN, ^controller_ref, :process, ^controller_pid, _reason} ->
        exit(:controller_died)
    after
      0 ->
        # Send value to simulator
        case get_simulator_client() do
          {:ok, client} ->
            case Trenino.Simulator.Client.set(client, endpoint, value) do
              {:ok, _} ->
                Logger.debug("[ButtonController] Sequence command: #{endpoint} = #{value}")

              {:error, reason} ->
                Logger.warning("[ButtonController] Sequence command failed: #{inspect(reason)}")
            end

          :error ->
            Logger.warning("[ButtonController] Simulator not connected for sequence")
        end
    end

    # Wait for delay, but check for controller death during wait
    if delay_ms > 0 do
      receive do
        {:DOWN, ^controller_ref, :process, ^controller_pid, _reason} ->
          exit(:controller_died)
      after
        delay_ms -> :ok
      end
    end

    # Continue with next command
    execute_sequence_loop(rest, controller_pid, element_id, controller_ref)
  end
end
