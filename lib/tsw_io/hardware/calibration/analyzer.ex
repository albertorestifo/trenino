defmodule TswIo.Hardware.Calibration.Analyzer do
  @moduledoc """
  Analyzes calibration sweep data to detect input characteristics.

  The analyzer detects:
  - `inverted` - input values decrease as physical position increases
  - `rollover` - values wrap from max (1023) to 0 during sweep
  """

  alias TswIo.Hardware.Calibration.Analyzer.Analysis

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

  For inverted inputs, returns the inverted value (max_hardware - min_raw)
  so that Calculator can apply the same inversion to raw values.

  We use min/max instead of median to ensure the calibrated range is
  conservative (inside actual travel):
  - Normal: min of samples (lowest value at min position)
  - Inverted: max_hardware - max(samples) = lowest inverted value at min position
  """
  @spec calculate_min([integer()], Analysis.t(), integer()) :: integer()
  def calculate_min(min_samples, analysis, max_hardware_value \\ 1023)

  def calculate_min(min_samples, %Analysis{inverted: true}, max_hardware_value) do
    # For inverted: raw is HIGH at min position, so we take max(raw) to get
    # the conservative boundary, then invert it to get lowest inverted value
    max_hardware_value - Enum.max(min_samples)
  end

  def calculate_min(min_samples, %Analysis{inverted: false}, _max_hardware_value) do
    # For normal: take min(raw) to get conservative lowest value
    Enum.min(min_samples)
  end

  @doc """
  Calculates the logical maximum value from samples.

  For inverted inputs, returns the inverted value.
  For rollover inputs, accounts for the wrap-around by extending max_value
  past max_hardware_value.

  We use min/max instead of median to ensure the calibrated range is
  conservative (inside actual travel):
  - Normal: max of samples (highest value at max position)
  - Inverted: max_hardware - min(samples) = highest inverted value at max position
  """
  @spec calculate_max([integer()], [integer()], Analysis.t(), integer()) :: integer()
  def calculate_max(max_samples, _min_samples, %Analysis{} = analysis, max_hardware_value) do
    effective_max =
      if analysis.inverted do
        # For inverted: raw is LOW at max position
        # Take min(max_samples) to get conservative boundary, then invert
        max_hardware_value - Enum.min(max_samples)
      else
        # For normal: take max(max_samples) for conservative range
        Enum.max(max_samples)
      end

    if analysis.rollover do
      # For rollover, the range wraps around. Extend by adding (max_hardware + 1)
      # so that max_value > max_hardware_value, signaling to the Calculator
      # that values below min_value might need adjustment.
      effective_max + max_hardware_value + 1
    else
      effective_max
    end
  end

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
