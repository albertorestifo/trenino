defmodule Trenino.Train.LeverController do
  # Normalized hardware travel (0..1) that releases a lever held after a sweep.
  @resume_travel 0.03

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

  A value the simulator already received is not sent again. Notched levers snap
  to their own position after a write, so repeating a gate target on every jitter
  sample would pull the handle off the notch and let it snap back, over and over.

  ## Calibration sweeps

  `Trenino.Simulator.LeverAnalyzer.analyze/3` registers the control it sweeps
  with `sweep_started/1` and `sweep_finished/1`. While a sweep runs, hardware
  input for a lever bound to that control is dropped and any pending write or
  retry for it is cancelled, so analog noise cannot move the lever mid-sweep.

  After the sweep the lever stays held at the hardware position seen last. Its
  writes resume once the hardware lever moves at least `#{@resume_travel}` of its
  travel from there, so a stale hardware value is not pushed over the position
  the analyzer restored. If no sample was seen, the first one sets that baseline.
  """

  use GenServer
  require Logger

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Hardware.Input.Calibration
  alias Trenino.Hardware.InputNormalizer
  alias Trenino.Serial.Connection, as: SerialConnection
  alias Trenino.Simulator.Client, as: SimulatorClient
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train
  alias Trenino.Train.{LeverConfig, LeverInputBinding, LeverMapper}

  @retry_delays [200, 400, 800]

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
              binding: LeverInputBinding.t(),
              control_path: String.t() | nil
            }
          }

    @type pending_write :: {LeverConfig.t(), float(), Task.t() | nil}

    @type t :: %__MODULE__{
            active_train: Train.Train.t() | nil,
            input_lookup: input_lookup(),
            binding_lookup: binding_lookup(),
            subscribed_ports: MapSet.t(String.t()),
            pending: %{integer() => pending_write()},
            retries: %{
              integer() => %{
                attempts: non_neg_integer(),
                timer: reference() | nil,
                token: reference() | nil
              }
            },
            last_written: %{integer() => float()},
            sweeps: %{(control_path :: String.t()) => reference()},
            held: %{(lever_config_id :: integer()) => baseline :: float() | nil},
            positions: %{(lever_config_id :: integer()) => normalized :: float()}
          }

    defstruct active_train: nil,
              input_lookup: %{},
              binding_lookup: %{},
              subscribed_ports: MapSet.new(),
              pending: %{},
              retries: %{},
              last_written: %{},
              sweeps: %{},
              held: %{},
              positions: %{}
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

  @doc """
  Stops forwarding hardware input to the levers bound to `control_path` until
  `sweep_finished/1` is called or the calling process exits.

  `Trenino.Simulator.LeverAnalyzer` calls this while it holds the sweep lock.
  It is a no-op when the controller is not running.
  """
  @spec sweep_started(String.t()) :: :ok
  def sweep_started(control_path) when is_binary(control_path) do
    call_if_running({:sweep_started, control_path, self()})
  end

  @doc """
  Ends the sweep of `control_path`. Its levers stay held until the hardware
  lever moves; see the module docs.
  """
  @spec sweep_finished(String.t()) :: :ok
  def sweep_finished(control_path) when is_binary(control_path) do
    call_if_running({:sweep_finished, control_path})
  end

  # A sweep must not fail because the controller is restarting.
  defp call_if_running(message) do
    if Process.whereis(__MODULE__), do: GenServer.call(__MODULE__, message)
    :ok
  catch
    :exit, _reason -> :ok
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    # Subscribe to train detection
    Train.subscribe()
    SimulatorConnection.subscribe()

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

  def handle_call({:sweep_started, control_path, pid}, _from, %State{} = state) do
    state = end_sweep(state, control_path)
    ref = Process.monitor(pid)
    state = %{state | sweeps: Map.put(state.sweeps, control_path, ref)}
    {:reply, :ok, hold_levers(state, control_path)}
  end

  def handle_call({:sweep_finished, control_path}, _from, %State{} = state) do
    {:reply, :ok, end_sweep(state, control_path)}
  end

  @impl true
  def handle_cast(:reload_bindings, %State{active_train: nil} = state) do
    {:noreply, state}
  end

  # A rebind can point at an input that was added or calibrated after its device
  # connected, so the input lookup is rebuilt along with the bindings.
  def handle_cast(:reload_bindings, %State{active_train: train} = state) do
    {:noreply, state |> rebuild_input_lookup() |> load_bindings_for_train(train)}
  end

  # Train detection events
  @impl true
  def handle_info({:train_changed, nil}, %State{} = state) do
    Logger.info("[LeverController] Train deactivated, clearing bindings")
    state = cancel_pending(state)
    {:noreply, %{state | active_train: nil, binding_lookup: %{}, held: %{}, positions: %{}}}
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

  def handle_info(
        {:simulator_status_changed, %ConnectionState{status: :connected}},
        %State{} = state
      ) do
    state =
      Enum.reduce(state.pending, state, fn
        {id, {config, value, nil}}, acc -> start_write(clear_retry(acc, id), config, value)
        {id, _write}, acc -> clear_retry(acc, id)
      end)

    {:noreply, state}
  end

  def handle_info({:simulator_status_changed, %ConnectionState{}}, %State{} = state) do
    {:noreply, %{cancel_retry_timers(state) | last_written: %{}}}
  end

  def handle_info({:retry_write, id, token}, %State{} = state) do
    case {Map.get(state.retries, id), Map.get(state.pending, id)} do
      {%{token: ^token}, {config, value, nil}} ->
        state = put_in(state.retries[id].timer, nil)
        state = put_in(state.retries[id].token, nil)
        {:noreply, start_write(state, config, value)}

      _ ->
        {:noreply, state}
    end
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
    case Enum.find(state.sweeps, fn {_path, sweep_ref} -> sweep_ref == ref end) do
      {control_path, _ref} ->
        {:noreply, %{state | sweeps: Map.delete(state.sweeps, control_path)}}

      nil ->
        Logger.warning("[LeverController] Simulator write crashed: #{inspect(reason)}")
        {:noreply, finish_write(state, ref, :error)}
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

    # PubSub subscriptions outlive a device disconnect, so a port that comes
    # back must not be subscribed a second time.
    new_ports
    |> MapSet.difference(old_ports)
    |> Enum.each(&ConfigurationManager.subscribe_input_values/1)

    %{state | input_lookup: input_lookup, subscribed_ports: MapSet.union(old_ports, new_ports)}
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
    state = cancel_pending(state)
    bindings = Train.list_bindings_for_train(train.id)

    binding_lookup =
      bindings
      |> Enum.filter(& &1.enabled)
      |> Map.new(fn binding ->
        {binding.input_id,
         %{
           lever_config: binding.lever_config,
           binding: binding,
           control_path: control_path(binding.lever_config)
         }}
      end)

    # Recalibration reloads bindings right after the sweep, so holds survive it.
    lever_ids = Enum.map(binding_lookup, fn {_input_id, info} -> info.lever_config.id end)

    Logger.info(
      "[LeverController] Loaded #{map_size(binding_lookup)} enabled bindings for train #{train.name}"
    )

    %{
      state
      | active_train: train,
        binding_lookup: binding_lookup,
        pending: %{},
        held: Map.take(state.held, lever_ids),
        positions: Map.take(state.positions, lever_ids)
    }
  end

  defp control_path(%LeverConfig{value_endpoint: endpoint}) when is_binary(endpoint) do
    case String.split_at(endpoint, -byte_size(".InputValue")) do
      {path, ".InputValue"} -> path
      _ -> nil
    end
  end

  defp control_path(%LeverConfig{}), do: nil

  defp apply_input_update(%State{} = state, port, pin, raw_value) do
    case resolve_simulator_value(state, port, pin, raw_value) do
      {:ok, binding_info, normalized, sim_value} ->
        route_value(state, binding_info, normalized, sim_value)

      :skip ->
        state
    end
  end

  defp route_value(state, %{lever_config: config, control_path: path}, normalized, sim_value) do
    %LeverConfig{id: id} = config

    cond do
      # The baseline follows the hardware while the sweep runs.
      Map.has_key?(state.sweeps, path) ->
        %{state | held: Map.put(state.held, id, normalized)}

      Map.has_key?(state.held, id) ->
        release_if_moved(state, config, normalized, sim_value)

      true ->
        state
        |> Map.update!(:positions, &Map.put(&1, id, normalized))
        |> enqueue_value(config, sim_value)
    end
  end

  defp release_if_moved(state, %LeverConfig{id: id} = config, normalized, sim_value) do
    case Map.fetch!(state.held, id) do
      baseline when is_number(baseline) and abs(normalized - baseline) >= @resume_travel ->
        %{
          state
          | held: Map.delete(state.held, id),
            positions: Map.put(state.positions, id, normalized)
        }
        |> enqueue_value(config, sim_value)

      baseline when is_number(baseline) ->
        state

      nil ->
        %{state | held: Map.put(state.held, id, normalized)}
    end
  end

  # Cancels pending writes and retries for the swept levers and holds them at
  # their last known hardware position. An HTTP request already sent cannot be
  # recalled.
  defp hold_levers(%State{} = state, control_path) do
    state.binding_lookup
    |> Enum.filter(fn {_input_id, info} -> info.control_path == control_path end)
    |> Enum.reduce(state, fn {_input_id, %{lever_config: %LeverConfig{id: id}}}, acc ->
      case Map.get(acc.pending, id) do
        {_, _, %Task{} = task} -> Task.shutdown(task, :brutal_kill)
        _ -> :ok
      end

      acc = clear_retry(acc, id)

      %{
        acc
        | pending: Map.delete(acc.pending, id),
          last_written: Map.delete(acc.last_written, id),
          held: Map.put(acc.held, id, Map.get(acc.positions, id))
      }
    end)
  end

  defp end_sweep(%State{} = state, control_path) do
    case Map.pop(state.sweeps, control_path) do
      {nil, _sweeps} ->
        state

      {ref, sweeps} ->
        Process.demonitor(ref, [:flush])
        %{state | sweeps: sweeps}
    end
  end

  defp resolve_simulator_value(%State{active_train: nil}, _port, _pin, _raw_value), do: :skip

  defp resolve_simulator_value(%State{} = state, port, pin, raw_value) do
    with {:ok, input_info} <- Map.fetch(state.input_lookup, {port, pin}),
         {:ok, binding_info} <- Map.fetch(state.binding_lookup, input_info.input_id),
         {:ok, normalized} <-
           InputNormalizer.normalize(
             raw_value,
             input_info.calibration,
             LeverMapper.input_precision()
           ),
         {:ok, sim_value} <- LeverMapper.map_input(binding_info.lever_config, normalized) do
      {:ok, binding_info, normalized, sim_value}
    else
      :error -> :skip
      {:error, _reason} -> :skip
    end
  end

  # One in-flight write per lever. A newer sample replaces the pending value so
  # a slow simulator response cannot replay a FIFO of jitter.
  defp enqueue_value(%State{} = state, %LeverConfig{id: id} = lever_config, sim_value) do
    case {Map.get(state.pending, id), Map.get(state.retries, id)} do
      {{_, _, task}, %{timer: timer}} when is_reference(timer) ->
        put_in(state.pending[id], {lever_config, sim_value, task})

      {{_, _, %Task{} = task}, _} ->
        put_in(state.pending[id], {lever_config, sim_value, task})

      _ ->
        if Map.get(state.last_written, id) == sim_value do
          state
        else
          start_write(clear_retry(state, id), lever_config, sim_value)
        end
    end
  end

  defp start_write(%State{} = state, %LeverConfig{id: id} = lever_config, sim_value) do
    task =
      case simulator_client() do
        {:ok, client} ->
          Task.Supervisor.async_nolink(Trenino.TaskSupervisor, fn ->
            {send_to_simulator(client, lever_config, sim_value), id, sim_value}
          end)

        :error ->
          nil
      end

    put_in(state.pending[id], {lever_config, sim_value, task})
  end

  defp finish_write(%State{} = state, ref, {:ok, id, written}) do
    case Map.get(state.pending, id) do
      {%LeverConfig{}, latest, %Task{ref: ^ref}} when latest == written ->
        record_written(state, id, written)

      {%LeverConfig{} = lever_config, latest, %Task{ref: ^ref}} ->
        start_write(record_written(state, id, written), lever_config, latest)

      _ ->
        state
    end
  end

  # Keep the latest target through failures. Delayed retries are bounded, and
  # disconnected controllers wait for reconnect instead of spawning writers.
  defp finish_write(%State{} = state, ref, _result) do
    Enum.reduce(state.pending, state, fn
      {id, {config, value, %Task{ref: ^ref}}}, acc ->
        acc |> put_in([Access.key(:pending), id], {config, value, nil}) |> schedule_retry(id)

      _, acc ->
        acc
    end)
  end

  defp record_written(%State{} = state, id, written) do
    %{
      clear_retry(state, id)
      | pending: Map.delete(state.pending, id),
        last_written: Map.put(state.last_written, id, written)
    }
  end

  defp schedule_retry(state, id) do
    retry = Map.get(state.retries, id, %{attempts: 0, timer: nil, token: nil})

    with delay when is_integer(delay) <- Enum.at(@retry_delays, retry.attempts),
         {:ok, _client} <- simulator_client() do
      token = make_ref()
      timer = Process.send_after(self(), {:retry_write, id, token}, delay)
      put_in(state.retries[id], %{attempts: retry.attempts + 1, timer: timer, token: token})
    else
      nil ->
        Logger.warning(
          "[LeverController] Gave up writing lever #{id} after #{retry.attempts} retries; " <>
            "it is sent again when the lever moves"
        )

        state

      _ ->
        state
    end
  end

  defp clear_retry(state, id) do
    case Map.get(state.retries, id) do
      %{timer: timer} when is_reference(timer) -> Process.cancel_timer(timer)
      _ -> :ok
    end

    %{state | retries: Map.delete(state.retries, id)}
  end

  defp cancel_retry_timers(state) do
    retries =
      Map.new(state.retries, fn {id, retry} ->
        if retry.timer, do: Process.cancel_timer(retry.timer)
        {id, %{retry | timer: nil, token: nil}}
      end)

    %{state | retries: retries}
  end

  defp cancel_pending(%State{} = state) do
    Enum.each(state.pending, fn
      {_, {_, _, %Task{} = task}} -> Task.shutdown(task, :brutal_kill)
      _ -> :ok
    end)

    %{cancel_retry_timers(state) | pending: %{}, retries: %{}, last_written: %{}}
  end

  defp send_to_simulator(client, %LeverConfig{value_endpoint: endpoint}, value) do
    case SimulatorClient.set(client, endpoint, value) do
      {:ok, _response} ->
        :ok

      {:error, reason} ->
        Logger.warning("[LeverController] Failed to send value to simulator: #{inspect(reason)}")

        :error
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
