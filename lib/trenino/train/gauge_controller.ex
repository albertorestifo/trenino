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

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  def reload_bindings, do: GenServer.cast(__MODULE__, :reload)
  def subscribe(id), do: Phoenix.PubSub.subscribe(Trenino.PubSub, "train:gauges:#{id}")

  def snapshot(id) do
    if Process.whereis(__MODULE__), do: GenServer.call(__MODULE__, {:snapshot, id}), else: %{}
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

  @impl true
  def handle_cast(:reload, s), do: {:noreply, activate(s, s.train)}
  @impl true
  def handle_info({:train_changed, train}, s), do: {:noreply, activate(s, train)}
  def handle_info({:gauge_bindings_changed, _}, s), do: {:noreply, activate(s, s.train)}

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

    {:noreply,
     %{
       s
       | task: nil,
         cleaning: false,
         cleanup_job: nil,
         timer: Process.send_after(self(), {:poll, s.generation}, 0)
     }}
  end

  def handle_info({ref, {:cleanup_failed, _}}, %State{task: %{ref: ref}, cleaning: true} = s) do
    Process.demonitor(ref, [:flush])
    {:noreply, failed_cleanup(s)}
  end

  def handle_info({:cleanup_timeout, ref}, %State{task: %{ref: ref}, cleaning: true} = s) do
    Task.shutdown(s.task, :brutal_kill)
    {:noreply, failed_cleanup(s)}
  end

  def handle_info({:retry_cleanup, token}, %State{cleanup_job: %{token: token}, task: nil} = s),
    do: {:noreply, run_cleanup(s)}

  def handle_info({:poll_timeout, ref}, %State{task: %{ref: ref}, cleaning: false} = s) do
    Task.shutdown(s.task, :brutal_kill)
    {:noreply, cleanup(%{s | task: nil})}
  end

  def handle_info({:DOWN, ref, :process, _, _}, %State{task: %{ref: ref}, cleaning: true} = s),
    do: {:noreply, failed_cleanup(s)}

  def handle_info({:DOWN, ref, :process, _, _}, %State{task: %{ref: ref}} = s),
    do: {:noreply, cleanup(%{s | task: nil})}

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

  defp activate(s, train) do
    s = cleanup(s)
    generation = s.generation + 1

    client =
      case SimulatorConnection.get_status() do
        %ConnectionState{status: :connected, client: client} -> client
        _ -> nil
      end

    bindings =
      if train, do: Map.new(Train.list_enabled_gauge_bindings(train.id), &{&1.id, &1}), else: %{}

    %{
      s
      | train: train,
        client: client,
        bindings: bindings,
        subscriptions: %{},
        status: %{},
        generation: generation,
        retry_after: %{},
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
      ids =
        s.bindings
        |> Map.values()
        |> Enum.map(& &1.endpoint)
        |> Enum.uniq()
        |> Enum.sort()
        |> Enum.take(1000)
        |> Enum.with_index(4000)
        |> Enum.map(&elem(&1, 1))

      run_cleanup(%{
        s
        | task: nil,
          cleaning: true,
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
        {:ok, _} -> {:cont, :cleanup_complete}
        error -> {:halt, {:cleanup_failed, error}}
      end
    end)
  end

  defp failed_cleanup(s) do
    Process.send_after(self(), {:retry_cleanup, s.cleanup_job.token}, 1000)
    %{s | task: nil, cleaning: true}
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
    endpoints =
      s.bindings
      |> Map.values()
      |> Enum.map(& &1.endpoint)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.take(1000)

    {subs, values, retries} =
      endpoints
      |> Enum.with_index(4000)
      |> Enum.reduce({s.subscriptions, %{}, s.retry_after}, fn {endpoint, id},
                                                               {subs, values, retries} ->
        case ensure_subscription(s.client, endpoint, id, subs, retries) do
          {:ok, subs, retries} ->
            {subs, Map.put(values, endpoint, Client.get_subscription(s.client, id)), retries}

          {:error, retries} ->
            {subs, values, retries}
        end
      end)

    %{subscriptions: subs, values: values, retries: retries}
  end

  defp ensure_subscription(client, endpoint, id, subs, retries) do
    retry = Map.get(retries, endpoint, %{after: now(), delay: 1000})

    cond do
      Map.has_key?(subs, endpoint) ->
        {:ok, subs, retries}

      retry.after > now() ->
        {:error, retries}

      true ->
        case Client.subscribe(client, endpoint, id) do
          {:ok, _} ->
            {:ok, Map.put(subs, endpoint, id), Map.delete(retries, endpoint)}

          _ ->
            {:error,
             Map.put(retries, endpoint, %{
               after: now() + retry.delay,
               delay: min(5000, retry.delay * 2)
             })}
        end
    end
  end

  defp apply_poll(s, result) do
    s = %{s | subscriptions: result.subscriptions, retry_after: result.retries}

    Enum.reduce(s.bindings, s, fn {id, binding}, acc ->
      apply_sample(acc, id, binding, Map.get(result.values, binding.endpoint))
    end)
  end

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
            failure: error
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
