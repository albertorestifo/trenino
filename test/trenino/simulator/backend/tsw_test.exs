defmodule Trenino.Simulator.Backend.TSWTest do
  use Trenino.DataCase, async: true

  alias Trenino.Simulator.Backend.TSW
  alias Trenino.Simulator.Client
  alias Trenino.Train.Identifier

  @client %Client{base_url: "http://localhost:31270", api_key: "test"}

  test "identifies as TSW without optional capabilities" do
    assert TSW.id() == :tsw
    assert TSW.capabilities() == []
  end

  describe "connect/1" do
    test "builds a client from url and api key" do
      assert {:ok, %Client{base_url: "http://localhost:31270", api_key: "key"}} =
               TSW.connect(%{url: "http://localhost:31270", api_key: "key"})
    end

    test "needs both url and api key" do
      assert TSW.connect(%{url: "http://localhost:31270", api_key: nil}) ==
               {:error, :needs_config}
    end
  end

  describe "get/2" do
    test "returns a single value bare" do
      stub(Client, :get, fn @client, "X.Y" -> {:ok, %{"Values" => %{"Value" => 1.5}}} end)
      assert TSW.get(@client, "X.Y") == {:ok, 1.5}
    end

    test "returns several values as a map" do
      stub(Client, :get, fn @client, "X.Y" -> {:ok, %{"Values" => %{"A" => 1, "B" => 2}}} end)
      assert TSW.get(@client, "X.Y") == {:ok, %{"A" => 1, "B" => 2}}
    end

    test "passes errors through" do
      stub(Client, :get, fn @client, "X.Y" -> {:error, {:http_error, 404, %{}}} end)
      assert TSW.get(@client, "X.Y") == {:error, {:http_error, 404, %{}}}
    end
  end

  test "read/2 leaves out paths that fail" do
    stub(Client, :get, fn
      @client, "ok.path" -> {:ok, %{"Values" => %{"Value" => 3}}}
      @client, "bad.path" -> {:error, {:http_error, 404, %{}}}
    end)

    assert TSW.read(@client, ["ok.path", "bad.path"]) == {:ok, %{"ok.path" => 3}}
  end

  describe "set/3" do
    test "returns :ok on success" do
      stub(Client, :set, fn @client, "X.InputValue", 0.5 -> {:ok, %{"Result" => "Success"}} end)
      assert TSW.set(@client, "X.InputValue", 0.5) == :ok
    end

    test "passes errors through" do
      stub(Client, :set, fn @client, _, _ -> {:error, {:request_failed, :timeout}} end)
      assert TSW.set(@client, "X.InputValue", 0.5) == {:error, {:request_failed, :timeout}}
    end
  end

  test "vehicle_id/1 uses the formation identifier" do
    stub(Identifier, :derive_from_formation, fn @client -> {:ok, "RVM_LGV_BR390"} end)
    assert TSW.vehicle_id(@client) == {:ok, "RVM_LGV_BR390"}
  end
end
