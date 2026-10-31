defmodule Trenino.Train.GaugeMapper do
  @moduledoc "Pure conversion and piecewise interpolation; never sends physical commands."
  alias Trenino.Hardware.{DialCalibration, StepperAxis}
  alias Trenino.Train.GaugeBinding
  @type mapping :: %{value: float(), target: integer(), clamped: boolean()}
  @spec map(GaugeBinding.t(), term(), StepperAxis.t()) :: {:ok, mapping()} | {:error, atom()}
  def map(%GaugeBinding{} = b, raw, %StepperAxis{} = a) do
    with %DialCalibration{valid: true} = cal <- GaugeBinding.calibration(a),
         {:ok, converted} <- convert(raw, b.input_unit, cal.output_unit),
         {:ok, value} <- transform(converted, b),
         {:ok, target, clamped} <- interpolate(value, cal.points, b.out_of_range),
         true <- target >= a.min_position and target <= a.max_position do
      {:ok, %{value: Float.round(value, 2), target: target, clamped: clamped}}
    else
      nil -> {:error, :invalid_calibration_or_limits}
      %DialCalibration{} -> {:error, :invalid_calibration_or_limits}
      false -> {:error, :invalid_calibration_or_limits}
      error -> error
    end
  rescue
    ArithmeticError -> {:error, :non_finite_mapping}
  end

  @doc """
  Target position for a value already in dial units (no unit conversion or transform).
  Used to preview a calibration before it is saved.
  """
  @spec dial_target(DialCalibration.t(), term(), :clamp | :reject) ::
          {:ok, mapping()} | {:error, atom()}
  def dial_target(%DialCalibration{} = cal, value, policy) when is_number(value) do
    with {:ok, target, clamped} <- interpolate(value * 1.0, cal.points, policy) do
      {:ok, %{value: Float.round(value * 1.0, 2), target: target, clamped: clamped}}
    end
  end

  def dial_target(_, _, _), do: {:error, :invalid_sample_or_units}

  @spec convert(term(), atom(), atom()) :: {:ok, float()} | {:error, atom()}
  def convert(n, unit, unit) when is_number(n) and unit in [:mps, :kmh, :mph], do: {:ok, n * 1.0}

  def convert(n, from, to)
      when is_number(n) and from in [:mps, :kmh, :mph] and to in [:mps, :kmh, :mph] do
    {:ok, n * factor(from) / factor(to)}
  rescue
    ArithmeticError -> {:error, :non_finite_sample}
  end

  def convert(n, :raw, :raw) when is_number(n) do
    {:ok, n * 1.0}
  rescue
    ArithmeticError -> {:error, :non_finite_sample}
  end

  def convert(_, _, _), do: {:error, :invalid_sample_or_units}
  defp factor(:mps), do: 1.0
  defp factor(:kmh), do: 1 / 3.6
  defp factor(:mph), do: 0.44704

  defp transform(v, b) when is_number(b.multiplier) and is_number(b.offset) do
    value = if b.absolute_value, do: abs(v), else: v
    {:ok, value * b.multiplier + b.offset}
  rescue
    ArithmeticError -> {:error, :non_finite_transform}
  end

  defp transform(_, _), do: {:error, :invalid_transform}

  defp interpolate(v, [first, second | rest] = points, policy) do
    last = List.last(points)

    cond do
      v < first.value -> boundary(first.position, policy)
      v > last.value -> boundary(last.position, policy)
      v == last.value -> {:ok, last.position, false}
      true -> interval(v, [first, second | rest])
    end
  end

  defp interpolate(_, _, _), do: {:error, :invalid_calibration}

  defp interval(v, [a, b | _]) when v >= a.value and v < b.value do
    {:ok, round(a.position + (v - a.value) / (b.value - a.value) * (b.position - a.position)),
     false}
  end

  defp interval(v, [_ | rest]), do: interval(v, rest)
  defp interval(_, _), do: {:error, :invalid_calibration}
  defp boundary(_, :reject), do: {:error, :out_of_range}
  defp boundary(position, :clamp), do: {:ok, position, true}
end
