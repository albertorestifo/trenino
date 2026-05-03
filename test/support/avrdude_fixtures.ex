defmodule Trenino.AvrdudeFixtures do
  @moduledoc """
  Pre-recorded avrdude transcript strings for use in upload flow tests.
  Each function returns the exact stdout+stderr output avrdude produces
  for that scenario, matching the patterns in Uploader.@error_patterns.
  """

  @doc "Clean successful upload — avrdude exits 0."
  def successful_upload do
    """
    avrdude: Version 7.1, compiled on Mar 10 2023 at 12:30:00

    avrdude: AVR device initialized and ready to accept instructions
    Reading | ################################################## | 100% 0.00s

    avrdude: device signature = 0x1e9514 (probably m32u4)
    avrdude: erasing chip
    avrdude: reading input file "firmware.hex"
    avrdude: writing flash (28672 bytes):

    Writing | ################################################## | 100% 6.05s

    avrdude: 28672 bytes of flash written
    avrdude: verifying flash memory against firmware.hex:

    Verifying | ################################################## | 100% 2.01s

    avrdude: 28672 bytes of flash verified

    avrdude done.  Thank you.
    """
  end

  @doc "Old-bootloader Nano fails at 115200 baud — triggers baud-rate retry path."
  def old_bootloader_nano_115200_fail do
    """
    avrdude: stk500_getsync() attempt 1 of 10: not in sync: resp=0x00
    avrdude: stk500_getsync() attempt 2 of 10: not in sync: resp=0x00
    avrdude: stk500_getsync() attempt 3 of 10: not in sync: resp=0x00
    avrdude: stk500_recv(): programmer is not responding
    avrdude: stk500_getsync(): not in sync: resp=0x00
    """
  end

  @doc "Port not found — device unplugged or wrong COM port."
  def port_not_found do
    """
    avrdude: ser_open(): can't open device "/dev/ttyUSB0": No such file or directory
    """
  end

  @doc "Permission denied accessing serial port."
  def permission_denied do
    """
    avrdude: ser_open(): permission denied accessing /dev/ttyUSB0
    """
  end

  @doc "Wrong board selected — device signature does not match expected MCU."
  def device_signature_mismatch do
    """
    avrdude: AVR device initialized and ready to accept instructions
    Reading | ################################################## | 100% 0.00s

    avrdude: device signature = 0x1e9514 (probably m32u4)
    avrdude: Expected signature for ATmega328P is 1E 95 0F
             Double check chip, or use -F to override this check.
    """
  end

  @doc "Flash written but verify failed — unstable USB connection."
  def verification_error do
    """
    avrdude: writing flash (28672 bytes):

    Writing | ################################################## | 100% 6.05s

    avrdude: verification error, first mismatch at byte 0x0100
             0x3c != 0x1c
    avrdude: verification error; content mismatch
    """
  end

  @doc "Bootloader not responding — avr109 programmer on Micro/Leonardo."
  def bootloader_not_responding do
    """
    avrdude: butterfly_recv(): programmer is not responding
    avrdude: error: programmer did not respond to command: get sync
    """
  end
end
