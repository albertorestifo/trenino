defmodule Trenino.Firmware.AvrdudeConfPathTest do
  use Trenino.SerialSafetyCase, async: true

  alias Trenino.Firmware.Avrdude

  # conf_path/1 only touches files, so it runs the real code instead of the forbidden stub.
  setup do
    stub(Avrdude, :conf_path, fn app_path -> call_original(Avrdude, :conf_path, [app_path]) end)
    :ok
  end

  describe "conf_path/1" do
    @describetag :tmp_dir

    defp write_conf(path) do
      File.mkdir_p!(Path.dirname(path))
      File.write!(path, "avrdude_conf_version = \"8.1\";\n")
      path
    end

    test "finds the Windows Tauri resource under binaries next to the executable",
         %{tmp_dir: dir} do
      conf = write_conf(Path.join([dir, "binaries", "avrdude.conf"]))

      assert Avrdude.conf_path(dir) == {:ok, conf}
    end

    test "finds the macOS Tauri resource in Contents/Resources", %{tmp_dir: dir} do
      macos = Path.join([dir, "Trenino.app", "Contents", "MacOS"])
      File.mkdir_p!(macos)

      conf =
        write_conf(
          Path.join([dir, "Trenino.app", "Contents", "Resources", "binaries", "avrdude.conf"])
        )

      assert Avrdude.conf_path(macos) == {:ok, conf}
    end

    test "finds the Linux package resource in lib/trenino", %{tmp_dir: dir} do
      bin = Path.join([dir, "usr", "bin"])
      File.mkdir_p!(bin)
      conf = write_conf(Path.join([dir, "usr", "lib", "trenino", "binaries", "avrdude.conf"]))

      assert Avrdude.conf_path(bin) == {:ok, conf}
    end

    test "still finds a configuration placed directly next to the executable",
         %{tmp_dir: dir} do
      conf = write_conf(Path.join(dir, "avrdude.conf"))

      assert Avrdude.conf_path(dir) == {:ok, conf}
    end
  end
end
