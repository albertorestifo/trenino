defmodule Trenino.Simulator.Backend.TSW do
  @moduledoc """
  Train Sim World backend: wraps the TSW External Interface
  (`Trenino.Simulator.Client`). Its handle is a `%Client{}`.

  TSW has no control catalogue and no push: callers poll `read/2`, and
  levers are discovered with `Trenino.Simulator.LeverAnalyzer`.
  """

  @behaviour Trenino.Simulator.Backend

  alias Trenino.Simulator.Client
  alias Trenino.Train.Identifier

  @impl true
  def id, do: :tsw

  @impl true
  def capabilities, do: []

  @impl true
  def connect(%{url: url, api_key: api_key}) when is_binary(url) and is_binary(api_key),
    do: {:ok, Client.new(url, api_key)}

  def connect(_config), do: {:error, :needs_config}

  @impl true
  def check(%Client{} = client), do: Client.info(client)

  @impl true
  def disconnect(%Client{}), do: :ok

  @impl true
  def get(%Client{} = client, path) when is_binary(path) do
    with {:ok, response} <- Client.get(client, path), do: unwrap_values(response)
  end

  @impl true
  def read(%Client{} = client, paths) when is_list(paths) do
    values =
      Enum.reduce(paths, %{}, fn path, acc ->
        case get(client, path) do
          {:ok, value} -> Map.put(acc, path, value)
          {:error, _} -> acc
        end
      end)

    {:ok, values}
  end

  @impl true
  def set(%Client{} = client, path, value) when is_binary(path) do
    case Client.set(client, path, value) do
      {:ok, _response} -> :ok
      {:error, _} = error -> error
    end
  end

  @impl true
  def vehicle_id(%Client{} = client), do: Identifier.derive_from_formation(client)

  # TSW answers `{"Values": {"<name>": value}}`. A single value is returned
  # bare; several (e.g. a gauge's multi-value function) as the map.
  defp unwrap_values(%{"Values" => values}) when map_size(values) == 1,
    do: {:ok, values |> Map.values() |> hd()}

  defp unwrap_values(%{"Values" => values}) when is_map(values), do: {:ok, values}
  defp unwrap_values(response), do: {:error, {:unexpected_response, response}}
end
