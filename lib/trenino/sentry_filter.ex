defmodule Trenino.SentryFilter do
  @moduledoc """
  Recognises Sentry events that report conditions outside Trenino's control,
  so `Trenino.Settings.sentry_before_send/1` can drop them.

  Keep every rule narrow: match on the crashing library and the exact reason,
  never on a broad message pattern that could hide a real Trenino bug.
  """

  alias Sentry.Event
  alias Sentry.Interfaces.Message

  # Sentry runs before_send on the full event, so `original_exception` holds the
  # raised struct. Socket errors that mean the client (the desktop webview or a browser tab)
  # went away mid-request. Same list Bandit uses for its `:log_client_closures`.
  @client_closure_errors [:closed, :enotconn, :einval, :econnaborted, :econnreset]

  # A ThousandIsland connection process stops with the raw reason of a
  # `{:tcp_error, socket, reason}` message. Only an abortive close by the peer.
  @connection_abort_reasons [":econnaborted", ":econnreset"]

  @doc """
  Returns `true` when the event is known noise.

  Rules:

    * A `Circuits.UART` GenServer stopping with `:port_timed_out`. The library
      exits inside its own `handle_call` when its native port does not answer
      within 4 s (a flaky or unplugged USB device), so OTP always logs a crash
      report for the UART process. `Trenino.Serial.Connection` traps that exit
      and treats it as a failed connection.
    * A ThousandIsland HTTP connection process stopping with `:econnaborted`
      or `:econnreset`. ThousandIsland stops the connection with the socket's
      error reason when the client aborts the TCP connection (common on
      Windows when the webview reloads or closes), so OTP logs a crash report.
    * A `Bandit.TransportError` for a client closure, raised by `Plug.Conn`
      when Bandit cannot write a response because the client already closed
      the socket. Bandit itself stays silent about these; only
      `Sentry.PlugCapture` reports them.
  """
  @spec drop?(term()) :: boolean()
  def drop?(%Event{} = event) do
    uart_port_timeout?(event) or connection_aborted?(event) or client_closed_transport?(event)
  end

  def drop?(_event), do: false

  defp uart_port_timeout?(%Event{extra: extra} = event) when is_map(extra) do
    crash_reason(extra) == ":port_timed_out" and
      (circuits_uart?(event.culprit) or circuits_uart?(message_text(event.message)))
  end

  defp uart_port_timeout?(_event), do: false

  defp connection_aborted?(%Event{extra: extra} = event) when is_map(extra) do
    crash_reason(extra) in @connection_abort_reasons and
      thousand_island_connection?(message_text(event.message))
  end

  defp connection_aborted?(_event), do: false

  defp client_closed_transport?(%Event{original_exception: %Bandit.TransportError{error: error}}),
    do: error in @client_closure_errors

  defp client_closed_transport?(_event), do: false

  defp crash_reason(extra), do: Map.get(extra, :crash_reason) || Map.get(extra, "crash_reason")

  defp message_text(%Message{formatted: formatted}), do: formatted
  defp message_text(message) when is_binary(message), do: message
  defp message_text(_message), do: nil

  defp circuits_uart?(text) when is_binary(text), do: String.contains?(text, "Circuits.UART.")
  defp circuits_uart?(_text), do: false

  defp thousand_island_connection?(text) when is_binary(text),
    do: String.contains?(text, "Process Label: {:thousand_island, :connection,")

  defp thousand_island_connection?(_text), do: false
end
