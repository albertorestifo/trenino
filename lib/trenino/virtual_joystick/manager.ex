defmodule Trenino.VirtualJoystick.Manager do
  @moduledoc false

  use GenServer

  alias Trenino.VirtualJoystick.{Bridge, Configurator, Mapper, Platform}

  @topic "virtual_joystick"
  defmodule State do
    @moduledoc false

    @type status ::
            :unsupported
            | :off
            | :enabling
            | :active
            | :disabling
            | :needs_setup
            | :needs_cleanup
            | :degraded
            | :error

    @type t :: %__MODULE__{
            requested?: boolean(),
            status: status(),
            reason: term(),
            mappings: map(),
            subscribed_ports: MapSet.t(String.t()),
            connected_ports: MapSet.t(String.t()),
            last_raw_values: map(),
            bridge_pid: pid() | nil,
            axis_range: {integer(), integer()} | nil,
            retry_attempt: non_neg_integer(),
            retry_timer: reference() | nil,
            transition_ref: reference() | nil,
            transition_action: atom() | nil,
            created_during_transition?: boolean(),
            platform: module(),
            context: module(),
            configurator: module(),
            bridge: module(),
            serial: module(),
            inputs: module(),
            mapper: module(),
            task_supervisor: atom() | pid(),
            retry_delays: [non_neg_integer()]
          }

    defstruct requested?: false,
              status: :off,
              reason: nil,
              mappings: %{},
              subscribed_ports: MapSet.new(),
              connected_ports: MapSet.new(),
              last_raw_values: %{},
              bridge_pid: nil,
              axis_range: nil,
              retry_attempt: 0,
              retry_timer: nil,
              transition_ref: nil,
              transition_action: nil,
              created_during_transition?: false,
              platform: Platform,
              context: Trenino.VirtualJoystick,
              configurator: Configurator,
              bridge: Bridge,
              serial: Trenino.Serial.Connection,
              inputs: Trenino.Hardware.ConfigurationManager,
              mapper: Mapper,
              task_supervisor: Trenino.TaskSupervisor,
              retry_delays: [250, 500, 1_000, 2_000, 4_000]
  end

  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    server_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, opts, server_opts)
  end

  def status(server \\ __MODULE__), do: GenServer.call(server, :status)
  def status_details(server \\ __MODULE__), do: GenServer.call(server, :status_details)
  def enable(server \\ __MODULE__), do: GenServer.call(server, :enable)
  def disable(server \\ __MODULE__), do: GenServer.call(server, :disable)
  def retry(server \\ __MODULE__), do: GenServer.call(server, :retry)
  def remove_leftover(server \\ __MODULE__), do: GenServer.call(server, :remove_leftover)
  def repair(server \\ __MODULE__), do: GenServer.call(server, :repair)

  def reload_mappings(server \\ __MODULE__) do
    if process_alive?(server), do: GenServer.cast(server, :reload_mappings)
    :ok
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    state =
      Enum.reduce(
        [
          :platform,
          :context,
          :configurator,
          :bridge,
          :serial,
          :inputs,
          :mapper,
          :task_supervisor,
          :retry_delays
        ],
        %State{},
        fn key, state ->
          case Keyword.fetch(opts, key) do
            {:ok, value} -> Map.put(state, key, value)
            :error -> state
          end
        end
      )

    configuration = state.context.get_configuration()
    state = %{state | requested?: configuration.enabled}
    :ok = state.serial.subscribe()
    state = reload_runtime_mappings(state)

    if state.platform.windows?() do
      {:ok, reconcile_startup(state)}
    else
      {:ok, %{state | status: :unsupported}}
    end
  end

  @impl true
  def handle_call(:status, _from, state), do: {:reply, state.status, state}

  def handle_call(:status_details, _from, state),
    do: {:reply, %{status: state.status, reason: state.reason}, state}

  def handle_call(command, _from, %State{status: status} = state)
      when command in [:enable, :disable, :retry, :remove_leftover] and
             status in [:enabling, :disabling] do
    {:reply, {:error, :transition_in_progress}, state}
  end

  def handle_call(:enable, _from, %State{status: :unsupported} = state),
    do: {:reply, {:error, :unsupported}, state}

  def handle_call(:enable, _from, %State{status: :active} = state),
    do: {:reply, :ok, state}

  def handle_call(:enable, _from, state) do
    {:reply, :ok, begin_configurator(state, :enable, :enabling, & &1.configurator.create())}
  end

  def handle_call(:disable, _from, %State{status: :off} = state),
    do: {:reply, :ok, state}

  def handle_call(:disable, _from, %State{status: :unsupported} = state),
    do: {:reply, {:error, :unsupported}, state}

  def handle_call(:disable, _from, state) do
    state = state |> cancel_retry() |> stop_bridge_safely()
    {:reply, :ok, begin_configurator(state, :disable, :disabling, & &1.configurator.delete())}
  end

  def handle_call(:remove_leftover, _from, %State{status: :needs_cleanup} = state) do
    state = state |> cancel_retry() |> stop_bridge_safely()
    {:reply, :ok, begin_configurator(state, :cleanup, :disabling, & &1.configurator.delete())}
  end

  def handle_call(:remove_leftover, _from, state),
    do: {:reply, {:error, :invalid_state}, state}

  def handle_call(:retry, _from, %State{status: :needs_setup} = state) do
    {:reply, :ok, begin_configurator(state, :enable, :enabling, & &1.configurator.create())}
  end

  def handle_call(:retry, _from, %State{status: status} = state)
      when status in [:degraded, :error] do
    state = state |> cancel_retry() |> Map.put(:retry_attempt, 0)
    {:reply, :ok, retry_bridge_now(state)}
  end

  def handle_call(:retry, _from, state), do: {:reply, {:error, :invalid_state}, state}

  def handle_call(:repair, _from, %State{status: :error} = state) do
    {:reply, :ok, reconcile_startup(state)}
  end

  def handle_call(:repair, _from, state), do: {:reply, {:error, :invalid_state}, state}

  @impl true
  def handle_cast(:reload_mappings, state), do: {:noreply, reload_runtime_mappings(state)}

  @impl true
  def handle_info({:manager_transition_result, ref, action, result}, state) do
    if ref == state.transition_ref and action == state.transition_action do
      {:noreply, finish_transition(state, action, result)}
    else
      {:noreply, state}
    end
  end

  def handle_info(
        {:virtual_joystick_bridge, {:ready, %{device: 1, axis_min: minimum, axis_max: maximum}}},
        state
      )
      when is_integer(minimum) and is_integer(maximum) and maximum > minimum do
    state = state |> cancel_retry() |> Map.put(:axis_range, {minimum, maximum})
    state = publish_current_state(state)

    state =
      if state.transition_action == :enable do
        {:ok, _} = state.context.confirm_enabled(true)
        %{state | requested?: true, transition_ref: nil, transition_action: nil}
      else
        state
      end

    {:noreply,
     state
     |> Map.put(:retry_attempt, 0)
     |> Map.put(:created_during_transition?, false)
     |> set_status(:active, nil)}
  end

  def handle_info({:virtual_joystick_bridge, {:ready, _bad_handshake}}, state) do
    {:noreply, bridge_start_failed(state, :invalid_axis_range)}
  end

  def handle_info({:virtual_joystick_bridge, {:exit, reason}}, state) do
    state = %{state | bridge_pid: nil, axis_range: nil}

    if state.requested? do
      {:noreply, state |> set_status(:degraded, reason) |> schedule_retry()}
    else
      {:noreply, state}
    end
  end

  def handle_info({:virtual_joystick_bridge, {:device_removed, device}}, state) do
    state = %{state | bridge_pid: nil, axis_range: nil}

    if state.requested? do
      {:noreply, state |> set_status(:degraded, {:device_removed, device}) |> schedule_retry()}
    else
      {:noreply, state}
    end
  end

  def handle_info({:virtual_joystick_bridge, {:error, reason}}, state),
    do: {:noreply, bridge_start_failed(state, reason)}

  def handle_info(:retry_bridge, %State{retry_timer: timer} = state) when not is_nil(timer) do
    {:noreply, retry_bridge_now(%{state | retry_timer: nil})}
  end

  def handle_info(:retry_bridge, state), do: {:noreply, state}

  def handle_info({:input_value_updated, port, pin, raw_value}, state) do
    key = {port, pin}
    state = %{state | last_raw_values: Map.put(state.last_raw_values, key, raw_value)}

    case state.mappings[key] do
      nil -> {:noreply, state}
      mapping -> {:noreply, maybe_send_mapping(state, mapping, raw_value)}
    end
  end

  def handle_info({:devices_updated, _devices}, state) do
    old_ports = state.connected_ports
    new_state = reload_runtime_mappings(state)
    disconnected = MapSet.difference(old_ports, new_state.connected_ports)

    state =
      if state.status == :active do
        Enum.reduce(disconnected, state, &send_safe_for_port(&2, &1))
      else
        state
      end

    {:noreply, %{new_state | status: state.status, reason: state.reason}}
  end

  def handle_info({:EXIT, pid, _reason}, %State{bridge_pid: pid} = state),
    do: {:noreply, state}

  def handle_info(_message, state), do: {:noreply, state}

  @impl true
  def terminate(_reason, state) do
    _ = stop_bridge_safely(state)
    :ok
  end

  defp reconcile_startup(state) do
    case {state.requested?, state.configurator.status()} do
      {false, :device_missing} ->
        set_status(state, :off, nil)

      {false, :compatible} ->
        set_status(state, :needs_cleanup, :leftover_device)

      {true, :device_missing} ->
        set_status(state, :needs_setup, :device_missing)

      {true, :compatible} ->
        state |> set_status(:degraded, nil) |> start_bridge()

      {_requested, status} when status in [:incompatible, :busy, :driver_missing] ->
        set_status(state, :error, status)
    end
  end

  defp begin_configurator(state, action, status, operation) do
    ref = make_ref()
    owner = self()
    configurator = state.configurator

    {:ok, _pid} =
      Task.Supervisor.start_child(state.task_supervisor, fn ->
        result = operation.(%{configurator: configurator})
        send(owner, {:manager_transition_result, ref, action, result})
      end)

    state
    |> cancel_retry()
    |> Map.put(:transition_ref, ref)
    |> Map.put(:transition_action, action)
    |> set_status(status, nil)
  end

  defp finish_transition(state, :enable, :ok) do
    state
    |> Map.put(:created_during_transition?, true)
    |> start_bridge()
  end

  defp finish_transition(state, :enable, {:error, :uac_cancelled}) do
    state
    |> clear_transition()
    |> set_status(if(state.requested?, do: :needs_setup, else: :off), :uac_cancelled)
  end

  defp finish_transition(state, :enable, {:error, reason}) do
    state |> clear_transition() |> set_status(enable_failure_status(state, reason), reason)
  end

  defp finish_transition(state, action, :ok) when action in [:disable, :cleanup] do
    state = clear_transition(state)

    state =
      if action == :disable and state.requested? do
        {:ok, _} = state.context.confirm_enabled(false)
        %{state | requested?: false}
      else
        state
      end

    set_status(state, :off, nil)
  end

  defp finish_transition(state, :disable, {:error, :uac_cancelled}) do
    state = clear_transition(state)

    if state.requested? and state.configurator.status() == :compatible do
      state
      |> set_status(:degraded, :uac_cancelled)
      |> start_bridge()
    else
      set_status(state, :needs_cleanup, :uac_cancelled)
    end
  end

  defp finish_transition(state, action, {:error, reason}) when action in [:disable, :cleanup] do
    state |> clear_transition() |> set_status(:needs_cleanup, reason)
  end

  defp enable_failure_status(state, _reason) do
    if state.configurator.status() == :compatible, do: :needs_cleanup, else: :needs_setup
  end

  defp clear_transition(state),
    do: %{state | transition_ref: nil, transition_action: nil, created_during_transition?: false}

  defp start_bridge(state) do
    case state.bridge.start_link(owner: self()) do
      {:ok, pid} -> %{state | bridge_pid: pid, axis_range: nil}
      {:error, reason} -> bridge_start_failed(state, reason)
    end
  end

  defp bridge_start_failed(%State{transition_action: :enable} = state, reason) do
    state
    |> Map.put(:bridge_pid, nil)
    |> clear_transition()
    |> set_status(:needs_cleanup, reason)
  end

  defp bridge_start_failed(state, reason) do
    state = %{state | bridge_pid: nil, axis_range: nil}

    if state.requested? do
      state |> set_status(:degraded, reason) |> schedule_retry()
    else
      set_status(state, :error, reason)
    end
  end

  defp schedule_retry(state) do
    if state.requested? and state.configurator.status() == :compatible do
      case Enum.at(state.retry_delays, state.retry_attempt) do
        nil ->
          set_status(%{state | retry_timer: nil}, :error, state.reason)

        delay ->
          timer = Process.send_after(self(), :retry_bridge, delay)
          %{state | retry_timer: timer, retry_attempt: state.retry_attempt + 1}
      end
    else
      set_status(state, :error, state.configurator.status())
    end
  end

  defp retry_bridge_now(state) do
    if state.requested? and state.configurator.status() == :compatible do
      start_bridge(state)
    else
      set_status(state, :error, state.configurator.status())
    end
  end

  defp cancel_retry(%State{retry_timer: nil} = state), do: state

  defp cancel_retry(state) do
    Process.cancel_timer(state.retry_timer)
    %{state | retry_timer: nil}
  end

  defp reload_runtime_mappings(state) do
    devices = state.serial.list_devices()

    ports_by_config =
      devices
      |> Enum.filter(&(&1.status == :connected and not is_nil(&1.device_config_id)))
      |> Map.new(&{&1.device_config_id, &1.port})

    connected_ports = MapSet.new(Map.values(ports_by_config))

    mappings =
      state.context.list_mappings()
      |> Enum.reduce(%{}, fn mapping, result ->
        with input when not is_nil(input) <- mapping.input,
             device when not is_nil(device) <- input.device,
             port when not is_nil(port) <- ports_by_config[device.config_id] do
          Map.put(result, {port, input.pin}, mapping)
        else
          _ -> result
        end
      end)

    new_ports = MapSet.difference(connected_ports, state.subscribed_ports)

    {last_raw_values, subscribed_ports} =
      Enum.reduce(new_ports, {state.last_raw_values, state.subscribed_ports}, fn port,
                                                                                 {raw, subscribed} ->
        :ok = state.inputs.subscribe_input_values(port)

        raw =
          Enum.reduce(state.inputs.get_input_values(port), raw, fn {pin, value}, values ->
            Map.put(values, {port, pin}, value)
          end)

        {raw, MapSet.put(subscribed, port)}
      end)

    %{
      state
      | mappings: mappings,
        connected_ports: connected_ports,
        subscribed_ports: subscribed_ports,
        last_raw_values: last_raw_values
    }
  end

  defp publish_current_state(state) do
    Enum.reduce(state.mappings, state, fn {key, mapping}, current ->
      case Map.fetch(current.last_raw_values, key) do
        {:ok, raw} -> send_mapping(current, mapping, raw)
        :error -> send_safe_mapping(current, mapping)
      end
    end)
  end

  defp maybe_send_mapping(%State{status: :active} = state, mapping, raw),
    do: send_mapping(state, mapping, raw)

  defp maybe_send_mapping(state, _mapping, _raw), do: state

  defp send_mapping(state, %{target_type: :axis} = mapping, raw) do
    case state.mapper.axis_value(
           raw,
           mapping.input.calibration,
           mapping.inverted,
           state.axis_range
         ) do
      {:ok, value} ->
        _ = state.bridge.set_axis(state.bridge_pid, mapping.axis, value)
        state

      {:error, _reason} ->
        state
    end
  end

  defp send_mapping(state, %{target_type: :button} = mapping, raw) do
    _ = state.bridge.set_button(state.bridge_pid, mapping.button, raw != 0)
    state
  end

  defp send_safe_for_port(state, port) do
    state.mappings
    |> Enum.filter(fn {{mapping_port, _pin}, _mapping} -> mapping_port == port end)
    |> Enum.reduce(state, fn {_key, mapping}, current -> send_safe_mapping(current, mapping) end)
  end

  defp send_safe_mapping(state, %{target_type: :axis} = mapping) do
    {minimum, maximum} = state.axis_range
    _ = state.bridge.set_axis(state.bridge_pid, mapping.axis, round((minimum + maximum) / 2))
    state
  end

  defp send_safe_mapping(state, %{target_type: :button} = mapping) do
    _ = state.bridge.set_button(state.bridge_pid, mapping.button, false)
    state
  end

  defp stop_bridge_safely(%State{bridge_pid: nil} = state), do: state

  defp stop_bridge_safely(state) do
    _ = state.bridge.reset(state.bridge_pid)
    _ = state.bridge.shutdown(state.bridge_pid)
    %{state | bridge_pid: nil, axis_range: nil}
  end

  defp set_status(%State{status: status, reason: reason} = state, status, reason), do: state

  defp set_status(%State{status: status} = state, status, reason) do
    broadcast_details(status, reason)
    %{state | reason: reason}
  end

  defp set_status(state, status, reason) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      @topic,
      {:virtual_joystick_status_changed, status}
    )

    broadcast_details(status, reason)

    %{state | status: status, reason: reason}
  end

  defp broadcast_details(status, reason) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      @topic,
      {:virtual_joystick_status_details_changed, %{status: status, reason: reason}}
    )
  end

  defp process_alive?(server) when is_pid(server), do: Process.alive?(server)
  defp process_alive?(server) when is_atom(server), do: not is_nil(Process.whereis(server))
end
