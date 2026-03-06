defmodule Trenino.MCP.Tools.ScriptTools do
  @moduledoc """
  MCP tools for CRUD operations on Lua scripts.

  Scripts are Lua programs attached to train configurations that react to
  simulator API value changes and can control hardware outputs.
  """

  alias Trenino.Train, as: TrainContext

  def tools do
    [
      %{
        name: "list_scripts",
        description:
          "List all Lua scripts for a train. Returns script metadata (id, name, enabled, triggers) " <>
            "without the full code. Use get_script to retrieve the code for a specific script.",
        input_schema: %{
          type: "object",
          properties: %{
            train_id: %{type: "integer", description: "Train ID"}
          },
          required: ["train_id"]
        }
      },
      %{
        name: "get_script",
        description:
          "Get a Lua script by ID, including its full code, triggers, and enabled status.",
        input_schema: %{
          type: "object",
          properties: %{
            id: %{type: "integer", description: "Script ID"}
          },
          required: ["id"]
        }
      },
      %{
        name: "create_script",
        description:
          "Create a new Lua script for a train. Scripts must define an on_change(event) callback. " <>
            "Triggers are simulator endpoint paths that fire the script when their values change. " <>
            "Use list_simulator_endpoints to find valid trigger paths.",
        input_schema: %{
          type: "object",
          properties: %{
            train_id: %{type: "integer", description: "Train ID"},
            name: %{type: "string", description: "Human-readable name, e.g. 'Speed Warning'"},
            code: %{
              type: "string",
              description: "Lua source code. Must define function on_change(event)."
            },
            triggers: %{
              type: "array",
              description:
                "Simulator endpoint paths that trigger the script, " <>
                  "e.g. [\"CurrentDrivableActor/Throttle.InputValue\"]",
              items: %{type: "string"}
            },
            enabled: %{
              type: "boolean",
              description: "Whether the script is active (default: true)"
            }
          },
          required: ["train_id", "name", "code"]
        }
      },
      %{
        name: "update_script",
        description:
          "Update a Lua script's name, code, triggers, or enabled status. " <>
            "Only provided fields are changed.",
        input_schema: %{
          type: "object",
          properties: %{
            id: %{type: "integer", description: "Script ID"},
            name: %{type: "string", description: "New name"},
            code: %{type: "string", description: "New Lua source code"},
            triggers: %{
              type: "array",
              description: "New trigger endpoint paths",
              items: %{type: "string"}
            },
            enabled: %{type: "boolean", description: "Enable or disable the script"}
          },
          required: ["id"]
        }
      },
      %{
        name: "delete_script",
        description: "Delete a Lua script.",
        input_schema: %{
          type: "object",
          properties: %{
            id: %{type: "integer", description: "Script ID to delete"}
          },
          required: ["id"]
        }
      }
    ]
  end

  def execute("list_scripts", %{"train_id" => train_id}) do
    scripts =
      TrainContext.list_scripts(train_id)
      |> Enum.map(&serialize_summary/1)

    {:ok, %{scripts: scripts}}
  end

  def execute("get_script", %{"id" => id}) do
    case TrainContext.get_script(id) do
      {:ok, script} -> {:ok, %{script: serialize(script)}}
      {:error, :not_found} -> {:error, "Script not found with id #{id}"}
    end
  end

  def execute("create_script", %{"train_id" => train_id, "name" => name, "code" => code} = args) do
    attrs =
      %{name: name, code: code}
      |> maybe_put(:triggers, args["triggers"])
      |> maybe_put(:enabled, args["enabled"])

    case TrainContext.create_script(train_id, attrs) do
      {:ok, script} -> {:ok, %{script: serialize(script)}}
      {:error, %Ecto.Changeset{} = changeset} -> {:error, format_changeset_errors(changeset)}
    end
  end

  def execute("update_script", %{"id" => id} = args) do
    case TrainContext.get_script(id) do
      {:ok, script} ->
        attrs =
          %{}
          |> maybe_put(:name, args["name"])
          |> maybe_put(:code, args["code"])
          |> maybe_put(:triggers, args["triggers"])
          |> maybe_put(:enabled, args["enabled"])

        case TrainContext.update_script(script, attrs) do
          {:ok, updated} -> {:ok, %{script: serialize(updated)}}
          {:error, %Ecto.Changeset{} = changeset} -> {:error, format_changeset_errors(changeset)}
        end

      {:error, :not_found} ->
        {:error, "Script not found with id #{id}"}
    end
  end

  def execute("delete_script", %{"id" => id}) do
    case TrainContext.get_script(id) do
      {:ok, script} ->
        case TrainContext.delete_script(script) do
          {:ok, _} -> {:ok, %{deleted: true, id: id}}
          {:error, changeset} -> {:error, format_changeset_errors(changeset)}
        end

      {:error, :not_found} ->
        {:error, "Script not found with id #{id}"}
    end
  end

  defp serialize_summary(%Trenino.Train.Script{} = s) do
    %{
      id: s.id,
      train_id: s.train_id,
      name: s.name,
      enabled: s.enabled,
      triggers: s.triggers
    }
  end

  defp serialize(%Trenino.Train.Script{} = s) do
    %{
      id: s.id,
      train_id: s.train_id,
      name: s.name,
      enabled: s.enabled,
      code: s.code,
      triggers: s.triggers
    }
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

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
