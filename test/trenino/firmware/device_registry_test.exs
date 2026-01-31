defmodule Trenino.Firmware.DeviceRegistryTest do
  use Trenino.DataCase, async: false

  alias Trenino.Firmware
  alias Trenino.Firmware.DeviceRegistry

  # DeviceRegistry is started by the Application supervision tree
  # We don't need to start/stop it manually for most tests

  setup do
    # After each test, reload fallback devices
    on_exit(fn ->
      # Reload fallback devices by calling with empty manifest
      manifest = %{
        "version" => "1.0",
        "project" => "trenino_firmware",
        "devices" => []
      }

      DeviceRegistry.reload_from_manifest(manifest, 0)
    end)

    :ok
  end

  describe "get_device_config/1" do
    test "returns config for known environment" do
      assert {:ok, config} = DeviceRegistry.get_device_config("uno")

      assert config.environment == "uno"
      assert config.display_name == "Arduino Uno"
      assert config.firmware_file == "trenino-uno.firmware.hex"
      assert config.mcu == "m328p"
      assert config.programmer == "arduino"
      assert config.baud_rate == 115_200
      assert config.use_1200bps_touch == false
    end

    test "returns config for Leonardo with 1200bps touch" do
      assert {:ok, config} = DeviceRegistry.get_device_config("leonardo")

      assert config.environment == "leonardo"
      assert config.display_name == "Arduino Leonardo"
      assert config.mcu == "m32u4"
      assert config.programmer == "avr109"
      assert config.baud_rate == 57_600
      assert config.use_1200bps_touch == true
    end

    test "returns config for all static environments" do
      environments = [
        "uno",
        "nanoatmega328",
        "leonardo",
        "micro",
        "sparkfun_promicro16",
        "megaatmega2560"
      ]

      for env <- environments do
        assert {:ok, config} = DeviceRegistry.get_device_config(env)
        assert config.environment == env
        assert is_binary(config.display_name)
        assert is_binary(config.firmware_file)
        assert is_binary(config.mcu)
        assert is_binary(config.programmer)
        assert is_integer(config.baud_rate)
        assert is_boolean(config.use_1200bps_touch)
      end
    end

    test "returns error for unknown environment" do
      assert {:error, :unknown_device} = DeviceRegistry.get_device_config("unknown_board")
    end
  end

  describe "list_available_devices/0" do
    test "returns all fallback devices when no manifest" do
      devices = DeviceRegistry.list_available_devices()

      assert length(devices) == 7

      environments = Enum.map(devices, & &1.environment) |> Enum.sort()

      assert "uno" in environments
      assert "nanoatmega328" in environments
      assert "leonardo" in environments
      assert "micro" in environments
      assert "sparkfun_promicro16" in environments
      assert "megaatmega2560" in environments
    end

    test "devices are sorted by display name" do
      devices = DeviceRegistry.list_available_devices()
      names = Enum.map(devices, & &1.display_name)

      assert names == Enum.sort(names)
    end

    test "all devices have required fields" do
      devices = DeviceRegistry.list_available_devices()

      for device <- devices do
        assert is_binary(device.environment)
        assert is_binary(device.display_name)
        assert is_binary(device.firmware_file)
        assert is_binary(device.mcu)
        assert is_binary(device.programmer)
        assert is_integer(device.baud_rate)
        assert is_boolean(device.use_1200bps_touch)
      end
    end
  end

  describe "select_options/0" do
    test "returns options suitable for form select" do
      options = DeviceRegistry.select_options()

      assert length(options) == 7

      for {name, env} <- options do
        assert is_binary(name)
        assert is_binary(env)
      end
    end

    test "options are sorted alphabetically by display name" do
      options = DeviceRegistry.select_options()
      names = Enum.map(options, fn {name, _env} -> name end)

      assert names == Enum.sort(names)
    end

    test "includes all environments" do
      options = DeviceRegistry.select_options()
      environments = Enum.map(options, fn {_name, env} -> env end)

      assert "uno" in environments
      assert "leonardo" in environments
      assert "sparkfun_promicro16" in environments
    end
  end

  describe "detect_device_from_filename/1" do
    test "detects device from trenino firmware filename" do
      assert {:ok, "leonardo"} =
               DeviceRegistry.detect_device_from_filename("trenino-leonardo.firmware.hex")

      assert {:ok, "uno"} = DeviceRegistry.detect_device_from_filename("trenino-uno.firmware.hex")

      assert {:ok, "megaatmega2560"} =
               DeviceRegistry.detect_device_from_filename("trenino-megaatmega2560.firmware.hex")
    end

    test "detects device from short firmware filename" do
      assert {:ok, "leonardo"} =
               DeviceRegistry.detect_device_from_filename("trenino-leonardo.hex")

      assert {:ok, "uno"} = DeviceRegistry.detect_device_from_filename("trenino-uno.hex")
    end

    test "returns error for unknown device" do
      assert :error = DeviceRegistry.detect_device_from_filename("trenino-unknown.hex")
    end

    test "returns error for non-matching filename" do
      assert :error = DeviceRegistry.detect_device_from_filename("firmware.hex")
      assert :error = DeviceRegistry.detect_device_from_filename("arduino-uno.hex")
      assert :error = DeviceRegistry.detect_device_from_filename("leonardo.hex")
    end
  end

  describe "reload_from_manifest/2" do
    test "loads devices from valid manifest" do
      manifest = %{
        "version" => "1.0",
        "project" => "trenino_firmware",
        "devices" => [
          %{
            "environment" => "uno",
            "displayName" => "Custom Uno",
            "firmwareFile" => "trenino-uno.hex"
          },
          %{
            "environment" => "leonardo",
            "displayName" => "Custom Leonardo",
            "firmwareFile" => "trenino-leonardo.hex"
          }
        ]
      }

      assert :ok = DeviceRegistry.reload_from_manifest(manifest, 1)

      # Should now have the custom devices
      assert {:ok, config} = DeviceRegistry.get_device_config("uno")
      assert config.display_name == "Custom Uno"
      assert config.firmware_file == "trenino-uno.hex"

      assert {:ok, config} = DeviceRegistry.get_device_config("leonardo")
      assert config.display_name == "Custom Leonardo"
    end

    test "only loads devices with known hardware configs" do
      manifest = %{
        "version" => "1.0",
        "project" => "trenino_firmware",
        "devices" => [
          %{
            "environment" => "uno",
            "displayName" => "Arduino Uno",
            "firmwareFile" => "trenino-uno.hex"
          },
          %{
            "environment" => "unknown_board",
            "displayName" => "Unknown Board",
            "firmwareFile" => "trenino-unknown.hex"
          }
        ]
      }

      assert :ok = DeviceRegistry.reload_from_manifest(manifest, 1)

      # Should have uno
      assert {:ok, _config} = DeviceRegistry.get_device_config("uno")

      # Should not have unknown_board
      assert {:error, :unknown_device} = DeviceRegistry.get_device_config("unknown_board")
    end

    test "falls back to hardcoded devices when manifest has no devices" do
      manifest = %{
        "version" => "1.0",
        "project" => "trenino_firmware",
        "devices" => []
      }

      assert {:error, :no_devices} = DeviceRegistry.reload_from_manifest(manifest, 1)

      # Should still have fallback devices
      devices = DeviceRegistry.list_available_devices()
      assert length(devices) == 7
    end

    test "falls back when manifest devices are invalid" do
      manifest = %{
        "version" => "1.0",
        "project" => "trenino_firmware",
        "devices" => [
          %{
            "environment" => "uno"
            # Missing displayName and firmwareFile
          }
        ]
      }

      assert {:error, :no_valid_devices} = DeviceRegistry.reload_from_manifest(manifest, 1)

      # Should still have fallback devices
      devices = DeviceRegistry.list_available_devices()
      assert length(devices) == 7
    end

    test "merges manifest devices with hardware configs" do
      manifest = %{
        "version" => "1.0",
        "project" => "trenino_firmware",
        "devices" => [
          %{
            "environment" => "leonardo",
            "displayName" => "My Leonardo",
            "firmwareFile" => "custom-leonardo.hex"
          }
        ]
      }

      assert :ok = DeviceRegistry.reload_from_manifest(manifest, 1)

      assert {:ok, config} = DeviceRegistry.get_device_config("leonardo")

      # From manifest
      assert config.display_name == "My Leonardo"
      assert config.firmware_file == "custom-leonardo.hex"

      # From hardware config
      assert config.mcu == "m32u4"
      assert config.programmer == "avr109"
      assert config.baud_rate == 57_600
      assert config.use_1200bps_touch == true
    end
  end

  describe "initialization from database" do
    test "reloads manifest from database" do
      # Create a release with a manifest
      manifest = %{
        "version" => "1.0",
        "project" => "trenino_firmware",
        "devices" => [
          %{
            "environment" => "uno",
            "displayName" => "DB Uno",
            "firmwareFile" => "db-uno.hex"
          }
        ]
      }

      _release =
        Firmware.upsert_release(%{
          version: "1.0.0",
          tag_name: "v1.0.0",
          manifest_json: Jason.encode!(manifest)
        })

      # Reload the registry from database
      assert :ok = DeviceRegistry.reload_from_manifest(manifest, 1)

      # Should have loaded the manifest
      assert {:ok, config} = DeviceRegistry.get_device_config("uno")
      assert config.display_name == "DB Uno"
      assert config.firmware_file == "db-uno.hex"
    end

    test "handles invalid manifest JSON gracefully" do
      # Create a release with invalid manifest JSON
      _release =
        Firmware.upsert_release(%{
          version: "1.0.0",
          tag_name: "v1.0.0",
          manifest_json: "invalid json{{"
        })

      # Should still have fallback devices available
      devices = DeviceRegistry.list_available_devices()
      assert length(devices) == 7
    end
  end
end
