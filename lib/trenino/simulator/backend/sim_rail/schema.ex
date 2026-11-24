defmodule Trenino.Simulator.Backend.SimRail.Schema do
  @moduledoc """
  Maps the TreninoBridge vehicle schema (`GET /api/v1/vehicle`, also the
  `schema` field of `/api/v1/dump`) onto `Trenino.Simulator.Control` structs.

  * Unbound decor (windows, curtains: `kind: "decor"` without a `path`) is
    left out; bound decor becomes `:other`.
  * Notch tables are kept per control: the same path can appear once per cab
    with different positions (EU07 `main_brake`, Traxx `activation_handle`).
  * Older bridge builds omit `smooth`; a position counts as smooth when its
    `lower`/`upper` band is wider than a point.
  """

  alias Trenino.Simulator.Control
  alias Trenino.Simulator.Control.Position

  @kinds %{
    "lever" => :lever,
    "switch" => :switch,
    "button" => :button,
    "flap" => :flap
  }

  @doc "The player vehicle's name (`vehicle.name`), or nil."
  @spec vehicle_name(map() | nil) :: String.t() | nil
  def vehicle_name(%{"vehicle" => %{"name" => name}}) when is_binary(name), do: name
  def vehicle_name(_schema), do: nil

  @doc "The schema's controls, without unbound decor."
  @spec controls(map()) :: [Control.t()]
  def controls(%{"controls" => controls}) when is_list(controls) do
    for control <- controls, not unbound_decor?(control), do: to_control(control)
  end

  def controls(_schema), do: []

  @doc "Map one schema control."
  @spec to_control(map()) :: Control.t()
  def to_control(%{"id" => id} = control) do
    button = Map.get(control, "button") || %{}

    %Control{
      id: id,
      kind: Map.get(@kinds, control["kind"], :other),
      type: control["type"],
      path: control["path"],
      position: control["position"],
      positions: control |> Map.get("positions", []) |> Enum.map(&to_position/1),
      pressed_value: to_float(button["pressed"]),
      released_value: to_float(button["released"]),
      actions: Map.get(control, "actions") || []
    }
  end

  defp to_position(%{"index" => index} = position) do
    lower = to_float(position["lower"])
    upper = to_float(position["upper"])

    %Position{
      index: index,
      value: to_float(position["value"]),
      label: blank_to_nil(position["label"]),
      stable: position["stable"],
      lower: lower,
      upper: upper,
      smooth: smooth?(position, lower, upper)
    }
  end

  defp smooth?(%{"smooth" => smooth}, _lower, _upper) when is_boolean(smooth), do: smooth

  defp smooth?(_position, lower, upper) when is_float(lower) and is_float(upper),
    do: lower != upper

  defp smooth?(_position, _lower, _upper), do: false

  defp unbound_decor?(control), do: control["kind"] == "decor" and is_nil(control["path"])

  defp blank_to_nil(label) when label in [nil, ""], do: nil
  defp blank_to_nil(label) when is_binary(label), do: label

  @doc false
  @spec to_float(term()) :: float() | nil
  def to_float(value) when is_float(value), do: value
  def to_float(value) when is_integer(value), do: value * 1.0
  def to_float(_value), do: nil
end
