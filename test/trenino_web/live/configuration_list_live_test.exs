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

  describe "simulator status in the connections dropdown" do
    test "shows settings as a navigation tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(
               view,
               "nav[aria-label='Primary navigation'] a[href='/settings']",
               "Settings"
             )
    end

    test "never renders a simulator banner", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      send(
        view.pid,
        {:simulator_status_changed, %ConnectionState{status: :error, last_error: :timeout}}
      )

      render(view)
      refute has_element?(view, "#simulator-status-banner")
      refute has_element?(view, "header .bg-error")
      refute has_element?(view, "#simulator-notice")
    end

    test "shows each simulator state with its next step and action", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      open_dropdown(view)
      row = "#simulator-status-row"

      cases = [
        {%ConnectionState{status: :connected}, "Connected", nil, nil},
        {%ConnectionState{status: :connecting}, "Connecting", nil, nil},
        {%ConnectionState{status: :needs_config}, "Needs attention", "API key",
         "a[href='/settings']"},
        {%ConnectionState{status: :disconnected}, "Needs attention", "Start Train Sim World",
         "button[phx-click='nav_retry_simulator']"},
        {%ConnectionState{status: :error, last_error: :timeout}, "Failed", "did not respond",
         "button[phx-click='nav_retry_simulator']"},
        {%ConnectionState{status: :error, last_error: :invalid_key}, "Failed",
         "API key was rejected", "a[href='/settings']"}
      ]

      for {state, label, hint, action} <- cases do
        send(view.pid, {:simulator_status_changed, state})
        render(view)

        assert has_element?(view, row, label)
        if hint, do: assert(has_element?(view, row, hint))

        if action,
          do: assert(has_element?(view, "#{row} #{action}")),
          else: refute(has_element?(view, "#{row} a, #{row} button"))
      end
    end
  end

  describe "connections summary" do
    test "labels every summary state with text, not color alone", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      summary = "button[phx-click='nav_toggle_dropdown']"
      connected_sim = %ConnectionState{status: :connected}

      cases = [
        {[], connected_sim, "No devices", "hero-minus-circle-mini"},
        {[device("COM1", :connected)], connected_sim, "1 connected", "hero-check-circle-mini"},
        {[device("COM1", :connected), device("COM2", :connected)], connected_sim, "2 connected",
         "hero-check-circle-mini"},
        {[device("COM1", :discovering)], connected_sim, "Connecting", "hero-arrow-path-mini"},
        {[device("COM1", :connected)], %ConnectionState{status: :connecting}, "Connecting",
         "hero-arrow-path-mini"},
        {[device("COM1", :connected), device("COM2", :failed)], connected_sim, "Needs attention",
         "hero-exclamation-triangle-mini"},
        {[device("COM1", :connected)], %ConnectionState{status: :error, last_error: :timeout},
         "Needs attention", "hero-exclamation-triangle-mini"},
        {[], %ConnectionState{status: :needs_config}, "Needs attention",
         "hero-exclamation-triangle-mini"},
        {[device("COM1", :connected)], %ConnectionState{status: :disconnected}, "Needs attention",
         "hero-exclamation-triangle-mini"}
      ]

      for {devices, sim, label, icon} <- cases do
        send(view.pid, {:simulator_status_changed, sim})
        send(view.pid, {:devices_updated, devices})
        render(view)

        assert has_element?(view, summary, label)
        assert has_element?(view, "#{summary}[aria-label='Connections: #{label}'] .#{icon}")
      end
    end

    test "device rows use the status vocabulary", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      send(
        view.pid,
        {:devices_updated,
         [device("COM1", :connected), device("COM2", :discovering), device("COM3", :failed)]}
      )

      html = open_dropdown(view)

      assert html =~ "Connected"
      assert html =~ "Connecting"
      assert html =~ "Failed"
      refute html =~ "Discovering"
    end

    test "device rows are named after their configuration, port second", %{conn: conn} do
      {:ok, config} = Hardware.create_device(%{name: "Class 66 desk"})
      {:ok, view, _html} = live(conn, ~p"/")

      send(
        view.pid,
        {:devices_updated,
         [
           %{device("/dev/cu.usbserial-A1", :connected) | device_config_id: config.config_id},
           device("/dev/cu.usbmodem2", :connected)
         ]}
      )

      open_dropdown(view)

      assert has_element?(view, "button[aria-label='Disconnect from Class 66 desk']")
      assert has_element?(view, "span.font-mono", "/dev/cu.usbserial-A1")
      assert has_element?(view, "button[aria-label='Disconnect from /dev/cu.usbmodem2']")
    end
  end

  defp open_dropdown(view) do
    view |> element("button[phx-click='nav_toggle_dropdown']") |> render_click()
  end

  defp device(port, status),
    do: %Trenino.Serial.Connection.DeviceConnection{port: port, status: status}

  describe "device scanning" do
    test "scan button shows scanning state when clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Open the dropdown first
      view |> element("button[phx-click='nav_toggle_dropdown']") |> render_click()

      html = render(view)

      # Dropdown is open and shows the scan action
      assert has_element?(view, "button[phx-click='nav_scan_devices']", "Scan")
      refute html =~ "Scanning..."

      # Click the scan button
      html = view |> element("button[phx-click='nav_scan_devices']") |> render_click()

      # Now shows "Scanning..."
      assert html =~ "Scanning..."
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

      # Button is reset to "Scan"
      assert has_element?(view, "button[phx-click='nav_scan_devices']", "Scan")
      refute html =~ "Scanning..."
    end
  end
end
