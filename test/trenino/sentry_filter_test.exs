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

  # Shape produced by Sentry.LoggerHandler for a ThousandIsland connection
  # process whose client aborted the TCP connection (Sentry issue TRENINO-E).
  @connection_abort_report """
  GenServer #PID<0.1704.0> terminating
  ** (stop) :econnaborted
  Process Label: {:thousand_island, :connection, {Bandit.DelegatingHandler, {{127, 0, 0, 1}, 57709}}}
  Last message: {:tcp_error, #Port<0.3083>, :econnaborted}
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

    test "drops a ThousandIsland connection aborted by the client" do
      assert SentryFilter.drop?(
               event(
                 message: %Message{formatted: @connection_abort_report},
                 extra: %{crash_reason: ":econnaborted"}
               )
             )
    end

    test "drops a ThousandIsland connection reset by the client" do
      report = String.replace(@connection_abort_report, "econnaborted", "econnreset")

      assert SentryFilter.drop?(
               event(
                 message: %Message{formatted: report},
                 extra: %{"crash_reason" => ":econnreset"}
               )
             )
    end

    test "keeps other ThousandIsland connection crashes" do
      refute SentryFilter.drop?(
               event(
                 message: %Message{formatted: @connection_abort_report},
                 extra: %{crash_reason: "%RuntimeError{message: \"boom\"}"}
               )
             )
    end

    test "keeps a ThousandIsland connection stopping with another socket error" do
      for reason <- ["closed", "etimedout"] do
        report = String.replace(@connection_abort_report, "econnaborted", reason)

        refute SentryFilter.drop?(
                 event(message: %Message{formatted: report}, extra: %{crash_reason: ":#{reason}"})
               )
      end
    end

    test "keeps an :econnaborted crash from a ThousandIsland acceptor" do
      report =
        String.replace(
          @connection_abort_report,
          "{:thousand_island, :connection,",
          "{:thousand_island, :acceptor,"
        )

      refute SentryFilter.drop?(
               event(
                 message: %Message{formatted: report},
                 extra: %{crash_reason: ":econnaborted"}
               )
             )
    end

    test "keeps an :econnaborted crash that is not a ThousandIsland connection" do
      refute SentryFilter.drop?(
               event(
                 message: %Message{
                   formatted: "GenServer Trenino.Simulator.Connection terminating"
                 },
                 extra: %{crash_reason: ":econnaborted"}
               )
             )
    end

    test "drops a Bandit.TransportError for a client that closed the socket" do
      # As reported by Sentry.PlugCapture (Sentry issue TRENINO-F).
      exception = %Bandit.TransportError{message: "Unrecoverable error: closed", error: :closed}

      assert SentryFilter.drop?(Event.transform_exception(exception, []))
    end

    test "keeps a Bandit.TransportError that is not a client closure" do
      exception = %Bandit.TransportError{message: "Unrecoverable error: emfile", error: :emfile}

      refute SentryFilter.drop?(Event.transform_exception(exception, []))

      refute SentryFilter.drop?(%{
               Event.transform_exception(exception, [])
               | original_exception: nil
             })
    end

    test "keeps other exceptions" do
      refute SentryFilter.drop?(Event.transform_exception(%RuntimeError{message: "closed"}, []))
    end

    test "keeps events that are not Sentry events" do
      refute SentryFilter.drop?(%{message: "boom"})
    end
  end
end
