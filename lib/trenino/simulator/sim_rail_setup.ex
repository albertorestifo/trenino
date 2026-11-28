defmodule Trenino.Simulator.SimRailSetup do
  @moduledoc """
  Installs the TreninoBridge mod into a SimRail folder.

  SimRail has no external API, so Trenino talks to it through two MelonLoader
  assemblies that ship with the desktop app (built by
  `.github/workflows/simrail-mods.yml`, see `integrations/simrail/README.md`):

    * `Mods/TreninoBridge.dll`: the bridge API Trenino connects to.
    * `Plugins/TreninoInteropGuard.dll`: keeps MelonLoader's Il2CppInterop from
      hooking the wrong function, which crashes SimRail.

  MelonLoader itself is installed by the player. This module checks a SimRail
  folder, sets the two `UserData/Loader.cfg` keys MelonLoader needs for SimRail
  and copies the bundled assemblies into the game. It only reads and writes
  files: it never starts or stops the game.
  """

  alias Trenino.Settings.Simulator, as: SimulatorSettings

  @bridge "TreninoBridge.dll"
  @guard "TreninoInteropGuard.dll"

  # MelonLoader cannot detect SimRail's Unity version, and older Cpp2IL builds
  # misread the game binary (integrations/simrail/README.md).
  @loader_settings [
    {"version_override", "2023.1.8f1"},
    {"force_il2cpp_dumper_version", "2022.1.0-pre-release.21"}
  ]

  @steam_dirs [
    "C:/Program Files (x86)/Steam",
    "C:/Program Files/Steam"
  ]

  @type mod_state :: :installed | :outdated | :missing
  @type loader_state :: :configured | :needs_update | :missing_keys | :missing_file

  defmodule Bundle do
    @moduledoc "The TreninoBridge assemblies shipped with this build of Trenino."

    @type t :: %__MODULE__{
            dir: Path.t(),
            bridge: Path.t(),
            guard: Path.t(),
            bridge_version: String.t() | nil,
            guard_version: String.t() | nil
          }

    @enforce_keys [:dir, :bridge, :guard]
    defstruct [:dir, :bridge, :guard, :bridge_version, :guard_version]
  end

  defmodule Status do
    @moduledoc "What a SimRail folder has and lacks for TreninoBridge."

    @type t :: %__MODULE__{
            game: boolean(),
            melonloader: boolean(),
            assemblies_generated: boolean(),
            loader: Trenino.Simulator.SimRailSetup.loader_state(),
            bridge: Trenino.Simulator.SimRailSetup.mod_state(),
            guard: Trenino.Simulator.SimRailSetup.mod_state()
          }

    defstruct game: false,
              melonloader: false,
              assemblies_generated: false,
              loader: :missing_file,
              bridge: :missing,
              guard: :missing
  end

  @doc "The MelonLoader settings SimRail needs, as `{key, value}` pairs."
  @spec loader_settings() :: [{String.t(), String.t()}]
  def loader_settings, do: @loader_settings

  @doc """
  The bundled assemblies, or `{:error, :not_bundled}` when this build has none
  (development builds, or a desktop build made without them).

  Looks in `config :trenino, :simrail_mods_dir` when set, then where Tauri
  installs the `resources/simrail` resources relative to `APP_PATH`.
  """
  @spec bundle() :: {:ok, Bundle.t()} | {:error, :not_bundled}
  def bundle do
    dirs =
      case Application.get_env(:trenino, :simrail_mods_dir) do
        nil -> tauri_resource_dirs(System.get_env("APP_PATH"))
        dir -> [dir]
      end

    case Enum.find(dirs, &bundle_dir?/1) do
      nil -> {:error, :not_bundled}
      dir -> {:ok, read_bundle(dir)}
    end
  end

  # Tauri keeps resource paths under the resource directory: the install
  # directory on Windows, Contents/Resources on macOS and /usr/lib/<productName>
  # on Linux packages (see Trenino.Firmware.Avrdude.conf_path/1).
  defp tauri_resource_dirs(nil), do: []
  defp tauri_resource_dirs(""), do: []

  defp tauri_resource_dirs(app_path) do
    [
      Path.join([app_path, "resources", "simrail"]),
      Path.join([app_path, "..", "Resources", "resources", "simrail"]),
      Path.join([app_path, "..", "lib", "trenino", "resources", "simrail"])
    ]
    |> Enum.map(&Path.expand/1)
  end

  defp bundle_dir?(dir) do
    assembly?(Path.join([dir, "Mods", @bridge])) and
      assembly?(Path.join([dir, "Plugins", @guard]))
  end

  # The desktop build bundles empty placeholders when the mods were not built.
  defp assembly?(path) do
    case File.open(path, [:read, :binary], &IO.binread(&1, 2)) do
      {:ok, "MZ"} -> true
      _ -> false
    end
  end

  defp read_bundle(dir) do
    manifest =
      with {:ok, json} <- File.read(Path.join(dir, "manifest.json")),
           {:ok, %{} = map} <- Jason.decode(json) do
        map
      else
        _ -> %{}
      end

    %Bundle{
      dir: dir,
      bridge: Path.join([dir, "Mods", @bridge]),
      guard: Path.join([dir, "Plugins", @guard]),
      bridge_version: version(manifest["bridge"]),
      guard_version: version(manifest["guard"])
    }
  end

  defp version(value) when is_binary(value) and value != "", do: value
  defp version(_value), do: nil

  @doc "Whether `dir` is a SimRail install folder."
  @spec game_dir?(Path.t()) :: boolean()
  def game_dir?(dir) when is_binary(dir), do: File.regular?(Path.join(dir, "SimRail.exe"))

  @doc """
  Finds SimRail in the Steam libraries of this computer. Windows only: returns
  nil elsewhere or when SimRail is not found.
  """
  @spec detect_game_dir() :: Path.t() | nil
  def detect_game_dir do
    if SimulatorSettings.windows?(), do: detect_game_dir(@steam_dirs), else: nil
  end

  @doc false
  @spec detect_game_dir([Path.t()]) :: Path.t() | nil
  def detect_game_dir(steam_dirs) when is_list(steam_dirs) do
    steam_dirs
    |> Enum.flat_map(&steam_libraries/1)
    |> Enum.uniq()
    |> Enum.map(&Path.join([&1, "steamapps", "common", "SimRail"]))
    |> Enum.find(&game_dir?/1)
  end

  # A Steam install is a library itself; libraryfolders.vdf lists the others.
  defp steam_libraries(steam_dir) do
    vdf = Path.join([steam_dir, "steamapps", "libraryfolders.vdf"])

    others =
      case File.read(vdf) do
        {:ok, content} -> library_paths(content)
        {:error, _} -> []
      end

    [steam_dir | others]
  end

  @doc false
  @spec library_paths(String.t()) :: [Path.t()]
  def library_paths(vdf) when is_binary(vdf) do
    ~r/"path"\s+"((?:[^"\\]|\\.)*)"/
    |> Regex.scan(vdf, capture: :all_but_first)
    |> Enum.map(fn [path] -> String.replace(path, "\\\\", "\\") end)
  end

  @doc "Checks `dir` against the bundle (or, without one, only for presence)."
  @spec status(Path.t(), Bundle.t() | nil) :: Status.t()
  def status(dir, bundle \\ nil) when is_binary(dir) do
    %Status{
      game: game_dir?(dir),
      melonloader:
        File.regular?(Path.join(dir, "version.dll")) and
          File.dir?(Path.join(dir, "MelonLoader")),
      assemblies_generated:
        File.regular?(Path.join([dir, "MelonLoader", "Il2CppAssemblies", "Assembly-CSharp.dll"])),
      loader: loader_state(dir),
      bridge: mod_state(Path.join([dir, "Mods", @bridge]), bundle && bundle.bridge),
      guard: mod_state(Path.join([dir, "Plugins", @guard]), bundle && bundle.guard)
    }
  end

  @doc "Whether everything is in place for the bridge to run."
  @spec ready?(Status.t()) :: boolean()
  def ready?(%Status{} = status) do
    status.game and status.melonloader and status.loader == :configured and
      status.bridge == :installed and status.guard == :installed
  end

  defp mod_state(installed, bundled) do
    cond do
      not File.regular?(installed) -> :missing
      is_nil(bundled) -> :installed
      same_file?(installed, bundled) -> :installed
      true -> :outdated
    end
  end

  defp same_file?(a, b) do
    with {:ok, a_bin} <- File.read(a), {:ok, b_bin} <- File.read(b) do
      a_bin == b_bin
    else
      _ -> false
    end
  end

  defp loader_path(dir), do: Path.join([dir, "UserData", "Loader.cfg"])

  defp loader_state(dir) do
    case File.read(loader_path(dir)) do
      {:ok, content} -> loader_content_state(content)
      {:error, _} -> :missing_file
    end
  end

  defp loader_content_state(content) do
    values =
      Enum.map(@loader_settings, fn {key, value} -> {current_value(content, key), value} end)

    cond do
      Enum.any?(values, fn {current, _} -> is_nil(current) end) -> :missing_keys
      Enum.all?(values, fn {current, wanted} -> current == wanted end) -> :configured
      true -> :needs_update
    end
  end

  defp key_regex(key), do: ~r/^([ \t]*#{Regex.escape(key)}[ \t]*=[ \t]*)(.*?)[ \t]*(\r?)$/m

  defp current_value(content, key) do
    case Regex.run(key_regex(key), content, capture: :all_but_first) do
      [_prefix, raw, _cr] -> raw |> String.trim() |> String.trim("\"")
      nil -> nil
    end
  end

  @doc """
  Sets the SimRail keys in `UserData/Loader.cfg`, keeping everything else.

  MelonLoader writes that file on its first start, so it must exist: returns
  `{:error, :missing_file}` before then, and `{:error, :missing_keys}` when the
  MelonLoader version writes a file without those keys.
  """
  @spec configure_loader(Path.t()) :: :ok | {:error, :missing_file | :missing_keys | term()}
  def configure_loader(dir) when is_binary(dir) do
    path = loader_path(dir)

    with {:ok, content} <- read_loader(path),
         :ok <- require_keys(content) do
      updated =
        Enum.reduce(@loader_settings, content, fn {key, value}, acc ->
          Regex.replace(key_regex(key), acc, "\\1\"#{value}\"\\3", global: false)
        end)

      if updated == content, do: :ok, else: File.write(path, updated)
    end
  end

  defp read_loader(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, :enoent} -> {:error, :missing_file}
      {:error, reason} -> {:error, reason}
    end
  end

  defp require_keys(content) do
    if Enum.all?(@loader_settings, fn {key, _} -> current_value(content, key) end),
      do: :ok,
      else: {:error, :missing_keys}
  end

  @doc """
  Copies the bundled assemblies into `dir` (`Mods/` and `Plugins/`).

  Windows locks the files while SimRail runs, so an install over a running
  game fails with `{:error, {:copy_failed, file, reason}}`.
  """
  @spec install(Path.t(), Bundle.t()) ::
          :ok | {:error, :not_game_dir | {:copy_failed, String.t(), term()}}
  def install(dir, %Bundle{} = bundle) when is_binary(dir) do
    if game_dir?(dir) do
      with :ok <- copy(bundle.guard, Path.join(dir, "Plugins")) do
        copy(bundle.bridge, Path.join(dir, "Mods"))
      end
    else
      {:error, :not_game_dir}
    end
  end

  defp copy(source, target_dir) do
    target = Path.join(target_dir, Path.basename(source))

    with :ok <- File.mkdir_p(target_dir),
         {:ok, _bytes} <- File.copy(source, target) do
      :ok
    else
      {:error, reason} -> {:error, {:copy_failed, Path.basename(source), reason}}
    end
  end
end
