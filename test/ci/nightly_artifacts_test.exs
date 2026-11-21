defmodule Trenino.CI.NightlyArtifactsTest do
  use ExUnit.Case, async: true

  @workflow_path Path.join([File.cwd!(), ".github", "workflows", "build-desktop.yml"])

  test "nightly build publishes clearly named platform downloads" do
    workflow = File.read!(@workflow_path)

    assert workflow =~ "nightly_artifact: Trenino-nightly-windows-x86_64"
    assert workflow =~ "nightly_artifact: Trenino-nightly-linux-x86_64"
    assert workflow =~ "Trenino-nightly-windows-x86_64-setup.exe"
    assert workflow =~ "Trenino-nightly-windows-x86_64.msi"
    assert workflow =~ "Trenino-nightly-linux-x86_64.AppImage"
    assert workflow =~ "name: ${{ matrix.nightly_artifact }}"
    assert workflow =~ "path: nightly-artifacts/*"
  end
end
