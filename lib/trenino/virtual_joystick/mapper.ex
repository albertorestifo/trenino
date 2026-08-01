defmodule Trenino.VirtualJoystick.Mapper do
  @moduledoc """
  Converts calibrated analog values into virtual joystick axis values.
  """

  alias Trenino.Hardware.Calibration.Calculator
  alias Trenino.Hardware.Input.Calibration

  @spec axis_value(integer(), Calibration.t() | nil, boolean(), {integer(), integer()}) ::
          {:ok, integer()} | {:error, :invalid_range | :uncalibrated}
  def axis_value(_raw_value, _calibration, _inverted, {minimum, maximum}) when maximum <= minimum,
    do: {:error, :invalid_range}

  def axis_value(_raw_value, nil, _inverted, _range), do: {:error, :uncalibrated}

  def axis_value(raw_value, %Calibration{} = calibration, inverted, {minimum, maximum}) do
    case Calculator.total_travel(calibration) do
      travel when travel > 0 ->
        normalized = Calculator.normalize(raw_value, calibration) / travel
        normalized = if inverted, do: 1 - normalized, else: normalized

        {:ok, round(minimum + normalized * (maximum - minimum))}

      _ ->
        {:error, :uncalibrated}
    end
  end
end
