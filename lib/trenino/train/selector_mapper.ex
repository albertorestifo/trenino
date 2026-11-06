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

  @doc """
  Find the position whose range contains `input_value`.

  Returns `nil` when the value falls in a dead zone between positions.
  """
  @spec find_position([SelectorPosition.t() | range()], float()) ::
          SelectorPosition.t() | range() | nil
  def find_position(positions, input_value) when is_float(input_value) do
    Enum.find(positions, fn %{input_min: min, input_max: max} ->
      input_value >= min and input_value <= max
    end)
  end

  @doc """
  Split the 0.0-1.0 range into `count` equal positions with dead zones.

  Each position gets a slot of `1 / count`. A `dead_zone` fraction of each
  slot (default #{@default_dead_zone}) is left as a gap, half on each side,
  between neighbouring positions. The first position starts at 0.0 and the
  last ends at 1.0, so the ends of travel are always reachable.

  Bounds are rounded inwards to 2 decimals (minimums up, maximums down), so
  any positive `dead_zone` leaves a gap of at least 0.01 between neighbours
  and the result always passes `validate_layout/1`.

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
      when is_integer(count) and count >= 1 and is_float(dead_zone) and dead_zone > 0.0 and
             dead_zone < 1.0 do
    slot = 1.0 / count
    half_gap = slot * dead_zone / 2

    for index <- 0..(count - 1) do
      input_min = if index == 0, do: 0.0, else: index * slot + half_gap
      input_max = if index == count - 1, do: 1.0, else: (index + 1) * slot - half_gap

      %{index: index, input_min: round_up(input_min), input_max: round_down(input_max)}
    end
  end

  # Works in hundredths: Float.floor(0.3, 2) is 0.29 because 0.3 is stored as
  # 0.2999..., so a bound already on the 2-decimal grid would still move.
  # Rounding the hundredths first drops that float noise.
  defp round_up(value), do: :math.ceil(Float.round(value * 100, 4)) / 100
  defp round_down(value), do: :math.floor(Float.round(value * 100, 4)) / 100

  @doc """
  Check that no two position ranges overlap.

  Ranges are inclusive on both ends, so positions that share a boundary
  (`a.input_max == b.input_min`) overlap too: a reading on that boundary
  would match both.
  """
  @spec validate_layout([range()]) :: :ok | {:error, :overlap}
  def validate_layout(ranges) do
    ranges
    |> Enum.sort_by(& &1.input_min)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.all?(fn [a, b] -> b.input_min > a.input_max end)
    |> if(do: :ok, else: {:error, :overlap})
  end
end
