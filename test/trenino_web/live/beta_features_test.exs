defmodule TreninoWeb.BetaFeaturesTest do
  # Switches the global :beta_features mode, so it cannot run async
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Hardware
  alias Trenino.Settings
  alias Trenino.Train, as: TrainContext

  setup :set_mimic_global

  setup do
    Sandbox.mode(Trenino.Repo, {:shared, self()})
    {:ok, _} = Settings.set_error_reporting(:disabled)

    previous = Application.get_env(:trenino, :beta_features)
    Application.put_env(:trenino, :beta_features, :setting)
    on_exit(fn -> Application.put_env(:trenino, :beta_features, previous) end)
    :ok
  end

  describe "with beta features off" do
    test "the configuration page hides gauges", %{conn: conn} do
      {:ok, device} = Hardware.create_device(%{name: "Panel"})
      {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")

      refute has_element?(view, "#gauges")
      refute has_element?(view, "a[href='#gauges']")
      assert has_element?(view, "#outputs")
    end

    test "the train page hides gauge bindings and selectors", %{conn: conn} do
      {:ok, train} =
        TrainContext.create_train(%{name: "T", identifiers: [%{identifier: "Beta_T"}]})

      {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")

      refute has_element?(view, "#gauge-bindings")
      refute has_element?(view, "a[href='#gauge-bindings']")

      view |> element("#add-element") |> render_click()
      assert has_element?(view, "#add-element-form option[value='lever']")
      refute has_element?(view, "#add-element-form option[value='selector']")
    end
  end

  describe "settings page with beta features off" do
    test "lists only Train Sim World", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/settings")

      assert has_element?(view, "#simulator-tsw")
      refute has_element?(view, "#simulator-simrail")
    end

    test "shows Train Sim World as in use even when SimRail was chosen", %{conn: conn} do
      {:ok, _} = Settings.set_simulator(:simrail)
      {:ok, view, _} = live(conn, ~p"/settings")

      assert has_element?(view, "#simulator-tsw", "In use")
    end

    test "the SimRail page sends you to Train Sim World", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/settings/simulators/tsw"}}} =
               live(conn, ~p"/settings/simulators/simrail")
    end

    test "saving connects to Train Sim World", %{conn: conn} do
      {:ok, _} = Settings.set_simulator(:simrail)
      expect(Trenino.Simulator.Connection, :reconfigure, fn -> :ok end)
      {:ok, view, _} = live(conn, ~p"/settings/simulators/tsw")

      view
      |> form("#simulator-form", simulator: %{url: "http://localhost:31270", api_key: ""})
      |> render_submit()

      assert :tsw = Settings.simulator()
    end

    test "hides the SimRail setup assistant toggle", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/settings")

      refute has_element?(view, "#simrail-onboarding-option")
    end
  end

  describe "SimRail setup assistant (opt-in)" do
    setup do
      {:ok, _} = Settings.set_beta_features(:enabled)
      :ok
    end

    test "is off until its own toggle is on", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/settings/simulators/simrail")
      refute has_element?(view, "#open-simrail-setup")

      assert {:error, {:live_redirect, %{to: "/settings/simulators/simrail"}}} =
               live(conn, ~p"/settings/simulators/simrail/setup")
    end

    test "its toggle turns it on", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/settings")
      refute has_element?(view, "input[data-testid='simrail-onboarding-toggle'][checked]")

      view |> element("input[data-testid='simrail-onboarding-toggle']") |> render_click()
      assert Settings.beta_feature?(:simrail_onboarding)

      {:ok, view, _} = live(conn, ~p"/settings/simulators/simrail")
      assert has_element?(view, "#open-simrail-setup")
      assert {:ok, _view, _html} = live(conn, ~p"/settings/simulators/simrail/setup")
    end

    test "stays off while beta features are off", %{conn: conn} do
      {:ok, _} = Settings.set_beta_feature(:simrail_onboarding, :enabled)
      {:ok, _} = Settings.set_beta_features(:disabled)

      assert {:error, {:live_redirect, _}} = live(conn, ~p"/settings/simulators/simrail/setup")
    end
  end

  describe "settings toggle" do
    test "enabling beta features shows them on the next page load", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/settings")
      refute has_element?(view, "input[data-testid='beta-features-toggle'][checked]")

      view |> element("input[data-testid='beta-features-toggle']") |> render_click()
      assert Settings.beta_features?()

      {:ok, device} = Hardware.create_device(%{name: "Panel"})
      {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
      assert has_element?(view, "#gauges")
    end

    test "is replaced by a note when beta features are always on", %{conn: conn} do
      Application.put_env(:trenino, :beta_features, :all)
      {:ok, view, _} = live(conn, ~p"/settings")

      refute has_element?(view, "input[data-testid='beta-features-toggle']")
      assert render(view) =~ "Beta features are always on in this build."
    end
  end
end
