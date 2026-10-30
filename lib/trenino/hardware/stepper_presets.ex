defmodule Trenino.Hardware.StepperPresets do
  @moduledoc "Editable, physically unverified host-side commissioning candidates."
  def class323_speedometer_axis do
    %{
      name: "Class 323 speedometer (unverified)",
      axis_index: 0,
      driver: :adafruit_motor_shield,
      mode: :x27_six_state,
      shield_address: 96,
      motor_port: 1,
      reverse: false,
      min_position: 0,
      max_position: 720,
      max_speed: 100,
      acceleration: 200,
      idle_behavior: :hold,
      host_loss_behavior: :release,
      watchdog_ms: 1000,
      reference_strategy: :host_reference,
      startup_reference: :manual,
      commissioned: false,
      home_direction: -1,
      home_steps: 1080,
      home_backoff: 10,
      home_speed: 100,
      home_timeout_ms: 15_000,
      home_position: 0
    }
  end
end
