defmodule TreninoWeb.SimulatorSettingsLiveTest do
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
    {:ok, view, _} = live(conn, ~p"/settings/simulators/tsw")
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
    {:ok, view, _} = live(conn, ~p"/settings/simulators/tsw")
    assert has_element?(view, "#api-key-help", "On the Windows PC running Train Sim World")
    assert has_element?(view, "#api-key-help", "CommAPIKey.txt")
  end

  test "Windows key instructions describe local automatic discovery", %{conn: conn} do
    stub(Trenino.Settings.Simulator, :windows?, fn -> true end)
    stub(Trenino.Settings.Simulator, :read_from_file, fn -> {:ok, "found-key"} end)
    {:ok, view, _} = live(conn, ~p"/settings/simulators/tsw")
    assert has_element?(view, "#api-key-help", "Trenino checks")
    assert has_element?(view, "#api-key-help", "TrainSimWorld7")
    assert has_element?(view, "#api-key-help", "TrainSimWorld6")
    refute has_element?(view, "#api-key-help", "copy the key")
  end

  describe "Train Sim World settings" do
    test "renders the URL field", %{conn: conn} do
      {:ok, _} = Settings.set_simulator_url("http://192.168.1.42:31270")
      {:ok, _view, html} = live(conn, ~p"/settings/simulators/tsw")

      assert html =~ "http://192.168.1.42:31270"
    end

    test "saves a new URL on submit", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/simulators/tsw")

      view
      |> form("[data-testid='simulator-form']",
        simulator: %{url: "http://10.0.0.1:31270", api_key: ""}
      )
      |> render_submit()

      assert "http://10.0.0.1:31270" = Settings.simulator_url()
    end

    test "saves an api key override when provided", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/simulators/tsw")

      view
      |> form("[data-testid='simulator-form']",
        simulator: %{url: "http://localhost:31270", api_key: "my-override"}
      )
      |> render_submit()

      assert {:ok, "my-override"} = Settings.api_key()
    end

    test "leaves api key untouched when override field is blank", %{conn: conn} do
      {:ok, _} = Settings.set_api_key("existing")
      {:ok, view, _html} = live(conn, ~p"/settings/simulators/tsw")

      view
      |> form("[data-testid='simulator-form']",
        simulator: %{url: "http://localhost:31270", api_key: ""}
      )
      |> render_submit()

      assert {:ok, "existing"} = Settings.api_key()
    end
  end

  describe "SimRail (beta)" do
    test "shows the bridge URL and token", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/simulators/simrail")

      assert has_element?(view, "#simrail_url[value='http://127.0.0.1:31275']")
      assert has_element?(view, "#simrail_token[type='password']")
      assert has_element?(view, "#simrail-token-help", "another computer")
      refute has_element?(view, "#simulator_url")
    end

    test "says saving switches simulators when another one is in use", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/simulators/simrail")

      assert has_element?(view, "#active-simulator-note", "Saving here switches to SimRail")
    end

    test "saving stores the choice, URL and token, and reconnects", %{conn: conn} do
      expect(Trenino.Simulator.Connection, :reconfigure, fn -> :ok end)
      {:ok, view, _html} = live(conn, ~p"/settings/simulators/simrail")

      view
      |> form("#simulator-form",
        simulator: %{simrail_url: "http://192.168.1.20:31275", simrail_token: "bridge-token"}
      )
      |> render_submit()

      assert :simrail = Settings.simulator()
      assert "http://192.168.1.20:31275" = Settings.simrail_url()
      assert "bridge-token" = Settings.simrail_token()
      assert "http://localhost:31270" = Settings.simulator_url()

      send(
        view.pid,
        {:simulator_status_changed, %Trenino.Simulator.ConnectionState{status: :connected}}
      )

      assert has_element?(view, "#simulator-connection-result", "Connected to SimRail")
      assert has_element?(view, "#active-simulator-note", "Trenino connects to SimRail")
    end

    test "a blank token keeps the stored one", %{conn: conn} do
      {:ok, _} = Settings.set_simulator(:simrail)
      {:ok, _} = Settings.set_simrail_token("existing")
      stub(Trenino.Simulator.Connection, :reconfigure, fn -> :ok end)
      {:ok, view, _html} = live(conn, ~p"/settings/simulators/simrail")

      view
      |> form("#simulator-form",
        simulator: %{simrail_url: "http://127.0.0.1:31275", simrail_token: ""}
      )
      |> render_submit()

      assert "existing" = Settings.simrail_token()
    end

    test "says when no token is saved", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/simulators/simrail")

      assert has_element?(view, "#simrail-token-status", "No token saved")
      refute has_element?(view, "#remove-simrail-token")
    end

    test "a saved token can be removed without being shown", %{conn: conn} do
      {:ok, _} = Settings.set_simulator(:simrail)
      {:ok, _} = Settings.set_simrail_token("secret-bridge-token")
      expect(Trenino.Simulator.Connection, :reconfigure, fn -> :ok end)
      {:ok, view, html} = live(conn, ~p"/settings/simulators/simrail")

      refute html =~ "secret-bridge-token"
      assert has_element?(view, "#simrail-token-status", "A token is saved")

      view |> element("#remove-simrail-token") |> render_click()

      assert nil == Settings.simrail_token()
      assert has_element?(view, "#simrail-token-status", "No token saved")
      assert has_element?(view, "#simulator-connection-result", "Token removed")
    end

    test "rejects a bridge URL without a scheme", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/simulators/simrail")

      view
      |> form("#simulator-form", simulator: %{simrail_url: "127.0.0.1:31275"})
      |> render_change()

      assert render(view) =~ "URL must start with http:// or https://"
    end

    test "links to the setup assistant", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/simulators/simrail")

      assert has_element?(
               view,
               "#open-simrail-setup[href='/settings/simulators/simrail/setup']"
             )
    end
  end

  describe "Train Sim World page" do
    test "saving switches back to Train Sim World", %{conn: conn} do
      {:ok, _} = Settings.set_simulator(:simrail)
      stub(Trenino.Simulator.Connection, :reconfigure, fn -> :ok end)
      {:ok, view, _html} = live(conn, ~p"/settings/simulators/tsw")

      assert has_element?(
               view,
               "#active-simulator-note",
               "Saving here switches to Train Sim World"
             )

      view
      |> form("#simulator-form", simulator: %{url: "http://localhost:31270", api_key: ""})
      |> render_submit()

      assert :tsw = Settings.simulator()
    end
  end

  test "an unknown simulator goes back to Settings", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/settings"}}} =
             live(conn, ~p"/settings/simulators/other")
  end
end
