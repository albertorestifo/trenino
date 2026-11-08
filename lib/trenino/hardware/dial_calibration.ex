defmodule Trenino.Hardware.DialCalibration do
  @moduledoc """
  The measured dial of one gauge: dial value -> position in steps from the end stop, and
  the unit the printed dial shows. The dial belongs to the hardware, so every train
  binding on the gauge shares it.

  Kept in its own table (not on `Gauge`) so saving or reviewing a dial never touches the
  applied-configuration fingerprint.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Trenino.Hardware.{DialPoint, Gauge}

  @type t :: %__MODULE__{}
  @units [:raw, :mps, :kmh, :mph]

  schema "hardware_dial_calibrations" do
    belongs_to :gauge, Gauge
    field :output_unit, Ecto.Enum, values: @units, default: :raw
    field :valid, :boolean, default: true
    field :reviewed, :boolean, default: false
    embeds_many :points, DialPoint, on_replace: :delete
    timestamps(type: :utc_datetime)
  end

  @doc """
  Validates points and unit against the gauge travel. Passing `reviewed: true`
  with otherwise valid data marks the dial valid and reviewed; any change to the
  points or unit without it clears the review, and an explicit `reviewed: false` clears it
  even when nothing else changed.
  """
  @spec changeset(t(), map(), Gauge.t() | nil) :: Ecto.Changeset.t()
  def changeset(%__MODULE__{} = calibration, attrs, gauge \\ nil) do
    reviewed? = review_request(attrs)

    calibration
    |> cast(attrs, [:output_unit])
    |> cast_embed(:points, with: &DialPoint.changeset/2, required: true)
    |> validate_required([:gauge_id, :output_unit])
    |> validate_points(gauge)
    |> review(reviewed?)
    |> foreign_key_constraint(:gauge_id)
    |> unique_constraint(:gauge_id)
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

  defp validate_points(cs, gauge) do
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

    validate_bounds(cs, points, gauge)
  end

  defp validate_bounds(cs, points, %Gauge{travel: travel}) do
    if Enum.all?(points, &(is_integer(&1.position) and &1.position in 0..travel)),
      do: cs,
      else: add_error(cs, :points, "positions must be between 0 and the gauge travel (#{travel})")
  end

  defp validate_bounds(cs, _, _), do: cs
end
