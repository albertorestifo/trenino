defmodule Trenino.Firmware.AvrdudeRunner do
  @moduledoc """
  Executes avrdude as a subprocess and collects its output.

  Isolated into its own module so tests can stub it via Mimic,
  allowing the retry logic in Uploader to be exercised without
  spawning real processes.
  """

  @type progress_callback :: (integer(), String.t() -> any())

  @collect_timeout_ms 120_000

  @doc """
  Runs avrdude with the given arguments and collects all output.

  Returns `{:ok, output}` on exit status 0 or `{:error, output}` on non-zero exit.
  Calls `progress_callback.(percent, message)` for each progress line detected.
  """
  @spec run(String.t(), [String.t()], progress_callback() | nil) ::
          {:ok, String.t()} | {:error, String.t()}
  def run(avrdude_path, args, progress_callback) do
    port =
      Port.open({:spawn_executable, avrdude_path}, [
        :binary,
        :exit_status,
        :stderr_to_stdout,
        args: args
      ])

    collect_output(port, "", progress_callback)
  end

  # avrdude echoes raw bytes from the device (e.g. a running sketch answering
  # bootloader commands), so the output is not guaranteed to be valid UTF-8.
  # Sanitize it before it reaches Logger, the database or Sentry.
  defp collect_output(port, acc, progress_callback) do
    receive do
      {^port, {:data, data}} ->
        new_acc = acc <> data
        if progress_callback, do: parse_progress(data, progress_callback)
        collect_output(port, new_acc, progress_callback)

      {^port, {:exit_status, 0}} ->
        {:ok, String.replace_invalid(acc)}

      {^port, {:exit_status, _code}} ->
        {:error, String.replace_invalid(acc)}
    after
      @collect_timeout_ms ->
        Port.close(port)

        {:error,
         String.replace_invalid(acc) <> "\n[Timeout: avrdude did not respond within 2 minutes]"}
    end
  end

  defp parse_progress(data, callback) do
    lines = String.split(data, "\n")

    Enum.each(lines, fn line ->
      case Regex.run(~r/(Reading|Writing|Verifying)\s+\|.*?\|\s+(\d+)%/, line) do
        [_, operation, percent_str] ->
          percent = String.to_integer(percent_str)
          callback.(percent, format_operation(operation, percent))

        nil ->
          :ok
      end
    end)
  end

  defp format_operation("Reading", _percent), do: "Reading device..."
  defp format_operation("Writing", percent), do: "Writing flash (#{percent}%)"
  defp format_operation("Verifying", percent), do: "Verifying (#{percent}%)"
end
