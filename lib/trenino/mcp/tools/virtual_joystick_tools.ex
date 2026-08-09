defmodule Trenino.MCP.Tools.VirtualJoystickTools do
  @moduledoc """
  MCP tools for virtual joystick mappings and lifecycle management.
  """

  alias Trenino.VirtualJoystick
  alias Trenino.VirtualJoystick.{Mapping, Platform}

  @axes ~w(x y z rx ry rz slider_1 slider_2)
  @empty_tools ~w(
    get_virtual_joystick_status
    list_virtual_joystick_mappings
    enable_virtual_joystick
    disable_virtual_joystick
    retry_virtual_joystick
    cleanup_virtual_joystick
    check_virtual_joystick_installation
  )

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
        "check_virtual_joystick_installation",
        "Recheck the vJoy installation after the user completes driver repair.",
        empty_schema()
      )
    ]
  end

  def execute(name, arguments) when is_binary(name) do
    case validate_arguments(name, arguments) do
      :ok -> do_execute(name, arguments)
      {:error, errors} -> validation_result(errors)
    end
  end

  defp do_execute("get_virtual_joystick_status", %{}) do
    details = status_details()
    {:ok, %{status: Atom.to_string(details.status), reason: reason(details.reason)}}
  end

  defp do_execute("list_virtual_joystick_mappings", %{}) do
    {:ok, %{status: "ok", mappings: Enum.map(VirtualJoystick.list_mappings(), &serialize/1)}}
  end

  defp do_execute(
         "map_virtual_joystick_axis",
         %{"input_id" => input_id, "axis" => axis} = args
       ) do
    attrs = %{
      target_type: :axis,
      axis: axis,
      device_index: Map.get(args, "device_index", 1),
      inverted: Map.get(args, "inverted", false)
    }

    put_mapping(input_id, attrs, args)
  end

  defp do_execute(
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

  defp do_execute("delete_virtual_joystick_mapping", %{"id" => id}) do
    case VirtualJoystick.delete_mapping(id) do
      {:ok, %Mapping{}} -> {:ok, %{status: "ok", reason: nil, deleted: true, id: id}}
      {:error, :not_found} -> error_result(:not_found)
      {:error, %Ecto.Changeset{} = changeset} -> validation_result(changeset)
    end
  end

  defp do_execute("enable_virtual_joystick", %{}), do: lifecycle(:enable)
  defp do_execute("disable_virtual_joystick", %{}), do: lifecycle(:disable)
  defp do_execute("retry_virtual_joystick", %{}), do: lifecycle(:retry)
  defp do_execute("cleanup_virtual_joystick", %{}), do: lifecycle(:remove_leftover)
  defp do_execute("check_virtual_joystick_installation", %{}), do: lifecycle(:repair)

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

  defp validate_arguments(name, arguments) when name in @empty_tools do
    validate_object(arguments, [], [])
  end

  defp validate_arguments("map_virtual_joystick_axis", arguments) do
    with :ok <-
           validate_object(
             arguments,
             ["input_id", "axis"],
             ["device_index", "inverted", "replace"]
           ) do
      errors =
        []
        |> require_type(arguments, "input_id", &is_integer/1, "must be an integer")
        |> require_value(arguments, "axis", &(&1 in @axes), "must be a supported axis")
        |> optional_value(
          arguments,
          "device_index",
          &(is_integer(&1) and &1 === 1),
          "must be the integer 1"
        )
        |> optional_value(arguments, "inverted", &is_boolean/1, "must be a boolean")
        |> optional_value(arguments, "replace", &is_boolean/1, "must be a boolean")

      validation_outcome(errors)
    end
  end

  defp validate_arguments("map_virtual_joystick_button", arguments) do
    with :ok <-
           validate_object(
             arguments,
             ["input_id", "button"],
             ["device_index", "replace"]
           ) do
      errors =
        []
        |> require_type(arguments, "input_id", &is_integer/1, "must be an integer")
        |> require_value(
          arguments,
          "button",
          &(is_integer(&1) and &1 in 1..32),
          "must be an integer from 1 to 32"
        )
        |> optional_value(
          arguments,
          "device_index",
          &(is_integer(&1) and &1 === 1),
          "must be the integer 1"
        )
        |> optional_value(arguments, "replace", &is_boolean/1, "must be a boolean")

      validation_outcome(errors)
    end
  end

  defp validate_arguments("delete_virtual_joystick_mapping", arguments) do
    with :ok <- validate_object(arguments, ["id"], []) do
      []
      |> require_type(arguments, "id", &is_integer/1, "must be an integer")
      |> validation_outcome()
    end
  end

  defp validate_object(arguments, required, optional) when is_map(arguments) do
    keys = Map.keys(arguments)
    missing = required -- keys
    extra = keys -- (required ++ optional)

    errors =
      Enum.map(missing, &%{field: &1, message: "is required"}) ++
        Enum.map(extra, &%{field: &1, message: "is not allowed"})

    validation_outcome(errors)
  end

  defp validate_object(_arguments, _required, _optional),
    do: {:error, [%{field: "arguments", message: "must be an object"}]}

  defp require_type(errors, arguments, field, predicate, message),
    do: require_value(errors, arguments, field, predicate, message)

  defp require_value(errors, arguments, field, predicate, message) do
    case Map.fetch(arguments, field) do
      {:ok, value} -> if predicate.(value), do: errors, else: add_error(errors, field, message)
      :error -> errors
    end
  end

  defp optional_value(errors, arguments, field, predicate, message),
    do: require_value(errors, arguments, field, predicate, message)

  defp add_error(errors, field, message), do: [%{field: field, message: message} | errors]

  defp validation_outcome([]), do: :ok
  defp validation_outcome(errors), do: {:error, Enum.reverse(errors)}

  defp lifecycle(command) do
    result =
      if Process.whereis(Trenino.VirtualJoystick.Manager) do
        apply(VirtualJoystick, command, [])
      else
        if platform().windows?(), do: {:error, :runtime_unavailable}, else: {:error, :unsupported}
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
      if platform().windows?() do
        %{status: :runtime_unavailable, reason: :manager_unavailable}
      else
        %{status: :unsupported, reason: nil}
      end
    end
  end

  defp platform do
    Application.get_env(:trenino, :virtual_joystick_mcp_platform, Platform)
  end

  defp validation_result(errors) when is_list(errors) do
    {:ok, %{status: "error", reason: %{code: "validation_failed", errors: errors}}}
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
