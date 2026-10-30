defmodule Trenino.Train.GaugeBinding do
  @moduledoc "Train-owned telemetry, units and measured piecewise calibration."
  use Ecto.Schema
  import Ecto.Changeset
  alias Trenino.Hardware.StepperAxis
  alias Trenino.Train.GaugePoint
  @type t :: %__MODULE__{}
  schema "train_gauge_bindings" do
    belongs_to :train, Trenino.Train.Train
    belongs_to :stepper_axis, StepperAxis
    field :name, :string
    field :endpoint, :string
    field :value_key, :string
    field :input_unit, Ecto.Enum, values: [:raw, :mps, :kmh, :mph], default: :raw
    field :output_unit, Ecto.Enum, values: [:raw, :mps, :kmh, :mph], default: :raw
    field :multiplier, :float, default: 1.0
    field :offset, :float, default: 0.0
    field :absolute_value, :boolean, default: false
    field :out_of_range, Ecto.Enum, values: [:clamp, :reject], default: :clamp
    field :inactive_behavior, Ecto.Enum, values: [:hold, :release], default: :hold
    field :stale_after_ms, :integer, default: 2000
    field :enabled, :boolean, default: false
    field :calibration_valid, :boolean, default: true
    field :calibration_reviewed, :boolean, default: false
    embeds_many :points, GaugePoint, on_replace: :delete
    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = binding, attrs, axis \\ nil) do
    binding
    |> cast(attrs, [
      :stepper_axis_id,
      :name,
      :endpoint,
      :value_key,
      :input_unit,
      :output_unit,
      :multiplier,
      :offset,
      :absolute_value,
      :out_of_range,
      :inactive_behavior,
      :stale_after_ms,
      :enabled,
      :calibration_reviewed
    ])
    |> cast_embed(:points, with: &GaugePoint.changeset/2)
    |> validate_required([
      :train_id,
      :stepper_axis_id,
      :name,
      :endpoint,
      :input_unit,
      :output_unit,
      :multiplier,
      :offset
    ])
    |> validate_length(:name, max: 100)
    |> validate_number(:stale_after_ms,
      greater_than_or_equal_to: 500,
      less_than_or_equal_to: 60_000
    )
    |> validate_units()
    |> validate_points(axis)
    |> review_calibration(
      Map.get(attrs, :calibration_reviewed, Map.get(attrs, "calibration_reviewed")) in [
        true,
        "true"
      ]
    )
    |> validate_enabled(axis)
    |> foreign_key_constraint(:train_id)
    |> foreign_key_constraint(:stepper_axis_id)
    |> unique_constraint([:train_id, :stepper_axis_id])
  end

  defp review_calibration(cs, reviewed?) do
    cond do
      cs.valid? and reviewed? and
          Map.has_key?(cs.changes, :points) ->
        cs |> put_change(:calibration_valid, true) |> put_change(:calibration_reviewed, true)

      Map.has_key?(cs.changes, :stepper_axis_id) and cs.data.id != nil ->
        put_change(cs, :calibration_valid, false)
        |> put_change(:calibration_reviewed, false)
        |> put_change(:enabled, false)

      Map.has_key?(cs.changes, :points) and not reviewed? ->
        put_change(cs, :calibration_reviewed, false)

      true ->
        cs
    end
  end

  defp validate_units(cs) do
    units = [get_field(cs, :input_unit), get_field(cs, :output_unit)]

    if :raw in units and units != [:raw, :raw],
      do: add_error(cs, :output_unit, "raw units only convert to raw"),
      else: cs
  end

  defp validate_points(cs, axis) do
    points = get_field(cs, :points)

    cs =
      if length(points) in 2..32,
        do: cs,
        else: add_error(cs, :points, "requires 2 to 32 measured points")

    pairs = Enum.chunk_every(points, 2, 1, :discard)

    values =
      Enum.all?(pairs, fn [a, b] ->
        is_number(a.value) and is_number(b.value) and a.value < b.value
      end)

    deltas =
      Enum.map(pairs, fn [a, b] ->
        if is_integer(a.position) and is_integer(b.position), do: b.position - a.position, else: 0
      end)

    monotonic = Enum.all?(deltas, &(&1 > 0)) or Enum.all?(deltas, &(&1 < 0))

    cs =
      if values and monotonic,
        do: cs,
        else:
          add_error(cs, :points, "values must increase and positions must be strictly monotonic")

    validate_bounds(cs, points, axis)
  end

  defp validate_bounds(cs, points, %StepperAxis{} = axis) do
    if Enum.all?(points, fn p ->
         is_integer(p.position) and p.position >= axis.min_position and
           p.position <= axis.max_position
       end), do: cs, else: add_error(cs, :points, "positions must be within axis limits")
  end

  defp validate_bounds(cs, _, _), do: cs

  defp validate_enabled(cs, %StepperAxis{} = axis) do
    if get_field(cs, :enabled) and
         not (axis.commissioned and axis.idle_behavior == :hold and
                get_field(cs, :calibration_valid) and get_field(cs, :calibration_reviewed)),
       do: add_error(cs, :enabled, "requires commissioned hold axis and valid calibration"),
       else: cs
  end

  defp validate_enabled(cs, _), do: add_error(cs, :stepper_axis_id, "select an existing axis")
end
