defmodule TreninoWeb.StepperSetupTest do
  use TreninoWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  alias Trenino.Hardware

  test "adding a gauge asks only for a name and port, saves defaults and opens the setup", %{
    conn: conn
  } do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
    assert has_element?(view, "#stepper-axes")
    view |> element("#stepper-add") |> render_click()
    assert has_element?(view, "#stepper-axis-form")
    refute has_element?(view, "#stepper-axis-form [name='stepper_axis[idle_behavior]']")
    refute has_element?(view, "#stepper-axis-form [name='stepper_axis[watchdog_ms]']")
    refute has_element?(view, "#stepper-axis-form [name='stepper_axis[shield_address]']")

    view
    |> form("#stepper-axis-form", stepper_axis: %{name: "Speed", motor_port: "2"})
    |> render_submit()

    assert [
             %{
               name: "Speed",
               motor_port: 2,
               axis_index: 1,
               mode: :x27_six_state,
               idle_behavior: :hold,
               commissioned: false,
               startup_reference: :manual
             } = axis
           ] = Hardware.list_stepper_axes(device.id)

    # Saving never moves anything; it opens the guided setup for the new gauge.
    assert has_element?(view, "#gauge-wizard-#{axis.id}")
    assert has_element?(view, "#stepper-status-#{axis.id}", "Offline")
  end

  test "a port in use cannot be picked and a full shield cannot take another gauge", %{
    conn: conn
  } do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, _} = Hardware.create_stepper_axis(device.id, %{"name" => "Speed"})
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")

    view |> element("#stepper-add") |> render_click()
    assert has_element?(view, "#stepper-axis-form option[value='1'][disabled]", "in use")
    assert has_element?(view, "#stepper-axis-form option[value='2'][selected]")

    view |> form("#stepper-axis-form", stepper_axis: %{name: "Brake"}) |> render_submit()
    assert length(Hardware.list_stepper_axes(device.id)) == 2
    assert has_element?(view, "#stepper-add[disabled][aria-describedby='stepper-add-reason']")
    assert has_element?(view, "#stepper-add-reason", "Both motor ports are in use")
  end

  test "the shield address is one line until the operator asks to change it", %{conn: conn} do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, _} = Hardware.create_stepper_axis(device.id, %{"name" => "Speed"})
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")

    assert has_element?(view, "#stepper-shield", "0x60")
    refute has_element?(view, "#stepper-recommission-address")

    view |> element("#stepper-change-address") |> render_click()

    assert has_element?(
             view,
             "#stepper-recommission-address",
             "Unplug any display at address 0x70"
           )

    refute has_element?(view, "#stepper-recommission-address input[type=checkbox]")
    assert has_element?(view, "#stepper-recommission-address button[type=submit][disabled]")
  end

  test "renaming a set-up gauge keeps it set up, even on a legacy index/port pairing", %{
    conn: conn
  } do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})

    {:ok, axis} =
      Hardware.create_stepper_axis(device.id, %{name: "Speed", axis_index: 0, motor_port: 2})

    {:ok, _} = Hardware.commission_stepper_axis(axis)
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")

    view |> element("#stepper-edit-#{axis.id}") |> render_click()
    view |> form("#stepper-axis-form", stepper_axis: %{name: "Speedo"}) |> render_submit()

    assert [%{name: "Speedo", axis_index: 0, motor_port: 2, commissioned: true}] =
             Hardware.list_stepper_axes(device.id)
  end

  test "an address outside the shield range is refused with a clear message", %{conn: conn} do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, _} = Hardware.create_stepper_axis(device.id, %{"name" => "Speed"})
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
    view |> element("#stepper-change-address") |> render_click()

    view
    |> form("#stepper-recommission-address", %{address: "0x78"})
    |> render_submit()

    assert has_element?(view, "#stepper-axes [role=alert]", "0x60 to 0x77")
  end

  test "0x70 display with a gauge still to set up shows a non-blocking warning", %{conn: conn} do
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

      # Never confirmed on a device: unknown, so the banner must not claim a difference.
      assert has_element?(view, "#apply-needed-banner", "Not confirmed on the device")
      refute has_element?(view, "#apply-needed-banner", "Saved changes are not on the device")
      assert has_element?(view, "#apply-unavailable-reason", "no device is connected")

      fingerprint =
        Hardware.config_fingerprint([], [], [], Hardware.list_stepper_axes(device.id))

      {:ok, applied} = Hardware.confirm_configuration(device.id, device.config_id, fingerprint)
      send(view.pid, {:configuration_applied, "tty", applied, device.config_id})
      refute has_element?(view, "#apply-needed-banner")

      [axis] = Hardware.list_stepper_axes(device.id)
      {:ok, _} = Hardware.update_stepper_axis(axis, %{reverse: true})
      send(view.pid, {:stepper_axis_saved, axis})
      assert has_element?(view, "#apply-needed-banner", "Apply needed")
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
