defmodule Trenino.CI.InstallerHooksTest do
  use ExUnit.Case, async: true

  @hooks_path Path.join([
                File.cwd!(),
                "tauri",
                "src-tauri",
                "windows",
                "installer-hooks.nsh"
              ])

  test "installation never installs or claims the vJoy driver" do
    post_install = macro_body(File.read!(@hooks_path), "NSIS_HOOK_POSTINSTALL")

    refute post_install =~ "vJoySetup.exe"
    refute post_install =~ "vJoyConfig.exe"
    refute post_install =~ "VJoyInstalledByTrenino"
    assert post_install =~ "vc_redist.x64.exe"
  end

  test "uninstall only offers driver removal when an earlier release installed it" do
    pre_uninstall = macro_body(File.read!(@hooks_path), "NSIS_HOOK_PREUNINSTALL")

    assert pre_uninstall =~
             ~s(ReadRegDWORD $0 HKLM "${TRENINO_REGISTRY_KEY}" "VJoyInstalledByTrenino")

    assert pre_uninstall =~ "vJoy was not installed by Trenino; retaining the shared driver."

    assert pre_uninstall =~
             ~s(ReadRegDWORD $4 HKCU "${TRENINO_REGISTRY_KEY}" "${VJOY_DEVICE_MARKER}")
  end

  defp macro_body(hooks, name) do
    [_, rest] = String.split(hooks, "!macro #{name}\n", parts: 2)
    [body, _] = String.split(rest, "!macroend", parts: 2)
    body
  end
end
