defmodule Trenino.Train.GaugeController do
  @moduledoc "Fresh simulator samples drive commissioned, referenced axes through the manager."
  use GenServer
  require Logger
  alias Trenino.Hardware.StepperManager
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
  # An unchanged, accepted target is not re-sent on every sample (each send reads the axis
  # from the database). It is re-sent as soon as the stepper session reports it no longer
  # holds that target (a manual lease, a re-reference, a reconnect), and at least this often
  # as a backstop.
  @resend_after_ms 2000

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

  @impl true
  def init(_opts) do
    # Trap exits so a supervisor shutdown runs terminate/2 and releases the steppers.
    Process.flag(:trap_exit, true)
    Train.subscribe()
    SimulatorConnection.subscribe()
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

  @impl true
  def handle_cast(:reload, s), do: {:noreply, reload(s)}
  @impl true
  def handle_info({:train_changed, train}, s), do: {:noreply, activate(s, train)}
  def handle_info({:gauge_bindings_changed, _}, s), do: {:noreply, reload(s)}

  def handle_info({:stepper_updated, device_id, %{axes: axes}}, s) when is_map(axes),
    do: {:noreply, forget_unheld_targets(s, device_id, axes)}

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

  def handle_info(_, s), do: {:noreply, s}

  @impl true
  def terminate(_, s) do
    if s.timer, do: Process.cancel_timer(s.timer)
    if s.task, do: Task.shutdown(s.task, :brutal_kill)

    Enum.each(s.bindings, fn {_, binding} ->
      StepperManager.inactive(binding.stepper_axis_id, binding.inactive_behavior)
    end)
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
      Enum.each(Map.drop(s.bindings, Map.keys(bindings)), fn {_, b} ->
        StepperManager.inactive(b.stepper_axis_id, b.inactive_behavior)
      end)

      subscribe_steppers(%{
        s
        | bindings: bindings,
          status: Map.take(s.status, Map.keys(bindings)),
          sent: %{}
      })
    else
      activate(s, s.train)
    end
  end

  defp reload(s), do: activate(s, s.train)

  defp load_bindings(nil), do: %{}

  defp load_bindings(train),
    do: Map.new(Train.list_enabled_gauge_bindings(train.id), &{&1.id, &1})

  # PubSub subscriptions are never dropped, so each device topic is joined only once.
  defp subscribe_steppers(s) do
    devices =
      s.bindings
      |> Map.values()
      |> Enum.map(& &1.stepper_axis.device_id)
      |> MapSet.new()

    devices
    |> MapSet.difference(s.stepper_devices)
    |> Enum.each(&StepperManager.subscribe/1)

    %{s | stepper_devices: MapSet.union(s.stepper_devices, devices)}
  end

  # A target in flight (`pending`) is not yet reflected in `last_target`, so it is kept.
  defp forget_unheld_targets(s, device_id, axes) do
    sent =
      Map.reject(s.sent, fn {id, %{target: target}} ->
        case s.bindings[id] do
          %{stepper_axis: %{device_id: ^device_id}, stepper_axis_id: axis_id} ->
            not holds_target?(Map.get(axes, axis_id), target)

          _ ->
            false
        end
      end)

    %{s | sent: sent}
  end

  defp holds_target?(%{pending: nil, last_target: held}, target), do: held == target
  defp holds_target?(%{pending: _}, _target), do: true
  defp holds_target?(_axis, _target), do: false

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

    subscribe_steppers(%{
      s
      | train: train,
        client: client,
        bindings: bindings,
        subscriptions: %{},
        status: %{},
        sent: %{},
        generation: generation,
        retry_after: %{},
        endpoint_errors: %{},
        timer: Process.send_after(self(), {:poll, generation}, 0)
    })
  end

  defp cleanup(%State{cleaning: true} = s) do
    if s.timer, do: Process.cancel_timer(s.timer)
    s
  end

  defp cleanup(s) do
    if s.timer, do: Process.cancel_timer(s.timer)
    if s.task, do: Task.shutdown(s.task, :brutal_kill)

    Enum.each(s.bindings, fn {_, b} ->
      StepperManager.inactive(b.stepper_axis_id, b.inactive_behavior)
    end)

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
         {:ok, mapped} <- GaugeMapper.map(b, raw, b.stepper_axis) do
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

    case Map.get(s.sent, id) do
      %{target: ^target, at: at} when now - at < @resend_after_ms ->
        {s, :ok}

      _ ->
        result = StepperManager.set_target(b.stepper_axis_id, target, s.train.id)

        sent =
          if result == :ok,
            do: Map.put(s.sent, id, %{target: target, at: now}),
            else: Map.delete(s.sent, id)

        {%{s | sent: sent}, result}
    end
  end

  defp expire_samples(s) do
    Enum.reduce(s.bindings, s, fn {id, b}, acc ->
      status = Map.get(acc.status, id)

      if status && now() - status.received_at >= b.stale_after_ms && not status.inactive do
        StepperManager.inactive(b.stepper_axis_id, b.inactive_behavior)
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
