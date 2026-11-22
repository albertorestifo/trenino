defmodule Trenino.SimRailFixtures do
  @moduledoc """
  TreninoBridge profiles from `integrations/simrail/profiles/` (`GET /api/v1/dump`
  output). Their `schema` field is the `GET /api/v1/vehicle` response.
  """

  @profiles_dir Path.expand("../../integrations/simrail/profiles", __DIR__)

  @doc "The full dump of a profile, e.g. `\"en57_en57-047\"`."
  @spec dump(String.t()) :: map()
  def dump(name) do
    @profiles_dir |> Path.join(name <> ".json") |> File.read!() |> Jason.decode!()
  end

  @doc "The vehicle schema of a profile, as `GET /api/v1/vehicle` returns it."
  @spec schema(String.t()) :: map()
  def schema("traxx_e186-134"), do: "traxx_e186-134" |> dump() |> upgrade_legacy_schema()
  def schema(name), do: dump(name)["schema"]

  @doc "The values of a profile, as `GET /api/v1/values` returns them."
  @spec values(String.t()) :: map()
  def values(name), do: dump(name)["values"]

  # The Traxx profile predates the bridge reporting `stable` and `button`;
  # rebuild them from the raw control properties it captured, the way the
  # current bridge does (`StablePosition`, `pressed`/`nonPressedPhysicsValue`).
  defp upgrade_legacy_schema(%{"schema" => schema, "rawControls" => raw}) do
    controls =
      schema["controls"]
      |> Enum.zip(raw)
      |> Enum.map(fn {control, %{"id" => id, "props" => props}} ->
        ^id = control["id"]
        control |> add_stable(props) |> add_button(props)
      end)

    %{schema | "controls" => controls}
  end

  defp add_stable(%{"positions" => positions} = control, %{"Positions" => raw})
       when length(positions) == length(raw) and positions != [] do
    positions =
      positions
      |> Enum.zip(raw)
      |> Enum.map(fn {position, %{"StablePosition" => stable}} ->
        Map.put(position, "stable", stable)
      end)

    %{control | "positions" => positions}
  end

  defp add_stable(control, _props), do: control

  defp add_button(control, %{
         "pressedPhysicsValue" => pressed,
         "nonPressedPhysicsValue" => released
       }),
       do: Map.put(control, "button", %{"pressed" => pressed, "released" => released})

  defp add_button(control, _props), do: control
end
