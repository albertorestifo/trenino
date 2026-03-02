defmodule Trenino.Serial.Connection.PortTimeoutTest do
  @moduledoc """
  Tests that :port_timed_out exits from Circuits.UART don't crash the
  Connection GenServer. This reproduces the bug where Bluetooth or
  unresponsive devices cause exit(:port_timed_out) in UART's internal
  call_port/4, which propagates through GenServer.call and crashes the
  Connection process.
  """

  use ExUnit.Case, async: false
  use Mimic

  alias Trenino.Serial.Connection

  setup :set_mimic_global

  setup do
    # Prevent automatic discovery from interfering with our test
    stub(Circuits.UART, :enumerate, fn -> %{} end)

    # Ensure the Connection GenServer is alive before each test
    conn_pid = GenServer.whereis(Connection)
    assert conn_pid != nil
    assert Process.alive?(conn_pid)

    %{conn_pid: conn_pid}
  end

  describe "port_timed_out during UART.open" do
    test "Connection GenServer survives when UART.open exits with :port_timed_out", %{
      conn_pid: conn_pid
    } do
      fake_pid = spawn(fn -> Process.sleep(:infinity) end)

      Circuits.UART
      |> stub(:start_link, fn -> {:ok, fake_pid} end)
      |> stub(:open, fn _pid, _port, _opts -> exit(:port_timed_out) end)
      |> stub(:close, fn _pid -> :ok end)

      # Trigger a connection attempt to a port that will timeout
      GenServer.cast(Connection, {:connect, "/dev/tty.timeout-test"})

      # Synchronous call to ensure the cast has been processed
      devices = Connection.list_devices()

      # Connection GenServer must still be alive
      assert Process.alive?(conn_pid)
      assert is_list(devices)

      # The timed-out port should be tracked as failed (not crash the server)
      timeout_device = Enum.find(devices, &(&1.port == "/dev/tty.timeout-test"))
      assert timeout_device != nil
      assert timeout_device.status in [:disconnecting, :failed]

      Process.exit(fake_pid, :kill)
    end
  end

  describe "port_timed_out during discovery" do
    test "Connection GenServer survives when Discovery.discover exits with :port_timed_out", %{
      conn_pid: conn_pid
    } do
      fake_pid = spawn(fn -> Process.sleep(:infinity) end)

      Circuits.UART
      |> stub(:start_link, fn -> {:ok, fake_pid} end)
      |> stub(:open, fn _pid, _port, _opts -> :ok end)
      |> stub(:close, fn _pid -> :ok end)

      # Discovery.discover will exit with :port_timed_out (simulating UART
      # functions inside discovery raising an exit)
      Trenino.Serial.Discovery
      |> stub(:discover, fn _pid -> exit(:port_timed_out) end)

      # Trigger a connection that will succeed opening but fail during discovery
      GenServer.cast(Connection, {:connect, "/dev/tty.discover-timeout-test"})

      # Wait briefly for the async cast chain (connect → open → check_device → discover)
      Process.sleep(100)

      # Synchronous call to ensure processing is complete
      devices = Connection.list_devices()

      # Connection GenServer must still be alive
      assert Process.alive?(conn_pid)
      assert is_list(devices)

      # The timed-out port should be tracked (not crash the server)
      timeout_device = Enum.find(devices, &(&1.port == "/dev/tty.discover-timeout-test"))
      assert timeout_device != nil
      assert timeout_device.status in [:discovering, :disconnecting, :failed]

      Process.exit(fake_pid, :kill)
    end
  end
end
