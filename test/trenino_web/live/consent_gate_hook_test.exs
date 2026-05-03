defmodule TreninoWeb.ConsentGateHookTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Settings

  setup do
    Sandbox.mode(Trenino.Repo, {:shared, self()})
    :ok
  end

  test "redirects to /consent when no preference is set", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/consent"}}} = live(conn, ~p"/")
  end

  test "allows the page to render once consent is given", %{conn: conn} do
    {:ok, _} = Settings.set_error_reporting(:enabled)

    assert {:ok, _view, html} = live(conn, ~p"/")
    assert html =~ "Trenino"
  end

  test "allows the page to render even when consent is declined", %{conn: conn} do
    {:ok, _} = Settings.set_error_reporting(:disabled)

    assert {:ok, _view, _html} = live(conn, ~p"/")
  end
end
