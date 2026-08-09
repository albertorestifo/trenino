defmodule Trenino.CI.BuildDesktopScriptTest do
  use ExUnit.Case, async: true

  test "Windows vJoy SDK extraction uses path-safe 7-Zip" do
    contents = File.read!(Path.join([File.cwd!(), "scripts", "build-desktop.sh"]))

    refute contents =~ "Expand-Archive"
    assert contents =~ "mkdir -p \"$VJOY_STAGE/sdk\""
    assert contents =~ "7z x -y -o\"$VJOY_STAGE/sdk\" \"$RESOURCES_DIR/SDK.zip\" >/dev/null"
  end
end
