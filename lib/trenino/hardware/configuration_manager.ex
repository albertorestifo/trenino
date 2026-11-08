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
  alias Trenino.Hardware.Gauge
  alias Trenino.Hardware.I2cModule
  alias Trenino.Hardware.Input
  alias Trenino.Serial.Connection

  alias Trenino.Serial.Protocol.ConfigurationError
  alias Trenino.Serial.Protocol.ConfigurationStored
  alias Trenino.Serial.Protocol.Configure
  alias Trenino.Serial.Protocol.InputValue
  alias Trenino.Serial.Protocol.ModuleError

  require Logger

  @config_timeout_ms 10_000
  # The firmware stores at most this many modules (MAX_MODULES in its config_manager.h).
  @max_modules 8
  # Module errors this soon after ConfigurationStored belong to that Apply.
  @module_error_window_ms 5_000
  @config_topic "hardware:configuration"
  @input_values_topic "hardware:input_values"

  defmodule State do
    @moduledoc false

    @type in_flight_info :: %{
            port: String.t(),
            timer_ref: reference(),
            device_id: integer()
          }

    @type t :: %__MODULE__{
            in_flight: %{integer() => in_flight_info()},
            input_values: %{String.t() => %{integer() => integer()}},
            subscribed_ports: MapSet.t(String.t()),
            applied_at: %{String.t() => integer()}
          }

    # applied_at: port => monotonic ms of its last ConfigurationStored, so module errors
    # that follow an Apply can be told apart from the ones repeated at every connect.
    defstruct in_flight: %{},
              input_values: %{},
              subscribed_ports: MapSet.new(),
              applied_at: %{}
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
      broadcast_config_event({:configuration_failed, info.port, info.device_id, :disconnected})
    end)

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
            broadcast_config_event({:configuration_applied, port, device, config_id})

            {:noreply,
             %{
               state
               | in_flight: new_in_flight,
                 applied_at: Map.put(state.applied_at, port, now_ms())
             }}

          {:error, reason} ->
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

      {%{port: ^port, timer_ref: timer_ref, device_id: device_id}, new_in_flight} ->
        Process.cancel_timer(timer_ref)
        Logger.error("Configuration #{config_id} rejected by device")
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

  # Firmware 3.3.0 reports a gauge that failed to start (a pin the board lacks, or no
  # room in the step timer) with address 0. The message carries no pin, so it can only
  # be reported per device. The firmware repeats boot-time errors at every connect, so
  # only the ones right after an Apply are broadcast; the rest are logged.
  @impl true
  def handle_info(
        {:serial_message, port, %ModuleError{i2c_address: 0, error_code: code}},
        %State{} = state
      ) do
    Logger.warning("ModuleError: a gauge on #{port} failed to start (error_code=#{code})")

    with {:ok, at} <- Map.fetch(state.applied_at, port),
         true <- now_ms() - at <= @module_error_window_ms do
      broadcast_config_event({:gauge_start_failed, port})
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(
        {:serial_message, _port, %ModuleError{i2c_address: addr, error_code: code}},
        %State{} = state
      ) do
    Logger.warning(
      "ModuleError: I2C module at #{I2cModule.format_i2c_address(addr)} failed init (error_code=#{code})"
    )

    {:noreply, state}
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

      {%{port: port, device_id: device_id}, new_in_flight} ->
        Logger.error("Configuration #{config_id} timed out")
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
         gauges = Hardware.list_gauges(device_id),
         {:ok, outputs} <- Hardware.list_outputs(device_id),
         parts = build_config_parts(inputs, matrices, i2c_modules, gauges),
         :ok <- validate_configuration(port, parts, gauges, outputs),
         :ok <- validate_gauge_pins(gauges, inputs, matrices, outputs),
         config_id = device.config_id,
         :ok <- send_configuration_messages(port, config_id, parts) do
      timer_ref = Process.send_after(self(), {:config_timeout, config_id}, @config_timeout_ms)

      in_flight_info = %{
        port: port,
        timer_ref: timer_ref,
        device_id: device_id,
        fingerprint: Hardware.config_fingerprint(inputs, matrices, i2c_modules, gauges)
      }

      new_in_flight = Map.put(state.in_flight, config_id, in_flight_info)
      {:ok, config_id, %{state | in_flight: new_in_flight}}
    else
      true -> {:error, :busy}
      error -> error
    end
  end

  # Gauges are configure parts, but they need firmware 3.3.0 (module type 7); older
  # firmware rejects the whole configuration. The empty Configure packet sent for an
  # outputs-only configuration (outputs need no device-side parts, but the device must
  # still learn the config_id) needs firmware 3.1.0.
  defp validate_configuration(_port, parts, _gauges, _outputs)
       when length(parts) > @max_modules,
       do: {:error, :too_many_modules}

  defp validate_configuration(port, parts, gauges, outputs) do
    case {gauges, parts, outputs} do
      {[], [], []} -> {:error, :no_inputs}
      {[], [], _outputs} -> validate_firmware_floor(port, "3.1.0")
      {[], _parts, _} -> :ok
      {_gauges, _, _} -> validate_firmware_floor(port, Hardware.gauge_firmware_version())
    end
  end

  # Gauge saves already refuse pins used by inputs, matrices or outputs, but those can be
  # added after the gauge. The firmware would reject the configuration (or ignore SetOutput
  # on the pin), so the clash is caught here with a clear reason.
  defp validate_gauge_pins([], _inputs, _matrices, _outputs), do: :ok

  defp validate_gauge_pins(gauges, inputs, matrices, outputs) do
    gauge_pins = MapSet.new(gauges, &Gauge.used_pins/1) |> Enum.concat() |> MapSet.new()

    other_pins =
      Enum.map(inputs, & &1.pin) ++
        Enum.map(outputs, & &1.pin) ++
        Enum.flat_map(
          matrices,
          &(Enum.map(&1.row_pins, fn p -> p.pin end) ++ Enum.map(&1.col_pins, fn p -> p.pin end))
        )

    if Enum.any?(other_pins, &MapSet.member?(gauge_pins, &1)),
      do: {:error, :gauge_pin_conflict},
      else: :ok
  end

  defp validate_firmware_floor(port, floor) do
    conn = Enum.find(Connection.connected_devices(), &(&1.port == port))

    with %{device_version: version} when is_binary(version) <- conn,
         {:ok, parsed} <- Version.parse(version),
         true <- Version.compare(parsed, floor) != :lt and parsed.pre == [] do
      :ok
    else
      _ -> {:error, :firmware_update_required}
    end
  end

  defp send_configuration_messages(port, config_id, []) do
    Connection.send_message(port, %Configure{
      config_id: config_id,
      total_parts: 0,
      part_number: 0,
      input_type: :empty
    })
  end

  defp send_configuration_messages(port, config_id, config_parts) do
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

  defp build_config_parts(inputs, matrices, i2c_modules, gauges) do
    input_parts = Enum.map(inputs, &{:input, &1})
    matrix_parts = Enum.map(matrices, &{:matrix, &1})
    i2c_parts = Enum.map(i2c_modules, &{:i2c_module, &1})
    gauge_parts = Enum.map(gauges, &{:gauge, &1})
    input_parts ++ matrix_parts ++ i2c_parts ++ gauge_parts
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

  defp build_configure_message(config_id, total_parts, part_number, {:gauge, %Gauge{} = gauge}) do
    %Configure{
      config_id: config_id,
      total_parts: total_parts,
      part_number: part_number,
      input_type: :gauge,
      driver: gauge.driver,
      pins: gauge.pins,
      travel: gauge.travel,
      max_speed: gauge.max_speed,
      acceleration: gauge.acceleration,
      reverse: gauge.reverse
    }
  end

  defp now_ms, do: System.monotonic_time(:millisecond)

  defp broadcast_config_event(event) do
    Phoenix.PubSub.broadcast(Trenino.PubSub, @config_topic, event)
  end
end
