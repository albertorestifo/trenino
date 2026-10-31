defmodule Trenino.Train.GaugePresetsTest do
  use ExUnit.Case, async: true
  alias Trenino.Hardware.StepperPresets
  alias Trenino.Train.GaugePresets

  test "binding starter does not invent an endpoint, enable control or carry a dial" do
    p = GaugePresets.class323_speedometer()
    assert p.endpoint == nil
    assert p.input_unit == :mps
    refute p.enabled
    refute Map.has_key?(p, :points)
  end

  test "dial starter is an unreviewed estimate on the axis side" do
    p = StepperPresets.class323_dial_calibration()
    assert p.output_unit == :mph
    assert p.points == [%{value: 0.0, position: 0}, %{value: 100.0, position: 720}]
    refute Map.has_key?(p, :reviewed)
  end
end
