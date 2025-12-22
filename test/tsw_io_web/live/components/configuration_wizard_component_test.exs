defmodule TswIoWeb.ConfigurationWizardComponentTest do
  use TswIoWeb.ConnCase, async: false
  use Mimic

  import Phoenix.LiveViewTest

  alias TswIo.Simulator.Client
  alias TswIo.Simulator.ConnectionState
  alias TswIo.Simulator
  alias TswIo.Train, as: TrainContext
  alias TswIo.Hardware

  setup :verify_on_exit!
  setup :set_mimic_global

  setup do
    # Create a train with elements
    {:ok, train} =
      TrainContext.create_train(%{
        name: "Test Train",
        identifier: "Test_Train_Wizard_#{System.unique_integer([:positive])}"
      })

    {:ok, lever_element} =
      TrainContext.create_element(train.id, %{
        name: "Throttle",
        type: :lever
      })

    {:ok, button_element} =
      TrainContext.create_element(train.id, %{
        name: "Horn",
        type: :button
      })

    # Create a device with button input
    {:ok, device} = Hardware.create_device(%{name: "Test Device"})

    {:ok, button_input} =
      Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

    # Create a mock client
    client = Client.new("http://localhost:8080", "test-key")

    # Create a connected simulator status
    simulator_status =
      %ConnectionState{}
      |> ConnectionState.mark_connecting(client)
      |> ConnectionState.mark_connected(%{"version" => "1.0"})

    %{
      train: train,
      lever_element: lever_element,
      button_element: button_element,
      button_input: button_input,
      device: device,
      client: client,
      simulator_status: simulator_status
    }
  end

  describe "wizard opening" do
    test "opens wizard when simulator is connected and configure_lever is clicked", %{
      conn: conn,
      train: train,
      lever_element: lever_element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      # Mock API explorer initialization
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      # Click configure lever
      html =
        view
        |> element("[phx-click='configure_lever'][phx-value-id='#{lever_element.id}']")
        |> render_click()

      # Should show wizard, not old modal
      assert html =~ "Configure Lever"
      assert html =~ "Find in Simulator"
      # The step indicator should be visible
      assert html =~ "Confirm"
    end

    test "opens wizard when simulator is connected and configure_button is clicked", %{
      conn: conn,
      train: train,
      button_element: button_element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      html =
        view
        |> element("[phx-click='configure_button'][phx-value-id='#{button_element.id}']")
        |> render_click()

      # Should show wizard
      assert html =~ "Configure Button"
      assert html =~ "Find in Simulator"
      # Button wizard has Test Values step
      assert html =~ "Test Values"
    end

    test "does not open wizard when simulator is not connected", %{
      conn: conn,
      train: train,
      lever_element: lever_element
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :disconnected, client: nil}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      view
      |> element("[phx-click='configure_lever'][phx-value-id='#{lever_element.id}']")
      |> render_click()

      # Wizard should NOT open when simulator is not connected
      refute render(view) =~ "Configure Lever"
      refute render(view) =~ "Browse Simulator API"
    end
  end

  describe "wizard steps" do
    test "shows step indicators for lever configuration", %{
      conn: conn,
      train: train,
      lever_element: lever_element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      html =
        view
        |> element("[phx-click='configure_lever'][phx-value-id='#{lever_element.id}']")
        |> render_click()

      # Lever has 2 steps: Find in Simulator -> Confirm
      assert html =~ "Find in Simulator"
      assert html =~ "Confirm"
      # Should NOT show Test Values for lever
      refute html =~ "Test Values"
    end

    test "shows step indicators for button configuration", %{
      conn: conn,
      train: train,
      button_element: button_element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      html =
        view
        |> element("[phx-click='configure_button'][phx-value-id='#{button_element.id}']")
        |> render_click()

      # Button has 3 steps: Find in Simulator -> Test Values -> Confirm
      assert html =~ "Find in Simulator"
      assert html =~ "Test Values"
      assert html =~ "Confirm"
    end
  end

  describe "wizard cancellation" do
    test "closes wizard when cancel button is clicked", %{
      conn: conn,
      train: train,
      lever_element: lever_element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      # Open wizard
      view
      |> element("[phx-click='configure_lever'][phx-value-id='#{lever_element.id}']")
      |> render_click()

      assert render(view) =~ "Configure Lever"

      # Cancel the wizard (click X button - targets the component)
      view
      |> element("button[phx-click='cancel']")
      |> render_click()

      # Wait for the parent to process the message and re-render
      # The cancel event sends {:configuration_cancelled, id} to parent
      html = render(view)

      # Wizard should be closed
      refute html =~ "Configure Lever"
      refute html =~ "Find in Simulator"
    end
  end
end
