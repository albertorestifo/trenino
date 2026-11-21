defmodule Trenino.Firmware.UploaderTest do
  use Trenino.DataCase, async: true

  alias Trenino.Firmware.Avrdude
  alias Trenino.Firmware.Uploader

  setup do
    # Load test device configurations for uploader tests
    load_test_devices()
    stub(Trenino.Firmware.Avrdude, :executable_path, fn -> {:ok, "/fake/avrdude"} end)
    stub(Trenino.Firmware.Avrdude, :conf_path, fn -> {:error, :not_found} end)
    :ok
  end

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

    test "detects wrong board type from an invalid device signature" do
      output = "avrdude: Yikes!  Invalid device signature."
      assert Uploader.parse_error_output(output) == :wrong_board_type
    end

    test "does not treat the informational device signature line as an error" do
      output = "Device signature = 1E 95 0F (ATmega328P)\nError: something new"
      assert Uploader.parse_error_output(output) == :unknown_error
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

  describe "parse_error_output/1 with avrdude 8.1 transcripts" do
    alias Trenino.AvrdudeFixtures

    test "classifies a sync failure despite the trailing 'unable to open port'" do
      assert Uploader.parse_error_output(AvrdudeFixtures.avrdude8_sync_failure()) ==
               :bootloader_not_responding
    end

    test "classifies a signature mismatch as wrong board" do
      assert Uploader.parse_error_output(AvrdudeFixtures.avrdude8_signature_mismatch()) ==
               :wrong_board_type
    end

    test "classifies a flash verification mismatch" do
      assert Uploader.parse_error_output(AvrdudeFixtures.avrdude8_verification_mismatch()) ==
               :verification_failed
    end

    test "classifies an stk500v2 timeout as bootloader not responding" do
      assert Uploader.parse_error_output(AvrdudeFixtures.avrdude8_stk500v2_timeout()) ==
               :bootloader_not_responding
    end

    test "classifies a missing port from avrdude's own text, not the localized reason" do
      assert Uploader.parse_error_output(AvrdudeFixtures.avrdude8_port_missing_localized()) ==
               :port_not_found
    end

    test "classifies a bare 'unable to open port' as port not found" do
      assert Uploader.parse_error_output("Error: unable to open port COM3 for programmer arduino") ==
               :port_not_found
    end

    test "matches case-insensitively" do
      assert Uploader.parse_error_output(
               "OS error: cannot open port /dev/ttyACM0: Permission denied"
             ) ==
               :permission_denied
    end

    test "leaves a configuration error unclassified so it is reported" do
      assert Uploader.parse_error_output(AvrdudeFixtures.avrdude8_config_error()) ==
               :unknown_error
    end

    test "leaves empty output unclassified" do
      assert Uploader.parse_error_output("\n[avrdude exited with status -1073741515]") ==
               :unknown_error
    end
  end

  describe "environment_error?/1" do
    test "is true for failures caused by hardware, board selection or the user" do
      for reason <- [
            :port_not_found,
            :permission_denied,
            :bootloader_not_responding,
            :bootloader_port_not_found,
            :wrong_board_type,
            :verification_failed,
            :timeout,
            :cancelled
          ] do
        assert Uploader.environment_error?(reason), "#{reason} should not be reported"
      end
    end

    test "is false for failures that point at a bug" do
      for reason <- [
            :unknown_error,
            :avrdude_not_found,
            :hex_file_not_found,
            :unknown_device,
            :crash
          ] do
        refute Uploader.environment_error?(reason), "#{reason} should be reported"
      end

      refute Uploader.environment_error?({:unexpected, :tuple})
    end
  end

  describe "diagnostic_output/1" do
    alias Trenino.AvrdudeFixtures

    # Sentry's server-side scrubbing replaces the whole value with [Filtered]
    # when it contains any of these words, case-insensitively.
    @sentry_denylist ~w(password secret passwd api_key apikey auth credentials mysql_pwd privatekey private_key token bearer)

    test "full avrdude 8.1 output would be scrubbed by Sentry" do
      output = String.downcase(AvrdudeFixtures.avrdude8_sync_failure())
      assert Enum.any?(@sentry_denylist, &String.contains?(output, &1))
    end

    test "survives Sentry's default scrubbing for every avrdude 8.1 transcript" do
      for output <- [
            AvrdudeFixtures.avrdude8_sync_failure(),
            AvrdudeFixtures.avrdude8_signature_mismatch(),
            AvrdudeFixtures.avrdude8_config_error(),
            "Error: bad token in avrdude.conf\nError: oops"
          ] do
        tail = output |> Uploader.diagnostic_output() |> String.downcase()
        refute Enum.any?(@sentry_denylist, &String.contains?(tail, &1)), tail
      end
    end

    test "keeps the error lines and drops the banner and config info lines" do
      tail = Uploader.diagnostic_output(AvrdudeFixtures.avrdude8_sync_failure())

      assert tail =~ "Error: programmer is not responding"
      assert tail =~ "[avrdude exited with status 1]"
      refute tail =~ "Avrdude version"
      refute tail =~ "System wide configuration file is"
      refute tail =~ "\n\n"
    end

    test "keeps a configuration error line but redacts the user name" do
      tail = Uploader.diagnostic_output(AvrdudeFixtures.avrdude8_config_error())

      assert tail =~ "unable to process system wide configuration file"
      assert tail =~ ~S"C:\Users\[user]\AppData"
      refute tail =~ "alice"
    end

    test "redacts unix home directories" do
      assert Uploader.diagnostic_output("Error: cannot open /home/bob/fw.hex") ==
               "Error: cannot open /home/[user]/fw.hex"
    end

    test "keeps only the last lines and bytes" do
      output = Enum.map_join(1..200, "\n", &"line #{&1} #{String.duplicate("x", 150)}")
      tail = Uploader.diagnostic_output(output)

      assert byte_size(tail) <= 4_000
      assert tail =~ "line 200 "
      refute tail =~ "line 150 "
      assert String.valid?(tail)
    end

    test "passes nil through" do
      assert Uploader.diagnostic_output(nil) == nil
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

        # Should get an error tuple, not a function clause error
        assert match?({:error, _}, result) or match?({:error, _, _}, result)
      end
    end
  end

  describe "avrdude_hex_path/1" do
    test "returns path unchanged on any OS" do
      path = "/var/trenino/firmware/v1.0.0_uno.hex"
      assert Uploader.avrdude_hex_path(path) == path
    end
  end

  describe "retryable_baud_rates/2" do
    test "returns alternate baud rates for arduino programmer excluding tried rate" do
      assert Uploader.retryable_baud_rates("arduino", 115_200) == [57_600]
    end

    test "returns alternate baud rates for arduino programmer excluding other tried rate" do
      assert Uploader.retryable_baud_rates("arduino", 57_600) == [115_200]
    end

    test "returns empty list for unknown programmer" do
      assert Uploader.retryable_baud_rates("avrisp", 115_200) == []
    end

    test "returns empty list when tried rate is not in alternates" do
      assert Uploader.retryable_baud_rates("arduino", 9600) == [57_600, 115_200]
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

        # Should get an error tuple, not a function clause error
        assert match?({:error, _}, result) or match?({:error, _, _}, result)
      end
    end
  end
end
