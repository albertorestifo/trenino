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

  describe "list_devices when Connection GenServer is blocked" do
    # Previous tests (nav_hook, port_timeout) leave state in the GenServer.
    # Wait for any cleanup tasks to finish (transitional → failed), then clear
    # all failed ports so the blocking cast below is not ignored by should_connect?.
    setup do
      wait_for_no_transitional_ports()
      GenServer.cast(Connection, :scan)
      Connection.list_devices()
      :ok
    end

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

      # Kill and restart the blocked GenServer while stubs are still active,
      # so the restarted GenServer uses stubbed enumerate (returns %{})
      # instead of attempting real UART operations
      kill_and_restart_connection(fake_pid)
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

      kill_and_restart_connection(fake_pid)
    end
  end

  # Poll until no port is in a transitional state (connecting/discovering/disconnecting).
  # This ensures cleanup tasks from previous tests have fully completed before
  # the blocking tests clear state and cast their own blocking connect.
  defp wait_for_no_transitional_ports(attempts \\ 20) do
    devices = Connection.list_devices()
    transitional = [:connecting, :discovering, :disconnecting]

    if attempts > 0 and Enum.any?(devices, &(&1.status in transitional)) do
      Process.sleep(50)
      wait_for_no_transitional_ports(attempts - 1)
    end
  end

  # Kill the blocked Connection GenServer, clean up the fake UART process,
  # and wait for the supervisor to restart a fresh, responsive GenServer.
  # Must be called while Mimic stubs are still active so the restarted
  # GenServer's initial discovery timer fires with stubbed enumerate.
  defp kill_and_restart_connection(fake_pid) do
    old_pid = GenServer.whereis(Connection)
    Process.exit(fake_pid, :kill)

    if old_pid do
      Process.exit(old_pid, :kill)
      wait_for_genserver_restart(old_pid)

      # The restarted GenServer schedules discovery at 1 second.
      # Wait for it to fire while stubs are still active, preventing
      # real UART operations from blocking the GenServer after cleanup.
      Process.sleep(1_200)

      # Sync barrier to ensure the discovery has been fully processed
      Connection.list_devices()
    end
  end

  defp wait_for_genserver_restart(old_pid, attempts \\ 20) do
    if attempts <= 0 do
      raise "Connection GenServer did not restart in time"
    end

    case GenServer.whereis(Connection) do
      nil ->
        Process.sleep(50)
        wait_for_genserver_restart(old_pid, attempts - 1)

      ^old_pid ->
        Process.sleep(50)
        wait_for_genserver_restart(old_pid, attempts - 1)

      _new_pid ->
        # Verify it's responsive
        try do
          Connection.list_devices()
          :ok
        catch
          :exit, _ ->
            Process.sleep(50)
            wait_for_genserver_restart(old_pid, attempts - 1)
        end
    end
  end
end
