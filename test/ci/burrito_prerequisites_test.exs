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
end
