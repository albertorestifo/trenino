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

      refute has_element?(view, "#stepper-axes")
      refute has_element?(view, "a[href='#stepper-axes']")
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

  describe "settings toggle" do
    test "enabling beta features shows them on the next page load", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/settings")
      refute has_element?(view, "input[data-testid='beta-features-toggle'][checked]")

      view |> element("input[data-testid='beta-features-toggle']") |> render_click()
      assert Settings.beta_features?()

      {:ok, device} = Hardware.create_device(%{name: "Panel"})
      {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
      assert has_element?(view, "#stepper-axes")
    end

    test "is replaced by a note when beta features are always on", %{conn: conn} do
      Application.put_env(:trenino, :beta_features, :all)
      {:ok, view, _} = live(conn, ~p"/settings")

      refute has_element?(view, "input[data-testid='beta-features-toggle']")
      assert render(view) =~ "Beta features are always on in this build."
    end
  end
end
