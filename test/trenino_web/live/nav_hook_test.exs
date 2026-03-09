defmodule TreninoWeb.NavHookTest do
  @moduledoc """
  Tests that NavHook handles Connection GenServer failures gracefully.

  Reproduces the scenario where UART port timeouts block the Connection
  GenServer, causing list_devices() to fail during LiveView mount.
  """

  use TreninoWeb.ConnCase, async: false
  use Mimic

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox

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
      fake_pid = spawn(fn -> Process.sleep(:infinity) end)

      # Simulate UART.open blocking indefinitely (as happens with port_timed_out)
      Circuits.UART
      |> stub(:start_link, fn -> {:ok, fake_pid} end)
      |> stub(:open, fn _pid, _port, _opts ->
        Process.sleep(:infinity)
      end)
      |> stub(:close, fn _pid -> :ok end)

      # Block the Connection GenServer by triggering a connect that will hang
      GenServer.cast(Trenino.Serial.Connection, {:connect, "/dev/tty.blocking-test"})

      # Give the cast a moment to start processing
      Process.sleep(50)

      # The page should still load — NavHook must not crash
      conn = get(conn, ~p"/")
      assert html_response(conn, 200) =~ "Trenino"

      Process.exit(fake_pid, :kill)
    end

    test "LiveView mounts successfully when Connection GenServer is busy", %{conn: conn} do
      fake_pid = spawn(fn -> Process.sleep(:infinity) end)

      Circuits.UART
      |> stub(:start_link, fn -> {:ok, fake_pid} end)
      |> stub(:open, fn _pid, _port, _opts ->
        Process.sleep(:infinity)
      end)
      |> stub(:close, fn _pid -> :ok end)

      # Block the Connection GenServer
      GenServer.cast(Trenino.Serial.Connection, {:connect, "/dev/tty.blocking-test-lv"})
      Process.sleep(50)

      # LiveView should mount without crashing
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Trenino"

      Process.exit(fake_pid, :kill)
    end
  end
end
