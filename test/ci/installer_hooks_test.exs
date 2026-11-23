defmodule Trenino.CI.InstallerHooksTest do
  use ExUnit.Case, async: true

  @hooks_path Path.join([
                File.cwd!(),
                "tauri",
                "src-tauri",
                "windows",
                "installer-hooks.nsh"
              ])

  test "installation installs the bundled Visual C++ Redistributable" do
    post_install = macro_body(File.read!(@hooks_path), "NSIS_HOOK_POSTINSTALL")

    assert post_install =~ "vc_redist.x64.exe"
  end

  defp macro_body(hooks, name) do
    [_, rest] = String.split(hooks, "!macro #{name}\n", parts: 2)
    [body, _] = String.split(rest, "!macroend", parts: 2)
    body
  end
end
