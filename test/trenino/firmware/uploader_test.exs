defmodule Trenino.Firmware.UploaderTest do
  use ExUnit.Case, async: true

  alias Trenino.Firmware.Avrdude
  alias Trenino.Firmware.Uploader

  describe "error_message/1" do
    test "returns message for :port_not_found" do
      message = Uploader.error_message(:port_not_found)

      assert message =~ "Device not found"
      assert message =~ "USB cable"
    end

    test "returns message for :bootloader_not_responding" do
      message = Uploader.error_message(:bootloader_not_responding)

      assert message =~ "Bootloader not responding"
      assert message =~ "board type"
    end

    test "returns message for :wrong_board_type" do
      message = Uploader.error_message(:wrong_board_type)

      assert message =~ "Board type mismatch"
    end

    test "returns message for :verification_failed" do
      message = Uploader.error_message(:verification_failed)

      assert message =~ "verification failed"
      assert message =~ "USB connection"
    end

    test "returns message for :timeout" do
      message = Uploader.error_message(:timeout)

      assert message =~ "timed out"
    end

    test "returns message for :permission_denied" do
      message = Uploader.error_message(:permission_denied)

      assert message =~ "Permission denied"
    end

    test "returns message for :hex_file_not_found" do
      message = Uploader.error_message(:hex_file_not_found)

      assert message =~ "Firmware file not found"
    end

    test "returns message for :avrdude_not_found" do
      message = Uploader.error_message(:avrdude_not_found)

      assert message =~ "avrdude not found"
    end

    test "returns message for :unknown_error" do
      message = Uploader.error_message(:unknown_error)

      assert message =~ "unknown error"
    end

    test "returns message for :unknown_device" do
      message = Uploader.error_message(:unknown_device)

      assert message =~ "Unknown device type"
      assert message =~ "not recognized"
    end

    test "returns generic message for unhandled atoms" do
      message = Uploader.error_message(:some_other_error)

      assert message =~ "unexpected error"
    end
  end

  # Testing parse_error indirectly through behavior - these would be tested
  # via integration tests with actual avrdude output, but we can test the
  # error classification logic patterns
  describe "parse_error_output/1" do
    test "detects port not found from 'can't open device'" do
      output = "avrdude: can't open device /dev/ttyUSB0: No such file"
      assert Uploader.parse_error_output(output) == :port_not_found
    end

    test "detects port not found from 'cannot open port'" do
      output = "error: cannot open port /dev/ttyUSB0"
      assert Uploader.parse_error_output(output) == :port_not_found
    end

    test "detects bootloader not responding from 'programmer is not responding'" do
      output = "avrdude: stk500_recv(): programmer is not responding"
      assert Uploader.parse_error_output(output) == :bootloader_not_responding
    end

    test "detects bootloader not responding from 'not in sync'" do
      output = "avrdude: stk500_getsync(): not in sync: resp=0x00"
      assert Uploader.parse_error_output(output) == :bootloader_not_responding
    end

    test "detects bootloader not responding from stk500 not responding" do
      output = "avrdude: stk500v2_recv(): not responding"
      assert Uploader.parse_error_output(output) == :bootloader_not_responding
    end

    test "detects bootloader not responding from 'initialization failed'" do
      output = "avrdude: initialization failed, rc=-1"
      assert Uploader.parse_error_output(output) == :bootloader_not_responding
    end

    test "detects bootloader not responding from butterfly/AVR910 protocol" do
      output = "butterfly and AVR910 mode"
      assert Uploader.parse_error_output(output) == :bootloader_not_responding
    end

    test "detects wrong board type from device signature" do
      output = "avrdude: device signature = 0x1e950f"
      assert Uploader.parse_error_output(output) == :wrong_board_type
    end

    test "detects verification failed" do
      output = "avrdude: verification error, first mismatch at byte 0x0100"
      assert Uploader.parse_error_output(output) == :verification_failed
    end

    test "detects timeout" do
      output = "[Timeout: avrdude did not respond within 2 minutes]"
      assert Uploader.parse_error_output(output) == :timeout
    end

    test "detects permission denied" do
      output = "avrdude: ser_open(): permission denied accessing /dev/ttyUSB0"
      assert Uploader.parse_error_output(output) == :permission_denied
    end

    test "returns unknown_error for unrecognized output" do
      output = "some random error that doesn't match patterns"
      assert Uploader.parse_error_output(output) == :unknown_error
    end
  end

  describe "progress parsing patterns" do
    test "writing progress pattern matches avrdude output" do
      line = "Writing | ################################################## | 100% 1.15s"
      assert Regex.match?(~r/(Reading|Writing|Verifying)\s+\|.*?\|\s+(\d+)%/, line)
    end

    test "reading progress pattern matches avrdude output" do
      line = "Reading | ########################                           | 45% 0.23s"
      assert Regex.match?(~r/(Reading|Writing|Verifying)\s+\|.*?\|\s+(\d+)%/, line)
    end

    test "verifying progress pattern matches avrdude output" do
      line = "Verifying | ################################################## | 100% 0.15s"
      assert Regex.match?(~r/(Reading|Writing|Verifying)\s+\|.*?\|\s+(\d+)%/, line)
    end

    test "extracts operation and percentage from progress line" do
      line = "Writing | ##################                                 | 35% 0.42s"

      case Regex.run(~r/(Reading|Writing|Verifying)\s+\|.*?\|\s+(\d+)%/, line) do
        [_, operation, percent_str] ->
          assert operation == "Writing"
          assert percent_str == "35"

        nil ->
          flunk("Regex should match progress line")
      end
    end
  end

  describe "upload/4 with missing hex file" do
    @tag :skip_without_avrdude
    test "returns error when hex file doesn't exist with environment string" do
      # Skip this test if avrdude is not available
      case Avrdude.executable_path() do
        {:ok, _} ->
          result = Uploader.upload("/dev/ttyUSB0", "uno", "/nonexistent/firmware.hex")

          assert {:error, :hex_file_not_found, message} = result
          assert message =~ "not found"

        {:error, :avrdude_not_found} ->
          # Expected on CI systems without avrdude
          :ok
      end
    end

    @tag :skip_without_avrdude
    test "returns error when hex file doesn't exist with legacy board_type atom" do
      # Skip this test if avrdude is not available
      case Avrdude.executable_path() do
        {:ok, _} ->
          result = Uploader.upload("/dev/ttyUSB0", :uno, "/nonexistent/firmware.hex")

          assert {:error, :hex_file_not_found, message} = result
          assert message =~ "not found"

        {:error, :avrdude_not_found} ->
          # Expected on CI systems without avrdude
          :ok
      end
    end

    @tag :skip_without_avrdude
    test "returns error for unknown environment" do
      case Avrdude.executable_path() do
        {:ok, _} ->
          # Create a dummy hex file for testing
          hex_file = "/tmp/test_firmware.hex"
          File.write!(hex_file, ":00000001FF\n")

          result = Uploader.upload("/dev/ttyUSB0", "unknown_board", hex_file)

          assert {:error, :unknown_device, message} = result
          assert message =~ "Unknown device environment"

          File.rm(hex_file)

        {:error, :avrdude_not_found} ->
          :ok
      end
    end
  end

  describe "environment string support" do
    test "accepts environment strings for upload/4" do
      # These tests verify the function signature accepts environment strings
      # Actual upload testing requires hardware and is done in integration tests

      environments = [
        "uno",
        "nanoatmega328",
        "leonardo",
        "micro",
        "sparkfun_promicro16",
        "megaatmega2560"
      ]

      for env <- environments do
        # Verify the function accepts the environment string
        # This will fail if DeviceRegistry doesn't know about it or hex file doesn't exist
        # but that's a different error than invalid argument type
        result = Uploader.upload("/dev/null", env, "/nonexistent.hex")

        # Should get hex_file_not_found or similar, not a function clause error
        assert match?({:error, _, _}, result)
      end
    end
  end

  describe "backward compatibility with board_type atoms" do
    test "converts legacy board_type atoms to environment strings" do
      # These should be converted internally
      legacy_types = [
        {:uno, "uno"},
        {:nano, "nanoatmega328"},
        {:leonardo, "leonardo"},
        {:micro, "micro"},
        {:mega2560, "megaatmega2560"},
        {:sparkfun_pro_micro, "sparkfun_promicro16"}
      ]

      for {board_type, _expected_env} <- legacy_types do
        # Verify the function accepts legacy board_type atoms
        result = Uploader.upload("/dev/null", board_type, "/nonexistent.hex")

        # Should get hex_file_not_found or similar, not a function clause error
        assert match?({:error, _, _}, result)
      end
    end
  end
end
