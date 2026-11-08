defmodule Trenino.Simulator.LeverMetadata do
  @moduledoc """
  Read-only description of a simulator lever.

  Everything here is read without moving the lever:

  - `role` comes from `Property.InputIdentifier` (for example `"Throttle"`,
    `"Reverser"`, `"AutomaticBrake"`). It is stable across trains, unlike node
    names such as `PowerHandle(IrregularLever)` or `MasterController`.
  - `labels` come from `Property.DisplayInfo.namedValues`, the names the game
    shows for each position ("Emergency", "{BrakePercent} Brake", "N3"). Each
    label covers a range of either output or input values.

  Labels do not give the input position of each notch when they are in output
  units, so a sweep (`Trenino.Simulator.LeverAnalyzer`) is still needed.
  """

  alias Trenino.Simulator.Client

  @root "CurrentDrivableActor"
  @label_epsilon 0.01
  # The game closes connections when too many requests arrive at once
  @list_concurrency 4

  defmodule Label do
    @moduledoc "A named range from the lever's DisplayInfo."

    @type source :: :input | :output
    @type t :: %__MODULE__{
            name: String.t(),
            source: source(),
            min: float(),
            max: float(),
            template?: boolean()
          }

    defstruct [:name, :source, :min, :max, template?: false]
  end

  @type t :: %__MODULE__{
          control_path: String.t(),
          node_name: String.t(),
          role: String.t() | nil,
          notch_count: integer() | nil,
          input_min: float() | nil,
          input_max: float() | nil,
          output_min: float() | nil,
          output_max: float() | nil,
          default_input: float() | nil,
          current_input: float() | nil,
          current_output: float() | nil,
          current_notch_index: integer() | nil,
          labels: [Label.t()]
        }

  defstruct [
    :control_path,
    :node_name,
    :role,
    :notch_count,
    :input_min,
    :input_max,
    :output_min,
    :output_max,
    :default_input,
    :current_input,
    :current_output,
    :current_notch_index,
    labels: []
  ]

  @doc """
  Reads the metadata of one lever, e.g. `"CurrentDrivableActor/Throttle_F"`.

  Fields that the simulator does not expose are left `nil`.
  """
  @spec read(Client.t(), String.t()) :: {:ok, t()} | {:error, term()}
  def read(%Client{} = client, control_path) when is_binary(control_path) do
    case Client.get(client, "#{control_path}.Function.GetNotchCount") do
      {:ok, %{"Values" => _} = response} ->
        {:ok, build(client, control_path, first_value(response))}

      {:ok, _} ->
        {:error, :not_a_lever}

      error ->
        error
    end
  end

  @doc """
  Lists every lever on the current train, sorted by role then by node name.

  A lever is any node under `CurrentDrivableActor` that answers
  `Function.GetNotchCount`.
  """
  @spec list_levers(Client.t()) :: {:ok, [t()]} | {:error, term()}
  def list_levers(%Client{} = client) do
    case Client.list(client, @root) do
      {:ok, %{"Nodes" => nodes}} when is_list(nodes) -> {:ok, read_levers(client, nodes)}
      {:ok, _} -> {:ok, []}
      error -> error
    end
  end

  defp read_levers(client, nodes) do
    nodes
    |> Enum.map(&node_name/1)
    |> Enum.reject(&is_nil/1)
    |> Task.async_stream(&read(client, "#{@root}/#{&1}"),
      max_concurrency: @list_concurrency,
      timeout: 15_000,
      on_timeout: :kill_task
    )
    |> Enum.flat_map(fn
      {:ok, {:ok, %__MODULE__{} = lever}} -> [lever]
      _ -> []
    end)
    |> Enum.sort_by(&{&1.role || "~", cab_rank(&1.node_name), &1.node_name})
  end

  @doc """
  Parses `Property.DisplayInfo` values into labels, sorted by range start.
  """
  @spec parse_labels(map() | nil) :: [Label.t()]
  def parse_labels(%{"namedValues" => named}) when is_list(named) do
    named
    |> Enum.flat_map(&parse_label/1)
    |> Enum.sort_by(&{&1.source, &1.min})
  end

  def parse_labels(_), do: []

  @doc """
  Returns the narrowest label of the given source whose range contains `value`.
  """
  @spec label_for([Label.t()], Label.source(), number()) :: Label.t() | nil
  def label_for(labels, source, value) when is_list(labels) and is_number(value) do
    labels
    |> Enum.filter(&(&1.source == source and contains?(&1, value)))
    |> Enum.min_by(&(&1.max - &1.min), fn -> nil end)
  end

  @doc """
  The source that most labels use, or `nil` when the lever has none.
  """
  @spec label_source([Label.t()]) :: Label.source() | nil
  def label_source([]), do: nil

  def label_source(labels) do
    labels
    |> Enum.frequencies_by(& &1.source)
    |> Enum.max_by(fn {_source, count} -> count end)
    |> elem(0)
  end

  @doc """
  A short summary of the lever's labels, e.g. `"Emergency · Brake · Off · Power"`.
  """
  @spec label_summary(t()) :: String.t()
  def label_summary(%__MODULE__{labels: labels}) do
    labels
    |> Enum.map(&display_name(&1, nil))
    |> Enum.reject(&(&1 == ""))
    |> Enum.dedup()
    |> Enum.join(" · ")
  end

  @doc """
  The display name of a label, with `{Placeholder}` tokens resolved.

  When `value` is given (a gate's output), the placeholder becomes that value
  as an integer: `"B{BrakeText}"` at -3 is `"B3"`, `"{PowerNumber}"` at 2 is
  `"Power 2"`. Without a value the placeholder is removed:
  `"{BrakePercent} Brake"` is `"Brake"`.
  """
  @spec display_name(Label.t(), number() | nil) :: String.t()
  def display_name(%Label{template?: false, name: name}, _value), do: name

  def display_name(%Label{name: name}, value) do
    stem = placeholder_stem(name)

    case {String.trim(String.replace(name, ~r/\{[^}]*\}/, "")), value} do
      {"", nil} ->
        stem

      {"", value} ->
        String.trim("#{stem} #{format_int(value)}")

      {text, nil} ->
        text |> String.replace(~r/\s+/, " ")

      {_text, value} ->
        name
        |> String.replace(~r/\{[^}]*\}/, format_int(value))
        |> String.replace(~r/\s+/, " ")
        |> String.trim()
    end
  end

  # ---------------------------------------------------------------------------

  defp build(client, control_path, notch_count) do
    get = fn endpoint -> get_value(client, "#{control_path}.#{endpoint}") end

    %__MODULE__{
      control_path: control_path,
      node_name: control_path |> String.split("/") |> List.last(),
      role: parse_role(get.("Property.InputIdentifier")),
      notch_count: to_int(notch_count),
      input_min: to_float(get.("Function.GetMinimumInputValue")),
      input_max: to_float(get.("Function.GetMaximumInputValue")),
      output_min: to_float(get.("Function.GetMinimumOutputValue")),
      output_max: to_float(get.("Function.GetMaximumOutputValue")),
      default_input: to_float(get.("Property.DefaultInputValue")),
      current_input: to_float(get.("Function.GetCurrentInputValue")),
      current_output: to_float(get.("Function.GetCurrentOutputValue")),
      current_notch_index: to_int(get.("Function.GetCurrentNotchIndex")),
      labels: parse_labels(get_values(client, "#{control_path}.Property.DisplayInfo"))
    }
  end

  defp get_value(client, path) do
    case Client.get(client, path) do
      {:ok, %{"Values" => _} = response} -> first_value(response)
      _ -> nil
    end
  end

  defp get_values(client, path) do
    case Client.get(client, path) do
      {:ok, %{"Values" => values}} when is_map(values) -> values
      _ -> nil
    end
  end

  defp first_value(%{"Values" => %{"ReturnValue" => value}}), do: value
  defp first_value(%{"Values" => %{"Value" => value}}), do: value

  defp first_value(%{"Values" => values}) when is_map(values) and map_size(values) > 0,
    do: values |> Map.values() |> hd()

  defp first_value(_), do: nil

  defp parse_role(%{"identifier" => "None"}), do: nil
  defp parse_role(%{"identifier" => id}) when is_binary(id), do: id
  defp parse_role("None"), do: nil
  defp parse_role(id) when is_binary(id), do: id
  defp parse_role(_), do: nil

  defp parse_label(%{"valueRange" => %{"min" => min, "max" => max}, "displayName" => name} = raw)
       when is_number(min) and is_number(max) and is_binary(name) do
    [
      %Label{
        name: name,
        source: parse_source(raw["valueSource"]),
        min: Float.round(min * 1.0, 2),
        max: Float.round(max * 1.0, 2),
        template?: raw["bDisplayNameIsFormatString"] == true or String.contains?(name, "{")
      }
    ]
  end

  defp parse_label(_), do: []

  defp parse_source("Input"), do: :input
  defp parse_source(_), do: :output

  defp contains?(%Label{min: min, max: max}, value),
    do: value >= min - @label_epsilon and value <= max + @label_epsilon

  defp placeholder_stem(name) do
    case Regex.run(~r/\{([^}]*)\}/, name) do
      [_, placeholder] ->
        placeholder
        |> String.replace(~r/(Number|Percent|Pos|Position|Text|Value|%)$/, "")
        |> String.trim()

      _ ->
        ""
    end
  end

  defp format_int(value), do: value |> abs() |> round() |> Integer.to_string()

  defp node_name(%{"Name" => name}) when is_binary(name), do: name
  defp node_name(%{"NodeName" => name}) when is_binary(name), do: name
  defp node_name(_), do: nil

  # Twin-cab trains expose every control twice (`Throttle_F`, `Throttle_B`).
  # The front cab is listed first; it is the usual driving cab.
  defp cab_rank(name) do
    cond do
      String.match?(name, ~r/_F(L|R)?$/) -> 0
      String.match?(name, ~r/_B(L|R)?$/) -> 2
      true -> 1
    end
  end

  defp to_float(value) when is_number(value), do: Float.round(value * 1.0, 2)
  defp to_float(_), do: nil

  defp to_int(value) when is_integer(value), do: value
  defp to_int(value) when is_float(value), do: round(value)
  defp to_int(_), do: nil
end
