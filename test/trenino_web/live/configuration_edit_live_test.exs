defmodule TreninoWeb.ConfigurationEditLiveTest do
  use TreninoWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Trenino.Hardware
  alias Trenino.Hardware.Calibration.Session, as: CalibrationSession
  alias Trenino.Hardware.Input

  describe "mount/3 with invalid config_id" do
    test "redirects when configuration not found", %{conn: conn} do
      {:error, {:redirect, %{to: "/", flash: flash}}} =
        live(conn, "/configurations/999999999")

      assert flash["error"] ==
               "That configuration no longer exists. Pick another one from Devices."
    end

    test "redirects with invalid config_id format", %{conn: conn} do
      {:error, {:redirect, %{to: "/", flash: flash}}} =
        live(conn, "/configurations/invalid")

      assert flash["error"] ==
               "That configuration link is not valid. Pick a configuration from Devices."
    end
  end

  describe "Input changeset" do
    test "validates required fields" do
      changeset = Input.changeset(%Input{}, %{})

      refute changeset.valid?
      # input_type is always required
      assert %{input_type: ["can't be blank"]} = errors_on(changeset)
      # Note: pin is only required for analog/button types, not matrix
      # Note: sensitivity is only required when input_type is :analog
    end

    test "validates pin is required for analog type" do
      changeset = Input.changeset(%Input{}, %{input_type: :analog, device_id: 1})

      refute changeset.valid?
      assert %{pin: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates pin is required for button type" do
      changeset = Input.changeset(%Input{}, %{input_type: :button, device_id: 1})

      refute changeset.valid?
      assert %{pin: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates pin range for analog" do
      changeset =
        Input.changeset(%Input{}, %{pin: -1, input_type: :analog, sensitivity: 5, device_id: 1})

      refute changeset.valid?
      assert %{pin: ["must be between 0 and 127 for physical inputs"]} = errors_on(changeset)

      changeset =
        Input.changeset(%Input{}, %{pin: 128, input_type: :analog, sensitivity: 5, device_id: 1})

      refute changeset.valid?
      assert %{pin: ["must be between 0 and 127 for physical inputs"]} = errors_on(changeset)

      changeset =
        Input.changeset(%Input{}, %{pin: 0, input_type: :analog, sensitivity: 5, device_id: 1})

      assert changeset.valid?
    end

    test "validates sensitivity range" do
      changeset =
        Input.changeset(%Input{}, %{pin: 5, input_type: :analog, sensitivity: 0, device_id: 1})

      refute changeset.valid?
      assert %{sensitivity: ["must be greater than 0"]} = errors_on(changeset)

      changeset =
        Input.changeset(%Input{}, %{pin: 5, input_type: :analog, sensitivity: 11, device_id: 1})

      refute changeset.valid?
      assert %{sensitivity: ["must be less than or equal to 10"]} = errors_on(changeset)

      changeset =
        Input.changeset(%Input{}, %{pin: 5, input_type: :analog, sensitivity: 10, device_id: 1})

      assert changeset.valid?
    end
  end

  describe "Button input changeset" do
    test "validates debounce range for button" do
      # Valid debounce
      changeset =
        Input.changeset(%Input{}, %{pin: 5, input_type: :button, debounce: 20, device_id: 1})

      assert changeset.valid?

      # Debounce too low
      changeset =
        Input.changeset(%Input{}, %{pin: 5, input_type: :button, debounce: -1, device_id: 1})

      refute changeset.valid?
      assert %{debounce: ["must be greater than or equal to 0"]} = errors_on(changeset)

      # Debounce too high
      changeset =
        Input.changeset(%Input{}, %{pin: 5, input_type: :button, debounce: 256, device_id: 1})

      refute changeset.valid?
      assert %{debounce: ["must be less than or equal to 255"]} = errors_on(changeset)
    end

    test "validates pin range for button" do
      changeset =
        Input.changeset(%Input{}, %{pin: -1, input_type: :button, debounce: 20, device_id: 1})

      refute changeset.valid?
      assert %{pin: ["must be between 0 and 127 for physical inputs"]} = errors_on(changeset)

      changeset =
        Input.changeset(%Input{}, %{pin: 128, input_type: :button, debounce: 20, device_id: 1})

      refute changeset.valid?
      assert %{pin: ["must be between 0 and 127 for physical inputs"]} = errors_on(changeset)

      changeset =
        Input.changeset(%Input{}, %{pin: 100, input_type: :button, debounce: 20, device_id: 1})

      assert changeset.valid?
    end

    test "requires debounce for button input" do
      changeset =
        Input.changeset(%Input{}, %{pin: 5, input_type: :button, device_id: 1})

      refute changeset.valid?
      assert %{debounce: ["can't be blank"]} = errors_on(changeset)
    end

    test "does not require sensitivity for button input" do
      changeset =
        Input.changeset(%Input{}, %{pin: 5, input_type: :button, debounce: 20, device_id: 1})

      assert changeset.valid?
      # No sensitivity error for button type
      assert errors_on(changeset) == %{}
    end
  end

  describe "sections" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Section panel"})

      {:ok, input} =
        Hardware.create_input(device.id, %{
          pin: 5,
          name: "Throttle",
          input_type: :analog,
          sensitivity: 5
        })

      {:ok, matrix} =
        Hardware.create_matrix(device.id, %{name: "Panel keys", row_pins: [2, 3], col_pins: [4]})

      {:ok, output} = Hardware.create_output(device.id, %{pin: 13})

      %{device: device, input: input, matrix: matrix, output: output}
    end

    test "each section is a titled card with an add action", %{conn: conn, device: device} do
      {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")

      for {id, title, add} <- [
            {"inputs", "Inputs", "Add input"},
            {"matrices", "Matrices", "Add matrix"},
            {"outputs", "Outputs", "Add output"},
            {"displays", "Displays", "Add display"},
            {"gauges", "Gauges", "Add gauge"}
          ] do
        assert has_element?(view, "section##{id}[data-section-card] h3##{id}-title", title)
        assert has_element?(view, "section##{id} button", add)
      end

      assert has_element?(view, "#displays [data-section-empty]", "No displays configured")
      assert has_element?(view, "#gauges [data-section-empty]", "No gauges configured")
    end

    test "sections sit in Controls and Feedback groups behind a per-section counted nav", %{
      conn: conn,
      device: device,
      output: output
    } do
      {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")

      assert has_element?(view, "nav#section-nav[aria-label='Hardware configuration sections']")

      for {id, label} <- [
            {"inputs", "Inputs"},
            {"matrices", "Matrices"},
            {"outputs", "Outputs"},
            {"displays", "Displays"},
            {"gauges", "Gauges"}
          ] do
        assert has_element?(view, "#section-nav a[href='##{id}']", label)
      end

      # Each nav count is the count on its section: one input, one matrix, one output,
      # and no displays or gauges.
      for id <- ["inputs", "matrices", "outputs"] do
        assert has_element?(view, "#section-nav a[href='##{id}'] .badge", "1")
        assert has_element?(view, "##{id}-title + .badge", "1")
      end

      refute has_element?(view, "#section-nav a[href='#displays'] .badge")
      refute has_element?(view, "#section-nav a[href='#gauges'] .badge")

      for {group, title, sections} <- [
            {"controls-group", "Controls", ["inputs", "matrices"]},
            {"feedback-group", "Feedback", ["outputs", "displays", "gauges"]}
          ] do
        assert has_element?(
                 view,
                 "div##{group}[data-section-group] > " <>
                   "h2##{group}-title.uppercase.tracking-wide.text-muted",
                 title
               )

        for id <- sections do
          assert has_element?(view, "div##{group} section##{id}[data-section-card]")
        end
      end

      view
      |> element("#output-actions-#{output.id} button[phx-click='delete_output']")
      |> render_click()

      refute has_element?(view, "#section-nav a[href='#outputs'] .badge")
      assert has_element?(view, "#section-nav a[href='#inputs'] .badge", "1")
    end

    test "the page has one h1 above the group headings", %{conn: conn, device: device} do
      {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")

      assert has_element?(view, "h1", "Edit configuration")

      assert view |> render() |> LazyHTML.from_fragment() |> LazyHTML.query("h1") |> Enum.count() ==
               1
    end

    test "new configuration hides the anchor nav but keeps the groups", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/configurations/new")

      assert has_element?(view, "h1", "New configuration")
      refute has_element?(view, "#section-nav")
      assert has_element?(view, "div#controls-group h2", "Controls")
      assert has_element?(view, "div#feedback-group h2", "Feedback")
    end

    test "new configuration shows Displays and Gauges the same way", %{conn: conn} do
      {:ok, view, _} = live(conn, ~p"/configurations/new")

      for {section, button, reason} <- [
            {"displays", "add-display", "Name the configuration first to add a display."},
            {"gauges", "gauge-add", "Name the configuration first to add a gauge."}
          ] do
        assert has_element?(view, "div#feedback-group section##{section}[data-section-card]")

        assert has_element?(
                 view,
                 "##{section} button##{button}[disabled][aria-describedby='#{button}-reason']"
               )

        assert has_element?(view, "##{section} p##{button}-reason", reason)
      end
    end

    test "input, matrix and output deletes ask for confirmation", %{
      conn: conn,
      device: device,
      input: input,
      matrix: matrix,
      output: output
    } do
      {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")

      assert has_element?(
               view,
               "#input-actions-#{input.id} button[phx-click='delete_input']" <>
                 "[aria-label='Delete Throttle'][data-confirm='Delete Throttle?']"
             )

      assert has_element?(
               view,
               "#matrix-actions-#{matrix.id} button[phx-click='delete_matrix']" <>
                 "[aria-label='Delete Panel keys'][data-confirm^='Delete Panel keys?']"
             )

      assert has_element?(
               view,
               "#output-actions-#{output.id} button[phx-click='delete_output']" <>
                 "[aria-label='Delete output on pin 13'][data-confirm='Delete output on pin 13?']"
             )

      view
      |> element("#output-actions-#{output.id} button[phx-click='delete_output']")
      |> render_click()

      refute has_element?(view, "#output-actions-#{output.id}")
    end
  end

  describe "Hardware context integration" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      %{device: device}
    end

    test "creates inputs for device", %{device: device} do
      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

      assert input.device_id == device.id
      assert input.pin == 5
      assert input.input_type == :analog
      assert input.sensitivity == 5
    end

    test "creates button input for device", %{device: device} do
      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      assert input.device_id == device.id
      assert input.pin == 5
      assert input.input_type == :button
      assert input.debounce == 20
      assert input.sensitivity == nil
    end

    test "lists inputs ordered by pin", %{device: device} do
      {:ok, _} = Hardware.create_input(device.id, %{pin: 10, input_type: :analog, sensitivity: 5})
      {:ok, _} = Hardware.create_input(device.id, %{pin: 2, input_type: :analog, sensitivity: 5})
      {:ok, _} = Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

      {:ok, inputs} = Hardware.list_inputs(device.id)
      pins = Enum.map(inputs, & &1.pin)

      assert pins == [2, 5, 10]
    end

    test "lists both analog and button inputs ordered by pin", %{device: device} do
      {:ok, _} = Hardware.create_input(device.id, %{pin: 10, input_type: :analog, sensitivity: 5})
      {:ok, _} = Hardware.create_input(device.id, %{pin: 2, input_type: :button, debounce: 20})
      {:ok, _} = Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

      {:ok, inputs} = Hardware.list_inputs(device.id)
      pins = Enum.map(inputs, & &1.pin)

      assert pins == [2, 5, 10]
      assert Enum.map(inputs, & &1.input_type) == [:button, :analog, :analog]
    end

    test "deletes input", %{device: device} do
      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

      {:ok, _} = Hardware.delete_input(input.id)

      {:ok, inputs} = Hardware.list_inputs(device.id)
      assert inputs == []
    end

    test "enforces unique pin per device", %{device: device} do
      {:ok, _} = Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

      {:error, changeset} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

      assert %{device_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "enforces unique pin even across different input types", %{device: device} do
      {:ok, _} = Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

      {:error, changeset} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      assert %{device_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "PubSub event handling" do
    test "configuration_applied event updates device" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, updated_device} = Hardware.update_device(device, %{config_id: 12_345})

      # Verify the device was updated
      {:ok, found} = Hardware.get_device_by_config_id(12_345)
      assert found.id == updated_device.id
    end

    test "configuration failure reasons map to a plain next step" do
      alias TreninoWeb.ConfigurationEditLive

      assert ConfigurationEditLive.configuration_failure_message(:timeout) =~
               "Check the USB cable and reconnect"

      assert ConfigurationEditLive.configuration_failure_message(:device_rejected) =~
               "Update the firmware"

      assert ConfigurationEditLive.configuration_failure_message(:no_inputs) =~
               "Add at least one input, matrix, output"

      firmware = ConfigurationEditLive.configuration_failure_message(:firmware_update_required)
      assert firmware =~ "3.3.0 or newer for gauges"
      refute firmware =~ "Stepper"

      unknown = ConfigurationEditLive.configuration_failure_message({:unexpected, :term})
      assert unknown =~ "could not be applied"
      refute unknown =~ "unexpected"
    end

    test "input value updates" do
      input_values = %{}
      pin = 5
      value = 512

      new_values = Map.put(input_values, pin, value)

      assert new_values == %{5 => 512}
    end
  end

  describe "Calibration integration" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

      %{device: device, input: input}
    end

    test "save_calibration creates calibration for input", %{input: input} do
      attrs = %{
        min_value: 10,
        max_value: 150,
        max_hardware_value: 1023,
        is_inverted: false,
        has_rollover: false
      }

      {:ok, calibration} = Hardware.save_calibration(input.id, attrs)

      assert calibration.input_id == input.id
      assert calibration.min_value == 10
      assert calibration.max_value == 150
      assert calibration.is_inverted == false
      assert calibration.has_rollover == false
    end

    test "save_calibration updates existing calibration", %{input: input} do
      # Create initial calibration
      {:ok, _} =
        Hardware.save_calibration(input.id, %{
          min_value: 10,
          max_value: 150,
          max_hardware_value: 1023,
          is_inverted: false,
          has_rollover: false
        })

      # Update it
      {:ok, updated} =
        Hardware.save_calibration(input.id, %{
          min_value: 20,
          max_value: 200,
          max_hardware_value: 1023,
          is_inverted: true,
          has_rollover: false
        })

      assert updated.min_value == 20
      assert updated.max_value == 200
      assert updated.is_inverted == true
    end

    test "start_calibration_session creates supervised session", %{input: input} do
      {:ok, pid} = Hardware.start_calibration_session(input, "/dev/test")

      assert Process.alive?(pid)

      # Clean up
      CalibrationSession.cancel(pid)
    end

    test "get_input retrieves input with preloads", %{input: input} do
      {:ok, found} = Hardware.get_input(input.id)
      assert found.id == input.id
      assert found.pin == input.pin
    end

    test "get_input with calibration preload", %{input: input} do
      # Create calibration
      {:ok, _} =
        Hardware.save_calibration(input.id, %{
          min_value: 10,
          max_value: 150,
          max_hardware_value: 1023,
          is_inverted: false,
          has_rollover: false
        })

      {:ok, found} = Hardware.get_input(input.id, preload: [:calibration])
      assert found.calibration != nil
      assert found.calibration.min_value == 10
    end

    test "normalize_value delegates to Calculator" do
      calibration = %Trenino.Hardware.Input.Calibration{
        min_value: 10,
        max_value: 150,
        max_hardware_value: 1023,
        is_inverted: false,
        has_rollover: false
      }

      # Normalized values are integers from 0 to total_travel (140)
      assert Hardware.normalize_value(10, calibration) == 0
      assert Hardware.normalize_value(80, calibration) == 70
      assert Hardware.normalize_value(150, calibration) == 140
    end

    test "total_travel delegates to Calculator" do
      calibration = %Trenino.Hardware.Input.Calibration{
        min_value: 10,
        max_value: 150,
        max_hardware_value: 1023,
        is_inverted: false,
        has_rollover: false
      }

      assert Hardware.total_travel(calibration) == 140
    end
  end

  describe "Calibration event handlers" do
    test "calibration_result success updates inputs" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

      # Simulate what the handler does
      {:ok, _calibration} =
        Hardware.save_calibration(input.id, %{
          min_value: 10,
          max_value: 150,
          max_hardware_value: 1023,
          is_inverted: false,
          has_rollover: false
        })

      # Reload inputs
      {:ok, inputs} = Hardware.list_inputs(device.id)
      assert length(inputs) == 1
    end

    test "calibration session broadcasts events" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

      # Subscribe before starting session
      CalibrationSession.subscribe(input.id)

      {:ok, pid} = Hardware.start_calibration_session(input, "/dev/test")

      # Should receive session_started
      assert_receive {:session_started, state}
      assert state.input_id == input.id

      CalibrationSession.cancel(pid)
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
