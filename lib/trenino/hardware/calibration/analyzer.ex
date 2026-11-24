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

  @typedoc "Calibration fields found by `circular_calibration/3`."
  @type circular_result :: %{
          min_value: non_neg_integer(),
          max_value: non_neg_integer(),
          is_inverted: boolean(),
          has_rollover: boolean()
        }

  # A lever must turn the magnet at least this far, and short of a full turn by enough
  # that the two ends can't be confused.
  @min_circular_travel_degrees 5
  @max_circular_travel_degrees 330

  @doc """
  Calibration of a circular (angle) sensor from unwrapped positions.

  The session follows the lever as one unwrapped position from the first reading of
  the min step to the last of the max step, adding the shortest step between readings,
  so `min_positions` and `max_positions` are on one continuous scale (they may be
  negative or beyond `n`). Each end is the median of its held positions. The signed
  distance between them gives direction and travel, whatever the user did during the
  sweep.

  Returns `{:error, :range_too_small}` under #{@min_circular_travel_degrees}° and
  `{:error, :range_too_large}` over #{@max_circular_travel_degrees}°.
  """
  @spec circular_calibration([integer()], [integer()], pos_integer()) ::
          {:ok, circular_result()} | {:error, :range_too_small | :range_too_large}
  def circular_calibration([_ | _] = min_positions, [_ | _] = max_positions, n) do
    min_pos = median_position(min_positions)
    max_pos = median_position(max_positions)
    travel = abs(max_pos - min_pos)

    cond do
      travel * 360 < @min_circular_travel_degrees * n ->
        {:error, :range_too_small}

      travel * 360 > @max_circular_travel_degrees * n ->
        {:error, :range_too_large}

      true ->
        {:ok,
         %{
           min_value: Integer.mod(min_pos, n),
           max_value: Integer.mod(max_pos, n),
           is_inverted: max_pos < min_pos,
           has_rollover: Integer.floor_div(min_pos, n) != Integer.floor_div(max_pos, n)
         }}
    end
  end

  defp median_position(positions) do
    sorted = Enum.sort(positions)
    len = length(sorted)
    mid = div(len, 2)

    if rem(len, 2) == 0 do
      Integer.floor_div(Enum.at(sorted, mid - 1) + Enum.at(sorted, mid), 2)
    else
      Enum.at(sorted, mid)
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
