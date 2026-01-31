defmodule Trenino.Firmware.ReleaseManifestIntegrationTest do
  @moduledoc """
  End-to-end integration tests using real release manifest data.

  These tests validate the entire firmware update flow from fetching
  GitHub releases to device configuration loading, using the actual
  release.json format from the trenino_firmware repository.
  """

  use Trenino.DataCase, async: false

  alias Trenino.Firmware
  alias Trenino.Firmware.DeviceRegistry

  # Real manifest from v2.2.1 release
  @test_manifest %{
    "version" => "v2.2.1",
    "releaseDate" => "2026-01-31T14:44:01Z",
    "project" => "trenino",
    "devices" => [
      %{
        "environment" => "due",
        "name" => "arduino-due",
        "displayName" => "Arduino Due",
        "firmwareFile" => "trenino-arduino-due.firmware.bin",
        "uploadConfig" => %{
          "protocol" => "sam-ba",
          "mcu" => "at91sam3x8e",
          "speed" => 115_200,
          "requires1200bpsTouch" => true
        }
      },
      %{
        "environment" => "leonardo",
        "name" => "arduino-leonardo",
        "displayName" => "Arduino Leonardo",
        "firmwareFile" => "trenino-arduino-leonardo.firmware.hex",
        "uploadConfig" => %{
          "protocol" => "avr109",
          "mcu" => "atmega32u4",
          "speed" => 57_600,
          "requires1200bpsTouch" => true
        }
      },
      %{
        "environment" => "nanoatmega328new",
        "name" => "arduino-nano",
        "displayName" => "Arduino Nano",
        "firmwareFile" => "trenino-arduino-nano.firmware.hex",
        "uploadConfig" => %{
          "protocol" => "arduino",
          "mcu" => "atmega328p",
          "speed" => 115_200,
          "requires1200bpsTouch" => false
        }
      },
      %{
        "environment" => "uno",
        "name" => "arduino-uno",
        "displayName" => "Arduino Uno",
        "firmwareFile" => "trenino-arduino-uno.firmware.hex",
        "uploadConfig" => %{
          "protocol" => "arduino",
          "mcu" => "atmega328p",
          "speed" => 115_200,
          "requires1200bpsTouch" => false
        }
      },
      %{
        "environment" => "esp32dev",
        "name" => "esp32",
        "displayName" => "ESP32 DevKit",
        "firmwareFile" => "trenino-esp32.firmware.bin",
        "uploadConfig" => %{
          "protocol" => "esptool",
          "mcu" => "esp32",
          "speed" => 921_600,
          "requires1200bpsTouch" => false
        }
      },
      %{
        "environment" => "sparkfun_promicro16",
        "name" => "sparkfun-pro-micro",
        "displayName" => "SparkFun Pro Micro",
        "firmwareFile" => "trenino-sparkfun-pro-micro.firmware.hex",
        "uploadConfig" => %{
          "protocol" => "avr109",
          "mcu" => "atmega32u4",
          "speed" => 57_600,
          "requires1200bpsTouch" => true
        }
      }
    ]
  }

  describe "end-to-end firmware release flow" do
    test "creates release from manifest and loads all devices" do
      # Step 1: Create firmware release with manifest
      {:ok, release} =
        Firmware.upsert_release(%{
          version: "2.2.1",
          tag_name: "v2.2.1",
          release_url: "https://github.com/albertorestifo/trenino_firmware/releases/tag/v2.2.1",
          release_notes: "Test release",
          published_at: ~U[2026-01-31 14:44:01Z],
          manifest_json: Jason.encode!(@test_manifest)
        })

      assert release.tag_name == "v2.2.1"
      assert release.manifest_json != nil

      # Step 2: Create firmware files for each device
      Enum.each(@test_manifest["devices"], fn device ->
        {:ok, _file} =
          Firmware.create_firmware_file(release.id, %{
            board_type: device["environment"],
            environment: device["environment"],
            download_url:
              "https://github.com/albertorestifo/trenino_firmware/releases/download/v2.2.1/#{device["firmwareFile"]}",
            file_size: 10_000
          })
      end)

      # Step 3: Reload device registry from manifest
      assert :ok = DeviceRegistry.reload_from_manifest(@test_manifest, release.id)

      # Step 4: Verify all devices are available
      devices = DeviceRegistry.list_available_devices()
      assert length(devices) == 6

      # Verify device names
      device_names = Enum.map(devices, & &1.display_name) |> Enum.sort()

      expected_names = [
        "Arduino Due",
        "Arduino Leonardo",
        "Arduino Nano",
        "Arduino Uno",
        "ESP32 DevKit",
        "SparkFun Pro Micro"
      ]

      assert device_names == expected_names
    end

    test "loads correct upload configurations for each device" do
      {:ok, release} = create_test_release()
      :ok = DeviceRegistry.reload_from_manifest(@test_manifest, release.id)

      # Test Arduino Nano configuration
      {:ok, nano_config} = DeviceRegistry.get_device_config("nanoatmega328new")
      assert nano_config.environment == "nanoatmega328new"
      assert nano_config.display_name == "Arduino Nano"
      assert nano_config.programmer == "arduino"
      assert nano_config.mcu == "m328p"
      assert nano_config.baud_rate == 115_200
      assert nano_config.use_1200bps_touch == false

      # Test Leonardo configuration (requires 1200bps touch)
      {:ok, leo_config} = DeviceRegistry.get_device_config("leonardo")
      assert leo_config.programmer == "avr109"
      assert leo_config.mcu == "m32u4"
      assert leo_config.baud_rate == 57_600
      assert leo_config.use_1200bps_touch == true

      # Test ESP32 configuration (different protocol)
      {:ok, esp_config} = DeviceRegistry.get_device_config("esp32dev")
      assert esp_config.programmer == "esptool"
      assert esp_config.mcu == "esp32"
      assert esp_config.baud_rate == 921_600
      assert esp_config.use_1200bps_touch == false
    end

    test "firmware file selection works with environment strings" do
      {:ok, release} = create_test_release_with_files()
      :ok = DeviceRegistry.reload_from_manifest(@test_manifest, release.id)

      {:ok, release_with_files} = Firmware.get_release(release.id, preload: [:firmware_files])

      # Find firmware file for Arduino Nano by environment
      nano_file =
        Enum.find(release_with_files.firmware_files, fn file ->
          file.environment == "nanoatmega328new"
        end)

      assert nano_file != nil
      assert nano_file.environment == "nanoatmega328new"
      assert String.ends_with?(nano_file.download_url, "arduino-nano.firmware.hex")

      # Find firmware file for ESP32
      esp_file =
        Enum.find(release_with_files.firmware_files, fn file ->
          file.environment == "esp32dev"
        end)

      assert esp_file != nil
      assert esp_file.environment == "esp32dev"
      assert String.ends_with?(esp_file.download_url, "esp32.firmware.bin")
    end

    test "select_options returns all devices with display names" do
      {:ok, release} = create_test_release()
      :ok = DeviceRegistry.reload_from_manifest(@test_manifest, release.id)

      options = DeviceRegistry.select_options()

      assert length(options) == 6
      assert {"Arduino Nano", "nanoatmega328new"} in options
      assert {"Arduino Leonardo", "leonardo"} in options
      assert {"ESP32 DevKit", "esp32dev"} in options
    end

    test "detects devices from firmware filenames" do
      {:ok, release} = create_test_release()
      :ok = DeviceRegistry.reload_from_manifest(@test_manifest, release.id)

      assert {:ok, "nanoatmega328new"} =
               DeviceRegistry.detect_device_from_filename("trenino-nanoatmega328new.firmware.hex")

      assert {:ok, "leonardo"} =
               DeviceRegistry.detect_device_from_filename("trenino-leonardo.firmware.hex")

      assert :error =
               DeviceRegistry.detect_device_from_filename("unknown-device.hex")
    end

    test "normalizes MCU names from full to avrdude short codes" do
      {:ok, release} = create_test_release()
      :ok = DeviceRegistry.reload_from_manifest(@test_manifest, release.id)

      # Verify MCU normalization
      {:ok, nano} = DeviceRegistry.get_device_config("nanoatmega328new")
      assert nano.mcu == "m328p", "atmega328p should be normalized to m328p"

      {:ok, leo} = DeviceRegistry.get_device_config("leonardo")
      assert leo.mcu == "m32u4", "atmega32u4 should be normalized to m32u4"

      {:ok, due} = DeviceRegistry.get_device_config("due")
      assert due.mcu == "at91sam3x8e", "ARM MCU should keep full name"
    end

    test "handles missing uploadConfig gracefully" do
      invalid_manifest = %{
        "version" => "v1.0.0",
        "project" => "trenino",
        "devices" => [
          %{
            "environment" => "test",
            "displayName" => "Test Device",
            "firmwareFile" => "test.hex"
            # Missing uploadConfig
          }
        ]
      }

      {:ok, release} =
        Firmware.upsert_release(%{
          version: "1.0.0",
          tag_name: "v1.0.0",
          manifest_json: Jason.encode!(invalid_manifest)
        })

      # Should handle gracefully and skip invalid devices
      {:error, :no_valid_devices} =
        DeviceRegistry.reload_from_manifest(invalid_manifest, release.id)

      # Registry should be empty (no valid devices)
      devices = DeviceRegistry.list_available_devices()
      assert devices == []
    end
  end

  # Helper functions

  defp create_test_release do
    Firmware.upsert_release(%{
      version: "2.2.1",
      tag_name: "v2.2.1",
      release_url: "https://github.com/albertorestifo/trenino_firmware/releases/tag/v2.2.1",
      release_notes: "Test release",
      published_at: ~U[2026-01-31 14:44:01Z],
      manifest_json: Jason.encode!(@test_manifest)
    })
  end

  defp create_test_release_with_files do
    {:ok, release} = create_test_release()

    Enum.each(@test_manifest["devices"], fn device ->
      Firmware.create_firmware_file(release.id, %{
        board_type: device["environment"],
        environment: device["environment"],
        download_url:
          "https://github.com/albertorestifo/trenino_firmware/releases/download/v2.2.1/#{device["firmwareFile"]}",
        file_size: 10_000
      })
    end)

    {:ok, release}
  end
end
