defmodule TreninoWeb.TrainListLiveTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Trenino.Train, as: TrainContext

  test "lists every identifier for a train profile", %{conn: conn} do
    {:ok, _train} =
      TrainContext.create_train(%{
        name: "BR 423",
        identifiers: [
          %{identifier: "RVM_OTHER_DB_BR423"},
          %{identifier: "RVM_FSN_DB_BR423"}
        ]
      })

    {:ok, _view, html} = live(conn, ~p"/trains")

    assert html =~ "RVM_FSN_DB_BR423"
    assert html =~ "RVM_OTHER_DB_BR423"
  end

  test "ambiguity banner shows every identifier for every matching profile", %{conn: conn} do
    {:ok, first} =
      TrainContext.create_train(%{
        name: "First profile",
        identifiers: [
          %{identifier: "RVM_FIRST"},
          %{identifier: "RVM_FIRST_ALT"}
        ]
      })

    {:ok, second} =
      TrainContext.create_train(%{
        name: "Second profile",
        identifiers: [
          %{identifier: "RVM_SECOND"},
          %{identifier: "RVM_SECOND_ALT"}
        ]
      })

    {:ok, view, _html} = live(conn, ~p"/trains")

    first = Trenino.Repo.preload(first, :identifiers)
    second = Trenino.Repo.preload(second, :identifiers)

    send(
      view.pid,
      {:multiple_trains_match, %{identifier: "RVM", trains: [first, second]}}
    )

    html = render(view)

    assert html =~ "Multiple Trains Match"
    assert html =~ "RVM_FIRST"
    assert html =~ "RVM_FIRST_ALT"
    assert html =~ "RVM_SECOND"
    assert html =~ "RVM_SECOND_ALT"
  end
end
