defmodule Trenino.Hardware.Calibration.Calculator do
  @moduledoc """
  Calculates normalized input values using calibration data.

  The normalized value ranges from 0 (at min) to total_travel (at max).
  Handles inversion and rollover automatically.

  ## How calibration data is stored

  The Calibration struct stores raw values as they appear at physical positions:
  - `min_value`: raw value at physical minimum position
  - `max_value`: raw value at physical maximum position
  - `is_inverted`: true if raw decreases as physical position increases
  - `has_rollover`: true if the range crosses the 0/max_hardware_value boundary

  ## Normalization cases

  1. **Simple (not inverted, no rollover)**: raw increases, normalized = raw - min
  2. **Inverted (no rollover)**: raw decreases, normalized = min - raw
  3. **Rollover (not inverted)**: raw increases and wraps 1023→0
  4. **Inverted with rollover**: raw decreases and wraps 0→1023
  """

  alias Trenino.Hardware.Input.Calibration

  @doc """
  Converts a raw input value to a normalized value.

  Returns an integer from 0 to total_travel.
  """
  @spec normalize(integer(), Calibration.t()) :: integer()
  def normalize(raw, %Calibration{} = cal) do
    raw
    |> distance_from_min(cal)
    |> clamp(0, total_travel(cal))
  end

  @doc """
  Returns the total travel range for a calibration.
  """
  @spec total_travel(Calibration.t()) :: integer()
  def total_travel(%Calibration{is_inverted: false, has_rollover: false} = cal) do
    cal.max_value - cal.min_value
  end

  def total_travel(%Calibration{is_inverted: true, has_rollover: false} = cal) do
    cal.min_value - cal.max_value
  end

  def total_travel(%Calibration{is_inverted: false, has_rollover: true} = cal) do
    # e.g., min=900, max=100: (1023 - 900 + 1) + 100 = 224
    cal.max_hardware_value - cal.min_value + 1 + cal.max_value
  end

  def total_travel(%Calibration{is_inverted: true, has_rollover: true} = cal) do
    # e.g., min=550, max=735: 550 + (1023 - 735 + 1) = 839
    cal.min_value + (cal.max_hardware_value - cal.max_value + 1)
  end

  # Simple case: raw increases with position
  defp distance_from_min(raw, %Calibration{is_inverted: false, has_rollover: false} = cal) do
    raw - cal.min_value
  end

  # Inverted: raw decreases with position
  defp distance_from_min(raw, %Calibration{is_inverted: true, has_rollover: false} = cal) do
    cal.min_value - raw
  end

  # Rollover (not inverted): raw increases, wraps from max_hw to 0
  # Travel direction: min → max_hw → 0 → max
  # Valid zones: [min, max_hw] and [0, max]
  # Dead zone: (max, min) - values that are between max and min
  defp distance_from_min(raw, %Calibration{is_inverted: false, has_rollover: true} = cal) do
    cond do
      raw >= cal.min_value ->
        # Before rollover (min to max_hw)
        raw - cal.min_value

      raw <= cal.max_value ->
        # After rollover (0 to max)
        cal.max_hardware_value - cal.min_value + 1 + raw

      true ->
        # Dead zone - clamp to nearest boundary
        # Values in dead zone closer to max clamp to max, closer to min clamp to 0
        midpoint = div(cal.max_value + cal.min_value, 2)

        if raw < midpoint do
          # Closer to max, clamp to total_travel
          total_travel(cal)
        else
          # Closer to min, clamp to 0
          0
        end
    end
  end

  # Inverted with rollover: raw decreases, wraps from 0 to max_hw
  # Travel direction: min → 0 → max_hw → max
  # Valid zones: [0, min] and [max, max_hw]
  # Dead zone: (min, max) - values between min and max
  defp distance_from_min(raw, %Calibration{is_inverted: true, has_rollover: true} = cal) do
    cond do
      raw <= cal.min_value ->
        # Before rollover (min down to 0)
        cal.min_value - raw

      raw >= cal.max_value ->
        # After rollover (max_hw down to max)
        cal.min_value + (cal.max_hardware_value - raw + 1)

      true ->
        # Dead zone - clamp to nearest boundary
        # Values in dead zone closer to min clamp to 0, closer to max clamp to total_travel
        midpoint = div(cal.min_value + cal.max_value, 2)

        if raw < midpoint do
          # Closer to min, clamp to 0
          0
        else
          # Closer to max, clamp to total_travel
          total_travel(cal)
        end
    end
  end

  defp clamp(value, min, max) do
    value
    |> max(min)
    |> min(max)
  end
end
