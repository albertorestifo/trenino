defmodule Trenino.CI.BurritoPrerequisitesTest do
  use ExUnit.Case, async: true

  @workflows ~w(ci nightly release)

  test "all Burrito workflows use the shared prerequisite action" do
    for workflow <- @workflows do
      contents = File.read!(Path.join([File.cwd!(), ".github", "workflows", "#{workflow}.yml"]))

      assert contents =~ "uses: ./.github/actions/setup-burrito",
             "#{workflow}.yml must use the shared Burrito prerequisite action"

      refute contents =~ "uses: mlugg/setup-zig",
             "#{workflow}.yml must not configure Zig outside the shared action"
    end
  end

  test "Windows CI pins Burrito to the Windows release target" do
    contents = File.read!(Path.join([File.cwd!(), ".github", "workflows", "ci.yml"]))

    assert contents =~
             "      - name: Build Burrito and Tauri package\n        env:\n          BURRITO_TARGET: windows_x86_64\n"
  end

  test "Windows CI installs the pinned Inno Setup extractor" do
    contents = File.read!(Path.join([File.cwd!(), ".github", "workflows", "ci.yml"]))

    assert contents =~
             "choco install innoextract --version 1.9 -y --no-progress"
  end
end
