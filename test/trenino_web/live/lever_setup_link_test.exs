defmodule TreninoWeb.LeverSetupLinkTest do
  @moduledoc """
  The lever wizard's deep link, its lever suggestions and Ask AI prompt, and
  navigation requested by the MCP server.
  """
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Trenino.Simulator
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train, as: TrainContext
  alias Trenino.UINavigation

  setup :verify_on_exit!
  setup :set_mimic_global

  setup do
    {:ok, train} =
      TrainContext.create_train(%{
        name: "Link Train",
        identifiers: [%{identifier: "Link_Train_#{System.unique_integer([:positive])}"}]
      })

    {:ok, element} = TrainContext.create_element(train.id, %{name: "Power", type: :lever})

    client = Client.new("http://localhost:8080", "test-key")
    stub(Simulator, :get_status, fn -> %ConnectionState{status: :connected, client: client} end)

    stub(Client, :list, fn
      _client, "CurrentDrivableActor" ->
        {:ok, %{"Nodes" => [%{"Name" => "Throttle_F"}, %{"Name" => "Horn"}]}}

      _client, _path ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
    end)

    stub(Client, :get, &fake_get/2)

    %{train: train, element: element}
  end

  defp fake_get(_client, "CurrentDrivableActor/Throttle_F." <> endpoint) do
    values =
      case endpoint do
        "Function.GetNotchCount" ->
          %{"ReturnValue" => 4}

        "Property.InputIdentifier" ->
          %{"identifier" => "Throttle"}

        "Property.DisplayInfo" ->
          %{"namedValues" => [label("Off", -1, -1), label("{Power}", 0, 1)]}

        _ ->
          %{"ReturnValue" => 0.0}
      end

    {:ok, %{"Result" => "Success", "Values" => values}}
  end

  defp fake_get(_client, _path), do: {:ok, %{"Result" => "Error"}}

  defp label(name, min, max),
    do: %{
      "valueSource" => "Output",
      "valueRange" => %{"min" => min, "max" => max},
      "displayName" => name
    }

  defp link(train, element, step), do: "/trains/#{train.id}?lever=#{element.id}&step=#{step}"

  test "a link opens the wizard on the lever at Find in Simulator, with suggestions", %{
    conn: conn,
    train: train,
    element: element
  } do
    {:ok, view, _html} = live(conn, link(train, element, "find_endpoint"))

    html = render_async(view)

    assert html =~ "Suggested levers"

    assert has_element?(
             view,
             "#lever-suggestions button[phx-value-path='CurrentDrivableActor/Throttle_F']"
           )

    assert html =~ "Off · Power"

    prompt = view |> element("#ask-ai-#{element.id}") |> render()
    assert prompt =~ "element_id #{element.id}"
    assert prompt =~ "train_id #{train.id}"
    assert prompt =~ "list_simulator_levers"
  end

  test "picking a suggestion fills in the endpoints", %{
    conn: conn,
    train: train,
    element: element
  } do
    {:ok, view, _html} = live(conn, link(train, element, "find_endpoint"))
    render_async(view)

    view
    |> element("#lever-suggestions button[phx-value-path='CurrentDrivableActor/Throttle_F']")
    |> render_click()

    assert render(view) =~ "CurrentDrivableActor/Throttle_F.InputValue"
  end

  test "a link to another train's lever shows an error", %{conn: conn, element: element} do
    {:ok, other} =
      TrainContext.create_train(%{
        name: "Other",
        identifiers: [%{identifier: "Other_#{System.unique_integer([:positive])}"}]
      })

    {:ok, _view, html} = live(conn, link(other, element, "find_endpoint"))
    assert html =~ "That lever link is not valid for this train."
  end

  test "a link while the simulator is disconnected explains what to do", %{
    conn: conn,
    train: train,
    element: element
  } do
    stub(Simulator, :get_status, fn -> %ConnectionState{status: :disconnected} end)

    {:ok, _view, html} = live(conn, link(train, element, "find_endpoint"))
    assert html =~ "Connect to the simulator"
  end

  test "the MCP server can move an open window to the lever", %{
    conn: conn,
    train: train,
    element: element
  } do
    {:ok, view, _html} = live(conn, ~p"/trains")
    path = link(train, element, "map_notches")

    assert UINavigation.request(path) == :ok
    assert_redirect(view, path)
  end

  test "navigation ignores paths outside the app", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/trains")

    for path <- ["//example.com/phish", "/\\example.com", "https://example.com", "trains"] do
      assert UINavigation.request(path, 100) == {:error, :no_window}
    end

    assert render(view) =~ "Trains"
  end
end
