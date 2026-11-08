defmodule TreninoWeb.TrainEditLiveTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Trenino.Hardware
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.Detection
  alias Trenino.Train.LeverSetup
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

  describe "section nav and groups" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Panel"})
      gauge = Trenino.GaugeFixtures.gauge_fixture(device.id, %{name: "Speed"})

      {:ok, train} =
        TrainContext.create_train(%{name: "Class 323", identifiers: [%{identifier: "Class323"}]})

      {:ok, binding} =
        TrainContext.create_gauge_binding(train.id, %{
          name: "Speedometer",
          gauge_id: gauge.id,
          endpoint: "VerifiedSpeed",
          input_unit: :mps
        })

      %{train: train, binding: binding}
    end

    test "groups have muted h2 headings and the nav links to each section with its count", %{
      conn: conn,
      train: train,
      binding: binding
    } do
      {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")

      assert has_element?(view, "nav#section-nav[aria-label='Train configuration sections']")

      for {id, label} <- [
            {"controls", "Controls"},
            {"displays-lights", "Displays & lights"},
            {"automation", "Automation"}
          ] do
        assert has_element?(
                 view,
                 "div##{id}[data-section-group] > " <>
                   "h2##{id}-title.uppercase.tracking-wide.text-muted",
                 label
               )
      end

      for {id, label} <- [
            {"elements", "Elements"},
            {"gauge-bindings", "Gauge bindings"},
            {"display-bindings", "Display bindings"},
            {"output-bindings", "Output bindings"},
            {"sequences", "Sequences"},
            {"scripts", "Scripts"}
          ] do
        assert has_element?(view, "#section-nav a[href='##{id}']", label)
      end

      assert has_element?(view, "div#controls section#elements[data-section-card]")
      assert has_element?(view, "div#displays-lights section#gauge-bindings")
      assert has_element?(view, "div#automation section#sequences")
      refute has_element?(view, "#section-nav a[href='#elements'] .badge")
      assert has_element?(view, "#section-nav a[href='#gauge-bindings'] .badge", "1")
      assert has_element?(view, "#gauge-bindings-title + .badge", "1")

      view |> element("#gauge-delete-#{binding.id}") |> render_click()

      assert TrainContext.list_gauge_bindings(train.id) == []
      refute has_element?(view, "#section-nav a[href='#gauge-bindings'] .badge")
    end

    test "the gauge bindings nav count follows a saved binding", %{conn: conn, train: train} do
      {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")
      assert has_element?(view, "#section-nav a[href='#gauge-bindings'] .badge", "1")

      # A train binds each gauge once, so the second binding needs its own gauge.
      {:ok, device} = Hardware.create_device(%{name: "Second panel"})
      gauge = Trenino.GaugeFixtures.gauge_fixture(device.id, %{name: "Brake"})

      {:ok, second} =
        TrainContext.create_gauge_binding(train.id, %{
          name: "Brake gauge",
          gauge_id: gauge.id,
          endpoint: "VerifiedBrake",
          input_unit: :mps
        })

      send(view.pid, {:gauge_binding_saved, second})

      assert has_element?(view, "#section-nav a[href='#gauge-bindings'] .badge", "2")
    end

    test "the sequences nav count follows the sequence manager", %{conn: conn, train: train} do
      {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")
      refute has_element?(view, "#section-nav a[href='#sequences'] .badge")

      {:ok, _} = TrainContext.create_sequence(train.id, %{name: "Door open"})
      send(view.pid, {TreninoWeb.SequenceManagerComponent, :sequences_changed})

      assert has_element?(view, "#section-nav a[href='#sequences'] .badge", "1")
    end

    test "new train hides the nav and the groups", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/trains/new")

      refute has_element?(view, "#section-nav")
      refute has_element?(view, "#controls")
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
      assert html =~ "Train identifiers"
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

    test "re-detects the active train when identifiers change", %{conn: conn} do
      train = saved_train_with_cached_detection()
      [existing] = train.identifiers

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      render_submit(view, "save_train", %{
        "train" => %{
          identifiers: %{
            "0" => %{id: existing.id, identifier: existing.identifier},
            "1" => %{identifier: "RVM_NEW_CAB"}
          },
          identifiers_sort: ["0", "1"]
        }
      })

      assert Detection.get_current_identifier() == nil
    end

    test "keeps the cached detection when identifiers are unchanged", %{conn: conn} do
      train = saved_train_with_cached_detection()
      [existing] = train.identifiers

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      render_submit(view, "save_train", %{
        "train" => %{
          name: "Renamed",
          identifiers: %{"0" => %{id: existing.id, identifier: existing.identifier}},
          identifiers_sort: ["0"]
        }
      })

      assert Detection.get_current_identifier() == "RVM_CACHED_CAB"
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
      view |> element("#add-element", "Add element") |> render_click()

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

      # Delete asks for confirmation and names the element
      assert has_element?(
               view,
               "[phx-click='delete_element'][phx-value-id='#{elem.id}'][data-confirm='Delete Horn?'][aria-label='Delete Horn']"
             )

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
      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      # Lever rows keep Configure in the "..." menu
      button =
        element(view, "#element-actions-#{element.id}-menu #configure-element-#{element.id}")

      html = render(button)
      assert html =~ "configure_lever"
      assert html =~ ~s(phx-value-id="#{element.id}")
      assert html =~ "Configure"
    end
  end

  describe "notch disk link" do
    setup do
      {:ok, train} =
        TrainContext.create_train(%{
          name: "BR430",
          identifiers: [%{identifier: "Test_Train_Disk_#{System.unique_integer([:positive])}"}]
        })

      {:ok, element} = TrainContext.create_element(train.id, %{name: "Master", type: :lever})

      {:ok, lever_config} =
        TrainContext.create_lever_config(
          element.id,
          LeverSetup.endpoints_for("CurrentDrivableActor/MasterController")
        )

      %{train: train, element: element, lever_config: lever_config}
    end

    test "a calibrated lever links to the generator with its notches", %{
      conn: conn,
      train: train,
      element: element,
      lever_config: lever_config
    } do
      notches = [
        %{
          type: :gate,
          value: -11.0,
          sim_input_min: 0.0,
          sim_input_max: 0.0,
          description: "Emergency"
        },
        %{
          type: :linear,
          min_value: -10.0,
          max_value: -0.91,
          sim_input_min: 0.1,
          sim_input_max: 0.41,
          description: "Brake"
        },
        %{type: :gate, value: 0.0, sim_input_min: 0.5, sim_input_max: 0.5, description: "Off"},
        %{
          type: :linear,
          min_value: 1.0,
          max_value: 10.0,
          sim_input_min: 0.59,
          sim_input_max: 1.0,
          description: "Power"
        }
      ]

      notches
      |> Enum.with_index()
      |> Enum.each(fn {attrs, index} ->
        {:ok, _} = TrainContext.create_notch(lever_config.id, Map.put(attrs, :index, index))
      end)

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      # Lives in the row's "..." menu, not inline next to Configure
      assert has_element?(view, "#element-actions-#{element.id}-menu #notch-disk-#{element.id}")

      link = element(view, "#notch-disk-#{element.id}")
      assert render(link) =~ ~s(target="_blank")
      assert render(link) =~ "(opens in new tab)"
      [href] = link |> render() |> LazyHTML.from_fragment() |> LazyHTML.attribute("href")

      assert "https://albertorestifo.github.io/train-lever-generator/?" <> query = href
      params = URI.decode_query(query)
      # Emergency, the Brake guard, Off centred at position 4 of 7, Power end stop
      assert params["positions"] == "7"
      assert params["deep"] == "1,4"
      assert params["smooth"] == "3,5,6"
      assert params["name"] == "BR430 Master"
    end

    test "an uncalibrated lever has no notch disk action", %{
      conn: conn,
      train: train,
      element: element
    } do
      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")
      refute has_element?(view, "#notch-disk-#{element.id}")
    end

    test "a lever with too many notches shows the action disabled with the reason", %{
      conn: conn,
      train: train,
      element: element,
      lever_config: lever_config
    } do
      for i <- 0..13 do
        {:ok, _} =
          TrainContext.create_notch(lever_config.id, %{
            index: i,
            type: :gate,
            value: i * 1.0,
            description: "N#{i}"
          })
      end

      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      assert has_element?(view, "button#notch-disk-#{element.id}[disabled]")
      assert render(element(view, "#notch-disk-#{element.id}")) =~ "more than 13 notches"
    end
  end

  describe "add actions" do
    setup do
      {:ok, train} =
        TrainContext.create_train(%{name: "Class 43", identifiers: [%{identifier: "Class43"}]})

      {:ok, script} =
        TrainContext.create_script(train.id, %{
          name: "Speed watcher",
          code: "function on_change(event) end"
        })

      %{train: train, script: script}
    end

    test "script add and edit are real links", %{conn: conn, train: train, script: script} do
      {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")

      assert has_element?(
               view,
               "a#add-script[href='/trains/#{train.id}/scripts/new'][data-phx-link='redirect']"
             )

      assert has_element?(
               view,
               "a#edit-script-#{script.id}[href='/trains/#{train.id}/scripts/#{script.id}']"
             )
    end

    test "add output binding is disabled with a visible reason while offline", %{
      conn: conn,
      train: train
    } do
      {:ok, view, _} = live(conn, ~p"/trains/#{train.id}")

      assert has_element?(
               view,
               "#add-output-binding[disabled][aria-describedby='output-prerequisites']"
             )

      assert has_element?(view, "#output-prerequisites", "Connect to the simulator")
      refute has_element?(view, "#add-output-binding-reason")
    end
  end

  # Note: "button element with custom on/off values" tests removed - configuration
  # now requires simulator connection and uses the ConfigurationWizard.
  # See configuration_wizard_component_test.exs for wizard tests.

  defp saved_train_with_cached_detection do
    {:ok, train} =
      TrainContext.create_train(%{
        name: "Cached",
        identifiers: [%{identifier: "RVM_EXISTING_CAB"}]
      })

    :sys.replace_state(Detection, &%{&1 | current_identifier: "RVM_CACHED_CAB"})
    on_exit(fn -> :sys.replace_state(Detection, &%{&1 | current_identifier: nil}) end)

    train
  end
end
