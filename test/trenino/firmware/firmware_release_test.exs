defmodule Trenino.Firmware.FirmwareReleaseTest do
  use Trenino.DataCase, async: false

  alias Trenino.Firmware.FirmwareFile
  alias Trenino.Firmware.FirmwareRelease

  describe "changeset/2" do
    test "creates valid changeset with required fields" do
      attrs = %{
        version: "1.0.0",
        tag_name: "v1.0.0"
      }

      changeset = FirmwareRelease.changeset(%FirmwareRelease{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :version) == "1.0.0"
      assert get_change(changeset, :tag_name) == "v1.0.0"
    end

    test "creates valid changeset with all fields" do
      attrs = %{
        version: "1.0.0",
        tag_name: "v1.0.0",
        release_url: "https://github.com/albertorestifo/trenino_firmware/releases/tag/v1.0.0",
        release_notes: "Initial release\n- Feature 1\n- Feature 2",
        published_at: ~U[2025-12-09 12:31:04Z]
      }

      changeset = FirmwareRelease.changeset(%FirmwareRelease{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :release_url) =~ "github.com"
      assert get_change(changeset, :release_notes) =~ "Initial release"
      assert get_change(changeset, :published_at) == ~U[2025-12-09 12:31:04Z]
    end

    test "requires version" do
      attrs = %{tag_name: "v1.0.0"}

      changeset = FirmwareRelease.changeset(%FirmwareRelease{}, attrs)

      refute changeset.valid?
      assert %{version: ["can't be blank"]} = errors_on(changeset)
    end

    test "requires tag_name" do
      attrs = %{version: "1.0.0"}

      changeset = FirmwareRelease.changeset(%FirmwareRelease{}, attrs)

      refute changeset.valid?
      assert %{tag_name: ["can't be blank"]} = errors_on(changeset)
    end

    test "enforces unique tag_name constraint" do
      attrs = %{version: "1.0.0", tag_name: "v1.0.0"}

      {:ok, _release} =
        %FirmwareRelease{}
        |> FirmwareRelease.changeset(attrs)
        |> Repo.insert()

      {:error, changeset} =
        %FirmwareRelease{}
        |> FirmwareRelease.changeset(attrs)
        |> Repo.insert()

      assert %{tag_name: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "schema associations" do
    test "has_many firmware_files" do
      attrs = %{version: "1.0.0", tag_name: "v1.0.0"}

      {:ok, release} =
        %FirmwareRelease{}
        |> FirmwareRelease.changeset(attrs)
        |> Repo.insert()

      # Insert a firmware file for this release
      {:ok, _file} =
        %FirmwareFile{}
        |> FirmwareFile.changeset(%{
          firmware_release_id: release.id,
          board_type: "uno",
          download_url: "https://example.com/uno.hex"
        })
        |> Repo.insert()

      # Preload and verify
      release = Repo.preload(release, :firmware_files)

      assert length(release.firmware_files) == 1
      assert hd(release.firmware_files).board_type == "uno"
    end
  end
end
