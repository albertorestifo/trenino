defmodule TswIo.Simulator do
  @moduledoc """
  Context for Train Sim World API simulator configuration and management.

  Provides functions for managing the simulator configuration (URL and API key),
  auto-detecting configuration on Windows, and accessing connection status.
  """

  import Ecto.Query

  alias TswIo.Repo
  alias TswIo.Simulator.Config
  alias TswIo.Simulator.Connection

  @default_url "http://localhost:31270"

  @doc """
  Get the current simulator configuration.

  Returns the single configuration record if it exists.
  """
  @spec get_config() :: {:ok, Config.t()} | {:error, :not_found}
  def get_config do
    case Repo.one(from c in Config, limit: 1) do
      nil -> {:error, :not_found}
      config -> {:ok, config}
    end
  end

  @doc """
  Create or update the simulator configuration.

  Only one configuration is allowed. If one exists, it will be updated.
  """
  @spec save_config(map()) :: {:ok, Config.t()} | {:error, Ecto.Changeset.t()}
  def save_config(attrs) do
    case get_config() do
      {:ok, existing} ->
        update_config(existing, attrs)

      {:error, :not_found} ->
        create_config(attrs)
    end
  end

  @doc """
  Create a new simulator configuration.
  """
  @spec create_config(map()) :: {:ok, Config.t()} | {:error, Ecto.Changeset.t()}
  def create_config(attrs) do
    result =
      %Config{}
      |> Config.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, config} ->
        Connection.reconfigure()
        {:ok, config}

      error ->
        error
    end
  end

  @doc """
  Update an existing simulator configuration.
  """
  @spec update_config(Config.t(), map()) :: {:ok, Config.t()} | {:error, Ecto.Changeset.t()}
  def update_config(%Config{} = config, attrs) do
    result =
      config
      |> Config.changeset(attrs)
      |> Repo.update()

    case result do
      {:ok, updated_config} ->
        Connection.reconfigure()
        {:ok, updated_config}

      error ->
        error
    end
  end

  @doc """
  Delete the simulator configuration.
  """
  @spec delete_config(Config.t()) :: {:ok, Config.t()} | {:error, Ecto.Changeset.t()}
  def delete_config(%Config{} = config) do
    result = Repo.delete(config)

    case result do
      {:ok, _} ->
        Connection.disconnect()
        result

      error ->
        error
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
      case System.get_env("USERPROFILE") do
        nil ->
          {:error, :userprofile_not_set}

        userprofile ->
          path =
            Path.join([
              userprofile,
              "Documents",
              "My Games",
              "TrainSimWorld6",
              "Saved",
              "Config",
              "CommAPIKey.txt"
            ])

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
      save_config(%{
        url: default_url(),
        api_key: api_key,
        auto_detected: true
      })
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

  # Delegate connection operations to Connection module
  defdelegate subscribe(), to: Connection
  defdelegate get_status(), to: Connection
  defdelegate retry_connection(), to: Connection
end
