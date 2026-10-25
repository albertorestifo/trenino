defmodule TreninoWeb.SettingsLiveTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Settings

  setup :set_mimic_global

  setup do
    Sandbox.mode(Trenino.Repo, {:shared, self()})
    # Pass the consent gate
    {:ok, _} = Settings.set_error_reporting(:disabled)
    :ok
  end

  test "save and test connection reports the actual connection outcome", %{conn: conn} do
    expect(Trenino.Simulator.Connection, :reconfigure, fn -> :ok end)
    {:ok, view, _} = live(conn, ~p"/settings")
    assert has_element?(view, "button[type='submit']", "Save and test connection")

    view
    |> form("#simulator-form", simulator: %{url: "http://localhost:31270", api_key: "test"})
    |> render_submit()

    assert has_element?(
             view,
             "#simulator-connection-result[role='status']",
             "Settings saved. Testing connection"
           )

    send(
      view.pid,
      {:simulator_status_changed,
       %Trenino.Simulator.ConnectionState{status: :error, last_error: :invalid_key}}
    )

    assert has_element?(view, "#simulator-connection-result", "API key was rejected")

    send(
      view.pid,
      {:simulator_status_changed, %Trenino.Simulator.ConnectionState{status: :connected}}
    )

    assert has_element?(view, "#simulator-connection-result", "Connected to Train Sim World")
  end

  test "non-Windows key instructions explain copying from the simulator PC", %{conn: conn} do
    stub(Trenino.Settings.Simulator, :windows?, fn -> false end)
    {:ok, view, _} = live(conn, ~p"/settings")
    assert has_element?(view, "#api-key-help", "On the Windows PC running Train Sim World")
    assert has_element?(view, "#api-key-help", "CommAPIKey.txt")
  end

  test "Windows key instructions describe local automatic discovery", %{conn: conn} do
    stub(Trenino.Settings.Simulator, :windows?, fn -> true end)
    stub(Trenino.Settings.Simulator, :read_from_file, fn -> {:ok, "found-key"} end)
    {:ok, view, _} = live(conn, ~p"/settings")
    assert has_element?(view, "#api-key-help", "Trenino checks")
    assert has_element?(view, "#api-key-help", "TrainSimWorld7")
    assert has_element?(view, "#api-key-help", "TrainSimWorld6")
    refute has_element?(view, "#api-key-help", "copy the key")
  end

  describe "mount/3" do
    test "renders the Settings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "Settings"
      assert html =~ "Error Reporting"
    end

    test "shows the toggle reflecting current preference (off)", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")
      refute has_element?(view, "input[data-testid='error-reporting-toggle'][checked]")
    end

    test "shows the toggle reflecting current preference (on)", %{conn: conn} do
      {:ok, _} = Settings.set_error_reporting(:enabled)
      {:ok, view, _html} = live(conn, ~p"/settings")
      assert has_element?(view, "input[data-testid='error-reporting-toggle'][checked]")
    end

    test "shows a link to revisit the consent screen", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")
      assert html =~ ~s(href="/consent")
    end
  end

  describe "toggle_error_reporting" do
    test "enables when toggled on", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      view
      |> element("input[data-testid='error-reporting-toggle']")
      |> render_click()

      assert Settings.error_reporting?()
    end

    test "disables when toggled off", %{conn: conn} do
      {:ok, _} = Settings.set_error_reporting(:enabled)
      {:ok, view, _html} = live(conn, ~p"/settings")

      view
      |> element("input[data-testid='error-reporting-toggle']")
      |> render_click()

      refute Settings.error_reporting?()
    end
  end

  describe "simulator section" do
    test "renders the URL field", %{conn: conn} do
      {:ok, _} = Settings.set_simulator_url("http://192.168.1.42:31270")
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "Simulator Connection"
      assert html =~ "http://192.168.1.42:31270"
    end

    test "saves a new URL on submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      view
      |> form("[data-testid='simulator-form']",
        simulator: %{url: "http://10.0.0.1:31270", api_key: ""}
      )
      |> render_submit()

      assert "http://10.0.0.1:31270" = Settings.simulator_url()
    end

    test "saves an api key override when provided", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      view
      |> form("[data-testid='simulator-form']",
        simulator: %{url: "http://localhost:31270", api_key: "my-override"}
      )
      |> render_submit()

      assert {:ok, "my-override"} = Settings.api_key()
    end

    test "leaves api key untouched when override field is blank", %{conn: conn} do
      {:ok, _} = Settings.set_api_key("existing")
      {:ok, view, _html} = live(conn, ~p"/settings")

      view
      |> form("[data-testid='simulator-form']",
        simulator: %{url: "http://localhost:31270", api_key: ""}
      )
      |> render_submit()

      assert {:ok, "existing"} = Settings.api_key()
    end
  end
end
