defmodule Trenino.CI.InstallerHooksTest do
  use ExUnit.Case, async: true

  @hooks_path Path.join([
                File.cwd!(),
                "tauri",
                "src-tauri",
                "windows",
                "installer-hooks.nsh"
              ])

  test "an incompatible shared vJoy driver warns without aborting Trenino installation" do
    hooks = File.read!(@hooks_path)

    refute hooks =~
             ~s(Abort "A stale or incompatible vJoy ${VJOY_VERSION} installation was detected.)

    refute hooks =~
             ~s(Abort "An existing vJoy driver could not be verified as the supported signed version.)

    assert hooks =~ "Virtual joystick mode will remain unavailable"

    assert hooks =~
             ~s(WriteRegDWORD HKLM "${TRENINO_REGISTRY_KEY}" "VJoyInstalledByTrenino" 0)
  end
end
