defmodule Trenino.Train.DisplayController do
  @moduledoc """
  Drives I2C display modules based on simulator endpoint values.

  Mirrors OutputController but sends WriteSegments instead of SetOutput.
  Uses subscription ID range 3000-3999 to avoid conflicts with
  OutputController (1000-1999) and ScriptRunner (2000-2999).
  """

  use GenServer
  require Logger

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Hardware.HT16K33
  alias Trenino.Hardware.I2cModule
  alias Trenino.Simulator.Client, as: SimulatorClient
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train
  alias Trenino.Train.DisplayBinding
  alias Trenino.Train.DisplayFormatter

  @poll_interval_ms 200
  @subscription_id_base 3000

  defmodule State do
    @moduledoc false

    @type binding_info :: %{
            binding: DisplayBinding.t(),
            subscription_id: integer(),
            last_text: String.t() | nil
          }

    @type t :: %__MODULE__{
            active_train: map() | nil,
            bindings: %{integer() => binding_info()},
            subscriptions: %{String.t() => integer()},
            poll_timer: reference() | nil
          }

    defstruct active_train: nil, bindings: %{}, subscriptions: %{}, poll_timer: nil
  end

  # Client API

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @doc """
  Reload bindings for the active train.

  Call this when display bindings are modified to pick up changes.
  """
  @spec reload_bindings() :: :ok
  def reload_bindings, do: GenServer.cast(__MODULE__, :reload_bindings)

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
  def handle_cast(:reload_bindings, %State{active_train: nil} = state), do: {:noreply, state}

  def handle_cast(:reload_bindings, %State{active_train: train} = state) do
    state = cleanup(state)
    {:noreply, load_bindings_for_train(state, train)}
  end

  @impl true
  def handle_info({:train_changed, nil}, %State{} = state) do
    Logger.info("[DisplayController] Train deactivated")
    state = cleanup(state)
    {:noreply, %{state | active_train: nil, bindings: %{}, subscriptions: %{}}}
  end

  def handle_info({:train_changed, train}, %State{} = state) do
    Logger.info("[DisplayController] Train activated: #{train.name}")
    state = cleanup(state)
    {:noreply, load_bindings_for_train(state, train)}
  end

  def handle_info({:train_detected, _}, %State{} = state), do: {:noreply, state}
  def handle_info({:detection_error, _}, %State{} = state), do: {:noreply, state}

  def handle_info(:poll_displays, %State{} = state) do
    state = poll_and_update(state)
    {:noreply, schedule_poll(state)}
  end

  def handle_info(_msg, %State{} = state), do: {:noreply, state}

  # Private Functions

  defp load_bindings_for_train(%State{} = state, train) do
    bindings = Train.list_enabled_display_bindings(train.id)

    if Enum.empty?(bindings) do
      %{state | active_train: train, bindings: %{}, subscriptions: %{}}
    else
      case get_simulator_client() do
        {:ok, client} ->
          {binding_map, sub_map} = setup_subscriptions(client, bindings)

          Logger.info(
            "[DisplayController] Loaded #{map_size(binding_map)} display bindings for #{train.name}"
          )

          schedule_poll(%{
            state
            | active_train: train,
              bindings: binding_map,
              subscriptions: sub_map
          })

        :error ->
          Logger.warning("[DisplayController] Simulator not connected, skipping subscriptions")
          %{state | active_train: train, bindings: %{}, subscriptions: %{}}
      end
    end
  end

  defp setup_subscriptions(client, bindings) do
    bindings
    |> Enum.group_by(& &1.endpoint)
    |> Enum.with_index()
    |> Enum.reduce({%{}, %{}}, fn {{endpoint, group}, index}, {b_acc, s_acc} ->
      sub_id = @subscription_id_base + index
      subscribe_endpoint(client, endpoint, group, sub_id, {b_acc, s_acc})
    end)
  end

  defp subscribe_endpoint(client, endpoint, group, sub_id, {b_acc, s_acc}) do
    case SimulatorClient.subscribe(client, endpoint, sub_id) do
      {:ok, _} ->
        updated =
          Enum.reduce(group, b_acc, fn %DisplayBinding{} = binding, acc ->
            Map.put(acc, binding.id, %{binding: binding, subscription_id: sub_id, last_text: nil})
          end)

        {updated, Map.put(s_acc, endpoint, sub_id)}

      {:error, reason} ->
        Logger.warning(
          "[DisplayController] Failed to subscribe to #{endpoint}: #{inspect(reason)}"
        )

        {b_acc, s_acc}
    end
  end

  defp cleanup(%State{poll_timer: timer, subscriptions: subs, bindings: bindings} = state) do
    if timer, do: Process.cancel_timer(timer)

    Enum.each(bindings, fn {_id, info} -> blank_display(info.binding) end)

    case get_simulator_client() do
      {:ok, client} ->
        Enum.each(subs, fn {_endpoint, sub_id} -> SimulatorClient.unsubscribe(client, sub_id) end)

      :error ->
        :ok
    end

    %{state | poll_timer: nil}
  end

  defp schedule_poll(%State{bindings: b} = state) when map_size(b) > 0 do
    %{state | poll_timer: Process.send_after(self(), :poll_displays, @poll_interval_ms)}
  end

  defp schedule_poll(%State{} = state), do: state

  defp poll_and_update(%State{} = state) do
    case get_simulator_client() do
      {:ok, client} ->
        state.bindings
        |> Enum.group_by(fn {_id, info} -> info.subscription_id end)
        |> Enum.reduce(state, fn {sub_id, entries}, acc ->
          process_subscription(client, sub_id, entries, acc)
        end)

      :error ->
        state
    end
  end

  defp process_subscription(client, sub_id, entries, state) do
    case SimulatorClient.get_subscription(client, sub_id) do
      {:ok, %{"Entries" => [%{"Values" => values, "NodeValid" => true} | _]}}
      when map_size(values) > 0 ->
        raw = values |> Map.values() |> List.first()
        value = if is_number(raw), do: Float.round(raw * 1.0, 2), else: raw
        update_displays(state, entries, value)

      _ ->
        state
    end
  end

  defp update_displays(state, entries, value) do
    Enum.reduce(entries, state, fn {id, info}, acc ->
      text = DisplayFormatter.format(info.binding.format_string, value)

      if text != info.last_text do
        send_to_display(info.binding, text)
        %{acc | bindings: Map.put(acc.bindings, id, %{info | last_text: text})}
      else
        acc
      end
    end)
  end

  defp send_to_display(%DisplayBinding{i2c_module: %I2cModule{} = mod}, text) do
    port = ConfigurationManager.config_id_to_port(mod.device.config_id)

    if port do
      chip_mod = chip_module(mod.module_chip)
      bytes = chip_mod.encode_string(text, mod.num_digits)
      Hardware.write_segments(port, mod.i2c_address, bytes)
    end
  end

  defp blank_display(%DisplayBinding{i2c_module: %I2cModule{} = mod}) do
    port = ConfigurationManager.config_id_to_port(mod.device.config_id)

    if port do
      blank = :binary.copy(<<0>>, mod.num_digits * 2)
      Hardware.write_segments(port, mod.i2c_address, blank)
    end
  end

  defp chip_module(:ht16k33), do: HT16K33

  defp get_simulator_client do
    case SimulatorConnection.get_status() do
      %ConnectionState{status: :connected, client: client} when client != nil -> {:ok, client}
      _ -> :error
    end
  end
end
