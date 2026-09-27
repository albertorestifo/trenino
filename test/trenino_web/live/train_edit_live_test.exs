defmodule TreninoWeb.TrainEditLiveTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Trenino.Hardware
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.Train

  # Sample state that NotchMappingSession broadcasts with events
  @sample_notch_mapping_state %{
    lever_config_id: 1,
    notch_count: 3,
    notches: [
      %{id: 1, index: 0, type: :gate, description: "Notch 0"},
      %{id: 2, index: 1, type: :linear, description: "Notch 1"},
      %{id: 3, index: 2, type: :gate, description: "Notch 2"}
    ],
    total_travel: 800,
    current_step: {:mapping_notch, 0},
    current_notch_index: 0,
    current_notch: %{id: 1, index: 0, type: :gate, description: "Notch 0"},
    is_capturing: false,
    captured_ranges: [nil, nil, nil],
    current_value: 400,
    current_min: nil,
    current_max: nil,
    sample_count: 0,
    can_capture: false,
    all_captured: false,
    result: nil,
    # Legacy fields
    boundary_count: 4,
    current_boundary_index: 0,
    captured_boundaries: [nil, nil, nil],
    notch_descriptions: ["Notch 0", "Notch 1", "Notch 2"],
    is_stable: false
  }

  # All events broadcast by NotchMappingSession that TrainEditLive must handle.
  # When adding new events to NotchMappingSession, add them here AND add a test below.
  @notch_mapping_events [
    :session_started,
    :step_changed,
    :sample_updated,
    :capture_started,
    :capture_stopped,
    {:mapping_result, :ok},
    {:mapping_result, :error},
    :notch_mapping_cancelled
  ]

  describe "notch mapping event handlers" do
    # These tests verify that TrainEditLive has handlers for ALL events
    # broadcast by NotchMappingSession. This prevents crashes when new
    # events are added to the session without updating the LiveView.
    #
    # IMPORTANT: When adding a new event to NotchMappingSession:
    # 1. Add it to @notch_mapping_events above
    # 2. Add a test case below
    # 3. Add a handle_info clause in TrainEditLive

    setup %{conn: conn} do
      # Create a train so we can navigate to the edit page
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Test Train",
          identifiers: [
            %{identifier: "Test_Train_#{System.unique_integer([:positive])}"}
          ]
        })

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")
      %{view: view, train: train}
    end

    test "handles :session_started event", %{view: view} do
      send(view.pid, {:session_started, @sample_notch_mapping_state})
      # Should not crash - verify the view is still alive
      assert render(view) =~ "Test Train"
    end

    test "handles :step_changed event", %{view: view} do
      send(view.pid, {:step_changed, @sample_notch_mapping_state})
      assert render(view) =~ "Test Train"
    end

    test "handles :sample_updated event", %{view: view} do
      send(view.pid, {:sample_updated, @sample_notch_mapping_state})
      assert render(view) =~ "Test Train"
    end

    test "handles :capture_started event", %{view: view} do
      state = %{@sample_notch_mapping_state | is_capturing: true}
      send(view.pid, {:capture_started, state})
      assert render(view) =~ "Test Train"
    end

    test "handles :capture_stopped event", %{view: view} do
      send(view.pid, {:capture_stopped, @sample_notch_mapping_state})
      assert render(view) =~ "Test Train"
    end

    test "handles :mapping_result success event", %{view: view} do
      send(view.pid, {:mapping_result, {:ok, %{id: 1}}})
      assert render(view) =~ "Test Train"
    end

    test "handles :mapping_result error event", %{view: view} do
      send(view.pid, {:mapping_result, {:error, :some_error}})
      assert render(view) =~ "Test Train"
    end

    test "handles :notch_mapping_cancelled event", %{view: view} do
      send(view.pid, :notch_mapping_cancelled)
      assert render(view) =~ "Test Train"
    end

    test "all documented events have test coverage" do
      # This test ensures we don't forget to add tests when new events are added.
      # The number of event tests should match the number of documented events.
      #
      # If this test fails, you need to:
      # 1. Add a test for the new event above
      # 2. Update the count below
      expected_event_count = length(@notch_mapping_events)
      # Count: session_started, step_changed, sample_updated, capture_started,
      #        capture_stopped, mapping_result (ok), mapping_result (error), cancelled
      actual_test_count = 8

      assert actual_test_count == expected_event_count,
             "Expected #{expected_event_count} event tests but have #{actual_test_count}. " <>
               "Add a test for any new events in @notch_mapping_events."
    end
  end

  describe "new train form" do
    test "pre-fills identifier from query params when configuring detected train", %{conn: conn} do
      # When a train is detected but not configured, the user clicks "Configure"
      # which navigates to /trains/new?identifier=BR_Class_66
      # The identifier should be pre-filled in the form
      {:ok, _view, html} = live(conn, ~p"/trains/new?identifier=BR_Class_66")

      assert html =~ ~s(name="train[identifiers][0][identifier]")
      assert html =~ ~s(value="BR_Class_66")
    end

    test "renders empty identifier when no connect params provided", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/trains/new")

      # The identifier field should be empty when no identifier is passed
      assert html =~ "Train Identifiers"
      assert html =~ ~s(placeholder="e.g., BR_Class_66")
      assert html =~ ~s(name="train[identifiers][0][identifier]")
    end

    test "saves train with pre-filled identifier from query params", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/trains/new?identifier=BR_Class_66")

      # Fill in the name and submit the form
      view
      |> form("form[phx-submit='save_train']",
        train: %{name: "Class 66", description: "British freight locomotive"}
      )
      |> render_submit()

      [train] = TrainContext.list_trains(preload: :identifiers)
      assert Train.identifier_values(train) == ["BR_Class_66"]
      assert train.name == "Class 66"
      assert train.description == "British freight locomotive"
    end

    test "creates a train with two equivalent identifiers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/trains/new")

      render_submit(view, "save_train", %{
        "train" => %{
          name: "BR 423",
          identifiers: %{
            "0" => %{identifier: "RVM_OTHER_DB_BR423"},
            "1" => %{identifier: "RVM_FSN_DB_BR423"}
          },
          identifiers_sort: ["0", "1"]
        }
      })

      [train] = TrainContext.list_trains(preload: :identifiers)

      assert Train.identifier_values(train) == [
               "RVM_FSN_DB_BR423",
               "RVM_OTHER_DB_BR423"
             ]
    end

    test "cannot save a train without any identifiers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/trains/new")

      html =
        render_submit(view, "save_train", %{
          "train" => %{name: "No aliases", identifiers_drop: ["0"]}
        })

      assert html =~ "must have at least one identifier"
      assert TrainContext.list_trains() == []
    end

    test "renders a conflicting identifier error", %{conn: conn} do
      {:ok, _train} =
        TrainContext.create_train(%{
          name: "Existing",
          identifiers: [%{identifier: "RVM_SHARED"}]
        })

      {:ok, view, _html} = live(conn, ~p"/trains/new")

      html =
        view
        |> form("#train-form",
          train: %{
            name: "Conflict",
            identifiers: %{"0" => %{identifier: "RVM_SHARED"}},
            identifiers_sort: ["0"]
          }
        )
        |> render_submit()

      assert html =~ "has already been taken"
    end

    test "removes one identifier while keeping another", %{conn: conn} do
      {:ok, train} =
        TrainContext.create_train(%{
          name: "BR 423",
          identifiers: [
            %{identifier: "RVM_FSN_DB_BR423"},
            %{identifier: "RVM_OTHER_DB_BR423"}
          ]
        })

      train = Trenino.Repo.preload(train, :identifiers, force: true)
      [first, second] = train.identifiers
      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      render_submit(view, "save_train", %{
        "train" => %{
          "name" => "BR 423",
          "identifiers" => %{
            "0" => %{
              "_persistent_id" => "0",
              "id" => Integer.to_string(first.id),
              "identifier" => first.identifier
            },
            "1" => %{
              "_persistent_id" => "1",
              "id" => Integer.to_string(second.id),
              "identifier" => second.identifier
            }
          },
          "identifiers_sort" => ["0", "1"],
          "identifiers_drop" => ["0"]
        }
      })

      {:ok, train} = TrainContext.get_train(train.id, preload: :identifiers)
      assert Train.identifier_values(train) == [second.identifier]
    end

    test "does not remove the last persisted identifier", %{conn: conn} do
      {:ok, train} =
        TrainContext.create_train(%{
          name: "BR 423",
          identifiers: [%{identifier: "RVM_FSN_DB_BR423"}]
        })

      train = Trenino.Repo.preload(train, :identifiers, force: true)
      [identifier] = train.identifiers
      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      html =
        render_submit(view, "save_train", %{
          "train" => %{
            "name" => "BR 423",
            "identifiers" => %{
              "0" => %{
                "_persistent_id" => "0",
                "id" => Integer.to_string(identifier.id),
                "identifier" => identifier.identifier
              }
            },
            "identifiers_sort" => ["0"],
            "identifiers_drop" => ["0"]
          }
        })

      assert html =~ "must have at least one identifier"
      {:ok, reloaded} = TrainContext.get_train(train.id, preload: [:identifiers])
      assert Train.identifier_values(reloaded) == ["RVM_FSN_DB_BR423"]
    end
  end

  describe "button elements" do
    setup %{conn: conn} do
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Test Train",
          identifiers: [
            %{identifier: "Test_Train_Button_#{System.unique_integer([:positive])}"}
          ]
        })

      %{conn: conn, train: train}
    end

    test "can add a button element", %{conn: conn, train: train} do
      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      # Open the add element modal
      view |> element("button", "Add Element") |> render_click()

      # Submit the form with button type
      view
      |> form("form[phx-submit='add_element']", element: %{name: "Horn", type: "button"})
      |> render_submit()

      # Verify the element was created
      {:ok, elements} = TrainContext.list_elements(train.id)
      assert length(elements) == 1
      assert hd(elements).name == "Horn"
      assert hd(elements).type == :button
    end

    test "displays button element card with correct badge", %{conn: conn, train: train} do
      # Create a button element directly
      {:ok, _element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})

      # Load the view after element is created
      {:ok, _view, html} = live(conn, ~p"/trains/#{train.id}")

      assert html =~ "Horn"
      assert html =~ "button"
    end

    test "can delete a button element", %{conn: conn, train: train} do
      # Create a button element directly
      {:ok, elem} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})

      # Load the view
      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      # Delete it
      view
      |> element("[phx-click='delete_element'][phx-value-id='#{elem.id}']")
      |> render_click()

      # Verify the element was deleted
      {:ok, elements} = TrainContext.list_elements(train.id)
      assert elements == []
    end

    # Note: Button configuration modal tests removed - configuration now requires
    # simulator connection and uses the ConfigurationWizard. See
    # configuration_wizard_component_test.exs for wizard tests.

    test "shows configuration progress on button element card after binding", %{
      conn: conn,
      train: train
    } do
      # Create a device with button input
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      # Create a button element
      {:ok, elem} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})

      # Create binding
      {:ok, _binding} =
        TrainContext.create_button_binding(elem.id, input.id, %{
          endpoint: "CurrentDrivableActor/Horn.InputValue"
        })

      # Load the view to see the binding
      {:ok, _view, html} = live(conn, ~p"/trains/#{train.id}")

      # Should show element name and Configure button
      assert html =~ "Horn"
      assert html =~ "Configure"
    end
  end

  describe "map notches button" do
    setup %{conn: conn} do
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Test Train",
          identifiers: [
            %{identifier: "Test_Train_Notches_#{System.unique_integer([:positive])}"}
          ]
        })

      # Create lever element
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      # Create lever config with endpoints
      {:ok, lever_config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "CurrentDrivableActor/Throttle.Function.GetMinimumInputValue",
          max_endpoint: "CurrentDrivableActor/Throttle.Function.GetMaximumInputValue",
          value_endpoint: "CurrentDrivableActor/Throttle.InputValue"
        })

      # Create a device with analog input and calibration
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 0, input_type: :analog, sensitivity: 5})

      {:ok, _calibration} =
        Hardware.save_calibration(input.id, %{
          min_value: 0,
          max_value: 1023,
          max_hardware_value: 1023,
          center_value: 512,
          deadzone: 10
        })

      # Bind the input to the lever config
      {:ok, _binding} = TrainContext.bind_input(lever_config.id, input.id)

      %{conn: conn, train: train, element: element, lever_config: lever_config}
    end

    test "shows configure button for lever elements", %{
      conn: conn,
      train: train,
      element: element
    } do
      {:ok, _view, html} = live(conn, ~p"/trains/#{train.id}")

      # Should have a configure_lever button
      assert html =~ "phx-click=\"configure_lever\""
      assert html =~ "phx-value-id=\"#{element.id}\""
      # Button always shows "Configure"
      assert html =~ "Configure"
    end
  end

  # Note: "button element with custom on/off values" tests removed - configuration
  # now requires simulator connection and uses the ConfigurationWizard.
  # See configuration_wizard_component_test.exs for wizard tests.
end
