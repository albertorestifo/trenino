defmodule Trenino.Serial.Connection.EnumerateFailureTest do
  @moduledoc """
  Port enumeration runs a native circuits_uart helper. When that helper cannot
  run, `Circuits.UART.enumerate/0` raises. These tests cover both shapes seen
  in production:

    * the helper exits without replying, so the 5s timeout calls
      `Port.close/1` on a closed port and raises `ArgumentError`
    * the helper cannot be started (`:eacces`), raising `ErlangError`

  Connection must survive, treat it as "no ports", warn once per failure
  streak instead of on every scan, and log no errors.
  """

  use Trenino.SerialSafetyCase, async: false

  import ExUnit.CaptureLog

  alias Trenino.Serial.Connection

  @port "/dev/cu.usbserial-ENUMFAIL"

  setup :set_mimic_global

  setup do
    previous = Application.get_env(:trenino, :serial_scan_interval_ms)
    # Ticks are driven by hand with send/2.
    Application.put_env(:trenino, :serial_scan_interval_ms, 3_600_000)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:trenino, :serial_scan_interval_ms, previous),
        else: Application.delete_env(:trenino, :serial_scan_interval_ms)
    end)

    :ok
  end

  defp helper_exits, do: fn -> raise ArgumentError end
  defp helper_blocked, do: fn -> :erlang.error(:eacces) end

  defp tick(pid) do
    send(pid, :discover)
    :sys.get_state(pid)
  end

  for {name, failure} <- [helper_exits: :helper_exits, helper_blocked: :helper_blocked] do
    test "survives repeated enumerate failures (#{name}) and warns once" do
      stub(Circuits.UART, :enumerate, unquote(failure)())
      pid = start_supervised!(Connection)

      log =
        capture_log(fn ->
          for _ <- 1..5, do: tick(pid)
        end)

      assert Process.alive?(pid)
      assert Process.whereis(Connection) == pid
      assert %{enumerate_failing?: true, ports: ports} = :sys.get_state(pid)
      assert ports == %{}

      assert length(Regex.scan(~r/Could not list serial ports/, log)) == 1
      assert log =~ "[warning]"
      refute log =~ "[error]"
    end
  end

  test "connects to ports once enumeration recovers" do
    {:ok, result} = Agent.start_link(fn -> :fail end)

    stub(Circuits.UART, :enumerate, fn ->
      case Agent.get(result, & &1) do
        :fail -> raise ArgumentError
        ports -> ports
      end
    end)

    fake_uart = spawn(fn -> Process.sleep(:infinity) end)
    on_exit(fn -> Process.exit(fake_uart, :kill) end)

    Circuits.UART
    |> stub(:start_link, fn -> {:ok, fake_uart} end)
    |> stub(:open, fn _pid, _port, _opts -> :ok end)
    |> stub(:configure, fn _pid, _opts -> :ok end)
    |> stub(:close, fn _pid -> :ok end)

    stub(Trenino.Serial.Discovery, :discover, fn _pid -> {:error, :no_valid_response} end)

    pid = start_supervised!(Connection)

    capture_log(fn -> tick(pid) end)
    assert %{enumerate_failing?: true} = :sys.get_state(pid)

    Agent.update(result, fn _ -> %{@port => %{}} end)
    capture_log(fn -> tick(pid) end)

    # The tick casts {:connect, port}; syncing again lets it be handled.
    state = :sys.get_state(pid)
    assert state.enumerate_failing? == false
    assert Map.has_key?(state.ports, @port)
  end

  describe "enumerate_ports/0 and list_ports/0" do
    test "return no ports instead of raising when the helper exits" do
      stub(Circuits.UART, :enumerate, helper_exits())

      assert Connection.enumerate_ports() == []
      assert {:error, %ArgumentError{}} = Connection.list_ports()
    end

    test "return no ports instead of raising when the helper is blocked" do
      stub(Circuits.UART, :enumerate, helper_blocked())

      assert Connection.enumerate_ports() == []
      assert {:error, %ErlangError{original: :eacces}} = Connection.list_ports()
    end

    test "still raise the test-suite hardware guard" do
      # The forbidden stub raises RuntimeError, which must not be swallowed.
      assert_raise RuntimeError, fn -> Connection.enumerate_ports() end
    end
  end
end
