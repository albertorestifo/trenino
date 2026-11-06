defmodule Trenino.Hardware.InputNormalizer do
  @moduledoc """
  Normalizes a raw analog reading to a 0.0-1.0 float using its calibration.

  The calibration system works in two stages:

  1. `Calculator.normalize/2` converts the raw ADC value to a calibrated
     integer (0 to total_travel).
  2. This module divides by total_travel and rounds to 2 decimals.

  For example, with calibration min=100 and max=900 (total travel 800), a raw
  reading of 512 normalizes to 412, which becomes `0.52`.
  """

  alias Trenino.Hardware.Calibration.Calculator
  alias Trenino.Hardware.Input.Calibration

  @spec normalize(integer(), Calibration.t() | nil) ::
          {:ok, float()} | {:error, :no_calibration | :invalid_calibration}
  def normalize(_raw_value, nil), do: {:error, :no_calibration}

  def normalize(raw_value, %Calibration{} = calibration) do
    normalized = Calculator.normalize(raw_value, calibration)
    total = Calculator.total_travel(calibration)

    if total > 0 do
      {:ok, Float.round(normalized / total, 2)}
    else
      {:error, :invalid_calibration}
    end
  end
end
