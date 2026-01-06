defmodule Trenino.Hardware.Calibration.Analyzer do
  @moduledoc """
  Analyzes calibration sweep data to detect input characteristics.

  The analyzer detects:
  - `inverted` - input values decrease as physical position increases
  - `rollover` - values wrap from max (1023) to 0 during sweep
  """

  alias Trenino.Hardware.Calibration.Analyzer.Analysis

  @doc """
  Analyzes sweep samples to detect input characteristics.

  Returns an Analysis struct with boolean flags for each characteristic.

  ## Examples

      # Normal input (increasing values)
      iex> analyze_sweep([10, 50, 100, 150], 1023)
      {:ok, %Analysis{inverted: false, rollover: false}}

      # Inverted input (decreasing values)
      iex> analyze_sweep([150, 100, 50, 10], 1023)
      {:ok, %Analysis{inverted: true, rollover: false}}

      # Rollover detected
      iex> analyze_sweep([1020, 1022, 1023, 0, 5, 10], 1023)
      {:ok, %Analysis{inverted: false, rollover: true}}
  """
  @spec analyze_sweep([integer()], integer()) :: {:ok, Analysis.t()}
  def analyze_sweep(sweep_samples, _max_hardware_value) when length(sweep_samples) < 2 do
    {:ok, %Analysis{inverted: false, rollover: false}}
  end

  def analyze_sweep(sweep_samples, max_hardware_value) do
    {:ok,
     %Analysis{
       inverted: inverted?(sweep_samples),
       rollover: rollover?(sweep_samples, max_hardware_value)
     }}
  end

  @doc """
  Calculates the logical minimum value from samples.
  """
  @spec calculate_min([integer()], Analysis.t()) :: integer()
  def calculate_min(min_samples, analysis)

  def calculate_min(min_samples, %Analysis{inverted: true}), do: Enum.max(min_samples)
  def calculate_min(min_samples, %Analysis{inverted: false}), do: Enum.min(min_samples)

  @doc """
  Calculates the logical maximum value from samples.
  """
  @spec calculate_max([integer()], Analysis.t()) :: integer()
  def calculate_max(max_samples, %Analysis{inverted: true}), do: Enum.min(max_samples)
  def calculate_max(max_samples, %Analysis{inverted: false}), do: Enum.max(max_samples)

  # Private functions

  defp inverted?(sweep_samples) do
    deltas =
      sweep_samples
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> b - a end)

    median_delta = median(deltas)
    median_delta < 0
  end

  defp rollover?(sweep_samples, max_hardware_value) do
    deltas =
      sweep_samples
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.map(fn [a, b] -> abs(b - a) end)

    case deltas do
      [] ->
        false

      deltas ->
        median_delta = median(deltas)
        max_delta = Enum.max(deltas)

        # Rollover detected if:
        # 1. Max delta is significantly larger than median (3x)
        # 2. Max delta is close to hardware max (80%)
        threshold = max(median_delta * 3, 10)
        max_delta > threshold and max_delta > max_hardware_value * 0.8
    end
  end

  defp median([]), do: 0

  defp median(list) do
    sorted = Enum.sort(list)
    len = length(sorted)
    mid = div(len, 2)

    if rem(len, 2) == 0 do
      div(Enum.at(sorted, mid - 1) + Enum.at(sorted, mid), 2)
    else
      Enum.at(sorted, mid)
    end
  end
end
