defmodule TreninoWeb.SelectorSetupTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Serial.Connection.DeviceConnection
  alias Trenino.Train, as: TrainContext
  alias Trenino.VirtualJoystick

  @lights_endpoint "CurrentDrivableActor/Headlights.InputValue"

  setup :set_mimic_global

  setup do
    {:ok, train} =
      TrainContext.create_train(%{
        name: "Class 66",
        identifiers: [%{identifier: "Selector_#{System.unique_integer([:positive])}"}]
      })

    {:ok, device} = Hardware.create_device(%{name: "Desk panel"})

    {:ok, input} =
      Hardware.create_input(device.id, %{
        pin: 3,
        input_type: :analog,
        sensitivity: 5,
        name: "Lights knob"
      })

    {:ok, _} =
      Hardware.save_calibration(input.id, %{
        min_value: 0,
        max_value: 1000,
        max_hardware_value: 1023
      })

    {:ok, uncalibrated} =
      Hardware.create_input(device.id, %{
        pin: 4,
        input_type: :analog,
        sensitivity: 5,
        name: "Raw pot"
      })

    port = "/dev/cu.selector-test"

    Mimic.stub(Trenino.Serial.Connection, :connected_devices, fn ->
      [%DeviceConnection{port: port, status: :connected, device_config_id: device.config_id}]
    end)

    Mimic.stub(ConfigurationManager, :get_input_values, fn ^port -> %{} end)

    %{train: train, input: input, uncalibrated: uncalibrated, port: port}
  end

  defp create_selector(train) do
    {:ok, element} = TrainContext.create_element(train.id, %{name: "Lights", type: :selector})
    element
  end

  defp open_wizard(conn, train, element) do
    {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

    view
    |> element("button[phx-click='configure_selector'][phx-value-id='#{element.id}']")
    |> render_click()

    view
  end

  defp pick_input(view, input) do
    view |> element("#selector-input-#{input.id}") |> render_click()
    settle(view)
  end

  # Readings reach the wizard through the page, once it watches the input.
  defp read(view, ctx, raw) do
    send(view.pid, {:input_value_updated, ctx.port, ctx.input.pin, raw})
    settle(view)
  end

  # The page forwards messages to the wizard with send_update, which queues
  # another message. The first render waits for the page to handle the
  # message; the second for the wizard update it queued.
  defp settle(view) do
    render(view)
    render(view)
  end

  defp set_enter_value(view, index, value) do
    view
    |> element("#selector-actions-form")
    |> render_change(%{
      "positions" => %{
        to_string(index) => %{
          "enter" => %{"kind" => "set_value", "endpoint" => @lights_endpoint, "value" => value}
        }
      }
    })
  end

  describe "adding a selector" do
    test "the add element modal offers selectors and opens their setup offline",
         %{conn: conn, train: train} do
      {:ok, view, _html} = live(conn, ~p"/trains/#{train.id}")

      view |> element("#add-element") |> render_click()
      assert has_element?(view, "#add-element-form option[value='selector']")

      view
      |> form("#add-element-form", element: %{name: "Lights", type: "selector"})
      |> render_submit()

      assert has_element?(view, "#selector-wizard-dialog[role='dialog']")
      assert render(view) =~ "Configure Lights"
    end
  end

  describe "choosing the input" do
    test "lists analog inputs and disables uncalibrated ones", ctx do
      view = open_wizard(ctx.conn, ctx.train, create_selector(ctx.train))

      assert has_element?(view, "#selector-input-#{ctx.input.id}:not([disabled])")
      assert has_element?(view, "#selector-input-#{ctx.uncalibrated.id}[disabled]")
      assert render(view) =~ "Calibrate this input on its hardware page first."
    end
  end

  describe "inputs shared with a lever" do
    test "warns when the input already drives a lever on the train", ctx do
      {:ok, lever} = TrainContext.create_element(ctx.train.id, %{name: "Throttle", type: :lever})

      {:ok, config} =
        TrainContext.create_lever_config(lever.id, %{
          min_endpoint: "T.Min",
          max_endpoint: "T.Max",
          value_endpoint: "T.InputValue"
        })

      {:ok, _} = TrainContext.bind_input(config.id, ctx.input.id)

      view = open_wizard(ctx.conn, ctx.train, create_selector(ctx.train))

      assert has_element?(view, "#selector-input-#{ctx.input.id}-lever")
      refute has_element?(view, "#selector-input-#{ctx.uncalibrated.id}-lever")
    end
  end

  describe "the simulator connection" do
    test "hides simulator browsing while disconnected", ctx do
      view = open_wizard(ctx.conn, ctx.train, create_selector(ctx.train))
      pick_input(view, ctx.input)
      view |> element("#selector-next") |> render_click()

      view
      |> element("#selector-actions-form")
      |> render_change(%{"positions" => %{"0" => %{"enter" => %{"kind" => "set_value"}}}})

      refute render(view) =~ "Browse simulator API"
    end
  end

  describe "positions" do
    setup ctx do
      view = open_wizard(ctx.conn, ctx.train, create_selector(ctx.train))
      pick_input(view, ctx.input)
      %{view: view}
    end

    test "starts with three evenly split positions", %{view: view} do
      assert has_element?(view, "#selector-position-2")
      refute has_element?(view, "#selector-position-3")
      assert has_element?(view, "#selector-position-1-min[value='0.37']")
    end

    test "changes the number of positions", %{view: view} do
      view |> element("#selector-count-form") |> render_change(%{"count" => "5"})

      assert has_element?(view, "#selector-position-4")
      assert has_element?(view, "#selector-position-4-max[value='1.00']")
    end

    test "shows the live reading and the position it is in", %{view: view} = ctx do
      assert render(view) =~ "Move the knob to see its reading."

      html = read(view, ctx, 500)
      assert html =~ "0.50"
      assert html =~ "in Position 2"
      assert has_element?(view, "#selector-position-1.bg-primary\\/10")

      assert read(view, ctx, 340) =~ "in a dead zone"
    end

    test "uses the cached reading when the input is picked", ctx do
      port = ctx.port
      pin = ctx.input.pin
      Mimic.stub(ConfigurationManager, :get_input_values, fn ^port -> %{pin => 800} end)

      view = open_wizard(ctx.conn, ctx.train, create_selector(ctx.train))
      pick_input(view, ctx.input)

      assert render(view) =~ "in Position 3"
    end

    test "builds ranges from captured detents", %{view: view} = ctx do
      refute has_element?(view, "#selector-capture-0:not([disabled])")

      for {raw, index} <- [{100, 0}, {500, 1}, {900, 2}] do
        read(view, ctx, raw)
        view |> element("#selector-capture-#{index}") |> render_click()
      end

      assert has_element?(view, "#selector-position-0-max[value='0.26']")
      assert has_element?(view, "#selector-position-1-min[value='0.34']")
      assert has_element?(view, "#selector-position-2-min[value='0.74']")
    end

    test "rejects detents that are too close", %{view: view} = ctx do
      for {raw, index} <- [{100, 0}, {120, 1}, {900, 2}] do
        read(view, ctx, raw)
        view |> element("#selector-capture-#{index}") |> render_click()
      end

      assert render(view) =~ "Two detents are too close together"
    end

    test "says when the device is not connected", ctx do
      Mimic.stub(Trenino.Serial.Connection, :connected_devices, fn -> [] end)

      view = open_wizard(ctx.conn, ctx.train, create_selector(ctx.train))
      pick_input(view, ctx.input)

      assert render(view) =~ "The device is not connected."
    end

    test "edits labels and ranges", %{view: view} do
      view
      |> element("#selector-positions-form")
      |> render_change(%{
        "positions" => %{"0" => %{"label" => "Off", "input_min" => "0.00", "input_max" => "0.20"}}
      })

      assert has_element?(view, "#selector-position-0-label[value='Off']")
      assert has_element?(view, "#selector-position-0-max[value='0.20']")

      view |> element("#selector-even-split") |> render_click()
      assert has_element?(view, "#selector-position-0-max[value='0.30']")
      assert has_element?(view, "#selector-position-0-label[value='Off']")
    end
  end

  describe "actions and saving" do
    setup ctx do
      element = create_selector(ctx.train)
      view = open_wizard(ctx.conn, ctx.train, element)
      pick_input(view, ctx.input)

      view
      |> element("#selector-positions-form")
      |> render_change(%{
        "positions" => %{"0" => %{"label" => "Off"}, "2" => %{"label" => "Full"}}
      })

      view |> element("#selector-next") |> render_click()
      %{view: view, element: element}
    end

    test "saves the selector and shows it as ready", %{view: view, element: element} do
      set_enter_value(view, 0, "0")
      set_enter_value(view, 2, "1")

      view
      |> element("#selector-actions-form")
      |> render_change(%{
        "positions" => %{"1" => %{"exit" => %{"kind" => "keystroke", "keystroke" => "L"}}}
      })

      view |> element("#selector-save") |> render_click()

      refute has_element?(view, "#selector-wizard-dialog")
      assert render(view) =~ "Selector saved"
      assert render(view) =~ "Ready"

      assert {:ok, binding} = TrainContext.get_selector_binding(element.id)

      assert [
               %{label: "Off", enter_kind: :set_value, enter_endpoint: @lights_endpoint},
               %{label: nil, enter_kind: :none, exit_kind: :keystroke, exit_keystroke: "L"},
               %{label: "Full", enter_value: 1.0}
             ] = binding.positions
    end

    test "shows validation errors per position", %{view: view} do
      view
      |> element("#selector-actions-form")
      |> render_change(%{"positions" => %{"1" => %{"enter" => %{"kind" => "set_value"}}}})

      view |> element("#selector-save") |> render_click()

      html = render(view)
      assert has_element?(view, "#selector-wizard-error")
      assert html =~ "Position 2: enter endpoint can&#39;t be blank"
    end

    test "fills an endpoint picked in the API explorer", %{view: view} do
      view
      |> element("#selector-actions-form")
      |> render_change(%{"positions" => %{"0" => %{"enter" => %{"kind" => "set_value"}}}})

      send(view.pid, {:api_explorer_select, "selector:0:enter", "Lights.InputValue"})
      settle(view)

      assert has_element?(view, "#selector-0-enter-endpoint[value='Lights.InputValue']")
    end

    test "offers the train's sequences", %{view: view, train: train} do
      {:ok, _} = TrainContext.create_sequence(train.id, %{name: "Lights on"})

      # Re-open to load the new sequence
      view
      |> element("button[phx-click='cancel'][aria-label='Close selector setup']")
      |> render_click()

      element = TrainContext.list_elements(train.id) |> elem(1) |> hd()

      view
      |> element("button[phx-click='configure_selector'][phx-value-id='#{element.id}']")
      |> render_click()

      view |> element("#selector-input-#{hd(Hardware.list_all_inputs()).id}") |> render_click()
      view |> element("#selector-next") |> render_click()

      view
      |> element("#selector-actions-form")
      |> render_change(%{"positions" => %{"0" => %{"enter" => %{"kind" => "sequence"}}}})

      assert render(view) =~ "Lights on"
    end

    test "replaces a virtual joystick mapping on request", %{view: view, input: input} do
      {:ok, _} = VirtualJoystick.put_mapping(input.id, %{target_type: :axis, axis: :slider_1})

      view |> element("#selector-save") |> render_click()
      assert render(view) =~ "mapped to the virtual joystick"

      view |> element("#selector-replace-mapping") |> render_click()

      assert render(view) =~ "Selector saved"
      assert VirtualJoystick.list_mappings() == []
    end

    test "cancel closes without saving", %{view: view, element: element} do
      view |> element("button[aria-label='Close selector setup']") |> render_click()

      refute has_element?(view, "#selector-wizard-dialog")
      assert {:error, :not_found} = TrainContext.get_selector_binding(element.id)
    end
  end

  describe "editing and live position" do
    setup ctx do
      element = create_selector(ctx.train)

      positions = [
        %{index: 0, label: "Off", input_min: 0.0, input_max: 0.4, enter_kind: :none},
        %{index: 1, label: "On", input_min: 0.6, input_max: 1.0, enter_kind: :none}
      ]

      {:ok, _} =
        TrainContext.save_selector(element.id, %{input_id: ctx.input.id, positions: positions})

      %{element: element}
    end

    test "opens an existing selector at its positions", ctx do
      view = open_wizard(ctx.conn, ctx.train, ctx.element)

      assert has_element?(view, "#selector-position-0-label[value='Off']")
      assert has_element?(view, "#selector-position-1-min[value='0.60']")
      refute has_element?(view, "#selector-position-2")
    end

    test "shows the selector's live position in the elements table", ctx do
      {:ok, view, _html} = live(ctx.conn, ~p"/trains/#{ctx.train.id}")
      element_id = ctx.element.id

      send(view.pid, {:selector_position_changed, element_id, %{index: 1, label: "On"}})
      assert view |> element("#selector-position-#{element_id}") |> render() =~ "At On"

      send(view.pid, {:selector_position_changed, element_id, %{index: 0, label: nil}})
      assert view |> element("#selector-position-#{element_id}") |> render() =~ "At position 1"

      send(view.pid, {:selector_position_changed, element_id, nil})
      refute has_element?(view, "#selector-position-#{element_id}")
    end
  end
end
