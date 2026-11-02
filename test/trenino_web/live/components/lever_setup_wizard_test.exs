defmodule TreninoWeb.LeverSetupWizardTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Trenino.Hardware
  alias Trenino.Simulator
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.LeverConfig

  setup :verify_on_exit!
  setup :set_mimic_global

  describe "edit mode detection" do
    setup do
      # Create a train with lever element
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Test Train",
          identifiers: [
            %{identifier: "Test_Train_EditMode_#{System.unique_integer([:positive])}"}
          ]
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
        Trenino.Repo.insert(%LeverConfig{
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
        Trenino.Repo.insert(%LeverConfig{
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
        Trenino.Repo.insert(%LeverConfig{
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
        Trenino.Repo.insert(%LeverConfig{
          element_id: lever_element.id,
          min_endpoint: "CurrentDrivableActor/MasterController.InputMin",
          max_endpoint: "CurrentDrivableActor/MasterController.InputMax",
          value_endpoint: "CurrentDrivableActor/MasterController.InputValue",
          lever_type: :discrete
        })

      # Add a notch with input mapping (fully configured)
      alias Trenino.Train.Notch

      {:ok, _notch} =
        Trenino.Repo.insert(%Notch{
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
        Trenino.Repo.insert(%LeverConfig{
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

  describe "lever type selection" do
    setup do
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Test Train",
          identifiers: [
            %{identifier: "Test_Train_LeverType_#{System.unique_integer([:positive])}"}
          ]
        })

      {:ok, lever_element} =
        TrainContext.create_element(train.id, %{
          name: "Throttle",
          type: :lever
        })

      client = Client.new("http://localhost:8080", "test-key")

      %{
        train: train,
        lever_element: lever_element,
        client: client
      }
    end

    test "shows Analog option in lever type selection", %{
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

      # Should show Analog option
      assert html =~ "Analog Potentiometer"
    end

    test "selecting Analog shows pin selection step", %{
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

      # Select analog lever type
      view
      |> element("input[value='analog']")
      |> render_click()

      html = render(view)

      # Should show input selection step
      assert html =~ "Select Hardware Input"
    end
  end

  describe "chip inputs" do
    test "lever setup offers a calibrated ADS1115 input", %{conn: conn} do
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Chip Train",
          identifiers: [%{identifier: "Chip_Train_#{System.unique_integer([:positive])}"}]
        })

      {:ok, lever_element} =
        TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, device} = Hardware.create_device(%{name: "Chip Device"})

      {:ok, %{inputs: [input]}} =
        Hardware.create_i2c_module(device.id, %{
          module_chip: :ads1115,
          i2c_address: 0x48,
          params: %{channel_mask: 0x01, gain: 0},
          channels: %{0 => %{name: "ADS Throttle"}}
        })

      {:ok, _} =
        Hardware.save_calibration(input.id, %{
          max_hardware_value: 1023,
          min_value: 0,
          max_value: 1000,
          has_rollover: false,
          is_inverted: false
        })

      client = Client.new("http://localhost:8080", "test-key")

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

      view |> element("input[value='analog']") |> render_click()

      assert render(view) =~ "ADS Throttle"
    end
  end

  describe "dependency tracking" do
    setup do
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Test Train",
          identifiers: [
            %{identifier: "Test_Train_Deps_#{System.unique_integer([:positive])}"}
          ]
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
        Trenino.Repo.insert(%LeverConfig{
          element_id: lever_element.id,
          min_endpoint: "CurrentDrivableActor/MasterController.InputMin",
          max_endpoint: "CurrentDrivableActor/MasterController.InputMax",
          value_endpoint: "CurrentDrivableActor/MasterController.InputValue",
          lever_type: :discrete
        })

      alias Trenino.Train.LeverInputBinding

      {:ok, _binding} =
        Trenino.Repo.insert(%LeverInputBinding{
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

  describe "map positions step" do
    alias TreninoWeb.LeverSetupWizard

    @notches [
      %{
        index: 0,
        type: :gate,
        value: 0.0,
        min_value: nil,
        max_value: nil,
        sim_input_min: 0.0,
        sim_input_max: 0.0,
        description: "Idle"
      },
      %{
        index: 1,
        type: :linear,
        value: nil,
        min_value: 0.0,
        max_value: 100.0,
        sim_input_min: 0.1,
        sim_input_max: 0.9,
        description: "Linear 0.0 to 100.0"
      },
      %{
        index: 2,
        type: :gate,
        value: -11.0,
        min_value: nil,
        max_value: nil,
        sim_input_min: 1.0,
        sim_input_max: 1.0,
        description: "Gate at output -11"
      }
    ]

    defp range(notch_index, min_pct, max_pct, sim_at_min, sim_at_max) do
      notch = Enum.at(@notches, notch_index)

      {out_min, out_max} =
        if notch.type == :gate,
          do: {notch.value, notch.value},
          else: {notch.min_value, notch.max_value}

      %{
        notch_index: notch_index,
        description: notch.description,
        type: notch.type,
        min_pct: min_pct,
        max_pct: max_pct,
        sim_at_min: sim_at_min,
        sim_at_max: sim_at_max,
        sim_output_min: out_min,
        sim_output_max: out_max
      }
    end

    defp end_info(notch_index, hardware_pct, sim_input) do
      notch = Enum.at(@notches, notch_index)

      %{
        notch_index: notch_index,
        description: notch.description,
        type: notch.type,
        hardware_pct: hardware_pct,
        sim_input: sim_input
      }
    end

    defp forward_preview do
      %{
        status: :ready,
        direction_known: true,
        inverted: false,
        low_end: end_info(0, 0.0, 0.0),
        high_end: end_info(2, 100.0, 1.0),
        live: end_info(1, 50.0, 0.5),
        hardware_ranges: [
          range(0, 0.0, 5.0, 0.0, 0.0),
          range(1, 10.0, 90.0, 0.1, 0.9),
          range(2, 95.0, 100.0, 1.0, 1.0)
        ]
      }
    end

    defp inverted_preview do
      %{
        status: :ready,
        direction_known: true,
        inverted: true,
        low_end: end_info(2, 0.0, 1.0),
        high_end: end_info(0, 100.0, 0.0),
        live: end_info(1, 36.0, 0.64),
        hardware_ranges: [
          range(2, 0.0, 5.0, 1.0, 1.0),
          range(1, 10.0, 90.0, 0.9, 0.1),
          range(0, 95.0, 100.0, 0.0, 0.0)
        ]
      }
    end

    defp mapping_state(overrides) do
      base = %{
        lever_config_id: 1,
        notch_count: length(@notches),
        notches: @notches,
        total_travel: 1000,
        current_step: {:mapping_notch, 1},
        current_notch_index: 1,
        current_notch: Enum.at(@notches, 1),
        is_capturing: true,
        captured_ranges: [%{min: 0, max: 50}, nil, nil],
        current_value: 640,
        current_min: 120,
        current_max: 880,
        sample_count: 42,
        can_capture: true,
        all_captured: false,
        result: nil
      }

      Map.merge(base, Map.new(overrides))
    end

    defp review_state(preview) do
      mapping_state(
        current_step: :preview,
        current_notch_index: nil,
        current_notch: nil,
        is_capturing: false,
        all_captured: true,
        captured_ranges: [%{min: 0, max: 50}, %{min: 100, max: 900}, %{min: 950, max: 1000}],
        preview: preview
      )
    end

    defp render_step(state) do
      render_component(&LeverSetupWizard.step_map_notches/1,
        mapping_state: state,
        can_proceed: false,
        myself: %Phoenix.LiveComponent.CID{cid: 1}
      )
    end

    test "capturing a linear notch shows full description, output and new copy" do
      html = render_step(mapping_state(preview: forward_preview()))

      assert html =~ "Notch 2 of 3: Linear 0.0 to 100.0"
      assert html =~ "Train output: 0 → 100"

      assert html =~
               "Sweep your lever across the whole Linear 0.0 to 100.0 range — either direction is fine."

      assert html =~ "Lowest"
      assert html =~ "Now"
      assert html =~ "Highest"
      assert html =~ "64%"
      assert html =~ "12%"
      assert html =~ "88%"
      assert html =~ "raw 640"
      assert html =~ "→ Linear 0.0 to 100.0, sim 0.50"
      refute html =~ "Linear…"
      refute html =~ "automatically detected when you save"
    end

    test "gate notch uses gate copy and single output value" do
      state =
        mapping_state(
          current_step: {:mapping_notch, 2},
          current_notch_index: 2,
          current_notch: Enum.at(@notches, 2),
          preview: forward_preview()
        )

      html = render_step(state)

      assert html =~ "Notch 3 of 3: Gate at output -11"
      assert html =~ "Train output: -11"

      assert html =~
               "Move your lever to where Gate at output -11 should be, then wiggle it within that position."
    end

    test "simulator bar is captioned and labelled with notch names, not MIN/MAX" do
      html = render_step(mapping_state(preview: forward_preview()))

      assert html =~ "Simulator notches (in simulator order)"
      assert html =~ "← Idle"
      assert html =~ "Gate at output -11 →"
      refute html =~ ">MIN<"
      refute html =~ ">MAX<"
    end

    test "forward lever shows physical strip without reversed badge" do
      html = render_step(mapping_state(preview: forward_preview()))

      assert html =~ "Your lever"
      assert html =~ "Low end (0%)"
      assert html =~ "High end (100%)"
      assert html =~ "Same direction as simulator"
      refute html =~ "Reversed vs. simulator"
      refute html =~ "Direction is detected after you capture a second notch"
    end

    test "inverted lever shows reversed badge" do
      html = render_step(mapping_state(preview: inverted_preview()))

      assert html =~ "Reversed vs. simulator"
      refute html =~ "Same direction as simulator"
    end

    test "partial capture without known direction shows the hint" do
      preview = %{
        status: :partial,
        direction_known: false,
        inverted: false,
        low_end: nil,
        high_end: nil,
        live: nil,
        hardware_ranges: [range(0, 0.0, 5.0, 0.0, 0.0)]
      }

      html = render_step(mapping_state(preview: preview))

      assert html =~ "Your lever"
      assert html =~ "Direction is detected after you capture a second notch"
      refute html =~ "Reversed vs. simulator"
      refute html =~ ", sim "
    end

    test "missing preview renders the step without the physical strip" do
      html = render_step(mapping_state([]))

      assert html =~ "Notch 2 of 3: Linear 0.0 to 100.0"
      assert html =~ "Simulator notches (in simulator order)"
      refute html =~ "Your lever"
      refute html =~ "Direction is detected"
    end

    test "nil preview renders the step without the physical strip" do
      html = render_step(mapping_state(preview: nil))

      refute html =~ "Your lever"
    end

    test "review state summarises ends for a forward lever" do
      html = render_step(review_state(forward_preview()))

      assert html =~
               "Low end of your lever → Idle (sim 0.00). High end → Gate at output -11 (sim 1.00)."

      refute html =~ "runs opposite to the simulator"
      refute html =~ "All Notches Mapped!"
      assert html =~ "Lever now →"
      assert html =~ ~s(phx-click="save_and_finish")
      assert html =~ "Save Mapping"
    end

    test "review state for an inverted lever lists ranges in physical order" do
      html = render_step(review_state(inverted_preview()))

      assert html =~
               "Low end of your lever → Gate at output -11 (sim 1.00). High end → Idle (sim 0.00)."

      assert html =~
               "Your lever runs opposite to the simulator — that's fine, it's handled automatically."

      assert html =~ "Lever range"
      assert html =~ "Sends to sim"
      assert html =~ "0–5%"
      assert html =~ "10–90%"
      assert html =~ "0.90 → 0.10"
      assert html =~ "0 → 100"
      assert html =~ "Linear 0.0 to 100.0</span>, sim 0.64"

      rows =
        html
        |> LazyHTML.from_fragment()
        |> LazyHTML.query("tr[data-notch-index]")
        |> LazyHTML.attribute("data-notch-index")

      assert rows == ["2", "1", "0"]
    end

    test "review state without live notch says the lever is between notches" do
      html = render_step(review_state(%{forward_preview() | live: nil}))

      assert html =~ "64% (not in a captured notch)"
    end
  end
end
