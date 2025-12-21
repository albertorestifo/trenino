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

    test "validates pin must be greater than or equal to 0 for analog" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      attrs = %{pin: -1, input_type: :analog, sensitivity: 5}

      assert {:error, changeset} = Hardware.create_input(device.id, attrs)
      assert %{pin: ["must be greater than or equal to 0"]} = errors_on(changeset)
    end

    test "validates pin must be less than 128 for analog" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      attrs = %{pin: 128, input_type: :analog, sensitivity: 5}

      assert {:error, changeset} = Hardware.create_input(device.id, attrs)
      assert %{pin: ["must be less than 128"]} = errors_on(changeset)
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

  describe "create_input/2 with matrix type" do
    test "creates matrix input with null pin" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      attrs = %{input_type: :matrix}

      assert {:ok, %Input{} = input} = Hardware.create_input(device.id, attrs)
      assert input.device_id == device.id
      assert input.pin == nil
      assert input.input_type == :matrix
    end

    test "matrix input requires pin to be null" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      attrs = %{pin: 5, input_type: :matrix}

      assert {:error, changeset} = Hardware.create_input(device.id, attrs)
      assert %{pin: ["must be null for matrix inputs"]} = errors_on(changeset)
    end

    test "allows multiple matrix inputs per device" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      assert {:ok, input1} = Hardware.create_input(device.id, %{input_type: :matrix})
      assert {:ok, input2} = Hardware.create_input(device.id, %{input_type: :matrix})

      assert input1.id != input2.id
      assert input1.pin == nil
      assert input2.pin == nil
    end
  end

  describe "set_matrix_pins/3" do
    test "creates row and column pins for matrix input" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, input} = Hardware.create_input(device.id, %{input_type: :matrix})

      row_pins = [2, 3, 4, 5]
      col_pins = [8, 9, 10]

      assert {:ok, pins} = Hardware.set_matrix_pins(input.id, row_pins, col_pins)
      assert length(pins) == 7

      row_pin_records = Enum.filter(pins, &(&1.pin_type == :row))
      col_pin_records = Enum.filter(pins, &(&1.pin_type == :col))

      assert length(row_pin_records) == 4
      assert length(col_pin_records) == 3

      # Verify positions are set correctly
      assert Enum.map(Enum.sort_by(row_pin_records, & &1.position), & &1.pin) == [2, 3, 4, 5]
      assert Enum.map(Enum.sort_by(col_pin_records, & &1.position), & &1.pin) == [8, 9, 10]
    end

    test "replaces existing matrix pins" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, input} = Hardware.create_input(device.id, %{input_type: :matrix})

      # Set initial pins
      {:ok, _} = Hardware.set_matrix_pins(input.id, [2, 3], [8, 9])

      # Replace with new pins
      {:ok, pins} = Hardware.set_matrix_pins(input.id, [10, 11, 12], [20, 21])
      assert length(pins) == 5

      row_pin_records = Enum.filter(pins, &(&1.pin_type == :row))
      col_pin_records = Enum.filter(pins, &(&1.pin_type == :col))

      assert Enum.map(Enum.sort_by(row_pin_records, & &1.position), & &1.pin) == [10, 11, 12]
      assert Enum.map(Enum.sort_by(col_pin_records, & &1.position), & &1.pin) == [20, 21]
    end

    test "validates pin range (0-127)" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, input} = Hardware.create_input(device.id, %{input_type: :matrix})

      assert {:error, _changeset} = Hardware.set_matrix_pins(input.id, [128], [8, 9])
      assert {:error, _changeset} = Hardware.set_matrix_pins(input.id, [2, 3], [128])
      # Note: -1 is invalid as a matrix GPIO pin (valid range is 0-127)
      assert {:error, _changeset} = Hardware.set_matrix_pins(input.id, [-1], [8, 9])
    end
  end

  describe "list_inputs/1 with matrix" do
    test "preloads matrix_pins" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, input} = Hardware.create_input(device.id, %{input_type: :matrix})
      {:ok, _} = Hardware.set_matrix_pins(input.id, [2, 3, 4], [8, 9])

      {:ok, [loaded_input]} = Hardware.list_inputs(device.id)

      assert length(loaded_input.matrix_pins) == 5
    end
  end
end
