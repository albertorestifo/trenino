defmodule Trenino.Serial.Connection.ScanTest do
  @moduledoc """
  Tests how quickly the Connection GenServer picks up new ports and retries
  failed ones.
  """

  use Trenino.SerialSafetyCase, async: false

  alias Trenino.Serial.Connection
  alias Trenino.Serial.Connection.DeviceConnection
  alias Trenino.Serial.Discovery
  alias Trenino.Serial.Protocol.IdentityResponse

  @port "/dev/cu.usbserial-A10TEST"

  setup :set_mimic_global

  setup do
    previous = Application.get_env(:trenino, :serial_scan_interval_ms)
    Application.put_env(:trenino, :serial_scan_interval_ms, 50)

    on_exit(fn ->
      if previous,
        do: Application.put_env(:trenino, :serial_scan_interval_ms, previous),
        else: Application.delete_env(:trenino, :serial_scan_interval_ms)
    end)

    {:ok, ports} = Agent.start_link(fn -> %{} end)
    stub(Circuits.UART, :enumerate, fn -> Agent.get(ports, & &1) end)

    fake_uart = spawn(fn -> Process.sleep(:infinity) end)
    on_exit(fn -> Process.exit(fake_uart, :kill) end)

    Circuits.UART
    |> stub(:start_link, fn -> {:ok, fake_uart} end)
    |> stub(:open, fn _pid, _port, _opts -> :ok end)
    |> stub(:configure, fn _pid, _opts -> :ok end)
    |> stub(:close, fn _pid -> :ok end)

    :ok = Connection.subscribe()
    start_supervised!(Connection)

    %{ports: ports}
  end

  defp plug_in(ports, port), do: Agent.update(ports, &Map.put(&1, port, %{}))

  defp await_status(port, status) do
    receive do
      {:devices_updated, devices} ->
        case Enum.find(devices, &(&1.port == port)) do
          %DeviceConnection{status: ^status} = conn -> conn
          _ -> await_status(port, status)
        end
    after
      3_000 -> flunk("#{port} never reached #{inspect(status)}")
    end
  end

  test "connects a port plugged in after startup on the next short scan", %{ports: ports} do
    stub(Discovery, :discover, fn _pid ->
      {:ok, %IdentityResponse{request_id: 1, version: "3.2.1", config_id: 7}}
    end)

    # Let the first scan run with no ports, then plug the board in.
    Process.sleep(1_100)
    plugged_at = System.monotonic_time(:millisecond)
    plug_in(ports, @port)

    conn = await_status(@port, :connected)
    elapsed = System.monotonic_time(:millisecond) - plugged_at

    assert conn.device_version == "3.2.1"
    # Used to wait for the next 60s discovery tick.
    assert elapsed < 1_000
  end

  test "keeps counting consecutive failures across retries", %{ports: ports} do
    stub(Discovery, :discover, fn _pid -> {:error, :no_valid_response} end)
    plug_in(ports, @port)

    first = await_status(@port, :failed)
    assert first.failures == 1
    assert first.error_reason == "No Trenino firmware detected"

    # Expire the backoff instead of waiting 5s for it.
    :sys.replace_state(Connection, fn state ->
      update_in(state.ports[@port].failed_at, &(&1 - DeviceConnection.retry_backoff_ms(first)))
    end)

    second = await_status(@port, :failed)
    assert second.failures == 2
  end
end
