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

  test "quick setup fills X27 defaults and flip direction explains next steps", %{conn: conn} do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
    view |> element("#stepper-preset-x27") |> render_click()
    assert render(view) =~ "X27.168 gauge motor"
    view |> form("#stepper-axis-form") |> render_submit()
    assert [%{reverse: false, motor_port: 1} = axis] = Hardware.list_stepper_axes(device.id)

    html = view |> element("button[phx-click=flip_direction]") |> render_click()
    assert html =~ "Apply to Device"
    assert html =~ "Assign reference"
    assert [%{reverse: true}] = Hardware.list_stepper_axes(device.id)
    refute Hardware.allcall_conflict_possible?(axis.device_id)
    refute html =~ "stepper-allcall-warning"
  end

  test "0x70 display with a stepper axis shows a non-blocking warning, no confirmation", %{
    conn: conn
  } do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, _} = Hardware.create_stepper_axis(device.id, %{"name" => "Speed"})

    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
    refute has_element?(view, "#stepper-allcall-warning")

    {:ok, _} =
      Hardware.create_i2c_module(device.id, %{
        name: "D",
        module_chip: :ht16k33,
        i2c_address: 0x70,
        params: %{
          brightness: 8,
          num_digits: 4,
          display_type: :fourteen_segment,
          has_dot: false,
          align_right: true,
          min_value: 0.0,
          max_value: 9999.0
        }
      })

    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
    assert has_element?(view, "#stepper-allcall-warning", "unplug the 0x70 display")
    assert has_element?(view, "#stepper-allcall-warning", "apply with the shield alone")
    refute has_element?(view, "button[phx-click=ack_registration]")
  end

  describe "apply state" do
    test "banner appears after saving a stepper axis until the device confirms it", %{conn: conn} do
      {:ok, device} = Hardware.create_device(%{name: "Panel"})
      {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
      refute has_element?(view, "#apply-needed-banner")
      assert has_element?(view, "#apply-unavailable-reason", "add at least one")

      view |> element("#stepper-add") |> render_click()
      view |> form("#stepper-axis-form", stepper_axis: %{name: "Speed"}) |> render_submit()

      assert has_element?(view, "#apply-needed-banner", "Apply needed")
      assert has_element?(view, "#apply-unavailable-reason", "no device is connected")

      fingerprint =
        Hardware.config_fingerprint([], [], [], Hardware.list_stepper_axes(device.id))

      {:ok, applied} = Hardware.confirm_configuration(device.id, device.config_id, fingerprint)
      send(view.pid, {:configuration_applied, "tty", applied, device.config_id})
      refute has_element?(view, "#apply-needed-banner")

      view |> element("button[phx-click=flip_direction]") |> render_click()
      assert has_element?(view, "#apply-needed-banner")
    end

    test "fingerprint ignores names", %{conn: _} do
      {:ok, device} = Hardware.create_device(%{name: "Panel"})
      {:ok, axis} = Hardware.create_stepper_axis(device.id, %{"name" => "A"})
      before = Hardware.config_fingerprint([], [], [], [axis])
      {:ok, renamed} = Hardware.update_stepper_axis(axis, %{"name" => "B"})
      assert before == Hardware.config_fingerprint([], [], [], [renamed])
      {:ok, flipped} = Hardware.update_stepper_axis(renamed, %{"reverse" => true})
      refute before == Hardware.config_fingerprint([], [], [], [flipped])
    end
  end
end
