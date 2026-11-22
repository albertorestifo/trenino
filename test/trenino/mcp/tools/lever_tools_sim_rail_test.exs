defmodule Trenino.MCP.Tools.LeverToolsSimRailTest do
  @moduledoc "Lever setup on a simulator with a control catalogue (SimRail profiles)."

  use Trenino.DataCase, async: true

  import Trenino.SimRailProfileFixtures

  alias Trenino.MCP.Tools.LeverTools
  alias Trenino.SimRailProfileFixtures.CatalogBackend
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.Connection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.{LeverConfig, LeverSetup}

  @throttle "Physics_Input_General.drive_handle"
  @brake "Physics_Input_General.main_brake"

  setup do
    # Nothing is swept: any HTTP request is a bug
    stub(Req, :request, fn _req, _opts -> flunk("catalog lever setup made a request") end)
    :ok
  end

  defp connect(profile_name) do
    handle = profile(profile_name)

    stub(Connection, :get_status, fn ->
      %ConnectionState{status: :connected, backend: CatalogBackend, client: handle}
    end)

    handle
  end

  defp lever_element(simulator, identifier, name) do
    {:ok, train} =
      TrainContext.create_train(%{
        name: "#{identifier} #{name}",
        simulator: simulator,
        identifiers: [%{identifier: identifier}]
      })

    {:ok, element} = TrainContext.create_element(train.id, %{name: name, type: :lever})
    element
  end

  defp run(tool, args), do: LeverTools.execute(tool, args)

  defp link(element, path) do
    {:ok, _} = run("set_lever_endpoint", %{"element_id" => element.id, "control_path" => path})
  end

  describe "EU07" do
    setup do
      {_vehicle, controls} = connect("4e_eu07-193")
      %{controls: controls}
    end

    test "lists cab levers with their control_id and notch table" do
      assert {:ok, %{levers: levers}} = run("list_simulator_levers", %{})

      throttle = Enum.find(levers, &(&1.control_path == @throttle))
      assert throttle.control_id =~ "nastawnik"
      assert length(throttle.positions) == 44

      direction = Enum.find(levers, &(&1.control_path == "Physics_Input_General.direction_rq"))
      assert hd(direction.positions).name == "Drive direction backward"
    end

    test "configures the resistor controller from its notch table" do
      element = lever_element(:simrail, "4e/eu07", "Throttle")
      link(element, @throttle)

      assert {:ok, %{lever_type: :discrete, warnings: [], lever: lever, next_step: :bind_input}} =
               run("calibrate_lever", %{"element_id" => element.id})

      assert lever.control_path == @throttle
      assert length(lever.notches) == 44

      {:ok, config} = TrainContext.get_lever_config(element.id)

      assert %LeverConfig{
               value_endpoint: @throttle,
               min_endpoint: @throttle,
               max_endpoint: @throttle,
               notch_count_endpoint: nil,
               calibrated_at: %DateTime{}
             } = config
    end

    test "asks which brake valve when variants share the path", %{controls: controls} do
      element = lever_element(:simrail, "4e/eu07", "Train brake")
      link(element, @brake)

      assert {:error, "Several controls" <> _} =
               run("calibrate_lever", %{"element_id" => element.id})

      stepped = lever(controls, @brake, "PhysicsInteractionLeverStepped")

      assert {:ok, %{control_id: id, lever: %{notches: notches}}} =
               run("calibrate_lever", %{"element_id" => element.id, "control_id" => stepped.id})

      assert id == stepped.id
      assert length(notches) == 11
    end

    test "rejects a path that is not a lever" do
      element = lever_element(:simrail, "4e/eu07", "Throttle")

      assert {:error, "Physics_Input_General.battery_rq is not a lever" <> _} =
               run("set_lever_endpoint", %{
                 "element_id" => element.id,
                 "control_path" => "Physics_Input_General.battery_rq"
               })
    end

    test "refuses a Train Sim World train" do
      element = lever_element(:tsw, "RVM_X", "Throttle")

      {:ok, _} =
        TrainContext.create_lever_config(
          element.id,
          LeverSetup.endpoints_for(@throttle, :simrail)
        )

      assert {:error, "This train is set up for Train Sim World, but SimRail is connected."} =
               run("calibrate_lever", %{"element_id" => element.id})
    end

    test "won't link a Train Sim World train's lever to a SimRail control" do
      element = lever_element(:tsw, "RVM_Y", "Throttle")

      assert {:error, "This train is set up for Train Sim World, but SimRail is connected."} =
               run("set_lever_endpoint", %{
                 "element_id" => element.id,
                 "control_path" => @throttle
               })

      assert {:error, :not_found} = TrainContext.get_lever_config(element.id)
    end
  end

  test "a SimRail train's lever is never swept" do
    element = lever_element(:simrail, "4e/eu07", "Throttle")
    client = Client.new("http://localhost:31270", "key")

    assert {:error, {:wrong_simulator, :simrail, :tsw}} =
             LeverSetup.calibrate(client, element.id, "CurrentDrivableActor/Throttle")
  end

  test "ED250 throttle is a hybrid lever with a 0..1 range" do
    connect("pendolino_ed250-018_variant")
    element = lever_element(:simrail, "pendolino/ed250", "Throttle")
    link(element, @throttle)

    assert {:ok, %{lever_type: :hybrid, lever: %{notches: notches}}} =
             run("calibrate_lever", %{"element_id" => element.id})

    assert Enum.map(notches, &{&1.type, &1.output}) == [
             {:gate, 0.0},
             {:linear, [0.0, 1.0]},
             {:gate, 1.0}
           ]
  end

  test "ED250 cruise lever is a lever, its spring-back positions included" do
    connect("pendolino_ed250-018_variant")
    element = lever_element(:simrail, "pendolino/ed250", "Cruise")
    link(element, "Physics_Input_General.speed_ctrl")

    assert {:ok, _result} = run("calibrate_lever", %{"element_id" => element.id})

    {:ok, config} = Trenino.Train.get_lever_config(element.id)
    notches = config |> Trenino.Repo.preload(:notches) |> Map.fetch!(:notches)

    # Positions 0, 1 and 3 spring back to position 2; all four are notches.
    assert notches |> Enum.sort_by(& &1.index) |> Enum.map(& &1.springs_back_to) ==
             [2, 2, nil, 2]
  end

  test "Traxx train brake via LeverSetup" do
    connect("traxx_e186-134")
    element = lever_element(:simrail, "traxx/e186", "Train brake")

    assert LeverSetup.catalog?()
    assert {:ok, _} = LeverSetup.set_endpoint(element.id, @brake)

    assert {:ok, %{lever_config: config, analysis: analysis}} =
             LeverSetup.configure_from_catalog(element.id, @brake)

    assert analysis.lever_type == :discrete

    assert config.notches |> Enum.sort_by(& &1.index) |> Enum.map(& &1.value) == [
             5.0,
             4.0,
             3.0,
             2.0,
             1.0,
             0.0
           ]
  end
end
