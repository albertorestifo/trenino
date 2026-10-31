defmodule Trenino.Train.GaugeController do
  @moduledoc "Fresh simulator samples drive commissioned, referenced axes through the manager."
  use GenServer
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

      %{s | bindings: bindings, status: Map.take(s.status, Map.keys(bindings))}
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

        {subs, Map.put(values, endpoint, response), retries,
         poll_error(errors, endpoint, response)}

      {:error, retries, reason} ->
        {subs, values, retries, Map.put(errors, endpoint, reason)}
    end
  end

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
      result = StepperManager.set_target(b.stepper_axis_id, mapped.target, s.train.id)

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

  defp expire_samples(s) do
    Enum.reduce(s.bindings, s, fn {id, b}, acc ->
      status = Map.get(acc.status, id)

      if status && now() - status.received_at >= b.stale_after_ms && not status.inactive do
        StepperManager.inactive(b.stepper_axis_id, b.inactive_behavior)
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
