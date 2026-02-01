defmodule Trenino.MCP.Tools.SimulatorToolsTest do
  use Trenino.DataCase, async: false
  use Mimic

  alias Trenino.MCP.Tools.SimulatorTools
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.Connection
  alias Trenino.Simulator.ConnectionState

  defp stub_connected_simulator do
    client = Client.new("http://localhost:1234", "test-key")

    stub(Connection, :get_status, fn ->
      %ConnectionState{status: :connected, client: client}
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

    test "gets a value" do
      client = stub_connected_simulator()

      expect(Client, :get, fn ^client, "Speed.Value" ->
        {:ok, %{"value" => 55.0}}
      end)

      assert {:ok, %{"value" => 55.0}} =
               SimulatorTools.execute("get_simulator_value", %{"path" => "Speed.Value"})
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

    test "sets a value" do
      client = stub_connected_simulator()

      expect(Client, :set, fn ^client, "Horn.InputValue", 1.0 ->
        {:ok, %{"ok" => true}}
      end)

      assert {:ok, _} =
               SimulatorTools.execute("set_simulator_value", %{
                 "path" => "Horn.InputValue",
                 "value" => 1.0
               })
    end
  end
end
