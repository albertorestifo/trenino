defmodule Trenino.CI.BuildDesktopScriptTest do
  use ExUnit.Case, async: true

  test "Windows vJoy SDK extraction uses path-safe 7-Zip" do
    contents = File.read!(Path.join([File.cwd!(), "scripts", "build-desktop.sh"]))

    refute contents =~ "Expand-Archive"
    assert contents =~ "mkdir -p \"$VJOY_STAGE/sdk\""
    assert contents =~ "7z x -y -o\"$VJOY_STAGE/sdk\" \"$RESOURCES_DIR/SDK.zip\" >/dev/null"
  end

  test "Windows vJoy installer extraction uses innoextract's known config path" do
    contents = File.read!(Path.join([File.cwd!(), "scripts", "build-desktop.sh"]))

    refute contents =~ "7z x -y -o\"$VJOY_STAGE/installer\" \"$RESOURCES_DIR/vJoySetup.exe\""

    assert contents =~
             "innoextract --silent --extract --output-dir \"$VJOY_STAGE/installer\" \"$RESOURCES_DIR/vJoySetup.exe\""

    assert contents =~ "VJOY_CONFIG=\"$VJOY_STAGE/installer/app/x64/vJoyConfig.exe\""
    assert contents =~ "[ ! -f \"$VJOY_CONFIG\" ]"
    assert contents =~ "cp \"$VJOY_CONFIG\" \"$RESOURCES_DIR/vJoyConfig.exe\""
  end
end
