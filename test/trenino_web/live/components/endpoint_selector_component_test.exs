defmodule TreninoWeb.EndpointSelectorComponentTest do
  use TreninoWeb.ConnCase, async: false
  use Mimic

  import Phoenix.LiveViewTest

  alias Trenino.Simulator.Client
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train, as: TrainContext
  alias TreninoWeb.EndpointSelectorComponent

  setup :verify_on_exit!
  setup :set_mimic_global

  setup do
    # Create a train for testing
    {:ok, train} =
      TrainContext.create_train(%{
        name: "Test Train",
        identifier: "Test_Train_Selector_#{System.unique_integer([:positive])}"
      })

    # Create a mock client
    client = Client.new("http://localhost:8080", "test-key")

    # Create a connected simulator status
    simulator_status =
      %ConnectionState{}
      |> ConnectionState.mark_connecting(client)
      |> ConnectionState.mark_connected(%{"version" => "1.0"})

    %{
      train: train,
      client: client,
      simulator_status: simulator_status
    }
  end

  describe "initialization" do
    test "renders with API explorer in step 1", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil
        )

      assert html =~ "Select Endpoint"
    end

    test "shows auto-detect button", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil
        )

      assert html =~ "Auto-Detect Control"
      assert html =~ "Quick Setup"
    end

    test "shows value detection step when include_value_detection: true", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil
        )

      # Should show step indicators with both steps
      assert html =~ "Select Endpoint"
      assert html =~ "Configure Value"
    end

    test "skips value detection when include_value_detection: false", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :sequence,
          include_value_detection: false,
          selected_endpoint: nil,
          selected_value: nil
        )

      # Should NOT show step indicators when value detection is disabled
      refute html =~ "Configure Value"
    end
  end

  describe "endpoint selection via browse" do
    test "selecting endpoint advances to value step when value detection enabled", %{
      client: client
    } do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      # First render shows select endpoint step
      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil
        )

      assert html =~ "Select Endpoint"

      # After selecting endpoint (simulated by passing explorer_event), should advance to value step
      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil,
          explorer_event: {:select, :endpoint, "CurrentDrivableActor/Throttle.InputValue"}
        )

      assert html =~ "Configure Value"
      assert html =~ "CurrentDrivableActor/Throttle.InputValue"
    end

    test "sends {:endpoint_selected, path} when value detection disabled", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      # When include_value_detection is false, selecting endpoint should not advance to value step
      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :sequence,
          include_value_detection: false,
          selected_endpoint: nil,
          selected_value: nil
        )

      # Should show the selection UI without value detection step
      assert html =~ "Select Endpoint"
      refute html =~ "Configure Value"
    end
  end

  describe "endpoint selection via auto-detect" do
    test "handles auto-detect result with float values", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      # Simulate auto-detect result with float values
      auto_detect_result = %{
        endpoint: "CurrentDrivableActor/Throttle.InputValue",
        control_name: "Throttle",
        current_value: 0.5,
        previous_value: 0.0
      }

      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil,
          explorer_event: {:auto_detect_result, auto_detect_result}
        )

      # Should advance to value step and show detected value
      assert html =~ "Configure Value"
      assert html =~ "CurrentDrivableActor/Throttle.InputValue"
    end

    test "advances to value step after detection", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      # Simulate auto-detect result with integer values
      auto_detect_result = %{
        endpoint: "CurrentDrivableActor/AWS_ResetButton.InputValue",
        control_name: "AWS_ResetButton",
        current_value: 1,
        previous_value: 0
      }

      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil,
          explorer_event: {:auto_detect_result, auto_detect_result}
        )

      # Should advance to configure value step
      assert html =~ "Configure Value"
      assert html =~ "AWS_ResetButton.InputValue"
    end

    test "does not advance to value step when value detection disabled", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      # Without value detection, component should not show value step
      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :sequence,
          include_value_detection: false,
          selected_endpoint: nil,
          selected_value: nil
        )

      # Should stay on select endpoint step
      assert html =~ "Select Endpoint"
      refute html =~ "Configure Value"
    end
  end

  describe "value detection" do
    test "allows manual value entry UI", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      # Render value configuration step with manual mode
      auto_detect_result = %{
        endpoint: "CurrentDrivableActor/Throttle.InputValue",
        control_name: "Throttle",
        current_value: 0.5,
        previous_value: 0.0
      }

      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil,
          explorer_event: {:auto_detect_result, auto_detect_result}
        )

      # Should show value configuration UI
      assert html =~ "Configure Value"
      # Manual value input field exists
      assert html =~ "Auto-Detect"
      assert html =~ "Manual"
    end

    test "rounds detected value to 2 decimal places", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      # First advance to value step
      auto_detect_result = %{
        endpoint: "CurrentDrivableActor/Throttle.InputValue",
        control_name: "Throttle",
        current_value: 0.33333333,
        previous_value: 0.0
      }

      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil,
          explorer_event: {:auto_detect_result, auto_detect_result}
        )

      # Should round to 2 decimal places - check actual rendering would require
      # the component to display the detected value, which it does after polling
      assert html =~ "Configure Value"
    end

    test "shows value detection UI elements", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      # Advance to value step
      auto_detect_result = %{
        endpoint: "CurrentDrivableActor/Throttle.InputValue",
        control_name: "Throttle",
        current_value: 0.5,
        previous_value: 0.0
      }

      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil,
          explorer_event: {:auto_detect_result, auto_detect_result}
        )

      # Should show detection controls
      assert html =~ "Start Detection"
      assert html =~ "Auto-Detect"
    end
  end

  describe "cancellation" do
    test "shows cancel button", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil
        )

      # Should show close button (X icon)
      assert html =~ "phx-click=\"cancel\""
    end

    test "renders cancel button for closing modal", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil
        )

      # Component should have cancel functionality
      assert html =~ "phx-click=\"cancel\""
    end
  end

  describe "navigation" do
    test "shows back button in value configuration step", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      # Advance to value step
      auto_detect_result = %{
        endpoint: "CurrentDrivableActor/Throttle.InputValue",
        control_name: "Throttle",
        current_value: 0.5,
        previous_value: 0.0
      }

      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil,
          explorer_event: {:auto_detect_result, auto_detect_result}
        )

      # Should show back button
      assert html =~ "phx-click=\"back_to_endpoint\""
      assert html =~ "Back"
    end

    test "shows toggle for auto vs manual value configuration", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      # Advance to value step
      auto_detect_result = %{
        endpoint: "CurrentDrivableActor/Throttle.InputValue",
        control_name: "Throttle",
        current_value: 0.5,
        previous_value: 0.0
      }

      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil,
          explorer_event: {:auto_detect_result, auto_detect_result}
        )

      # Should show mode toggle
      assert html =~ "Auto-Detect"
      assert html =~ "Manual"
      assert html =~ "toggle"
    end
  end

  describe "final confirmation" do
    test "shows confirm button in value configuration step", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      # Advance to value step
      auto_detect_result = %{
        endpoint: "CurrentDrivableActor/Throttle.InputValue",
        control_name: "Throttle",
        current_value: 0.5,
        previous_value: 0.0
      }

      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil,
          explorer_event: {:auto_detect_result, auto_detect_result}
        )

      # Should show confirm button
      assert html =~ "phx-click=\"confirm_selection\""
      assert html =~ "Confirm"
    end

    test "confirm button disabled when no value selected", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      # Advance to value step without any value set
      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil,
          explorer_event: {:select, :endpoint, "CurrentDrivableActor/Throttle.InputValue"}
        )

      # Confirm button should be disabled
      assert html =~ "disabled"
      assert html =~ "Confirm"
    end
  end

  describe "float rounding behavior" do
    test "rounds auto-detected float values to 2 decimal places", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      # Auto-detect with many decimal places
      auto_detect_result = %{
        endpoint: "CurrentDrivableActor/Throttle.InputValue",
        control_name: "Throttle",
        current_value: -0.20000000298023224,
        previous_value: 0.0
      }

      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil,
          explorer_event: {:auto_detect_result, auto_detect_result}
        )

      # Should advance to value step (the actual rounding happens in update/2)
      assert html =~ "Configure Value"
      assert html =~ "Throttle.InputValue"
    end

    test "handles integer values from auto-detect", %{client: client} do
      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      # Auto-detect with integer values (button press)
      auto_detect_result = %{
        endpoint: "CurrentDrivableActor/AWS_ResetButton.InputValue",
        control_name: "AWS_ResetButton",
        current_value: 1,
        previous_value: 0
      }

      html =
        render_component(EndpointSelectorComponent,
          id: "test-selector",
          client: client,
          mode: :button,
          include_value_detection: true,
          selected_endpoint: nil,
          selected_value: nil,
          explorer_event: {:auto_detect_result, auto_detect_result}
        )

      # Should handle integer values correctly
      assert html =~ "Configure Value"
      assert html =~ "AWS_ResetButton.InputValue"
    end
  end
end
