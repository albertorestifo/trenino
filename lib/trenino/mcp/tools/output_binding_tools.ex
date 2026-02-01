defmodule Trenino.MCP.Tools.OutputBindingTools do
  @moduledoc """
  MCP tools for CRUD operations on output bindings.

  Output bindings monitor simulator endpoint values and control hardware
  outputs (LEDs) based on conditions.
  """

  alias Trenino.Train, as: TrainContext

  def tools do
    [
      %{
        name: "list_output_bindings",
        description:
          "List all output bindings for a train. Each binding monitors a simulator endpoint " <>
            "and controls a hardware output (LED) based on a condition.",
        input_schema: %{
          type: "object",
          properties: %{
            train_id: %{type: "integer", description: "Train ID"}
          },
          required: ["train_id"]
        }
      },
      %{
        name: "create_output_binding",
        description:
          "Create an output binding that controls a hardware output (LED) based on a simulator endpoint value. " <>
            "Use list_simulator_endpoints to find endpoints and list_hardware_outputs to find available outputs. " <>
            "Operators: 'gt' (>), 'gte' (>=), 'lt' (<), 'lte' (<=), 'between' (range), " <>
            "'eq_true' (boolean true), 'eq_false' (boolean false).",
        input_schema: %{
          type: "object",
          properties: %{
            train_id: %{type: "integer", description: "Train ID"},
            name: %{type: "string", description: "Human-readable name, e.g. 'Brake warning LED'"},
            output_id: %{
              type: "integer",
              description: "Hardware output ID from list_hardware_outputs"
            },
            endpoint: %{type: "string", description: "Simulator endpoint path to monitor"},
            operator: %{
              type: "string",
              enum: ["gt", "gte", "lt", "lte", "between", "eq_true", "eq_false"],
              description: "Comparison operator"
            },
            value_a: %{
              type: "number",
              description:
                "Threshold value for numeric operators (not needed for eq_true/eq_false)"
            },
            value_b: %{
              type: "number",
              description: "Upper threshold (only for 'between' operator)"
            },
            enabled: %{
              type: "boolean",
              description: "Whether the binding is active (default: true)"
            }
          },
          required: ["train_id", "name", "output_id", "endpoint", "operator"]
        }
      },
      %{
        name: "update_output_binding",
        description:
          "Update an existing output binding. Only provide the fields you want to change.",
        input_schema: %{
          type: "object",
          properties: %{
            id: %{type: "integer", description: "Output binding ID"},
            name: %{type: "string", description: "Human-readable name"},
            output_id: %{type: "integer", description: "Hardware output ID"},
            endpoint: %{type: "string", description: "Simulator endpoint path"},
            operator: %{
              type: "string",
              enum: ["gt", "gte", "lt", "lte", "between", "eq_true", "eq_false"]
            },
            value_a: %{type: "number", description: "Threshold value"},
            value_b: %{type: "number", description: "Upper threshold (for 'between')"},
            enabled: %{type: "boolean", description: "Whether the binding is active"}
          },
          required: ["id"]
        }
      },
      %{
        name: "delete_output_binding",
        description: "Delete an output binding.",
        input_schema: %{
          type: "object",
          properties: %{
            id: %{type: "integer", description: "Output binding ID to delete"}
          },
          required: ["id"]
        }
      }
    ]
  end

  def execute("list_output_bindings", %{"train_id" => train_id}) do
    bindings =
      TrainContext.list_output_bindings(train_id)
      |> Enum.map(&serialize/1)

    {:ok, %{output_bindings: bindings}}
  end

  def execute("create_output_binding", %{"train_id" => train_id} = args) do
    attrs = build_attrs(args)

    case TrainContext.create_output_binding(train_id, attrs) do
      {:ok, binding} -> {:ok, %{output_binding: serialize(binding)}}
      {:error, changeset} -> {:error, format_changeset_errors(changeset)}
    end
  end

  def execute("update_output_binding", %{"id" => id} = args) do
    case TrainContext.get_output_binding(id) do
      {:ok, binding} ->
        attrs = build_attrs(args)

        case TrainContext.update_output_binding(binding, attrs) do
          {:ok, updated} -> {:ok, %{output_binding: serialize(updated)}}
          {:error, changeset} -> {:error, format_changeset_errors(changeset)}
        end

      {:error, :not_found} ->
        {:error, "Output binding not found with id #{id}"}
    end
  end

  def execute("delete_output_binding", %{"id" => id}) do
    case TrainContext.get_output_binding(id) do
      {:ok, binding} ->
        case TrainContext.delete_output_binding(binding) do
          {:ok, _} -> {:ok, %{deleted: true, id: id}}
          {:error, changeset} -> {:error, format_changeset_errors(changeset)}
        end

      {:error, :not_found} ->
        {:error, "Output binding not found with id #{id}"}
    end
  end

  defp build_attrs(args) do
    args
    |> Map.take(["name", "output_id", "endpoint", "operator", "value_a", "value_b", "enabled"])
    |> Enum.reduce(%{}, fn
      {"operator", v}, acc -> Map.put(acc, :operator, String.to_existing_atom(v))
      {k, v}, acc -> Map.put(acc, String.to_existing_atom(k), v)
    end)
  end

  defp serialize(b) do
    %{
      id: b.id,
      train_id: b.train_id,
      name: b.name,
      output_id: b.output_id,
      endpoint: b.endpoint,
      operator: b.operator,
      value_a: b.value_a,
      value_b: b.value_b,
      enabled: b.enabled
    }
  end

  defp format_changeset_errors(changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)

    "Validation failed: " <>
      Enum.map_join(errors, "; ", fn {field, messages} ->
        "#{field} #{Enum.join(messages, ", ")}"
      end)
  end
end
