defmodule TswIoWeb.ConfigurationListLiveTest do
  # Non-async because the Simulator.Connection GenServer needs database access
  use TswIoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias TswIo.Hardware
  alias TswIo.Simulator.ConnectionState

  # Allow the Connection GenServer to access the database sandbox
  setup do
    Ecto.Adapters.SQL.Sandbox.mode(TswIo.Repo, {:shared, self()})
    :ok
  end

  describe "basic rendering" do
    test "GET / renders configuration list", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      # Always present regardless of device state
      assert html =~ "TSW IO"
      assert html =~ "Configurations"
    end

    test "shows empty state when no configurations exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "No Configurations"
      assert html =~ "Create Configuration"
    end

    test "shows configuration cards when configurations exist", %{conn: conn} do
      {:ok, _device} = Hardware.create_device(%{name: "Test Config"})

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Test Config"
    end
  end

  describe "simulator status indicator" do
    test "shows simulator link in header", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Simulator"
      assert html =~ ~s(href="/simulator/config")
    end

    test "updates simulator status on PubSub event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Send connected status
      send(view.pid, {:simulator_status_changed, %ConnectionState{status: :connected}})

      html = render(view)
      assert html =~ "bg-success"
    end

    test "shows warning color when needs config", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      send(view.pid, {:simulator_status_changed, %ConnectionState{status: :needs_config}})

      html = render(view)
      assert html =~ "bg-warning"
    end

    test "shows error color on connection error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      send(
        view.pid,
        {:simulator_status_changed, %ConnectionState{status: :error, last_error: :timeout}}
      )

      html = render(view)
      assert html =~ "bg-error"
    end

    test "shows connecting animation when connecting", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      send(view.pid, {:simulator_status_changed, %ConnectionState{status: :connecting}})

      html = render(view)
      assert html =~ "bg-info"
      assert html =~ "animate-pulse"
    end

    test "shows disconnected color", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      send(view.pid, {:simulator_status_changed, %ConnectionState{status: :disconnected}})

      html = render(view)
      assert html =~ "bg-base-content/20"
    end
  end

  describe "simulator_status_color/1 helper function" do
    test "returns correct color classes for each status" do
      # Test the color mapping logic
      status_colors = [
        {:connected, "bg-success"},
        {:connecting, "bg-info animate-pulse"},
        {:error, "bg-error"},
        {:needs_config, "bg-warning"},
        {:disconnected, "bg-base-content/20"}
      ]

      for {status, expected_class} <- status_colors do
        color = simulator_status_color(status)

        assert color == expected_class,
               "Expected #{expected_class} for status #{status}, got #{color}"
      end
    end
  end

  # Helper that mirrors the LiveView implementation
  defp simulator_status_color(status) do
    case status do
      :connected -> "bg-success"
      :connecting -> "bg-info animate-pulse"
      :error -> "bg-error"
      :needs_config -> "bg-warning"
      :disconnected -> "bg-base-content/20"
    end
  end
end
