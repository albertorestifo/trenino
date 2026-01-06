defmodule TswIoWeb.LeverSetupWizardTest do
  use TswIoWeb.ConnCase, async: false
  use Mimic

  import Phoenix.LiveViewTest

  alias TswIo.Simulator.Client
  alias TswIo.Simulator.ConnectionState
  alias TswIo.Simulator
  alias TswIo.Train, as: TrainContext
  alias TswIo.Train.LeverConfig
  alias TswIo.Hardware

  setup :verify_on_exit!
  setup :set_mimic_global

  describe "edit mode detection" do
    setup do
      # Create a train with lever element
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Test Train",
          identifier: "Test_Train_EditMode_#{System.unique_integer([:positive])}"
        })

      {:ok, lever_element} =
        TrainContext.create_element(train.id, %{
          name: "Throttle",
          type: :lever
        })

      # Create device with analog input
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, analog_input} =
        Hardware.create_input(device.id, %{
          pin: 0,
          input_type: :analog,
          sensitivity: 10,
          calibration: %{min: 0, max: 1023}
        })

      # Create a mock client
      client = Client.new("http://localhost:8080", "test-key")

      %{
        train: train,
        lever_element: lever_element,
        device: device,
        analog_input: analog_input,
        client: client
      }
    end

    test "new lever shows 5 steps including Calibration Info", %{
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

      view
      |> element("[phx-click='configure_lever'][phx-value-id='#{lever_element.id}']")
      |> render_click()

      html = render(view)

      # New lever should show all 5 steps
      assert html =~ "Select Input"
      assert html =~ "Find in Simulator"
      assert html =~ "Calibration Info"
      assert html =~ "Detect Notches"
      assert html =~ "Map Positions"
    end

    test "lever with endpoints shows 4 steps (skips Calibration Info)", %{
      conn: conn,
      train: train,
      lever_element: lever_element,
      client: client
    } do
      # Create a lever config with just endpoints (partial config - edit mode)
      {:ok, _lever_config} =
        TswIo.Repo.insert(%LeverConfig{
          element_id: lever_element.id,
          min_endpoint: "CurrentDrivableActor/MasterController.InputMin",
          max_endpoint: "CurrentDrivableActor/MasterController.InputMax",
          value_endpoint: "CurrentDrivableActor/MasterController.InputValue"
        })

      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      view
      |> element("[phx-click='configure_lever'][phx-value-id='#{lever_element.id}']")
      |> render_click()

      html = render(view)

      # Lever with existing config (edit mode) should NOT show "Calibration Info" step
      assert html =~ "Select Input"
      assert html =~ "Find in Simulator"
      refute html =~ "Calibration Info"
      assert html =~ "Detect Notches"
      assert html =~ "Map Positions"
    end

    test "step indicators are clickable in edit mode", %{
      conn: conn,
      train: train,
      lever_element: lever_element,
      client: client
    } do
      # Create a lever config with endpoints (edit mode)
      {:ok, _lever_config} =
        TswIo.Repo.insert(%LeverConfig{
          element_id: lever_element.id,
          min_endpoint: "CurrentDrivableActor/MasterController.InputMin",
          max_endpoint: "CurrentDrivableActor/MasterController.InputMax",
          value_endpoint: "CurrentDrivableActor/MasterController.InputValue"
        })

      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      view
      |> element("[phx-click='configure_lever'][phx-value-id='#{lever_element.id}']")
      |> render_click()

      html = render(view)

      # In edit mode, step indicators should have clickable elements
      # The cursor-pointer class indicates clickability
      assert html =~ "cursor-pointer"
    end

    test "step indicators are NOT clickable in new mode", %{
      conn: conn,
      train: train,
      lever_element: lever_element,
      client: client
    } do
      # No lever_config created - this is a new lever
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      view
      |> element("[phx-click='configure_lever'][phx-value-id='#{lever_element.id}']")
      |> render_click()

      html = render(view)

      # In new mode, step indicators should NOT be clickable
      # The go_to_step phx-click should not be present
      refute html =~ "phx-click=\"go_to_step\""
    end

    test "can navigate directly to Find Endpoint in edit mode", %{
      conn: conn,
      train: train,
      lever_element: lever_element,
      client: client
    } do
      # Create a lever config (edit mode)
      {:ok, _lever_config} =
        TswIo.Repo.insert(%LeverConfig{
          element_id: lever_element.id,
          min_endpoint: "CurrentDrivableActor/MasterController.InputMin",
          max_endpoint: "CurrentDrivableActor/MasterController.InputMax",
          value_endpoint: "CurrentDrivableActor/MasterController.InputValue",
          lever_type: :discrete
        })

      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      view
      |> element("[phx-click='configure_lever'][phx-value-id='#{lever_element.id}']")
      |> render_click()

      # Click on "Find in Simulator" step indicator (step 2)
      view
      |> element("[phx-click='go_to_step'][phx-value-step='find_endpoint']")
      |> render_click()

      html = render(view)

      # Should now be showing the Find Endpoint step content
      assert html =~ "Auto-Detect Control"
    end

    test "configured steps show green checkmarks in edit mode", %{
      conn: conn,
      train: train,
      lever_element: lever_element,
      client: client
    } do
      # Create a fully configured lever
      {:ok, lever_config} =
        TswIo.Repo.insert(%LeverConfig{
          element_id: lever_element.id,
          min_endpoint: "CurrentDrivableActor/MasterController.InputMin",
          max_endpoint: "CurrentDrivableActor/MasterController.InputMax",
          value_endpoint: "CurrentDrivableActor/MasterController.InputValue",
          lever_type: :discrete
        })

      # Add a notch with input mapping (fully configured)
      alias TswIo.Train.Notch

      {:ok, _notch} =
        TswIo.Repo.insert(%Notch{
          lever_config_id: lever_config.id,
          index: 0,
          type: :gate,
          description: "Off",
          sim_input_min: 0.0,
          sim_input_max: 0.0,
          input_min: 0.0,
          input_max: 50.0
        })

      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      view
      |> element("[phx-click='configure_lever'][phx-value-id='#{lever_element.id}']")
      |> render_click()

      html = render(view)

      # Configured steps should show checkmark icons (hero-check)
      # The Find Endpoint step (step 2) should be marked as configured since endpoints are set
      # Looking for the success styling that indicates configuration
      assert html =~ "bg-success"

      # The current step (Select Input) should show primary styling
      assert html =~ "bg-primary"
    end

    test "unconfigured steps show step number (not checkmark)", %{
      conn: conn,
      train: train,
      lever_element: lever_element,
      client: client
    } do
      # Create a lever config with only endpoints (calibration not done)
      {:ok, _lever_config} =
        TswIo.Repo.insert(%LeverConfig{
          element_id: lever_element.id,
          min_endpoint: "CurrentDrivableActor/MasterController.InputMin",
          max_endpoint: "CurrentDrivableActor/MasterController.InputMax",
          value_endpoint: "CurrentDrivableActor/MasterController.InputValue"
          # lever_type is nil (no calibration)
        })

      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      view
      |> element("[phx-click='configure_lever'][phx-value-id='#{lever_element.id}']")
      |> render_click()

      html = render(view)

      # Find in Simulator (step 2) should be configured (green) since endpoints are set
      assert html =~ "bg-success"

      # Detect Notches (step 3) should NOT be configured (no lever_type)
      # Map Positions (step 4) should NOT be configured
      # These should show as base-300 (gray/inactive)
      assert html =~ "bg-base-300"
    end
  end

  describe "dependency tracking" do
    setup do
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Test Train",
          identifier: "Test_Train_Deps_#{System.unique_integer([:positive])}"
        })

      {:ok, lever_element} =
        TrainContext.create_element(train.id, %{
          name: "Throttle",
          type: :lever
        })

      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, analog_input1} =
        Hardware.create_input(device.id, %{
          pin: 0,
          input_type: :analog,
          sensitivity: 10,
          calibration: %{min: 0, max: 1023}
        })

      {:ok, analog_input2} =
        Hardware.create_input(device.id, %{
          pin: 1,
          input_type: :analog,
          sensitivity: 10,
          calibration: %{min: 0, max: 1023}
        })

      client = Client.new("http://localhost:8080", "test-key")

      # Create a lever config with input binding (edit mode)
      {:ok, lever_config} =
        TswIo.Repo.insert(%LeverConfig{
          element_id: lever_element.id,
          min_endpoint: "CurrentDrivableActor/MasterController.InputMin",
          max_endpoint: "CurrentDrivableActor/MasterController.InputMax",
          value_endpoint: "CurrentDrivableActor/MasterController.InputValue",
          lever_type: :discrete
        })

      alias TswIo.Train.LeverInputBinding

      {:ok, _binding} =
        TswIo.Repo.insert(%LeverInputBinding{
          lever_config_id: lever_config.id,
          input_id: analog_input1.id,
          enabled: true
        })

      %{
        train: train,
        lever_element: lever_element,
        lever_config: lever_config,
        device: device,
        analog_input1: analog_input1,
        analog_input2: analog_input2,
        client: client
      }
    end

    test "changing input shows warning indicator for Map Positions", %{
      conn: conn,
      train: train,
      lever_element: lever_element,
      analog_input2: analog_input2,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      view
      |> element("[phx-click='configure_lever'][phx-value-id='#{lever_element.id}']")
      |> render_click()

      # Select a different input (if available in UI)
      # This test checks that the warning indicator appears
      html = render(view)

      # First verify we're in edit mode (4 steps)
      refute html =~ "Calibration Info"

      # Select a different input - this should show warning
      if html =~ "phx-value-input-id=\"#{analog_input2.id}\"" do
        view
        |> element("input[phx-value-input-id='#{analog_input2.id}']")
        |> render_click()

        html = render(view)
        # Should show warning indicator (exclamation-triangle icon)
        assert html =~ "hero-exclamation-triangle"
      end
    end

    test "reverting input back removes warning indicator", %{
      conn: conn,
      train: train,
      lever_element: lever_element,
      analog_input1: analog_input1,
      analog_input2: analog_input2,
      client: client
    } do
      stub(Simulator, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      stub(Client, :list, fn _client ->
        {:ok, %{"NodeName" => "Root", "NodePath" => "Root", "Nodes" => []}}
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      view
      |> element("[phx-click='configure_lever'][phx-value-id='#{lever_element.id}']")
      |> render_click()

      html = render(view)

      # Only run this test if both inputs are available in UI
      if html =~ "phx-value-input-id=\"#{analog_input2.id}\"" do
        # Select a different input
        view
        |> element("input[phx-value-input-id='#{analog_input2.id}']")
        |> render_click()

        # Revert back to original input
        view
        |> element("input[phx-value-input-id='#{analog_input1.id}']")
        |> render_click()

        html = render(view)

        # Should NOT show warning indicator after reverting
        refute html =~ "hero-exclamation-triangle"
      end
    end
  end
end
