defmodule Trenino.Simulator do
  @moduledoc """
  Context for the connected train simulator (Train Sim World or SimRail).

  Everything outside `Trenino.Simulator.*` talks to the simulator through
  this module, never through a backend or `Trenino.Simulator.Client`
  directly. Each simulator implements `Trenino.Simulator.Backend`; the
  connected backend and its handle live in the connection state.

  Configuration (URL and API key) is stored in `Trenino.Settings`.

  ## Watching values

  Pushed or polled value changes are delivered as
  `{:simulator_values, %{path => value}}` messages and vehicle changes as
  `{:simulator_vehicle, vehicle_id | nil}`; see `Trenino.Simulator.Backend.watch/3`.
  """

  alias Trenino.Settings.Simulator, as: SettingsSimulator
  alias Trenino.Simulator.{Backend, Connection, ConnectionState, Control}

  @type simulator :: :tsw | :simrail

  defdelegate windows?(), to: SettingsSimulator

  # Delegate connection operations to Connection module
  defdelegate subscribe(), to: Connection
  defdelegate get_status(), to: Connection
  defdelegate retry_connection(), to: Connection

  @doc "The connected backend and its handle."
  @spec connected() :: {:ok, module(), Backend.handle()} | {:error, :not_connected}
  def connected do
    case Connection.get_status() do
      %ConnectionState{status: :connected, backend: backend, client: handle}
      when not is_nil(handle) ->
        {:ok, backend, handle}

      _ ->
        {:error, :not_connected}
    end
  end

  @doc "The connected simulator, or nil."
  @spec current() :: simulator() | nil
  def current do
    case connected() do
      {:ok, backend, _handle} -> backend.id()
      {:error, :not_connected} -> nil
    end
  end

  @doc "Whether the connected backend has `capability`."
  @spec supports?(Backend.capability()) :: boolean()
  def supports?(capability) do
    case connected() do
      {:ok, backend, _handle} -> capability in backend.capabilities()
      {:error, :not_connected} -> false
    end
  end

  @doc "Read one value."
  @spec get(Backend.path()) :: {:ok, Backend.value()} | {:error, term()}
  def get(path) when is_binary(path) do
    with {:ok, backend, handle} <- connected(), do: backend.get(handle, path)
  end

  @doc "Read several values; missing paths are left out."
  @spec read([Backend.path()]) :: {:ok, %{Backend.path() => Backend.value()}} | {:error, term()}
  def read(paths) when is_list(paths) do
    with {:ok, backend, handle} <- connected(), do: backend.read(handle, paths)
  end

  @doc "Write one value."
  @spec set(Backend.path(), Backend.value()) :: :ok | {:error, term()}
  def set(path, value) when is_binary(path) do
    with {:ok, backend, handle} <- connected(), do: backend.set(handle, path, value)
  end

  @doc "Identify the vehicle the player is driving."
  @spec vehicle_id() :: {:ok, String.t()} | {:error, term()}
  def vehicle_id do
    with {:ok, backend, handle} <- connected(), do: backend.vehicle_id(handle)
  end

  @doc "The player vehicle's controls, for backends with `:control_catalog`."
  @spec controls() :: {:ok, [Control.t()]} | {:error, term()}
  def controls do
    with {:ok, backend, handle} <- connected() do
      if :control_catalog in backend.capabilities(),
        do: backend.controls(handle),
        else: {:error, :not_supported}
    end
  end
end
