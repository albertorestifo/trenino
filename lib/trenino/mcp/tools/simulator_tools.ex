defmodule Trenino.MCP.Tools.SimulatorTools do
  @moduledoc """
  MCP tools for browsing and interacting with the Train Sim World simulator API.
  """

  alias Trenino.Simulator.Client, as: SimulatorClient
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState

  def tools do
    [
      %{
        name: "list_simulator_endpoints",
        description:
          "Browse the simulator API tree at a given path. Returns child endpoints with their types. " <>
            "Use with no path to see the root, then drill into children. " <>
            "The simulator must be connected (Train Sim World running with External Interface enabled).",
        input_schema: %{
          type: "object",
          properties: %{
            path: %{
              type: "string",
              description:
                "API path to browse, e.g. 'CurrentDrivableActor'. Omit or leave empty for root."
            }
          }
        }
      },
      %{
        name: "get_simulator_value",
        description:
          "Read the current value of a simulator endpoint. " <>
            "Use list_simulator_endpoints first to discover available endpoints.",
        input_schema: %{
          type: "object",
          properties: %{
            path: %{
              type: "string",
              description:
                "Full endpoint path, e.g. 'CurrentDrivableActor/MasterController.InputValue'"
            }
          },
          required: ["path"]
        }
      },
      %{
        name: "set_simulator_value",
        description:
          "Write a value to a simulator endpoint. Use this to experiment with controls " <>
            "and understand what endpoints do before creating bindings.",
        input_schema: %{
          type: "object",
          properties: %{
            path: %{
              type: "string",
              description: "Full endpoint path to write to"
            },
            value: %{
              description: "Value to set (number, string, or boolean)"
            }
          },
          required: ["path", "value"]
        }
      }
    ]
  end

  def execute("list_simulator_endpoints", args) do
    path = Map.get(args, "path")

    with_client(fn client ->
      case SimulatorClient.list(client, path) do
        {:ok, data} -> {:ok, data}
        {:error, reason} -> {:error, "Simulator error: #{inspect(reason)}"}
      end
    end)
  end

  def execute("get_simulator_value", %{"path" => path}) do
    with_client(fn client ->
      case SimulatorClient.get(client, path) do
        {:ok, data} -> {:ok, data}
        {:error, reason} -> {:error, "Simulator error: #{inspect(reason)}"}
      end
    end)
  end

  def execute("set_simulator_value", %{"path" => path, "value" => value}) do
    with_client(fn client ->
      case SimulatorClient.set(client, path, value) do
        {:ok, data} -> {:ok, data}
        {:error, reason} -> {:error, "Simulator error: #{inspect(reason)}"}
      end
    end)
  end

  defp with_client(fun) do
    case SimulatorConnection.get_status() do
      %ConnectionState{status: :connected, client: client} when client != nil ->
        fun.(client)

      _ ->
        {:error,
         "Simulator not connected. Ensure Train Sim World is running with External Interface enabled."}
    end
  end
end
