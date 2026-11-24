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

  describe "simulators" do
    test "lists Train Sim World and SimRail with links to their pages", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      assert has_element?(view, "#simulator-tsw a[href='/settings/simulators/tsw']")
      assert has_element?(view, "#simulator-simrail a[href='/settings/simulators/simrail']")
    end

    test "marks the simulator Trenino connects to", %{conn: conn} do
      {:ok, _} = Settings.set_simulator(:simrail)
      {:ok, view, _html} = live(conn, ~p"/settings")

      assert has_element?(view, "#simulator-simrail", "In use")
      assert has_element?(view, "#simulator-tsw", "Not in use")

      send(
        view.pid,
        {:simulator_status_changed, %Trenino.Simulator.ConnectionState{status: :connected}}
      )

      assert has_element?(view, "#simulator-simrail", "Connected")
    end
  end

  test "shows a quiet Discord link that opens outside the app", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/settings")

    assert has_element?(
             view,
             "#community-footer a[href='https://discord.gg/d75tmjwUav'][target='_blank'][rel~='noopener']",
             "Join the Trenino Discord"
           )
  end
end
