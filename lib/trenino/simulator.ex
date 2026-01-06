defmodule Trenino.Simulator do
  @moduledoc """
  Context for Train Sim World API simulator configuration and management.

  Provides functions for managing the simulator configuration (URL and API key),
  auto-detecting configuration on Windows, and accessing connection status.
  """

  import Ecto.Query

  alias Trenino.Repo
  alias Trenino.Simulator.AutoConfig
  alias Trenino.Simulator.Config
  alias Trenino.Simulator.Connection

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

  # Delegate auto-configuration operations to AutoConfig module
  defdelegate auto_detect_api_key(), to: AutoConfig
  defdelegate auto_configure(), to: AutoConfig
  defdelegate default_url(), to: AutoConfig
  defdelegate windows?(), to: AutoConfig

  # Delegate connection operations to Connection module
  defdelegate subscribe(), to: Connection
  defdelegate get_status(), to: Connection
  defdelegate retry_connection(), to: Connection
end
