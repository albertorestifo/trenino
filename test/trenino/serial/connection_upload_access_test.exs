defmodule Trenino.Serial.Connection.UploadAccessTest do
  @moduledoc """
  Upload access and cleanup races in Connection:

    * a request_upload_access call that times out on the client side must
      not leave the port :uploading with a token nobody holds
    * the owner of an upload token dying releases the port
    * cleanup of a disconnected port broadcasts once
    * a cleanup that finishes after the port was granted for upload does not
      crash Connection
  """

  use Trenino.SerialSafetyCase, async: false

  import ExUnit.CaptureLog

  alias Trenino.Serial.Connection
  alias Trenino.Serial.Connection.DeviceConnection
  alias Trenino.Serial.Protocol.IdentityResponse

  # Stands in for the Circuits.UART GenServer.
  defmodule FakeUart do
    use GenServer

    def init(:ok), do: {:ok, nil}
    def handle_call(_request, _from, state), do: {:reply, :ok, state}
  end

  setup :set_mimic_global

  setup do
    previous = Application.get_env(:trenino, :serial_scan_interval_ms)
    # Scans are driven by hand with send/2.
    Application.put_env(:trenino, :serial_scan_interval_ms, 3_600_000)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:trenino, :serial_scan_interval_ms, previous),
        else: Application.delete_env(:trenino, :serial_scan_interval_ms)
    end)

    :ok
  end

  defp start_connection do
    pid = start_supervised!(Connection)
    Connection.subscribe()
    pid
  end

  defp stub_uart(close_fun) do
    test_pid = self()

    Circuits.UART
    |> stub(:start_link, fn ->
      {:ok, pid} = GenServer.start_link(FakeUart, :ok)
      send(test_pid, {:uart_started, pid})
      {:ok, pid}
    end)
    |> stub(:open, fn pid, _port, _opts -> GenServer.call(pid, :open) end)
    |> stub(:configure, fn _pid, _opts -> :ok end)
    |> stub(:close, close_fun)

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

  defp flush_device_updates(count \\ 0) do
    receive do
      {:devices_updated, _} -> flush_device_updates(count + 1)
    after
      0 -> count
    end
  end

  describe "request_upload_access/1" do
    test "a request that times out on the client does not leave the port reserved" do
      test_pid = self()
      {:ok, calls} = Agent.start_link(fn -> 0 end)

      # The first enumerate blocks Connection until the test lets it go,
      # like a circuits_uart helper that hangs for its 5s timeout.
      stub(Circuits.UART, :enumerate, fn ->
        if Agent.get_and_update(calls, &{&1, &1 + 1}) == 0 do
          send(test_pid, :enumerating)

          receive do
            :continue -> %{}
          end
        else
          %{}
        end
      end)

      pid = start_connection()
      send(pid, :discover)
      assert_receive :enumerating, 1_000

      # config/test.exs sets the call timeout to 500ms.
      assert {:error, :timeout} = Connection.request_upload_access("COM9")

      send(pid, :continue)

      assert {:ok, token} = Connection.request_upload_access("COM9")
      assert :ok = Connection.release_upload_access("COM9", token)
    end

    test "the port is released when the token owner exits" do
      start_connection()
      test_pid = self()

      owner =
        spawn(fn ->
          send(test_pid, {:requested, Connection.request_upload_access("COM9")})
        end)

      owner_ref = Process.monitor(owner)
      assert_receive {:requested, {:ok, _token}}, 1_000
      assert_receive {:DOWN, ^owner_ref, :process, ^owner, _}, 1_000

      capture_log(fn ->
        assert {:ok, token} = Connection.request_upload_access("COM9")
        assert :ok = Connection.release_upload_access("COM9", token)
      end)
    end

    test "releasing the port stops monitoring the token owner" do
      pid = start_connection()

      {:monitors, before} = Process.info(pid, :monitors)
      assert {:ok, token} = Connection.request_upload_access("COM9")
      assert {:monitors, [_ | _] = during} = Process.info(pid, :monitors)
      assert {:process, self()} in during

      assert :ok = Connection.release_upload_access("COM9", token)
      assert {:monitors, ^before} = Process.info(pid, :monitors)
    end
  end

  describe "cleanup after disconnect" do
    test "broadcasts the failed port once" do
      stub(Circuits.UART, :enumerate, fn -> %{} end)
      test_pid = self()

      stub_uart(fn uart ->
        send(test_pid, {:closing, self()})
        GenServer.call(uart, :close)
      end)

      start_connection()
      port = "COM4"
      connect(port)
      flush_device_updates()

      Connection.disconnect(port)
      assert_receive {:closing, cleanup_pid}, 1_000
      cleanup_ref = Process.monitor(cleanup_pid)
      assert_receive {:DOWN, ^cleanup_ref, :process, ^cleanup_pid, _}, 1_000

      # Sync: the UART :DOWN and {:cleanup_complete} have been handled.
      assert %DeviceConnection{status: :failed} =
               Enum.find(Connection.list_devices(), &(&1.port == port))

      assert flush_device_updates() == 1
    end

    test "a cleanup finishing after the port was granted for upload keeps it reserved" do
      stub(Circuits.UART, :enumerate, fn -> %{} end)
      test_pid = self()

      # The cleanup task blocks in close until released; Connection's own
      # close (when granting upload access) goes through.
      stub_uart(fn uart ->
        if self() != Process.whereis(Connection) do
          send(test_pid, {:closing, self()})

          receive do
            :continue -> :ok
          end
        end

        GenServer.call(uart, :close)
      end)

      conn_pid = start_connection()
      conn_ref = Process.monitor(conn_pid)
      port = "COM4"
      connect(port)

      Connection.disconnect(port)
      assert_receive {:closing, cleanup_pid}, 1_000

      assert {:ok, token} = Connection.request_upload_access(port)

      cleanup_ref = Process.monitor(cleanup_pid)
      send(cleanup_pid, :continue)
      assert_receive {:DOWN, ^cleanup_ref, :process, ^cleanup_pid, _}, 1_000

      assert %DeviceConnection{status: :uploading} =
               Enum.find(Connection.list_devices(), &(&1.port == port))

      refute_received {:DOWN, ^conn_ref, :process, ^conn_pid, _}
      assert :ok = Connection.release_upload_access(port, token)
    end
  end
end
