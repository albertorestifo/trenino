defmodule TreninoWeb.Api.TrainApiController do
  use TreninoWeb, :controller

  alias Trenino.Train, as: TrainContext

  def index(conn, _params) do
    trains = TrainContext.list_trains()

    json(conn, %{
      trains:
        Enum.map(trains, fn t ->
          %{id: t.id, name: t.name, identifier: t.identifier, description: t.description}
        end)
    })
  end

  def show(conn, %{"id" => id}) do
    case TrainContext.get_train(String.to_integer(id), preload: [:elements]) do
      {:ok, train} ->
        json(conn, %{
          train: %{
            id: train.id,
            name: train.name,
            identifier: train.identifier,
            description: train.description,
            elements:
              Enum.map(train.elements, fn e ->
                %{id: e.id, name: e.name, type: e.type}
              end),
            output_bindings:
              TrainContext.list_output_bindings(train.id)
              |> Enum.map(fn b ->
                %{
                  id: b.id,
                  name: b.name,
                  endpoint: b.endpoint,
                  operator: b.operator,
                  output_id: b.output_id
                }
              end)
          }
        })

      {:error, :not_found} ->
        conn |> put_status(404) |> json(%{error: "not found"})
    end
  end
end
