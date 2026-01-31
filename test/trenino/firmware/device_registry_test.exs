defmodule Trenino.Firmware.DeviceRegistryTest do
  use Trenino.DataCase, async: false

  alias Trenino.Firmware
  alias Trenino.Firmware.DeviceRegistry

  # DeviceRegistry is started by the Application supervision tree
  # We don't need to start/stop it manually for most tests

  # Standard test manifest with common devices
  @test_manifest %{
    "version" => "1.0",
    "project" => "trenino_firmware",
    "devices" => [
      %{
        "environment" => "uno",
        "displayName" => "Arduino Uno",
        "firmwareFile" => "trenino-uno.firmware.hex",
        "uploadConfig" => %{
          "protocol" => "arduino",
          "mcu" => "atmega328p",
          "speed" => 115_200,
          "requires1200bpsTouch" => false
        }
      },
      %{
        "environment" => "nanoatmega328",
        "displayName" => "Arduino Nano",
        "firmwareFile" => "trenino-nanoatmega328.firmware.hex",
        "uploadConfig" => %{
          "protocol" => "arduino",
          "mcu" => "atmega328p",
          "speed" => 115_200,
          "requires1200bpsTouch" => false
        }
      },
      %{
        "environment" => "leonardo",
        "displayName" => "Arduino Leonardo",
        "firmwareFile" => "trenino-leonardo.firmware.hex",
        "uploadConfig" => %{
          "protocol" => "avr109",
          "mcu" => "atmega32u4",
          "speed" => 57_600,
          "requires1200bpsTouch" => true
        }
      },
      %{
        "environment" => "micro",
        "displayName" => "Arduino Micro",
        "firmwareFile" => "trenino-micro.firmware.hex",
        "uploadConfig" => %{
          "protocol" => "avr109",
          "mcu" => "atmega32u4",
          "speed" => 57_600,
          "requires1200bpsTouch" => true
        }
      },
      %{
        "environment" => "sparkfun_promicro16",
        "displayName" => "SparkFun Pro Micro",
        "firmwareFile" => "trenino-sparkfun-pro-micro.firmware.hex",
        "uploadConfig" => %{
          "protocol" => "avr109",
          "mcu" => "atmega32u4",
          "speed" => 57_600,
          "requires1200bpsTouch" => true
        }
      },
      %{
        "environment" => "megaatmega2560",
        "displayName" => "Arduino Mega 2560",
        "firmwareFile" => "trenino-megaatmega2560.firmware.hex",
        "uploadConfig" => %{
          "protocol" => "wiring",
          "mcu" => "atmega2560",
          "speed" => 115_200,
          "requires1200bpsTouch" => false
        }
      },
      %{
        "environment" => "due",
        "displayName" => "Arduino Due",
        "firmwareFile" => "trenino-due.firmware.bin",
        "uploadConfig" => %{
          "protocol" => "sam-ba",
          "mcu" => "at91sam3x8e",
          "speed" => 115_200,
          "requires1200bpsTouch" => true
        }
      }
    ]
  }

  setup do
    # Load standard manifest before each test
    DeviceRegistry.reload_from_manifest(@test_manifest, 1)

    # After each test, clear the manifest
    on_exit(fn ->
      # Reload with empty manifest to clear devices
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
    test "returns all devices from loaded manifest" do
      devices = DeviceRegistry.list_available_devices()

      assert length(devices) == 7

      environments = Enum.map(devices, & &1.environment) |> Enum.sort()

      assert "uno" in environments
      assert "nanoatmega328" in environments
      assert "leonardo" in environments
      assert "micro" in environments
      assert "sparkfun_promicro16" in environments
      assert "megaatmega2560" in environments
      assert "due" in environments
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
    setup do
      # Load a manifest with devices for detection to work
      manifest = %{
        "version" => "1.0",
        "project" => "trenino_firmware",
        "devices" => [
          %{
            "environment" => "leonardo",
            "displayName" => "Arduino Leonardo",
            "firmwareFile" => "trenino-leonardo.firmware.hex",
            "uploadConfig" => %{
              "protocol" => "avr109",
              "mcu" => "atmega32u4",
              "speed" => 57_600
            }
          },
          %{
            "environment" => "uno",
            "displayName" => "Arduino Uno",
            "firmwareFile" => "trenino-uno.firmware.hex",
            "uploadConfig" => %{
              "protocol" => "arduino",
              "mcu" => "atmega328p",
              "speed" => 115_200
            }
          },
          %{
            "environment" => "megaatmega2560",
            "displayName" => "Arduino Mega 2560",
            "firmwareFile" => "trenino-megaatmega2560.firmware.hex",
            "uploadConfig" => %{
              "protocol" => "wiring",
              "mcu" => "atmega2560",
              "speed" => 115_200
            }
          }
        ]
      }

      DeviceRegistry.reload_from_manifest(manifest, 1)
      :ok
    end

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
            "firmwareFile" => "trenino-uno.hex",
            "uploadConfig" => %{
              "protocol" => "arduino",
              "mcu" => "atmega328p",
              "speed" => 115_200
            }
          },
          %{
            "environment" => "leonardo",
            "displayName" => "Custom Leonardo",
            "firmwareFile" => "trenino-leonardo.hex",
            "uploadConfig" => %{
              "protocol" => "avr109",
              "mcu" => "atmega32u4",
              "speed" => 57_600
            }
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

    test "loads all devices with valid uploadConfig from manifest" do
      manifest = %{
        "version" => "1.0",
        "project" => "trenino_firmware",
        "devices" => [
          %{
            "environment" => "uno",
            "displayName" => "Arduino Uno",
            "firmwareFile" => "trenino-uno.hex",
            "uploadConfig" => %{
              "protocol" => "arduino",
              "mcu" => "atmega328p",
              "speed" => 115_200
            }
          },
          %{
            "environment" => "custom_board",
            "displayName" => "Custom Board",
            "firmwareFile" => "trenino-custom.hex",
            "uploadConfig" => %{
              "protocol" => "custom_protocol",
              "mcu" => "custom_mcu",
              "speed" => 9600
            }
          }
        ]
      }

      assert :ok = DeviceRegistry.reload_from_manifest(manifest, 1)

      # Should have uno
      assert {:ok, uno_config} = DeviceRegistry.get_device_config("uno")
      assert uno_config.environment == "uno"
      assert uno_config.programmer == "arduino"

      # Should also have custom board (any protocol/mcu is accepted from manifest)
      assert {:ok, custom_config} = DeviceRegistry.get_device_config("custom_board")
      assert custom_config.environment == "custom_board"
      assert custom_config.programmer == "custom_protocol"
      assert custom_config.mcu == "custom_mcu"
      assert custom_config.baud_rate == 9600
    end

    test "returns error when manifest has no devices" do
      manifest = %{
        "version" => "1.0",
        "project" => "trenino_firmware",
        "devices" => []
      }

      assert {:error, :no_devices} = DeviceRegistry.reload_from_manifest(manifest, 1)

      # Registry should be empty (no devices available)
      devices = DeviceRegistry.list_available_devices()
      assert devices == []
    end

    test "returns error when manifest devices are invalid" do
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

      # Registry should be empty (no valid devices)
      devices = DeviceRegistry.list_available_devices()
      assert devices == []
    end

    test "merges manifest devices with hardware configs" do
      manifest = %{
        "version" => "1.0",
        "project" => "trenino_firmware",
        "devices" => [
          %{
            "environment" => "leonardo",
            "displayName" => "My Leonardo",
            "firmwareFile" => "custom-leonardo.hex",
            "uploadConfig" => %{
              "protocol" => "avr109",
              "mcu" => "atmega32u4",
              "speed" => 57_600,
              "requires1200bpsTouch" => true
            }
          }
        ]
      }

      assert :ok = DeviceRegistry.reload_from_manifest(manifest, 1)

      assert {:ok, config} = DeviceRegistry.get_device_config("leonardo")

      # From manifest
      assert config.display_name == "My Leonardo"
      assert config.firmware_file == "custom-leonardo.hex"

      # From upload config
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
            "firmwareFile" => "db-uno.hex",
            "uploadConfig" => %{
              "protocol" => "arduino",
              "mcu" => "atmega328p",
              "speed" => 115_200
            }
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
