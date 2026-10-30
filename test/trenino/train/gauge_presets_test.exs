defmodule Trenino.Train.GaugePresetsTest do
  use ExUnit.Case, async: true
  alias Trenino.Train.GaugePresets

  test "starter does not invent an endpoint or enable control" do
    p = GaugePresets.class323_speedometer()
    assert p.endpoint == nil
    refute p.enabled
    assert p.points == [%{value: 0.0, position: 0}, %{value: 100.0, position: 720}]
  end
end
