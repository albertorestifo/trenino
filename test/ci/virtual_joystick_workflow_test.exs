defmodule Trenino.CI.VirtualJoystickWorkflowTest do
  use ExUnit.Case, async: true

  @workflows ~w(nightly release)

  test "nightly and release build and stage target-specific virtual joystick sidecars" do
    for workflow <- @workflows do
      contents = File.read!(Path.join([File.cwd!(), ".github", "workflows", "#{workflow}.yml"]))

      assert contents =~ "  build-virtual-joystick:\n",
             "#{workflow}.yml must define the virtual joystick build job"

      assert contents =~
               ~r/  build-tauri:\n(?:.*\n)*?    needs: \[[^\]]*build-virtual-joystick[^\]]*\]/,
             "#{workflow}.yml build-tauri must depend on build-virtual-joystick"

      assert contents =~ "name: virtual-joystick-${{ matrix.target }}",
             "#{workflow}.yml must download the target-specific virtual joystick artifact"

      assert contents =~
               "virtual_joystick-${{ matrix.tauri_target }}.exe",
             "#{workflow}.yml must stage the Windows virtual joystick sidecar"

      assert contents =~
               ~r/virtual_joystick-\$\{\{ matrix\.tauri_target \}\}(?!\.exe)/,
             "#{workflow}.yml must stage the Unix virtual joystick sidecar without .exe"

      assert contents =~
               "chmod +x \"tauri/src-tauri/binaries/virtual_joystick-${{ matrix.tauri_target }}\"",
             "#{workflow}.yml must make the Unix virtual joystick sidecar executable"

      assert contents =~ "virtual-joystick-download",
             "#{workflow}.yml must use and clean up a virtual joystick staging directory"
    end
  end
end
