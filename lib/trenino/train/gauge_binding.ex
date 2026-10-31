defmodule Trenino.Train.GaugeBinding do
  @moduledoc """
  Train-owned choice of speed source for a stepper axis: endpoint, input unit and
  value transform. The dial itself (points, dial unit, review) belongs to the axis, see
  `Trenino.Hardware.DialCalibration`.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Trenino.Hardware.{DialCalibration, StepperAxis}
  @type t :: %__MODULE__{}
  schema "train_gauge_bindings" do
    belongs_to :train, Trenino.Train.Train
    belongs_to :stepper_axis, StepperAxis
    field :name, :string
    field :endpoint, :string
    field :value_key, :string
    field :input_unit, Ecto.Enum, values: [:raw, :mps, :kmh, :mph], default: :raw
    field :multiplier, :float, default: 1.0
    field :offset, :float, default: 0.0
    field :absolute_value, :boolean, default: false
    field :out_of_range, Ecto.Enum, values: [:clamp, :reject], default: :clamp
    field :inactive_behavior, Ecto.Enum, values: [:hold, :release], default: :hold
    field :stale_after_ms, :integer, default: 2000
    field :enabled, :boolean, default: false
    timestamps(type: :utc_datetime)
  end

  @doc """
  `axis` is the selected `StepperAxis` with `:dial_calibration` preloaded; enabling and
  the unit check use that calibration.
  """
  def changeset(%__MODULE__{} = binding, attrs, axis \\ nil) do
    binding
    |> cast(attrs, [
      :stepper_axis_id,
      :name,
      :endpoint,
      :value_key,
      :input_unit,
      :multiplier,
      :offset,
      :absolute_value,
      :out_of_range,
      :inactive_behavior,
      :stale_after_ms,
      :enabled
    ])
    |> validate_required([
      :train_id,
      :stepper_axis_id,
      :name,
      :endpoint,
      :input_unit,
      :multiplier,
      :offset
    ])
    |> validate_length(:name, max: 100)
    |> validate_number(:stale_after_ms,
      greater_than_or_equal_to: 500,
      less_than_or_equal_to: 60_000
    )
    |> validate_units(calibration(axis))
    |> disable_on_axis_change()
    |> validate_enabled(axis)
    |> foreign_key_constraint(:train_id)
    |> foreign_key_constraint(:stepper_axis_id)
    |> unique_constraint([:train_id, :stepper_axis_id])
  end

  @doc "The axis's dial calibration, or `nil` when none is recorded or it is not loaded."
  @spec calibration(StepperAxis.t() | nil) :: DialCalibration.t() | nil
  def calibration(%StepperAxis{dial_calibration: %DialCalibration{} = calibration}),
    do: calibration

  def calibration(_), do: nil

  # A binding moved to another axis is a different physical dial: it must be re-enabled.
  defp disable_on_axis_change(cs) do
    if Map.has_key?(cs.changes, :stepper_axis_id) and cs.data.id != nil,
      do: put_change(cs, :enabled, false),
      else: cs
  end

  defp validate_units(cs, %DialCalibration{output_unit: output}) do
    units = [get_field(cs, :input_unit), output]

    if :raw in units and units != [:raw, :raw],
      do:
        add_error(
          cs,
          :input_unit,
          "raw input only converts to a raw dial; this axis dial is in #{output}"
        ),
      else: cs
  end

  defp validate_units(cs, nil), do: cs

  defp validate_enabled(cs, %StepperAxis{} = axis) do
    if get_field(cs, :enabled) and not enableable?(axis),
      do:
        add_error(
          cs,
          :enabled,
          "requires a commissioned hold axis with a valid, reviewed dial calibration"
        ),
      else: cs
  end

  defp validate_enabled(cs, _), do: add_error(cs, :stepper_axis_id, "select an existing axis")

  defp enableable?(axis) do
    case calibration(axis) do
      %DialCalibration{valid: true, reviewed: true} ->
        axis.commissioned and axis.idle_behavior == :hold

      _ ->
        false
    end
  end
end
