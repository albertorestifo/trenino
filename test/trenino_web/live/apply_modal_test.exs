defmodule TreninoWeb.ApplyModalTest do
  use TreninoWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Trenino.Hardware
  alias Trenino.Serial.Connection.DeviceConnection

  describe "apply modal" do
    test "shows which configuration each connected device is running", %{conn: conn} do
      {:ok, config} = Hardware.create_device(%{name: "Switch Panel"})
      {:ok, other} = Hardware.create_device(%{name: "Class 66 desk"})

      {:ok, view, _html} = live(conn, ~p"/configurations/#{config.config_id}")

      send(
        view.pid,
        {:devices_updated,
         [
           connected("/dev/cu.usbmodem111101", config.config_id),
           connected("/dev/cu.usbserial-A5069RR4", other.config_id),
           connected("/dev/cu.usbmodem3", nil),
           connected("/dev/cu.usbmodem4", 0),
           connected("/dev/cu.usbmodem5", 987_654)
         ]}
      )

      render_click(view, "show_apply_modal")

      assert has_element?(
               view,
               "#apply-device--dev-cu-usbmodem111101",
               "Running this configuration"
             )

      assert has_element?(view, "#apply-device--dev-cu-usbserial-A5069RR4", "Running")
      assert has_element?(view, "#apply-device--dev-cu-usbserial-A5069RR4", "Class 66 desk")
      assert has_element?(view, "#apply-device--dev-cu-usbmodem3", "No configuration")
      assert has_element?(view, "#apply-device--dev-cu-usbmodem4", "No configuration")
      assert has_element?(view, "#apply-device--dev-cu-usbmodem5", "Unknown configuration")
    end
  end

  describe "apply events for another configuration" do
    setup %{conn: conn} do
      {:ok, config} = Hardware.create_device(%{name: "Switch Panel"})
      {:ok, other} = Hardware.create_device(%{name: "Class 66 desk"})
      {:ok, view, _html} = live(conn, ~p"/configurations/#{config.config_id}")
      %{view: view, config: config, other: other}
    end

    test "another configuration being applied leaves this page alone", ctx do
      send(ctx.view.pid, {:configuration_applied, "/dev/other", ctx.other, ctx.other.config_id})

      html = render(ctx.view)
      refute html =~ "Configuration applied"
      refute html =~ "Class 66 desk"
      assert html =~ "Switch Panel"
    end

    test "another configuration failing to apply shows no error here", ctx do
      send(ctx.view.pid, {:configuration_failed, "/dev/other", ctx.other.id, :timeout})

      refute render(ctx.view) =~ "Check the USB cable"
    end

    test "this configuration's own events still update the page", ctx do
      send(ctx.view.pid, {:configuration_failed, "/dev/mine", ctx.config.id, :timeout})
      assert render(ctx.view) =~ "Check the USB cable"

      send(ctx.view.pid, {:configuration_applied, "/dev/mine", ctx.config, ctx.config.config_id})
      assert render(ctx.view) =~ "Configuration applied"
    end
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
