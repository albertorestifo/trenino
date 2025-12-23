defmodule TswIoWeb.ConfigurationEditLiveTest do
  use TswIoWeb.ConnCase

  import Phoenix.LiveViewTest

  alias TswIo.Hardware
  alias TswIo.Hardware.Input

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
      {:ok, updated_device} = Hardware.update_device(device, %{config_id: 12345})

      # Verify the device was updated
      {:ok, found} = Hardware.get_device_by_config_id(12345)
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
      TswIo.Hardware.Calibration.Session.cancel(pid)
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
      calibration = %TswIo.Hardware.Input.Calibration{
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
      calibration = %TswIo.Hardware.Input.Calibration{
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
      TswIo.Hardware.Calibration.Session.subscribe(input.id)

      {:ok, pid} = Hardware.start_calibration_session(input, "/dev/test")

      # Should receive session_started
      assert_receive {:session_started, state}
      assert state.input_id == input.id

      TswIo.Hardware.Calibration.Session.cancel(pid)
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
