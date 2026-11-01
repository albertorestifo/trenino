defmodule Trenino.Hardware.ConfigurationManager do
  @moduledoc """
  Manages device configuration lifecycle and coordinates between
  the Hardware context and Serial layer.

  Responsibilities:
  - Apply configurations to devices
  - Track in-flight configuration operations
  - Handle async responses (ConfigurationStored, ConfigurationError)
  - Broadcast configuration events to UI
  - Manage configuration timeouts
  - Store and broadcast input values
  """

  use GenServer

  alias Trenino.Hardware
  alias Trenino.Hardware.I2cModule
  alias Trenino.Hardware.Input
  alias Trenino.Hardware.StepperManager
  alias Trenino.Serial.Connection

  alias Trenino.Serial.Protocol.ConfigurationError
  alias Trenino.Serial.Protocol.ConfigurationStored
  alias Trenino.Serial.Protocol.Configure
  alias Trenino.Serial.Protocol.InputValue
  alias Trenino.Serial.Protocol.ModuleError

  require Logger

  @config_timeout_ms 10_000
  @config_topic "hardware:configuration"
  @input_values_topic "hardware:input_values"
  @i2c_status_topic "hardware:i2c_status"

  @type i2c_status :: :init_failed | :communication_lost | :reference_lost

  defmodule State do
    @moduledoc false

    @type in_flight_info :: %{
            port: String.t(),
            timer_ref: reference(),
            device_id: integer()
          }

    @type t :: %__MODULE__{
            in_flight: %{integer() => in_flight_info()},
            failed_i2c: %{
              String.t() => %{integer() => Trenino.Hardware.ConfigurationManager.i2c_status()}
            },
            input_values: %{String.t() => %{integer() => integer()}},
            subscribed_ports: MapSet.t(String.t())
          }

    defstruct in_flight: %{},
              failed_i2c: %{},
              input_values: %{},
              subscribed_ports: MapSet.new()
  end

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, %State{}, Keyword.merge([name: __MODULE__], opts))
  end

  @doc """
  Apply a configuration to a device.

  This generates a config_id, sends Configure messages to the device,
  and tracks the operation until ConfigurationStored or timeout.

  Returns `{:ok, config_id}` immediately - subscribe to events for completion.
  """
  @spec apply_configuration(String.t(), integer()) :: {:ok, integer()} | {:error, term()}
  def apply_configuration(port, device_id) do
    GenServer.call(__MODULE__, {:apply_configuration, port, device_id})
  end

  @doc "Subscribe to configuration events (for LiveView)"
  @spec subscribe_configuration() :: :ok | {:error, term()}
  def subscribe_configuration do
    Phoenix.PubSub.subscribe(Trenino.PubSub, @config_topic)
  end

  @doc "Subscribe to input value updates for a specific port"
  @spec subscribe_input_values(String.t()) :: :ok | {:error, term()}
  def subscribe_input_values(port) do
    # Ensure ConfigurationManager is listening to serial messages for this port
    GenServer.cast(__MODULE__, {:ensure_port_subscription, port})
    Phoenix.PubSub.subscribe(Trenino.PubSub, "#{@input_values_topic}:#{port}")
  end

  @doc "Subscribe to failed input chip changes for a port (`{:i2c_module_status, port, failed_map}`)"
  @spec subscribe_i2c_status(String.t()) :: :ok | {:error, term()}
  def subscribe_i2c_status(port) do
    GenServer.cast(__MODULE__, {:ensure_port_subscription, port})
    Phoenix.PubSub.subscribe(Trenino.PubSub, "#{@i2c_status_topic}:#{port}")
  end

  @doc "Input chips currently reported failed on a port, keyed by I2C address"
  @spec failed_i2c_modules(String.t()) :: %{integer() => i2c_status()}
  def failed_i2c_modules(port) do
    GenServer.call(__MODULE__, {:failed_i2c_modules, port})
  end

  @doc "Get current input values for a port"
  @spec get_input_values(String.t()) :: %{integer() => integer()}
  def get_input_values(port) do
    GenServer.call(__MODULE__, {:get_input_values, port})
  end

  @doc "Convert a config_id to port by looking up connected devices"
  @spec config_id_to_port(integer()) :: String.t() | nil
  def config_id_to_port(config_id) do
    Connection.connected_devices()
    |> Enum.find(&(&1.device_config_id == config_id))
    |> case do
      nil -> nil
      device -> device.port
    end
  end

  @doc "Convert a port to config_id by looking up connected devices"
  @spec port_to_config_id(String.t()) :: integer() | nil
  def port_to_config_id(port) do
    Connection.connected_devices()
    |> Enum.find(&(&1.port == port))
    |> case do
      nil -> nil
      device -> device.device_config_id
    end
  end

  # Server callbacks

  @impl true
  def init(%State{} = state) do
    # Subscribe to device updates to track connections
    Connection.subscribe()
    {:ok, state}
  end

  @impl true
  def handle_call({:apply_configuration, port, device_id}, _from, %State{} = state) do
    # Subscribe to messages from this port if not already subscribed
    state = maybe_subscribe_to_port(state, port)

    case do_apply_configuration(port, device_id, state) do
      {:ok, config_id, new_state} ->
        {:reply, {:ok, config_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_input_values, port}, _from, %State{} = state) do
    values = Map.get(state.input_values, port, %{})
    {:reply, values, state}
  end

  @impl true
  def handle_call({:failed_i2c_modules, port}, _from, %State{} = state) do
    {:reply, Map.get(state.failed_i2c, port, %{}), state}
  end

  @impl true
  def handle_cast({:ensure_port_subscription, port}, %State{} = state) do
    {:noreply, maybe_subscribe_to_port(state, port)}
  end

  @impl true
  def handle_info({:devices_updated, devices}, %State{} = state) do
    # Clear input values for disconnected devices
    connected_ports =
      devices
      |> Enum.filter(&(Map.get(&1, :status, :connected) == :connected))
      |> MapSet.new(& &1.port)

    new_input_values =
      Map.filter(state.input_values, fn {port, _} ->
        MapSet.member?(connected_ports, port)
      end)

    {active, disconnected} =
      Enum.split_with(state.in_flight, fn {_, info} ->
        MapSet.member?(connected_ports, info.port)
      end)

    Enum.each(disconnected, fn {_, info} ->
      Process.cancel_timer(info.timer_ref)

      StepperManager.finish_deployment(
        info.port,
        Map.get(info, :stepper_token),
        {:error, :disconnected}
      )

      broadcast_config_event({:configuration_failed, info.port, info.device_id, :disconnected})
    end)

    state =
      state.failed_i2c
      |> Map.keys()
      |> Enum.reject(&MapSet.member?(connected_ports, &1))
      |> Enum.reduce(state, &set_failed_i2c(&2, &1, %{}))

    {:noreply, %{state | input_values: new_input_values, in_flight: Map.new(active)}}
  end

  @impl true
  def handle_info(
        {:serial_message, port, %ConfigurationStored{config_id: config_id}},
        %State{} = state
      ) do
    case Map.pop(state.in_flight, config_id) do
      {nil, _} ->
        {:noreply, state}

      {%{port: ^port, timer_ref: timer_ref, device_id: device_id} = info, new_in_flight} ->
        Process.cancel_timer(timer_ref)

        case Hardware.confirm_configuration(device_id, config_id, Map.get(info, :fingerprint)) do
          {:ok, device} ->
            Logger.info("Configuration #{config_id} successfully stored on device")
            # Update the device connection's config_id to match
            Connection.update_device_config_id(port, config_id)
            StepperManager.finish_deployment(port, Map.get(info, :stepper_token), :ok)
            broadcast_config_event({:configuration_applied, port, device, config_id})
            {:noreply, %{state | in_flight: new_in_flight}}

          {:error, reason} ->
            StepperManager.finish_deployment(
              port,
              Map.get(info, :stepper_token),
              {:error, reason}
            )

            Logger.error("Failed to update device with config_id: #{inspect(reason)}")
            broadcast_config_event({:configuration_failed, port, device_id, reason})
            {:noreply, %{state | in_flight: new_in_flight}}
        end

      {_wrong_port, _} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(
        {:serial_message, port, %ConfigurationError{config_id: config_id}},
        %State{} = state
      ) do
    case Map.pop(state.in_flight, config_id) do
      {nil, _} ->
        {:noreply, state}

      {%{port: ^port, timer_ref: timer_ref, device_id: device_id} = info, new_in_flight} ->
        Process.cancel_timer(timer_ref)
        Logger.error("Configuration #{config_id} rejected by device")

        StepperManager.finish_deployment(
          port,
          Map.get(info, :stepper_token),
          {:error, :device_rejected}
        )

        broadcast_config_event({:configuration_failed, port, device_id, :device_rejected})
        {:noreply, %{state | in_flight: new_in_flight}}

      {_wrong_port, _} ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info({:serial_message, port, %InputValue{pin: pin, value: value}}, %State{} = state) do
    port_values = Map.get(state.input_values, port, %{})
    updated_values = Map.put(port_values, pin, value)
    new_input_values = Map.put(state.input_values, port, updated_values)

    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      "#{@input_values_topic}:#{port}",
      {:input_value_updated, port, pin, value}
    )

    {:noreply, %{state | input_values: new_input_values}}
  end

  @impl true
  def handle_info(
        {:serial_message, port, %ModuleError{i2c_address: addr, error_code: code}},
        %State{} = state
      ) do
    Logger.warning(
      "ModuleError: I2C module at #{I2cModule.format_i2c_address(addr)} #{ModuleError.describe(code)} (error_code=#{code})"
    )

    {:noreply, track_module_error(state, port, addr, code)}
  end

  @impl true
  def handle_info({:serial_message, _port, _other_message}, %State{} = state) do
    {:noreply, state}
  end

  @impl true
  def handle_info({:config_timeout, config_id}, %State{} = state) do
    case Map.pop(state.in_flight, config_id) do
      {nil, _} ->
        {:noreply, state}

      {%{port: port, device_id: device_id} = info, new_in_flight} ->
        Logger.error("Configuration #{config_id} timed out")
        StepperManager.finish_deployment(port, Map.get(info, :stepper_token), {:error, :timeout})
        broadcast_config_event({:configuration_failed, port, device_id, :timeout})
        {:noreply, %{state | in_flight: new_in_flight}}
    end
  end

  @impl true
  def handle_info(:scan_complete, %State{} = state) do
    # Ignore scan_complete events - not relevant for configuration manager
    {:noreply, state}
  end

  # Private helpers

  defp track_module_error(%State{} = state, port, addr, code) do
    status = ModuleError.status(code)

    if status != nil and input_chip_address?(port, addr) do
      current = Map.get(state.failed_i2c, port, %{})

      updated =
        if status == :recovered,
          do: Map.delete(current, addr),
          else: Map.put(current, addr, status)

      set_failed_i2c(state, port, updated)
    else
      state
    end
  end

  defp input_chip_address?(port, addr) do
    with %{device_config_id: config_id} when is_integer(config_id) <-
           Enum.find(Connection.connected_devices(), &(&1.port == port)),
         {:ok, device} <- Hardware.get_device_by_config_id(config_id) do
      device.id
      |> Hardware.list_i2c_modules()
      |> Enum.any?(&(&1.i2c_address == addr and I2cModule.input_chip?(&1)))
    else
      _ -> false
    end
  end

  # Stores the port's failures and broadcasts only when they changed.
  defp set_failed_i2c(%State{} = state, port, failed) do
    if Map.get(state.failed_i2c, port, %{}) == failed do
      state
    else
      Phoenix.PubSub.broadcast(
        Trenino.PubSub,
        "#{@i2c_status_topic}:#{port}",
        {:i2c_module_status, port, failed}
      )

      failed_i2c =
        if failed == %{},
          do: Map.delete(state.failed_i2c, port),
          else: Map.put(state.failed_i2c, port, failed)

      %{state | failed_i2c: failed_i2c}
    end
  end

  defp maybe_subscribe_to_port(%State{} = state, port) do
    if MapSet.member?(state.subscribed_ports, port) do
      state
    else
      Logger.debug("ConfigurationManager subscribing to serial messages for port: #{port}")
      Connection.subscribe_messages(port)
      %{state | subscribed_ports: MapSet.put(state.subscribed_ports, port)}
    end
  end

  defp do_apply_configuration(port, device_id, %State{} = state) do
    with false <- Enum.any?(state.in_flight, fn {_, info} -> info.port == port end),
         {:ok, device} <- Hardware.get_device(device_id),
         {:ok, inputs} <- Hardware.list_inputs(device_id),
         {:ok, matrices} <- Hardware.list_matrices(device_id),
         i2c_modules = Hardware.list_i2c_modules(device_id),
         :ok <- validate_configuration(port, device_id, inputs, matrices, i2c_modules),
         config_id = device.config_id,
         {:ok, token} <- StepperManager.begin_deployment(port) do
      case send_configuration_messages(port, config_id, inputs, matrices, i2c_modules) do
        :ok ->
          timer_ref = Process.send_after(self(), {:config_timeout, config_id}, @config_timeout_ms)

          in_flight_info = %{
            port: port,
            timer_ref: timer_ref,
            device_id: device_id,
            stepper_token: token,
            fingerprint:
              Hardware.config_fingerprint(
                inputs,
                matrices,
                i2c_modules,
                Hardware.list_stepper_axes(device_id)
              )
          }

          new_in_flight = Map.put(state.in_flight, config_id, in_flight_info)
          state = set_failed_i2c(state, port, %{})
          {:ok, config_id, %{state | in_flight: new_in_flight}}

        error ->
          StepperManager.finish_deployment(port, token, error)
          error
      end
    else
      true -> {:error, :busy}
      error -> error
    end
  end

  @max_modules 8
  @stepper_min_version "3.1.0"
  @chip_min_version "3.2.0"

  # Stepper axes need firmware 3.1+ and input chips 3.2+. Without these checks an older
  # device would accept the configuration while ignoring or mishandling the new parts.
  defp validate_configuration(port, device_id, inputs, matrices, i2c_modules) do
    axes = Hardware.list_stepper_axes(device_id)

    cond do
      axes == [] and inputs == [] and matrices == [] and i2c_modules == [] ->
        {:error, :no_inputs}

      length(inputs) + length(matrices) + length(i2c_modules) > @max_modules ->
        {:error, :too_many_modules}

      true ->
        required =
          [
            if(axes != [], do: @stepper_min_version),
            if(Enum.any?(i2c_modules, &I2cModule.input_chip?/1), do: @chip_min_version)
          ]
          |> Enum.reject(&is_nil/1)
          |> Enum.max(Version, fn -> nil end)

        validate_firmware(port, required)
    end
  end

  defp validate_firmware(_port, nil), do: :ok

  defp validate_firmware(port, minimum) do
    conn = Enum.find(Connection.connected_devices(), &(&1.port == port))

    with %{device_version: version} when is_binary(version) <- conn,
         {:ok, parsed} <- Version.parse(version),
         true <- Version.compare(parsed, minimum) != :lt and parsed.pre == [] do
      :ok
    else
      _ -> {:error, :firmware_update_required}
    end
  end

  defp send_configuration_messages(port, config_id, [], [], []) do
    Connection.send_message(port, %Configure{
      config_id: config_id,
      total_parts: 0,
      part_number: 0,
      input_type: :empty
    })
  end

  defp send_configuration_messages(port, config_id, inputs, matrices, i2c_modules) do
    config_parts = build_config_parts(inputs, matrices, i2c_modules)
    total_parts = length(config_parts)

    Logger.info(
      "Sending configuration to device on #{port}: config_id=#{config_id}, total_parts=#{total_parts}"
    )

    config_parts
    |> Enum.with_index()
    |> Enum.reduce_while(:ok, fn {part, index}, :ok ->
      message = build_configure_message(config_id, total_parts, index, part)
      Logger.info("  [#{index + 1}/#{total_parts}] #{inspect(message)}")

      case Connection.send_message(port, message) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp build_config_parts(inputs, matrices, i2c_modules) do
    input_parts = Enum.map(inputs, &{:input, &1})
    matrix_parts = Enum.map(matrices, &{:matrix, &1})
    i2c_parts = Enum.map(i2c_modules, &{:i2c_module, &1})
    input_parts ++ matrix_parts ++ i2c_parts
  end

  defp build_configure_message(
         config_id,
         total_parts,
         part_number,
         {:input, %Input{input_type: :analog} = input}
       ) do
    %Configure{
      config_id: config_id,
      total_parts: total_parts,
      part_number: part_number,
      input_type: :analog,
      pin: input.pin,
      sensitivity: input.sensitivity
    }
  end

  defp build_configure_message(
         config_id,
         total_parts,
         part_number,
         {:input, %Input{input_type: :button} = input}
       ) do
    %Configure{
      config_id: config_id,
      total_parts: total_parts,
      part_number: part_number,
      input_type: :button,
      pin: input.pin,
      debounce: input.debounce
    }
  end

  defp build_configure_message(
         config_id,
         total_parts,
         part_number,
         {:matrix, matrix}
       ) do
    # Get row and col pins from the matrix association
    row_pins =
      matrix.row_pins
      |> Enum.sort_by(& &1.position)
      |> Enum.map(& &1.pin)

    col_pins =
      matrix.col_pins
      |> Enum.sort_by(& &1.position)
      |> Enum.map(& &1.pin)

    %Configure{
      config_id: config_id,
      total_parts: total_parts,
      part_number: part_number,
      input_type: :matrix,
      row_pins: row_pins,
      col_pins: col_pins
    }
  end

  defp build_configure_message(
         config_id,
         total_parts,
         part_number,
         {:i2c_module, %I2cModule{module_chip: :ht16k33} = mod}
       ) do
    %Configure{
      config_id: config_id,
      total_parts: total_parts,
      part_number: part_number,
      input_type: :ht16k33,
      i2c_address: mod.i2c_address,
      brightness: mod.params.brightness,
      num_digits: mod.params.num_digits
    }
  end

  defp build_configure_message(
         config_id,
         total_parts,
         part_number,
         {:i2c_module, %I2cModule{module_chip: :mcp23017} = mod}
       ) do
    p = mod.params

    %Configure{
      config_id: config_id,
      total_parts: total_parts,
      part_number: part_number,
      input_type: :mcp23017,
      i2c_address: mod.i2c_address,
      direct_base: p.direct_base,
      matrix_base: p.matrix_base,
      debounce: p.debounce,
      direct_mask: p.direct_mask,
      row_mask: p.row_mask,
      col_mask: p.col_mask
    }
  end

  defp build_configure_message(
         config_id,
         total_parts,
         part_number,
         {:i2c_module, %I2cModule{module_chip: :ads1115} = mod}
       ) do
    p = mod.params

    %Configure{
      config_id: config_id,
      total_parts: total_parts,
      part_number: part_number,
      input_type: :ads1115,
      i2c_address: mod.i2c_address,
      pin_base: p.pin_base,
      channel_mask: p.channel_mask,
      gain: p.gain,
      ref_channel: p.ref_channel,
      sensitivities: Hardware.chip_sensitivities(mod)
    }
  end

  defp broadcast_config_event(event) do
    Phoenix.PubSub.broadcast(Trenino.PubSub, @config_topic, event)
  end
end
