defmodule Trenino.Hardware.InputNormalizerTest do
  use ExUnit.Case, async: true

  alias Trenino.Hardware.Input.Calibration
  alias Trenino.Hardware.InputNormalizer

  @calibration %Calibration{
    min_value: 100,
    max_value: 900,
    max_hardware_value: 1023,
    has_rollover: false,
    is_inverted: false
  }

  test "normalizes to a 2-decimal fraction of the calibrated travel" do
    assert InputNormalizer.normalize(512, @calibration) == {:ok, 0.52}
    assert InputNormalizer.normalize(100, @calibration) == {:ok, 0.0}
    assert InputNormalizer.normalize(900, @calibration) == {:ok, 1.0}
  end

  test "keeps the requested precision so adjacent ADC steps stay distinct" do
    assert InputNormalizer.normalize(512, @calibration, 4) == {:ok, 0.515}

    values = for raw <- 500..510, do: elem(InputNormalizer.normalize(raw, @calibration, 4), 1)
    assert length(Enum.uniq(values)) == 11
  end

  test "clamps readings outside the calibrated range" do
    assert InputNormalizer.normalize(0, @calibration) == {:ok, 0.0}
    assert InputNormalizer.normalize(1023, @calibration) == {:ok, 1.0}
  end

  test "follows an inverted calibration" do
    inverted = %{@calibration | min_value: 900, max_value: 100, is_inverted: true}

    assert InputNormalizer.normalize(900, inverted) == {:ok, 0.0}
    assert InputNormalizer.normalize(100, inverted) == {:ok, 1.0}
  end

  test "returns an error without calibration" do
    assert InputNormalizer.normalize(512, nil) == {:error, :no_calibration}
  end

  test "returns an error for a zero-travel calibration" do
    flat = %{@calibration | max_value: 100}

    assert InputNormalizer.normalize(100, flat) == {:error, :invalid_calibration}
  end
end
