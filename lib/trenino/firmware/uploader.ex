defmodule Trenino.Firmware.Uploader do
  @moduledoc """
  Executes firmware uploads via avrdude.

  Handles building the avrdude command, executing it, parsing
  output for progress updates, and translating errors.
  """

  require Logger

  alias Trenino.Firmware.{Avrdude, AvrdudeRunner, DeviceRegistry}

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
  @bootloader_poll_interval_ms 300
  @bootloader_poll_deadline_ms 5_000

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
        Logger.error("Avrdude failed with error: #{error_type}")
        Logger.error("Avrdude output:\n#{output}")
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
    ports_before = get_available_ports()

    case Circuits.UART.start_link() do
      {:ok, uart} ->
        result =
          case Circuits.UART.open(uart, port, speed: 1200) do
            :ok ->
              Process.sleep(@bootloader_initial_wait_ms)
              Circuits.UART.close(uart)
              Logger.info("Waiting for bootloader to start...")
              deadline = System.monotonic_time(:millisecond) + @bootloader_poll_deadline_ms
              poll_for_bootloader_port(port, ports_before, deadline)

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

  defp poll_for_bootloader_port(original_port, ports_before, deadline) do
    ports_after = get_available_ports()
    new_ports = ports_after -- ports_before

    cond do
      length(new_ports) == 1 ->
        [new_port] = new_ports
        Logger.info("Bootloader appeared on new port #{new_port} (was #{original_port})")
        {:ok, new_port}

      length(new_ports) > 1 ->
        new_port = Enum.max(new_ports)
        Logger.info("Multiple new ports appeared, using #{new_port}")
        {:ok, new_port}

      original_port in ports_after ->
        Logger.info("Original port #{original_port} still available, using it")
        {:ok, original_port}

      System.monotonic_time(:millisecond) >= deadline ->
        Logger.error("No ports available after bootloader trigger")
        {:error, :bootloader_port_not_found}

      true ->
        Process.sleep(@bootloader_poll_interval_ms)
        poll_for_bootloader_port(original_port, ports_before, deadline)
    end
  end

  defp get_available_ports do
    Circuits.UART.enumerate()
    |> Map.keys()
    |> Enum.sort()
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

  # Error patterns mapped to error atoms
  # Each pattern is either a string or a list of strings (all must match)
  # Order matters: more specific patterns should come before general ones
  @error_patterns [
    {"permission denied", :permission_denied},
    {"can't open device", :port_not_found},
    {"cannot open port", :port_not_found},
    {"programmer is not responding", :bootloader_not_responding},
    {"not in sync", :bootloader_not_responding},
    {["stk500", "not responding"], :bootloader_not_responding},
    {"initialization failed", :bootloader_not_responding},
    {["butterfly", "AVR910"], :bootloader_not_responding},
    {"device signature", :wrong_board_type},
    {"verification error", :verification_failed},
    {"Timeout", :timeout}
  ]

  @doc """
  Parse avrdude error output to determine the error type.
  """
  @spec parse_error_output(String.t()) :: atom()
  def parse_error_output(output) do
    Enum.find_value(@error_patterns, :unknown_error, fn
      {patterns, error} when is_list(patterns) ->
        if Enum.all?(patterns, &String.contains?(output, &1)), do: error

      {pattern, error} ->
        if String.contains?(output, pattern), do: error
    end)
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
