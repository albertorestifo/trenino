defmodule TreninoWeb.NavHookTest do
  @moduledoc """
  Tests that NavHook handles Connection GenServer failures gracefully.

  Reproduces the scenario where UART port timeouts block the Connection
  GenServer, causing list_devices() to fail during LiveView mount.
  """

  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Serial.Connection

  setup :set_mimic_global

  setup do
    Sandbox.mode(Trenino.Repo, {:shared, self()})

    # Prevent automatic discovery from interfering
    stub(Circuits.UART, :enumerate, fn -> %{} end)

    :ok
  end

  describe "mount with blocked Connection GenServer" do
    test "page loads successfully when Connection GenServer is busy with UART operations", %{
      conn: conn
    } do
      # gate_pid acts as both the fake UART pid and the blocking gate.
      # Killing it unblocks the stub and lets the GenServer recover normally
      # without needing to kill and restart the Connection GenServer itself.
      gate_pid = spawn(fn -> Process.sleep(:infinity) end)

      Circuits.UART
      |> stub(:start_link, fn -> {:ok, gate_pid} end)
      |> stub(:open, fn _pid, _port, _opts ->
        ref = Process.monitor(gate_pid)

        receive do
          {:DOWN, ^ref, :process, _, _} -> {:error, :eio}
        end
      end)
      |> stub(:close, fn _pid -> :ok end)

      # Block the Connection GenServer by triggering a connect that will hang
      GenServer.cast(Connection, {:connect, "/dev/tty.blocking-test"})

      # Give the cast a moment to start processing
      Process.sleep(50)

      # The page should still load — NavHook must not crash
      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "Trenino"

      unblock_genserver(gate_pid)
    end

    test "LiveView mounts successfully when Connection GenServer is busy", %{conn: conn} do
      gate_pid = spawn(fn -> Process.sleep(:infinity) end)

      Circuits.UART
      |> stub(:start_link, fn -> {:ok, gate_pid} end)
      |> stub(:open, fn _pid, _port, _opts ->
        ref = Process.monitor(gate_pid)

        receive do
          {:DOWN, ^ref, :process, _, _} -> {:error, :eio}
        end
      end)
      |> stub(:close, fn _pid -> :ok end)

      # Block the Connection GenServer
      GenServer.cast(Connection, {:connect, "/dev/tty.blocking-test-lv"})
      Process.sleep(50)

      # LiveView should mount without crashing
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Trenino"

      unblock_genserver(gate_pid)
    end
  end

  # Unblock the Connection GenServer by killing the gate process.
  # The stub's Process.monitor fires, UART.open returns {:error, :test_unblocked},
  # and the GenServer handles the error through its normal error path — no
  # GenServer kill or supervisor restart needed.
  defp unblock_genserver(gate_pid) do
    Process.exit(gate_pid, :kill)
    # Allow the GenServer to process the error and run async cleanup
    # (safe_stop_uart on a dead pid is a no-op, so cleanup is fast)
    Process.sleep(200)
    # Sync barrier: ensures all pending casts (cleanup_complete) are processed
    Connection.list_devices()
  end
end
