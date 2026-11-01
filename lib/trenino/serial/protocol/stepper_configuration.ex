defmodule Trenino.Serial.Protocol.StepperConfiguration do
  @moduledoc "Electrical configuration in commutation transitions, firmware extension revision 1."
  @type t :: %__MODULE__{}
  defstruct driver: :adafruit_motor_shield,
            mode: :x27_six_state,
            shield_address: 0x60,
            motor_port: 1,
            reverse: false,
            idle_behavior: :hold,
            host_loss_behavior: :release,
            reference_strategy: :host_reference,
            min_position: 0,
            max_position: 720,
            max_speed: 100,
            acceleration: 200,
            home_direction: -1,
            home_steps: 1080,
            home_speed: 100,
            home_timeout_ms: 15_000,
            home_position: 0,
            watchdog_ms: 1000,
            home_backoff: 10

  @spec valid?(t()) :: boolean()
  def valid?(%__MODULE__{} = c) do
    enums_valid?(c) and ranges_valid?(c) and relationships_valid?(c)
  end

  defp enums_valid?(c) do
    Enum.all?([
      c.driver == :adafruit_motor_shield,
      c.mode in [:x27_six_state, :full_step, :half_step],
      c.idle_behavior in [:hold, :release],
      c.host_loss_behavior in [:hold, :release],
      c.reference_strategy in [:host_reference, :internal_stop],
      is_boolean(c.reverse),
      c.motor_port in [1, 2],
      c.home_direction in [-1, 1]
    ])
  end

  defp ranges_valid?(c) do
    Enum.all?(
      [
        {c.shield_address, 96, 119},
        {c.min_position, -1_000_000, 1_000_000},
        {c.max_position, -1_000_000, 1_000_000},
        {c.max_speed, 1, 200},
        {c.acceleration, 1, 10_000},
        {c.watchdog_ms, 100, 60_000},
        {c.home_steps, 1, 65_535},
        {c.home_speed, 1, 200},
        {c.home_timeout_ms, 1, 60_000},
        {c.home_backoff, 0, 65_534},
        {c.home_position, -1_000_000, 1_000_000}
      ],
      fn {n, low, high} -> integer?(n, low, high) end
    )
  end

  defp relationships_valid?(c) do
    c.min_position < c.max_position and c.home_speed <= c.max_speed and
      c.home_backoff < c.home_steps and integer?(c.home_position, c.min_position, c.max_position)
  end

  defp integer?(n, low, high), do: is_integer(n) and n >= low and n <= high
end
