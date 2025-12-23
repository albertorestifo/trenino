defmodule TswIo.HardwareTest do
  # async: false due to SQLite write lock contention with other tests
  use TswIo.DataCase, async: false

  alias TswIo.Hardware
  alias TswIo.Hardware.Device
  alias TswIo.Hardware.Input

  describe "create_device/1" do
    test "creates a device with valid attributes and auto-generated config_id" do
      attrs = %{name: "Test Device"}

      assert {:ok, %Device{} = device} = Hardware.create_device(attrs)
      assert device.name == "Test Device"
      assert is_integer(device.config_id)
      assert device.config_id > 0
    end

    test "returns error changeset with missing name" do
      assert {:error, changeset} = Hardware.create_device(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "get_device/2" do
    test "returns device by id" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      assert {:ok, %Device{} = found} = Hardware.get_device(device.id)
      assert found.id == device.id
      assert found.name == "Test Device"
    end

    test "returns error when device not found" do
      assert {:error, :not_found} = Hardware.get_device(999_999)
    end

    test "preloads associations when requested" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, _input} =
        Hardware.create_input(device.id, %{pin: 1, input_type: :analog, sensitivity: 5})

      {:ok, found} = Hardware.get_device(device.id, preload: [:inputs])

      assert length(found.inputs) == 1
    end
  end

  describe "get_device_by_config_id/1" do
    test "returns device with matching config_id" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, device} = Hardware.update_device(device, %{config_id: 12345})

      assert {:ok, %Device{} = found} = Hardware.get_device_by_config_id(12345)
      assert found.id == device.id
    end

    test "returns error when no device matches config_id" do
      assert {:error, :not_found} = Hardware.get_device_by_config_id(999_999)
    end

    test "preloads inputs automatically" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, device} = Hardware.update_device(device, %{config_id: 12345})

      {:ok, _input} =
        Hardware.create_input(device.id, %{pin: 1, input_type: :analog, sensitivity: 5})

      {:ok, found} = Hardware.get_device_by_config_id(12345)

      assert length(found.inputs) == 1
    end
  end

  describe "update_device/2" do
    test "updates device with valid attributes" do
      {:ok, device} = Hardware.create_device(%{name: "Original Name"})

      assert {:ok, %Device{} = updated} = Hardware.update_device(device, %{name: "Updated Name"})
      assert updated.name == "Updated Name"
    end

    test "updates config_id" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      assert {:ok, %Device{} = updated} = Hardware.update_device(device, %{config_id: 54321})
      assert updated.config_id == 54321
    end
  end

  describe "confirm_configuration/2" do
    test "sets config_id on device" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      assert {:ok, %Device{} = updated} = Hardware.confirm_configuration(device.id, 98765)
      assert updated.config_id == 98765
    end

    test "returns error when device not found" do
      assert {:error, :not_found} = Hardware.confirm_configuration(999_999, 12345)
    end
  end

  describe "generate_config_id/0" do
    test "returns a positive integer" do
      assert {:ok, config_id} = Hardware.generate_config_id()
      assert is_integer(config_id)
      assert config_id > 0
    end

    test "generates unique values" do
      {:ok, id1} = Hardware.generate_config_id()
      {:ok, id2} = Hardware.generate_config_id()
      {:ok, id3} = Hardware.generate_config_id()

      assert id1 != id2
      assert id2 != id3
      assert id1 != id3
    end
  end

  describe "create_input/2" do
    test "creates input with valid attributes" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      attrs = %{pin: 5, input_type: :analog, sensitivity: 7}

      assert {:ok, %Input{} = input} = Hardware.create_input(device.id, attrs)
      assert input.device_id == device.id
      assert input.pin == 5
      assert input.input_type == :analog
      assert input.sensitivity == 7
    end

    test "creates input with string keys (from form params)" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      attrs = %{"pin" => "5", "input_type" => "analog", "sensitivity" => "7"}

      assert {:ok, %Input{} = input} = Hardware.create_input(device.id, attrs)
      assert input.device_id == device.id
      assert input.pin == 5
      assert input.input_type == :analog
      assert input.sensitivity == 7
    end

    test "returns error changeset with missing required fields" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      assert {:error, changeset} = Hardware.create_input(device.id, %{})

      errors = errors_on(changeset)
      # input_type is always required
      assert %{input_type: ["can't be blank"]} = errors
      # Note: pin is only required for analog/button types, not matrix
      # Note: sensitivity is now only required when input_type is :analog
    end

    test "validates pin must be between 0 and 127 for analog" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      # Pin too low
      attrs = %{pin: -1, input_type: :analog, sensitivity: 5}
      assert {:error, changeset} = Hardware.create_input(device.id, attrs)
      assert %{pin: ["must be between 0 and 127 for physical inputs"]} = errors_on(changeset)

      # Pin too high
      attrs = %{pin: 128, input_type: :analog, sensitivity: 5}
      assert {:error, changeset} = Hardware.create_input(device.id, attrs)
      assert %{pin: ["must be between 0 and 127 for physical inputs"]} = errors_on(changeset)
    end

    test "validates sensitivity must be greater than 0" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      attrs = %{pin: 5, input_type: :analog, sensitivity: 0}

      assert {:error, changeset} = Hardware.create_input(device.id, attrs)
      assert %{sensitivity: ["must be greater than 0"]} = errors_on(changeset)
    end

    test "validates sensitivity must be less than or equal to 10" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      attrs = %{pin: 5, input_type: :analog, sensitivity: 11}

      assert {:error, changeset} = Hardware.create_input(device.id, attrs)
      assert %{sensitivity: ["must be less than or equal to 10"]} = errors_on(changeset)
    end

    test "enforces unique pin per device" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      attrs = %{pin: 5, input_type: :analog, sensitivity: 5}

      assert {:ok, _input1} = Hardware.create_input(device.id, attrs)
      assert {:error, changeset} = Hardware.create_input(device.id, attrs)
      assert %{device_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows same pin on different devices" do
      {:ok, device1} = Hardware.create_device(%{name: "Device 1"})
      {:ok, device2} = Hardware.create_device(%{name: "Device 2"})
      attrs = %{pin: 5, input_type: :analog, sensitivity: 5}

      assert {:ok, _input1} = Hardware.create_input(device1.id, attrs)
      assert {:ok, _input2} = Hardware.create_input(device2.id, attrs)
    end
  end

  describe "list_inputs/1" do
    test "returns empty list when device has no inputs" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      assert {:ok, []} = Hardware.list_inputs(device.id)
    end

    test "returns inputs ordered by pin" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, _} = Hardware.create_input(device.id, %{pin: 10, input_type: :analog, sensitivity: 5})
      {:ok, _} = Hardware.create_input(device.id, %{pin: 2, input_type: :analog, sensitivity: 5})
      {:ok, _} = Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

      assert {:ok, inputs} = Hardware.list_inputs(device.id)

      pins = Enum.map(inputs, & &1.pin)
      assert pins == [2, 5, 10]
    end

    test "only returns inputs for specified device" do
      {:ok, device1} = Hardware.create_device(%{name: "Device 1"})
      {:ok, device2} = Hardware.create_device(%{name: "Device 2"})

      {:ok, _} = Hardware.create_input(device1.id, %{pin: 1, input_type: :analog, sensitivity: 5})
      {:ok, _} = Hardware.create_input(device2.id, %{pin: 2, input_type: :analog, sensitivity: 5})

      assert {:ok, inputs} = Hardware.list_inputs(device1.id)
      assert length(inputs) == 1
      assert hd(inputs).pin == 1
    end
  end

  describe "delete_input/1" do
    test "deletes input by id" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

      assert {:ok, %Input{}} = Hardware.delete_input(input.id)
      assert {:ok, []} = Hardware.list_inputs(device.id)
    end

    test "deletes input by struct" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :analog, sensitivity: 5})

      assert {:ok, %Input{}} = Hardware.delete_input(input)
      assert {:ok, []} = Hardware.list_inputs(device.id)
    end

    test "returns error when input not found" do
      assert {:error, :not_found} = Hardware.delete_input(999_999)
    end
  end

  describe "create_matrix/2" do
    test "creates matrix with name and row/col pins" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      attrs = %{
        name: "Test Matrix",
        row_pins: [2, 3, 4, 5],
        col_pins: [8, 9, 10]
      }

      assert {:ok, matrix} = Hardware.create_matrix(device.id, attrs)
      assert matrix.name == "Test Matrix"
      assert matrix.device_id == device.id

      # Verify pins were created
      assert length(matrix.row_pins) == 4
      assert length(matrix.col_pins) == 3

      # Verify positions are set correctly
      row_pin_values = Enum.map(Enum.sort_by(matrix.row_pins, & &1.position), & &1.pin)
      col_pin_values = Enum.map(Enum.sort_by(matrix.col_pins, & &1.position), & &1.pin)

      assert row_pin_values == [2, 3, 4, 5]
      assert col_pin_values == [8, 9, 10]
    end

    test "creates virtual button inputs for each matrix position" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      attrs = %{
        name: "Test Matrix",
        row_pins: [2, 3],
        col_pins: [8, 9, 10]
      }

      assert {:ok, matrix} = Hardware.create_matrix(device.id, attrs)
      assert length(matrix.buttons) == 6

      # Verify virtual pins are correctly calculated (128 + row_idx * num_cols + col_idx)
      button_pins = Enum.map(matrix.buttons, & &1.pin) |> Enum.sort()
      expected_pins = [128, 129, 130, 131, 132, 133]
      assert button_pins == expected_pins
    end

    # Note: Currently only one matrix per device is supported because all matrices
    # create virtual buttons starting at pin 128. Future enhancement could support
    # multiple matrices by using unique pin ranges per matrix.

    test "validates pin range (0-127)" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      assert {:error, _changeset} =
               Hardware.create_matrix(device.id, %{name: "M", row_pins: [128], col_pins: [8, 9]})

      assert {:error, _changeset} =
               Hardware.create_matrix(device.id, %{name: "M", row_pins: [2, 3], col_pins: [128]})

      assert {:error, _changeset} =
               Hardware.create_matrix(device.id, %{name: "M", row_pins: [-1], col_pins: [8, 9]})
    end
  end

  describe "list_matrices/1" do
    test "returns matrices with preloaded pins and buttons" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, _matrix} =
        Hardware.create_matrix(device.id, %{
          name: "Test Matrix",
          row_pins: [2, 3],
          col_pins: [8, 9]
        })

      {:ok, [loaded_matrix]} = Hardware.list_matrices(device.id)

      assert length(loaded_matrix.row_pins) == 2
      assert length(loaded_matrix.col_pins) == 2
      assert length(loaded_matrix.buttons) == 4
    end
  end

  describe "delete_matrix/1" do
    test "deletes matrix and cascades to virtual buttons" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, matrix} =
        Hardware.create_matrix(device.id, %{
          name: "Test Matrix",
          row_pins: [2, 3],
          col_pins: [8, 9]
        })

      # Verify buttons exist
      {:ok, inputs} = Hardware.list_inputs(device.id, include_virtual_buttons: true)
      assert length(inputs) == 4

      # Delete matrix
      assert {:ok, _} = Hardware.delete_matrix(matrix)

      # Verify buttons are deleted
      {:ok, inputs} = Hardware.list_inputs(device.id, include_virtual_buttons: true)
      assert length(inputs) == 0
    end
  end

  describe "list_inputs/2 with include_virtual_buttons option" do
    test "excludes virtual buttons by default" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, _matrix} =
        Hardware.create_matrix(device.id, %{
          name: "Test Matrix",
          row_pins: [2, 3],
          col_pins: [8, 9]
        })

      {:ok, _analog} =
        Hardware.create_input(device.id, %{pin: 0, input_type: :analog, sensitivity: 5})

      {:ok, inputs} = Hardware.list_inputs(device.id)
      assert length(inputs) == 1
      assert hd(inputs).input_type == :analog
    end

    test "includes virtual buttons when option is true" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, _matrix} =
        Hardware.create_matrix(device.id, %{
          name: "Test Matrix",
          row_pins: [2, 3],
          col_pins: [8, 9]
        })

      {:ok, _analog} =
        Hardware.create_input(device.id, %{pin: 0, input_type: :analog, sensitivity: 5})

      {:ok, inputs} = Hardware.list_inputs(device.id, include_virtual_buttons: true)
      assert length(inputs) == 5
    end
  end
end
