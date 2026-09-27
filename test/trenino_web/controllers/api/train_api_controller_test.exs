defmodule TreninoWeb.Api.TrainApiControllerTest do
  use TreninoWeb.ConnCase, async: true

  alias Trenino.Train, as: TrainContext

  setup do
    {:ok, train} =
      TrainContext.create_train(%{
        name: "BR 423",
        description: "EMU",
        identifiers: [
          %{identifier: "RVM_OTHER_DB_BR423"},
          %{identifier: "RVM_FSN_DB_BR423"}
        ]
      })

    %{train: train}
  end

  test "GET /api/trains returns sorted identifier arrays only", %{conn: conn} do
    response = conn |> get(~p"/api/trains") |> json_response(200)
    [train] = response["trains"]

    assert train["identifiers"] == ["RVM_FSN_DB_BR423", "RVM_OTHER_DB_BR423"]
    refute Map.has_key?(train, "identifier")
  end

  test "GET /api/trains/:id returns sorted identifier arrays only", %{conn: conn, train: train} do
    response = conn |> get(~p"/api/trains/#{train.id}") |> json_response(200)
    result = response["train"]

    assert result["identifiers"] == ["RVM_FSN_DB_BR423", "RVM_OTHER_DB_BR423"]
    refute Map.has_key?(result, "identifier")
    assert result["elements"] == []
    assert result["output_bindings"] == []
  end

  test "GET /api/trains/:id returns not found", %{conn: conn} do
    assert %{"error" => "not found"} =
             conn |> get(~p"/api/trains/-1") |> json_response(404)
  end
end
