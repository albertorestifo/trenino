defmodule Trenino.SentryFilterTest do
  use ExUnit.Case, async: true

  alias Sentry.Event
  alias Sentry.Interfaces.Message
  alias Trenino.SentryFilter

  # Shape produced by Sentry.LoggerHandler for the Circuits.UART crash report
  # (Sentry issue TRENINO-1).
  @uart_report """
  GenServer #PID<0.1028.0> terminating
  ** (stop) :port_timed_out
      (circuits_uart 1.7.0) lib/circuits_uart.ex:615: Circuits.UART.call_port/4
      (circuits_uart 1.7.0) lib/circuits_uart.ex:412: Circuits.UART.handle_call/3
  Last message (from Trenino.Serial.Connection): {:open, "COM11", []}
  """

  defp event(attrs) do
    struct!(%Event{event_id: "0", timestamp: "0"}, attrs)
  end

  describe "drop?/1" do
    test "drops the Circuits.UART :port_timed_out crash report" do
      assert SentryFilter.drop?(
               event(
                 message: %Message{formatted: @uart_report},
                 extra: %{crash_reason: ":port_timed_out"}
               )
             )
    end

    test "drops it when only the culprit names Circuits.UART" do
      assert SentryFilter.drop?(
               event(
                 culprit: "Circuits.UART.call_port/4",
                 extra: %{crash_reason: ":port_timed_out"}
               )
             )
    end

    test "keeps a :port_timed_out crash that is not from Circuits.UART" do
      refute SentryFilter.drop?(
               event(
                 message: %Message{formatted: "GenServer Trenino.Serial.Connection terminating"},
                 culprit: "Trenino.Serial.Connection.handle_call/3",
                 extra: %{crash_reason: ":port_timed_out"}
               )
             )
    end

    test "keeps other Circuits.UART crashes" do
      refute SentryFilter.drop?(
               event(
                 message: %Message{formatted: @uart_report},
                 extra: %{crash_reason: ":einval"}
               )
             )
    end

    test "keeps events that are not Sentry events" do
      refute SentryFilter.drop?(%{message: "boom"})
    end
  end
end
