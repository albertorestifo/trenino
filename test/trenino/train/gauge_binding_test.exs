defmodule Trenino.Train.GaugeBindingTest do
  use Trenino.DataCase, async: true
  alias Trenino.Hardware.{DialCalibration, Gauge}
  alias Trenino.Train.GaugeBinding

  @reviewed %DialCalibration{valid: true, reviewed: true, output_unit: :raw}

  defp attrs(extra \\ %{}),
    do: Map.merge(%{name: "Speed", endpoint: "Speed", gauge_id: 1}, extra)

  defp gauge(calibration, id \\ 1),
    do: %Gauge{id: id, travel: 3780, dial_calibration: calibration}

  defp changeset(attrs, gauge),
    do: GaugeBinding.changeset(%GaugeBinding{train_id: 1}, attrs, gauge)

  test "a binding carries no calibration or idle policy of its own" do
    fields = GaugeBinding.__schema__(:fields)

    for gone <- [
          :points,
          :output_unit,
          :calibration_valid,
          :calibration_reviewed,
          :inactive_behavior,
          :stepper_axis_id
        ],
        do: refute(gone in fields)

    assert :gauge_id in fields
  end

  test "enabling needs a gauge with a valid, reviewed dial" do
    enable = attrs(%{enabled: true})

    assert changeset(enable, gauge(@reviewed)).valid?
    refute changeset(enable, gauge(nil)).valid?
    refute changeset(enable, gauge(%{@reviewed | reviewed: false})).valid?
    refute changeset(enable, gauge(%{@reviewed | valid: false})).valid?
    assert changeset(attrs(), gauge(nil)).valid?
  end

  test "enableable?/1 reads the gauge's dial" do
    assert GaugeBinding.enableable?(gauge(@reviewed))
    refute GaugeBinding.enableable?(gauge(nil))
    refute GaugeBinding.enableable?(gauge(%{@reviewed | reviewed: false}))
    refute GaugeBinding.enableable?(gauge(%{@reviewed | valid: false}))
  end

  test "raw input only fits a raw dial" do
    mph = %DialCalibration{valid: true, reviewed: true, output_unit: :mph}
    refute changeset(attrs(%{input_unit: :raw}), gauge(mph)).valid?
    assert changeset(attrs(%{input_unit: :mps}), gauge(mph)).valid?
  end

  test "an unknown gauge is rejected" do
    cs = changeset(attrs(), nil)
    refute cs.valid?
    assert cs.errors[:gauge_id]
  end

  test "moving a saved binding to another gauge disables it" do
    saved = %GaugeBinding{
      id: 5,
      train_id: 1,
      gauge_id: 1,
      name: "Speed",
      endpoint: "Speed",
      enabled: true
    }

    cs = GaugeBinding.changeset(saved, %{gauge_id: 2}, gauge(@reviewed, 2))
    assert cs.valid?
    assert Ecto.Changeset.get_field(cs, :enabled) == false

    assert Ecto.Changeset.get_field(
             GaugeBinding.changeset(saved, %{name: "Renamed"}, gauge(@reviewed)),
             :enabled
           )
  end
end
