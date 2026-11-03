defmodule TreninoWeb.ConfigurationListLiveTest do
  # Non-async because the Simulator.Connection GenServer needs database access
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Hardware
  alias Trenino.Serial.Connection
  alias Trenino.Simulator.ConnectionState

  # Allow the Connection GenServer to access the database sandbox
  setup do
    Sandbox.mode(Trenino.Repo, {:shared, self()})
    :ok
  end

  # Stub serial Connection calls that would otherwise hit the real GenServer.
  # Connection.scan/0 is a GenServer.cast and Connection.list_devices/0 is a
  # GenServer.call; without stubs both go to the running process and can add
  # 200ms+ per test while the GenServer processes the request and attempts
  # (forbidden) UART enumeration.
  setup do
    stub(Connection, :scan, fn -> :ok end)
    stub(Connection, :connected_devices, fn -> [] end)
    stub(Connection, :list_devices, fn -> [] end)
    :ok
  end

  describe "basic rendering" do
    test "GET / renders configuration list", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      # Always present regardless of device state
      assert html =~ "Trenino"
      assert html =~ "Configurations"
    end

    test "shows empty state when no configurations exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "No Configurations"
      assert html =~ "Create Configuration"
    end

    test "shows configuration cards when configurations exist", %{conn: conn} do
      {:ok, _device} = Hardware.create_device(%{name: "Test Config"})

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Test Config"
    end
  end

  describe "simulator status indicator" do
    test "shows settings link in header", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Settings"
      assert html =~ ~s(href="/settings")
    end

    test "updates simulator status on PubSub event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Send connected status — banner is hidden, no error message shown
      send(view.pid, {:simulator_status_changed, %ConnectionState{status: :connected}})

      html = render(view)
      refute html =~ "Simulator connection failed"
      refute html =~ "Simulator is offline"
    end

    test "shows a neutral notice when needs config", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      send(view.pid, {:simulator_status_changed, %ConnectionState{status: :needs_config}})

      render(view)
      assert has_element?(view, "#simulator-status-banner", "Simulator not configured")
      assert has_element?(view, "#simulator-status-banner a[href='/settings']", "Open Settings")
    end

    test "shows a solid error banner on connection error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      send(
        view.pid,
        {:simulator_status_changed, %ConnectionState{status: :error, last_error: :timeout}}
      )

      render(view)
      assert has_element?(view, "#simulator-status-banner", "Simulator connection failed")
      assert has_element?(view, "#simulator-status-banner .bg-error")
    end

    test "hides sim banner when connecting", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Banner is hidden while connecting — no error message shown
      send(view.pid, {:simulator_status_changed, %ConnectionState{status: :connecting}})

      html = render(view)
      refute html =~ "Simulator connection failed"
      refute html =~ "Simulator is offline"
    end

    test "shows offline notice when disconnected", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      send(view.pid, {:simulator_status_changed, %ConnectionState{status: :disconnected}})

      render(view)
      assert has_element?(view, "#simulator-status-banner", "Simulator is offline")

      assert has_element?(
               view,
               "#simulator-status-banner button[phx-click='nav_retry_simulator']"
             )
    end
  end

  describe "device status summary" do
    test "labels every summary state with text, not color alone", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      summary = "button[phx-click='nav_toggle_dropdown']"

      assert has_element?(view, summary, "No devices")

      cases = [
        {[device("COM1", :connected)], "1 connected", "hero-check-circle-mini"},
        {[device("COM1", :connected), device("COM2", :connected)], "2 connected",
         "hero-check-circle-mini"},
        {[device("COM1", :discovering)], "Connecting", "hero-arrow-path-mini"},
        {[device("COM1", :connected), device("COM2", :failed)], "Needs attention",
         "hero-exclamation-triangle-mini"}
      ]

      for {devices, label, icon} <- cases do
        send(view.pid, {:devices_updated, devices})
        render(view)

        assert has_element?(view, summary, label)
        assert has_element?(view, "#{summary}[aria-label='Devices: #{label}'] .#{icon}")
      end
    end

    test "device rows use the status vocabulary", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      send(
        view.pid,
        {:devices_updated,
         [device("COM1", :connected), device("COM2", :discovering), device("COM3", :failed)]}
      )

      html = view |> element("button[phx-click='nav_toggle_dropdown']") |> render_click()

      assert html =~ "Connected"
      assert html =~ "Connecting"
      assert html =~ "Failed"
      refute html =~ "Discovering"
    end
  end

  defp device(port, status),
    do: %Trenino.Serial.Connection.DeviceConnection{port: port, status: status}

  describe "device scanning" do
    test "scan button shows scanning state when clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Open the dropdown first
      view |> element("button[phx-click='nav_toggle_dropdown']") |> render_click()

      html = render(view)

      # Dropdown is open and shows "Scan for Devices"
      assert html =~ "Scan for Devices"
      refute html =~ "Scanning..."

      # Click the scan button
      html = view |> element("button[phx-click='nav_scan_devices']") |> render_click()

      # Now shows "Scanning..."
      assert html =~ "Scanning..."
      refute html =~ "Scan for Devices"
    end

    test "scan button resets after scan_complete event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Open the dropdown first
      view |> element("button[phx-click='nav_toggle_dropdown']") |> render_click()

      # Click the scan button to start scanning
      view |> element("button[phx-click='nav_scan_devices']") |> render_click()

      # Simulate scan completion
      send(view.pid, :scan_complete)

      html = render(view)

      # Button should be reset to "Scan for Devices"
      assert html =~ "Scan for Devices"
      refute html =~ "Scanning..."
    end
  end
end
