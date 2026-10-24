defmodule Trenino.VirtualJoystick.InstalledHelpersTest do
  use ExUnit.Case, async: false
  alias Trenino.VirtualJoystick.Configurator.SystemAdapter

  setup do
    previous = System.get_env("APP_PATH")

    root =
      Path.expand(
        Path.join(System.tmp_dir!(), "trenino-installed-#{System.unique_integer([:positive])}")
      )

    File.mkdir_p!(Path.join(root, "resources"))

    on_exit(fn ->
      if previous, do: System.put_env("APP_PATH", previous), else: System.delete_env("APP_PATH")
      File.rm_rf!(root)
    end)

    %{root: root}
  end

  test "finds installed helpers outside the extracted backend", %{root: root} do
    config = Path.join([root, "resources", "vJoyConfig.exe"])
    interface = Path.join([root, "resources", "vJoyInterface.dll"])
    File.write!(config, "fixture")
    File.write!(interface, "fixture")
    System.put_env("APP_PATH", root)
    assert SystemAdapter.configurator_path() == {:ok, config}
    assert SystemAdapter.interface_path() == {:ok, interface}
  end

  test "does not trust executables at the installation root", %{root: root} do
    path = Path.join(root, "vJoyConfig.exe")
    File.write!(path, "fixture")
    System.put_env("APP_PATH", root)
    assert SystemAdapter.elevate(path, []) == {:error, :untrusted_configurator}
  end
end
