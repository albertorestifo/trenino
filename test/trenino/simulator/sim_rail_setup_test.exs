defmodule Trenino.Simulator.SimRailSetupTest do
  # bundle/0 reads the :simrail_mods_dir application env.
  use Trenino.DataCase, async: false

  alias Trenino.Simulator.SimRailSetup
  alias Trenino.Simulator.SimRailSetup.Bundle
  alias Trenino.Simulator.SimRailSetup.Status

  @moduletag :tmp_dir

  @loader_cfg """
  [loader]
  debug_mode = false

  [unityengine]
  version_override = ""
  force_il2cpp_dumper_version = ""\r
  disable_console_cleaner = false
  """

  setup %{tmp_dir: tmp_dir} do
    previous = Application.get_env(:trenino, :simrail_mods_dir)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:trenino, :simrail_mods_dir, previous),
        else: Application.delete_env(:trenino, :simrail_mods_dir)
    end)

    game = Path.join(tmp_dir, "SimRail")
    File.mkdir_p!(game)
    File.write!(Path.join(game, "SimRail.exe"), "")
    %{game: game, mods: Path.join(tmp_dir, "bundle")}
  end

  defp write_bundle(dir, bridge \\ "MZbridge", guard \\ "MZguard") do
    File.mkdir_p!(Path.join(dir, "Mods"))
    File.mkdir_p!(Path.join(dir, "Plugins"))
    File.write!(Path.join([dir, "Mods", "TreninoBridge.dll"]), bridge)
    File.write!(Path.join([dir, "Plugins", "TreninoInteropGuard.dll"]), guard)
    File.write!(Path.join(dir, "manifest.json"), ~s({"bridge": "0.3.1", "guard": "1.0.0"}))
    Application.put_env(:trenino, :simrail_mods_dir, dir)
  end

  defp install_melonloader(game) do
    File.write!(Path.join(game, "version.dll"), "")
    File.mkdir_p!(Path.join(game, "MelonLoader"))
  end

  describe "bundle/0" do
    test "reads the bundled assemblies and their versions", %{mods: mods} do
      write_bundle(mods)

      assert {:ok, %Bundle{bridge_version: "0.3.1", guard_version: "1.0.0"} = bundle} =
               SimRailSetup.bundle()

      assert bundle.bridge == Path.join([mods, "Mods", "TreninoBridge.dll"])
    end

    test "treats empty placeholders as not bundled", %{mods: mods} do
      write_bundle(mods, "", "")
      assert {:error, :not_bundled} = SimRailSetup.bundle()
    end
  end

  describe "library_paths/1" do
    test "reads the library folders Steam lists" do
      vdf = """
      "libraryfolders"
      {
        "0"
        {
          "path"    "C:\\\\Program Files (x86)\\\\Steam"
        }
        "1"
        {
          "path"    "D:\\\\SteamLibrary"
        }
      }
      """

      assert SimRailSetup.library_paths(vdf) == [
               "C:\\Program Files (x86)\\Steam",
               "D:\\SteamLibrary"
             ]
    end
  end

  describe "detect_game_dir/1" do
    test "finds SimRail in a library listed by Steam", %{tmp_dir: tmp_dir} do
      steam = Path.join(tmp_dir, "Steam")
      library = Path.join(tmp_dir, "Library")
      game = Path.join([library, "steamapps", "common", "SimRail"])
      File.mkdir_p!(game)
      File.write!(Path.join(game, "SimRail.exe"), "")
      File.mkdir_p!(Path.join(steam, "steamapps"))

      File.write!(
        Path.join([steam, "steamapps", "libraryfolders.vdf"]),
        ~s("libraryfolders" { "1" { "path" "#{library}" } })
      )

      assert SimRailSetup.detect_game_dir([steam]) == game
    end

    test "returns nil without SimRail", %{tmp_dir: tmp_dir} do
      assert SimRailSetup.detect_game_dir([Path.join(tmp_dir, "nowhere")]) == nil
    end
  end

  describe "status/2" do
    test "a bare game folder needs everything", %{game: game} do
      assert %Status{
               game: true,
               melonloader: false,
               loader: :missing_file,
               bridge: :missing,
               guard: :missing
             } = status = SimRailSetup.status(game)

      refute SimRailSetup.ready?(status)
    end

    test "a folder without SimRail.exe is not the game", %{tmp_dir: tmp_dir} do
      refute SimRailSetup.status(tmp_dir).game
    end

    test "detects MelonLoader and an unconfigured Loader.cfg", %{game: game} do
      install_melonloader(game)
      File.mkdir_p!(Path.join(game, "UserData"))
      File.write!(Path.join([game, "UserData", "Loader.cfg"]), @loader_cfg)

      assert %Status{melonloader: true, loader: :needs_update} = SimRailSetup.status(game)
    end

    test "is ready once configured and installed", %{game: game, mods: mods} do
      write_bundle(mods)
      {:ok, bundle} = SimRailSetup.bundle()
      install_melonloader(game)
      File.mkdir_p!(Path.join(game, "UserData"))
      File.write!(Path.join([game, "UserData", "Loader.cfg"]), @loader_cfg)

      :ok = SimRailSetup.configure_loader(game)
      :ok = SimRailSetup.install(game, bundle)

      status = SimRailSetup.status(game, bundle)
      assert %Status{loader: :configured, bridge: :installed, guard: :installed} = status
      assert SimRailSetup.ready?(status)
    end

    test "reports an installed mod that differs from the bundle as outdated", %{
      game: game,
      mods: mods
    } do
      write_bundle(mods)
      {:ok, bundle} = SimRailSetup.bundle()
      File.mkdir_p!(Path.join(game, "Mods"))
      File.write!(Path.join([game, "Mods", "TreninoBridge.dll"]), "MZold")

      assert %Status{bridge: :outdated, guard: :missing} = SimRailSetup.status(game, bundle)
    end
  end

  describe "configure_loader/1" do
    test "sets the SimRail keys and keeps the rest of the file", %{game: game} do
      File.mkdir_p!(Path.join(game, "UserData"))
      path = Path.join([game, "UserData", "Loader.cfg"])
      File.write!(path, @loader_cfg)

      assert :ok = SimRailSetup.configure_loader(game)
      content = File.read!(path)

      assert content =~ ~s(version_override = "2023.1.8f1"\n)
      assert content =~ ~s(force_il2cpp_dumper_version = "2022.1.0-pre-release.21"\r\n)
      assert content =~ "debug_mode = false"
      assert content =~ "disable_console_cleaner = false"
    end

    test "needs MelonLoader to have written the file", %{game: game} do
      assert {:error, :missing_file} = SimRailSetup.configure_loader(game)
    end

    test "does not add keys the file lacks", %{game: game} do
      File.mkdir_p!(Path.join(game, "UserData"))
      File.write!(Path.join([game, "UserData", "Loader.cfg"]), "[loader]\ndebug_mode = false\n")

      assert {:error, :missing_keys} = SimRailSetup.configure_loader(game)
    end
  end

  describe "install/2" do
    test "copies the assemblies into Mods and Plugins", %{game: game, mods: mods} do
      write_bundle(mods)
      {:ok, bundle} = SimRailSetup.bundle()

      assert :ok = SimRailSetup.install(game, bundle)
      assert File.read!(Path.join([game, "Mods", "TreninoBridge.dll"])) == "MZbridge"
      assert File.read!(Path.join([game, "Plugins", "TreninoInteropGuard.dll"])) == "MZguard"
    end

    test "refuses a folder that is not SimRail", %{tmp_dir: tmp_dir, mods: mods} do
      write_bundle(mods)
      {:ok, bundle} = SimRailSetup.bundle()

      assert {:error, :not_game_dir} = SimRailSetup.install(tmp_dir, bundle)
    end
  end
end
