defmodule Trenino.Firmware.UploadFlowTest do
  use Trenino.DataCase, async: false

  import Mimic

  alias Trenino.AvrdudeFixtures
  alias Trenino.Firmware.Avrdude
  alias Trenino.Firmware.AvrdudeRunner
  alias Trenino.Firmware.Uploader

  setup do
    load_test_devices()

    hex_file =
      Path.join(System.tmp_dir!(), "test_firmware_#{System.unique_integer([:positive])}.hex")

    File.write!(hex_file, ":00000001FF\n")
    on_exit(fn -> File.rm(hex_file) end)

    stub(Avrdude, :executable_path, fn -> {:ok, "/fake/avrdude"} end)

    {:ok, hex_file: hex_file}
  end

  describe "successful upload" do
    test "returns ok with duration and output", %{hex_file: hex_file} do
      stub(AvrdudeRunner, :run, fn _path, _args, _cb ->
        {:ok, AvrdudeFixtures.successful_upload()}
      end)

      assert {:ok, %{duration_ms: duration, output: output}} =
               Uploader.upload("COM3", "uno", hex_file)

      assert is_integer(duration) and duration >= 0
      assert output =~ "avrdude done"
    end
  end

  describe "non-retrying errors" do
    test "returns :wrong_board_type immediately on device signature mismatch", %{
      hex_file: hex_file
    } do
      stub(AvrdudeRunner, :run, fn _path, _args, _cb ->
        {:error, AvrdudeFixtures.device_signature_mismatch()}
      end)

      assert {:error, :wrong_board_type, output} = Uploader.upload("COM3", "uno", hex_file)
      assert output =~ "device signature"
    end

    test "returns :permission_denied immediately without retry", %{hex_file: hex_file} do
      stub(AvrdudeRunner, :run, fn _path, _args, _cb ->
        {:error, AvrdudeFixtures.permission_denied()}
      end)

      assert {:error, :permission_denied, _output} = Uploader.upload("COM3", "uno", hex_file)
    end

    test "returns :verification_failed immediately without retry", %{hex_file: hex_file} do
      stub(AvrdudeRunner, :run, fn _path, _args, _cb ->
        {:error, AvrdudeFixtures.verification_error()}
      end)

      assert {:error, :verification_failed, _output} = Uploader.upload("COM3", "uno", hex_file)
    end

    test "returns :hex_file_not_found when hex file does not exist" do
      assert {:error, :hex_file_not_found, message} =
               Uploader.upload("COM3", "uno", "/nonexistent/firmware.hex")

      assert message =~ "not found"
    end

    test "returns :unknown_device for unrecognised environment", %{hex_file: hex_file} do
      assert {:error, :unknown_device, message} =
               Uploader.upload("COM3", "totally_unknown_board", hex_file)

      assert message =~ "Unknown device environment"
    end
  end

  describe "baud-rate retry (old-bootloader Nano)" do
    test "retries at 57600 when 115200 fails with not-in-sync", %{hex_file: hex_file} do
      stub(AvrdudeRunner, :run, fn _path, args, _cb ->
        baud = Enum.at(args, Enum.find_index(args, &(&1 == "-b")) + 1)

        if baud == "115200" do
          {:error, AvrdudeFixtures.old_bootloader_nano_115200_fail()}
        else
          {:ok, AvrdudeFixtures.successful_upload()}
        end
      end)

      assert {:ok, %{duration_ms: _, output: _}} =
               Uploader.upload("COM3", "nanoatmega328", hex_file)
    end

    test "returns :bootloader_not_responding when all baud rates fail", %{hex_file: hex_file} do
      stub(AvrdudeRunner, :run, fn _path, _args, _cb ->
        {:error, AvrdudeFixtures.old_bootloader_nano_115200_fail()}
      end)

      assert {:error, :bootloader_not_responding, _} =
               Uploader.upload("COM3", "nanoatmega328", hex_file)
    end
  end
end
