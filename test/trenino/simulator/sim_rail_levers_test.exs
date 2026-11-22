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

    test "the cruise lever keeps every position, all springing back to the centre",
         %{controls: controls} do
      control = lever(controls, "Physics_Input_General.speed_ctrl", @stepped)

      assert {:ok, %Analysis{warnings: []} = analysis} = SimRailLevers.analyze(control)
      assert length(analysis.suggested_notches) == 4

      # Positions 0, 1 and 3 spring back to position 2 (notch 2).
      assert Enum.map(analysis.suggested_notches, & &1[:springs_back_to]) == [2, 2, nil, 2]
    end
  end

  describe "Traxx" do
    test "the train brake counts down from 5" do
      controls = controls("traxx_e186-134")
      control = lever(controls, "Physics_Input_General.main_brake", @stepped)

      {:ok, analysis} = SimRailLevers.analyze(control)
      assert gates(analysis) == [5.0, 4.0, 3.0, 2.0, 1.0, 0.0]
    end

    test "spring-back positions are ordinary notches that record where they spring back to" do
      # FINDINGS.md: only 1, 3, 5, 7 hold; 0/2 spring to 1, 4/6 spring to 5.
      # Springing back is the hardware's business; the software maps every position.
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

      assert {:ok, %Analysis{warnings: []} = analysis} = SimRailLevers.analyze(control)
      assert gates(analysis) == Enum.map(0..7, &(&1 / 1))

      assert Enum.map(analysis.suggested_notches, & &1[:springs_back_to]) ==
               [1, nil, 1, nil, 5, nil, 5, nil]
    end

    test "equal values merge only when they spring back to the same place" do
      control = %Control{
        id: "lever",
        kind: :lever,
        path: "A.b",
        positions: [
          %Position{index: 0, value: 0.0, stable: 1},
          %Position{index: 1, value: 0.0, stable: 1},
          %Position{index: 2, value: 0.0, stable: 2},
          %Position{index: 3, value: 1.0, stable: 3}
        ]
      }

      {:ok, analysis} = SimRailLevers.analyze(control)

      # Position 0 springs back, position 1 holds: same value, different
      # behaviour, so two notches. Positions 1 and 2 both hold at 0: one detent.
      assert gates(analysis) == [0.0, 0.0, 1.0]
      assert Enum.map(analysis.suggested_notches, & &1[:springs_back_to]) == [1, nil, nil]
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

  describe "distinct/1 and cab/1" do
    test "a lever whose cabs share a notch table is listed once" do
      levers = "traxx_e186-134" |> controls() |> SimRailLevers.distinct()
      drive = Enum.filter(levers, &(&1.path == "Physics_Input_General.drive_handle"))

      assert length(drive) == 1
    end

    test "a handle's smooth and stepped variants stay apart, named by variant" do
      # Each EU07 cab has its brake handle twice: a smooth and a stepped
      # variant with different notch tables, identical in both cabs.
      levers = "4e_eu07-193" |> controls() |> SimRailLevers.distinct()
      brakes = Enum.filter(levers, &(&1.path == "Physics_Input_General.main_brake"))

      assert length(brakes) == 2
      assert brakes |> Enum.map(&SimRailLevers.variant/1) |> Enum.sort() == ["Smooth", "Stepped"]
    end

    test "variant/1 names a control's interaction style" do
      assert SimRailLevers.variant(%Control{id: "a", kind: :lever, type: @stepped}) == "Stepped"
      assert SimRailLevers.variant(%Control{id: "a", kind: :lever, type: @smooth}) == "Smooth"

      assert SimRailLevers.variant(%Control{id: "a", kind: :lever, type: @notch_based}) ==
               "Smooth"
    end

    test "cab/1 reads every profiled train's cab names" do
      for {profile, path} <- [
            {"en57_en57-047", "Physics_Input_EN57.maincontroller_a"},
            {"pendolino_ed250-018_variant", "Physics_Input_General.drive_handle"},
            {"traxx_e186-134", "Physics_Input_General.drive_handle"}
          ] do
        cabs = profile |> controls() |> SimRailLevers.levers() |> Enum.filter(&(&1.path == path))

        assert cabs |> Enum.map(&SimRailLevers.cab/1) |> Enum.all?(&(&1 in ["Cab A", "Cab B"])),
               "#{profile}: #{inspect(Enum.map(cabs, & &1.id))}"
      end
    end

    test "cab/1 is nil when the control is outside a cab" do
      assert SimRailLevers.cab(%Control{id: "outside/handbrake/lever", kind: :lever}) == nil
    end
  end

  test "saved notches keep where they spring back to" do
    {:ok, train} =
      TrainContext.create_train(%{
        name: "Traxx",
        simulator: :simrail,
        identifiers: [%{identifier: "traxx/e186"}]
      })

    {:ok, element} = TrainContext.create_element(train.id, %{name: "Power", type: :lever})

    # The saved Traxx profile predates the bridge reporting `stable`, so the
    # set-point controller is built here: 0/2 spring to 1, 4/6 spring to 5.
    stable = %{0 => 1, 2 => 1, 4 => 5, 6 => 5}

    control = %Control{
      id: "drive_handle",
      kind: :lever,
      path: "Physics_Input_General.drive_handle",
      positions:
        for(i <- 0..7, do: %Position{index: i, value: i / 1, stable: Map.get(stable, i, i)})
    }

    {:ok, analysis} = SimRailLevers.analyze(control)

    {:ok, config} =
      TrainContext.create_lever_config_with_analysis(
        element.id,
        SimRailLevers.endpoints(control.path),
        analysis
      )

    springs =
      config
      |> Trenino.Repo.preload(:notches, force: true)
      |> Map.fetch!(:notches)
      |> Enum.sort_by(& &1.index)
      |> Enum.map(& &1.springs_back_to)

    assert springs == [1, nil, 1, nil, 5, nil, 5, nil]
  end
end
