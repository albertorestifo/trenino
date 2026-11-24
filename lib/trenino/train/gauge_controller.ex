defmodule Trenino.Train.GaugeController do
  @moduledoc """
  Fresh simulator samples drive the gauges of the active train's enabled bindings.

  Samples come from `Trenino.Simulator.Watcher`, which delivers every watched endpoint
  that has a value every 200 ms.

  Gauge commands are fire-and-forget (`SetGaugePosition`), so the controller re-sends an
  unchanged target every 2 seconds as a backstop, and at once after the device stores a
  configuration or reconnects: both re-zero every gauge, which forgets its position.

  A stale value holds the needle: nothing is sent until a fresh sample arrives.

  While a gauge is under manual control (the calibration panel or the `move_gauge` MCP
  tool), train samples for it are not sent. See `hold_manual/2`.
  """
  use GenServer
  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Serial.Connection, as: SerialConnection
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Simulator.Watcher
  alias Trenino.Train
  alias Trenino.Train.GaugeController.State
  alias Trenino.Train.GaugeMapper

  # Stale samples and expired manual holds are checked this often.
  @tick_ms 200
  # An unchanged target is not re-sent on every sample. It is re-sent after a configuration
  # is applied, the device list changes or manual control ends, and at least this often
  # as a backstop for the fire-and-forget command.
  @resend_after_ms 2000
  @link_ttl_ms 5000

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def reload_bindings, do: GenServer.cast(__MODULE__, :reload)
  def subscribe(id), do: Phoenix.PubSub.subscribe(Trenino.PubSub, "train:gauges:#{id}")

  def snapshot(id) do
    if Process.whereis(__MODULE__), do: GenServer.call(__MODULE__, {:snapshot, id}), else: %{}
  end

  @doc """
  Controller state and per-binding runtime for a train: `nil` when that train is not active.

  The `controller` map holds the train, whether the simulator is connected, the endpoints
  being watched and the last sample error. `bindings` maps binding id to its latest sample,
  converted value, target, stale flag and failure.
  """
  def runtime(id) do
    if Process.whereis(__MODULE__), do: GenServer.call(__MODULE__, {:runtime, id}), else: nil
  end

  @doc """
  Puts a gauge under manual control, so train samples stop moving it, until
  `release_manual/1` is called or the hold ends:

    * `owner: pid` - while `pid` is alive (the calibration panel's LiveView);
    * `ttl_ms: ms` - for `ms` milliseconds; calling again renews it (MCP `move_gauge`).

  A no-op when the controller is not running.
  """
  @spec hold_manual(integer(), keyword()) :: :ok
  def hold_manual(gauge_id, opts) when is_integer(gauge_id),
    do:
      call_if_running(
        {:hold_manual, gauge_id, Keyword.get(opts, :owner), Keyword.get(opts, :ttl_ms)}
      )

  @doc "Ends manual control of a gauge; the active train's value is sent again."
  @spec release_manual(integer()) :: :ok
  def release_manual(gauge_id) when is_integer(gauge_id),
    do: call_if_running({:release_manual, gauge_id})

  @doc "True while a gauge is under manual control."
  @spec manual?(integer()) :: boolean()
  def manual?(gauge_id) when is_integer(gauge_id) do
    if Process.whereis(__MODULE__),
      do: GenServer.call(__MODULE__, {:manual?, gauge_id}),
      else: false
  catch
    :exit, _ -> false
  end

  # Manual control must not fail because the controller is restarting.
  defp call_if_running(message) do
    if Process.whereis(__MODULE__), do: GenServer.call(__MODULE__, message)
    :ok
  catch
    :exit, _reason -> :ok
  end

  @impl true
  def init(_opts) do
    Train.subscribe()
    SimulatorConnection.subscribe()
    SerialConnection.subscribe()
    ConfigurationManager.subscribe_configuration()
    Watcher.subscribe()
    Phoenix.PubSub.subscribe(Trenino.PubSub, "train:gauges:configuration")
    {:ok, %State{}, {:continue, :initial}}
  end

  @impl true
  def handle_continue(:initial, s) do
    s = %{s | connected: connected?(SimulatorConnection.get_status())}
    {:noreply, activate(s, Train.get_active_train())}
  end

  @impl true
  def handle_call({:snapshot, id}, _, s),
    do: {:reply, if(s.train && s.train.id == id, do: s.status, else: %{}), s}

  def handle_call({:runtime, id}, _, s),
    do: {:reply, if(s.train && s.train.id == id, do: runtime_state(s), else: nil), s}

  # A timed hold (MCP) never replaces one owned by a live process (the calibration panel):
  # the panel keeps the gauge until it closes.
  def handle_call({:hold_manual, gauge_id, owner, ttl_ms}, _, s) do
    case s.manual do
      %{^gauge_id => %{ref: ref}} when is_reference(ref) and is_nil(owner) ->
        {:reply, :ok, s}

      _ ->
        {:reply, :ok, put_hold(s, gauge_id, owner, ttl_ms)}
    end
  end

  def handle_call({:release_manual, gauge_id}, _, s),
    do: {:reply, :ok, end_manual(s, gauge_id, resend: true)}

  def handle_call({:manual?, gauge_id}, _, s) do
    s = expire_manual(s)
    {:reply, Map.has_key?(s.manual, gauge_id), s}
  end

  defp put_hold(s, gauge_id, owner, ttl_ms) do
    s = end_manual(s, gauge_id, resend: false)
    ref = if is_pid(owner), do: Process.monitor(owner)
    until = if is_integer(ttl_ms), do: now() + ttl_ms
    %{s | manual: Map.put(s.manual, gauge_id, %{ref: ref, until: until})}
  end

  @impl true
  def handle_cast(:reload, s), do: {:noreply, reload(s)}
  @impl true
  def handle_info({:train_changed, train}, s), do: {:noreply, activate(s, train)}
  def handle_info({:gauge_bindings_changed, _}, s), do: {:noreply, reload(s)}

  # Both re-zero the device's gauges (a new configuration recreates them, a reconnect may
  # be a reboot) and may change where commands go, so links are looked up again and every
  # target is resent.
  def handle_info({:devices_updated, _devices}, s), do: {:noreply, relink(s)}

  def handle_info({:configuration_applied, _port, _device, _config_id}, s),
    do: {:noreply, relink(s)}

  # Samples from before a connect or disconnect say nothing about the simulator now.
  def handle_info({:simulator_status_changed, %ConnectionState{} = status}, s) do
    case connected?(status) do
      connected when connected == s.connected ->
        {:noreply, s}

      connected ->
        {:noreply, %{s | connected: connected, status: %{}, sent: %{}, links: %{}}}
    end
  end

  def handle_info(:simulator_watcher_started, s) do
    Watcher.watch(endpoints(s.bindings))
    {:noreply, s}
  end

  def handle_info({:simulator_values, values}, %State{train: %{}} = s) when is_map(values) do
    s =
      Enum.reduce(s.bindings, s, fn {id, binding}, acc ->
        case Map.fetch(values, binding.endpoint) do
          {:ok, value} -> apply_sample(acc, id, binding, value)
          :error -> acc
        end
      end)

    {:noreply, s}
  end

  def handle_info({:tick, generation}, %State{generation: generation} = s) do
    s = s |> expire_manual() |> expire_samples()
    {:noreply, %{s | timer: Process.send_after(self(), {:tick, generation}, @tick_ms)}}
  end

  def handle_info({:DOWN, ref, :process, _, _}, s) do
    case Enum.find(s.manual, fn {_, hold} -> hold.ref == ref end) do
      {gauge_id, _} -> {:noreply, end_manual(s, gauge_id, resend: true)}
      nil -> {:noreply, s}
    end
  end

  def handle_info(_, s), do: {:noreply, s}

  @impl true
  def terminate(_, s) do
    if s.timer, do: Process.cancel_timer(s.timer)
  end

  defp relink(s), do: %{s | links: %{}, sent: %{}}

  defp end_manual(s, gauge_id, resend: resend?) do
    case Map.pop(s.manual, gauge_id) do
      {nil, _} ->
        s

      {hold, manual} ->
        if hold.ref, do: Process.demonitor(hold.ref, [:flush])
        s = %{s | manual: manual}
        if resend?, do: forget_sent_for_gauge(s, gauge_id), else: s
    end
  end

  defp expire_manual(s) do
    now = now()

    s.manual
    |> Enum.filter(fn {_, hold} -> hold.until && hold.until <= now end)
    |> Enum.reduce(s, fn {gauge_id, _}, acc -> end_manual(acc, gauge_id, resend: true) end)
  end

  defp forget_sent_for_gauge(s, gauge_id) do
    sent = Map.reject(s.sent, fn {id, _} -> match?(%{gauge_id: ^gauge_id}, s.bindings[id]) end)
    %{s | sent: sent}
  end

  @doc """
  Resolve exactly one numeric sample from a watched value, or an explicitly selected
  value key when the endpoint returns several values (a map).
  """
  def sample(value, _key) when is_number(value), do: {:ok, value}

  def sample(values, key) when is_map(values) do
    value = if is_binary(key) and key != "", do: Map.get(values, key), else: single_value(values)
    if is_number(value), do: {:ok, value}, else: {:error, :invalid_or_ambiguous_sample}
  end

  def sample(_, _), do: {:error, :invalid_or_ambiguous_sample}

  defp single_value(values) when map_size(values) == 1, do: values |> Map.values() |> hd()
  defp single_value(_), do: nil

  # A reload with the same endpoints keeps the latest samples; only bindings that
  # disappeared are made inactive.
  defp reload(%State{train: %{}} = s) do
    bindings = load_bindings(s.train)

    if endpoints(bindings) == endpoints(s.bindings) do
      %{
        s
        | bindings: bindings,
          status: Map.take(s.status, Map.keys(bindings)),
          sent: %{},
          links: %{}
      }
    else
      activate(s, s.train)
    end
  end

  defp reload(s), do: activate(s, s.train)

  defp load_bindings(nil), do: %{}

  defp load_bindings(train),
    do: Map.new(Train.list_enabled_gauge_bindings(train.id), &{&1.id, &1})

  defp connected?(%ConnectionState{status: :connected, client: client}), do: not is_nil(client)
  defp connected?(_status), do: false

  defp endpoints(bindings) do
    bindings
    |> Map.values()
    |> Enum.map(& &1.endpoint)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp activate(s, train) do
    if s.timer, do: Process.cancel_timer(s.timer)
    Watcher.unwatch_all()
    generation = s.generation + 1
    bindings = load_bindings(train)
    Watcher.watch(endpoints(bindings))

    %{
      s
      | train: train,
        bindings: bindings,
        status: %{},
        sent: %{},
        links: %{},
        last_error: nil,
        generation: generation,
        timer: if(train, do: Process.send_after(self(), {:tick, generation}, @tick_ms))
    }
  end

  defp apply_sample(s, id, b, value) do
    with {:ok, raw} <- sample(value, b.value_key),
         {:ok, mapped} <- GaugeMapper.map(b, raw, b.gauge) do
      {s, result} = send_target(s, id, b, mapped.target)

      status =
        Map.merge(mapped, %{
          sample: Float.round(raw * 1.0, 2),
          received_at: now(),
          stale: false,
          inactive: false,
          failure: if(result == :ok, do: nil, else: result)
        })

      publish(s, id, status)
    else
      error ->
        status =
          Map.merge(Map.get(s.status, id, %{received_at: now(), inactive: false}), %{
            failure: error
          })

        publish(%{s | last_error: error}, id, status)
    end
  end

  defp send_target(s, id, b, target) do
    now = now()
    s = expire_manual(s)

    case Map.get(s.sent, id) do
      _ when is_map_key(s.manual, b.gauge_id) ->
        {%{s | sent: Map.delete(s.sent, id)}, :manual_control}

      %{target: ^target, at: at} when now - at < @resend_after_ms ->
        {s, :ok}

      _ ->
        {s, link} = link(s, b.gauge.device_id)
        result = send_position(link, b.gauge, target)

        sent =
          if result == :ok,
            do: Map.put(s.sent, id, %{target: target, at: now}),
            else: Map.delete(s.sent, id)

        {%{s | sent: sent}, result}
    end
  end

  defp send_position({:ok, port}, gauge, target) do
    case Hardware.set_gauge_position(port, gauge, target) do
      :ok -> :ok
      {:error, reason} -> reason
    end
  end

  defp send_position({:error, reason}, _gauge, _target), do: reason

  # Looking a link up reads the database and the serial registry, so the answer is cached
  # per device until the device list, the applied configuration or the gauges change, and
  # re-checked every few seconds: edits to inputs or outputs change whether the device
  # still runs the saved configuration, and they broadcast nothing here.
  defp link(s, device_id) do
    now = now()

    case Map.fetch(s.links, device_id) do
      {:ok, {link, at}} when now - at < @link_ttl_ms ->
        {s, link}

      _ ->
        link = Hardware.gauge_link(device_id)
        {%{s | links: Map.put(s.links, device_id, {link, now})}, link}
    end
  end

  defp expire_samples(s) do
    Enum.reduce(s.bindings, s, fn {id, b}, acc ->
      status = Map.get(acc.status, id)

      if status && now() - status.received_at >= b.stale_after_ms && not status.inactive do
        # Hold: the needle stays at the last value. After a reboot or a new configuration
        # it rests at zero until a fresh sample arrives.
        acc = %{acc | sent: Map.delete(acc.sent, id)}
        publish(acc, id, Map.merge(status, %{stale: true, inactive: true}))
      else
        acc
      end
    end)
  end

  defp runtime_state(s) do
    %{
      controller: %{
        train_id: s.train.id,
        simulator_connected: s.connected,
        last_error: s.last_error,
        watched_endpoints: endpoints(s.bindings)
      },
      bindings: s.status
    }
  end

  defp publish(s, id, status) do
    Phoenix.PubSub.broadcast(
      Trenino.PubSub,
      "train:gauges:#{s.train.id}",
      {:gauge_binding_updated, id, status}
    )

    %{s | status: Map.put(s.status, id, status)}
  end

  defp now, do: System.monotonic_time(:millisecond)
end
