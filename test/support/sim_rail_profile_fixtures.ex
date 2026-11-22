defmodule Trenino.SimRailProfileFixtures do
  @moduledoc """
  SimRail vehicle profiles (`integrations/simrail/profiles/*.json`, the
  bridge's `GET /api/v1/dump`) as `%Trenino.Simulator.Control{}` lists, and a
  fake `:control_catalog` backend serving them.

  The conversion here only reads what lever tests need; the real one belongs
  to the SimRail backend.
  """

  alias Trenino.Simulator.Control
  alias Trenino.Simulator.Control.Position

  @profiles Path.expand("../../integrations/simrail/profiles", __DIR__)

  @kinds %{"lever" => :lever, "switch" => :switch, "button" => :button, "flap" => :flap}

  @doc "The vehicle id and controls of a profile, e.g. `profile(\"4e_eu07-193\")`."
  @spec profile(String.t()) :: {String.t(), [Control.t()]}
  def profile(name) do
    %{"schema" => %{"vehicle" => %{"name" => vehicle}, "controls" => controls}} =
      @profiles |> Path.join(name <> ".json") |> File.read!() |> Jason.decode!()

    {vehicle, Enum.map(controls, &control/1)}
  end

  @doc "The controls of a profile."
  @spec controls(String.t()) :: [Control.t()]
  def controls(name), do: name |> profile() |> elem(1)

  @doc "The first lever control of `controls` writing `path` with control type `type`."
  @spec lever([Control.t()], String.t(), String.t()) :: Control.t()
  def lever(controls, path, type) do
    Enum.find(controls, &(&1.kind == :lever and &1.path == path and &1.type == type)) ||
      raise "no #{type} lever writes #{path}"
  end

  defp control(map) do
    %Control{
      id: map["id"],
      kind: Map.get(@kinds, map["kind"], :other),
      type: map["type"],
      path: map["path"],
      position: map["position"],
      positions: Enum.map(map["positions"] || [], &position/1),
      actions: map["actions"] || []
    }
  end

  defp position(map) do
    %Position{
      index: map["index"],
      value: float(map["value"]),
      label: map["label"],
      stable: map["stable"],
      lower: float(map["lower"]),
      upper: float(map["upper"]),
      smooth: map["smooth"] == true
    }
  end

  defp float(nil), do: nil
  defp float(value), do: value / 1

  defmodule CatalogBackend do
    @moduledoc """
    A connected `:control_catalog` backend whose handle is
    `{vehicle_id, controls}`. Use it as the `backend` of a stubbed
    `Trenino.Simulator.ConnectionState`.
    """

    @behaviour Trenino.Simulator.Backend

    @impl true
    def id, do: :simrail
    @impl true
    def capabilities, do: [:control_catalog, :push_values, :vehicle_events]
    @impl true
    def connect(_config), do: {:error, :fake}
    @impl true
    def check(_handle), do: {:ok, %{}}
    @impl true
    def disconnect(_handle), do: :ok
    @impl true
    def get(_handle, _path), do: {:error, :not_found}
    @impl true
    def read(_handle, _paths), do: {:ok, %{}}
    @impl true
    def set(_handle, _path, _value), do: :ok
    @impl true
    def vehicle_id({vehicle_id, _controls}), do: {:ok, vehicle_id}
    @impl true
    def controls({_vehicle_id, controls}), do: {:ok, controls}
    @impl true
    def watch(_handle, _paths, _pid), do: :ok
  end
end
