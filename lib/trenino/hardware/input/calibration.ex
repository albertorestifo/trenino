defmodule Trenino.Hardware.Input.Calibration do
  @moduledoc """
  Calibration of an analog input: the raw values at the two ends of its travel.

  `circular` is set for magnetic angle sensors, which report a full turn: their raw
  values are positions on a circle, so the travel may cross the sensor's 0/max point
  anywhere and readings past either end clamp to the nearer end round the circle.
  ADC inputs are not circular and keep `has_rollover` for the 1023/0 wrap.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Trenino.Hardware.Input

  schema "device_input_calibrations" do
    field :max_hardware_value, :integer
    field :min_value, :integer
    field :max_value, :integer
    field :has_rollover, :boolean, default: false
    field :is_inverted, :boolean, default: false
    field :circular, :boolean, default: false

    belongs_to :input, Input

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(calibration, attrs) do
    calibration
    |> cast(attrs, [
      :max_hardware_value,
      :min_value,
      :max_value,
      :has_rollover,
      :is_inverted,
      :circular,
      :input_id
    ])
    |> validate_required([
      :max_hardware_value,
      :min_value,
      :max_value,
      :has_rollover,
      :is_inverted,
      :input_id
    ])
  end
end
