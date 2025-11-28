defmodule TswIo.Hardware.Calibration.Calculator do
  @moduledoc """
  Calculates normalized input values using calibration data.

  The normalized value ranges from 0 (at min) to total_travel (at max).
  Handles inversion and rollover automatically.
  """

  alias TswIo.Hardware.Input.Calibration
  require Logger

  @doc """
  Converts a raw input value to a normalized value.

  The normalized value ranges from 0 (at min) to total_travel (at max).
  Handles inversion and rollover automatically.

  ## Examples

      iex> calibration = %Calibration{min_value: 10, max_value: 150, is_inverted: false, has_rollover: false, max_hardware_value: 1023}
      iex> normalize(10, calibration)
      0

      iex> normalize(80, calibration)
      70

      iex> normalize(150, calibration)
      140
  """
  @spec normalize(integer(), Calibration.t()) :: integer()
  def normalize(raw_value, %Calibration{} = calibration) do
    adjusted_value =
      raw_value
      |> adjust_for_inversion(calibration)
      |> adjust_for_rollover(raw_value, calibration)

    # For inverted rollover, the effective max extends through the rollover zone
    # up to just before reaching min from the other side
    effective_max = effective_max_value(calibration)
    clamped = clamp(adjusted_value, calibration.min_value, effective_max)

    res = clamped - calibration.min_value

    Logger.debug(
      "Normalized value: #{res} for raw value: #{raw_value} with calibration: #{inspect(calibration)}"
    )

    res
  end

  @doc """
  Returns the total travel range for a calibration.
  """
  @spec total_travel(Calibration.t()) :: integer()
  def total_travel(%Calibration{} = calibration) do
    effective_max_value(calibration) - calibration.min_value
  end

  # For inverted rollover, the entire dead zone clamps to max.
  # The effective max is one step before min_value (on the rollover side).
  defp effective_max_value(%Calibration{has_rollover: true, is_inverted: true} = calibration) do
    # The furthest point from min via rollover is min_value - 1 + max_hardware_value + 1
    calibration.min_value + calibration.max_hardware_value
  end

  defp effective_max_value(%Calibration{} = calibration) do
    calibration.max_value
  end

  # Private functions

  # For inverted inputs, the Analyzer stores min_value and max_value as the
  # already-inverted values (1023 - raw). So Calculator doesn't need to do
  # any inversion - just use the values as-is, but apply the same inversion
  # to the incoming raw value.
  defp adjust_for_inversion(value, %Calibration{is_inverted: false}), do: value

  defp adjust_for_inversion(value, %Calibration{is_inverted: true} = calibration) do
    calibration.max_hardware_value - value
  end

  defp adjust_for_rollover(value, _raw_value, %Calibration{has_rollover: false}), do: value

  # For inverted rollover: when the inverted value is below min_value,
  # we need to determine if we're in the rollover zone (past max) or
  # just past min going the other direction.
  #
  # For inverted inputs, the dead zone above raw_at_min spans from
  # raw_at_min+1 to max_hardware_value. We split this at the midpoint:
  # - Lower half (near min): past min backwards → clamp to 0
  # - Upper half (near max_hw): rollover from max → extend range
  defp adjust_for_rollover(
         value,
         raw_value,
         %Calibration{
           has_rollover: true,
           is_inverted: true
         } = calibration
       ) do
    if value < calibration.min_value do
      raw_at_min = calibration.max_hardware_value - calibration.min_value

      if raw_value <= raw_at_min do
        # In normal rollover zone (raw 0 to raw_at_min) - extend the range
        value + calibration.max_hardware_value + 1
      else
        # Raw is above raw_at_min - need to check if it's:
        # - Near min (clamp to 0)
        # - Near max_hw (rollover zone, extend range)
        dead_zone_above_min = calibration.max_hardware_value - raw_at_min
        boundary = raw_at_min + div(dead_zone_above_min, 2)

        if raw_value <= boundary do
          # Near min - clamp to min
          calibration.min_value
        else
          # Near max_hw (rollover zone) - extend range
          value + calibration.max_hardware_value + 1
        end
      end
    else
      value
    end
  end

  defp adjust_for_rollover(value, _raw_value, %Calibration{has_rollover: true} = calibration) do
    # Standard rollover case for non-inverted: Analyzer extended the range past hardware max
    if calibration.max_value > calibration.max_hardware_value and
         value < calibration.min_value do
      value + calibration.max_hardware_value + 1
    else
      value
    end
  end

  defp clamp(value, min, max) do
    value
    |> max(min)
    |> min(max)
  end
end
