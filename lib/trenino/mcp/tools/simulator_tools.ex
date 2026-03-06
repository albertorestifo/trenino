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
          "Browse the simulator API tree at a given path. The response contains two key sections: " <>
            "'Nodes' are child containers navigated with '/' (e.g. 'CurrentDrivableActor/AWS'), " <>
            "and 'Endpoints' are leaf values on the current node (e.g. 'Property.IsPlayer', 'Function.CanOperateDoors', 'InputValue'). " <>
            "To read an endpoint value, use get_simulator_value with the node path joined to the endpoint name using '.' (dot), " <>
            "e.g. 'CurrentDrivableActor.Function.CanOperateDoors' or 'CurrentDrivableActor/AWS.Function.IsWarningSound'. " <>
            "Use with no path to see the root, then drill into children.",
        input_schema: %{
          type: "object",
          properties: %{
            path: %{
              type: "string",
              description:
                "Node path to browse, e.g. 'CurrentDrivableActor' or 'CurrentDrivableActor/AWS'. Omit or leave empty for root."
            }
          }
        }
      },
      %{
        name: "get_simulator_value",
        description:
          "Read the current value of a simulator endpoint. " <>
            "Use list_simulator_endpoints first to discover available nodes and endpoints. " <>
            "Path format: 'NodePath.EndpointName' — use '/' to separate nodes, '.' to separate the final node from the endpoint. " <>
            "Examples: 'CurrentDrivableActor.Function.CanOperateDoors', " <>
            "'CurrentDrivableActor/AWS.Function.IsWarningSound', " <>
            "'CurrentDrivableActor/PassengerDoor_FL.Function.GetNormalisedOutputValue'.",
        input_schema: %{
          type: "object",
          properties: %{
            path: %{
              type: "string",
              description:
                "Full path: node path + '.' + endpoint name, e.g. 'CurrentDrivableActor/AWS.Function.IsWarningSound'"
            }
          },
          required: ["path"]
        }
      },
      %{
        name: "set_simulator_value",
        description:
          "Write a value to a writable simulator endpoint. Use list_simulator_endpoints to find writable endpoints " <>
            "(marked Writable: true, e.g. 'InputValue'). " <>
            "Path format is the same as get_simulator_value: 'NodePath.EndpointName'.",
        input_schema: %{
          type: "object",
          properties: %{
            path: %{
              type: "string",
              description:
                "Full path: node path + '.' + endpoint name, e.g. 'CurrentDrivableActor/ThrottleAndBrake (Irregular Lever).InputValue'"
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
