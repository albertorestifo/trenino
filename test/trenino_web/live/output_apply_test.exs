defmodule TreninoWeb.OutputApplyTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Trenino.Hardware
  alias Trenino.Serial.Connection.DeviceConnection

  setup :set_mimic_global

  setup do
    Mimic.stub(Circuits.UART, :enumerate, fn -> %{} end)
    {:ok, device} = Hardware.create_device(%{name: "Lamp panel"})
    %{device: device}
  end

  test "adding an output makes the configuration applicable", %{conn: conn, device: device} do
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
    assert has_element?(view, "#apply-unavailable-reason", "add at least one")
    assert has_element?(view, "#apply-unavailable-reason", "output")
    refute has_element?(view, "#apply-needed-banner")
    refute has_element?(view, "button[phx-click=show_apply_modal]")

    view |> element("#add-output") |> render_click()
    view |> form("#add-output-form", output: %{pin: 13, name: "Brake lamp"}) |> render_submit()

    # Outputs count as parts: the only thing left in the way is a connected device.
    assert has_element?(view, "#apply-unavailable-reason", "no device is connected")
    refute has_element?(view, "#apply-unavailable-reason", "add at least one")
    assert has_element?(view, "#apply-needed-banner", "Not confirmed on the device")

    send(view.pid, {:devices_updated, [connected("/dev/cu.usbmodem1", 987_654)]})
    refute has_element?(view, "#apply-unavailable-reason")
    assert has_element?(view, "button[phx-click=show_apply_modal]", "Apply to device")
  end

  test "output test toggles render once applied and drive the device", %{
    conn: conn,
    device: device
  } do
    {:ok, output} = Hardware.create_output(device.id, %{pin: 13, name: "Brake lamp"})
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
    refute has_element?(view, "button[phx-click=toggle_output]")

    port = "/dev/cu.usbmodem1"
    send(view.pid, {:devices_updated, [connected(port, device.config_id)]})

    fingerprint = Hardware.config_fingerprint([], [], [], [])
    {:ok, applied} = Hardware.confirm_configuration(device.id, device.config_id, fingerprint)
    send(view.pid, {:configuration_applied, port, applied, device.config_id})

    refute has_element?(view, "#apply-needed-banner")
    assert has_element?(view, "button[phx-click=toggle_output][aria-pressed=false]", "OFF")

    test_pid = self()

    Mimic.stub(Hardware, :set_output, fn ^port, pin, value ->
      send(test_pid, {:set_output, pin, value})
      :ok
    end)

    view
    |> element("button[phx-click=toggle_output][phx-value-id='#{output.id}']")
    |> render_click()

    assert_receive {:set_output, 13, :high}
    assert has_element?(view, "button[phx-click=toggle_output][aria-pressed=true]", "ON")

    view
    |> element("button[phx-click=toggle_output][phx-value-id='#{output.id}']")
    |> render_click()

    assert_receive {:set_output, 13, :low}
    assert has_element?(view, "button[phx-click=toggle_output][aria-pressed=false]", "OFF")
  end

  defp connected(port, config_id) do
    %DeviceConnection{
      port: port,
      status: :connected,
      device_config_id: config_id,
      device_version: "3.2.1"
    }
  end
end
