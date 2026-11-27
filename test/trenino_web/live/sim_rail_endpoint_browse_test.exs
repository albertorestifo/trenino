defmodule TreninoWeb.SimRailEndpointBrowseTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Trenino.Hardware
  alias Trenino.SimRailFixtures
  alias Trenino.Simulator
  alias Trenino.Simulator.Backend.SimRail
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train, as: TrainContext

  setup :set_mimic_global

  @profile "4e_eu07-193"

  setup do
    {:ok, handle} = SimRail.connect(%{url: "http://127.0.0.1:31275", api_key: nil})
    schema = SimRailFixtures.schema(@profile)
    values = SimRailFixtures.values(@profile)

    stub(Simulator, :get_status, fn ->
      %ConnectionState{status: :connected, backend: SimRail, client: handle}
    end)

    stub(Req, :get, fn
      _req, [url: "/api/v1/vehicle"] ->
        {:ok, Req.Response.new(status: 200, body: schema)}

      _req, [url: "/api/v1/values", params: [paths: pattern]] ->
        prefix = String.trim_trailing(pattern, "*")
        body = Map.filter(values, fn {path, _} -> String.starts_with?(path, prefix) end)
        {:ok, Req.Response.new(status: 200, body: body)}
    end)

    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, _output} = Hardware.create_output(device.id, %{pin: 7, name: "Brake lamp"})

    {:ok, train} =
      TrainContext.create_train(%{name: "EU07", identifiers: [%{identifier: "4e/eu07-193"}]})

    %{train: train}
  end

  test "the LED output wizard browses SimRail groups and selects a Group.field path", %{
    conn: conn,
    train: train
  } do
    {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")
    view |> element("#add-output-binding") |> render_click()

    group = "button[phx-click='navigate'][phx-value-node='Physics_Output_EU07']"
    assert has_element?(view, group)

    view |> element(group) |> render_click()

    # Fields list with their current values (rounded for display).
    assert has_element?(view, "button[phx-value-node='brakecyl1_pressure']", "4.14")

    view
    |> element("button[phx-click='select'][phx-value-path='Physics_Output_EU07.velocity']")
    |> render_click()

    assert render(view) =~ "Select output"
  end
end
