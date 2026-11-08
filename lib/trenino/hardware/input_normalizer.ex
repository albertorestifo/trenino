defmodule Trenino.Hardware.InputNormalizer do
  @moduledoc """
  Normalizes a raw analog reading to a 0.0-1.0 float using its calibration.

  The calibration system works in two stages:

  1. `Calculator.normalize/2` converts the raw ADC value to a calibrated
     integer (0 to total_travel).
  2. This module divides by total_travel and rounds to `precision` decimals
     (2 by default).

  For example, with calibration min=100 and max=900 (total travel 800), a raw
  reading of 512 normalizes to 412, which becomes `0.52` (or `0.515` with
  precision 4).

  Selectors use the default precision. Levers pass
  `Trenino.Train.LeverMapper.input_precision/0` so a notch covering a small
  part of the travel keeps every ADC step instead of 1/100 increments.
  """

  alias Trenino.Hardware.Calibration.Calculator
  alias Trenino.Hardware.Input.Calibration

  @default_precision 2

  @spec normalize(integer(), Calibration.t() | nil, non_neg_integer()) ::
          {:ok, float()} | {:error, :no_calibration | :invalid_calibration}
  def normalize(raw_value, calibration, precision \\ @default_precision)

  def normalize(_raw_value, nil, _precision), do: {:error, :no_calibration}

  def normalize(raw_value, %Calibration{} = calibration, precision) do
    normalized = Calculator.normalize(raw_value, calibration)
    total = Calculator.total_travel(calibration)

    if total > 0 do
      {:ok, Float.round(normalized / total, precision)}
    else
      {:error, :invalid_calibration}
    end
  end
end
