defmodule TreninoWeb.SimRailSetupLiveTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Settings
  alias Trenino.Simulator.Backend.SimRail, as: SimRailBackend
  alias Trenino.Simulator.ConnectionState

  @moduletag :tmp_dir

  setup :set_mimic_global

  setup %{tmp_dir: tmp_dir} do
    Sandbox.mode(Trenino.Repo, {:shared, self()})
    {:ok, _} = Settings.set_error_reporting(:disabled)

    previous = Application.get_env(:trenino, :simrail_mods_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:trenino, :simrail_mods_dir, previous),
        else: Application.delete_env(:trenino, :simrail_mods_dir)
    end)

    mods = Path.join(tmp_dir, "bundle")
    File.mkdir_p!(Path.join(mods, "Mods"))
    File.mkdir_p!(Path.join(mods, "Plugins"))
    File.write!(Path.join([mods, "Mods", "TreninoBridge.dll"]), "MZbridge")
    File.write!(Path.join([mods, "Plugins", "TreninoInteropGuard.dll"]), "MZguard")
    File.write!(Path.join(mods, "manifest.json"), ~s({"bridge": "0.3.1", "guard": "1.0.0"}))
    Application.put_env(:trenino, :simrail_mods_dir, mods)

    game = Path.join(tmp_dir, "SimRail")
    File.mkdir_p!(game)
    File.write!(Path.join(game, "SimRail.exe"), "")

    %{game: game}
  end

  defp install_melonloader(game) do
    File.write!(Path.join(game, "version.dll"), "")
    File.mkdir_p!(Path.join(game, "MelonLoader"))
    File.mkdir_p!(Path.join(game, "UserData"))

    File.write!(
      Path.join([game, "UserData", "Loader.cfg"]),
      "[unityengine]\nversion_override = \"\"\nforce_il2cpp_dumper_version = \"\"\n"
    )
  end

  test "starts by asking for the SimRail folder", %{conn: conn} do
    {:ok, view, _} = live(conn, ~p"/settings/simulators/simrail/setup")

    assert has_element?(view, "#step-folder[data-state='current']")
    assert has_element?(view, "#step-connect[data-state='todo']")
  end

  test "rejects a folder without SimRail.exe", %{conn: conn, tmp_dir: tmp_dir} do
    {:ok, view, _} = live(conn, ~p"/settings/simulators/simrail/setup")

    view |> form("#folder-form", folder: %{path: tmp_dir}) |> render_submit()

    assert has_element?(view, "#folder-error", "SimRail.exe")
    assert Settings.simrail_game_dir() == nil
  end

  test "asks for MelonLoader once the folder is chosen", %{conn: conn, game: game} do
    {:ok, view, _} = live(conn, ~p"/settings/simulators/simrail/setup")

    view |> form("#folder-form", folder: %{path: game}) |> render_submit()

    assert Settings.simrail_game_dir() == game
    assert has_element?(view, "#step-folder[data-state='done']", game)
    assert has_element?(view, "#step-melonloader[data-state='current']")
  end

  test "configures MelonLoader, installs the mod and connects", %{conn: conn, game: game} do
    install_melonloader(game)
    {:ok, _} = Settings.set_simrail_game_dir(game)
    {:ok, view, _} = live(conn, ~p"/settings/simulators/simrail/setup")

    assert has_element?(view, "#step-loader[data-state='current']")
    view |> element("#configure-loader") |> render_click()
    assert File.read!(Path.join([game, "UserData", "Loader.cfg"])) =~ "2023.1.8f1"

    assert has_element?(view, "#step-install[data-state='current']")
    view |> element("#install-mods") |> render_click()
    assert File.read!(Path.join([game, "Mods", "TreninoBridge.dll"])) == "MZbridge"

    assert has_element?(view, "#step-connect[data-state='current']")
    expect(Trenino.Simulator.Connection, :reconfigure, fn -> :ok end)
    view |> element("#connect-simrail") |> render_click()
    assert Settings.simulator() == :simrail

    send(
      view.pid,
      {:simulator_status_changed,
       %ConnectionState{
         status: :connected,
         backend: SimRailBackend,
         info: %{"bridge" => "0.3.1", "interopGuard" => true}
       }}
    )

    assert has_element?(view, "#simrail-connected", "TreninoBridge 0.3.1")
    refute has_element?(view, "#interop-guard-warning")
  end

  test "says when this build has no bundled mod", %{conn: conn, game: game} do
    Application.put_env(:trenino, :simrail_mods_dir, Path.join(game, "missing"))
    install_melonloader(game)
    {:ok, _} = Settings.set_simrail_game_dir(game)
    {:ok, view, _} = live(conn, ~p"/settings/simulators/simrail/setup")

    view |> element("#configure-loader") |> render_click()

    assert has_element?(view, "#mods-not-bundled")
    refute has_element?(view, "#install-mods")
  end
end
