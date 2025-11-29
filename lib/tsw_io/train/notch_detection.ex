defmodule TswIo.Train.NotchDetection do
  @moduledoc """
  Utility functions for lever notch detection and description suggestions.

  For actual calibration (detecting notches by moving the lever through its range),
  use `TswIo.Train.Calibration.LeverSession` which runs as a GenServer process.
  """

  @doc """
  Suggest default descriptions for notches based on their count and a preset type.

  Useful for common patterns like throttle notches (Idle, Notch 1-8, etc.)
  or reverser positions (Reverse, Neutral, Forward).

  ## Examples

      iex> suggest_descriptions(8, :throttle)
      ["Idle", "Notch 1", "Notch 2", "Notch 3", "Notch 4", "Notch 5", "Notch 6", "Full Power"]

      iex> suggest_descriptions(3, :reverser)
      ["Reverse", "Neutral", "Forward"]

  """
  @spec suggest_descriptions(integer(), atom()) :: [String.t()]
  def suggest_descriptions(count, :throttle) when count > 2 do
    middle_count = count - 2

    ["Idle"] ++
      Enum.map(1..middle_count, fn i -> "Notch #{i}" end) ++
      ["Full Power"]
  end

  def suggest_descriptions(3, :reverser) do
    ["Reverse", "Neutral", "Forward"]
  end

  def suggest_descriptions(count, _type) do
    Enum.map(0..(count - 1), fn i -> "Position #{i}" end)
  end
end
