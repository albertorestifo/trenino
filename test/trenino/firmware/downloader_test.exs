defmodule Trenino.Firmware.DownloaderTest do
  use Trenino.DataCase, async: false
  use Mimic

  import ExUnit.CaptureLog

  alias Trenino.Firmware
  alias Trenino.Firmware.Downloader
  alias Trenino.Firmware.FilePath

  setup :verify_on_exit!

  # Helper function to create a valid test manifest
  defp build_test_manifest(devices) do
    %{
      "version" => "1.0",
      "project" => "trenino_firmware",
      "devices" => devices
    }
  end

  # Helper function to create a valid device entry
  defp build_device(environment, display_name, firmware_file, opts \\ []) do
    %{
      "environment" => environment,
      "displayName" => display_name,
      "firmwareFile" => firmware_file,
      "uploadConfig" => %{
        "protocol" => opts[:protocol] || "arduino",
        "mcu" => opts[:mcu] || "atmega328p",
        "speed" => opts[:speed] || 115_200,
        "requires1200bpsTouch" => opts[:requires1200bps_touch] || false
      }
    }
  end

  # Test manifest for v1.0.0 release (defined as plain map for module attribute)
  @test_manifest_v1 %{
    "version" => "1.0",
    "project" => "trenino_firmware",
    "devices" => [
      %{
        "environment" => "leonardo",
        "displayName" => "Arduino Leonardo",
        "firmwareFile" => "tws-io-arduino-leonardo.hex",
        "uploadConfig" => %{
          "protocol" => "avr109",
          "mcu" => "atmega32u4",
          "speed" => 57_600,
          "requires1200bpsTouch" => true
        }
      },
      %{
        "environment" => "mega2560",
        "displayName" => "Arduino Mega 2560",
        "firmwareFile" => "tws-io-arduino-mega-2560.hex",
        "uploadConfig" => %{
          "protocol" => "wiring",
          "mcu" => "atmega2560",
          "speed" => 115_200,
          "requires1200bpsTouch" => false
        }
      },
      %{
        "environment" => "micro",
        "displayName" => "Arduino Micro",
        "firmwareFile" => "tws-io-arduino-micro.hex",
        "uploadConfig" => %{
          "protocol" => "avr109",
          "mcu" => "atmega32u4",
          "speed" => 57_600,
          "requires1200bpsTouch" => true
        }
      },
      %{
        "environment" => "nanoatmega328new",
        "displayName" => "Arduino Nano",
        "firmwareFile" => "tws-io-arduino-nano.hex",
        "uploadConfig" => %{
          "protocol" => "arduino",
          "mcu" => "atmega328p",
          "speed" => 115_200,
          "requires1200bpsTouch" => false
        }
      },
      %{
        "environment" => "uno",
        "displayName" => "Arduino Uno",
        "firmwareFile" => "tws-io-arduino-uno.hex",
        "uploadConfig" => %{
          "protocol" => "arduino",
          "mcu" => "atmega328p",
          "speed" => 115_200,
          "requires1200bpsTouch" => false
        }
      },
      %{
        "environment" => "sparkfun_promicro16",
        "displayName" => "SparkFun Pro Micro",
        "firmwareFile" => "tws-io-sparkfun-pro-micro.hex",
        "uploadConfig" => %{
          "protocol" => "avr109",
          "mcu" => "atmega32u4",
          "speed" => 57_600,
          "requires1200bpsTouch" => true
        }
      }
    ]
  }

  # Real GitHub API response fixture (from curl https://api.github.com/repos/albertorestifo/trenino_firmware/releases)
  @github_releases_response [
    %{
      "tag_name" => "v1.0.0",
      "name" => "v1.0.0",
      "html_url" => "https://github.com/albertorestifo/trenino_firmware/releases/tag/v1.0.0",
      "body" => "Initial release with support for Arduino boards",
      "published_at" => "2025-12-09T12:31:04Z",
      "assets" => [
        %{
          "name" => "release.json",
          "size" => 1024,
          "browser_download_url" =>
            "https://github.com/albertorestifo/trenino_firmware/releases/download/v1.0.0/release.json"
        },
        %{
          "name" => "tws-io-arduino-leonardo.hex",
          "size" => 22_890,
          "browser_download_url" =>
            "https://github.com/albertorestifo/trenino_firmware/releases/download/v1.0.0/tws-io-arduino-leonardo.hex"
        },
        %{
          "name" => "tws-io-arduino-mega-2560.hex",
          "size" => 18_582,
          "browser_download_url" =>
            "https://github.com/albertorestifo/trenino_firmware/releases/download/v1.0.0/tws-io-arduino-mega-2560.hex"
        },
        %{
          "name" => "tws-io-arduino-micro.hex",
          "size" => 22_890,
          "browser_download_url" =>
            "https://github.com/albertorestifo/trenino_firmware/releases/download/v1.0.0/tws-io-arduino-micro.hex"
        },
        %{
          "name" => "tws-io-arduino-nano.hex",
          "size" => 17_113,
          "browser_download_url" =>
            "https://github.com/albertorestifo/trenino_firmware/releases/download/v1.0.0/tws-io-arduino-nano.hex"
        },
        %{
          "name" => "tws-io-arduino-uno.hex",
          "size" => 17_113,
          "browser_download_url" =>
            "https://github.com/albertorestifo/trenino_firmware/releases/download/v1.0.0/tws-io-arduino-uno.hex"
        },
        %{
          "name" => "tws-io-sparkfun-pro-micro.hex",
          "size" => 22_890,
          "browser_download_url" =>
            "https://github.com/albertorestifo/trenino_firmware/releases/download/v1.0.0/tws-io-sparkfun-pro-micro.hex"
        }
      ]
    }
  ]

  describe "check_for_updates/0" do
    test "fetches releases from GitHub and stores them in database" do
      stub(Req, :get, fn url, _opts ->
        cond do
          url =~ "api.github.com/repos/albertorestifo/trenino_firmware/releases" ->
            {:ok, %Req.Response{status: 200, body: @github_releases_response}}

          url =~ "release.json" ->
            {:ok, %Req.Response{status: 200, body: @test_manifest_v1}}

          true ->
            {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      stub(Req, :get, fn url ->
        if url =~ "release.json" do
          {:ok, %Req.Response{status: 200, body: @test_manifest_v1}}
        else
          {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      assert {:ok, releases} = Downloader.check_for_updates()

      # Should have created one release
      assert length(releases) == 1
      assert hd(releases).tag_name == "v1.0.0"
      assert hd(releases).version == "1.0.0"

      # Verify it's in the database
      assert {:ok, release} = Firmware.get_release_by_tag("v1.0.0", preload: [:firmware_files])

      assert release.release_url ==
               "https://github.com/albertorestifo/trenino_firmware/releases/tag/v1.0.0"

      assert release.release_notes == "Initial release with support for Arduino boards"

      # Should have created firmware files for all 6 board types
      assert length(release.firmware_files) == 6

      # Verify specific environments
      environments = Enum.map(release.firmware_files, & &1.environment) |> Enum.sort()

      assert "leonardo" in environments
      assert "mega2560" in environments
      assert "micro" in environments
      assert "nanoatmega328new" in environments
      assert "uno" in environments
      assert "sparkfun_promicro16" in environments
    end

    test "handles multiple releases" do
      manifest_v1_1 =
        build_test_manifest([
          build_device("uno", "Arduino Uno", "tws-io-arduino-uno.hex")
        ])

      releases_response = [
        %{
          "tag_name" => "v1.1.0",
          "name" => "v1.1.0",
          "html_url" => "https://github.com/releases/v1.1.0",
          "body" => "Bug fixes",
          "published_at" => "2025-12-10T10:00:00Z",
          "assets" => [
            %{
              "name" => "release.json",
              "size" => 500,
              "browser_download_url" => "https://github.com/releases/v1.1.0/release.json"
            },
            %{
              "name" => "tws-io-arduino-uno.hex",
              "size" => 17_200,
              "browser_download_url" => "https://github.com/releases/v1.1.0/uno.hex"
            }
          ]
        }
        | @github_releases_response
      ]

      stub(Req, :get, fn url, _opts ->
        cond do
          url =~ "api.github.com/repos" ->
            {:ok, %Req.Response{status: 200, body: releases_response}}

          url =~ "v1.1.0/release.json" ->
            {:ok, %Req.Response{status: 200, body: manifest_v1_1}}

          url =~ "v1.0.0/release.json" ->
            {:ok, %Req.Response{status: 200, body: @test_manifest_v1}}

          true ->
            {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      stub(Req, :get, fn url ->
        cond do
          url =~ "v1.1.0/release.json" ->
            {:ok, %Req.Response{status: 200, body: manifest_v1_1}}

          url =~ "v1.0.0/release.json" ->
            {:ok, %Req.Response{status: 200, body: @test_manifest_v1}}

          true ->
            {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      assert {:ok, releases} = Downloader.check_for_updates()

      assert length(releases) == 2
      versions = Enum.map(releases, & &1.version) |> Enum.sort()
      assert versions == ["1.0.0", "1.1.0"]
    end

    test "updates existing release on re-fetch" do
      # First fetch
      stub(Req, :get, fn url, _opts ->
        cond do
          url =~ "api.github.com/repos" ->
            {:ok, %Req.Response{status: 200, body: @github_releases_response}}

          url =~ "release.json" ->
            {:ok, %Req.Response{status: 200, body: @test_manifest_v1}}

          true ->
            {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      stub(Req, :get, fn url ->
        if url =~ "release.json" do
          {:ok, %Req.Response{status: 200, body: @test_manifest_v1}}
        else
          {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      assert {:ok, [release1]} = Downloader.check_for_updates()

      # Second fetch with updated notes
      updated_response = [
        %{
          "tag_name" => "v1.0.0",
          "name" => "v1.0.0",
          "html_url" => "https://github.com/releases/v1.0.0",
          "body" => "Updated release notes",
          "published_at" => "2025-12-09T12:31:04Z",
          "assets" => [
            %{
              "name" => "release.json",
              "size" => 1024,
              "browser_download_url" =>
                "https://github.com/albertorestifo/trenino_firmware/releases/download/v1.0.0/release.json"
            }
          ]
        }
      ]

      stub(Req, :get, fn url, _opts ->
        cond do
          url =~ "api.github.com/repos" ->
            {:ok, %Req.Response{status: 200, body: updated_response}}

          url =~ "release.json" ->
            {:ok, %Req.Response{status: 200, body: @test_manifest_v1}}

          true ->
            {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      stub(Req, :get, fn url ->
        if url =~ "release.json" do
          {:ok, %Req.Response{status: 200, body: @test_manifest_v1}}
        else
          {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      assert {:ok, [release2]} = Downloader.check_for_updates()

      # Should be the same release (same ID)
      assert release1.id == release2.id
      assert release2.release_notes == "Updated release notes"
    end

    test "only includes assets specified in manifest" do
      manifest_uno_only =
        build_test_manifest([
          build_device("uno", "Arduino Uno", "tws-io-arduino-uno.hex")
        ])

      release_with_mixed_assets = [
        %{
          "tag_name" => "v1.0.0",
          "name" => "v1.0.0",
          "html_url" => "https://github.com/releases/v1.0.0",
          "body" => nil,
          "published_at" => "2025-12-09T12:31:04Z",
          "assets" => [
            %{
              "name" => "release.json",
              "size" => 500,
              "browser_download_url" => "https://github.com/releases/v1.0.0/release.json"
            },
            %{
              "name" => "tws-io-arduino-uno.hex",
              "size" => 17_113,
              "browser_download_url" => "https://github.com/releases/uno.hex"
            },
            %{
              "name" => "README.md",
              "size" => 1024,
              "browser_download_url" => "https://github.com/releases/README.md"
            },
            %{
              "name" => "firmware.bin",
              "size" => 50_000,
              "browser_download_url" => "https://github.com/releases/firmware.bin"
            }
          ]
        }
      ]

      stub(Req, :get, fn url, _opts ->
        cond do
          url =~ "api.github.com/repos" ->
            {:ok, %Req.Response{status: 200, body: release_with_mixed_assets}}

          url =~ "release.json" ->
            {:ok, %Req.Response{status: 200, body: manifest_uno_only}}

          true ->
            {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      stub(Req, :get, fn url ->
        if url =~ "release.json" do
          {:ok, %Req.Response{status: 200, body: manifest_uno_only}}
        else
          {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      assert {:ok, _releases} = Downloader.check_for_updates()

      {:ok, release} = Firmware.get_release_by_tag("v1.0.0", preload: [:firmware_files])

      # Should only have the uno.hex file (from manifest)
      assert length(release.firmware_files) == 1
      assert hd(release.firmware_files).environment == "uno"
    end

    test "handles missing assets for devices in manifest" do
      # Manifest references assets that don't exist in the release
      manifest_with_missing_assets =
        build_test_manifest([
          build_device("uno", "Arduino Uno", "tws-io-arduino-uno.hex"),
          build_device("leonardo", "Arduino Leonardo", "missing-file.hex",
            protocol: "avr109",
            mcu: "atmega32u4",
            speed: 57_600
          )
        ])

      release_with_missing_asset = [
        %{
          "tag_name" => "v1.0.0",
          "name" => "v1.0.0",
          "html_url" => "https://github.com/releases/v1.0.0",
          "body" => nil,
          "published_at" => "2025-12-09T12:31:04Z",
          "assets" => [
            %{
              "name" => "release.json",
              "size" => 500,
              "browser_download_url" => "https://github.com/releases/v1.0.0/release.json"
            },
            %{
              "name" => "tws-io-arduino-uno.hex",
              "size" => 17_113,
              "browser_download_url" => "https://github.com/releases/uno.hex"
            }
          ]
        }
      ]

      stub(Req, :get, fn url, _opts ->
        cond do
          url =~ "api.github.com/repos" ->
            {:ok, %Req.Response{status: 200, body: release_with_missing_asset}}

          url =~ "release.json" ->
            {:ok, %Req.Response{status: 200, body: manifest_with_missing_assets}}

          true ->
            {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      stub(Req, :get, fn url ->
        if url =~ "release.json" do
          {:ok, %Req.Response{status: 200, body: manifest_with_missing_assets}}
        else
          {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      assert {:ok, _releases} = Downloader.check_for_updates()

      {:ok, release} = Firmware.get_release_by_tag("v1.0.0", preload: [:firmware_files])

      # Should only have uno, leonardo asset is missing
      assert length(release.firmware_files) == 1
      assert hd(release.firmware_files).environment == "uno"
    end

    test "returns error on GitHub API failure" do
      expect(Req, :get, fn _url, _opts ->
        {:ok, %Req.Response{status: 403, body: %{"message" => "Rate limit exceeded"}}}
      end)

      # capture_log suppresses expected error log output
      capture_log(fn ->
        assert {:error, {:github_api_error, 403}} = Downloader.check_for_updates()
      end)
    end

    test "returns error on network failure" do
      expect(Req, :get, fn _url, _opts ->
        {:error, %Mint.TransportError{reason: :econnrefused}}
      end)

      # capture_log suppresses expected error log output
      capture_log(fn ->
        assert {:error, %Mint.TransportError{reason: :econnrefused}} =
                 Downloader.check_for_updates()
      end)
    end

    test "handles release without published_at" do
      manifest_simple =
        build_test_manifest([
          build_device("uno", "Arduino Uno", "firmware.hex")
        ])

      release_without_date = [
        %{
          "tag_name" => "v1.0.0",
          "name" => "v1.0.0",
          "html_url" => "https://github.com/releases/v1.0.0",
          "body" => nil,
          "published_at" => nil,
          "assets" => [
            %{
              "name" => "release.json",
              "size" => 500,
              "browser_download_url" => "https://github.com/releases/v1.0.0/release.json"
            },
            %{
              "name" => "firmware.hex",
              "size" => 10_000,
              "browser_download_url" => "https://github.com/releases/v1.0.0/firmware.hex"
            }
          ]
        }
      ]

      stub(Req, :get, fn url, _opts ->
        cond do
          url =~ "api.github.com/repos" ->
            {:ok, %Req.Response{status: 200, body: release_without_date}}

          url =~ "release.json" ->
            {:ok, %Req.Response{status: 200, body: manifest_simple}}

          true ->
            {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      stub(Req, :get, fn url ->
        if url =~ "release.json" do
          {:ok, %Req.Response{status: 200, body: manifest_simple}}
        else
          {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      assert {:ok, [release]} = Downloader.check_for_updates()
      assert release.published_at == nil
    end
  end

  describe "download_firmware/1" do
    setup do
      # Create a release with a firmware file
      stub(Req, :get, fn url, _opts ->
        cond do
          url =~ "api.github.com/repos" ->
            {:ok, %Req.Response{status: 200, body: @github_releases_response}}

          url =~ "release.json" ->
            {:ok, %Req.Response{status: 200, body: @test_manifest_v1}}

          true ->
            {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      stub(Req, :get, fn url ->
        if url =~ "release.json" do
          {:ok, %Req.Response{status: 200, body: @test_manifest_v1}}
        else
          {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      {:ok, [release]} = Downloader.check_for_updates()
      {:ok, release} = Firmware.get_release(release.id, preload: [:firmware_files])

      uno_file = Enum.find(release.firmware_files, &(&1.environment == "uno"))

      # Clean up any existing test files
      cache_dir = Application.app_dir(:trenino, "priv/firmware_cache")
      File.mkdir_p!(cache_dir)

      on_exit(fn ->
        # Clean up test files
        cache_dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".hex"))
        |> Enum.each(&File.rm(Path.join(cache_dir, &1)))
      end)

      %{release: release, uno_file: uno_file}
    end

    test "downloads firmware file to cache", %{uno_file: uno_file} do
      hex_content = ":10000000DEADBEEF12345678AABBCCDD00112233EE\n:00000001FF\n"

      expect(Req, :get, fn url, opts ->
        assert url =~ "tws-io-arduino-uno.hex"
        assert Keyword.has_key?(opts, :into)
        # Simulate writing to the file stream
        file_stream = Keyword.get(opts, :into)

        Enum.into([hex_content], file_stream)
        {:ok, %Req.Response{status: 200}}
      end)

      assert {:ok, downloaded_file} = Downloader.download_firmware(uno_file.id)

      # Verify the file exists on disk (not in DB)
      assert FilePath.downloaded?(downloaded_file)
    end

    test "returns error for non-existent firmware file" do
      assert {:error, :not_found} = Downloader.download_firmware(999_999)
    end

    test "returns error on download failure", %{uno_file: uno_file} do
      expect(Req, :get, fn _url, _opts ->
        {:ok, %Req.Response{status: 404}}
      end)

      assert {:error, {:download_failed, 404}} = Downloader.download_firmware(uno_file.id)
    end

    test "returns error on network failure", %{uno_file: uno_file} do
      expect(Req, :get, fn _url, _opts ->
        {:error, %Mint.TransportError{reason: :timeout}}
      end)

      assert {:error, %Mint.TransportError{reason: :timeout}} =
               Downloader.download_firmware(uno_file.id)
    end
  end

  describe "manifest support" do
    test "fetches and parses release.json manifest" do
      manifest =
        build_test_manifest([
          build_device("uno", "Arduino Uno", "trenino-uno.firmware.hex"),
          build_device("leonardo", "Arduino Leonardo", "trenino-leonardo.firmware.hex",
            protocol: "avr109",
            mcu: "atmega32u4",
            speed: 57_600,
            requires1200bps_touch: true
          )
        ])

      release_with_manifest = [
        %{
          "tag_name" => "v2.0.0",
          "name" => "v2.0.0",
          "html_url" => "https://github.com/releases/v2.0.0",
          "body" => "Release with manifest",
          "published_at" => "2026-01-17T10:00:00Z",
          "assets" => [
            %{
              "name" => "release.json",
              "size" => 500,
              "browser_download_url" => "https://github.com/releases/v2.0.0/release.json"
            },
            %{
              "name" => "trenino-uno.firmware.hex",
              "size" => 17_113,
              "browser_download_url" => "https://github.com/releases/v2.0.0/uno.hex"
            },
            %{
              "name" => "trenino-leonardo.firmware.hex",
              "size" => 22_890,
              "browser_download_url" => "https://github.com/releases/v2.0.0/leonardo.hex"
            }
          ]
        }
      ]

      # Mock Req.get/2 (with options) for GitHub API calls
      stub(Req, :get, fn url, _opts ->
        cond do
          String.contains?(url, "api.github.com/repos") ->
            {:ok, %Req.Response{status: 200, body: release_with_manifest}}

          String.contains?(url, "release.json") ->
            {:ok, %Req.Response{status: 200, body: manifest}}

          true ->
            {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      # Mock Req.get/1 (without options) for manifest downloads
      stub(Req, :get, fn url ->
        if String.contains?(url, "release.json") do
          {:ok, %Req.Response{status: 200, body: manifest}}
        else
          {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      assert {:ok, releases} = Downloader.check_for_updates()

      assert length(releases) == 1
      release = hd(releases)
      assert release.tag_name == "v2.0.0"

      # Verify manifest was stored
      {:ok, db_release} = Firmware.get_release(release.id, preload: [:firmware_files])
      assert db_release.manifest_json != nil

      parsed_manifest = Jason.decode!(db_release.manifest_json)
      assert parsed_manifest["version"] == "1.0"
      assert parsed_manifest["project"] == "trenino_firmware"
      assert length(parsed_manifest["devices"]) == 2

      # Verify firmware files were created from manifest
      assert length(db_release.firmware_files) == 2

      environments =
        Enum.map(db_release.firmware_files, & &1.environment) |> Enum.sort()

      assert "uno" in environments
      assert "leonardo" in environments
    end

    test "skips releases without release.json manifest" do
      release_without_manifest = [
        %{
          "tag_name" => "v1.5.0",
          "name" => "v1.5.0",
          "html_url" => "https://github.com/releases/v1.5.0",
          "body" => "Old release without manifest",
          "published_at" => "2026-01-17T10:00:00Z",
          "assets" => [
            %{
              "name" => "tws-io-arduino-uno.hex",
              "size" => 17_113,
              "browser_download_url" => "https://github.com/releases/v1.5.0/uno.hex"
            }
          ]
        }
      ]

      stub(Req, :get, fn url, _opts ->
        cond do
          url =~ "api.github.com/repos" ->
            {:ok, %Req.Response{status: 200, body: release_without_manifest}}

          url =~ "release.json" ->
            {:ok, %Req.Response{status: 404, body: nil}}

          true ->
            {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      stub(Req, :get, fn url ->
        if url =~ "release.json" do
          {:ok, %Req.Response{status: 404, body: nil}}
        else
          {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      assert {:ok, releases} = Downloader.check_for_updates()

      # Releases without manifests are now skipped
      assert releases == []
    end

    test "handles invalid manifest JSON" do
      # When manifest JSON is invalid, system should fall back to legacy filename detection
      release_with_bad_manifest = [
        %{
          "tag_name" => "v3.0.0",
          "name" => "v3.0.0",
          "html_url" => "https://github.com/releases/v3.0.0",
          "body" => "Release with bad manifest",
          "published_at" => "2026-01-17T10:00:00Z",
          "assets" => [
            %{
              "name" => "release.json",
              "size" => 100,
              "browser_download_url" => "https://github.com/releases/v3.0.0/release.json"
            }
          ]
        }
      ]

      stub(Req, :get, fn url, _opts ->
        cond do
          String.contains?(url, "api.github.com/repos") ->
            {:ok, %Req.Response{status: 200, body: release_with_bad_manifest}}

          String.contains?(url, "release.json") ->
            # Return invalid JSON (plain text)
            {:ok, %Req.Response{status: 200, body: "not valid json"}}

          true ->
            {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      stub(Req, :get, fn url ->
        if String.contains?(url, "release.json") do
          {:ok, %Req.Response{status: 200, body: "not valid json"}}
        else
          {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      # Should skip this release since it has no valid assets (only an invalid manifest)
      assert {:ok, releases} = Downloader.check_for_updates()

      # Release should be skipped entirely because it has no valid firmware files
      assert releases == []
    end

    test "validates manifest structure" do
      invalid_manifests = [
        # Missing version
        %{"project" => "test", "devices" => []},
        # Missing project
        %{"version" => "1.0", "devices" => []},
        # Missing devices
        %{"version" => "1.0", "project" => "test"},
        # Devices not a list
        %{"version" => "1.0", "project" => "test", "devices" => "not a list"}
      ]

      for manifest <- invalid_manifests do
        release_with_invalid_manifest = [
          %{
            "tag_name" => "v4.0.0",
            "name" => "v4.0.0",
            "html_url" => "https://github.com/releases/v4.0.0",
            "body" => "Release",
            "published_at" => "2026-01-17T10:00:00Z",
            "assets" => [
              %{
                "name" => "release.json",
                "size" => 100,
                "browser_download_url" => "https://github.com/releases/v4.0.0/release.json"
              }
            ]
          }
        ]

        stub(Req, :get, fn url, _opts ->
          cond do
            url =~ "api.github.com/repos" ->
              {:ok, %Req.Response{status: 200, body: release_with_invalid_manifest}}

            url =~ "release.json" ->
              {:ok, %Req.Response{status: 200, body: manifest}}

            true ->
              {:ok, %Req.Response{status: 404, body: nil}}
          end
        end)

        # Should skip releases with only invalid manifests and no firmware files
        assert {:ok, releases} = Downloader.check_for_updates()
        assert releases == []
      end
    end

    test "validates device entries in manifest" do
      manifest_with_invalid_devices = %{
        "version" => "1.0",
        "project" => "trenino_firmware",
        "devices" => [
          # Valid device
          build_device("uno", "Arduino Uno", "trenino-uno.hex"),
          # Missing displayName
          %{
            "environment" => "leonardo",
            "firmwareFile" => "trenino-leonardo.hex",
            "uploadConfig" => %{
              "protocol" => "avr109",
              "mcu" => "atmega32u4",
              "speed" => 57_600
            }
          },
          # Missing firmwareFile
          %{
            "environment" => "micro",
            "displayName" => "Arduino Micro",
            "uploadConfig" => %{
              "protocol" => "avr109",
              "mcu" => "atmega32u4",
              "speed" => 57_600
            }
          }
        ]
      }

      release = [
        %{
          "tag_name" => "v5.0.0",
          "name" => "v5.0.0",
          "html_url" => "https://github.com/releases/v5.0.0",
          "body" => "Release",
          "published_at" => "2026-01-17T10:00:00Z",
          "assets" => [
            %{
              "name" => "release.json",
              "size" => 500,
              "browser_download_url" => "https://github.com/releases/v5.0.0/release.json"
            }
          ]
        }
      ]

      stub(Req, :get, fn url, _opts ->
        cond do
          String.contains?(url, "api.github.com/repos") ->
            {:ok, %Req.Response{status: 200, body: release}}

          String.contains?(url, "release.json") ->
            {:ok, %Req.Response{status: 200, body: manifest_with_invalid_devices}}

          true ->
            {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      stub(Req, :get, fn url ->
        if String.contains?(url, "release.json") do
          {:ok, %Req.Response{status: 200, body: manifest_with_invalid_devices}}
        else
          {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      # Should reject manifest with invalid devices and skip the release
      assert {:ok, releases} = Downloader.check_for_updates()

      # Release should be skipped because manifest is invalid
      assert releases == []
    end

    test "uses manifest devices over legacy filename detection" do
      manifest =
        build_test_manifest([
          build_device("uno", "Custom Uno", "custom-uno.hex")
        ])

      release_with_both = [
        %{
          "tag_name" => "v6.0.0",
          "name" => "v6.0.0",
          "html_url" => "https://github.com/releases/v6.0.0",
          "body" => "Release",
          "published_at" => "2026-01-17T10:00:00Z",
          "assets" => [
            %{
              "name" => "release.json",
              "size" => 300,
              "browser_download_url" => "https://github.com/releases/v6.0.0/release.json"
            },
            %{
              "name" => "custom-uno.hex",
              "size" => 17_113,
              "browser_download_url" => "https://github.com/releases/v6.0.0/custom-uno.hex"
            },
            %{
              "name" => "tws-io-arduino-leonardo.hex",
              "size" => 22_890,
              "browser_download_url" => "https://github.com/releases/v6.0.0/leonardo.hex"
            }
          ]
        }
      ]

      stub(Req, :get, fn url, _opts ->
        cond do
          String.contains?(url, "api.github.com/repos") ->
            {:ok, %Req.Response{status: 200, body: release_with_both}}

          String.contains?(url, "release.json") ->
            {:ok, %Req.Response{status: 200, body: manifest}}

          true ->
            {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      stub(Req, :get, fn url ->
        if String.contains?(url, "release.json") do
          {:ok, %Req.Response{status: 200, body: manifest}}
        else
          {:ok, %Req.Response{status: 404, body: nil}}
        end
      end)

      assert {:ok, releases} = Downloader.check_for_updates()

      {:ok, db_release} = Firmware.get_release(hd(releases).id, preload: [:firmware_files])

      # Should only have the device from manifest (uno), not leonardo
      assert length(db_release.firmware_files) == 1
      file = hd(db_release.firmware_files)
      assert file.environment == "uno"

      # Should have the custom filename from manifest
      assert file.download_url =~ "custom-uno.hex"
    end
  end
end
