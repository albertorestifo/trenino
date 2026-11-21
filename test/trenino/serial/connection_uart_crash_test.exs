defmodule Trenino.Serial.Connection.UartCrashTest do
  @moduledoc """
  Circuits.UART exits its own process with `:port_timed_out` when the port
  program stops answering (flaky USB device on Windows). Connection starts
  UART processes with `start_link`, so these tests use a real linked fake UART
  process that dies the same way, and check that the exit signal does not take
  Connection down.
  """

  use Trenino.SerialSafetyCase, async: false

  import ExUnit.CaptureLog

  alias Trenino.Serial.Connection
  alias Trenino.Serial.Connection.DeviceConnection
  alias Trenino.Serial.Protocol.{IdentityResponse, SetOutput}

  # Stands in for the Circuits.UART GenServer: each call either answers or
  # exits the process with :port_timed_out, like Circuits.UART.call_port/4.
  defmodule FakeUart do
    use GenServer

    def init(timeouts), do: {:ok, timeouts}

    def handle_call({command, _args}, _from, timeouts) do
      if command in timeouts, do: exit(:port_timed_out), else: {:reply, :ok, timeouts}
    end
  end

  setup :set_mimic_global

  setup do
    stub(Circuits.UART, :enumerate, fn -> %{} end)
    conn_pid = start_supervised!(Connection)
    conn_ref = Process.monitor(conn_pid)
    Connection.subscribe()
    %{conn_pid: conn_pid, conn_ref: conn_ref}
  end

  # The stubbed start_link runs inside Connection, so the fake UART is linked
  # to Connection exactly like the real one.
  defp stub_uart(timeouts) do
    test_pid = self()

    Circuits.UART
    |> stub(:start_link, fn ->
      {:ok, pid} = GenServer.start_link(FakeUart, timeouts)
      send(test_pid, {:uart_started, pid})
      {:ok, pid}
    end)
    |> stub(:open, fn pid, _port, _opts -> GenServer.call(pid, {:open, nil}) end)
    |> stub(:write, fn pid, _data -> GenServer.call(pid, {:write, nil}) end)
    |> stub(:close, fn pid -> GenServer.call(pid, {:close, nil}) end)
    |> stub(:configure, fn _pid, _opts -> :ok end)

    stub(Trenino.Serial.Discovery, :discover, fn _pid ->
      {:ok, %IdentityResponse{request_id: 1, version: "1.0.0", config_id: 1}}
    end)
  end

  defp connect(port) do
    GenServer.cast(Connection, {:connect, port})
    assert_receive {:uart_started, uart_pid}, 1_000
    assert_receive {:devices_updated, devices}, 1_000
    assert %DeviceConnection{status: :connected} = Enum.find(devices, &(&1.port == port))
    uart_pid
  end

  defp assert_connection_alive(conn_pid, conn_ref) do
    # :sys.get_state exits if Connection died while handling earlier messages.
    assert %Connection.State{} = :sys.get_state(conn_pid)
    refute_received {:DOWN, ^conn_ref, :process, ^conn_pid, _}
  end

  defp assert_port_failed(port) do
    assert_receive {:devices_updated, devices}, 1_000
    assert %DeviceConnection{status: :failed} = Enum.find(devices, &(&1.port == port))
  end

  test "a UART process that times out while opening does not kill Connection", ctx do
    stub_uart([:open])
    port = "COM11"

    capture_log(fn ->
      GenServer.cast(Connection, {:connect, port})
      assert_receive {:uart_started, uart_pid}, 1_000
      uart_ref = Process.monitor(uart_pid)
      # The UART may already be dead when monitored (reason :noproc); this is
      # only a sync point.
      assert_receive {:DOWN, ^uart_ref, :process, ^uart_pid, _reason}, 1_000
      assert_connection_alive(ctx.conn_pid, ctx.conn_ref)
      assert_port_failed(port)
    end)

    assert %DeviceConnection{status: :failed, error_type: :port_timed_out, failures: 1} =
             Enum.find(Connection.list_devices(), &(&1.port == port))
  end

  test "send_message returns an error when the UART write times out", ctx do
    stub_uart([:write])
    port = "COM5"
    uart_pid = connect(port)
    uart_ref = Process.monitor(uart_pid)

    capture_log(fn ->
      assert {:error, :port_timed_out} =
               Connection.send_message(port, %SetOutput{pin: 12, value: :low})

      assert_receive {:DOWN, ^uart_ref, :process, ^uart_pid, :port_timed_out}, 1_000
      assert_connection_alive(ctx.conn_pid, ctx.conn_ref)
      assert_port_failed(port)
    end)
  end

  test "request_upload_access grants the port when closing the UART times out", ctx do
    stub_uart([:close])
    port = "COM3"
    uart_pid = connect(port)
    uart_ref = Process.monitor(uart_pid)

    capture_log(fn ->
      assert {:ok, token} = Connection.request_upload_access(port)
      assert is_binary(token)
      assert_receive {:DOWN, ^uart_ref, :process, ^uart_pid, :port_timed_out}, 1_000
      assert_connection_alive(ctx.conn_pid, ctx.conn_ref)
    end)

    assert %DeviceConnection{status: :uploading} =
             Enum.find(Connection.list_devices(), &(&1.port == port))
  end

  test "a port that fails discovery has its UART process stopped", ctx do
    stub_uart([])

    stub(Trenino.Serial.Discovery, :discover, fn _pid -> {:error, :no_valid_response} end)

    port = "COM7"

    capture_log(fn ->
      GenServer.cast(Connection, {:connect, port})
      assert_receive {:uart_started, uart_pid}, 1_000
      uart_ref = Process.monitor(uart_pid)
      assert_port_failed(port)
      assert_receive {:DOWN, ^uart_ref, :process, ^uart_pid, _reason}, 1_000
      assert_connection_alive(ctx.conn_pid, ctx.conn_ref)
    end)
  end

  test "send_message and request_upload_access return errors when Connection is down" do
    stop_supervised!(Connection)

    assert {:error, :noproc} = Connection.send_message("COM5", %SetOutput{pin: 1, value: :low})
    assert {:error, :noproc} = Connection.request_upload_access("COM3")
  end
end
