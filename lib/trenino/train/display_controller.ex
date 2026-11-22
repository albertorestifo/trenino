defmodule Trenino.Train.DisplayController do
  @moduledoc """
  Drives I2C display modules based on simulator endpoint values.

  Mirrors OutputController but sends WriteSegments instead of SetOutput.
  Endpoint values come from `Trenino.Simulator.Watcher`.
  """

  use GenServer
  require Logger

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Hardware.HT16K33
  alias Trenino.Hardware.HT16K33.Params, as: HT16K33Params
  alias Trenino.Hardware.I2cModule
  alias Trenino.Serial.Connection, as: SerialConnection
  alias Trenino.Serial.Protocol.SetModuleBrightness
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Simulator.Watcher
  alias Trenino.Train
  alias Trenino.Train.DisplayBinding
  alias Trenino.Train.DisplayFormatter

  defmodule State do
    @moduledoc false

    @type binding_info :: %{
            binding: DisplayBinding.t(),
            last_text: String.t() | nil
          }

    @type t :: %__MODULE__{
            active_train: Trenino.Train.Train.t() | nil,
            bindings: %{integer() => binding_info()},
            endpoints: [String.t()]
          }

    defstruct active_train: nil, bindings: %{}, endpoints: []
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
    SimulatorConnection.subscribe()
    SerialConnection.subscribe()
    ConfigurationManager.subscribe_configuration()
    Watcher.subscribe()
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
    {:noreply, %{state | active_train: nil, bindings: %{}, endpoints: []}}
  end

  def handle_info({:train_changed, train}, %State{} = state) do
    Logger.info("[DisplayController] Train activated: #{train.name}")
    state = cleanup(state)
    {:noreply, load_bindings_for_train(state, train)}
  end

  def handle_info({:train_detected, _}, %State{} = state), do: {:noreply, state}
  def handle_info({:detection_error, _}, %State{} = state), do: {:noreply, state}

  def handle_info(
        {:simulator_status_changed, %ConnectionState{status: :connected}},
        %State{active_train: train} = state
      )
      when not is_nil(train) do
    state = cleanup(state)
    {:noreply, load_bindings_for_train(state, train)}
  end

  def handle_info({:devices_updated, _devices}, %State{} = state) do
    {:noreply, invalidate_displays(state)}
  end

  def handle_info(
        {:configuration_applied, _port, _device, _config_id},
        %State{active_train: train} = state
      )
      when not is_nil(train) do
    # Configuration deployment may change or remove modules. Do not blank old
    # addresses after deployment; reload persisted settings before replaying.
    state = cleanup(state, false)
    {:noreply, load_bindings_for_train(state, train)}
  end

  def handle_info(:simulator_watcher_started, %State{endpoints: endpoints} = state) do
    Watcher.watch(endpoints)
    {:noreply, state}
  end

  def handle_info({:simulator_values, values}, %State{} = state) when is_map(values) do
    {:noreply, Enum.reduce(values, state, &update_endpoint/2)}
  end

  def handle_info(_msg, %State{} = state), do: {:noreply, state}

  # Private Functions

  defp load_bindings_for_train(%State{} = state, train) do
    bindings = Train.list_enabled_display_bindings(train.id)

    binding_map =
      Map.new(bindings, fn %DisplayBinding{} = binding ->
        {binding.id, %{binding: binding, last_text: nil}}
      end)

    endpoints = bindings |> Enum.map(& &1.endpoint) |> Enum.uniq() |> Enum.sort()

    if map_size(binding_map) > 0 do
      Logger.info(
        "[DisplayController] Loaded #{map_size(binding_map)} display bindings for #{train.name}"
      )
    end

    Watcher.watch(endpoints)
    %{state | active_train: train, bindings: binding_map, endpoints: endpoints}
  end

  defp cleanup(%State{bindings: bindings} = state, blank? \\ true) do
    if blank?, do: Enum.each(bindings, fn {_id, info} -> blank_display(info.binding) end)
    Watcher.unwatch_all()
    state
  end

  defp update_endpoint({endpoint, raw}, %State{} = state) do
    value = if is_number(raw), do: Float.round(raw * 1.0, 2), else: raw

    entries = Enum.filter(state.bindings, fn {_id, info} -> info.binding.endpoint == endpoint end)
    update_displays(state, entries, value)
  end

  defp clamp_to_min(raw_value, %HT16K33Params{min_value: min_v})
       when is_number(raw_value) and is_number(min_v) and raw_value < min_v,
       do: min_v

  defp clamp_to_min(raw_value, _params), do: raw_value

  defp update_displays(state, entries, value) do
    Enum.reduce(entries, state, fn {id, info}, acc ->
      converted = DisplayFormatter.convert(value, info.binding.unit)
      clamped = clamp_to_min(converted, info.binding.i2c_module.params)
      text = DisplayFormatter.format(info.binding.format_string, clamped)

      update_display(acc, id, info, text)
    end)
  end

  defp update_display(state, _id, %{last_text: text}, text), do: state

  defp update_display(state, id, info, text) do
    case send_to_display(info.binding, text, info.last_text == nil) do
      :ok -> %{state | bindings: Map.put(state.bindings, id, %{info | last_text: text})}
      _ -> state
    end
  end

  defp invalidate_displays(%State{} = state) do
    bindings = Map.new(state.bindings, fn {id, info} -> {id, %{info | last_text: nil}} end)
    %{state | bindings: bindings}
  end

  defp send_to_display(%DisplayBinding{i2c_module: %I2cModule{} = mod}, text, initialize?) do
    port = ConfigurationManager.config_id_to_port(mod.device.config_id)

    if port do
      chip_mod = chip_module(mod.module_chip)
      bytes = chip_mod.encode_string(text, mod.params)

      with :ok <- set_brightness(port, mod, initialize?) do
        Hardware.write_segments(port, mod.i2c_address, bytes)
      end
    else
      {:error, :disconnected}
    end
  end

  defp set_brightness(port, %I2cModule{} = mod, true) do
    SerialConnection.send_message(port, %SetModuleBrightness{
      i2c_address: mod.i2c_address,
      brightness: mod.params.brightness
    })
  end

  defp set_brightness(_port, %I2cModule{}, false), do: :ok

  defp blank_display(%DisplayBinding{i2c_module: %I2cModule{} = mod}) do
    port = ConfigurationManager.config_id_to_port(mod.device.config_id)

    if port do
      blank = chip_module(mod.module_chip).encode_string("", mod.params)
      Hardware.write_segments(port, mod.i2c_address, blank)
    end
  end

  # i2c_module not preloaded — this should not happen since list_enabled_display_bindings/1
  # always preloads i2c_module: :device
  defp blank_display(%DisplayBinding{}) do
    Logger.error("[DisplayController] blank_display called with unloaded i2c_module association")
  end

  defp chip_module(:ht16k33), do: HT16K33
end
