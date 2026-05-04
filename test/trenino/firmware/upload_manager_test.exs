defmodule Trenino.Firmware.UploadManagerTest do
  @moduledoc """
  Tests for UploadManager focusing on cancel/timeout correctly terminating
  the avrdude subprocess. Uses async: false because UploadManager and
  Connection are global GenServers.
  """

  use Trenino.DataCase, async: false

  alias Trenino.Firmware
  alias Trenino.Firmware.{AvrdudeRunner, FilePath, UploadManager}
  alias Trenino.Serial.Connection

  setup :set_mimic_global

  setup do
    stub(Circuits.UART, :enumerate, fn -> %{} end)
    stub(Trenino.Firmware.Avrdude, :executable_path, fn -> {:ok, "/fake/avrdude"} end)
    stub(Trenino.Firmware.Avrdude, :conf_path, fn -> {:error, :not_found} end)
    load_test_devices()

    # Create a firmware release and file in the DB
    {:ok, release} =
      Firmware.create_release(%{
        version: "99.0.0",
        tag_name: "v99.0.0",
        published_at: DateTime.utc_now()
      })

    {:ok, firmware_file} =
      Firmware.create_firmware_file(release.id, %{
        board_type: "uno",
        environment: "uno",
        download_url: "https://example.com/firmware.hex",
        file_size: 100
      })

    # Write a real hex file at the expected path
    hex_path = FilePath.firmware_path("99.0.0", "uno")
    File.mkdir_p!(Path.dirname(hex_path))
    File.write!(hex_path, ":00000001FF\n")

    on_exit(fn -> File.rm(hex_path) end)

    {:ok, release: release, firmware_file: firmware_file, hex_path: hex_path}
  end

  describe "cancel_upload/1" do
    test "kills the avrdude task process", %{firmware_file: firmware_file} do
      test_pid = self()

      stub(AvrdudeRunner, :run, fn _path, _args, _cb ->
        # Report the task pid so the test can assert it's killed
        send(test_pid, {:avrdude_task_pid, self()})

        # Block indefinitely — simulates a long-running avrdude
        receive do
          :never -> :ok
        end
      end)

      port = "/dev/tty.upload-cancel-test"
      UploadManager.subscribe_uploads()

      assert {:ok, upload_id} = UploadManager.start_upload(port, "uno", firmware_file.id)

      # Wait for the avrdude task to actually start running
      assert_receive {:avrdude_task_pid, task_pid}, 2_000
      assert Process.alive?(task_pid)

      # Cancel the upload
      assert :ok = UploadManager.cancel_upload(upload_id)

      # avrdude task must be dead — the OS port linked to it is killed too
      ref = Process.monitor(task_pid)
      assert_receive {:DOWN, ^ref, :process, ^task_pid, _reason}, 1_000

      # PubSub must have broadcast the cancellation
      assert_receive {:upload_failed, ^upload_id, :cancelled, _message}

      # Port must be released (no longer in :uploading state)
      devices = Connection.list_devices()
      uploading = Enum.find(devices, &(&1.port == port and &1.status == :uploading))
      assert uploading == nil
    end

    test "upload timeout kills the avrdude task", %{firmware_file: firmware_file} do
      test_pid = self()

      stub(AvrdudeRunner, :run, fn _path, _args, _cb ->
        send(test_pid, {:avrdude_task_pid, self()})

        receive do
          :never -> :ok
        end
      end)

      UploadManager.subscribe_uploads()

      port = "/dev/tty.upload-timeout-test"
      assert {:ok, upload_id} = UploadManager.start_upload(port, "uno", firmware_file.id)

      assert_receive {:avrdude_task_pid, task_pid}, 2_000
      assert Process.alive?(task_pid)

      # Inject a timeout message directly (avoids waiting 120s for the real timer)
      send(Process.whereis(UploadManager), {:upload_timeout, upload_id})

      # Task must be killed by the timeout handler
      ref = Process.monitor(task_pid)
      assert_receive {:DOWN, ^ref, :process, ^task_pid, _reason}, 1_000

      assert_receive {:upload_failed, ^upload_id, :timeout, _message}
    end
  end
end
