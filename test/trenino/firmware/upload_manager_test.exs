defmodule Trenino.Firmware.UploadManagerTest do
  @moduledoc """
  Tests for UploadManager focusing on cancel/timeout correctly terminating
  the avrdude subprocess. Uses async: false because UploadManager and
  Connection are global GenServers.
  """

  use Trenino.DataCase, async: false

  alias Trenino.AvrdudeFixtures
  alias Trenino.Firmware
  alias Trenino.Firmware.{AvrdudeRunner, FilePath, UploadManager}
  alias Trenino.Serial.Connection

  setup :set_mimic_global

  setup do
    stub(Circuits.UART, :enumerate, fn -> %{} end)
    start_supervised!(Connection)
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

  describe "start_upload/3 when the serial port stops answering" do
    test "returns the error and keeps the manager running", %{firmware_file: firmware_file} do
      manager_pid = Process.whereis(UploadManager)
      stub(Connection, :request_upload_access, fn "COM3" -> {:error, :port_timed_out} end)

      assert {:error, :port_timed_out} =
               UploadManager.start_upload("COM3", "uno", firmware_file.id)

      assert Process.whereis(UploadManager) == manager_pid
      assert UploadManager.current_upload() == nil
    end

    # Connection.request_upload_access can take its whole 5s call timeout
    # before the manager does its own work, so the caller must not give up
    # first while the upload starts anyway. This test is slow by design.
    @tag timeout: 20_000
    test "waits for a slow port grant instead of timing out", %{firmware_file: firmware_file} do
      port = "/dev/tty.upload-slow-grant"
      UploadManager.subscribe_uploads()

      # Leave no upload running for the next test if this one fails.
      on_exit(fn ->
        with %{upload_id: id} <- UploadManager.current_upload(),
             do: UploadManager.cancel_upload(id)
      end)

      stub(Connection, :request_upload_access, fn ^port ->
        # Simulates a busy Connection; not a synchronization point.
        receive do
        after
          5_200 -> Mimic.call_original(Connection, :request_upload_access, [port])
        end
      end)

      stub(AvrdudeRunner, :run, fn _path, _args, _cb ->
        {:ok, AvrdudeFixtures.successful_upload()}
      end)

      assert {:ok, upload_id} = UploadManager.start_upload(port, "uno", firmware_file.id)
      assert_receive {:upload_completed, ^upload_id, _duration_ms}, 2_000
    end

    test "returns an error instead of exiting when the manager is not running", %{
      firmware_file: firmware_file
    } do
      :ok = Supervisor.terminate_child(Trenino.Supervisor, UploadManager)
      on_exit(fn -> Supervisor.restart_child(Trenino.Supervisor, UploadManager) end)

      assert {:error, :noproc} = UploadManager.start_upload("COM3", "uno", firmware_file.id)
    end
  end

  describe "Sentry reporting of failed uploads" do
    setup do
      test_pid = self()

      stub(Sentry, :capture_message, fn message, opts ->
        send(test_pid, {:sentry_capture, message, opts})
        :excluded
      end)

      UploadManager.subscribe_uploads()
      :ok
    end

    test "does not report a failure caused by the device or board selection", %{
      firmware_file: firmware_file
    } do
      stub(AvrdudeRunner, :run, fn _path, _args, _cb ->
        {:error, AvrdudeFixtures.avrdude8_sync_failure()}
      end)

      port = "/dev/tty.upload-env-failure-test"
      assert {:ok, upload_id} = UploadManager.start_upload(port, "uno", firmware_file.id)

      assert_receive {:upload_failed, ^upload_id, :bootloader_not_responding, _message}, 2_000
      refute_received {:sentry_capture, _, _}

      # Still recorded in the upload history with the full output
      assert {:ok, history} = Firmware.get_upload_history(upload_id)
      assert history.status == :failed
      assert history.error_message == "bootloader_not_responding"
      assert history.avrdude_output =~ "AUTHORS"
    end

    test "does not report an upload timeout", %{firmware_file: firmware_file} do
      stub(AvrdudeRunner, :run, fn _path, _args, _cb ->
        receive do
          :never -> :ok
        end
      end)

      port = "/dev/tty.upload-timeout-report-test"
      assert {:ok, upload_id} = UploadManager.start_upload(port, "uno", firmware_file.id)

      send(Process.whereis(UploadManager), {:upload_timeout, upload_id})

      assert_receive {:upload_failed, ^upload_id, :timeout, _message}, 2_000
      refute_received {:sentry_capture, _, _}
    end

    test "reports an unclassified failure with a scrub-safe output tail", %{
      firmware_file: firmware_file
    } do
      stub(AvrdudeRunner, :run, fn _path, _args, _cb ->
        {:error, AvrdudeFixtures.avrdude8_config_error()}
      end)

      port = "/dev/tty.upload-bug-failure-test"
      assert {:ok, upload_id} = UploadManager.start_upload(port, "uno", firmware_file.id)

      assert_receive {:upload_failed, ^upload_id, :unknown_error, _message}, 2_000
      assert_received {:sentry_capture, "firmware_upload_failed", opts}

      assert opts[:fingerprint] == ["firmware_upload_failed", "unknown_error"]
      assert opts[:tags] == %{error_reason: "unknown_error", board: "uno"}

      extra = opts[:extra]
      refute Map.has_key?(extra, :avrdude_output)
      assert extra.upload_id == upload_id
      assert extra.avrdude_output_tail =~ "unable to process system wide configuration file"
      assert extra.avrdude_output_tail =~ "[avrdude exited with status 1]"
      refute extra.avrdude_output_tail =~ ~r/auth/i
    end
  end
end
