defmodule Trenino.Simulator.Backend.SimRailTest do
  use Trenino.DataCase, async: true

  alias Trenino.SimRailFixtures
  alias Trenino.Simulator.Backend.SimRail
  alias Trenino.Simulator.Control
  alias Trenino.Simulator.Control.Position

  @url "http://127.0.0.1:31275"

  defp handle(api_key \\ nil) do
    {:ok, handle} = SimRail.connect(%{url: @url, api_key: api_key})
    handle
  end

  defp ok(body), do: {:ok, Req.Response.new(status: 200, body: body)}

  defp status(code, body \\ %{"error" => "nope"}),
    do: {:ok, Req.Response.new(status: code, body: body)}

  defp stub_vehicle(profile) do
    schema = SimRailFixtures.schema(profile)
    stub(Req, :get, fn _req, [url: "/api/v1/vehicle"] -> ok(schema) end)
  end

  defp controls_on(controls, path), do: Enum.filter(controls, &(&1.path == path))

  defp values_of(%Control{positions: positions}), do: Enum.map(positions, & &1.value)

  test "identifies as SimRail with push values, a control catalogue and vehicle events" do
    assert SimRail.id() == :simrail
    assert SimRail.capabilities() == [:push_values, :control_catalog, :vehicle_events]
  end

  describe "connect/1" do
    test "builds a handle without a token" do
      assert {:ok, %SimRail{url: @url, api_key: nil} = handle} =
               SimRail.connect(%{url: @url <> "/", api_key: nil})

      assert Req.Request.get_header(handle.req, "authorization") == []
    end

    test "sends the token as a bearer header when set" do
      assert {:ok, %SimRail{api_key: "secret", req: req}} =
               SimRail.connect(%{url: @url, api_key: "secret"})

      assert Req.Request.get_header(req, "authorization") == ["Bearer secret"]
    end

    test "treats a blank token as none" do
      assert {:ok, %SimRail{api_key: nil}} = SimRail.connect(%{url: @url, api_key: ""})
    end

    test "needs a url" do
      assert SimRail.connect(%{api_key: nil}) == {:error, :needs_config}
      assert SimRail.connect(%{url: "", api_key: nil}) == {:error, :needs_config}
    end
  end

  describe "check/1" do
    test "returns the bridge status" do
      status = %{"ok" => true, "api" => "1", "bridge" => "0.2.0", "inTrain" => true}
      expect(Req, :get, fn _req, [url: "/api/v1/status"] -> ok(status) end)

      assert SimRail.check(handle()) == {:ok, status}
    end

    test "reports a rejected token like the TSW client" do
      expect(Req, :get, fn _req, _opts -> status(401) end)
      assert {:error, {:invalid_key, _}} = SimRail.check(handle("wrong"))
    end

    test "reports an unreachable bridge" do
      expect(Req, :get, fn _req, _opts -> {:error, %Req.TransportError{reason: :econnrefused}} end)

      assert {:error, {:request_failed, %Req.TransportError{}}} = SimRail.check(handle())
    end
  end

  describe "get/2 and read/2" do
    test "reads several paths in one request, as floats" do
      expect(Req, :get, fn _req, opts ->
        assert opts[:url] == "/api/v1/values"

        assert opts[:params] == [
                 paths: "Physics_Input_EN57.maincontroller_a,Physics_Output_EN57.velocity"
               ]

        ok(%{"Physics_Input_EN57.maincontroller_a" => 2, "Physics_Output_EN57.velocity" => 41.25})
      end)

      assert SimRail.read(handle(), [
               "Physics_Input_EN57.maincontroller_a",
               "Physics_Output_EN57.velocity"
             ]) ==
               {:ok,
                %{
                  "Physics_Input_EN57.maincontroller_a" => 2.0,
                  "Physics_Output_EN57.velocity" => 41.25
                }}
    end

    test "reading no paths does not ask for every value" do
      reject(Req, :get, 2)
      assert SimRail.read(handle(), []) == {:ok, %{}}
    end

    test "get returns one value" do
      values = SimRailFixtures.values("en57_en57-047")
      path = "Physics_Input_EN57.mainbrake_a"

      expect(Req, :get, fn _req, opts ->
        assert opts[:params] == [paths: path]
        ok(Map.take(values, [path]))
      end)

      assert SimRail.get(handle(), path) == {:ok, values[path] * 1.0}
    end

    test "get reports a path the bridge does not know" do
      expect(Req, :get, fn _req, _opts -> ok(%{}) end)
      assert SimRail.get(handle(), "Nope.nope") == {:error, :invalid_path}
    end

    test "reports when the player is not in a train" do
      expect(Req, :get, fn _req, _opts -> status(409) end)
      assert SimRail.read(handle(), ["A.b"]) == {:error, :not_in_train}
    end
  end

  describe "set/3" do
    test "puts the value to the path" do
      expect(Req, :put, fn _req, opts ->
        assert opts[:url] == "/api/v1/values/Physics_Input_General.drive_handle"
        assert opts[:json] == %{value: 3}

        ok(%{"path" => "Physics_Input_General.drive_handle", "value" => 3, "syncedControls" => 1})
      end)

      assert SimRail.set(handle(), "Physics_Input_General.drive_handle", 3) == :ok
    end

    test "writes booleans as 1/0" do
      expect(Req, :put, fn _req, opts ->
        assert opts[:json] == %{value: 1}
        ok(%{})
      end)

      assert SimRail.set(handle(), "Physics_Input_General.battery_rq", true) == :ok
    end

    test "rejects non-numeric values without a request" do
      reject(Req, :put, 2)
      assert {:error, {:invalid_value, "x"}} = SimRail.set(handle(), "A.b", "x")
    end

    test "reports an unknown path" do
      expect(Req, :put, fn _req, _opts -> status(404) end)
      assert SimRail.set(handle(), "A.b", 1) == {:error, :invalid_path}
    end
  end

  describe "vehicle_id/1" do
    test "is the schema's vehicle name" do
      stub_vehicle("4e_eu07-193")
      assert SimRail.vehicle_id(handle()) == {:ok, "4e/eu07-193"}
    end

    test "is :not_in_train on 409" do
      expect(Req, :get, fn _req, [url: "/api/v1/vehicle"] -> status(409) end)
      assert SimRail.vehicle_id(handle()) == {:error, :not_in_train}
    end
  end

  describe "controls/1 for the EN57" do
    setup do
      stub_vehicle("en57_en57-047")
      {:ok, controls} = SimRail.controls(handle())
      %{controls: controls}
    end

    test "leaves out unbound decor", %{controls: controls} do
      assert length(controls) == 113
      assert Enum.all?(controls, & &1.path)
      refute Enum.any?(controls, &(&1.kind == :other and &1.type =~ "Dummy"))
    end

    test "maps the stepped throttle", %{controls: controls} do
      assert [%Control{kind: :lever, type: "PhysicsInteractionLeverStepped"} = throttle] =
               controls_on(controls, "Physics_Input_EN57.maincontroller_a")

      assert values_of(throttle) == [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]

      assert %Position{index: 0, label: nil, stable: nil, smooth: false, lower: nil} =
               hd(throttle.positions)

      refute Enum.any?(throttle.positions, &Control.momentary?/1)
    end

    test "keeps non-uniform and reversed notch values", %{controls: controls} do
      assert [brake] = controls_on(controls, "Physics_Input_EN57.mainbrake_a")
      assert values_of(brake) == [0.0, 1.0, 2.0, 4.0, 5.0, 5.6, 6.0, 7.0]

      assert [direction] = controls_on(controls, "Physics_Input_EN57.directioncontroller_a")
      assert values_of(direction) == [4.0, 3.0, 2.0, 1.0, 0.0]
    end
  end

  describe "controls/1 for the Traxx" do
    setup do
      stub_vehicle("traxx_e186-134")
      {:ok, controls} = SimRail.controls(handle())
      %{controls: controls}
    end

    test "marks spring-back positions of the traction lever", %{controls: controls} do
      assert [drive | _] = controls_on(controls, "Physics_Input_General.drive_handle")
      assert Enum.map(drive.positions, & &1.stable) == [1, 1, 1, 3, 5, 5, 5, 7]

      assert drive.positions |> Enum.filter(&Control.momentary?/1) |> Enum.map(& &1.index) ==
               [0, 2, 4, 6]
    end

    test "maps the three direction push buttons on one path", %{controls: controls} do
      buttons = controls_on(controls, "Physics_Input_General.direction_rq")

      assert buttons
             |> Enum.map(&{&1.kind, &1.pressed_value, &1.released_value})
             |> Enum.uniq()
             |> Enum.sort() ==
               [{:button, -1.0, 0.0}, {:button, 1.0, 0.0}, {:button, 2.0, 0.0}]

      assert Enum.all?(buttons, &(&1.positions == []))
    end

    test "keeps each cab's notch table for the activation handle", %{controls: controls} do
      tables =
        controls
        |> controls_on("Physics_Input_TRAXX_E186.activation_handle")
        |> Enum.map(&values_of/1)

      assert tables == [[0.0, 1.0, 2.0], [0.0, 1.0, 3.0]]
    end
  end

  describe "controls/1 for the EU07" do
    setup do
      stub_vehicle("4e_eu07-193")
      {:ok, controls} = SimRail.controls(handle())
      %{controls: controls}
    end

    test "keeps different brake valves on the same path", %{controls: controls} do
      brakes = controls_on(controls, "Physics_Input_General.main_brake")

      assert %Control{type: "PhysicsInteractionLeverSmoothNotchBased"} =
               smooth = Enum.find(brakes, &(&1.type =~ "Smooth"))

      assert %Control{type: "PhysicsInteractionLeverStepped"} =
               stepped = Enum.find(brakes, &(&1.type =~ "Stepped"))

      assert values_of(smooth) == [8.0, 7.0, 6.0, 3.0, 2.0, 1.0, 0.0]

      assert %Position{value: 6.0, lower: 6.5, upper: 4.5, smooth: true} =
               Enum.at(smooth.positions, 2)

      assert %Position{value: 8.0, lower: 8.0, upper: 8.0, smooth: false} = hd(smooth.positions)

      assert values_of(stepped) ==
               [8.0, 7.0, 6.0, 5.25, 4.5, 4.0, 3.5, 3.0, 2.0, 1.0, 0.0]

      refute Enum.any?(stepped.positions, &Control.momentary?/1)
    end

    test "maps push buttons and their actions", %{controls: controls} do
      assert [vigilance | _] =
               controls_on(controls, "Physics_Input_General.security_system_button")

      assert %Control{
               kind: :button,
               pressed_value: 1.0,
               released_value: -1.0,
               actions: ["Alerter"]
             } =
               vigilance

      main_switch =
        controls
        |> controls_on("Physics_Input_General.main_switch")
        |> Enum.map(& &1.pressed_value)
        |> Enum.uniq()
        |> Enum.sort()

      assert main_switch == [-1.0, 1.0]
    end

    test "maps a spring-return horn switch", %{controls: controls} do
      assert [horn | _] = controls_on(controls, "Physics_Input_General.horn_signal")
      assert horn.kind == :switch
      assert horn.actions == ["Horn High", "Horn Low"]
      assert Enum.map(horn.positions, &Control.momentary?/1) == [true, false, true]
    end
  end

  test "controls/1 is :not_in_train on 409" do
    expect(Req, :get, fn _req, [url: "/api/v1/vehicle"] -> status(409) end)
    assert SimRail.controls(handle()) == {:error, :not_in_train}
  end
end
