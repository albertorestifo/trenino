defmodule TswIo.Firmware.UploadHistoryTest do
  use TswIo.DataCase, async: false

  alias TswIo.Firmware.UploadHistory
  alias TswIo.Firmware.FirmwareRelease
  alias TswIo.Firmware.FirmwareFile

  defp create_firmware_file do
    {:ok, release} =
      %FirmwareRelease{}
      |> FirmwareRelease.changeset(%{version: "1.0.0", tag_name: "v1.0.0"})
      |> Repo.insert()

    {:ok, file} =
      %FirmwareFile{}
      |> FirmwareFile.changeset(%{
        firmware_release_id: release.id,
        board_type: :uno,
        download_url: "https://example.com/uno.hex"
      })
      |> Repo.insert()

    file
  end

  describe "changeset/2" do
    test "creates valid changeset with required fields" do
      attrs = %{
        upload_id: "upload_123",
        port: "/dev/ttyUSB0",
        board_type: :uno,
        status: :started
      }

      changeset = UploadHistory.changeset(%UploadHistory{}, attrs)

      assert changeset.valid?
    end

    test "creates valid changeset with all fields" do
      file = create_firmware_file()

      attrs = %{
        upload_id: "upload_456",
        port: "/dev/ttyACM0",
        board_type: :leonardo,
        firmware_file_id: file.id,
        status: :completed,
        avrdude_output: "avrdude: 22890 bytes written",
        duration_ms: 5432,
        started_at: ~U[2025-12-09 12:00:00Z],
        completed_at: ~U[2025-12-09 12:00:05Z]
      }

      changeset = UploadHistory.changeset(%UploadHistory{}, attrs)

      assert changeset.valid?
    end

    test "requires upload_id" do
      attrs = %{port: "/dev/ttyUSB0", board_type: :uno, status: :started}

      changeset = UploadHistory.changeset(%UploadHistory{}, attrs)

      refute changeset.valid?
      assert %{upload_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires port" do
      attrs = %{upload_id: "upload_123", board_type: :uno, status: :started}

      changeset = UploadHistory.changeset(%UploadHistory{}, attrs)

      refute changeset.valid?
      assert %{port: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires board_type" do
      attrs = %{upload_id: "upload_123", port: "/dev/ttyUSB0", status: :started}

      changeset = UploadHistory.changeset(%UploadHistory{}, attrs)

      refute changeset.valid?
      assert %{board_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires status" do
      attrs = %{upload_id: "upload_123", port: "/dev/ttyUSB0", board_type: :uno}

      changeset = UploadHistory.changeset(%UploadHistory{}, attrs)

      refute changeset.valid?
      assert %{status: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates status enum" do
      attrs = %{
        upload_id: "upload_123",
        port: "/dev/ttyUSB0",
        board_type: :uno,
        status: :invalid_status
      }

      changeset = UploadHistory.changeset(%UploadHistory{}, attrs)

      refute changeset.valid?
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "accepts all valid status values" do
      statuses = [:started, :completed, :failed, :cancelled]

      for status <- statuses do
        attrs = %{
          upload_id: "upload_#{status}",
          port: "/dev/ttyUSB0",
          board_type: :uno,
          status: status
        }

        changeset = UploadHistory.changeset(%UploadHistory{}, attrs)

        assert changeset.valid?, "Expected status #{status} to be valid"
      end
    end
  end

  describe "start_changeset/1" do
    test "creates changeset with started status" do
      attrs = %{
        upload_id: "upload_start_123",
        port: "/dev/ttyUSB0",
        board_type: :nano
      }

      changeset = UploadHistory.start_changeset(attrs)

      assert changeset.valid?
      assert get_change(changeset, :status) == :started
      assert get_change(changeset, :started_at)
    end

    test "sets started_at to current time (truncated to second)" do
      # started_at is truncated to second, so we need to truncate our comparison values too
      before = DateTime.utc_now() |> DateTime.truncate(:second)

      attrs = %{upload_id: "upload_time", port: "/dev/ttyUSB0", board_type: :uno}
      changeset = UploadHistory.start_changeset(attrs)

      after_time = DateTime.utc_now() |> DateTime.add(1, :second) |> DateTime.truncate(:second)

      started_at = get_change(changeset, :started_at)
      assert DateTime.compare(started_at, before) in [:gt, :eq]
      assert DateTime.compare(started_at, after_time) in [:lt, :eq]
    end

    test "includes firmware_file_id when provided" do
      file = create_firmware_file()

      attrs = %{
        upload_id: "upload_with_file",
        port: "/dev/ttyUSB0",
        board_type: :uno,
        firmware_file_id: file.id
      }

      changeset = UploadHistory.start_changeset(attrs)

      assert changeset.valid?
      assert get_change(changeset, :firmware_file_id) == file.id
    end
  end

  describe "complete_changeset/2" do
    test "sets status to completed and completed_at" do
      {:ok, history} =
        UploadHistory.start_changeset(%{
          upload_id: "upload_complete",
          port: "/dev/ttyUSB0",
          board_type: :uno
        })
        |> Repo.insert()

      # Small delay to ensure duration_ms is non-zero
      Process.sleep(10)

      changeset = UploadHistory.complete_changeset(history, %{avrdude_output: "success"})

      assert get_change(changeset, :status) == :completed
      assert get_change(changeset, :completed_at)
      assert get_change(changeset, :duration_ms) >= 0
      assert get_change(changeset, :avrdude_output) == "success"
    end

    test "calculates duration_ms from started_at" do
      # Use truncated datetime for started_at since that's what the schema stores
      started_at =
        DateTime.utc_now()
        |> DateTime.add(-5, :second)
        |> DateTime.truncate(:second)

      history = %UploadHistory{started_at: started_at}
      changeset = UploadHistory.complete_changeset(history)

      duration_ms = get_change(changeset, :duration_ms)
      # Should be approximately 5000ms (could be 4000-6000 due to truncation)
      assert duration_ms >= 4000
      assert duration_ms < 7000
    end

    test "handles nil started_at" do
      history = %UploadHistory{started_at: nil}

      changeset = UploadHistory.complete_changeset(history)

      assert get_change(changeset, :status) == :completed
      assert get_change(changeset, :duration_ms) == nil
    end
  end

  describe "fail_changeset/3" do
    test "sets status to failed with error message" do
      {:ok, history} =
        UploadHistory.start_changeset(%{
          upload_id: "upload_fail",
          port: "/dev/ttyUSB0",
          board_type: :leonardo
        })
        |> Repo.insert()

      changeset = UploadHistory.fail_changeset(history, "Device not responding")

      assert get_change(changeset, :status) == :failed
      assert get_change(changeset, :error_message) == "Device not responding"
      assert get_change(changeset, :completed_at)
      assert get_change(changeset, :duration_ms)
    end

    test "includes avrdude_output when provided" do
      history = %UploadHistory{started_at: DateTime.utc_now()}

      changeset =
        UploadHistory.fail_changeset(
          history,
          "Verification failed",
          "avrdude: verification error, first mismatch at byte 0x0100"
        )

      assert get_change(changeset, :error_message) == "Verification failed"
      assert get_change(changeset, :avrdude_output) =~ "verification error"
    end
  end

  describe "cancel_changeset/1" do
    test "sets status to cancelled" do
      {:ok, history} =
        UploadHistory.start_changeset(%{
          upload_id: "upload_cancel",
          port: "/dev/ttyUSB0",
          board_type: :micro
        })
        |> Repo.insert()

      changeset = UploadHistory.cancel_changeset(history)

      assert get_change(changeset, :status) == :cancelled
      assert get_change(changeset, :completed_at)
      assert get_change(changeset, :duration_ms)
    end

    test "does not set error_message" do
      history = %UploadHistory{started_at: DateTime.utc_now()}

      changeset = UploadHistory.cancel_changeset(history)

      refute get_change(changeset, :error_message)
    end
  end

  describe "schema associations" do
    test "belongs_to firmware_file" do
      file = create_firmware_file()

      {:ok, history} =
        %UploadHistory{}
        |> UploadHistory.changeset(%{
          upload_id: "upload_assoc",
          port: "/dev/ttyUSB0",
          board_type: :uno,
          firmware_file_id: file.id,
          status: :completed
        })
        |> Repo.insert()

      history = Repo.preload(history, :firmware_file)

      assert history.firmware_file.id == file.id
      assert history.firmware_file.board_type == :uno
    end
  end
end
