defmodule Trenino.CI.VirtualJoystickWorkflowTest do
  use ExUnit.Case, async: true

  @build_workflow Path.join([File.cwd!(), ".github", "workflows", "build-desktop.yml"])

  test "nightly and release both build through the shared desktop workflow" do
    for workflow <- ~w(nightly release) do
      contents = File.read!(Path.join([File.cwd!(), ".github", "workflows", "#{workflow}.yml"]))

      assert contents =~ "uses: ./.github/workflows/build-desktop.yml",
             "#{workflow}.yml must build through build-desktop.yml"

      assert contents =~ "channel: #{workflow}",
             "#{workflow}.yml must pass its channel to build-desktop.yml"
    end
  end

  test "the desktop build compiles and stages the Windows virtual joystick sidecar" do
    contents = File.read!(@build_workflow)

    assert contents =~
             ~r/- name: Build virtual joystick utility\n\s+if: runner\.os == 'Windows'\n\s+run: cargo build --release --manifest-path tauri\/virtual_joystick\/Cargo\.toml/

    assert contents =~
             ~s|cp "tauri/virtual_joystick/target/release/virtual_joystick$EXT" "$bin/virtual_joystick-$TRIPLE$EXT"|
  end

  test "the desktop build stages verified Windows vJoy runtime resources" do
    contents = File.read!(@build_workflow)

    assert contents =~ "choco install innoextract --version 1.9 -y --no-progress"
    assert contents =~ "./scripts/stage-vjoy-resources.ps1"
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
    assert contents =~ "'app/x64/vJoyInstall.dll'"
    assert contents =~ "'vJoyInstall.dll'"
    assert contents =~ "'vJoy-LICENSE.txt'"
  end
end
