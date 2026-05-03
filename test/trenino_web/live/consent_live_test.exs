defmodule TreninoWeb.ConsentLiveTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Settings

  setup do
    Sandbox.mode(Trenino.Repo, {:shared, self()})
    :ok
  end

  describe "mount/3" do
    test "renders the consent card", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/consent")

      assert html =~ "Help improve Trenino"
      assert html =~ "Share error reports"
      assert html =~ "No thanks"
    end

    test "is reachable without redirecting", %{conn: conn} do
      assert {:ok, _view, _html} = live(conn, ~p"/consent")
    end
  end

  describe "events" do
    test "accept stores :enabled and redirects to /", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/consent")

      assert {:error, {:redirect, %{to: "/"}}} =
               view |> element("button[phx-click=accept]") |> render_click()

      assert Settings.error_reporting?()
    end

    test "decline stores :disabled and redirects to /", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/consent")

      assert {:error, {:redirect, %{to: "/"}}} =
               view |> element("button[phx-click=decline]") |> render_click()

      assert Settings.error_reporting_set?()
      refute Settings.error_reporting?()
    end
  end
end
