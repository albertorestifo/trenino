defmodule Trenino.Train.GaugeBinding do
  @moduledoc """
  Train-owned choice of speed source for a gauge: endpoint, input unit and value
  transform. The dial itself (points, dial unit, review) belongs to the gauge, see
  `Trenino.Hardware.DialCalibration`. A stale value holds the needle where it is.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias Trenino.Hardware.{DialCalibration, Gauge}
  @type t :: %__MODULE__{}
  schema "train_gauge_bindings" do
    belongs_to :train, Trenino.Train.Train
    belongs_to :gauge, Gauge
    field :name, :string
    field :endpoint, :string
    field :value_key, :string
    field :input_unit, Ecto.Enum, values: [:raw, :mps, :kmh, :mph], default: :raw
    field :multiplier, :float, default: 1.0
    field :offset, :float, default: 0.0
    field :absolute_value, :boolean, default: false
    field :out_of_range, Ecto.Enum, values: [:clamp, :reject], default: :clamp
    field :stale_after_ms, :integer, default: 2000
    field :enabled, :boolean, default: false
    timestamps(type: :utc_datetime)
  end

  @doc """
  `gauge` is the selected `Gauge` with `:dial_calibration` preloaded; enabling and the
  unit check use that calibration.
  """
  def changeset(%__MODULE__{} = binding, attrs, gauge \\ nil) do
    binding
    |> cast(attrs, [
      :gauge_id,
      :name,
      :endpoint,
      :value_key,
      :input_unit,
      :multiplier,
      :offset,
      :absolute_value,
      :out_of_range,
      :stale_after_ms,
      :enabled
    ])
    |> validate_required([
      :train_id,
      :gauge_id,
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
    |> validate_units(calibration(gauge))
    |> disable_on_gauge_change()
    |> validate_enabled(gauge)
    |> foreign_key_constraint(:train_id)
    |> foreign_key_constraint(:gauge_id)
    |> unique_constraint([:train_id, :gauge_id])
  end

  @doc "The gauge's dial calibration, or `nil` when none is recorded or it is not loaded."
  @spec calibration(Gauge.t() | nil) :: DialCalibration.t() | nil
  def calibration(%Gauge{dial_calibration: %DialCalibration{} = calibration}),
    do: calibration

  def calibration(_), do: nil

  # A binding moved to another gauge is a different physical dial: it must be re-enabled.
  defp disable_on_gauge_change(cs) do
    if Map.has_key?(cs.changes, :gauge_id) and cs.data.id != nil,
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
          "raw input only converts to a raw dial; this gauge dial is in #{output}"
        ),
      else: cs
  end

  defp validate_units(cs, nil), do: cs

  defp validate_enabled(cs, %Gauge{} = gauge) do
    if get_field(cs, :enabled) and not enableable?(gauge),
      do: add_error(cs, :enabled, "requires a valid, reviewed dial calibration"),
      else: cs
  end

  defp validate_enabled(cs, _), do: add_error(cs, :gauge_id, "select an existing gauge")

  @doc "True when the gauge's dial is valid and reviewed, so a binding on it may run."
  @spec enableable?(Gauge.t()) :: boolean()
  def enableable?(%Gauge{} = gauge),
    do: match?(%DialCalibration{valid: true, reviewed: true}, calibration(gauge))
end
