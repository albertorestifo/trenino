defmodule Trenino.Train.LeverRecalibrationTest do
  @moduledoc "Recalibrating a lever keeps the user's notch mapping only when it still fits."
  use Trenino.DataCase, async: true

  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.LeverSetup

  @path "CurrentDrivableActor/Reverser"

  setup do
    {:ok, train} =
      TrainContext.create_train(%{name: "Recal", identifiers: [%{identifier: "recal_test"}]})

    {:ok, element} = TrainContext.create_element(train.id, %{name: "Reverser", type: :lever})

    {:ok, config} =
      TrainContext.create_lever_config_with_analysis(
        element.id,
        LeverSetup.endpoints_for(@path),
        analysis([{:gate, -1.0, 0.0}, {:gate, 0.0, 0.5}, {:gate, 1.0, 1.0}])
      )

    updates =
      config.notches
      |> Enum.sort_by(& &1.index)
      |> Enum.map(&%{id: &1.id, input_min: &1.index * 0.3, input_max: &1.index * 0.3 + 0.2})

    {:ok, config} = TrainContext.update_notch_input_ranges(config.id, updates)

    %{config: config}
  end

  defp analysis(notches) do
    %{
      lever_type: :discrete,
      suggested_notches:
        notches
        |> Enum.with_index()
        |> Enum.map(fn {{type, value, sim}, index} ->
          %{type: type, index: index, value: value, input_min: sim, input_max: sim}
        end)
    }
  end

  defp hardware(config) do
    config.notches |> Enum.sort_by(& &1.index) |> Enum.map(&{&1.input_min, &1.input_max})
  end

  test "same control and layout: every notch keeps its hardware range", %{config: config} do
    {:ok, updated} =
      TrainContext.update_lever_config_with_analysis(
        config,
        LeverSetup.endpoints_for(@path),
        analysis([{:gate, -1.0, 0.0}, {:gate, 0.0, 0.48}, {:gate, 1.0, 1.0}])
      )

    assert hardware(updated) == [{0.0, 0.2}, {0.3, 0.5}, {0.6, 0.8}]

    assert Enum.map(updated.notches |> Enum.sort_by(& &1.index), & &1.sim_input_min) == [
             0.0,
             0.48,
             1.0
           ]
  end

  test "a different layout needs mapping again", %{config: config} do
    {:ok, updated} =
      TrainContext.update_lever_config_with_analysis(
        config,
        LeverSetup.endpoints_for(@path),
        analysis([{:gate, -1.0, 0.0}, {:gate, 1.0, 1.0}])
      )

    assert hardware(updated) == [{nil, nil}, {nil, nil}]
  end

  test "a different simulator control needs mapping again", %{config: config} do
    {:ok, updated} =
      TrainContext.update_lever_config_with_analysis(
        config,
        LeverSetup.endpoints_for("CurrentDrivableActor/Reverser_B"),
        analysis([{:gate, -1.0, 0.0}, {:gate, 0.0, 0.5}, {:gate, 1.0, 1.0}])
      )

    assert hardware(updated) == [{nil, nil}, {nil, nil}, {nil, nil}]
  end
end
