defmodule Trenino.MCP.Tools.SelectorTools do
  @moduledoc """
  MCP tools for selectors: potentiometers used as multi-position switches.

  A selector element is bound to a calibrated analog input. Its 0.0-1.0
  range is split into 2-12 positions with dead zones between them, and each
  position has an enter and an exit action.
  """

  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.{SelectorBinding, SelectorMapper, SelectorPosition}

  @action_kinds ~w(none set_value sequence keystroke)

  @action_schema %{
    type: "object",
    description:
      "Action to run. kind 'set_value' needs endpoint and value, 'sequence' needs " <>
        "sequence_id, 'keystroke' needs keystroke (tapped once, e.g. 'L' or 'CTRL+L'). " <>
        "'none' does nothing.",
    properties: %{
      kind: %{type: "string", enum: @action_kinds},
      endpoint: %{
        type: "string",
        description: "Simulator endpoint, e.g. 'X/Headlights.InputValue'"
      },
      value: %{type: "number", description: "Value sent to the endpoint"},
      sequence_id: %{type: "integer", description: "Sequence ID from list_sequences"},
      keystroke: %{type: "string", description: "Key combination"}
    },
    required: ["kind"]
  }

  @position_schema %{
    type: "object",
    properties: %{
      label: %{type: "string", description: "Position name, e.g. 'Off', 'Dim', 'Full'"},
      input_min: %{
        type: "number",
        description: "Start of the position's range (0.0-1.0). Give both bounds or neither."
      },
      input_max: %{type: "number", description: "End of the position's range (0.0-1.0)"},
      enter: @action_schema,
      exit: @action_schema
    }
  }

  def tools do
    [
      %{
        name: "get_selector",
        description:
          "Get a selector element's binding: its analog input and its positions, each with " <>
            "its input range, label, enter action and exit action.",
        input_schema: %{
          type: "object",
          properties: %{
            element_id: %{type: "integer", description: "Selector element ID from get_train"}
          },
          required: ["element_id"]
        }
      },
      %{
        name: "configure_selector",
        description:
          "Create or update a selector element's binding. A selector turns a calibrated " <>
            "potentiometer into a multi-position switch: its 0.0-1.0 range is split into " <>
            "2-12 positions in physical order (index 0 is at 0.0), and each position runs " <>
            "its enter action when the knob moves into it and its exit action when it " <>
            "leaves. Readings between positions are dead zones and change nothing.\n\n" <>
            "positions replaces the whole set. Give input_min/input_max for every position " <>
            "or for none: without ranges the positions are split evenly with dead zones. " <>
            "Neighbouring ranges need a gap of at least 0.02. Omit positions to keep the " <>
            "existing ones (e.g. to change only the input or enabled).\n\n" <>
            "Use list_device_inputs to find a calibrated analog input.",
        input_schema: %{
          type: "object",
          properties: %{
            element_id: %{type: "integer", description: "Selector element ID"},
            input_id: %{
              type: "integer",
              description: "Calibrated analog input ID (required when creating)"
            },
            enabled: %{type: "boolean", description: "Whether the selector is active"},
            positions: %{type: "array", items: @position_schema, minItems: 2, maxItems: 12},
            replace_joystick_mapping: %{
              type: "boolean",
              description:
                "Remove a virtual joystick mapping on the same input instead of failing"
            }
          },
          required: ["element_id"]
        }
      },
      %{
        name: "set_selector_even_split",
        description:
          "Re-split a selector's range evenly into count positions with dead zones. " <>
            "Labels and actions of existing positions are kept by index; new positions " <>
            "start with no actions and extra positions are removed.",
        input_schema: %{
          type: "object",
          properties: %{
            element_id: %{type: "integer", description: "Selector element ID"},
            count: %{
              type: "integer",
              minimum: 2,
              maximum: 12,
              description: "Number of positions (default: the current count)"
            },
            dead_zone: %{
              type: "number",
              minimum: 0.05,
              maximum: 0.5,
              description: "Fraction of each slot left as a gap (default 0.2)"
            }
          },
          required: ["element_id"]
        }
      },
      %{
        name: "delete_selector",
        description: "Remove a selector element's binding and its positions.",
        input_schema: %{
          type: "object",
          properties: %{
            element_id: %{type: "integer", description: "Selector element ID"}
          },
          required: ["element_id"]
        }
      }
    ]
  end

  def execute("get_selector", %{"element_id" => element_id}) do
    case TrainContext.get_selector_binding(element_id) do
      {:ok, binding} -> {:ok, %{selector: serialize(binding)}}
      {:error, :not_found} -> {:error, not_found(element_id)}
    end
  end

  def execute("configure_selector", %{"element_id" => element_id} = args) do
    with {:ok, attrs} <- build_attrs(args) do
      opts = [replace?: Map.get(args, "replace_joystick_mapping", false) == true]
      save(element_id, attrs, opts)
    end
  end

  def execute("set_selector_even_split", %{"element_id" => element_id} = args) do
    with {:ok, binding} <- fetch_binding(element_id),
         {:ok, count} <- split_count(args, binding),
         {:ok, dead_zone} <- dead_zone(args) do
      by_index = Map.new(binding.positions, &{&1.index, &1})

      positions =
        count
        |> SelectorMapper.even_split(dead_zone)
        |> Enum.map(fn range ->
          by_index
          |> Map.get(range.index, %SelectorPosition{})
          |> position_attrs()
          |> Map.merge(range)
        end)

      save(element_id, %{positions: positions}, [])
    end
  end

  def execute("delete_selector", %{"element_id" => element_id}) do
    case TrainContext.delete_selector_binding(element_id) do
      :ok -> {:ok, %{deleted: true, element_id: element_id}}
      {:error, :not_found} -> {:error, not_found(element_id)}
    end
  end

  @doc """
  Serialize a selector binding with its positions for MCP responses.
  """
  @spec serialize(SelectorBinding.t()) :: map()
  def serialize(%SelectorBinding{} = binding) do
    %{
      id: binding.id,
      element_id: binding.element_id,
      input_id: binding.input_id,
      enabled: binding.enabled,
      positions: Enum.map(binding.positions, &serialize_position/1)
    }
  end

  defp serialize_position(%SelectorPosition{} = position) do
    %{
      index: position.index,
      label: position.label,
      input_min: position.input_min,
      input_max: position.input_max,
      enter: serialize_action(position, :enter),
      exit: serialize_action(position, :exit)
    }
  end

  defp serialize_action(%SelectorPosition{} = position, :enter) do
    %{
      kind: position.enter_kind,
      endpoint: position.enter_endpoint,
      value: position.enter_value,
      sequence_id: position.enter_sequence_id,
      keystroke: position.enter_keystroke
    }
  end

  defp serialize_action(%SelectorPosition{} = position, :exit) do
    %{
      kind: position.exit_kind,
      endpoint: position.exit_endpoint,
      value: position.exit_value,
      sequence_id: position.exit_sequence_id,
      keystroke: position.exit_keystroke
    }
  end

  # The stored fields of a position, as attrs for a new position set.
  defp position_attrs(%SelectorPosition{} = position) do
    Map.take(position, [
      :label,
      :enter_kind,
      :enter_endpoint,
      :enter_value,
      :enter_sequence_id,
      :enter_keystroke,
      :exit_kind,
      :exit_endpoint,
      :exit_value,
      :exit_sequence_id,
      :exit_keystroke
    ])
  end

  defp save(element_id, attrs, opts) do
    case TrainContext.save_selector(element_id, attrs, opts) do
      {:ok, binding} ->
        {:ok, %{selector: serialize(binding)}}

      {:error, :destination_conflict} ->
        {:error,
         "This input is assigned to the virtual joystick. Remove that mapping, or pass " <>
           "replace_joystick_mapping: true to replace it."}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, format_changeset_errors(changeset)}
    end
  end

  defp fetch_binding(element_id) do
    case TrainContext.get_selector_binding(element_id) do
      {:ok, binding} -> {:ok, binding}
      {:error, :not_found} -> {:error, not_found(element_id)}
    end
  end

  defp split_count(%{"count" => count}, _binding) when is_integer(count) do
    {min, max} = SelectorBinding.position_limits()

    if count >= min and count <= max,
      do: {:ok, count},
      else: {:error, "count must be between #{min} and #{max}"}
  end

  defp split_count(%{"count" => _count}, _binding), do: {:error, "count must be an integer"}
  defp split_count(_args, %SelectorBinding{positions: positions}), do: {:ok, length(positions)}

  defp dead_zone(%{"dead_zone" => dead_zone}) when is_number(dead_zone) do
    if dead_zone >= 0.05 and dead_zone <= 0.5,
      do: {:ok, dead_zone * 1.0},
      else: {:error, "dead_zone must be between 0.05 and 0.5"}
  end

  defp dead_zone(%{"dead_zone" => _dead_zone}), do: {:error, "dead_zone must be a number"}
  defp dead_zone(_args), do: {:ok, 0.2}

  defp build_attrs(args) do
    base =
      args
      |> Map.take(["input_id", "enabled"])
      |> Map.new(fn {key, value} -> {String.to_existing_atom(key), value} end)

    case Map.fetch(args, "positions") do
      :error ->
        {:ok, base}

      {:ok, positions} ->
        with {:ok, attrs} <- build_positions(positions),
             do: {:ok, Map.put(base, :positions, attrs)}
    end
  end

  defp build_positions(positions) when is_list(positions) do
    with {:ok, built} <- map_ok(positions, &build_position/1) do
      apply_ranges(built)
    end
  end

  defp build_positions(_positions), do: {:error, "positions must be a list"}

  defp build_position(position) when is_map(position) do
    with {:ok, enter} <- build_action(Map.get(position, "enter"), :enter),
         {:ok, exit} <- build_action(Map.get(position, "exit"), :exit) do
      range = Map.take(position, ["input_min", "input_max"])

      {:ok,
       %{label: Map.get(position, "label")}
       |> Map.merge(enter)
       |> Map.merge(exit)
       |> Map.merge(Map.new(range, fn {key, value} -> {String.to_existing_atom(key), value} end))}
    end
  end

  defp build_position(_position), do: {:error, "each position must be an object"}

  defp build_action(nil, prefix), do: {:ok, %{kind_key(prefix) => :none}}

  defp build_action(%{"kind" => kind} = action, prefix) when kind in @action_kinds do
    {:ok,
     %{
       kind_key(prefix) => String.to_existing_atom(kind),
       field_key(prefix, :endpoint) => Map.get(action, "endpoint"),
       field_key(prefix, :value) => Map.get(action, "value"),
       field_key(prefix, :sequence_id) => Map.get(action, "sequence_id"),
       field_key(prefix, :keystroke) => Map.get(action, "keystroke")
     }}
  end

  defp build_action(_action, prefix),
    do: {:error, "#{prefix}.kind must be one of: #{Enum.join(@action_kinds, ", ")}"}

  defp kind_key(prefix), do: field_key(prefix, :kind)
  defp field_key(:enter, name), do: :"enter_#{name}"
  defp field_key(:exit, name), do: :"exit_#{name}"

  # Index follows list order. Ranges come from the caller for every position,
  # or from an even split for all of them.
  defp apply_ranges(positions) do
    with_range =
      Enum.count(positions, &(Map.has_key?(&1, :input_min) or Map.has_key?(&1, :input_max)))

    {min, max} = SelectorBinding.position_limits()

    cond do
      with_range == 0 and length(positions) in min..max ->
        ranges = SelectorMapper.even_split(length(positions))
        {:ok, Enum.zip_with(positions, ranges, &Map.merge/2)}

      with_range == 0 ->
        {:error, "positions must have between #{min} and #{max} entries"}

      with_range == length(positions) ->
        indexed =
          positions
          |> Enum.sort_by(&Map.get(&1, :input_min))
          |> Enum.with_index()
          |> Enum.map(fn {position, index} -> Map.put(position, :index, index) end)

        {:ok, indexed}

      true ->
        {:error, "give input_min and input_max for every position, or for none"}
    end
  end

  defp map_ok(list, fun) do
    Enum.reduce_while(list, {:ok, []}, fn item, {:ok, acc} ->
      case fun.(item) do
        {:ok, value} -> {:cont, {:ok, [value | acc]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end

  defp not_found(element_id), do: "No selector binding found for element #{element_id}"

  # Flattens nested position errors to "positions[1].enter_endpoint can't be blank".
  defp format_changeset_errors(changeset) do
    errors =
      changeset
      |> Ecto.Changeset.traverse_errors(fn {msg, opts} ->
        Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
          opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
        end)
      end)
      |> flatten_errors("")

    "Validation failed: " <> Enum.join(errors, "; ")
  end

  defp flatten_errors(errors, path) when is_map(errors) do
    Enum.flat_map(errors, fn {field, value} -> flatten_errors(value, join_path(path, field)) end)
  end

  defp flatten_errors([%{} | _] = nested, path) do
    nested
    |> Enum.with_index()
    |> Enum.flat_map(fn {errors, index} -> flatten_errors(errors, "#{path}[#{index}]") end)
  end

  defp flatten_errors(messages, path) when is_list(messages) do
    Enum.map(messages, &"#{path} #{&1}")
  end

  defp join_path("", field), do: to_string(field)
  defp join_path(path, field), do: "#{path}.#{field}"
end
