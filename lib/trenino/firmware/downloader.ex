defmodule Trenino.Firmware.Downloader do
  @moduledoc """
  Downloads firmware files from GitHub releases.

  Fetches release metadata from the GitHub API and downloads
  HEX files to the local firmware cache.
  """

  require Logger

  alias Trenino.Firmware
  alias Trenino.Firmware.{DeviceRegistry, FilePath, FirmwareFile}

  @github_repo "albertorestifo/trenino_firmware"
  @github_api_url "https://api.github.com/repos/#{@github_repo}/releases"

  @doc """
  Fetch releases from GitHub and store new ones in the database.

  Returns `{:ok, new_releases}` where new_releases is a list of
  newly created release records.
  """
  @spec check_for_updates() :: {:ok, [Firmware.FirmwareRelease.t()]} | {:error, term()}
  def check_for_updates do
    case fetch_github_releases() do
      {:ok, releases} ->
        new_releases =
          releases
          |> Enum.map(&parse_release/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.map(&store_release/1)
          |> Enum.filter(&match?({:ok, _}, &1))
          |> Enum.map(fn {:ok, release} -> release end)

        {:ok, new_releases}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Download a firmware file to the local cache.

  Returns `{:ok, firmware_file}` on success. The file is saved with a
  predictable name based on version and board type.
  """
  @spec download_firmware(integer()) :: {:ok, FirmwareFile.t()} | {:error, term()}
  def download_firmware(firmware_file_id) do
    with {:ok, file} <- Firmware.get_firmware_file(firmware_file_id, preload: [:firmware_release]),
         :ok <- FilePath.ensure_cache_dir(),
         destination <- FilePath.firmware_path(file),
         {:ok, _} <- download_file(file.download_url, destination) do
      {:ok, file}
    end
  end

  # GitHub API

  defp fetch_github_releases do
    Logger.info("Fetching firmware releases from GitHub")

    case Req.get(@github_api_url, headers: github_headers()) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: status, body: body}} ->
        Logger.error("GitHub API error: #{status} - #{inspect(body)}")
        {:error, {:github_api_error, status}}

      {:error, reason} ->
        Logger.error("Failed to fetch GitHub releases: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp github_headers do
    headers = [
      {"accept", "application/vnd.github.v3+json"},
      {"user-agent", "trenino/1.0"}
    ]

    # Add auth token if configured (for higher rate limits)
    case Application.get_env(:trenino, :github_token) do
      nil -> headers
      token -> [{"authorization", "token #{token}"} | headers]
    end
  end

  # Release parsing

  defp parse_release(release) do
    assets = release["assets"] || []
    tag_name = release["tag_name"]

    case fetch_and_parse_manifest(tag_name, assets) do
      nil ->
        Logger.warning("Release #{tag_name} has no valid manifest - skipping")
        nil

      manifest_data ->
        %{
          version: parse_version(tag_name),
          tag_name: tag_name,
          release_url: release["html_url"],
          release_notes: release["body"],
          published_at: parse_datetime(release["published_at"]),
          manifest_json: Jason.encode!(manifest_data),
          manifest: manifest_data,
          assets: parse_assets_from_manifest(assets, manifest_data)
        }
    end
  end

  defp parse_version("v" <> version), do: version
  defp parse_version(version), do: version

  defp parse_datetime(nil), do: nil

  defp parse_datetime(datetime_string) do
    case DateTime.from_iso8601(datetime_string) do
      {:ok, datetime, _offset} -> datetime
      _ -> nil
    end
  end

  # Manifest handling

  defp fetch_and_parse_manifest(tag_name, assets) do
    case find_manifest_asset(assets) do
      nil ->
        Logger.info("No release.json found for #{tag_name}")
        nil

      asset ->
        case download_manifest(asset["browser_download_url"]) do
          {:ok, manifest} ->
            Logger.info("Successfully fetched manifest for #{tag_name}")
            manifest

          {:error, reason} ->
            Logger.error("Failed to fetch manifest for #{tag_name}: #{inspect(reason)}")
            nil
        end
    end
  end

  defp find_manifest_asset(assets) do
    Enum.find(assets, fn asset ->
      asset["name"] == "release.json"
    end)
  end

  defp download_manifest(url) do
    case Req.get(url) do
      {:ok, %{status: 200, body: body}} ->
        validate_manifest(body)

      {:ok, %{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_manifest(data) when is_map(data) do
    required_fields = ["version", "project", "devices"]
    device_required_fields = ["environment", "displayName", "firmwareFile", "uploadConfig"]
    upload_config_required_fields = ["protocol", "mcu", "speed"]

    with :ok <- check_required_fields(data, required_fields),
         :ok <-
           validate_devices(
             data["devices"],
             device_required_fields,
             upload_config_required_fields
           ) do
      {:ok, data}
    else
      {:error, reason} ->
        Logger.warning("Invalid manifest structure: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp validate_manifest(_), do: {:error, :not_a_map}

  defp check_required_fields(data, fields) do
    missing = Enum.filter(fields, fn field -> not Map.has_key?(data, field) end)

    if missing == [] do
      :ok
    else
      {:error, {:missing_fields, missing}}
    end
  end

  defp validate_devices(devices, required_fields, upload_config_required_fields)
       when is_list(devices) do
    invalid =
      Enum.filter(devices, fn device ->
        cond do
          not is_map(device) ->
            true

          Enum.any?(required_fields, fn field -> not Map.has_key?(device, field) end) ->
            true

          not is_map(device["uploadConfig"]) ->
            true

          Enum.any?(upload_config_required_fields, fn field ->
            not Map.has_key?(device["uploadConfig"], field)
          end) ->
            true

          true ->
            false
        end
      end)

    if invalid == [] do
      :ok
    else
      {:error, {:invalid_devices, invalid}}
    end
  end

  defp validate_devices(_, _, _), do: {:error, :devices_not_a_list}

  # Asset parsing

  defp parse_assets_from_manifest(assets, manifest_data) do
    devices = manifest_data["devices"] || []

    Enum.map(devices, fn device ->
      filename = device["firmwareFile"]
      environment = device["environment"]

      # Find matching asset
      asset =
        Enum.find(assets, fn a ->
          a["name"] == filename
        end)

      if asset do
        %{
          filename: filename,
          download_url: asset["browser_download_url"],
          file_size: asset["size"],
          board_type: environment_to_board_type(environment),
          environment: environment
        }
      else
        Logger.warning("Manifest references missing asset: #{filename}")
        nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  # Convert environment name to legacy board_type atom for database compatibility
  # This maintains backward compatibility with existing database records
  defp environment_to_board_type(environment) do
    mapping = %{
      "uno" => :uno,
      "nanoatmega328new" => :nano,
      "leonardo" => :leonardo,
      "micro" => :micro,
      "sparkfun_promicro16" => :sparkfun_pro_micro,
      "megaatmega2560" => :mega2560,
      "due" => :due,
      "esp32dev" => :esp32
    }

    Map.get(mapping, environment, String.to_atom(environment))
  end

  # Database storage

  defp store_release(release_data) do
    case Firmware.upsert_release(Map.drop(release_data, [:assets, :manifest])) do
      {:ok, release} ->
        # Store firmware files for this release
        Enum.each(release_data.assets, fn asset ->
          store_firmware_file(release.id, asset)
        end)

        # Reload DeviceRegistry if we have a manifest
        if release_data.manifest do
          DeviceRegistry.reload_from_manifest(release_data.manifest, release.id)
        end

        {:ok, release}

      error ->
        error
    end
  end

  defp store_firmware_file(release_id, asset) do
    attrs = %{
      board_type: asset.board_type,
      environment: asset.environment,
      download_url: asset.download_url,
      file_size: asset.file_size
    }

    case Firmware.get_firmware_file_for_board(release_id, asset.board_type) do
      {:ok, existing} ->
        Firmware.update_firmware_file(existing, attrs)

      {:error, :not_found} ->
        Firmware.create_firmware_file(release_id, attrs)
    end
  end

  # File download

  defp download_file(url, destination) do
    Logger.info("Downloading firmware from #{url}")

    case Req.get(url, into: File.stream!(destination), decode_body: false) do
      {:ok, %{status: 200}} ->
        Logger.info("Downloaded firmware to #{destination}")
        {:ok, destination}

      {:ok, %{status: status}} ->
        File.rm(destination)
        {:error, {:download_failed, status}}

      {:error, reason} ->
        File.rm(destination)
        {:error, reason}
    end
  end
end
