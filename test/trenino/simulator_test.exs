defmodule Trenino.SimulatorTest do
  use Trenino.DataCase, async: true

  alias Trenino.Simulator
  alias Trenino.Simulator.Backend.TSW
  alias Trenino.Simulator.{Client, Connection, ConnectionState}

  @client %Client{base_url: "http://localhost:31270", api_key: "test"}

  describe "windows?/0" do
    test "returns a boolean" do
      result = Simulator.windows?()
      assert is_boolean(result)
    end
  end

  describe "when not connected" do
    setup do
      stub(Connection, :get_status, fn -> %ConnectionState{status: :disconnected} end)
      :ok
    end

    test "operations return :not_connected" do
      assert Simulator.connected() == {:error, :not_connected}
      assert Simulator.current() == nil
      refute Simulator.supports?(:push_values)
      assert Simulator.get("A.B") == {:error, :not_connected}
      assert Simulator.read(["A.B"]) == {:error, :not_connected}
      assert Simulator.set("A.B", 1) == {:error, :not_connected}
      assert Simulator.vehicle_id() == {:error, :not_connected}
      assert Simulator.controls() == {:error, :not_connected}
    end
  end

  describe "when connected to TSW" do
    setup do
      stub(Connection, :get_status, fn ->
        %ConnectionState{status: :connected, backend: TSW, client: @client}
      end)

      :ok
    end

    test "reports the backend" do
      assert Simulator.connected() == {:ok, TSW, @client}
      assert Simulator.current() == :tsw
      refute Simulator.supports?(:control_catalog)
    end

    test "set/2 dispatches to the backend" do
      test_pid = self()

      stub(Client, :set, fn @client, path, value ->
        send(test_pid, {:set, path, value})
        {:ok, %{"Result" => "Success"}}
      end)

      assert Simulator.set("CurrentDrivableActor/Throttle(Lever).InputValue", 0.5) == :ok
      assert_received {:set, "CurrentDrivableActor/Throttle(Lever).InputValue", 0.5}
    end

    test "get/1 unwraps a single TSW value" do
      stub(Client, :get, fn @client, _path -> {:ok, %{"Values" => %{"Speed" => 12.5}}} end)

      assert Simulator.get("CurrentDrivableActor.Function.HUD_GetSpeed") == {:ok, 12.5}
    end

    test "controls/0 is not supported by TSW" do
      assert Simulator.controls() == {:error, :not_supported}
    end
  end
end
