defmodule Trenino.Simulator.SimRailLevers do
  @moduledoc """
  Builds lever configuration from a control's notch table, for simulators
  that report their controls (`:control_catalog`, SimRail) instead of being
  swept like Train Sim World.

  `analyze/1` turns a `%Trenino.Simulator.Control{}` into an `Analysis` with
  the same `lever_type` and `suggested_notches` shape that
  `Trenino.Simulator.LeverAnalyzer` produces, so it is saved with
  `Trenino.Train.create_lever_config_with_analysis/3` and
  `update_lever_config_with_analysis/3` like a sweep result.

  SimRail writes the notch value itself (there is no separate input/output
  value), so each notch's simulator input range is its value:

    * A position that holds a single value becomes a `:gate` notch at `value`.
      That includes the bands of notch-based smooth levers (an FV4a brake
      valve's `lower`/`upper`): the lever snaps to the position's value, the
      band only says where it snaps from.
    * A `smooth` position with a `lower`/`upper` band becomes a `:linear`
      notch over the band: the lever writes any value inside it (the ED250's
      0..1 throttle, a brake valve's service range).
    * Neighbouring gates with the same value and the same behaviour (the ED250
      throttle's two `0` positions, which both hold) are merged: they are one
      detent to the hardware.
    * **Spring-back positions** (`stable != index`) are notches like any other:
      a position of the lever is a position, and whether the physical lever
      springs back from it is up to the hardware (a spring, a detent valley,
      or nothing). Each notch records `springs_back_to`, the notch index the
      cab lever returns to, only so the notch disk designer and the mapping
      wizard can shape and explain it; runtime code never reads it. A written
      value stays until the next write (the game springs its lever back only
      from its own keyboard/mouse interaction), so the value tracks the
      hardware lever.
    * A control with fewer than two notches is not a lever
      (`{:error, :too_few_positions}`).

  Values are rounded to 2 places like every simulator value Trenino stores.
  """

  alias Trenino.Simulator.Control
  alias Trenino.Simulator.Control.Position

  defmodule Analysis do
    @moduledoc """
    A lever configuration derived from a notch table.

    `lever_type` and `suggested_notches` have the shape of
    `Trenino.Simulator.LeverAnalyzer.AnalysisResult`'s fields of the same
    name.
    """

    alias Trenino.Simulator.Control
    alias Trenino.Simulator.LeverAnalyzer

    @type t :: %__MODULE__{
            control: Control.t(),
            lever_type: :discrete | :continuous | :hybrid,
            suggested_notches: [LeverAnalyzer.suggested_notch()],
            warnings: [String.t()]
          }

    @enforce_keys [:control, :lever_type, :suggested_notches]
    defstruct [:control, :lever_type, :suggested_notches, warnings: []]
  end

  @type find_error ::
          {:error, {:no_lever, String.t()}}
          | {:error, {:unknown_control, String.t()}}
          | {:error, {:ambiguous_control, [String.t()]}}

  @doc "The controls that can be set up as levers: levers with a notch table."
  @spec levers([Control.t()]) :: [Control.t()]
  def levers(controls) when is_list(controls) do
    Enum.filter(controls, &lever?/1)
  end

  defp lever?(%Control{kind: :lever, path: path, positions: [_ | _]}) when is_binary(path),
    do: true

  defp lever?(%Control{}), do: false

  @doc """
  The levers to offer for setup: a train has one physical lever per cab writing
  the same path, so levers with the same path and notch table are listed once.
  Variants with different tables stay apart: the EU07's brake handle exists as
  a smooth and a stepped control in each cab (`variant/1`).
  """
  @spec distinct([Control.t()]) :: [Control.t()]
  def distinct(controls) when is_list(controls) do
    controls |> levers() |> Enum.uniq_by(&{&1.path, notch_table(&1)})
  end

  @doc """
  How the control is operated: "Smooth" (dragged freely, possibly with notch
  bands) or "Stepped" (moves notch by notch).
  """
  @spec variant(Control.t()) :: String.t()
  def variant(%Control{type: type}) when is_binary(type) do
    if String.contains?(type, "Smooth"), do: "Smooth", else: "Stepped"
  end

  def variant(%Control{}), do: "Stepped"

  @doc """
  The cab a control sits in ("Cab A"), from its place in the vehicle: SimRail
  names cab parts `kabina A`, `kabina_4e_B`, `traxx_kabina_A`. Nil outside a cab.
  """
  @spec cab(Control.t()) :: String.t() | nil
  def cab(%Control{id: id}) do
    id
    |> String.split("/")
    |> Enum.find_value(fn part ->
      case Regex.run(~r/kabina.*[_ ]([A-Z])$/i, part) do
        [_, letter] -> "Cab " <> String.upcase(letter)
        nil -> nil
      end
    end)
  end

  @doc """
  The lever control writing `path`. Several controls can write the same path
  (one per cab, or a smooth and a stepped variant of one brake valve) with
  different notch tables; `control_id` picks one. Without it, controls whose
  notch tables are identical count as one.
  """
  @spec find([Control.t()], String.t(), String.t() | nil) :: {:ok, Control.t()} | find_error()
  def find(controls, path, control_id \\ nil) when is_binary(path) do
    candidates = controls |> levers() |> Enum.filter(&(&1.path == path))

    case {candidates, control_id} do
      {[], _} ->
        {:error, {:no_lever, path}}

      {_, id} when is_binary(id) ->
        case Enum.find(candidates, &(&1.id == id)) do
          nil -> {:error, {:unknown_control, id}}
          control -> {:ok, control}
        end

      {[control | _], nil} ->
        if length(Enum.uniq_by(candidates, &notch_table/1)) == 1,
          do: {:ok, control},
          else: {:error, {:ambiguous_control, Enum.map(candidates, & &1.id)}}
    end
  end

  defp notch_table(%Control{positions: positions}) do
    Enum.map(positions, &{&1.value, &1.stable, &1.lower, &1.upper, &1.smooth, &1.index})
  end

  @doc """
  The lever config endpoints of a control path. SimRail reads and writes the
  path itself and has no notch count or index endpoints.
  """
  @spec endpoints(String.t()) :: map()
  def endpoints(path) when is_binary(path) do
    %{
      min_endpoint: path,
      max_endpoint: path,
      value_endpoint: path,
      notch_count_endpoint: nil,
      notch_index_endpoint: nil
    }
  end

  @doc "Lever configuration for `control`, see the module documentation."
  @spec analyze(Control.t()) :: {:ok, Analysis.t()} | {:error, :no_positions | :too_few_positions}
  def analyze(%Control{positions: []}), do: {:error, :no_positions}

  def analyze(%Control{positions: positions} = control) do
    zones =
      positions
      |> Enum.sort_by(& &1.index)
      |> Enum.flat_map(&zone/1)
      |> merge_gates()

    if length(zones) < 2 do
      {:error, :too_few_positions}
    else
      {:ok,
       %Analysis{
         control: control,
         lever_type: lever_type(zones),
         suggested_notches: notches(zones)
       }}
    end
  end

  # A zone is one notch to be: its shape, the game positions it covers and the
  # position it springs back to (nil when it holds).
  defp zone(%Position{smooth: true, lower: lower, upper: upper} = position)
       when is_number(lower) and is_number(upper) and lower != upper do
    [
      %{
        shape: {:linear, round2(min(lower, upper)), round2(max(lower, upper))},
        label: label(position),
        positions: [position.index],
        springs_to: springs_to(position)
      }
    ]
  end

  defp zone(%Position{value: value} = position) when is_number(value) do
    [
      %{
        shape: {:gate, round2(value)},
        label: label(position),
        positions: [position.index],
        springs_to: springs_to(position)
      }
    ]
  end

  defp zone(%Position{}), do: []

  defp springs_to(%Position{} = position),
    do: if(Control.momentary?(position), do: position.stable)

  # Neighbouring gates with the same value and the same behaviour (both hold,
  # or both spring back to the same position) are one detent.
  defp merge_gates(zones) do
    zones
    |> Enum.chunk_by(fn
      %{shape: {:gate, value}, springs_to: target} -> {:gate, value, target}
      zone -> zone
    end)
    |> Enum.map(fn [first | _] = chunk ->
      %{first | positions: Enum.flat_map(chunk, & &1.positions)}
    end)
  end

  defp lever_type(zones) do
    case zones |> Enum.map(&elem(&1.shape, 0)) |> Enum.uniq() do
      [:gate] -> :discrete
      [:linear] -> :continuous
      _ -> :hybrid
    end
  end

  # Spring-back targets are game position indexes; notches need notch indexes.
  defp notches(zones) do
    notch_of =
      for {zone, index} <- Enum.with_index(zones), position <- zone.positions, into: %{} do
        {position, index}
      end

    zones
    |> Enum.with_index()
    |> Enum.map(fn {zone, index} ->
      Map.put(notch(zone, index), :springs_back_to, zone.springs_to && notch_of[zone.springs_to])
    end)
  end

  defp notch(%{shape: {:gate, value}, label: label}, index) do
    %{
      type: :gate,
      index: index,
      value: value,
      input_min: value,
      input_max: value,
      actual_input_min: value,
      actual_input_max: value,
      description: label || format(value)
    }
  end

  defp notch(%{shape: {:linear, low, high}, label: label}, index) do
    %{
      type: :linear,
      index: index,
      min_value: low,
      max_value: high,
      input_min: low,
      input_max: high,
      actual_input_min: low,
      actual_input_max: high,
      description: label || "#{format(low)} – #{format(high)}"
    }
  end

  @doc """
  A readable name for a SimRail position label such as
  `"Train/Drive_direction/Drive_direction_forward"` (`"Drive direction forward"`).
  """
  @spec label(Position.t()) :: String.t() | nil
  def label(%Position{label: label}) when is_binary(label) and label != "" do
    label |> String.split("/") |> List.last() |> String.replace("_", " ")
  end

  def label(%Position{}), do: nil

  defp round2(value), do: Float.round(value / 1, 2)

  defp format(nil), do: "?"
  defp format(value) when is_float(value) and value == trunc(value), do: "#{trunc(value)}"
  defp format(value), do: "#{value}"
end
