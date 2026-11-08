defmodule Trenino.Train.GaugeController do
  @moduledoc """
  Fresh simulator samples drive the gauges of the active train's enabled bindings.

  Gauge commands are fire-and-forget (`SetGaugePosition`), so the controller re-sends an
  unchanged target every 2 seconds as a backstop, and at once after the device stores a
  configuration or reconnects: both re-zero every gauge, which forgets its position.

  A stale value holds the needle: nothing is sent until a fresh sample arrives.

  While a gauge is under manual control (the calibration panel or the `move_gauge` MCP
  tool), train samples for it are not sent. See `hold_manual/2`.
  """
  use GenServer
  require Logger
  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Serial.Connection, as: SerialConnection
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train
  alias Trenino.Train.GaugeController.State
  alias Trenino.Train.GaugeMapper

  # The simulator rejects deleting an absent subscription; cleanup's goal is already met.
  @no_such_subscription "dtg.comm.NoSuchSubscription"
  # After this many failed cleanup attempts the old subscription IDs are abandoned and
  # never reused: polling resumes on a fresh ID range instead of stalling forever.
  @max_cleanup_attempts 3
  @id_block 1000
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

  The `controller` map holds the train, simulator connection, cleaning flag, retry count and
  last error. `bindings` maps binding id to its latest sample, converted value, target,
  stale flag and failure.
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
    # Trap exits so a supervisor shutdown runs terminate/2 (stops the poll task); simulator
    # subscriptions left behind are cleared on the next start.
    Process.flag(:trap_exit, true)
    Train.subscribe()
    SimulatorConnection.subscribe()
    SerialConnection.subscribe()
    ConfigurationManager.subscribe_configuration()
    Phoenix.PubSub.subscribe(Trenino.PubSub, "train:gauges:configuration")
    {:ok, %State{}, {:continue, :initial}}
  end

  @impl true
  def handle_continue(:initial, s), do: {:noreply, activate(s, Train.get_active_train())}
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

  def handle_info({:simulator_status_changed, %ConnectionState{}}, s),
    do: {:noreply, activate(s, s.train)}

  def handle_info({:poll, generation}, %State{generation: generation} = s) do
    s = expire_samples(s)
    s = if s.task || s.cleaning, do: s, else: start_poll(s)
    {:noreply, %{s | timer: Process.send_after(self(), {:poll, generation}, 200)}}
  end

  def handle_info(
        {ref, {generation, result}},
        %State{task: %{ref: ref}, generation: generation} = s
      ) do
    Process.demonitor(ref, [:flush])
    {:noreply, apply_poll(%{s | task: nil}, result)}
  end

  def handle_info({ref, :cleanup_complete}, %State{task: %{ref: ref}, cleaning: true} = s) do
    Process.demonitor(ref, [:flush])
    if s.timer, do: Process.cancel_timer(s.timer)

    {:noreply, finish_cleanup(%{s | last_error: nil})}
  end

  def handle_info({ref, {:cleanup_failed, error}}, %State{task: %{ref: ref}, cleaning: true} = s) do
    Process.demonitor(ref, [:flush])
    {:noreply, failed_cleanup(s, {:cleanup_failed, error})}
  end

  def handle_info({:cleanup_timeout, ref}, %State{task: %{ref: ref}, cleaning: true} = s) do
    Task.shutdown(s.task, :brutal_kill)
    {:noreply, failed_cleanup(s, :cleanup_timeout)}
  end

  def handle_info({:retry_cleanup, token}, %State{cleanup_job: %{token: token}, task: nil} = s),
    do: {:noreply, run_cleanup(s)}

  def handle_info({:poll_timeout, ref}, %State{task: %{ref: ref}, cleaning: false} = s) do
    Task.shutdown(s.task, :brutal_kill)
    {:noreply, cleanup(%{s | task: nil, last_error: :poll_timeout})}
  end

  def handle_info(
        {:DOWN, ref, :process, _, reason},
        %State{task: %{ref: ref}, cleaning: true} = s
      ),
      do: {:noreply, failed_cleanup(s, {:cleanup_crashed, reason})}

  def handle_info({:DOWN, ref, :process, _, reason}, %State{task: %{ref: ref}} = s),
    do: {:noreply, cleanup(%{s | task: nil, last_error: {:poll_crashed, reason}})}

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
    if s.task, do: Task.shutdown(s.task, :brutal_kill)
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

  @doc "Resolve exactly one valid numeric sample, or an explicitly selected value key."
  def sample({:ok, %{"Entries" => [%{"NodeValid" => true, "Values" => values}]}}, key)
      when is_map(values) do
    value = if is_binary(key) and key != "", do: Map.get(values, key), else: single_value(values)
    if is_number(value), do: {:ok, value}, else: {:error, :invalid_or_ambiguous_sample}
  end

  def sample(_, _), do: {:error, :invalid_node}
  defp single_value(values) when map_size(values) == 1, do: values |> Map.values() |> hd()
  defp single_value(_), do: nil

  # A reload with the same simulator and endpoints keeps healthy subscriptions;
  # only bindings that disappeared are made inactive.
  defp reload(%State{train: %{}, cleaning: false} = s) do
    bindings = load_bindings(s.train)

    if current_client() == s.client and endpoints(bindings) == endpoints(s.bindings) do
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

  defp current_client do
    case SimulatorConnection.get_status() do
      %ConnectionState{status: :connected, client: client} -> client
      _ -> nil
    end
  end

  defp endpoints(bindings) do
    bindings
    |> Map.values()
    |> Enum.map(& &1.endpoint)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.take(1000)
  end

  defp activate(s, train) do
    s = cleanup(s)
    generation = s.generation + 1
    client = current_client()
    bindings = load_bindings(train)

    %{
      s
      | train: train,
        client: client,
        bindings: bindings,
        subscriptions: %{},
        status: %{},
        sent: %{},
        links: %{},
        generation: generation,
        retry_after: %{},
        endpoint_errors: %{},
        timer: Process.send_after(self(), {:poll, generation}, 0)
    }
  end

  defp cleanup(%State{cleaning: true} = s) do
    if s.timer, do: Process.cancel_timer(s.timer)
    s
  end

  defp cleanup(s) do
    if s.timer, do: Process.cancel_timer(s.timer)
    if s.task, do: Task.shutdown(s.task, :brutal_kill)

    if s.client do
      ids = s.bindings |> endpoints() |> Enum.with_index(s.id_base) |> Enum.map(&elem(&1, 1))

      run_cleanup(%{
        s
        | task: nil,
          cleaning: true,
          cleanup_attempts: 0,
          subscriptions: %{},
          cleanup_job: %{client: s.client, ids: ids, token: make_ref()}
      })
    else
      %{s | task: nil, cleaning: false, cleanup_job: nil}
    end
  end

  defp run_cleanup(s) do
    job = s.cleanup_job

    task =
      Task.Supervisor.async_nolink(Trenino.TaskSupervisor, fn ->
        unsubscribe_all(job)
      end)

    Process.send_after(self(), {:cleanup_timeout, task.ref}, 5000)
    %{s | task: task, cleaning: true}
  end

  defp unsubscribe_all(job) do
    Enum.reduce_while(job.ids, :cleanup_complete, fn id, _ ->
      case Client.unsubscribe(job.client, id) do
        {:ok, _} ->
          {:cont, :cleanup_complete}

        {:error, {:http_error, 400, %{"errorCode" => @no_such_subscription}}} ->
          {:cont, :cleanup_complete}

        error ->
          {:halt, {:cleanup_failed, error}}
      end
    end)
  end

  defp failed_cleanup(s, error) do
    attempts = s.cleanup_attempts + 1
    s = %{s | task: nil, cleanup_attempts: attempts, last_error: error}

    if attempts >= @max_cleanup_attempts do
      abandon_cleanup(s)
    else
      Process.send_after(self(), {:retry_cleanup, s.cleanup_job.token}, 1000)
      s
    end
  end

  # The old subscriptions may still exist, so their IDs are skipped, never reused.
  defp abandon_cleanup(s), do: finish_cleanup(%{s | id_base: s.id_base + @id_block})

  defp finish_cleanup(s) do
    if s.timer, do: Process.cancel_timer(s.timer)

    %{
      s
      | task: nil,
        cleaning: false,
        cleanup_job: nil,
        cleanup_attempts: 0,
        timer: Process.send_after(self(), {:poll, s.generation}, 0)
    }
  end

  defp start_poll(%State{client: nil} = s), do: s
  defp start_poll(%State{bindings: bindings} = s) when map_size(bindings) == 0, do: s

  defp start_poll(s) do
    generation = s.generation
    task = Task.Supervisor.async_nolink(Trenino.TaskSupervisor, fn -> {generation, fetch(s)} end)
    Process.send_after(self(), {:poll_timeout, task.ref}, 5000)
    %{s | task: task}
  end

  defp fetch(s) do
    {subs, values, retries, errors} =
      s.bindings
      |> endpoints()
      |> Enum.with_index(s.id_base)
      |> Enum.reduce({s.subscriptions, %{}, s.retry_after, %{}}, fn {endpoint, id}, acc ->
        fetch_endpoint(s.client, endpoint, id, acc)
      end)

    %{subscriptions: subs, values: values, retries: retries, errors: errors}
  end

  defp fetch_endpoint(client, endpoint, id, {subs, values, retries, errors}) do
    case ensure_subscription(client, endpoint, id, subs, retries) do
      {:ok, subs, retries} ->
        response = Client.get_subscription(client, id)
        {subs, retries} = evict_failed(response, endpoint, subs, retries)

        {subs, Map.put(values, endpoint, response), retries,
         poll_error(errors, endpoint, response)}

      {:error, retries, reason} ->
        {subs, values, retries, Map.put(errors, endpoint, reason)}
    end
  end

  # A failed GET may mean the simulator forgot the subscription (e.g. it restarted), so
  # the endpoint is dropped and resubscribed under the usual backoff.
  defp evict_failed({:error, reason}, endpoint, subs, retries) do
    retry = Map.get(retries, endpoint, %{delay: 1000})

    {Map.delete(subs, endpoint),
     Map.put(retries, endpoint, %{
       after: now() + retry.delay,
       delay: min(5000, retry.delay * 2),
       reason: {:poll_failed, reason}
     })}
  end

  defp evict_failed(_response, _endpoint, subs, retries), do: {subs, retries}

  defp poll_error(errors, endpoint, {:error, reason}),
    do: Map.put(errors, endpoint, {:poll_failed, reason})

  defp poll_error(errors, _endpoint, _response), do: errors

  defp ensure_subscription(client, endpoint, id, subs, retries) do
    retry = Map.get(retries, endpoint, %{after: now(), delay: 1000})

    cond do
      Map.has_key?(subs, endpoint) ->
        {:ok, subs, retries}

      retry.after > now() ->
        {:error, retries, Map.get(retry, :reason)}

      true ->
        clear_stale_subscription(client, id)

        case Client.subscribe(client, endpoint, id) do
          {:ok, _} ->
            {:ok, Map.put(subs, endpoint, id), Map.delete(retries, endpoint)}

          error ->
            reason = {:subscribe_failed, error}

            {:error,
             Map.put(retries, endpoint, %{
               after: now() + retry.delay,
               delay: min(5000, retry.delay * 2),
               reason: reason
             }), reason}
        end
    end
  end

  # The ID counter restarts at 4000 with the app, so a subscription from a previous run
  # may still hold this ID; subscribing onto it would append paths and break sampling.
  # A missing subscription is the normal case. Other failures surface through subscribe.
  defp clear_stale_subscription(client, id) do
    case Client.unsubscribe(client, id) do
      {:ok, _} ->
        :ok

      {:error, {:http_error, 400, %{"errorCode" => @no_such_subscription}}} ->
        :ok

      error ->
        Logger.debug("[GaugeController] Could not clear subscription #{id}: #{inspect(error)}")
    end
  end

  defp apply_poll(s, result) do
    s = %{
      s
      | subscriptions: result.subscriptions,
        retry_after: result.retries,
        endpoint_errors: result.errors,
        last_error: first_error(result.errors)
    }

    Enum.reduce(s.bindings, s, fn {id, binding}, acc ->
      apply_sample(acc, id, binding, Map.get(result.values, binding.endpoint))
    end)
  end

  defp first_error(errors) when map_size(errors) == 0, do: nil
  defp first_error(errors), do: errors |> Enum.sort() |> hd() |> elem(1)

  defp apply_sample(s, id, b, response) do
    with {:ok, raw} <- sample(response, b.value_key),
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
            failure: Map.get(s.endpoint_errors, b.endpoint, error)
          })

        publish(s, id, status)
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
        simulator_connected: s.client != nil,
        cleaning: s.cleaning,
        cleanup_attempts: s.cleanup_attempts,
        last_error: s.last_error,
        subscribed_endpoints: s.subscriptions |> Map.keys() |> Enum.sort()
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
