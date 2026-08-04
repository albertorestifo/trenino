defmodule Trenino.MCP.Tools.VirtualJoystickTools do
  @moduledoc """
  MCP tools for virtual joystick mappings and lifecycle management.
  """

  alias Trenino.VirtualJoystick
  alias Trenino.VirtualJoystick.Mapping

  @axes ~w(x y z rx ry rz slider_1 slider_2)

  def tools do
    [
      tool("get_virtual_joystick_status", "Get virtual joystick runtime status.", empty_schema()),
      tool(
        "list_virtual_joystick_mappings",
        "List all hardware inputs mapped to the virtual joystick.",
        empty_schema()
      ),
      tool(
        "map_virtual_joystick_axis",
        "Create or update an analog input mapping to a virtual joystick axis.",
        axis_schema()
      ),
      tool(
        "map_virtual_joystick_button",
        "Create or update a button input mapping to a virtual joystick button.",
        button_schema()
      ),
      tool(
        "delete_virtual_joystick_mapping",
        "Delete a virtual joystick mapping.",
        id_schema()
      ),
      tool("enable_virtual_joystick", "Begin enabling the virtual joystick.", empty_schema()),
      tool("disable_virtual_joystick", "Begin disabling the virtual joystick.", empty_schema()),
      tool(
        "retry_virtual_joystick",
        "Retry virtual joystick setup or connection.",
        empty_schema()
      ),
      tool(
        "cleanup_virtual_joystick",
        "Begin removing a leftover virtual joystick device.",
        empty_schema()
      ),
      tool(
        "repair_virtual_joystick",
        "Repair virtual joystick setup after an error.",
        empty_schema()
      )
    ]
  end

  def execute("get_virtual_joystick_status", %{}) do
    details = status_details()
    {:ok, %{status: Atom.to_string(details.status), reason: reason(details.reason)}}
  end

  def execute("list_virtual_joystick_mappings", %{}) do
    {:ok, %{status: "ok", mappings: Enum.map(VirtualJoystick.list_mappings(), &serialize/1)}}
  end

  def execute("map_virtual_joystick_axis", %{"input_id" => input_id, "axis" => axis} = args) do
    attrs = %{
      target_type: :axis,
      axis: axis,
      device_index: Map.get(args, "device_index", 1),
      inverted: Map.get(args, "inverted", false)
    }

    put_mapping(input_id, attrs, args)
  end

  def execute(
        "map_virtual_joystick_button",
        %{"input_id" => input_id, "button" => button} = args
      ) do
    attrs = %{
      target_type: :button,
      button: button,
      device_index: Map.get(args, "device_index", 1)
    }

    put_mapping(input_id, attrs, args)
  end

  def execute("delete_virtual_joystick_mapping", %{"id" => id}) do
    case VirtualJoystick.delete_mapping(id) do
      {:ok, %Mapping{}} -> {:ok, %{status: "ok", reason: nil, deleted: true, id: id}}
      {:error, :not_found} -> error_result(:not_found)
      {:error, %Ecto.Changeset{} = changeset} -> validation_result(changeset)
    end
  end

  def execute("enable_virtual_joystick", %{}), do: lifecycle(:enable)
  def execute("disable_virtual_joystick", %{}), do: lifecycle(:disable)
  def execute("retry_virtual_joystick", %{}), do: lifecycle(:retry)
  def execute("cleanup_virtual_joystick", %{}), do: lifecycle(:remove_leftover)
  def execute("repair_virtual_joystick", %{}), do: lifecycle(:repair)

  defp tool(name, description, schema),
    do: %{name: name, description: description, input_schema: schema}

  defp empty_schema,
    do: %{type: "object", properties: %{}, required: [], additionalProperties: false}

  defp id_schema do
    %{
      type: "object",
      properties: %{id: %{type: "integer", description: "Virtual joystick mapping ID"}},
      required: ["id"],
      additionalProperties: false
    }
  end

  defp axis_schema do
    %{
      type: "object",
      properties: %{
        input_id: %{type: "integer", description: "Hardware input ID"},
        device_index: %{type: "integer", enum: [1], description: "Virtual device index"},
        axis: %{type: "string", enum: @axes, description: "Virtual joystick axis"},
        inverted: %{type: "boolean", description: "Invert the axis direction"},
        replace: %{
          type: "boolean",
          description: "Replace an existing simulator/API destination"
        }
      },
      required: ["input_id", "axis"],
      additionalProperties: false
    }
  end

  defp button_schema do
    %{
      type: "object",
      properties: %{
        input_id: %{type: "integer", description: "Hardware input ID"},
        device_index: %{type: "integer", enum: [1], description: "Virtual device index"},
        button: %{type: "integer", minimum: 1, maximum: 32},
        replace: %{
          type: "boolean",
          description: "Replace an existing simulator/API destination"
        }
      },
      required: ["input_id", "button"],
      additionalProperties: false
    }
  end

  defp put_mapping(input_id, attrs, args) do
    case VirtualJoystick.put_mapping(input_id, attrs, replace?: Map.get(args, "replace", false)) do
      {:ok, %Mapping{} = mapping} ->
        VirtualJoystick.reload_mappings()
        {:ok, %{status: "ok", reason: nil, mapping: serialize(mapping)}}

      {:error, :destination_conflict} ->
        error_result(:destination_conflict)

      {:error, :not_found} ->
        error_result(:not_found)

      {:error, %Ecto.Changeset{} = changeset} ->
        validation_result(changeset)
    end
  end

  defp lifecycle(command) do
    result =
      if Process.whereis(Trenino.VirtualJoystick.Manager) do
        apply(VirtualJoystick, command, [])
      else
        {:error, :unsupported}
      end

    case result do
      :ok -> {:ok, %{status: "accepted", reason: nil}}
      {:error, reason} -> error_result(reason)
    end
  end

  defp status_details do
    if Process.whereis(Trenino.VirtualJoystick.Manager) do
      VirtualJoystick.status_details()
    else
      %{status: :unsupported, reason: nil}
    end
  end

  defp validation_result(%Ecto.Changeset{} = changeset) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {message, options} ->
        Enum.reduce(options, message, fn {key, value}, text ->
          String.replace(text, "%{#{key}}", to_string(value))
        end)
      end)

    {:ok, %{status: "error", reason: %{code: "validation_failed", errors: errors}}}
  end

  defp error_result(reason),
    do: {:ok, %{status: "error", reason: reason(reason)}}

  defp reason(nil), do: nil
  defp reason(reason) when is_atom(reason), do: %{code: Atom.to_string(reason)}

  defp reason({code, details}) when is_atom(code),
    do: %{code: Atom.to_string(code), details: inspect(details)}

  defp reason(reason), do: %{code: "runtime_error", details: inspect(reason)}

  defp serialize(%Mapping{} = mapping) do
    %{
      id: mapping.id,
      input_id: mapping.input_id,
      device_index: mapping.device_index,
      target_type: Atom.to_string(mapping.target_type),
      axis: optional_atom(mapping.axis),
      button: mapping.button,
      inverted: mapping.inverted
    }
  end

  defp optional_atom(nil), do: nil
  defp optional_atom(value), do: Atom.to_string(value)
end
