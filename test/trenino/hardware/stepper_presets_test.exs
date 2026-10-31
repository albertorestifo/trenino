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

  test "x27_168 preset targets port 1 / 0x60 six-state" do
    assert %{motor_port: 1, shield_address: 96, mode: :x27_six_state} =
             StepperPresets.x27_168_axis()
  end
end
