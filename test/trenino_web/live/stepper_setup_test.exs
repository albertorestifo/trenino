defmodule TreninoWeb.StepperSetupTest do
  use TreninoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias Trenino.Hardware

  test "axis setup is editable and saving never commands hardware", %{conn: conn} do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
    assert has_element?(view, "#stepper-axes")
    view |> element("#stepper-add") |> render_click()
    assert has_element?(view, "#stepper-axis-form")

    view
    |> form("#stepper-axis-form", stepper_axis: %{name: "Speed", shield_address: "0x60"})
    |> render_submit()

    assert [%{name: "Speed", commissioned: false, startup_reference: :manual}] =
             Hardware.list_stepper_axes(device.id)

    assert has_element?(view, "#stepper-axes", "Speed")
    assert has_element?(view, "#stepper-axes", "Disconnected")
  end
end
