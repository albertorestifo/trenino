defmodule Trenino.Simulator.SimRailLeversTest do
  use Trenino.DataCase, async: true

  import Trenino.SimRailProfileFixtures

  alias Trenino.Simulator.Control
  alias Trenino.Simulator.Control.Position
  alias Trenino.Simulator.SimRailLevers
  alias Trenino.Simulator.SimRailLevers.Analysis
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.Notch

  @stepped "PhysicsInteractionLeverStepped"
  @smooth "PhysicsInteractionLeverSmooth"
  @notch_based "PhysicsInteractionLeverSmoothNotchBased"

  defp gates(%Analysis{suggested_notches: notches}) do
    Enum.map(notches, fn %{type: :gate, value: value} -> value end)
  end

  describe "EU07" do
    setup do: %{controls: controls("4e_eu07-193")}

    test "the 44-position resistor controller is 44 gates", %{controls: controls} do
      control = lever(controls, "Physics_Input_General.drive_handle", @stepped)

      assert {:ok, %Analysis{lever_type: :discrete, warnings: []} = analysis} =
               SimRailLevers.analyze(control)

      assert gates(analysis) == Enum.map(0..43, &(&1 / 1))
      assert Enum.map(analysis.suggested_notches, & &1.index) == Enum.to_list(0..43)
    end

    test "the notch-based FV4a brake valve snaps to its notch values", %{controls: controls} do
      control = lever(controls, "Physics_Input_General.main_brake", @notch_based)

      assert {:ok, %Analysis{lever_type: :discrete} = analysis} = SimRailLevers.analyze(control)
      assert gates(analysis) == [8.0, 7.0, 6.0, 3.0, 2.0, 1.0, 0.0]
    end

    test "the smooth independent brake is two linear bands", %{controls: controls} do
      control = lever(controls, "Physics_Input_General.local_brake", @smooth)

      assert {:ok, %Analysis{lever_type: :continuous, suggested_notches: notches}} =
               SimRailLevers.analyze(control)

      assert [
               %{type: :linear, index: 0, min_value: 0.5, max_value: 1.0, input_min: 0.5},
               %{type: :linear, index: 1, min_value: +0.0, max_value: 0.5, input_max: 0.5}
             ] = notches
    end

    test "direction positions are named from the game's labels", %{controls: controls} do
      control = lever(controls, "Physics_Input_General.direction_rq", @stepped)

      {:ok, analysis} = SimRailLevers.analyze(control)

      assert Enum.map(analysis.suggested_notches, &{&1.value, &1.description}) == [
               {-1.0, "Drive direction backward"},
               {2.0, "Drive direction neutral"},
               {1.0, "Drive direction forward"}
             ]
    end

    test "find/3 needs a control_id when the brake valve's variants differ", %{
      controls: controls
    } do
      path = "Physics_Input_General.main_brake"
      stepped = lever(controls, path, @stepped)

      assert {:error, {:ambiguous_control, ids}} = SimRailLevers.find(controls, path)
      assert stepped.id in ids
      assert {:ok, ^stepped} = SimRailLevers.find(controls, path, stepped.id)
      assert {:error, {:unknown_control, "nope"}} = SimRailLevers.find(controls, path, "nope")
    end

    test "find/3 takes the first control when every cab has the same notches", %{
      controls: controls
    } do
      path = "Physics_Input_General.drive_handle"
      assert {:ok, %Control{path: ^path}} = SimRailLevers.find(controls, path)
      assert {:error, {:no_lever, "Nope.nope"}} = SimRailLevers.find(controls, "Nope.nope")
    end
  end

  describe "ED250" do
    setup do: %{controls: controls("pendolino_ed250-018_variant")}

    test "the analog throttle is a gate, a 0..1 range and a gate", %{controls: controls} do
      control = lever(controls, "Physics_Input_General.drive_handle", @smooth)

      assert {:ok, %Analysis{lever_type: :hybrid, suggested_notches: notches}} =
               SimRailLevers.analyze(control)

      # The two `0` positions are one detent
      assert [
               %{type: :gate, index: 0, value: +0.0},
               %{type: :linear, index: 1, min_value: +0.0, max_value: 1.0},
               %{type: :gate, index: 2, value: 1.0}
             ] = notches
    end

    test "the smooth brake valve has a service range between its gates", %{controls: controls} do
      control = lever(controls, "Physics_Input_General.main_brake", @smooth)

      {:ok, %Analysis{lever_type: :hybrid, suggested_notches: notches}} =
        SimRailLevers.analyze(control)

      assert Enum.map(notches, &Map.take(&1, [:type, :value, :min_value, :max_value])) == [
               %{type: :gate, value: 7.0},
               %{type: :gate, value: 6.0},
               %{type: :linear, min_value: 3.8, max_value: 6.0},
               %{type: :linear, min_value: 2.67, max_value: 3.8},
               %{type: :gate, value: 2.67},
               %{type: :gate, value: 2.0},
               %{type: :gate, value: 1.0},
               %{type: :gate, value: 0.0}
             ]
    end

    test "the spring-return cruise lever is not a lever", %{controls: controls} do
      control = lever(controls, "Physics_Input_General.speed_ctrl", @stepped)
      assert {:error, :spring_return} = SimRailLevers.analyze(control)
    end
  end

  describe "Traxx" do
    test "the train brake counts down from 5" do
      controls = controls("traxx_e186-134")
      control = lever(controls, "Physics_Input_General.main_brake", @stepped)

      {:ok, analysis} = SimRailLevers.analyze(control)
      assert gates(analysis) == [5.0, 4.0, 3.0, 2.0, 1.0, 0.0]
    end

    test "spring-return positions of the set-point controller are left out and named" do
      # FINDINGS.md: only 1, 3, 5, 7 hold; 0/2 spring to 1, 4/6 spring to 5
      stable = %{0 => 1, 2 => 1, 4 => 5, 6 => 5}

      control = %Control{
        id: "drive_handle",
        kind: :lever,
        path: "Physics_Input_General.drive_handle",
        positions:
          for i <- 0..7 do
            %Position{index: i, value: i / 1, stable: Map.get(stable, i, i)}
          end
      }

      assert {:ok, %Analysis{warnings: [warning]} = analysis} = SimRailLevers.analyze(control)
      assert gates(analysis) == [1.0, 3.0, 5.0, 7.0]
      assert Enum.map(analysis.suggested_notches, & &1.index) == [0, 1, 2, 3]
      assert warning =~ "0 (springs back to 1)"
      assert warning =~ "6 (springs back to 5)"
    end
  end

  test "an analysis saves as a lever config" do
    {:ok, train} =
      TrainContext.create_train(%{
        name: "ED250",
        simulator: :simrail,
        identifiers: [%{identifier: "pendolino/ed250"}]
      })

    {:ok, element} = TrainContext.create_element(train.id, %{name: "Brake", type: :lever})

    control =
      "pendolino_ed250-018_variant"
      |> controls()
      |> lever("Physics_Input_General.main_brake", @smooth)

    {:ok, analysis} = SimRailLevers.analyze(control)
    endpoints = SimRailLevers.endpoints(control.path)

    assert {:ok, config} =
             TrainContext.create_lever_config_with_analysis(element.id, endpoints, analysis)

    assert config.value_endpoint == "Physics_Input_General.main_brake"
    assert config.lever_type == :hybrid
    assert [%Notch{type: :gate, sim_input_min: 7.0, sim_input_max: 7.0} | _] = config.notches

    assert %Notch{type: :linear, sim_input_min: 3.8, sim_input_max: 6.0} =
             Enum.find(config.notches, &(&1.index == 2))
  end
end
