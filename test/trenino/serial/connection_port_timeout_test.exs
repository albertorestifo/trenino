defmodule Trenino.Serial.Connection.PortTimeoutTest do
  @moduledoc """
  Tests that :port_timed_out exits from Circuits.UART don't crash the
  Connection GenServer. This reproduces the bug where Bluetooth or
  unresponsive devices cause exit(:port_timed_out) in UART's internal
  call_port/4, which propagates through GenServer.call and crashes the
  Connection process.
  """

  use Trenino.SerialSafetyCase, async: false

  alias Trenino.Serial.Connection

  setup :set_mimic_global

  setup do
    # Prevent automatic discovery from interfering with our test
    stub(Circuits.UART, :enumerate, fn -> %{} end)

    # ExUnit stops this process and its discovery timers before the next test.
    conn_pid = start_supervised!(Connection)

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

  describe "list_devices when Connection GenServer is blocked" do
    test "returns empty list instead of crashing when GenServer is busy" do
      fake_pid = spawn(fn -> Process.sleep(:infinity) end)

      Circuits.UART
      |> stub(:start_link, fn -> {:ok, fake_pid} end)
      |> stub(:open, fn _pid, _port, _opts ->
        # Simulate UART.open blocking for longer than the GenServer.call timeout
        Process.sleep(:infinity)
      end)
      |> stub(:close, fn _pid -> :ok end)

      # Trigger a connection attempt that will block the GenServer
      GenServer.cast(Connection, {:connect, "/dev/tty.blocking-test"})

      # Give the cast a moment to start processing (GenServer is now blocked)
      Process.sleep(50)

      # list_devices should return [] instead of crashing with :port_timed_out
      task =
        Task.async(fn ->
          Connection.list_devices()
        end)

      result = Task.yield(task, 1_000) || Task.shutdown(task)

      assert {:ok, devices} = result
      assert devices == []

      stop_supervised!(Connection)
      Process.exit(fake_pid, :kill)
    end

    test "connected_devices returns empty list when GenServer is busy" do
      fake_pid = spawn(fn -> Process.sleep(:infinity) end)

      Circuits.UART
      |> stub(:start_link, fn -> {:ok, fake_pid} end)
      |> stub(:open, fn _pid, _port, _opts ->
        Process.sleep(:infinity)
      end)
      |> stub(:close, fn _pid -> :ok end)

      GenServer.cast(Connection, {:connect, "/dev/tty.blocking-test-2"})
      Process.sleep(50)

      task =
        Task.async(fn ->
          Connection.connected_devices()
        end)

      result = Task.yield(task, 1_000) || Task.shutdown(task)

      assert {:ok, devices} = result
      assert devices == []

      stop_supervised!(Connection)
      Process.exit(fake_pid, :kill)
    end
  end

  describe "non-blocking discovery" do
    test "GenServer answers calls immediately while discovery Task is running", %{
      conn_pid: conn_pid
    } do
      test_pid = self()
      fake_uart_pid = spawn(fn -> Process.sleep(:infinity) end)

      on_exit(fn ->
        if Process.alive?(fake_uart_pid), do: Process.exit(fake_uart_pid, :kill)
      end)

      Circuits.UART
      |> stub(:start_link, fn -> {:ok, fake_uart_pid} end)
      |> stub(:open, fn _pid, _port, _opts -> :ok end)
      |> stub(:close, fn _pid -> :ok end)

      # Stub Discovery to block and report its task pid back to the test
      Trenino.Serial.Discovery
      |> stub(:discover, fn _pid ->
        send(test_pid, {:discovery_running, self()})

        receive do
          :continue -> {:error, :test_cancelled}
        after
          5_000 -> {:error, :test_timeout}
        end
      end)

      # Trigger connection — port opens successfully then starts discovery Task
      GenServer.cast(Connection, {:connect, "/dev/tty.non-blocking-test"})

      # Block until we know the discovery Task is actually running
      assert_receive {:discovery_running, discovery_pid}, 2_000

      # GenServer must answer a call IMMEDIATELY despite ongoing discovery
      t0 = System.monotonic_time(:millisecond)
      devices = Connection.list_devices()
      elapsed_ms = System.monotonic_time(:millisecond) - t0

      assert is_list(devices)
      assert elapsed_ms < 500, "GenServer took #{elapsed_ms}ms — discovery is still blocking it"
      assert Process.alive?(conn_pid)

      # Release the blocked discovery Task so it exits cleanly
      send(discovery_pid, :continue)
    end

    test "stale discovery result is ignored when port timed out before Task finished", %{
      conn_pid: conn_pid
    } do
      test_pid = self()
      fake_uart_pid = spawn(fn -> Process.sleep(:infinity) end)

      on_exit(fn ->
        if Process.alive?(fake_uart_pid), do: Process.exit(fake_uart_pid, :kill)
      end)

      Circuits.UART
      |> stub(:start_link, fn -> {:ok, fake_uart_pid} end)
      |> stub(:open, fn _pid, _port, _opts -> :ok end)
      |> stub(:close, fn _pid -> :ok end)
      |> stub(:configure, fn _pid, _opts -> :ok end)

      identity = %Trenino.Serial.Protocol.IdentityResponse{
        request_id: 1,
        version: "1.0.0",
        config_id: 0
      }

      Trenino.Serial.Discovery
      |> stub(:discover, fn _pid ->
        send(test_pid, {:discovery_running, self()})

        receive do
          :continue -> {:ok, identity}
        after
          5_000 -> {:error, :test_timeout}
        end
      end)

      port = "/dev/tty.stale-result-test"
      GenServer.cast(Connection, {:connect, port})

      # Wait until discovery is running, then disconnect the port
      assert_receive {:discovery_running, discovery_pid}, 2_000
      Connection.disconnect(port)

      # Give disconnect time to process
      Process.sleep(50)

      # Unblock the discovery Task — it will send a successful result back,
      # but the GenServer should ignore it since the port is no longer :discovering
      send(discovery_pid, :continue)

      # Allow the stale result cast to be processed
      Process.sleep(50)

      devices = Connection.list_devices()
      matching = Enum.find(devices, &(&1.port == port))

      # Port must NOT have been moved to :connected by the stale result
      if matching, do: assert(matching.status != :connected)
      assert Process.alive?(conn_pid)
    end
  end
end
