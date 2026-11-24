defmodule Trenino.Firmware.Uploader do
  @moduledoc """
  Executes firmware uploads via avrdude.

  Handles building the avrdude command, executing it, parsing
  output for progress updates, and translating errors.
  """

  require Logger

  alias Trenino.Firmware.{Avrdude, AvrdudeRunner, DeviceRegistry}
  alias Trenino.Serial.Connection

  @type progress_callback :: (integer(), String.t() -> any())

  @type upload_result ::
          {:ok, %{duration_ms: integer(), output: String.t()}}
          | {:error, atom(), String.t()}

  # Known alternate baud rates by programmer type. The STK500v1 "arduino"
  # programmer ships at 115200 on new-bootloader Nanos (Optiboot) and
  # 57600 on old-bootloader clones.
  @alternate_baud_rates %{
    "arduino" => [57_600, 115_200]
  }

  @bootloader_initial_wait_ms 100
  @bootloader_poll_interval_ms 100
  # Windows installs the bootloader's driver the first time it appears, which
  # can take several seconds. The Arduino IDE waits up to 10 seconds too.
  @bootloader_poll_deadline_ms 10_000
  # The board takes ~500ms to drop off USB after the touch. Until then the
  # original port is still the running sketch, not the bootloader, so it is
  # only accepted once it has disappeared and come back, or after this grace
  # period for boards that are already in the bootloader and never reset.
  @bootloader_reset_grace_ms 2_000
  # A port can be listed before its driver accepts connections (Windows lists
  # the bootloader's COM port before usbser is ready, macOS reports "Resource
  # busy"). avrdude then gets no answer from the bootloader. The Arduino IDE
  # waits 250ms after the port appears; the bootloader stays up for 8 seconds.
  @bootloader_port_settle_ms 500

  @doc """
  Returns alternate baud rates to try for a programmer when the initial
  baud rate fails. Filters out the already-tried baud rate.
  """
  @spec retryable_baud_rates(String.t(), integer()) :: [integer()]
  def retryable_baud_rates(programmer, tried_baud_rate) do
    @alternate_baud_rates
    |> Map.get(programmer, [])
    |> Enum.reject(&(&1 == tried_baud_rate))
  end

  @doc """
  Upload firmware to a device.

  ## Parameters

    * `port` - Serial port (e.g., "/dev/cu.usbmodem14201")
    * `environment` - PlatformIO environment name (e.g., "uno", "leonardo")
    * `hex_file_path` - Path to the .hex firmware file
    * `progress_callback` - Optional function called with (percent, message)

  ## Returns

    * `{:ok, %{duration_ms: integer, output: String.t()}}` on success
    * `{:error, reason_atom, avrdude_output}` on failure
  """
  @spec upload(String.t(), String.t() | atom(), String.t(), progress_callback() | nil) ::
          upload_result()
  def upload(port, environment, hex_file_path, progress_callback \\ nil)

  # Backward compatibility: convert atom board_type to environment string
  def upload(port, environment, hex_file_path, progress_callback) when is_atom(environment) do
    upload(port, Atom.to_string(environment), hex_file_path, progress_callback)
  end

  def upload(port, environment, hex_file_path, progress_callback)
      when is_binary(environment) do
    start_time = System.monotonic_time(:millisecond)

    with {:ok, avrdude_path} <- Avrdude.executable_path(),
         {:ok, config} <- DeviceRegistry.get_device_config(environment),
         :ok <- verify_hex_file(hex_file_path),
         {:ok, upload_port} <- maybe_trigger_bootloader(port, config) do
      upload_with_retries(
        avrdude_path,
        config,
        upload_port,
        hex_file_path,
        progress_callback,
        start_time
      )
    else
      {:error, :unknown_device} ->
        {:error, :unknown_device, "Unknown device environment: #{environment}"}

      error ->
        error
    end
  end

  defp upload_with_retries(avrdude_path, config, port, hex_file_path, callback, start_time) do
    case attempt_upload(avrdude_path, config, port, hex_file_path, callback) do
      {:ok, output} ->
        finish_upload(output, start_time)

      {:error, :port_not_found, output} ->
        retry_port_not_found(
          avrdude_path,
          config,
          port,
          hex_file_path,
          callback,
          output,
          start_time
        )

      {:error, :bootloader_not_responding, output} ->
        retry_baud_rates(avrdude_path, config, port, hex_file_path, callback, output, start_time)

      {:error, error_type, output} ->
        {:error, error_type, output}
    end
  end

  # Run avrdude once with the given config, return {:ok, output} or {:error, type, output}
  defp attempt_upload(avrdude_path, config, port, hex_file_path, callback) do
    args = build_args(config, port, hex_file_path)
    Logger.info("Running avrdude: #{avrdude_path} #{Enum.join(args, " ")}")

    case AvrdudeRunner.run(avrdude_path, args, callback) do
      {:ok, output} ->
        {:ok, output}

      {:error, output} ->
        error_type = parse_error(output)
        Logger.warning("Avrdude failed with error: #{error_type}")
        Logger.warning("Avrdude output:\n#{output}")
        {:error, error_type, output}
    end
  end

  defp finish_upload(output, start_time) do
    duration_ms = System.monotonic_time(:millisecond) - start_time
    Logger.info("Avrdude completed successfully in #{duration_ms}ms")
    {:ok, %{duration_ms: duration_ms, output: output}}
  end

  # Retry once after a short delay — serial ports can be slow to appear
  defp retry_port_not_found(
         avrdude_path,
         config,
         port,
         hex_file_path,
         callback,
         first_output,
         start_time
       ) do
    Logger.warning("Port not found, retrying in 2 seconds...")
    report_progress(callback, 0, "Port not found, retrying...")
    Process.sleep(2_000)

    case attempt_upload(avrdude_path, config, port, hex_file_path, callback) do
      {:ok, output} -> finish_upload(output, start_time)
      {:error, _error_type, _output} -> {:error, :port_not_found, first_output}
    end
  end

  # Try alternate baud rates when the bootloader doesn't respond
  defp retry_baud_rates(
         avrdude_path,
         config,
         port,
         hex_file_path,
         callback,
         first_output,
         start_time
       ) do
    alternates = retryable_baud_rates(config.programmer, config.baud_rate)

    try_baud_rates(
      avrdude_path,
      config,
      port,
      hex_file_path,
      callback,
      alternates,
      first_output,
      start_time
    )
  end

  defp try_baud_rates(_avrdude_path, _config, _port, _hex, _cb, [], first_output, _start_time) do
    {:error, :bootloader_not_responding, first_output}
  end

  defp try_baud_rates(
         avrdude_path,
         config,
         port,
         hex,
         cb,
         [baud | rest],
         first_output,
         start_time
       ) do
    Logger.info("Retrying with alternate baud rate: #{baud}")
    report_progress(cb, 0, "Retrying at #{baud} baud...")
    alt_config = %{config | baud_rate: baud}

    case attempt_upload(avrdude_path, alt_config, port, hex, cb) do
      {:ok, output} ->
        finish_upload(output, start_time)

      {:error, :bootloader_not_responding, _output} ->
        try_baud_rates(avrdude_path, config, port, hex, cb, rest, first_output, start_time)

      {:error, error_type, output} ->
        {:error, error_type, output}
    end
  end

  defp report_progress(nil, _percent, _message), do: :ok
  defp report_progress(callback, percent, message), do: callback.(percent, message)

  # Trigger bootloader on boards that need 1200bps touch (Leonardo, Micro, Pro Micro)
  defp maybe_trigger_bootloader(port, %{use_1200bps_touch: true}) do
    Logger.info("Triggering bootloader with 1200bps touch on #{port}")

    ports_before =
      case get_available_ports() do
        {:ok, ports} -> ports
        :error -> :unknown
      end

    case Circuits.UART.start_link() do
      {:ok, uart} ->
        result =
          case Circuits.UART.open(uart, port, speed: 1200) do
            :ok ->
              Process.sleep(@bootloader_initial_wait_ms)
              Circuits.UART.close(uart)
              Logger.info("Waiting for bootloader to start...")
              touched_at = System.monotonic_time(:millisecond)
              poll_for_bootloader_port(port, ports_before, false, touched_at)

            {:error, reason} ->
              Logger.warning("Could not open port for 1200bps touch: #{inspect(reason)}")
              {:ok, port}
          end

        GenServer.stop(uart)
        result

      {:error, reason} ->
        Logger.warning("Could not start UART for 1200bps touch: #{inspect(reason)}")
        {:ok, port}
    end
  end

  defp maybe_trigger_bootloader(port, _config), do: {:ok, port}

  defp poll_for_bootloader_port(original_port, ports_before, seen_gone?, touched_at) do
    case get_available_ports() do
      # No baseline (enumeration failed before the touch): the first poll
      # where the original port is gone becomes the baseline, so only ports
      # appearing after it count as new. A bootloader port already visible in
      # that poll is not detected, which fails safe.
      {:ok, ports_after} when ports_before == :unknown ->
        if original_port in ports_after do
          check_bootloader_ports(original_port, :unknown, ports_after, seen_gone?, touched_at)
        else
          check_bootloader_ports(original_port, ports_after, ports_after, true, touched_at)
        end

      {:ok, ports_after} ->
        check_bootloader_ports(original_port, ports_before, ports_after, seen_gone?, touched_at)

      # Enumeration failed this round: retry without drawing conclusions about
      # which ports came or went.
      :error ->
        if System.monotonic_time(:millisecond) - touched_at >= @bootloader_poll_deadline_ms do
          {:error, :bootloader_port_not_found}
        else
          Process.sleep(@bootloader_poll_interval_ms)
          poll_for_bootloader_port(original_port, ports_before, seen_gone?, touched_at)
        end
    end
  end

  defp check_bootloader_ports(original_port, ports_before, ports_after, seen_gone?, touched_at) do
    new_ports = new_ports(ports_before, ports_after) -- [original_port]
    original_present? = original_port in ports_after
    elapsed_ms = System.monotonic_time(:millisecond) - touched_at

    cond do
      new_ports != [] ->
        new_ports |> pick_new_port(original_port) |> settle_port()

      original_present? and seen_gone? ->
        Logger.info("Bootloader re-enumerated on #{original_port}")
        settle_port({:ok, original_port})

      original_present? and elapsed_ms >= @bootloader_reset_grace_ms ->
        Logger.info("Original port #{original_port} never reset, using it")
        {:ok, original_port}

      elapsed_ms >= @bootloader_poll_deadline_ms ->
        Logger.warning("No ports available after bootloader trigger")
        {:error, :bootloader_port_not_found}

      true ->
        Process.sleep(@bootloader_poll_interval_ms)

        poll_for_bootloader_port(
          original_port,
          ports_before,
          seen_gone? or not original_present?,
          touched_at
        )
    end
  end

  # Without a baseline yet (see poll_for_bootloader_port/4), every port would
  # look new, so only the original port is considered.
  defp new_ports(:unknown, _ports_after), do: []
  defp new_ports(ports_before, ports_after), do: ports_after -- ports_before

  defp pick_new_port([new_port], original_port) do
    Logger.info("Bootloader appeared on new port #{new_port} (was #{original_port})")
    {:ok, new_port}
  end

  defp pick_new_port(new_ports, _original_port) do
    new_port = Enum.max(new_ports)
    Logger.info("Multiple new ports appeared, using #{new_port}")
    {:ok, new_port}
  end

  defp settle_port({:ok, _port} = result) do
    Process.sleep(@bootloader_port_settle_ms)
    result
  end

  defp get_available_ports do
    case Connection.list_ports() do
      {:ok, ports} ->
        {:ok, ports |> Map.keys() |> Enum.sort()}

      {:error, error} ->
        Logger.warning("Could not list serial ports: #{Exception.message(error)}")
        :error
    end
  end

  # Build avrdude command arguments
  defp build_args(config, port, hex_file_path) do
    conf_args =
      case Avrdude.conf_path() do
        {:ok, path} -> ["-C", path]
        {:error, :not_found} -> []
      end

    conf_args ++
      [
        "-c",
        config.programmer,
        "-p",
        config.mcu,
        "-P",
        port,
        "-b",
        to_string(config.baud_rate),
        "-D",
        "-U",
        "flash:w:#{avrdude_hex_path(hex_file_path)}:i",
        "-v"
      ]
  end

  # avrdude 8.x correctly parses Windows drive-letter paths in -U arguments,
  # so no transformation is needed. The bundled avrdude is always 8.x.
  @doc false
  def avrdude_hex_path(path), do: path

  # Verify the hex file exists and is readable
  defp verify_hex_file(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, :hex_file_not_found, "Firmware file not found: #{path}"}
    end
  end

  # Error patterns mapped to error atoms, matched case-insensitively (avrdude
  # 8.x capitalises the first word of each line). Patterns are lowercase.
  # Each pattern is either a string or a list of strings (all must match).
  # Order matters: more specific patterns should come before general ones.
  # Only avrdude's own English text is matched: the OS half of messages such
  # as "cannot open port COM3: <reason>" is localized on Windows.
  @error_patterns [
    {"permission denied", :permission_denied},
    {"can't open device", :port_not_found},
    {"cannot open port", :port_not_found},
    {"programmer is not responding", :bootloader_not_responding},
    {"not in sync", :bootloader_not_responding},
    {"cannot get into sync", :bootloader_not_responding},
    {"programmer is out of sync", :bootloader_not_responding},
    {"protocol expects sync byte", :bootloader_not_responding},
    {"cannot communicate with device", :bootloader_not_responding},
    {"timeout communicating with programmer", :bootloader_not_responding},
    {"timeout/error communicating with programmer", :bootloader_not_responding},
    {["stk500", "not responding"], :bootloader_not_responding},
    {"initialization failed", :bootloader_not_responding},
    {["butterfly", "avr910"], :bootloader_not_responding},
    # avrdude 6.x: "Yikes!  Invalid device signature." / "Expected signature
    # for ...". avrdude 8.x: "Error: invalid device signature" / "Error:
    # expected signature for ATmega328P is 1E 95 0F". The plain "Device
    # signature = ..." line is printed on every -v run and must not match.
    {"invalid device signature", :wrong_board_type},
    {"expected signature for", :wrong_board_type},
    # avrdude 6.x: "verification error"; avrdude 8.x: "flash verification mismatch"
    {"verification error", :verification_failed},
    {"verification mismatch", :verification_failed},
    # Appended by AvrdudeRunner when avrdude hangs. A bare "timeout" would also
    # match the "Timeout : 200" row of the part table older avrdude builds print.
    {"[timeout:", :timeout},
    # avrdude 8.x prints this whenever the programmer's open step fails,
    # including after sync failures, so it only applies when nothing above did.
    {"unable to open port", :port_not_found}
  ]

  # Failures caused by the user's hardware, cabling, board selection or
  # environment. They are shown to the user and kept in the upload history,
  # but are not bugs in Trenino, so they are not reported to Sentry. Any
  # reason not listed here (unknown_error, avrdude_not_found, crashes, new
  # atoms) is reported.
  @environment_errors [
    :port_not_found,
    :permission_denied,
    :bootloader_not_responding,
    :bootloader_port_not_found,
    :wrong_board_type,
    :verification_failed,
    :timeout,
    :cancelled
  ]

  @doc """
  Parse avrdude error output to determine the error type.
  """
  @spec parse_error_output(String.t()) :: atom()
  def parse_error_output(output) do
    output = String.downcase(output)

    Enum.find_value(@error_patterns, :unknown_error, fn
      {patterns, error} when is_list(patterns) ->
        if Enum.all?(patterns, &String.contains?(output, &1)), do: error

      {pattern, error} ->
        if String.contains?(output, pattern), do: error
    end)
  end

  @doc """
  Returns true when an upload failure reason is caused by the user's hardware
  or environment (wrong board, device absent or not responding, cancelled)
  rather than by a bug in Trenino.
  """
  @spec environment_error?(term()) :: boolean()
  def environment_error?(reason), do: reason in @environment_errors

  # Sentry's server-side scrubbing replaces a whole value with "[Filtered]"
  # when it contains any of these words, case-insensitively. Every avrdude 8.x
  # run prints "Copyright see https://github.com/avrdudes/avrdude/blob/main/AUTHORS",
  # which matches "auth".
  @sentry_sensitive_words ~r/password|secret|passwd|api_key|apikey|auth|credentials|mysql_pwd|privatekey|private_key|token|bearer/i
  @diagnostic_max_lines 40
  @diagnostic_max_bytes 4_000

  @doc """
  Returns the last lines of avrdude output in a form fit for error reports.

  Drops blank lines, the version and copyright banner, the informational
  configuration file lines and any line Sentry would scrub, then redacts user
  names in remaining paths (`C:\\Users\\<name>`, `/home/<name>`) and keeps at most
  #{@diagnostic_max_lines} lines and about #{@diagnostic_max_bytes} bytes (a
  UTF-8 character split by the cut becomes a replacement character).
  """
  @spec diagnostic_output(String.t() | nil) :: String.t() | nil
  def diagnostic_output(nil), do: nil

  def diagnostic_output(output) when is_binary(output) do
    output
    |> String.split(~r/\R/)
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.reject(&diagnostic_noise?/1)
    |> Enum.take(-@diagnostic_max_lines)
    |> Enum.map_join("\n", &redact_user_paths/1)
    |> take_trailing_bytes(@diagnostic_max_bytes)
  end

  defp diagnostic_noise?(line) do
    line == "" or
      String.starts_with?(line, [
        "Avrdude version",
        "avrdude version",
        "Copyright",
        "System wide configuration file is",
        "User configuration file"
      ]) or
      Regex.match?(@sentry_sensitive_words, line)
  end

  # Windows user names may contain spaces ("C:\Users\John Smith\..."), so the
  # name runs to the next separator. Unix names can't contain spaces.
  defp redact_user_paths(line) do
    line
    |> then(&Regex.replace(~r/([A-Za-z]:[\\\/]Users[\\\/])[^\\\/]+/i, &1, "\\1[user]"))
    |> then(
      &Regex.replace(~r{(/(?:Users|home|run/media|media)/)[^/\s:]+}i, &1, fn
        _, prefix -> prefix <> "[user]"
      end)
    )
  end

  defp take_trailing_bytes(string, max_bytes) when byte_size(string) <= max_bytes, do: string

  defp take_trailing_bytes(string, max_bytes) do
    string
    |> binary_part(byte_size(string) - max_bytes, max_bytes)
    |> String.replace_invalid()
  end

  # Keep private alias for internal use
  defp parse_error(output), do: parse_error_output(output)

  @doc """
  Returns a user-friendly error message for an error atom.
  """
  @spec error_message(atom()) :: String.t()
  def error_message(:port_not_found) do
    """
    Device not found. Please check:
    - Device is connected via USB
    - USB cable supports data (not charge-only)
    - Device appears in the connected devices list
    """
  end

  def error_message(:bootloader_not_responding) do
    """
    Bootloader not responding. For Pro Micro, Leonardo, and Micro boards:
    - Double-tap the reset button to enter bootloader mode
    - Start the upload within 8 seconds

    For other boards, verify:
    - Selected board type matches your physical board
    - Device is powered on and connected
    - Try a different USB port or cable
    """
  end

  def error_message(:wrong_board_type) do
    """
    Board type mismatch. The selected board type doesn't match
    the connected device. Please select the correct board type
    and try again.
    """
  end

  def error_message(:verification_failed) do
    """
    Upload verification failed. The firmware was written but
    could not be verified. This may be caused by:
    - Unstable USB connection
    - Power supply issues
    - Hardware defect

    Please try again with a different USB port or cable.
    """
  end

  def error_message(:timeout) do
    """
    Upload timed out. The device stopped responding during
    the upload process. Please:
    - Check the USB connection
    - Verify the board type is correct
    - Try a different USB port
    """
  end

  def error_message(:permission_denied) do
    """
    Permission denied accessing the serial port. You may need to:
    - Add your user to the dialout group (Linux)
    - Grant terminal access to serial ports (macOS)
    - Run as administrator (Windows)
    """
  end

  def error_message(:hex_file_not_found) do
    "Firmware file not found. Please download the firmware first."
  end

  def error_message(:avrdude_not_found) do
    """
    avrdude not found. Please ensure avrdude is installed:
    - macOS: brew install avrdude
    - Linux: apt-get install avrdude
    - Windows: Download from https://github.com/avrdudes/avrdude/releases
    """
  end

  def error_message(:bootloader_port_not_found) do
    """
    Bootloader port not found. The device disconnected but the bootloader
    did not appear on any port. Please try:
    - Double-tap the reset button to manually enter bootloader mode
    - Start the upload within 8 seconds
    - Try a different USB port
    """
  end

  def error_message(:unknown_device) do
    """
    Unknown device type. The selected device is not recognized.
    Please check for updates or try selecting a different board type.
    """
  end

  def error_message(:unknown_error) do
    "An unknown error occurred during upload. Please check the log for details."
  end

  def error_message(_) do
    "An unexpected error occurred."
  end
end
