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

  # avrdude 8.1 transcripts as produced by the bundled Windows build with -v.
  # Every 8.x run starts with the version and copyright banner and prints the
  # configuration file paths, which include the user's home directory.

  @avrdude8_banner """
  Avrdude version 8.1
  Copyright see https://github.com/avrdudes/avrdude/blob/main/AUTHORS

  System wide configuration file is C:\\Users\\alice\\AppData\\Local\\Trenino\\avrdude.conf
  User configuration file C:\\Users\\alice\\.avrduderc does not exist

  """

  @doc "avrdude 8.1: Uno selected but the board never answers the STK500 sync."
  def avrdude8_sync_failure do
    @avrdude8_banner <>
      """
      Using port            : COM3
      Using programmer      : arduino
      Setting baud rate     : 115200
      Error: programmer is not responding
      Warning: attempt 1 of 10: not in sync: resp=0x00
      Error: programmer is not responding
      Warning: attempt 10 of 10: not in sync: resp=0x00
      Error: unable to open port COM3 for programmer arduino

      Avrdude done.  Thank you.

      [avrdude exited with status 1]
      """
  end

  @doc "avrdude 8.1: board answers but its MCU is not the selected one."
  def avrdude8_signature_mismatch do
    @avrdude8_banner <>
      """
      Using port            : COM3
      Using programmer      : arduino
      AVR part              : ATmega328P
      Device signature = 1E 95 16 (ATmega328PB)
      Error: expected signature for ATmega328P is 1E 95 0F
        - double check chip or use -F to carry on regardless

      Avrdude done.  Thank you.
      """
  end

  @doc "avrdude 8.1: flash written but read-back differs."
  def avrdude8_verification_mismatch do
    @avrdude8_banner <>
      """
      Device signature = 1E 95 0F (ATmega328P)
      Writing 924 bytes to flash
      Reading | ################################################## | 100% 0.12s
      Error: flash verification mismatch
        device 0x1c != input 0x3c at addr 0x0100 (error)

      Avrdude done.  Thank you.
      """
  end

  @doc "avrdude 8.1: Mega (wiring/stk500v2) bootloader never answers."
  def avrdude8_stk500v2_timeout do
    @avrdude8_banner <>
      """
      Using port            : COM5
      Using programmer      : wiring
      Error: timeout communicating with programmer
      Error: unable to open port COM5 for programmer wiring
      """
  end

  @doc "avrdude 8.1: port missing; the OS reason is localized on Windows."
  def avrdude8_port_missing_localized do
    @avrdude8_banner <>
      """
      Using port            : COM3
      Error: cannot open port \\\\.\\COM3: Das System kann die angegebene Datei nicht finden.
      Error: unable to open port COM3 for programmer arduino
      """
  end

  @doc "avrdude 8.1: config file could not be processed (a Trenino bundling bug)."
  def avrdude8_config_error do
    @avrdude8_banner <>
      """
      Error: unable to process system wide configuration file C:\\Users\\alice\\AppData\\Local\\Trenino\\avrdude.conf

      [avrdude exited with status 1]
      """
  end
end
