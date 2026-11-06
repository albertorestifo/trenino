defmodule Trenino.Train.SelectorMapper do
  @moduledoc """
  Resolves a normalized hardware input value to a selector position.

  A selector splits a potentiometer's 0.0-1.0 range into positions. Ranges are
  matched inclusively on both ends and never overlap, so a value matches at
  most one position. Values in the gaps between positions match nothing: the
  caller keeps the selector in its last position. Those gaps are the
  selector's "play", and they absorb ADC jitter at a boundary without any
  time-based hysteresis.

  Unlike `Trenino.Train.LeverMapper`, there are no simulator ranges, no
  narrow-gate padding and no half-open boundaries: a selector only needs to
  know which detent the knob sits in.
  """

  alias Trenino.Train.SelectorPosition

  @typedoc "Anything with a hardware input range."
  @type range :: %{
          required(:input_min) => float(),
          required(:input_max) => float(),
          optional(atom()) => any()
        }

  @typedoc "A position range produced by `even_split/2`."
  @type split_range :: %{index: non_neg_integer(), input_min: float(), input_max: float()}

  @default_dead_zone 0.2
  @min_dead_zone 0.05
  @max_dead_zone 0.5
  @min_gap 0.02

  @doc """
  The smallest gap allowed between two neighbouring positions.

  Readings are rounded to 2 decimals before matching, so a gap of 0.02 is the
  narrowest one that still holds a reachable value (e.g. 0.31 between 0.30
  and 0.32). Anything narrower lets the selector flap between positions.
  """
  @spec min_gap() :: float()
  def min_gap, do: @min_gap

  @doc """
  Find the position whose range contains `input_value`.

  Returns `nil` when the value falls in a dead zone between positions.
  """
  @spec find_position([SelectorPosition.t() | range()], number()) ::
          SelectorPosition.t() | range() | nil
  def find_position(positions, input_value) when is_number(input_value) do
    Enum.find(positions, fn %{input_min: min, input_max: max} ->
      input_value >= min and input_value <= max
    end)
  end

  @doc """
  Split the 0.0-1.0 range into `count` equal positions with dead zones.

  Each position gets a slot of `1 / count`. A `dead_zone` fraction of each
  slot (default #{@default_dead_zone}, allowed #{@min_dead_zone}..#{@max_dead_zone})
  is left as a gap, half on each side, between neighbouring positions. Gaps
  are never narrower than `min_gap/0`. The first position starts at 0.0 and
  the last ends at 1.0, so the ends of travel are always reachable.

  Bounds land on the 2-decimal grid and the result always passes
  `validate_layout/1` for up to 12 positions.

  ## Examples

      iex> SelectorMapper.even_split(3)
      [
        %{index: 0, input_min: 0.0, input_max: 0.3},
        %{index: 1, input_min: 0.37, input_max: 0.63},
        %{index: 2, input_min: 0.7, input_max: 1.0}
      ]

  """
  @spec even_split(pos_integer(), float()) :: [split_range()]
  def even_split(count, dead_zone \\ @default_dead_zone)
      when is_integer(count) and count >= 1 and is_float(dead_zone) and
             dead_zone >= @min_dead_zone and dead_zone <= @max_dead_zone do
    # Work in hundredths so every bound is an exact grid point
    slot = 100 / count
    half_gap = max(slot * dead_zone / 2, @min_gap * 100 / 2)

    for index <- 0..(count - 1) do
      input_min = if index == 0, do: 0, else: ceil_hundredths(index * slot + half_gap)

      input_max =
        if index == count - 1, do: 100, else: floor_hundredths((index + 1) * slot - half_gap)

      %{index: index, input_min: input_min / 100, input_max: input_max / 100}
    end
  end

  # Rounding first drops float noise (100 / 3 * 0.9 is 29.999...), so a bound
  # that is exactly on the grid stays there.
  defp ceil_hundredths(value), do: value |> Float.round(6) |> :math.ceil() |> trunc()
  defp floor_hundredths(value), do: value |> Float.round(6) |> :math.floor() |> trunc()

  @doc """
  Check that no two position ranges overlap and that neighbours are at least
  `min_gap/0` apart.

  Ranges are inclusive on both ends, so positions that share a boundary
  (`a.input_max == b.input_min`) overlap too: a reading on that boundary
  would match both.
  """
  @spec validate_layout([range()]) :: :ok | {:error, :overlap}
  def validate_layout(ranges) do
    ranges
    |> Enum.sort_by(& &1.input_min)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [a, b] -> Float.round((b.input_min - a.input_max) / 1, 2) >= @min_gap end)
    |> if(do: :ok, else: {:error, :overlap})
  end
end
