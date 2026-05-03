defmodule Trenino.MCP.Tools.DisplayBindingTools do
  @moduledoc "MCP tools for CRUD operations on display bindings."

  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.DisplayBinding
  alias Trenino.Train.DisplayController

  def tools do
    [
      %{
        name: "list_display_bindings",
        description: "List all display bindings for a train.",
        input_schema: %{
          type: "object",
          properties: %{train_id: %{type: "integer"}},
          required: ["train_id"]
        }
      },
      %{
        name: "create_display_binding",
        description:
          "Create a display binding that shows a simulator endpoint value on an I2C display. " <>
            "Use list_i2c_modules to find i2c_module_id. " <>
            "format_string tokens: '{value}' (raw), '{value:.Nf}' (float with N decimals). " <>
            "Example: '{value:.0f}' shows speed as integer.",
        input_schema: %{
          type: "object",
          properties: %{
            train_id: %{type: "integer"},
            name: %{type: "string", description: "e.g. 'Train speed'"},
            i2c_module_id: %{type: "integer"},
            endpoint: %{type: "string", description: "Simulator endpoint path"},
            format_string: %{type: "string", description: "e.g. '{value:.0f}' or '{value}'"},
            enabled: %{type: "boolean"}
          },
          required: ["train_id", "i2c_module_id", "endpoint", "format_string"]
        }
      },
      %{
        name: "update_display_binding",
        description: "Update an existing display binding.",
        input_schema: %{
          type: "object",
          properties: %{
            id: %{type: "integer"},
            name: %{type: "string"},
            i2c_module_id: %{type: "integer"},
            endpoint: %{type: "string"},
            format_string: %{type: "string"},
            enabled: %{type: "boolean"}
          },
          required: ["id"]
        }
      },
      %{
        name: "delete_display_binding",
        description: "Delete a display binding.",
        input_schema: %{
          type: "object",
          properties: %{id: %{type: "integer"}},
          required: ["id"]
        }
      }
    ]
  end

  def execute("list_display_bindings", %{"train_id" => train_id}) do
    bindings = TrainContext.list_display_bindings(train_id) |> Enum.map(&serialize/1)
    {:ok, %{display_bindings: bindings}}
  end

  def execute("create_display_binding", %{"train_id" => train_id} = args) do
    attrs = build_attrs(args)

    case TrainContext.create_display_binding(train_id, attrs) do
      {:ok, binding} ->
        DisplayController.reload_bindings()
        {:ok, %{display_binding: serialize(binding)}}

      {:error, changeset} ->
        {:error, format_changeset_errors(changeset)}
    end
  end

  def execute("update_display_binding", %{"id" => id} = args) do
    case TrainContext.get_display_binding(id) do
      {:ok, binding} ->
        case TrainContext.update_display_binding(binding, build_attrs(args)) do
          {:ok, updated} ->
            DisplayController.reload_bindings()
            {:ok, %{display_binding: serialize(updated)}}

          {:error, changeset} ->
            {:error, format_changeset_errors(changeset)}
        end

      {:error, :not_found} ->
        {:error, "Display binding not found with id #{id}"}
    end
  end

  def execute("delete_display_binding", %{"id" => id}) do
    case TrainContext.get_display_binding(id) do
      {:ok, binding} ->
        case TrainContext.delete_display_binding(binding) do
          {:ok, _} ->
            DisplayController.reload_bindings()
            {:ok, %{deleted: true, id: id}}

          {:error, changeset} ->
            {:error, format_changeset_errors(changeset)}
        end

      {:error, :not_found} ->
        {:error, "Display binding not found with id #{id}"}
    end
  end

  defp build_attrs(args) do
    args
    |> Map.take(["name", "i2c_module_id", "endpoint", "format_string", "enabled"])
    |> Enum.reduce(%{}, fn {k, v}, acc -> Map.put(acc, String.to_existing_atom(k), v) end)
  end

  defp serialize(%DisplayBinding{} = b) do
    %{
      id: b.id,
      train_id: b.train_id,
      i2c_module_id: b.i2c_module_id,
      name: b.name,
      endpoint: b.endpoint,
      format_string: b.format_string,
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
