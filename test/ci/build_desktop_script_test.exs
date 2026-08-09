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

  test "Windows backend sidecar is staged with an executable suffix" do
    binaries_dir = stage_backend_for("MINGW64_NT-10.0")

    assert File.read!(Path.join(binaries_dir, "trenino_backend-x86_64-pc-windows-msvc.exe")) ==
             "backend"

    refute File.exists?(Path.join(binaries_dir, "trenino_backend-x86_64-pc-windows-msvc"))
  end

  test "Windows avrdude sidecar and configuration are staged before Tauri builds" do
    binaries_dir = stage_backend_for("MINGW64_NT-10.0")

    assert File.read!(Path.join(binaries_dir, "avrdude-x86_64-pc-windows-msvc.exe")) ==
             "avrdude"

    assert File.read!(Path.join(binaries_dir, "avrdude.conf")) == "configuration"
  end

  test "Windows avrdude download is version-pinned and checksum-verified" do
    contents = File.read!(Path.join([File.cwd!(), "scripts", "build-desktop.sh"]))
    downloader = File.read!(Path.join([File.cwd!(), "scripts", "download-avrdude.ps1"]))

    assert contents =~ ~s(AVRDUDE_VERSION="8.1")

    assert contents =~
             ~s(AVRDUDE_WINDOWS_X64_SHA256="e4d571d81fee3387d51bfdedd0b6565e4c201e974101cac2caec7adfd6201da3")

    assert contents =~ "scripts/download-avrdude.ps1"
    assert downloader =~ "Get-FileHash -LiteralPath $archive -Algorithm SHA256"
    assert downloader =~ ~s("avrdude-$TargetTriple.exe")
    assert downloader =~ "Join-Path $destination 'avrdude.conf'"
  end

  test "Unix backend sidecar is staged without an executable suffix" do
    binaries_dir = stage_backend_for("Linux")

    assert File.read!(Path.join(binaries_dir, "trenino_backend-x86_64-unknown-linux-gnu")) ==
             "backend"

    refute File.exists?(Path.join(binaries_dir, "trenino_backend-x86_64-unknown-linux-gnu.exe"))
  end

  defp stage_backend_for(uname_s) do
    project_dir =
      Path.join(System.tmp_dir!(), "trenino-build-desktop-#{System.unique_integer([:positive])}")

    on_exit(fn -> File.rm_rf!(project_dir) end)

    File.mkdir_p!(Path.join(project_dir, "scripts"))
    File.mkdir_p!(Path.join(project_dir, "burrito_out"))
    File.mkdir_p!(Path.join(project_dir, "tauri/keystroke"))
    File.mkdir_p!(Path.join(project_dir, "test-bin"))

    script = Path.join(project_dir, "scripts/build-desktop.sh")
    File.cp!(Path.join(File.cwd!(), "scripts/build-desktop.sh"), script)
    File.write!(Path.join(project_dir, "burrito_out/trenino_desktop_test"), "backend")

    write_executable!(Path.join(project_dir, "test-bin/mix"), "#!/bin/sh\nexit 0\n")
    write_executable!(Path.join(project_dir, "test-bin/cargo"), "#!/bin/sh\nexit 42\n")

    write_executable!(
      Path.join(project_dir, "test-bin/powershell.exe"),
      "#!/bin/sh\nmkdir -p \"$TEST_PROJECT_DIR/tauri/src-tauri/binaries\"\nprintf avrdude > \"$TEST_PROJECT_DIR/tauri/src-tauri/binaries/avrdude-x86_64-pc-windows-msvc.exe\"\nprintf configuration > \"$TEST_PROJECT_DIR/tauri/src-tauri/binaries/avrdude.conf\"\n"
    )

    write_executable!(
      Path.join(project_dir, "test-bin/uname"),
      "#!/bin/sh\nif [ \"$1\" = \"-s\" ]; then echo \"$TEST_UNAME_S\"; else echo x86_64; fi\n"
    )

    path = Path.join(project_dir, "test-bin") <> ":" <> System.fetch_env!("PATH")

    {output, status} =
      System.cmd("/bin/bash", [script],
        env: [
          {"PATH", path},
          {"TEST_UNAME_S", uname_s},
          {"TEST_PROJECT_DIR", project_dir}
        ],
        stderr_to_stdout: true
      )

    assert status == 42
    assert output =~ "==> Building keystroke utility..."

    Path.join(project_dir, "tauri/src-tauri/binaries")
  end

  defp write_executable!(path, contents) do
    File.write!(path, contents)
    File.chmod!(path, 0o755)
  end
end
