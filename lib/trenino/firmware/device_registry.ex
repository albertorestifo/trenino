defmodule Trenino.Firmware.DeviceRegistry do
  @moduledoc """
  Manages device configuration registry with dynamic loading from firmware release manifests.

  All device configurations are loaded from release.json manifests which include:
  - Device display names and firmware files
  - Upload configuration (protocol, MCU, speed, etc.)
  - No hardcoded device configurations

  The registry is a GenServer that maintains an ETS table with device configurations.
  """

  use GenServer
  require Logger

  alias Trenino.Firmware

  @table_name :firmware_device_registry

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
    case load_initial_devices() do
      {:ok, _count} ->
        :ok

      {:error, _reason} ->
        # No manifest in database - schedule a background fetch to self-heal.
        # This handles the case where releases were stored before manifest support
        # was added, or the database was freshly migrated.
        send(self(), :backfill_manifests)
    end

    {:ok, %{}}
  end

  @impl true
  def handle_info(:backfill_manifests, state) do
    Logger.info("No device manifest in database, fetching from GitHub")

    Task.start(fn ->
      try do
        case Firmware.Downloader.check_for_updates() do
          {:ok, _releases} ->
            Logger.info("Background manifest fetch completed successfully")

          {:error, reason} ->
            Logger.warning("Background manifest fetch failed: #{inspect(reason)}")
        end
      rescue
        e -> Logger.warning("Background manifest fetch error: #{Exception.message(e)}")
      end
    end)

    {:noreply, state}
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
         {:ok, upload_config} <- Map.fetch(device, "uploadConfig") do
      build_device_config(environment, display_name, firmware_file, upload_config)
    else
      :error ->
        log_invalid_device(device)
        nil
    end
  end

  defp build_device_config(environment, display_name, firmware_file, upload_config) do
    # Convert manifest field names to internal format
    # Manifest uses: protocol, mcu, speed, requires1200bpsTouch
    # Internal uses: programmer, mcu, baud_rate, use_1200bps_touch
    %{
      environment: environment,
      display_name: display_name,
      firmware_file: firmware_file,
      mcu: normalize_mcu(upload_config["mcu"]),
      programmer: upload_config["protocol"],
      baud_rate: upload_config["speed"],
      use_1200bps_touch: upload_config["requires1200bpsTouch"] || false
    }
  end

  # Convert full MCU names from manifest to avrdude short codes
  defp normalize_mcu(mcu) when is_binary(mcu) do
    case mcu do
      "atmega328p" -> "m328p"
      "atmega32u4" -> "m32u4"
      "atmega2560" -> "m2560"
      "at91sam3x8e" -> "at91sam3x8e"
      "esp32" -> "esp32"
      other -> other
    end
  end

  defp log_invalid_device(device) do
    env = Map.get(device, "environment", "unknown")
    upload_config = Map.get(device, "uploadConfig")

    if upload_config do
      Logger.warning("Manifest device missing required fields: #{inspect(device)}")
    else
      Logger.warning(
        "Manifest device '#{env}' missing uploadConfig - device will be skipped. " <>
          "uploadConfig is required for all devices in the manifest."
      )
    end
  end

  defp load_fallback_devices do
    Logger.error(
      "No firmware release manifest available. " <>
        "Please check for firmware updates to download device configurations. " <>
        "No devices will be available until a release manifest is loaded."
    )

    # Clear existing entries and leave registry empty
    :ets.delete_all_objects(@table_name)

    {:error, :no_manifest}
  end
end
