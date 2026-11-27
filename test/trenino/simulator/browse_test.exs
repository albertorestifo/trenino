defmodule Trenino.Simulator.BrowseTest do
  use Trenino.DataCase, async: true

  alias Trenino.SimRailFixtures
  alias Trenino.Simulator.Backend.SimRail
  alias Trenino.Simulator.Browse
  alias Trenino.Simulator.Client

  @profile "4e_eu07-193"

  defp handle do
    {:ok, handle} = SimRail.connect(%{url: "http://127.0.0.1:31275", api_key: nil})
    handle
  end

  defp ok(body), do: {:ok, Req.Response.new(status: 200, body: body)}

  defp stub_bridge do
    schema = SimRailFixtures.schema(@profile)
    values = SimRailFixtures.values(@profile)
    owner = self()

    stub(Req, :get, fn
      _req, [url: "/api/v1/vehicle"] ->
        ok(schema)

      _req, [url: "/api/v1/values", params: [paths: pattern]] ->
        send(owner, {:values_read, pattern})
        prefix = String.trim_trailing(pattern, "*")
        ok(Map.filter(values, fn {path, _} -> String.starts_with?(path, prefix) end))
    end)
  end

  describe "SimRail" do
    test "the root lists the train's IO groups as nodes" do
      stub_bridge()

      assert {:ok, %{"Nodes" => nodes, "Endpoints" => []}} = Browse.list(handle())
      names = Enum.map(nodes, & &1["Name"])

      assert "Physics_Output_EU07" in names
      assert "Physics_Input_General" in names
      assert {:ok, %{"Nodes" => ^nodes}} = Browse.list(handle(), "")
    end

    test "a group lists its fields with their current values" do
      stub_bridge()

      assert {:ok, %{"Nodes" => [], "Endpoints" => endpoints}} =
               Browse.list(handle(), "Physics_Output_EU07")

      assert_received {:values_read, "Physics_Output_EU07.*"}

      pipe = Enum.find(endpoints, &(&1["Name"] == "brakecyl1_pressure"))
      assert %{"Writable" => false, "Value" => value} = pipe
      assert_in_delta value, 4.14, 0.01
      assert Enum.any?(endpoints, &(&1["Name"] == "velocity"))
    end

    test "input groups are writable" do
      stub_bridge()

      assert {:ok, %{"Endpoints" => [%{"Writable" => true} | _]}} =
               Browse.list(handle(), "Physics_Input_General")
    end

    test "fields are listed even when their values can't be read" do
      schema = SimRailFixtures.schema(@profile)

      stub(Req, :get, fn
        _req, [url: "/api/v1/vehicle"] ->
          ok(schema)

        _req, [url: "/api/v1/values", params: _] ->
          {:error, %Req.TransportError{reason: :econnrefused}}
      end)

      assert {:ok, %{"Endpoints" => [endpoint | _]}} =
               Browse.list(handle(), "Physics_Output_EU07")

      refute Map.has_key?(endpoint, "Value")
    end

    test "an unknown group is an invalid path" do
      stub_bridge()
      assert {:error, :invalid_path} = Browse.list(handle(), "Physics_Output_Nope")
    end

    test "get previews one value" do
      stub(Req, :get, fn _req,
                         [url: "/api/v1/values", params: [paths: "Physics_Output_EU07.velocity"]] ->
        ok(%{"Physics_Output_EU07.velocity" => 42.5})
      end)

      assert {:ok, %{"Value" => 42.5}} = Browse.get(handle(), "Physics_Output_EU07.velocity")
    end
  end

  describe "Train Sim World" do
    test "list and get go to the TSW client" do
      client = Client.new("http://localhost:1234", "key")

      expect(Client, :list, fn ^client, nil -> {:ok, %{"Nodes" => []}} end)
      expect(Client, :get, fn ^client, "A.B" -> {:ok, %{"Values" => %{"B" => 1}}} end)

      assert {:ok, %{"Nodes" => []}} = Browse.list(client)
      assert {:ok, %{"Values" => _}} = Browse.get(client, "A.B")
    end
  end

  test "supported?/1" do
    assert Browse.supported?(handle())
    assert Browse.supported?(Client.new("http://localhost:1234", "key"))
    refute Browse.supported?(:other)
  end
end
