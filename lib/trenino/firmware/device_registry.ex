defmodule Trenino.Firmware.DeviceRegistry do
  @moduledoc """
  Manages device configuration registry with dynamic loading from firmware release manifests.

  This module replaces the hardcoded BoardConfig with a hybrid approach:
  - Static hardware configurations (avrdude parameters) defined in the app
  - Dynamic device list loaded from release.json manifests
  - ETS cache for fast lookups
  - Fallback to hardcoded devices if no manifest available

  The registry is a GenServer that maintains an ETS table with merged device configurations.
  """

  use GenServer
  require Logger

  alias Trenino.Firmware

  @table_name :firmware_device_registry

  # Static hardware configurations mapping PlatformIO environments to avrdude parameters
  # These are kept static as they represent physical chipset characteristics
  @hardware_configs %{
    "uno" => %{
      mcu: "m328p",
      programmer: "arduino",
      baud_rate: 115_200,
      use_1200bps_touch: false
    },
    "nanoatmega328" => %{
      mcu: "m328p",
      programmer: "arduino",
      baud_rate: 115_200,
      use_1200bps_touch: false
    },
    "nanoatmega328new" => %{
      mcu: "m328p",
      programmer: "arduino",
      baud_rate: 115_200,
      use_1200bps_touch: false
    },
    "leonardo" => %{
      mcu: "m32u4",
      programmer: "avr109",
      baud_rate: 57_600,
      use_1200bps_touch: true
    },
    "micro" => %{
      mcu: "m32u4",
      programmer: "avr109",
      baud_rate: 57_600,
      use_1200bps_touch: true
    },
    "sparkfun_promicro16" => %{
      mcu: "m32u4",
      programmer: "avr109",
      baud_rate: 57_600,
      use_1200bps_touch: true
    },
    "megaatmega2560" => %{
      mcu: "m2560",
      programmer: "wiring",
      baud_rate: 115_200,
      use_1200bps_touch: false
    }
  }

  ## Client API

  @doc """
  Starts the DeviceRegistry GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Gets the complete device configuration for a given environment.

  Returns `{:ok, config}` with merged manifest and hardware data, or
  `{:error, :unknown_device}` if the environment is not found.

  ## Examples

      iex> DeviceRegistry.get_device_config("leonardo")
      {:ok, %{
        environment: "leonardo",
        display_name: "Arduino Leonardo",
        firmware_file: "trenino-leonardo.firmware.hex",
        mcu: "m32u4",
        programmer: "avr109",
        baud_rate: 57600,
        use_1200bps_touch: true
      }}
  """
  def get_device_config(environment) when is_binary(environment) do
    case :ets.lookup(@table_name, environment) do
      [{^environment, config}] -> {:ok, config}
      [] -> {:error, :unknown_device}
    end
  end

  @doc """
  Lists all available devices from the registry.

  Returns a list of device configurations.
  """
  def list_available_devices do
    @table_name
    |> :ets.tab2list()
    |> Enum.map(fn {_env, config} -> config end)
    |> Enum.sort_by(& &1.display_name)
  end

  @doc """
  Returns select options for UI dropdowns in the format `{display_name, environment}`.
  """
  def select_options do
    list_available_devices()
    |> Enum.map(fn config ->
      {config.display_name, config.environment}
    end)
  end

  @doc """
  Detects device environment from a firmware filename.

  Attempts to match patterns like "trenino-leonardo.firmware.hex" to "leonardo".

  Returns `{:ok, environment}` or `:error` if no match found.
  """
  def detect_device_from_filename(filename) when is_binary(filename) do
    # Pattern: trenino-{environment}.firmware.hex or trenino-{environment}.hex
    case Regex.run(~r/trenino-([^.]+)(?:\.firmware)?\.hex$/, filename) do
      [_, environment] ->
        case get_device_config(environment) do
          {:ok, _config} -> {:ok, environment}
          {:error, :unknown_device} -> :error
        end

      nil ->
        :error
    end
  end

  @doc """
  Reloads the device registry from a manifest.

  Called when a new firmware release is downloaded with a manifest.
  Updates the ETS cache with devices from the manifest.

  ## Parameters
    - `manifest_data`: Parsed JSON manifest (map with "devices" list)
    - `release_id`: Database ID of the firmware release (for logging)
  """
  def reload_from_manifest(manifest_data, release_id) do
    GenServer.call(__MODULE__, {:reload_from_manifest, manifest_data, release_id})
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for device configs
    :ets.new(@table_name, [:named_table, :set, :public, read_concurrency: true])

    # Load initial devices from database or use fallback
    load_initial_devices()

    {:ok, %{}}
  end

  @impl true
  def handle_call({:reload_from_manifest, manifest_data, release_id}, _from, state) do
    Logger.info("Reloading device registry from manifest (release_id: #{release_id})")

    case load_devices_from_manifest(manifest_data) do
      {:ok, device_count} ->
        Logger.info("Successfully loaded #{device_count} devices from manifest")
        {:reply, :ok, state}

      {:error, reason} ->
        Logger.error("Failed to load devices from manifest: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  ## Private Functions

  defp load_initial_devices do
    case load_latest_manifest_from_db() do
      {:ok, manifest_data} ->
        Logger.info("Loading devices from database manifest")
        load_devices_from_manifest(manifest_data)

      :error ->
        Logger.info("No manifest found in database, using fallback devices")
        load_fallback_devices()
    end
  end

  defp load_latest_manifest_from_db do
    case Firmware.get_latest_release() do
      {:ok, %{manifest_json: manifest_json}} when manifest_json != nil ->
        case Jason.decode(manifest_json) do
          {:ok, manifest} -> {:ok, manifest}
          {:error, _} -> :error
        end

      _ ->
        :error
    end
  end

  defp load_devices_from_manifest(manifest_data) do
    devices = Map.get(manifest_data, "devices", [])

    if devices == [] do
      handle_empty_manifest()
    else
      devices
      |> Enum.map(&parse_manifest_device/1)
      |> Enum.reject(&is_nil/1)
      |> apply_device_configs()
    end
  end

  defp handle_empty_manifest do
    Logger.warning("Manifest contains no devices, falling back")
    load_fallback_devices()
    {:error, :no_devices}
  end

  defp apply_device_configs([]) do
    Logger.warning("No valid devices in manifest, falling back")
    load_fallback_devices()
    {:error, :no_valid_devices}
  end

  defp apply_device_configs(device_configs) do
    :ets.delete_all_objects(@table_name)

    Enum.each(device_configs, fn config ->
      :ets.insert(@table_name, {config.environment, config})
    end)

    {:ok, length(device_configs)}
  end

  defp parse_manifest_device(device) do
    with {:ok, environment} <- Map.fetch(device, "environment"),
         {:ok, display_name} <- Map.fetch(device, "displayName"),
         {:ok, firmware_file} <- Map.fetch(device, "firmwareFile"),
         {:ok, hw_config} <- Map.fetch(@hardware_configs, environment) do
      build_device_config(environment, display_name, firmware_file, hw_config)
    else
      :error ->
        log_invalid_device(device)
        nil
    end
  end

  defp build_device_config(environment, display_name, firmware_file, hw_config) do
    %{
      environment: environment,
      display_name: display_name,
      firmware_file: firmware_file,
      mcu: hw_config.mcu,
      programmer: hw_config.programmer,
      baud_rate: hw_config.baud_rate,
      use_1200bps_touch: hw_config.use_1200bps_touch
    }
  end

  defp log_invalid_device(device) do
    env = Map.get(device, "environment", "unknown")

    if Map.has_key?(@hardware_configs, env) do
      Logger.warning("Manifest device missing required fields: #{inspect(device)}")
    else
      Logger.info(
        "Skipping manifest device with unknown environment: #{env} (not in hardware configs)"
      )
    end
  end

  defp load_fallback_devices do
    Logger.debug("Loading fallback devices from static hardware configs")

    fallback_devices =
      @hardware_configs
      |> Enum.map(fn {env, hw_config} ->
        {env,
         %{
           environment: env,
           display_name: infer_display_name(env),
           firmware_file: "trenino-#{env}.firmware.hex",
           mcu: hw_config.mcu,
           programmer: hw_config.programmer,
           baud_rate: hw_config.baud_rate,
           use_1200bps_touch: hw_config.use_1200bps_touch
         }}
      end)

    # Clear existing entries
    :ets.delete_all_objects(@table_name)

    # Insert fallback devices
    Enum.each(fallback_devices, fn {env, config} ->
      :ets.insert(@table_name, {env, config})
    end)

    {:ok, length(fallback_devices)}
  end

  defp infer_display_name(environment) do
    case environment do
      "uno" -> "Arduino Uno"
      "nanoatmega328" -> "Arduino Nano (ATmega328)"
      "nanoatmega328new" -> "Arduino Nano"
      "leonardo" -> "Arduino Leonardo"
      "micro" -> "Arduino Micro"
      "sparkfun_promicro16" -> "SparkFun Pro Micro"
      "megaatmega2560" -> "Arduino Mega 2560"
      other -> String.capitalize(other)
    end
  end
end
