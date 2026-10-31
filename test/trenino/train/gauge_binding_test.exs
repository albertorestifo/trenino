defmodule Trenino.Train.GaugeBindingTest do
  use Trenino.DataCase, async: true
  alias Trenino.Hardware.{DialCalibration, StepperAxis}
  alias Trenino.Train.GaugeBinding

  defp attrs(extra \\ %{}),
    do: Map.merge(%{name: "Speed", endpoint: "Speed", stepper_axis_id: 1}, extra)

  defp axis(calibration) do
    %StepperAxis{
      id: 1,
      commissioned: true,
      idle_behavior: :hold,
      dial_calibration: calibration
    }
  end

  defp changeset(attrs, axis), do: GaugeBinding.changeset(%GaugeBinding{train_id: 1}, attrs, axis)

  test "a binding carries no calibration of its own" do
    fields = GaugeBinding.__schema__(:fields)

    for gone <- [:points, :output_unit, :calibration_valid, :calibration_reviewed],
        do: refute(gone in fields)
  end

  test "enabling needs a commissioned hold axis with a valid, reviewed dial" do
    reviewed = %DialCalibration{valid: true, reviewed: true, output_unit: :raw}
    enable = attrs(%{enabled: true})

    assert changeset(enable, axis(reviewed)).valid?
    refute changeset(enable, axis(nil)).valid?
    refute changeset(enable, axis(%{reviewed | reviewed: false})).valid?
    refute changeset(enable, axis(%{reviewed | valid: false})).valid?
    refute changeset(enable, %{axis(reviewed) | commissioned: false}).valid?
    refute changeset(enable, %{axis(reviewed) | idle_behavior: :release}).valid?
    assert changeset(attrs(), axis(nil)).valid?
  end

  test "raw input only fits a raw dial" do
    mph = %DialCalibration{valid: true, reviewed: true, output_unit: :mph}
    refute changeset(attrs(%{input_unit: :raw}), axis(mph)).valid?
    assert changeset(attrs(%{input_unit: :mps}), axis(mph)).valid?
  end

  test "an unknown axis is rejected" do
    refute changeset(attrs(), nil).valid?
  end
end
