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

  test "nightly and release stage verified Windows vJoy runtime resources" do
    for workflow <- @workflows do
      contents = File.read!(Path.join([File.cwd!(), ".github", "workflows", "#{workflow}.yml"]))

      assert contents =~ "choco install innoextract --version 1.9 -y --no-progress",
             "#{workflow}.yml must install the pinned vJoy installer extractor"

      assert contents =~ "./scripts/stage-vjoy-resources.ps1",
             "#{workflow}.yml must stage the verified vJoy resources before Tauri builds"
    end
  end

  test "shared vJoy staging verifies pinned inputs and creates every packaged resource" do
    contents = File.read!(Path.join([File.cwd!(), "scripts", "stage-vjoy-resources.ps1"]))

    assert contents =~ "$version = '2.2.2.0'"
    assert contents =~ "ef569a3105cd301b89580f18f60c66b339e95296acf2c0dfcaf4b4bbf8ab68fe"
    assert contents =~ "0e796b185b66819d5fbeae645f3f038ecbfbbde837d3d3f06cba82ae1db07c67"
    assert contents =~ "7f0ed151caab68bbfd1a37727c8fe75c94be45aff98a88d63bc7e46e3fb0c5e1"
    assert contents =~ "Get-AuthenticodeSignature"
    assert contents =~ "SignerCertificate.Subject -notmatch 'BRUNNER'"
    assert contents =~ "'vJoyInterface.dll'"
    assert contents =~ "'vJoyConfig.exe'"
    assert contents =~ "'vJoy-LICENSE.txt'"
  end
end
