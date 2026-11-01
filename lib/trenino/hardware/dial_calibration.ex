defmodule Trenino.Hardware.DialCalibration do
  @moduledoc """
  The measured dial of one stepper axis: dial value -> position, and the unit the
  printed dial shows. The dial belongs to the hardware, so every train binding on the
  axis shares it.

  Kept in its own table (not on `StepperAxis`) so the axis stays purely electrical:
  saving or reviewing a dial never touches the motion fields, the commissioning flag
  or the applied-configuration fingerprint.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Trenino.Hardware.{DialPoint, StepperAxis}

  @type t :: %__MODULE__{}
  @units [:raw, :mps, :kmh, :mph]

  schema "hardware_stepper_dial_calibrations" do
    belongs_to :stepper_axis, StepperAxis
    field :output_unit, Ecto.Enum, values: @units, default: :raw
    field :valid, :boolean, default: true
    field :reviewed, :boolean, default: false
    embeds_many :points, DialPoint, on_replace: :delete
    timestamps(type: :utc_datetime)
  end

  @doc """
  Validates points and unit against the axis soft limits. Passing `reviewed: true`
  with otherwise valid data marks the dial valid and reviewed; any change to the
  points or unit without it clears the review, and an explicit `reviewed: false` clears it
  even when nothing else changed.
  """
  @spec changeset(t(), map(), StepperAxis.t() | nil) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = calibration, attrs, axis \\ nil) do
    reviewed? = review_request(attrs)

    calibration
    |> cast(attrs, [:output_unit])
    |> cast_embed(:points, with: &DialPoint.changeset/2, required: true)
    |> validate_required([:stepper_axis_id, :output_unit])
    |> validate_points(axis)
    |> review(reviewed?)
    |> foreign_key_constraint(:stepper_axis_id)
    |> unique_constraint(:stepper_axis_id)
  end

  defp review_request(attrs) do
    case Map.get(attrs, :reviewed, Map.get(attrs, "reviewed")) do
      value when value in [true, "true"] -> true
      value when value in [false, "false"] -> :withdraw
      _ -> false
    end
  end

  defp review(cs, true) do
    if cs.valid?,
      do: cs |> put_change(:valid, true) |> put_change(:reviewed, true),
      else: cs
  end

  # An explicit `reviewed: false` withdraws the review even when nothing else changed.
  defp review(cs, :withdraw), do: put_change(cs, :reviewed, false)

  defp review(cs, false) do
    if Map.has_key?(cs.changes, :points) or Map.has_key?(cs.changes, :output_unit),
      do: put_change(cs, :reviewed, false),
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
       end),
       do: cs,
       else: add_error(cs, :points, "positions must be within axis limits")
  end

  defp validate_bounds(cs, _, _), do: cs
end
