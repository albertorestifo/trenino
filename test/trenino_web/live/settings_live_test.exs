defmodule TreninoWeb.SettingsLiveTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Settings

  setup do
    Sandbox.mode(Trenino.Repo, {:shared, self()})
    # Pass the consent gate
    {:ok, _} = Settings.set_error_reporting(:disabled)
    :ok
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
