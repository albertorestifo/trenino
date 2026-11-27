defmodule Trenino.Train.GaugeUnit do
  @moduledoc """
  Units of gauge bindings (what the simulator reports) and dial calibrations (what the
  printed dial shows), and conversion between them. Kept apart from the schemas so both
  can use the unit list at compile time.
  """

  @speed_units [:mps, :kmh, :mph]
  @pressure_units [:bar, :kpa, :psi]

  @doc """
  Every gauge unit: `:raw` (no conversion), speeds and pressures. A value converts only
  within its family (speed to speed, pressure to pressure); `:raw` only to `:raw`.
  """
  @spec units() :: [atom()]
  def units, do: [:raw | @speed_units ++ @pressure_units]

  @doc "True when a value in `from` can be shown on a dial in `to`."
  @spec convertible?(atom(), atom()) :: boolean()
  def convertible?(unit, unit), do: unit in units()
  def convertible?(from, to), do: family(from) != nil and family(from) == family(to)

  @spec convert(term(), atom(), atom()) :: {:ok, float()} | {:error, atom()}
  def convert(n, unit, unit) when is_number(n) and unit in @speed_units, do: {:ok, n * 1.0}
  def convert(n, unit, unit) when is_number(n) and unit in @pressure_units, do: {:ok, n * 1.0}

  def convert(n, from, to)
      when is_number(n) and from in @speed_units and to in @speed_units do
    {:ok, n * factor(from) / factor(to)}
  rescue
    ArithmeticError -> {:error, :non_finite_sample}
  end

  def convert(n, from, to)
      when is_number(n) and from in @pressure_units and to in @pressure_units do
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
  # Pressures in bar.
  defp factor(:bar), do: 1.0
  defp factor(:kpa), do: 0.01
  defp factor(:psi), do: 0.0689475729

  defp family(unit) when unit in @speed_units, do: :speed
  defp family(unit) when unit in @pressure_units, do: :pressure
  defp family(_), do: nil
end
