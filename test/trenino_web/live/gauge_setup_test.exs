defmodule TreninoWeb.GaugeSetupTest do
  use TreninoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias Trenino.{Hardware, Train}

  test "offline gauge starter has editable endpoint and calibration and saves disabled", %{
    conn: conn
  } do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, _axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed"})

    {:ok, train} =
      Train.create_train(%{name: "Class 323", identifiers: [%{identifier: "Class323"}]})

    {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")
    assert has_element?(view, "#gauge-bindings")
    view |> element("#gauge-add") |> render_click()
    view |> element("#gauge-class323") |> render_click()
    assert has_element?(view, "#gauge-calibration-points")
    assert has_element?(view, "button[phx-click=claim][disabled]")

    view
    |> form("#gauge-binding-form",
      gauge_binding: %{name: "Speedometer", endpoint: "VerifiedSpeed"}
    )
    |> render_submit()

    assert [
             %{
               id: binding_id,
               enabled: false,
               calibration_reviewed: false,
               endpoint: "VerifiedSpeed",
               input_unit: :mps,
               output_unit: :mph
             }
           ] =
             Train.list_gauge_bindings(train.id)

    assert render(view) =~ "Unverified points"

    send(
      view.pid,
      {:gauge_binding_updated, binding_id,
       %{
         sample: 44.704,
         value: 100.0,
         target: 720,
         stale: true,
         failure: {:error, :needs_reference}
       }}
    )

    html = render(view)
    assert html =~ "Estimated target: 720 transitions"
    assert html =~ "Simulator data is stale"
    assert html =~ "Reference the axis before moving it."
    refute html =~ ":needs_reference"
  end
end
