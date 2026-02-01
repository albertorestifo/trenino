defmodule TreninoWeb.Api.SimulatorApiController do
  use TreninoWeb, :controller

  alias Trenino.Simulator.Client, as: SimulatorClient
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState

  def endpoints(conn, params) do
    path = Map.get(params, "path")

    case get_client() do
      {:ok, client} ->
        case SimulatorClient.list(client, path) do
          {:ok, data} -> json(conn, data)
          {:error, reason} -> conn |> put_status(502) |> json(%{error: inspect(reason)})
        end

      :error ->
        conn |> put_status(503) |> json(%{error: "simulator not connected"})
    end
  end

  def value(conn, %{"path" => path}) do
    case get_client() do
      {:ok, client} ->
        case SimulatorClient.get(client, path) do
          {:ok, data} -> json(conn, data)
          {:error, reason} -> conn |> put_status(502) |> json(%{error: inspect(reason)})
        end

      :error ->
        conn |> put_status(503) |> json(%{error: "simulator not connected"})
    end
  end

  def value(conn, _params) do
    conn |> put_status(400) |> json(%{error: "path parameter required"})
  end

  defp get_client do
    case SimulatorConnection.get_status() do
      %ConnectionState{status: :connected, client: client} when client != nil ->
        {:ok, client}

      _ ->
        :error
    end
  end
end
