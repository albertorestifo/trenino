defmodule Trenino.Firmware.AvrdudeRunnerTest do
  use Trenino.DataCase, async: true

  alias Trenino.Firmware.AvrdudeRunner

  describe "run/3" do
    test "replaces invalid UTF-8 bytes echoed from the device" do
      # A running sketch answering avr109 commands produces raw bytes such as 0x80.
      script = ~S"printf 'Programmer id = \200;\n'; exit 1"

      # Bypasses the ForbiddenAvrdudeRunner guard on purpose: this spawns
      # /bin/sh, never avrdude, so no hardware is touched.
      assert {:error, output} =
               Mimic.call_original(AvrdudeRunner, :run, ["/bin/sh", ["-c", script], nil])

      assert String.valid?(output)
      assert output =~ "Programmer id = "
    end
  end
end
