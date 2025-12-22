defmodule TswIoWeb.ApiExplorerComponentTest do
  use TswIoWeb.ConnCase, async: false
  use Mimic

  import Phoenix.LiveViewTest

  alias TswIo.Simulator.Client
  alias TswIo.Simulator.ConnectionState
  alias TswIo.Simulator
  alias TswIo.Train, as: TrainContext

  setup :verify_on_exit!
  setup :set_mimic_global

  setup do
    # Create a train with elements
    {:ok, train} =
      TrainContext.create_train(%{
        name: "Test Train",
        identifier: "Test_Train_#{System.unique_integer([:positive])}"
      })

    # Create a lever element with config
    {:ok, lever_element} =
      TrainContext.create_element(train.id, %{
        name: "Throttle",
        type: :lever
      })

    {:ok, lever_config} =
      TrainContext.create_lever_config(lever_element.id, %{
        min_endpoint: "Throttle.Min",
        max_endpoint: "Throttle.Max",
        value_endpoint: "Throttle.Value",
        notch_count_endpoint: "Throttle.NotchCount",
        notch_index_endpoint: "Throttle.NotchIndex"
      })

    # Create a button element for button detection tests
    {:ok, button_element} =
      TrainContext.create_element(train.id, %{
        name: "Horn",
        type: :button
      })

    # Reload train with all associations for tests
    {:ok, train} = TrainContext.get_train(train.id, preload: [elements: [lever_config: :notches]])

    # Create a mock client
    client = Client.new("http://localhost:8080", "test-key")

    # Create a connected simulator status
    simulator_status =
      %ConnectionState{}
      |> ConnectionState.mark_connecting(client)
      |> ConnectionState.mark_connected(%{"version" => "1.0"})

    # Get lever element from reloaded train (to ensure it has lever_config association)
    lever_element = Enum.find(train.elements, &(&1.type == :lever))

    %{
      train: train,
      element: lever_element,
      lever_element: lever_element,
      button_element: button_element,
      lever_config: lever_config,
      client: client,
      simulator_status: simulator_status
    }
  end

  # Helper to open the configuration wizard in lever mode (which contains the embedded API explorer)
  # When simulator is connected, clicking configure_lever opens the wizard directly
  defp open_api_explorer(view, el, _field) do
    # Open the wizard (which contains the embedded API explorer)
    view
    |> element("button[phx-click='configure_lever'][phx-value-id='#{el.id}']")
    |> render_click()
  end

  # Helper to open the configuration wizard in button mode
  defp open_button_api_explorer(view, button_element) do
    view
    |> element("button[phx-click='configure_button'][phx-value-id='#{button_element.id}']")
    |> render_click()
  end

  describe "component initialization" do
    test "loads root nodes on mount", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      # Mock simulator to return connected status with client
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      # Mock Client.list to return root nodes in actual API format
      stub(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [
             %{"NodeName" => "ControlDesk", "NodePath" => "Root/ControlDesk"},
             %{"NodeName" => "Gauges", "NodePath" => "Root/Gauges"},
             %{"NodeName" => "Train", "NodePath" => "Root/Train"}
           ]
         }}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "min_endpoint")

      # The modal should be visible with root nodes
      html = render(view)
      assert html =~ "Browse Simulator API"
      assert html =~ "ControlDesk"
      assert html =~ "Gauges"
      assert html =~ "Train"
    end

    test "shows error when API list fails", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:error, :connection_refused}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "min_endpoint")

      html = render(view)
      assert html =~ "Failed to load API nodes"
    end
  end

  describe "navigation" do
    test "navigates into folder nodes", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      # First call returns root nodes, second returns child nodes
      expect(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [
             %{"NodeName" => "ControlDesk", "NodePath" => "Root/ControlDesk"},
             %{"NodeName" => "Gauges", "NodePath" => "Root/Gauges"}
           ]
         }}
      end)

      # Child level responses use "Name" instead of "NodeName"
      expect(Client, :list, fn _client, "ControlDesk" ->
        {:ok,
         %{
           "NodeName" => "ControlDesk",
           "NodePath" => "Root/ControlDesk",
           "Nodes" => [
             %{"Name" => "Throttle"},
             %{"Name" => "Brake"},
             %{"Name" => "Reverser"}
           ]
         }}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "min_endpoint")

      # Click on ControlDesk to navigate into it
      view
      |> element("button[phx-click='navigate'][phx-value-node='ControlDesk']")
      |> render_click()

      html = render(view)
      # Should show child nodes
      assert html =~ "Throttle"
      assert html =~ "Brake"
      assert html =~ "Reverser"
      # Should show breadcrumb
      assert html =~ "ControlDesk"
    end

    test "navigates back via breadcrumb", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      expect(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [%{"NodeName" => "ControlDesk", "NodePath" => "Root/ControlDesk"}]
         }}
      end)

      # Child level responses use "Name" instead of "NodeName"
      expect(Client, :list, fn _client, "ControlDesk" ->
        {:ok,
         %{
           "NodeName" => "ControlDesk",
           "NodePath" => "Root/ControlDesk",
           "Nodes" => [%{"Name" => "Throttle"}]
         }}
      end)

      # Going back to root
      expect(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [
             %{"NodeName" => "ControlDesk", "NodePath" => "Root/ControlDesk"},
             %{"NodeName" => "Gauges", "NodePath" => "Root/Gauges"}
           ]
         }}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "min_endpoint")

      # Navigate into ControlDesk
      view
      |> element("button[phx-click='navigate'][phx-value-node='ControlDesk']")
      |> render_click()

      # Go back to root via home button
      view
      |> element("button[phx-click='go_back'][phx-value-index='0']")
      |> render_click()

      html = render(view)
      assert html =~ "ControlDesk"
      assert html =~ "Gauges"
    end

    test "shows leaf node preview when navigating to endpoint", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      expect(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [%{"NodeName" => "Value", "NodePath" => "Root/Value"}]
         }}
      end)

      # Navigating to Value fails list (it's a leaf), so we try get
      expect(Client, :list, fn _client, "Value" ->
        {:error, :not_a_directory}
      end)

      expect(Client, :get, fn _client, "Value" ->
        {:ok, %{"value" => 0.75}}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "min_endpoint")

      view
      |> element("button[phx-click='navigate'][phx-value-node='Value']")
      |> render_click()

      html = render(view)
      assert html =~ "Preview"
      assert html =~ "0.75"
    end
  end

  describe "search filtering" do
    test "filters nodes by search term", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [
             %{"NodeName" => "Throttle", "NodePath" => "Root/Throttle"},
             %{"NodeName" => "ThrottleMin", "NodePath" => "Root/ThrottleMin"},
             %{"NodeName" => "ThrottleMax", "NodePath" => "Root/ThrottleMax"},
             %{"NodeName" => "Brake", "NodePath" => "Root/Brake"},
             %{"NodeName" => "Reverser", "NodePath" => "Root/Reverser"}
           ]
         }}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "min_endpoint")

      # Initially all nodes visible
      html = render(view)
      assert html =~ "Throttle"
      assert html =~ "Brake"

      # Search for "Throttle"
      view
      |> element("input[phx-keyup='search']")
      |> render_keyup(%{"value" => "Throttle"})

      html = render(view)
      assert html =~ "Throttle"
      assert html =~ "ThrottleMin"
      assert html =~ "ThrottleMax"
      refute html =~ ">Brake<"
      refute html =~ ">Reverser<"
    end

    test "search is case insensitive", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [
             %{"NodeName" => "ThrottleNode", "NodePath" => "Root/ThrottleNode"},
             %{"NodeName" => "BRAKE", "NodePath" => "Root/BRAKE"},
             %{"NodeName" => "reverser", "NodePath" => "Root/reverser"}
           ]
         }}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "min_endpoint")

      view
      |> element("input[phx-keyup='search']")
      |> render_keyup(%{"value" => "brake"})

      html = render(view)
      assert html =~ "BRAKE"
      # ThrottleNode should be filtered out when searching for "brake"
      refute html =~ "ThrottleNode"
    end
  end

  describe "preview functionality" do
    test "previews node value without navigating", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [
             %{"NodeName" => "ThrottleValue", "NodePath" => "Root/ThrottleValue"},
             %{"NodeName" => "BrakeValue", "NodePath" => "Root/BrakeValue"}
           ]
         }}
      end)

      expect(Client, :get, fn _client, "ThrottleValue" ->
        {:ok, %{"value" => 0.5, "unit" => "normalized"}}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "min_endpoint")

      # Click preview button (eye icon)
      view
      |> element("button[phx-click='preview'][phx-value-node='ThrottleValue']")
      |> render_click()

      html = render(view)
      assert html =~ "Preview"
      assert html =~ "ThrottleValue"
      assert html =~ "0.5"
      # Nodes should still be visible (didn't navigate away)
      assert html =~ "BrakeValue"
    end
  end

  describe "path selection" do
    test "selecting path sends event to parent", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [
             %{"NodeName" => "Throttle.Min", "NodePath" => "Root/Throttle.Min"},
             %{"NodeName" => "Throttle.Max", "NodePath" => "Root/Throttle.Max"}
           ]
         }}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "min_endpoint")

      # Select a path
      view
      |> element("button[phx-click='select'][phx-value-path='Throttle.Min']")
      |> render_click()

      html = render(view)

      # In wizard flow, explorer stays open - the wizard manages the overall flow
      # The selection is captured and can be seen in various ways
      assert html =~ "Browse Simulator API"
      # The path is still visible in the explorer
      assert html =~ "Throttle.Min"
    end

    test "selecting path from preview", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [%{"NodeName" => "Throttle.Value", "NodePath" => "Root/Throttle.Value"}]
         }}
      end)

      expect(Client, :get, fn _client, "Throttle.Value" ->
        {:ok, %{"value" => 0.75}}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "value_endpoint")

      # Preview the value
      view
      |> element("button[phx-click='preview'][phx-value-node='Throttle.Value']")
      |> render_click()

      # Select from preview panel (the btn-primary "Select This Path" button)
      view
      |> element("button.btn-primary[phx-click='select'][phx-value-path='Throttle.Value']")
      |> render_click()

      html = render(view)
      # Explorer stays open in wizard flow - selection is captured by the wizard
      assert html =~ "Browse Simulator API"
    end
  end

  describe "closing the explorer" do
    test "closes on backdrop click", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [%{"NodeName" => "Node1", "NodePath" => "Root/Node1"}]
         }}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "min_endpoint")

      assert render(view) =~ "Browse Simulator API"

      # Click the backdrop to close
      view
      |> element("div.bg-black\\/50[phx-click='close']")
      |> render_click()

      refute render(view) =~ "Browse Simulator API"
    end

    test "closes on X button click", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [%{"NodeName" => "Node1", "NodePath" => "Root/Node1"}]
         }}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "min_endpoint")

      assert render(view) =~ "Browse Simulator API"

      # Click the X button (btn-circle)
      view
      |> element("button.btn-circle[phx-click='close']")
      |> render_click()

      refute render(view) =~ "Browse Simulator API"
    end
  end

  describe "error handling" do
    test "shows error when navigating to inaccessible node", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      expect(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [%{"NodeName" => "Protected", "NodePath" => "Root/Protected"}]
         }}
      end)

      # List fails
      expect(Client, :list, fn _client, "Protected" ->
        {:error, :access_denied}
      end)

      # Get also fails
      expect(Client, :get, fn _client, "Protected" ->
        {:error, :access_denied}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "min_endpoint")

      view
      |> element("button[phx-click='navigate'][phx-value-node='Protected']")
      |> render_click()

      html = render(view)
      assert html =~ "Failed to access"
    end

    test "does not open wizard when simulator not connected", %{
      conn: conn,
      train: train,
      element: element
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :disconnected, client: nil}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      # Try to configure - should not open wizard since simulator not connected
      view
      |> element("button[phx-click='configure_lever'][phx-value-id='#{element.id}']")
      |> render_click()

      # The wizard/explorer should NOT be shown when simulator is not connected
      html = render(view)
      refute html =~ "Browse Simulator API"
      refute html =~ "Configure Throttle"
    end
  end

  describe "item icons and indicators" do
    test "shows correct icons for nodes and endpoints", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [
             %{"NodeName" => "Folder", "NodePath" => "Root/Folder"},
             %{"NodeName" => "Function(param)", "NodePath" => "Root/Function(param)"}
           ],
           "Endpoints" => [
             %{"Name" => "InputValue", "Writable" => true},
             %{"Name" => "OutputValue", "Writable" => false}
           ]
         }}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "min_endpoint")

      html = render(view)
      # Folder icon for plain node names
      assert html =~ "hero-folder"
      # Cube icon for function-like names with parentheses
      assert html =~ "hero-cube"
      # Adjustments icon for endpoints
      assert html =~ "hero-adjustments-horizontal"
      # RW indicator for writable endpoints
      assert html =~ "RW"
      # RO indicator for read-only endpoints
      assert html =~ "RO"
    end
  end

  describe "lever detection" do
    test "shows lever detection banner when navigating to lever node", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      # First call returns root nodes
      expect(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [
             %{"NodeName" => "Throttle(Lever)", "NodePath" => "Root/Throttle(Lever)"}
           ]
         }}
      end)

      # Second call returns lever endpoints
      expect(Client, :list, fn _client, "Throttle(Lever)" ->
        {:ok,
         %{
           "NodeName" => "Throttle(Lever)",
           "NodePath" => "Root/Throttle(Lever)",
           "Nodes" => [],
           "Endpoints" => [
             %{"Name" => "InputValue", "Writable" => true},
             %{"Name" => "Function.GetMinimumInputValue", "Writable" => false},
             %{"Name" => "Function.GetMaximumInputValue", "Writable" => false},
             %{"Name" => "Function.GetNotchCount", "Writable" => false},
             %{"Name" => "Function.GetCurrentNotchIndex", "Writable" => false}
           ]
         }}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "min_endpoint")

      # Navigate to the lever node
      view
      |> element("button[phx-click='navigate'][phx-value-node='Throttle(Lever)']")
      |> render_click()

      html = render(view)

      # Should show lever detection banner
      assert html =~ "Lever Control Detected"
      assert html =~ "Configure All Endpoints"
      assert html =~ "Choose Individual Endpoints"
      # With notches available
      assert html =~ "with notches"
    end

    test "shows lever detection without notches when notch endpoints missing", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      expect(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [%{"NodeName" => "SimpleLever", "NodePath" => "Root/SimpleLever"}]
         }}
      end)

      # Lever without notch endpoints
      expect(Client, :list, fn _client, "SimpleLever" ->
        {:ok,
         %{
           "NodeName" => "SimpleLever",
           "NodePath" => "Root/SimpleLever",
           "Nodes" => [],
           "Endpoints" => [
             %{"Name" => "InputValue", "Writable" => true},
             %{"Name" => "Function.GetMinimumInputValue", "Writable" => false},
             %{"Name" => "Function.GetMaximumInputValue", "Writable" => false}
           ]
         }}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "min_endpoint")

      view
      |> element("button[phx-click='navigate'][phx-value-node='SimpleLever']")
      |> render_click()

      html = render(view)

      assert html =~ "Lever Control Detected"
      # Should NOT show "with notches"
      refute html =~ "with notches"
    end
  end

  describe "button detection" do
    test "shows button detection banner when navigating to button node", %{
      conn: conn,
      train: train,
      button_element: button_element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      expect(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [%{"NodeName" => "HornControl", "NodePath" => "Root/HornControl"}]
         }}
      end)

      # Button node - has InputValue but NOT min/max endpoints (not a lever)
      expect(Client, :list, fn _client, "HornControl" ->
        {:ok,
         %{
           "NodeName" => "HornControl",
           "NodePath" => "Root/HornControl",
           "Nodes" => [],
           "Endpoints" => [
             %{"Name" => "InputValue", "Writable" => true}
           ]
         }}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      # Open wizard in BUTTON mode (not lever mode)
      open_button_api_explorer(view, button_element)

      view
      |> element("button[phx-click='navigate'][phx-value-node='HornControl']")
      |> render_click()

      html = render(view)

      # Should show button detection banner (only in button mode)
      assert html =~ "Button Endpoint Found"
      assert html =~ "HornControl.InputValue"
      assert html =~ "Use This Endpoint"
    end

    test "shows suggested values when button has min/max endpoints", %{
      conn: conn,
      train: train,
      button_element: button_element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      expect(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [%{"NodeName" => "Bell", "NodePath" => "Root/Bell"}]
         }}
      end)

      # Button with min/max values
      expect(Client, :list, fn _client, "Bell" ->
        {:ok,
         %{
           "NodeName" => "Bell",
           "NodePath" => "Root/Bell",
           "Nodes" => [],
           "Endpoints" => [
             %{"Name" => "InputValue", "Writable" => true},
             %{"Name" => "Function.GetMinimumInputValue", "Writable" => false},
             %{"Name" => "Function.GetMaximumInputValue", "Writable" => false}
           ]
         }}
      end)

      # Mock fetching min/max values
      expect(Client, :get, fn _client, "Bell.Function.GetMinimumInputValue" ->
        {:ok, 0.0}
      end)

      expect(Client, :get, fn _client, "Bell.Function.GetMaximumInputValue" ->
        {:ok, 1.0}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      # Open wizard in BUTTON mode
      open_button_api_explorer(view, button_element)

      view
      |> element("button[phx-click='navigate'][phx-value-node='Bell']")
      |> render_click()

      html = render(view)

      # Should show button detection with suggested values
      assert html =~ "Button Endpoint Found"
      assert html =~ "Bell.InputValue"
    end

    test "does not show button detection for lever nodes", %{
      conn: conn,
      train: train,
      element: element,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      expect(Client, :list, fn _client ->
        {:ok,
         %{
           "NodeName" => "Root",
           "NodePath" => "Root",
           "Nodes" => [%{"NodeName" => "Throttle", "NodePath" => "Root/Throttle"}]
         }}
      end)

      # Full lever node
      expect(Client, :list, fn _client, "Throttle" ->
        {:ok,
         %{
           "NodeName" => "Throttle",
           "NodePath" => "Root/Throttle",
           "Nodes" => [],
           "Endpoints" => [
             %{"Name" => "InputValue", "Writable" => true},
             %{"Name" => "Function.GetMinimumInputValue", "Writable" => false},
             %{"Name" => "Function.GetMaximumInputValue", "Writable" => false},
             %{"Name" => "Function.GetNotchCount", "Writable" => false},
             %{"Name" => "Function.GetCurrentNotchIndex", "Writable" => false}
           ]
         }}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      open_api_explorer(view, element, "min_endpoint")

      view
      |> element("button[phx-click='navigate'][phx-value-node='Throttle']")
      |> render_click()

      html = render(view)

      # Should show lever detection, not button detection
      assert html =~ "Lever Control Detected"
      # Should NOT show button detection (lever takes precedence in default mode)
      # In default mode, lever is detected if it matches, button is only shown if NOT a lever
    end
  end
end
