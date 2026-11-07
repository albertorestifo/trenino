defmodule Trenino.Train.OutputController do
  @moduledoc """
  Controls hardware outputs based on simulator API values.

  This GenServer:
  - Subscribes to train detection events to know which train is active
  - Creates API subscriptions for configured output bindings
  - Polls subscription values periodically
  - Evaluates conditions and sets hardware output states

  ## Architecture

  When a train becomes active:
  1. Load all enabled output bindings for the train
  2. Create subscriptions for each unique endpoint
  3. Start polling subscription values (every 200ms)
  4. Evaluate conditions and update output states

  Uses subscription ID range 1000-1999 to avoid conflicts with
  other subscription users.
  """

  use GenServer
  require Logger

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Simulator.Client, as: SimulatorClient
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train
  alias Trenino.Train.OutputBinding

  @poll_interval_ms 200
  @retry_delay_ms 1000
  @subscription_id_base 1000

  defmodule State do
    @moduledoc false

    @type binding_info :: %{
            binding: OutputBinding.t(),
            subscription_id: integer(),
            current_state: boolean()
          }

    @type t :: %__MODULE__{
            active_train: Train.Train.t() | nil,
            bindings: %{integer() => binding_info()},
            endpoint_ids: %{String.t() => integer()},
            subscriptions: %{String.t() => integer()},
            retry_after: %{String.t() => integer()},
            poll_timer: reference() | nil,
            poll_token: reference() | nil
          }

    # `endpoint_ids` holds every endpoint the train needs; `subscriptions` only the ones
    # the simulator currently holds. The difference is (re)subscribed on each poll once
    # its `retry_after` time has passed, so a failed or lost subscription recovers.
    defstruct active_train: nil,
              bindings: %{},
              endpoint_ids: %{},
              subscriptions: %{},
              retry_after: %{},
              poll_timer: nil,
              poll_token: nil
  end

  # Client API

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Reload bindings for the active train.

  Call this when output bindings are modified to pick up changes.
  """
  @spec reload_bindings() :: :ok
  def reload_bindings do
    GenServer.cast(__MODULE__, :reload_bindings)
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    Train.subscribe()
    SimulatorConnection.subscribe()

    state = %State{}

    state =
      case Train.get_active_train() do
        nil -> state
        train -> load_bindings_for_train(state, train)
      end

    {:ok, state}
  end

  @impl true
  def handle_cast(:reload_bindings, %State{active_train: nil} = state) do
    {:noreply, state}
  end

  def handle_cast(:reload_bindings, %State{active_train: train} = state) do
    state = cleanup_subscriptions(state)
    {:noreply, load_bindings_for_train(state, train)}
  end

  @impl true
  def handle_info({:train_changed, nil}, %State{} = state) do
    Logger.info("[OutputController] Train deactivated, cleaning up")
    state = cleanup_subscriptions(state)
    {:noreply, %{state | active_train: nil, bindings: %{}, endpoint_ids: %{}, subscriptions: %{}}}
  end

  def handle_info({:train_changed, train}, %State{} = state) do
    Logger.info("[OutputController] Train activated: #{train.name}")
    state = cleanup_subscriptions(state)
    {:noreply, load_bindings_for_train(state, train)}
  end

  def handle_info({:train_detected, _}, %State{} = state), do: {:noreply, state}
  def handle_info({:detection_error, _}, %State{} = state), do: {:noreply, state}

  # A (re)connected simulator may have restarted and forgotten every subscription, so all
  # endpoints are subscribed afresh on the next poll.
  def handle_info({:simulator_status_changed, %ConnectionState{status: :connected}}, state) do
    {:noreply, %{state | subscriptions: %{}, retry_after: %{}}}
  end

  # Without a simulator the outputs no longer reflect anything, so they are switched off.
  def handle_info({:simulator_status_changed, %ConnectionState{}}, %State{} = state) do
    {:noreply, %{all_outputs_off(state) | subscriptions: %{}, retry_after: %{}}}
  end

  def handle_info({:poll_subscriptions, token}, %State{poll_token: token} = state) do
    state = poll_and_update_outputs(state)
    {:noreply, schedule_poll(state)}
  end

  def handle_info(_msg, %State{} = state), do: {:noreply, state}

  # Private Functions

  # Bindings load whether or not the simulator is reachable right now; subscribing is
  # left to the poll loop, which retries until it succeeds.
  defp load_bindings_for_train(%State{} = state, train) do
    bindings = Train.list_enabled_output_bindings(train.id)

    endpoint_ids =
      bindings
      |> Enum.map(& &1.endpoint)
      |> Enum.uniq()
      |> Enum.sort()
      |> Enum.with_index(@subscription_id_base)
      |> Map.new()

    binding_map =
      Map.new(bindings, fn %OutputBinding{} = binding ->
        {binding.id,
         %{
           binding: binding,
           subscription_id: endpoint_ids[binding.endpoint],
           current_state: false
         }}
      end)

    if map_size(binding_map) == 0 do
      Logger.info("[OutputController] No output bindings for train #{train.name}")
    else
      Logger.info(
        "[OutputController] Loaded #{map_size(binding_map)} bindings for train #{train.name}"
      )
    end

    schedule_poll(
      %{
        state
        | active_train: train,
          bindings: binding_map,
          endpoint_ids: endpoint_ids,
          subscriptions: %{},
          retry_after: %{}
      },
      0
    )
  end

  defp ensure_subscriptions(%State{} = state, client) do
    now = now()

    state.endpoint_ids
    |> Enum.reject(fn {endpoint, _} -> Map.has_key?(state.subscriptions, endpoint) end)
    |> Enum.filter(fn {endpoint, _} -> Map.get(state.retry_after, endpoint, now) <= now end)
    |> Enum.reduce(state, fn {endpoint, id}, acc ->
      subscribe_endpoint(acc, client, endpoint, id)
    end)
  end

  defp subscribe_endpoint(%State{} = state, client, endpoint, subscription_id) do
    # A subscription left over from a previous run may still hold this ID, and subscribing
    # onto it would append a second path.
    clear_stale_subscription(client, subscription_id)

    case SimulatorClient.subscribe(client, endpoint, subscription_id) do
      {:ok, _} ->
        Logger.info("[OutputController] Subscribed to #{endpoint} with ID #{subscription_id}")

        %{
          state
          | subscriptions: Map.put(state.subscriptions, endpoint, subscription_id),
            retry_after: Map.delete(state.retry_after, endpoint)
        }

      {:error, reason} ->
        unless Map.has_key?(state.retry_after, endpoint) do
          Logger.warning(
            "[OutputController] Failed to subscribe to #{endpoint}, retrying: #{inspect(reason)}"
          )
        end

        retry_later(state, endpoint)
    end
  end

  # A missing subscription is the normal case; any other failure surfaces through the
  # subscribe that follows.
  defp clear_stale_subscription(client, subscription_id) do
    _ = SimulatorClient.unsubscribe(client, subscription_id)
    :ok
  end

  defp retry_later(%State{} = state, endpoint) do
    %{
      state
      | subscriptions: Map.delete(state.subscriptions, endpoint),
        retry_after: Map.put(state.retry_after, endpoint, now() + @retry_delay_ms)
    }
  end

  defp cleanup_subscriptions(%State{poll_timer: timer, subscriptions: subs} = state) do
    if timer, do: Process.cancel_timer(timer)

    case get_simulator_client() do
      {:ok, client} ->
        Enum.each(subs, fn {_endpoint, sub_id} ->
          SimulatorClient.unsubscribe(client, sub_id)
        end)

      :error ->
        :ok
    end

    %{all_outputs_off(state) | poll_timer: nil, poll_token: nil}
  end

  defp all_outputs_off(%State{} = state) do
    bindings =
      Map.new(state.bindings, fn {id, info} ->
        set_output_state(info.binding, false)
        {id, %{info | current_state: false}}
      end)

    %{state | bindings: bindings}
  end

  defp schedule_poll(state, delay \\ @poll_interval_ms)

  defp schedule_poll(%State{bindings: bindings} = state, delay) when map_size(bindings) > 0 do
    token = make_ref()
    timer = Process.send_after(self(), {:poll_subscriptions, token}, delay)
    %{state | poll_timer: timer, poll_token: token}
  end

  defp schedule_poll(%State{} = state, _delay), do: %{state | poll_timer: nil, poll_token: nil}

  defp poll_and_update_outputs(%State{} = state) do
    case get_simulator_client() do
      {:ok, client} ->
        state = ensure_subscriptions(state, client)

        by_subscription =
          state.bindings
          |> Enum.filter(fn {_id, info} ->
            Map.has_key?(state.subscriptions, info.binding.endpoint)
          end)
          |> Enum.group_by(fn {_id, info} -> info.subscription_id end)

        Enum.reduce(by_subscription, state, fn {sub_id, binding_entries}, acc ->
          process_subscription(client, sub_id, binding_entries, acc)
        end)

      :error ->
        state
    end
  end

  defp process_subscription(client, sub_id, binding_entries, state) do
    case SimulatorClient.get_subscription(client, sub_id) do
      {:ok, %{"Entries" => [%{"Values" => values, "NodeValid" => true} | _]}}
      when map_size(values) > 0 ->
        raw_value = values |> Map.values() |> List.first()
        value = normalize_value(raw_value)
        update_bindings_with_value(state, binding_entries, value)

      {:ok, _} ->
        state

      # The simulator may have dropped the subscription (e.g. it restarted), so the
      # endpoint is subscribed again after the retry delay.
      {:error, reason} ->
        Logger.debug(
          "[OutputController] Failed to get subscription #{sub_id}, resubscribing: #{inspect(reason)}"
        )

        [{_id, info} | _] = binding_entries
        retry_later(state, info.binding.endpoint)
    end
  end

  # Normalize subscription values: round floats to 2 decimals, pass booleans through
  defp normalize_value(value) when is_boolean(value), do: value
  defp normalize_value(value) when is_number(value), do: Float.round(value * 1.0, 2)
  defp normalize_value(value), do: value

  defp update_bindings_with_value(state, binding_entries, value) do
    Enum.reduce(binding_entries, state, fn {id, info}, acc ->
      new_state = evaluate_condition(info.binding, value)

      if new_state != info.current_state do
        Logger.debug(
          "[OutputController] #{info.binding.name}: value=#{value}, state=#{new_state}"
        )

        set_output_state(info.binding, new_state)

        updated_info = %{info | current_state: new_state}
        %{acc | bindings: Map.put(acc.bindings, id, updated_info)}
      else
        acc
      end
    end)
  end

  # Numeric operators
  defp evaluate_condition(%OutputBinding{operator: :gt, value_a: threshold}, value)
       when is_number(value) do
    value > threshold
  end

  defp evaluate_condition(%OutputBinding{operator: :gte, value_a: threshold}, value)
       when is_number(value) do
    value >= threshold
  end

  defp evaluate_condition(%OutputBinding{operator: :lt, value_a: threshold}, value)
       when is_number(value) do
    value < threshold
  end

  defp evaluate_condition(%OutputBinding{operator: :lte, value_a: threshold}, value)
       when is_number(value) do
    value <= threshold
  end

  defp evaluate_condition(
         %OutputBinding{operator: :between, value_a: min, value_b: max},
         value
       )
       when is_number(value) do
    value >= min and value <= max
  end

  # Boolean operators
  defp evaluate_condition(%OutputBinding{operator: :eq_true}, value) when is_boolean(value) do
    value == true
  end

  defp evaluate_condition(%OutputBinding{operator: :eq_false}, value) when is_boolean(value) do
    value == false
  end

  # Fallback for type mismatches (e.g., boolean value with numeric operator)
  defp evaluate_condition(_binding, _value), do: false

  defp set_output_state(%OutputBinding{output: output}, state) do
    port = ConfigurationManager.config_id_to_port(output.device.config_id)

    if port do
      value = if state, do: :high, else: :low
      Hardware.set_output(port, output.pin, value)
    end
  end

  defp now, do: System.monotonic_time(:millisecond)

  defp get_simulator_client do
    case SimulatorConnection.get_status() do
      %ConnectionState{status: :connected, client: client} when client != nil ->
        {:ok, client}

      _ ->
        :error
    end
  end
end
