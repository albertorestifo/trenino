defmodule TreninoWeb.FirmwareLivePortsTest do
  @moduledoc """
  The firmware page lists serial ports for the upload modal. Listing runs the
  circuits_uart helper, which raises when it cannot run and can block for 5s,
  so it must not run in render/1 and must not crash the page.
  """

  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Firmware

  @port "/dev/cu.usbmodem-FWTEST"

  setup :set_mimic_global

  setup do
    Sandbox.mode(Trenino.Repo, {:shared, self()})

    {:ok, _release} = Firmware.create_release(%{version: "1.0.0", tag_name: "v1.0.0"})

    :ok
  end

  defp open_upload_modal(conn) do
    {:ok, view, _html} = live(conn, "/firmware?port=#{URI.encode_www_form(@port)}")
    render_async(view)
    view
  end

  test "renders the upload modal with no ports when enumeration raises", %{conn: conn} do
    stub(Circuits.UART, :enumerate, fn -> raise ArgumentError end)

    view = open_upload_modal(conn)

    assert Process.alive?(view.pid)
    assert has_element?(view, ".modal button[phx-click=nav_scan_devices]", "Scan for Devices")
    refute has_element?(view, "#port-selection-form")
  end

  test "renders the upload modal with no ports when the helper is blocked", %{conn: conn} do
    stub(Circuits.UART, :enumerate, fn -> :erlang.error(:eacces) end)

    view = open_upload_modal(conn)

    assert Process.alive?(view.pid)
    assert has_element?(view, ".modal button[phx-click=nav_scan_devices]", "Scan for Devices")
    refute has_element?(view, "#port-selection-form")
  end

  test "lists ports outside render and refreshes on device updates", %{conn: conn} do
    {:ok, calls} = Agent.start_link(fn -> 0 end)
    {:ok, ports} = Agent.start_link(fn -> %{} end)

    stub(Circuits.UART, :enumerate, fn ->
      Agent.update(calls, &(&1 + 1))
      Agent.get(ports, & &1)
    end)

    view = open_upload_modal(conn)
    refute has_element?(view, "#port-selection-form")

    # Re-rendering does not list ports again.
    calls_after_mount = Agent.get(calls, & &1)
    for _ <- 1..3, do: render(view)
    assert Agent.get(calls, & &1) == calls_after_mount

    Agent.update(ports, fn _ -> %{@port => %{}} end)
    :ok = Trenino.PubSubHelpers.wait_for_subscriber("device_updates")
    Phoenix.PubSub.broadcast(Trenino.PubSub, "device_updates", {:devices_updated, []})
    render_async(view)

    assert has_element?(view, ~s(#port-selection-form option[value="#{@port}"]))
  end
end
