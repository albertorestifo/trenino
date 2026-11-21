defmodule Trenino.SentryFilter do
  @moduledoc """
  Recognises Sentry events that report conditions outside Trenino's control,
  so `Trenino.Settings.sentry_before_send/1` can drop them.

  Keep every rule narrow: match on the crashing library and the exact reason,
  never on a broad message pattern that could hide a real Trenino bug.
  """

  alias Sentry.Event
  alias Sentry.Interfaces.Message

  @doc """
  Returns `true` when the event is known noise.

  Rules:

    * A `Circuits.UART` GenServer stopping with `:port_timed_out`. The library
      exits inside its own `handle_call` when its native port does not answer
      within 4 s (a flaky or unplugged USB device), so OTP always logs a crash
      report for the UART process. `Trenino.Serial.Connection` traps that exit
      and treats it as a failed connection.
  """
  @spec drop?(term()) :: boolean()
  def drop?(%Event{} = event), do: uart_port_timeout?(event)
  def drop?(_event), do: false

  defp uart_port_timeout?(%Event{extra: extra} = event) when is_map(extra) do
    crash_reason(extra) == ":port_timed_out" and
      (circuits_uart?(event.culprit) or circuits_uart?(message_text(event.message)))
  end

  defp uart_port_timeout?(_event), do: false

  defp crash_reason(extra), do: Map.get(extra, :crash_reason) || Map.get(extra, "crash_reason")

  defp message_text(%Message{formatted: formatted}), do: formatted
  defp message_text(message) when is_binary(message), do: message
  defp message_text(_message), do: nil

  defp circuits_uart?(text) when is_binary(text), do: String.contains?(text, "Circuits.UART.")
  defp circuits_uart?(_text), do: false
end
