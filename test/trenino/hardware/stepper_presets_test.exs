defmodule Trenino.Hardware.StepperPresetsTest do
  use ExUnit.Case, async: true
  alias Trenino.Hardware.StepperPresets

  test "unverified profile never opts into motion" do
    preset = StepperPresets.class323_speedometer_axis()
    refute preset.commissioned
    assert preset.reference_strategy == :host_reference
    assert preset.startup_reference == :manual
    assert preset.max_position == 720
  end
end
