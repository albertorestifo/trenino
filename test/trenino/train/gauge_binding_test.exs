defmodule Trenino.Train.GaugeBindingTest do
  use Trenino.DataCase, async: true
  alias Trenino.Hardware.StepperAxis
  alias Trenino.Train.GaugeBinding
  defp attrs(points), do: %{name: "Speed", endpoint: "Speed", stepper_axis_id: 1, points: points}

  test "calibration requires sorted distinct values and monotonic bounded positions" do
    axis = %StepperAxis{id: 1}

    for points <- [
          [],
          [%{value: 0, position: 0}],
          [%{value: 0, position: 0}, %{value: 0.001, position: 100}],
          [%{value: 0, position: 0}, %{value: 10, position: 800}]
        ] do
      refute GaugeBinding.changeset(%GaugeBinding{train_id: 1}, attrs(points), axis).valid?
    end

    assert GaugeBinding.changeset(
             %GaugeBinding{train_id: 1},
             attrs([%{value: 0, position: 720}, %{value: 100, position: 0}]),
             axis
           ).valid?

    refute GaugeBinding.changeset(
             %GaugeBinding{train_id: 1},
             Map.put(
               attrs([%{value: 0, position: 0}, %{value: 100, position: 720}]),
               :enabled,
               true
             ),
             axis
           ).valid?
  end
end
