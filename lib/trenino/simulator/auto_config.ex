defmodule Trenino.Simulator.AutoConfig do
  @moduledoc """
  Handles automatic configuration detection for the TSW API.

  Provides functions to:
  - Detect if running on Windows
  - Auto-detect the API key from the TSW configuration file
  - Create configuration from auto-detected values
  - Ensure configuration exists (with automatic detection on Windows)
  """

  import Ecto.Query

  alias Trenino.Repo
  alias Trenino.Simulator.Config

  @default_url "http://localhost:31270"

  @doc """
  Ensures configuration exists, auto-detecting on Windows if needed.

  This is the primary entry point for the Connection GenServer.
  It will:
  1. Return existing config if found
  2. On Windows: attempt auto-detection, save and return config if successful
  3. On non-Windows: return `{:error, :not_found}` immediately

  Returns `{:ok, config}` if configuration is available (existing or newly detected),
  or `{:error, reason}` if configuration cannot be determined.
  """
  @spec ensure_config() ::
          {:ok, Config.t()}
          | {:error, :not_found | :not_windows | :file_not_found | :read_error | term()}
  def ensure_config do
    case get_existing_config() do
      {:ok, config} ->
        {:ok, config}

      {:error, :not_found} ->
        maybe_auto_configure()
    end
  end

  @doc """
  Attempt to auto-detect the API key on Windows.

  Looks for CommAPIKey.txt in the default TSW location:
  `Documents/My Games/TrainSimWorld6/Saved/Config/CommAPIKey.txt`

  Returns `{:ok, api_key}` if found, `{:error, reason}` otherwise.
  """
  @spec auto_detect_api_key() ::
          {:ok, String.t()} | {:error, :not_windows | :file_not_found | :read_error}
  def auto_detect_api_key do
    if windows?() do
      detect_api_key_from_file()
    else
      {:error, :not_windows}
    end
  end

  @doc """
  Create a configuration from auto-detected values.

  Detects the API key and uses the default URL.
  """
  @spec auto_configure() ::
          {:ok, Config.t()}
          | {:error, :not_windows | :file_not_found | :read_error | Ecto.Changeset.t()}
  def auto_configure do
    with {:ok, api_key} <- auto_detect_api_key() do
      save_auto_detected_config(api_key)
    end
  end

  @doc """
  Get the default TSW API URL.
  """
  @spec default_url() :: String.t()
  def default_url, do: @default_url

  @doc """
  Check if the current platform is Windows.
  """
  @spec windows?() :: boolean()
  def windows? do
    case :os.type() do
      {:win32, _} -> true
      _ -> false
    end
  end

  # Private functions

  defp get_existing_config do
    case Repo.one(from c in Config, limit: 1) do
      nil -> {:error, :not_found}
      config -> {:ok, config}
    end
  end

  defp maybe_auto_configure do
    if windows?() do
      auto_configure()
    else
      {:error, :not_found}
    end
  end

  defp detect_api_key_from_file do
    case System.get_env("USERPROFILE") do
      nil ->
        {:error, :userprofile_not_set}

      userprofile ->
        path = api_key_file_path(userprofile)

        case File.read(path) do
          {:ok, content} ->
            api_key = String.trim(content)
            {:ok, api_key}

          {:error, :enoent} ->
            {:error, :file_not_found}

          {:error, _} ->
            {:error, :read_error}
        end
    end
  end

  defp api_key_file_path(userprofile) do
    Path.join([
      userprofile,
      "Documents",
      "My Games",
      "TrainSimWorld6",
      "Saved",
      "Config",
      "CommAPIKey.txt"
    ])
  end

  defp save_auto_detected_config(api_key) do
    attrs = %{
      url: default_url(),
      api_key: api_key,
      auto_detected: true
    }

    %Config{}
    |> Config.changeset(attrs)
    |> Repo.insert()
  end
end
