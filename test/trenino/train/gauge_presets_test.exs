defmodule Trenino.Train.GaugePresetsTest do
  use ExUnit.Case, async: true
  alias Trenino.Train.GaugePresets

  test "binding starter does not invent an endpoint, enable control or carry a dial" do
    p = GaugePresets.class323_speedometer()
    assert p.endpoint == nil
    assert p.input_unit == :mps
    refute p.enabled
    refute Map.has_key?(p, :points)
  end
end
