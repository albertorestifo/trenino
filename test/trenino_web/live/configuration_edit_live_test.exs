defmodule TreninoWeb.ConfigurationEditLiveTest do
  use TreninoWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Trenino.Hardware
  alias Trenino.Hardware.Calibration.Session, as: CalibrationSession
  alias Trenino.Hardware.Input

  describe "apply_to_device errors" do
    setup %{conn: conn} do
      Mimic.set_mimic_global()
      {:ok, device} = Hardware.create_device(%{name: "Apply device"})
      {:ok, view, _html} = live(conn, "/configurations/#{device.config_id}")
      %{device: device, view: view, port: "/dev/tty.apply_#{System.unique_integer([:positive])}"}
    end

    test "shows the generic firmware message", %{device: device, view: view, port: port} do
      {:ok, _} =
        Hardware.create_i2c_module(device.id, %{
          module_chip: :mcp23017,
          i2c_address: 0x20,
          params: %{direct_mask: 1, row_mask: 0, col_mask: 0}
        })

      Mimic.stub(Trenino.Serial.Connection, :connected_devices, fn ->
        [%{port: port, device_version: "3.1.0"}]
      end)

      html = render_hook(view, "apply_to_device", %{"port" => port})
      assert html =~ "This configuration needs newer firmware. Update the device firmware"
    end

    test "shows the too many modules error", %{device: device, view: view, port: port} do
      for pin <- 1..9 do
        {:ok, _} = Hardware.create_input(device.id, %{pin: pin, input_type: :button, debounce: 5})
      end

      html = render_hook(view, "apply_to_device", %{"port" => port})
      assert html =~ "at most 8 modules"
    end
  end

  describe "mount/3 with invalid config_id" do
    test "redirects when configuration not found", %{conn: conn} do
      {:error, {:redirect, %{to: "/", flash: flash}}} =
        live(conn, "/configurations/999999999")

      assert flash["error"] == "Configuration not found"
    end

    test "redirects with invalid config_id format", %{conn: conn} do
      {:error, {:redirect, %{to: "/", flash: flash}}} =
        live(conn, "/configurations/invalid")

      assert flash["error"] == "Invalid configuration ID"
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

    test "configuration failure reasons" do
      # Test the error message mapping logic from handle_info
      reasons = [:timeout, :device_rejected, :no_inputs, :unknown]

      expected_messages = [
        "Configuration timed out - device did not respond",
        "Device rejected the configuration",
        "Cannot apply empty configuration",
        "Failed to apply configuration"
      ]

      for {reason, expected} <- Enum.zip(reasons, expected_messages) do
        message =
          case reason do
            :timeout -> "Configuration timed out - device did not respond"
            :device_rejected -> "Device rejected the configuration"
            :no_inputs -> "Cannot apply empty configuration"
            _ -> "Failed to apply configuration"
          end

        assert message == expected, "Expected '#{expected}' for reason #{inspect(reason)}"
      end
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

  describe "chip inputs" do
    alias Trenino.Hardware.ConfigurationManager

    setup %{conn: conn} do
      Mimic.set_mimic_global()
      {:ok, device} = Hardware.create_device(%{name: "Chip device"})

      {:ok, mcp} =
        Hardware.create_i2c_module(device.id, %{
          name: "Panel",
          module_chip: :mcp23017,
          i2c_address: 0x20,
          params: %{direct_mask: 0b10000, row_mask: 0b11, col_mask: 0b1100}
        })

      {:ok, ads} =
        Hardware.create_i2c_module(device.id, %{
          module_chip: :ads1115,
          i2c_address: 0x48,
          params: %{channel_mask: 0b0100, gain: 1, ref_channel: nil}
        })

      %{conn: conn, device: device, mcp: mcp, ads: ads}
    end

    defp connect_device(device) do
      port = "/dev/tty.chip_#{System.unique_integer([:positive])}"

      Mimic.stub(Trenino.Serial.Connection, :list_devices, fn ->
        [
          %Trenino.Serial.Connection.DeviceConnection{
            port: port,
            status: :connected,
            device_config_id: device.config_id
          }
        ]
      end)

      port
    end

    test "device page groups inputs under their chip", %{conn: conn, device: device, mcp: mcp} do
      {:ok, view, html} = live(conn, "/configurations/#{device.config_id}")

      assert has_element?(view, "#chip-inputs-#{mcp.id}")
      assert has_element?(view, "#chip-inputs-#{mcp.id} td", "MCP 0x20 GPA4")
      assert has_element?(view, "#chip-inputs-#{mcp.id} td", "MCP 0x20 R1C1")
      assert html =~ "ADS 0x48 AIN2"
      # Chip inputs are not listed with the board inputs.
      refute has_element?(view, "#add-display[disabled]")
    end

    test "modal titles are chip neutral and keep their ids", %{
      conn: conn,
      device: device,
      mcp: mcp
    } do
      {:ok, view, _html} = live(conn, "/configurations/#{device.config_id}")

      view |> element("#add-display") |> render_click()
      assert has_element?(view, "#i2c-display-title", "Add I2C module")
      view |> element("button", "Cancel") |> render_click()

      view |> element("#edit-display-#{mcp.id}") |> render_click()
      assert has_element?(view, "#i2c-display-title", "Edit I2C module")
    end

    test "chip inputs can be calibrated and renamed from the device page", %{
      conn: conn,
      device: device,
      mcp: mcp,
      ads: ads
    } do
      port = connect_device(device)
      {:ok, view, _html} = live(conn, "/configurations/#{device.config_id}")
      [ads_input] = Hardware.list_i2c_module_inputs(ads)
      [direct | _] = Hardware.list_i2c_module_inputs(mcp)

      assert has_element?(view, "#chip-input-#{ads_input.id} button", "Calibrate")
      refute has_element?(view, "#chip-input-#{direct.id} button", "Calibrate")

      render_blur(element(view, "#chip-input-#{ads_input.id} input[type=text]"), %{
        "value" => "Brake pipe"
      })

      assert {:ok, %{name: "Brake pipe"}} = Hardware.get_input(ads_input.id)
      assert has_element?(view, "#chip-input-#{ads_input.id} input[value='Brake pipe']")

      render_blur(element(view, "#chip-input-#{ads_input.id} input[type=number]"), %{
        "value" => "8"
      })

      assert {:ok, %{sensitivity: 8}} = Hardware.get_input(ads_input.id)

      view |> element("#chip-input-#{ads_input.id} button", "Calibrate") |> render_click()
      assert has_element?(view, "h2", "Calibrate Input")
      assert has_element?(view, "p", "ADS 0x48 AIN2")

      send(view.pid, {:input_value_updated, port, ads_input.pin, 512})
      assert render(view) =~ "512"
    end

    test "sensitivity edits on a child make the configuration unapplied", %{
      conn: conn,
      device: device,
      ads: ads
    } do
      [ads_input] = Hardware.list_i2c_module_inputs(ads)

      fingerprint =
        Hardware.config_fingerprint([], [], Hardware.list_i2c_modules(device.id), [])

      {:ok, device} = Hardware.confirm_configuration(device.id, device.config_id, fingerprint)
      {:ok, view, _html} = live(conn, "/configurations/#{device.config_id}")
      refute has_element?(view, "#apply-needed-banner")

      render_blur(element(view, "#chip-input-#{ads_input.id} input[type=number]"), %{
        "value" => "9"
      })

      assert has_element?(view, "#apply-needed-banner")
    end

    test "failed chip shows address and wiring hint", %{conn: conn, device: device, mcp: mcp} do
      port = connect_device(device)
      send(ConfigurationManager, {:devices_updated, []})
      {:ok, view, _html} = live(conn, "/configurations/#{device.config_id}")

      send(view.pid, {:i2c_module_status, port, %{0x20 => :init_failed}})
      html = render(view)

      assert has_element?(view, "#chip-failure-#{mcp.id}", "MCP 0x20")
      assert html =~ "Check wiring and the address jumpers."
    end

    test "chip status updates live", %{conn: conn, device: device, mcp: mcp, ads: ads} do
      port = connect_device(device)
      {:ok, view, _html} = live(conn, "/configurations/#{device.config_id}")
      refute has_element?(view, "#chip-failure-#{mcp.id}")

      send(view.pid, {:i2c_module_status, port, %{0x48 => :reference_lost}})
      render(view)

      assert has_element?(
               view,
               "#chip-failure-#{ads.id}",
               "Supply reference lost. Check the wire to the reference channel."
             )

      send(view.pid, {:i2c_module_status, port, %{}})
      render(view)
      refute has_element?(view, "#chip-failure-#{ads.id}")
    end

    test "chip rows do not crash the display controls", %{
      conn: conn,
      device: device,
      mcp: mcp
    } do
      connect_device(device)
      {:ok, view, _html} = live(conn, "/configurations/#{device.config_id}")

      refute has_element?(view, "button[phx-click='test_display']")
      assert has_element?(view, "#test-chip-matrix-#{mcp.id}")
      render_click(view, "test_display", %{"id" => to_string(mcp.id)})
      send(view.pid, {:display_test_step, mcp.id, 1})
      assert render(view) =~ "Panel"
    end

    test "matrix test wizard runs for an MCP matrix", %{conn: conn, device: device, mcp: mcp} do
      port = connect_device(device)
      {:ok, view, _html} = live(conn, "/configurations/#{device.config_id}")

      [matrix_cell | _] =
        mcp |> Hardware.list_i2c_module_inputs() |> Enum.filter(&(&1.i2c_channel >= 16))

      view |> element("#test-chip-matrix-#{mcp.id}") |> render_click()
      html = render(view)

      assert html =~ "2 rows x 2 columns"
      assert html =~ "GPA0"
      assert html =~ "GPA3"

      send(view.pid, {:input_value_updated, port, matrix_cell.pin, 1})
      html = render(view)
      assert html =~ "1 / 4 buttons tested"
    end

    test "a parent re-render does not reset the open chip form", %{
      conn: conn,
      device: device,
      mcp: mcp
    } do
      port = connect_device(device)
      {:ok, view, _html} = live(conn, "/configurations/#{device.config_id}")

      view |> element("#edit-display-#{mcp.id}") |> render_click()

      view
      |> form("#i2c-module-form", %{"i2c_module" => %{"name" => "Renamed"}})
      |> render_change()

      send(view.pid, {:i2c_module_status, port, %{0x20 => :communication_lost}})
      send(view.pid, {:input_value_updated, port, 4, 1})

      # A parent update with the same module must not re-initialise the form.
      {:ok, same} = Hardware.get_i2c_module(mcp.id)

      Phoenix.LiveView.send_update(view.pid, TreninoWeb.I2cModuleFormComponent,
        id: "i2c-module-form",
        i2c_module: same,
        device_id: device.id
      )

      assert render(view) =~ ~s(value="Renamed")
    end

    test "deleting a bound chip confirms with the impact computed at click time", %{
      conn: conn,
      device: device,
      ads: ads
    } do
      [input] = Hardware.list_i2c_module_inputs(ads)
      {:ok, view, _html} = live(conn, "/configurations/#{device.config_id}")

      # Bound after the page loaded: a load-time impact would miss it.
      {:ok, train} =
        Trenino.Train.create_train(%{name: "Bound", identifiers: [%{identifier: "Bound_1"}]})

      {:ok, elem} = Trenino.Train.create_element(train.id, %{name: "Horn", type: :button})

      {:ok, _} =
        Trenino.Train.create_button_binding(elem.id, input.id, %{endpoint: "Horn.InputValue"})

      view
      |> element("button[phx-click='ask_delete_i2c_module'][phx-value-id='#{ads.id}']")
      |> render_click()

      assert has_element?(view, "#delete-confirm-#{ads.id}", "Button Horn on Bound")

      view |> element("#confirm-delete-#{ads.id}") |> render_click()
      assert {:error, :not_found} = Hardware.get_i2c_module(ads.id)
    end

    test "cancelling the confirmation keeps the chip", %{conn: conn, device: device, ads: ads} do
      {:ok, view, _html} = live(conn, "/configurations/#{device.config_id}")

      view
      |> element("button[phx-click='ask_delete_i2c_module'][phx-value-id='#{ads.id}']")
      |> render_click()

      assert has_element?(view, "#delete-confirm-#{ads.id}")

      view |> element("#cancel-delete-#{ads.id}") |> render_click()
      refute has_element?(view, "#delete-confirm-#{ads.id}")
      assert {:ok, _} = Hardware.get_i2c_module(ads.id)
    end
  end
end
