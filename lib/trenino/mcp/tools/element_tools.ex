defmodule Trenino.MCP.Tools.ElementTools do
  @moduledoc """
  MCP tools for managing train elements (buttons and levers).
  """

  alias Trenino.Train, as: TrainContext

  def tools do
    [
      %{
        name: "list_elements",
        description:
          "List all elements (buttons and levers) for a train. Returns id, name, and type for each element.",
        input_schema: %{
          type: "object",
          properties: %{
            train_id: %{type: "integer", description: "Train ID"}
          },
          required: ["train_id"]
        }
      },
      %{
        name: "create_element",
        description:
          "Create a new element (button or lever) on a train. " <>
            "Elements represent controls that can be bound to hardware inputs. " <>
            "After creating a button element, use create_button_binding to bind it to a hardware input.",
        input_schema: %{
          type: "object",
          properties: %{
            train_id: %{type: "integer", description: "Train ID"},
            name: %{type: "string", description: "Human-readable name, e.g. 'Horn Hi'"},
            type: %{
              type: "string",
              enum: ["button", "lever"],
              description: "Element type: 'button' for push buttons, 'lever' for analog controls"
            }
          },
          required: ["train_id", "name", "type"]
        }
      },
      %{
        name: "delete_element",
        description:
          "Delete an element from a train. This will also delete any associated button binding or lever config.",
        input_schema: %{
          type: "object",
          properties: %{
            id: %{type: "integer", description: "Element ID to delete"}
          },
          required: ["id"]
        }
      }
    ]
  end

  def execute("list_elements", %{"train_id" => train_id}) do
    {:ok, elements} = TrainContext.list_elements(train_id)

    {:ok,
     %{
       elements:
         Enum.map(elements, fn e ->
           %{id: e.id, name: e.name, type: e.type}
         end)
     }}
  end

  def execute("create_element", %{"train_id" => train_id, "name" => name, "type" => type}) do
    attrs = %{name: name, type: String.to_existing_atom(type)}

    case TrainContext.create_element(train_id, attrs) do
      {:ok, element} ->
        {:ok, %{element: %{id: element.id, name: element.name, type: element.type}}}

      {:error, changeset} ->
        {:error, format_changeset_errors(changeset)}
    end
  end

  def execute("delete_element", %{"id" => id}) do
    case TrainContext.get_element(id) do
      {:ok, element} ->
        case TrainContext.delete_element(element) do
          {:ok, _} -> {:ok, %{deleted: true, id: id}}
          {:error, changeset} -> {:error, format_changeset_errors(changeset)}
        end

      {:error, :not_found} ->
        {:error, "Element not found with id #{id}"}
    end
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
