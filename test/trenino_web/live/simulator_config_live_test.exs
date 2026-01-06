defmodule TreninoWeb.SimulatorConfigLiveTest do
  # Non-async because the Simulator.Connection GenServer needs database access
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Trenino.Simulator
  alias Trenino.Simulator.Config
  alias Trenino.Simulator.ConnectionState

  # Allow the Connection GenServer to access the database sandbox
  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Trenino.Repo, {:shared, self()})
    :ok
  end

  describe "mount/3" do
    test "renders the simulator config page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/simulator/config")

      assert html =~ "Simulator Configuration"
      assert html =~ "Configure connection to Train Sim World API"
    end

    test "shows connection status section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/simulator/config")

      # Should show some connection status (the actual status depends on Connection GenServer)
      # We verify the status display components are rendered
      assert html =~ "<h3 class=\"font-medium\">"
      assert html =~ "opacity-80"
    end

    test "pre-fills default URL when no config exists", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/simulator/config")

      # On Windows, toggle to manual mode to see the form
      html = maybe_toggle_to_manual(view)

      assert html =~ "http://localhost:31270"
    end

    test "shows existing config when present", %{conn: conn} do
      {:ok, _config} = create_config(%{url: "http://192.168.1.100:31270", api_key: "my-key"})

      {:ok, view, _html} = live(conn, ~p"/simulator/config")

      # On Windows, toggle to manual mode to see the form
      html = maybe_toggle_to_manual(view)

      assert html =~ "http://192.168.1.100:31270"
    end
  end

  describe "connection status display" do
    test "shows success status when connected", %{conn: conn} do
      {:ok, _config} = create_config()
      {:ok, view, _html} = live(conn, ~p"/simulator/config")

      # Simulate connection status change via PubSub
      send(view.pid, {:simulator_status_changed, %ConnectionState{status: :connected}})

      html = render(view)
      assert html =~ "Connected"
      assert html =~ "alert-success"
    end

    test "shows connecting status", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/simulator/config")

      send(view.pid, {:simulator_status_changed, %ConnectionState{status: :connecting}})

      html = render(view)
      assert html =~ "Connecting..."
      assert html =~ "alert-info"
    end

    test "shows error status with retry button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/simulator/config")

      send(
        view.pid,
        {:simulator_status_changed, %ConnectionState{status: :error, last_error: :timeout}}
      )

      html = render(view)
      assert html =~ "Connection Error"
      assert html =~ "Connection timed out"
      assert html =~ "Retry"
    end

    test "shows invalid key error message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/simulator/config")

      send(
        view.pid,
        {:simulator_status_changed, %ConnectionState{status: :error, last_error: :invalid_key}}
      )

      html = render(view)
      assert html =~ "Invalid API key"
    end

    test "shows connection failed error message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/simulator/config")

      send(
        view.pid,
        {:simulator_status_changed,
         %ConnectionState{status: :error, last_error: :connection_failed}}
      )

      html = render(view)
      assert html =~ "Could not connect to the simulator"
    end
  end

  describe "form validation" do
    test "validates URL format on change", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/simulator/config")

      # On Windows, toggle to manual mode first
      maybe_toggle_to_manual(view)

      html =
        view
        |> form("#config-form", config: %{url: "invalid-url", api_key: "test-key"})
        |> render_change()

      assert html =~ "must be a valid HTTP or HTTPS URL"
    end

    test "validates required api_key", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/simulator/config")

      # On Windows, toggle to manual mode first
      maybe_toggle_to_manual(view)

      html =
        view
        |> form("#config-form", config: %{url: "http://localhost:31270", api_key: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end

    test "accepts valid HTTPS URL", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/simulator/config")

      # On Windows, toggle to manual mode first
      maybe_toggle_to_manual(view)

      html =
        view
        |> form("#config-form",
          config: %{url: "https://192.168.1.100:31270", api_key: "test-key"}
        )
        |> render_change()

      refute html =~ "must be a valid HTTP or HTTPS URL"
    end
  end

  describe "save event" do
    test "creates new config successfully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/simulator/config")

      # On Windows, toggle to manual mode first
      maybe_toggle_to_manual(view)

      view
      |> form("#config-form", config: %{url: "http://localhost:31270", api_key: "my-api-key"})
      |> render_submit()

      # Verify config was saved
      assert {:ok, config} = Simulator.get_config()
      assert config.url == "http://localhost:31270"
      assert config.api_key == "my-api-key"
    end

    test "updates existing config", %{conn: conn} do
      {:ok, _} = create_config(%{url: "http://localhost:31270", api_key: "old-key"})

      {:ok, view, _html} = live(conn, ~p"/simulator/config")

      # On Windows, toggle to manual mode first
      maybe_toggle_to_manual(view)

      view
      |> form("#config-form", config: %{url: "http://192.168.1.100:31270", api_key: "new-key"})
      |> render_submit()

      # Verify config was updated
      assert {:ok, config} = Simulator.get_config()
      assert config.url == "http://192.168.1.100:31270"
      assert config.api_key == "new-key"
    end

    test "shows validation errors on invalid submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/simulator/config")

      # On Windows, toggle to manual mode first
      maybe_toggle_to_manual(view)

      html =
        view
        |> form("#config-form", config: %{url: "ftp://invalid", api_key: "key"})
        |> render_submit()

      assert html =~ "must be a valid HTTP or HTTPS URL"

      # Verify config was NOT saved
      assert {:error, :not_found} = Simulator.get_config()
    end
  end

  describe "retry event" do
    test "triggers retry when retry button clicked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/simulator/config")

      # Send an error status first so retry button appears
      send(
        view.pid,
        {:simulator_status_changed, %ConnectionState{status: :error, last_error: :timeout}}
      )

      html = render(view)
      assert html =~ "Retry"

      # Click retry button - this should not raise an error
      view
      |> element("button", "Retry")
      |> render_click()

      # Verify the retry was handled (the view should still be alive)
      assert render(view) =~ "Simulator Configuration"
    end
  end

  describe "delete event" do
    test "deletes existing config successfully", %{conn: conn} do
      {:ok, _} = create_config()

      {:ok, view, _html} = live(conn, ~p"/simulator/config")

      view
      |> element("button", "Delete")
      |> render_click()

      # Verify config was deleted
      assert {:error, :not_found} = Simulator.get_config()
    end

    test "delete button is hidden when no config exists", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/simulator/config")

      refute html =~ ">Delete<"
    end

    test "delete button is shown when config exists", %{conn: conn} do
      {:ok, _} = create_config()

      {:ok, _view, html} = live(conn, ~p"/simulator/config")

      assert html =~ ">Delete<" or html =~ "Delete\n"
    end
  end

  describe "toggle_manual event" do
    test "on non-Windows, shows manual config by default", %{conn: conn} do
      # Non-Windows platforms should show manual config immediately
      case :os.type() do
        {:win32, _} ->
          :ok

        _ ->
          {:ok, _view, html} = live(conn, ~p"/simulator/config")

          # Should show manual configuration fields
          assert html =~ "API URL"
          assert html =~ "API Key"
      end
    end
  end

  describe "auto_detect event" do
    test "shows error on non-Windows platforms", %{conn: conn} do
      case :os.type() do
        {:win32, _} ->
          :ok

        _ ->
          # On non-Windows, auto-detect should not be shown by default
          # but if we force the manual toggle off, auto_detect would fail
          {:ok, _view, html} = live(conn, ~p"/simulator/config")

          # Manual config is shown on non-Windows, so no auto-detect button
          refute html =~ "Auto-Detect Configuration"
      end
    end
  end

  describe "navigation" do
    test "has link back to home page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/simulator/config")

      assert html =~ "Trenino"
      assert html =~ ~s(href="/")
    end
  end

  # Helper to create a config for tests
  defp create_config(attrs \\ %{}) do
    default_attrs = %{
      url: "http://localhost:31270",
      api_key: "test-api-key"
    }

    %Config{}
    |> Config.changeset(Map.merge(default_attrs, attrs))
    |> Trenino.Repo.insert()
  end

  # On Windows, the manual config form is hidden by default.
  # This helper toggles to manual mode if needed and returns the rendered HTML.
  defp maybe_toggle_to_manual(view) do
    html = render(view)

    if html =~ "Manual Configuration" do
      # Windows mode - need to toggle to manual
      view
      |> element("button", "Manual Configuration")
      |> render_click()
    else
      html
    end
  end
end
