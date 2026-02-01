defmodule TreninoWeb.Api.ScriptControllerTest do
  use TreninoWeb.ConnCase, async: false

  alias Trenino.Train, as: TrainContext

  setup do
    {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})
    %{train: train}
  end

  describe "GET /api/trains/:train_id/scripts" do
    test "returns empty list", %{conn: conn, train: train} do
      conn = get(conn, "/api/trains/#{train.id}/scripts")
      assert %{"scripts" => []} = json_response(conn, 200)
    end

    test "returns scripts", %{conn: conn, train: train} do
      {:ok, _} =
        TrainContext.create_script(train.id, %{
          name: "Script A",
          code: "function on_change(event) end"
        })

      conn = get(conn, "/api/trains/#{train.id}/scripts")
      assert %{"scripts" => [%{"name" => "Script A"}]} = json_response(conn, 200)
    end
  end

  describe "POST /api/trains/:train_id/scripts" do
    test "creates a script", %{conn: conn, train: train} do
      conn =
        post(conn, "/api/trains/#{train.id}/scripts", %{
          name: "New Script",
          code: "function on_change(event) end",
          triggers: ["Endpoint.A"]
        })

      assert %{"script" => %{"name" => "New Script", "triggers" => ["Endpoint.A"]}} =
               json_response(conn, 201)
    end

    test "returns errors for invalid data", %{conn: conn, train: train} do
      conn = post(conn, "/api/trains/#{train.id}/scripts", %{})
      assert %{"errors" => _} = json_response(conn, 422)
    end
  end

  describe "GET /api/scripts/:id" do
    test "returns script", %{conn: conn, train: train} do
      {:ok, script} =
        TrainContext.create_script(train.id, %{
          name: "Test",
          code: "function on_change(event) end"
        })

      conn = get(conn, "/api/scripts/#{script.id}")
      assert %{"script" => %{"name" => "Test"}} = json_response(conn, 200)
    end

    test "returns 404", %{conn: conn} do
      conn = get(conn, "/api/scripts/99999")
      assert json_response(conn, 404)
    end
  end

  describe "PUT /api/scripts/:id" do
    test "updates script", %{conn: conn, train: train} do
      {:ok, script} =
        TrainContext.create_script(train.id, %{
          name: "Old",
          code: "function on_change(event) end"
        })

      conn = put(conn, "/api/scripts/#{script.id}", %{name: "New"})
      assert %{"script" => %{"name" => "New"}} = json_response(conn, 200)
    end
  end

  describe "DELETE /api/scripts/:id" do
    test "deletes script", %{conn: conn, train: train} do
      {:ok, script} =
        TrainContext.create_script(train.id, %{
          name: "ToDelete",
          code: "function on_change(event) end"
        })

      conn = delete(conn, "/api/scripts/#{script.id}")
      assert %{"ok" => true} = json_response(conn, 200)
    end
  end
end
