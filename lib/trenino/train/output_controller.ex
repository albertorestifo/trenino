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
            subscriptions: %{String.t() => integer()},
            poll_timer: reference() | nil
          }

    defstruct active_train: nil,
              bindings: %{},
              subscriptions: %{},
              poll_timer: nil
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
    {:noreply, %{state | active_train: nil, bindings: %{}, subscriptions: %{}}}
  end

  def handle_info({:train_changed, train}, %State{} = state) do
    Logger.info("[OutputController] Train activated: #{train.name}")
    state = cleanup_subscriptions(state)
    {:noreply, load_bindings_for_train(state, train)}
  end

  def handle_info({:train_detected, _}, %State{} = state), do: {:noreply, state}
  def handle_info({:detection_error, _}, %State{} = state), do: {:noreply, state}

  def handle_info(:poll_subscriptions, %State{} = state) do
    state = poll_and_update_outputs(state)
    {:noreply, schedule_poll(state)}
  end

  def handle_info(_msg, %State{} = state), do: {:noreply, state}

  # Private Functions

  defp load_bindings_for_train(%State{} = state, train) do
    bindings = Train.list_enabled_output_bindings(train.id)

    if Enum.empty?(bindings) do
      Logger.info("[OutputController] No output bindings for train #{train.name}")
      %{state | active_train: train, bindings: %{}, subscriptions: %{}}
    else
      case get_simulator_client() do
        {:ok, client} ->
          {binding_map, subscription_map} = setup_subscriptions(client, bindings)

          state = %{
            state
            | active_train: train,
              bindings: binding_map,
              subscriptions: subscription_map
          }

          Logger.info(
            "[OutputController] Loaded #{map_size(binding_map)} bindings for train #{train.name}"
          )

          schedule_poll(state)

        :error ->
          Logger.warning(
            "[OutputController] Simulator not connected, cannot set up subscriptions"
          )

          %{state | active_train: train, bindings: %{}, subscriptions: %{}}
      end
    end
  end

  defp setup_subscriptions(client, bindings) do
    endpoint_groups = Enum.group_by(bindings, & &1.endpoint)

    endpoint_groups
    |> Enum.with_index()
    |> Enum.reduce({%{}, %{}}, fn {{endpoint, bindings_for_endpoint}, index}, acc ->
      subscription_id = @subscription_id_base + index
      subscribe_endpoint(client, endpoint, bindings_for_endpoint, subscription_id, acc)
    end)
  end

  defp subscribe_endpoint(
         client,
         endpoint,
         bindings_for_endpoint,
         subscription_id,
         {b_acc, s_acc}
       ) do
    case SimulatorClient.subscribe(client, endpoint, subscription_id) do
      {:ok, _} ->
        Logger.info("[OutputController] Subscribed to #{endpoint} with ID #{subscription_id}")
        updated_bindings = add_bindings_to_map(bindings_for_endpoint, subscription_id, b_acc)
        {updated_bindings, Map.put(s_acc, endpoint, subscription_id)}

      {:error, reason} ->
        Logger.warning(
          "[OutputController] Failed to subscribe to #{endpoint}: #{inspect(reason)}"
        )

        {b_acc, s_acc}
    end
  end

  defp add_bindings_to_map(bindings_for_endpoint, subscription_id, binding_map) do
    Enum.reduce(bindings_for_endpoint, binding_map, fn %OutputBinding{} = binding, acc ->
      Map.put(acc, binding.id, %{
        binding: binding,
        subscription_id: subscription_id,
        current_state: false
      })
    end)
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

    Enum.each(state.bindings, fn {_id, info} ->
      set_output_state(info.binding, false)
    end)

    %{state | poll_timer: nil}
  end

  defp schedule_poll(%State{bindings: bindings} = state) when map_size(bindings) > 0 do
    timer = Process.send_after(self(), :poll_subscriptions, @poll_interval_ms)
    %{state | poll_timer: timer}
  end

  defp schedule_poll(%State{} = state), do: state

  defp poll_and_update_outputs(%State{} = state) do
    case get_simulator_client() do
      {:ok, client} ->
        by_subscription =
          Enum.group_by(state.bindings, fn {_id, info} -> info.subscription_id end)

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

      {:ok, %{"Entries" => [%{"NodeValid" => false} | _]}} ->
        Logger.debug("[OutputController] Subscription #{sub_id} node invalid")
        state

      {:ok, _} ->
        state

      {:error, reason} ->
        Logger.debug(
          "[OutputController] Failed to get subscription #{sub_id}: #{inspect(reason)}"
        )

        state
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

  defp get_simulator_client do
    case SimulatorConnection.get_status() do
      %ConnectionState{status: :connected, client: client} when client != nil ->
        {:ok, client}

      _ ->
        :error
    end
  end
end
