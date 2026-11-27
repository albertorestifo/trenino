defmodule Trenino.MCP.Tools.SimulatorToolsTest do
  use Trenino.DataCase, async: true

  defmodule SimRailStub do
    @moduledoc false
    def id, do: :simrail
  end

  alias Trenino.MCP.Tools.SimulatorTools
  alias Trenino.MCP.Tools.SimulatorToolsTest.SimRailStub
  alias Trenino.SimRailFixtures
  alias Trenino.Simulator
  alias Trenino.Simulator.Backend.SimRail
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.Connection
  alias Trenino.Simulator.ConnectionState

  defp stub_connected_simulator do
    client = Client.new("http://localhost:1234", "test-key")

    stub(Connection, :get_status, fn ->
      %ConnectionState{status: :connected, backend: Simulator.Backend.TSW, client: client}
    end)

    client
  end

  defp stub_disconnected_simulator do
    stub(Connection, :get_status, fn ->
      %ConnectionState{status: :disconnected, client: nil}
    end)
  end

  describe "list_simulator_endpoints" do
    test "returns error when simulator not connected" do
      stub_disconnected_simulator()

      assert {:error, message} = SimulatorTools.execute("list_simulator_endpoints", %{})
      assert message =~ "Simulator not connected"
    end

    test "lists endpoints at root" do
      client = stub_connected_simulator()

      expect(Client, :list, fn ^client, nil ->
        {:ok, %{"children" => [%{"name" => "CurrentDrivableActor"}]}}
      end)

      assert {:ok, data} = SimulatorTools.execute("list_simulator_endpoints", %{})
      assert data["children"]
    end

    test "lists endpoints at a path" do
      client = stub_connected_simulator()

      expect(Client, :list, fn ^client, "CurrentDrivableActor" ->
        {:ok, %{"children" => [%{"name" => "MasterController"}]}}
      end)

      assert {:ok, _data} =
               SimulatorTools.execute("list_simulator_endpoints", %{
                 "path" => "CurrentDrivableActor"
               })
    end

    test "browses SimRail groups and fields" do
      {:ok, handle} = SimRail.connect(%{url: "http://127.0.0.1:31275", api_key: nil})
      schema = SimRailFixtures.schema("4e_eu07-193")

      stub(Connection, :get_status, fn ->
        %ConnectionState{status: :connected, backend: SimRail, client: handle}
      end)

      stub(Req, :get, fn
        _req, [url: "/api/v1/vehicle"] ->
          {:ok, Req.Response.new(status: 200, body: schema)}

        _req, [url: "/api/v1/values", params: [paths: "Physics_Output_EU07.*"]] ->
          {:ok, Req.Response.new(status: 200, body: %{"Physics_Output_EU07.velocity" => 12.5})}
      end)

      assert {:ok, %{"Nodes" => nodes}} = SimulatorTools.execute("list_simulator_endpoints", %{})
      assert %{"Name" => "Physics_Output_EU07"} in nodes

      assert {:ok, %{"Endpoints" => endpoints}} =
               SimulatorTools.execute("list_simulator_endpoints", %{
                 "path" => "Physics_Output_EU07"
               })

      assert %{"Name" => "velocity", "Value" => 12.5, "Writable" => false} in endpoints
    end

    test "returns error for simulators that can't be browsed" do
      stub(Connection, :get_status, fn ->
        %ConnectionState{status: :connected, backend: SimRailStub, client: :handle}
      end)

      assert {:error, message} = SimulatorTools.execute("list_simulator_endpoints", %{})
      assert message =~ "not available for simrail"
    end

    test "returns error on simulator failure" do
      client = stub_connected_simulator()

      expect(Client, :list, fn ^client, nil ->
        {:error, :timeout}
      end)

      assert {:error, message} = SimulatorTools.execute("list_simulator_endpoints", %{})
      assert message =~ "Simulator error"
    end
  end

  describe "get_simulator_value" do
    test "returns error when simulator not connected" do
      stub_disconnected_simulator()

      assert {:error, message} =
               SimulatorTools.execute("get_simulator_value", %{"path" => "Test.Value"})

      assert message =~ "Simulator not connected"
    end

    test "gets a value through the simulator facade" do
      expect(Simulator, :get, fn "Speed.Value" -> {:ok, 55.0} end)

      assert {:ok, %{"path" => "Speed.Value", "value" => 55.0}} =
               SimulatorTools.execute("get_simulator_value", %{"path" => "Speed.Value"})
    end

    test "unwraps a TSW response" do
      client = stub_connected_simulator()

      expect(Client, :get, fn ^client, "Speed.Value" ->
        {:ok, %{"Values" => %{"Value" => 55.0}}}
      end)

      assert {:ok, %{"value" => 55.0}} =
               SimulatorTools.execute("get_simulator_value", %{"path" => "Speed.Value"})
    end

    test "returns error on simulator failure" do
      expect(Simulator, :get, fn "Speed.Value" -> {:error, :timeout} end)

      assert {:error, message} =
               SimulatorTools.execute("get_simulator_value", %{"path" => "Speed.Value"})

      assert message =~ "Simulator error"
    end
  end

  describe "set_simulator_value" do
    test "returns error when simulator not connected" do
      stub_disconnected_simulator()

      assert {:error, message} =
               SimulatorTools.execute("set_simulator_value", %{
                 "path" => "Test.Value",
                 "value" => 1.0
               })

      assert message =~ "Simulator not connected"
    end

    test "sets a TSW value" do
      client = stub_connected_simulator()

      expect(Client, :set, fn ^client, "Horn.InputValue", 1.0 ->
        {:ok, %{"ok" => true}}
      end)

      assert {:ok, %{"path" => "Horn.InputValue", "value" => 1.0}} =
               SimulatorTools.execute("set_simulator_value", %{
                 "path" => "Horn.InputValue",
                 "value" => 1.0
               })
    end

    test "writes SimRail paths as given" do
      expect(Simulator, :set, fn "Physics_Input_EN57.maincontroller_a", 3 -> :ok end)

      assert {:ok, _} =
               SimulatorTools.execute("set_simulator_value", %{
                 "path" => "Physics_Input_EN57.maincontroller_a",
                 "value" => 3
               })
    end
  end
end
