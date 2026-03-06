defmodule Trenino.Hardware.InputDetectionSession do
  @moduledoc """
  Manages a short-lived session for detecting which hardware input a user interacts with.

  On start, the session builds a lookup table of `{port, pin} → input_info` from
  the database, subscribes to hardware input PubSub topics for all connected device
  ports, and waits for a matching event.

  The first event received for a pin establishes a baseline value. Subsequent events
  that show a significant change trigger detection and notify the caller.

  Detection thresholds:
  - Button: any value change (0→1 or 1→0)
  - Analog: value changes by more than 50 raw ADC units

  ## Usage

      {:ok, pid} = InputDetectionSession.start(self(), input_type: :button, timeout_ms: 60_000)

      receive do
        {:input_detected, %{input_id: _, pin: _, input_type: _, name: _, device_id: _, device_name: _, value: _}} ->
          # Input was detected
        {:detection_timeout} ->
          # No input detected within timeout
      end

  """

  use GenServer
  require Logger

  alias Trenino.Hardware
  alias Trenino.Serial.Connection

  @analog_threshold 50
  @default_timeout_ms 60_000
  @input_values_topic "hardware:input_values"
  @test_port "test_port"

  defmodule State do
    @moduledoc false

    @type input_info :: %{
            input_id: integer(),
            pin: integer(),
            input_type: :analog | :button | :bldc_lever,
            name: String.t() | nil,
            device_id: integer(),
            device_name: String.t()
          }

    @type t :: %__MODULE__{
            callback_pid: pid(),
            input_type: :button | :analog | :any,
            pin_lookup: %{{String.t(), integer()} => input_info()},
            baselines: %{{String.t(), integer()} => integer()},
            timeout_timer: reference() | nil
          }

    defstruct [
      :callback_pid,
      :input_type,
      :pin_lookup,
      :baselines,
      :timeout_timer
    ]
  end

  # Client API

  @doc """
  Start a hardware input detection session.

  ## Options

    * `:input_type` - Filter which inputs to detect: `:button`, `:analog`, or `:any` (default: `:any`)
    * `:timeout_ms` - Milliseconds before sending `{:detection_timeout}` to callback_pid (default: #{@default_timeout_ms})

  Returns `{:ok, pid}` or `{:error, reason}`.
  """
  @spec start(pid(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start(callback_pid, opts \\ []) when is_pid(callback_pid) do
    GenServer.start(__MODULE__, {callback_pid, opts})
  end

  @doc """
  Stop the detection session.
  """
  @spec stop(pid()) :: :ok
  def stop(pid) do
    GenServer.stop(pid, :normal)
  end

  # Server Callbacks

  @impl true
  def init({callback_pid, opts}) do
    Process.monitor(callback_pid)

    input_type = Keyword.get(opts, :input_type, :any)
    timeout_ms = Keyword.get(opts, :timeout_ms, @default_timeout_ms)

    connected = Connection.connected_devices()
    pin_lookup = build_pin_lookup(connected)

    subscribe_to_ports(connected)

    timeout_timer = Process.send_after(self(), :timeout, timeout_ms)

    state = %State{
      callback_pid: callback_pid,
      input_type: input_type,
      pin_lookup: pin_lookup,
      baselines: %{},
      timeout_timer: timeout_timer
    }

    Logger.info(
      "[InputDetectionSession] Started with input_type=#{input_type}, #{map_size(pin_lookup)} pins in lookup"
    )

    {:ok, state}
  end

  @impl true
  def handle_info(
        {:input_value_updated, port, pin, value},
        %State{} = state
      ) do
    key = {port, pin}

    case Map.get(state.pin_lookup, key) do
      nil ->
        # Pin not found in any device configuration — ignore
        {:noreply, state}

      input_info ->
        handle_input_event(key, input_info, value, state)
    end
  end

  def handle_info(:timeout, %State{} = state) do
    Logger.info("[InputDetectionSession] Timeout - no input detected")
    send(state.callback_pid, {:detection_timeout})
    {:stop, :normal, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, %State{} = state) do
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, %State{timeout_timer: timer}) do
    if timer, do: Process.cancel_timer(timer)
    :ok
  end

  # Private Functions

  defp handle_input_event(key, input_info, value, %State{} = state) do
    case Map.get(state.baselines, key) do
      nil ->
        # First event for this pin — record as baseline
        {:noreply, %{state | baselines: Map.put(state.baselines, key, value)}}

      baseline ->
        if significant_change?(input_info.input_type, state.input_type, baseline, value) do
          detection = build_detection(input_info, value)
          Logger.info("[InputDetectionSession] Detected input: #{inspect(detection)}")
          send(state.callback_pid, {:input_detected, detection})
          {:stop, :normal, state}
        else
          {:noreply, state}
        end
    end
  end

  defp significant_change?(input_type, filter, baseline, value) do
    type_matches?(input_type, filter) and value_changed?(input_type, baseline, value)
  end

  defp type_matches?(_input_type, :any), do: true
  defp type_matches?(input_type, filter), do: input_type == filter

  defp value_changed?(:button, baseline, value), do: value != baseline
  defp value_changed?(:analog, baseline, value), do: abs(value - baseline) > @analog_threshold
  defp value_changed?(:bldc_lever, baseline, value), do: abs(value - baseline) > @analog_threshold

  defp build_detection(input_info, value) do
    Map.put(input_info, :value, value)
  end

  defp build_pin_lookup(connected) do
    devices = Hardware.list_configurations(preload: [:inputs])

    # Build a map of config_id → port for connected devices
    config_id_to_port =
      Map.new(connected, fn device_conn ->
        {device_conn.device_config_id, device_conn.port}
      end)

    Enum.reduce(devices, %{}, fn device, acc ->
      ports_for_device = ports_for_device(device.config_id, config_id_to_port)

      Enum.reduce(device.inputs, acc, fn input, inner_acc ->
        add_input_to_lookup(inner_acc, device, input, ports_for_device)
      end)
    end)
  end

  # Always include inputs under test_port for test support
  # Also include under the real port if the device is connected
  defp ports_for_device(config_id, config_id_to_port) do
    case Map.get(config_id_to_port, config_id) do
      nil -> [@test_port]
      port -> [port, @test_port]
    end
  end

  defp add_input_to_lookup(acc, device, input, ports) do
    input_info = %{
      input_id: input.id,
      pin: input.pin,
      input_type: input.input_type,
      name: input.name,
      device_id: device.id,
      device_name: device.name
    }

    Enum.reduce(ports, acc, fn port, port_acc ->
      Map.put(port_acc, {port, input.pin}, input_info)
    end)
  end

  defp subscribe_to_ports(connected) do
    # Always subscribe to the test port for testing purposes
    Phoenix.PubSub.subscribe(Trenino.PubSub, "#{@input_values_topic}:#{@test_port}")

    # Subscribe to each connected device's port
    Enum.each(connected, fn device_conn ->
      Phoenix.PubSub.subscribe(
        Trenino.PubSub,
        "#{@input_values_topic}:#{device_conn.port}"
      )
    end)
  end
end
