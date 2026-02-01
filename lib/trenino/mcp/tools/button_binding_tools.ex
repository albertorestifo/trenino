defmodule Trenino.MCP.Tools.ButtonBindingTools do
  @moduledoc """
  MCP tools for CRUD operations on button input bindings.

  Button bindings connect hardware inputs (physical buttons) to train
  button elements with configurable behavior modes.
  """

  alias Trenino.Train, as: TrainContext

  def tools do
    [
      %{
        name: "get_button_binding",
        description:
          "Get the button binding for a specific button element. " <>
            "Returns the binding configuration including mode, endpoint, and values.",
        input_schema: %{
          type: "object",
          properties: %{
            element_id: %{type: "integer", description: "Button element ID from get_train"}
          },
          required: ["element_id"]
        }
      },
      %{
        name: "create_button_binding",
        description:
          "Bind a hardware input to a button element. Modes:\n" <>
            "- 'simple': Send on_value when pressed, off_value when released (requires endpoint)\n" <>
            "- 'momentary': Repeat on_value at interval while held (requires endpoint, repeat_interval_ms)\n" <>
            "- 'sequence': Execute command sequences on press/release (requires on_sequence_id and/or off_sequence_id)\n" <>
            "- 'keystroke': Simulate a keyboard key press (requires keystroke, e.g. 'W' or 'CTRL+S')\n\n" <>
            "Use list_device_inputs to find input IDs and get_train to find button element IDs.",
        input_schema: %{
          type: "object",
          properties: %{
            element_id: %{type: "integer", description: "Button element ID from get_train"},
            input_id: %{type: "integer", description: "Hardware input ID from list_device_inputs"},
            mode: %{
              type: "string",
              enum: ["simple", "momentary", "sequence", "keystroke"],
              description: "Button behavior mode"
            },
            endpoint: %{
              type: "string",
              description: "Simulator endpoint (required for simple/momentary modes)"
            },
            on_value: %{type: "number", description: "Value sent when pressed (default: 1.0)"},
            off_value: %{type: "number", description: "Value sent when released (default: 0.0)"},
            keystroke: %{
              type: "string",
              description: "Key combo for keystroke mode, e.g. 'W', 'CTRL+S'"
            },
            on_sequence_id: %{
              type: "integer",
              description: "Sequence ID to execute on press (for sequence mode)"
            },
            off_sequence_id: %{
              type: "integer",
              description:
                "Sequence ID to execute on release (for sequence mode, latching buttons only)"
            },
            repeat_interval_ms: %{
              type: "integer",
              description: "Repeat interval in ms for momentary mode (100-5000, default: 100)"
            },
            hardware_type: %{
              type: "string",
              enum: ["momentary", "latching"],
              description: "Physical button type (default: momentary)"
            }
          },
          required: ["element_id", "input_id", "mode"]
        }
      },
      %{
        name: "update_button_binding",
        description:
          "Update an existing button binding. Only provide the fields you want to change.",
        input_schema: %{
          type: "object",
          properties: %{
            element_id: %{type: "integer", description: "Button element ID"},
            mode: %{type: "string", enum: ["simple", "momentary", "sequence", "keystroke"]},
            endpoint: %{type: "string", description: "Simulator endpoint"},
            on_value: %{type: "number"},
            off_value: %{type: "number"},
            keystroke: %{type: "string"},
            on_sequence_id: %{type: "integer"},
            off_sequence_id: %{type: "integer"},
            repeat_interval_ms: %{type: "integer"},
            hardware_type: %{type: "string", enum: ["momentary", "latching"]},
            enabled: %{type: "boolean", description: "Whether the binding is active"}
          },
          required: ["element_id"]
        }
      },
      %{
        name: "delete_button_binding",
        description: "Remove a button binding from a button element.",
        input_schema: %{
          type: "object",
          properties: %{
            element_id: %{type: "integer", description: "Button element ID"}
          },
          required: ["element_id"]
        }
      }
    ]
  end

  def execute("get_button_binding", %{"element_id" => element_id}) do
    case TrainContext.get_button_binding(element_id) do
      {:ok, binding} -> {:ok, %{button_binding: serialize(binding)}}
      {:error, :not_found} -> {:error, "No button binding found for element #{element_id}"}
    end
  end

  def execute(
        "create_button_binding",
        %{"element_id" => element_id, "input_id" => input_id} = args
      ) do
    attrs = build_attrs(args)

    case TrainContext.create_button_binding(element_id, input_id, attrs) do
      {:ok, binding} -> {:ok, %{button_binding: serialize(binding)}}
      {:error, changeset} -> {:error, format_changeset_errors(changeset)}
    end
  end

  def execute("update_button_binding", %{"element_id" => element_id} = args) do
    case TrainContext.get_button_binding(element_id) do
      {:ok, binding} ->
        attrs = build_attrs(args)

        case TrainContext.update_button_binding(binding, attrs) do
          {:ok, updated} -> {:ok, %{button_binding: serialize(updated)}}
          {:error, changeset} -> {:error, format_changeset_errors(changeset)}
        end

      {:error, :not_found} ->
        {:error, "No button binding found for element #{element_id}"}
    end
  end

  def execute("delete_button_binding", %{"element_id" => element_id}) do
    case TrainContext.delete_button_binding(element_id) do
      :ok -> {:ok, %{deleted: true, element_id: element_id}}
      {:error, :not_found} -> {:error, "No button binding found for element #{element_id}"}
    end
  end

  defp build_attrs(args) do
    args
    |> Map.take([
      "mode",
      "endpoint",
      "on_value",
      "off_value",
      "keystroke",
      "on_sequence_id",
      "off_sequence_id",
      "repeat_interval_ms",
      "hardware_type",
      "enabled"
    ])
    |> Enum.reduce(%{}, fn
      {"mode", v}, acc -> Map.put(acc, :mode, String.to_existing_atom(v))
      {"hardware_type", v}, acc -> Map.put(acc, :hardware_type, String.to_existing_atom(v))
      {k, v}, acc -> Map.put(acc, String.to_existing_atom(k), v)
    end)
  end

  defp serialize(b) do
    %{
      id: b.id,
      element_id: b.element_id,
      input_id: b.input_id,
      mode: b.mode,
      endpoint: b.endpoint,
      on_value: b.on_value,
      off_value: b.off_value,
      enabled: b.enabled,
      hardware_type: b.hardware_type,
      keystroke: b.keystroke,
      repeat_interval_ms: b.repeat_interval_ms,
      on_sequence_id: b.on_sequence_id,
      off_sequence_id: b.off_sequence_id
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
