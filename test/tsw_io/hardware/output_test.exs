defmodule TswIo.Hardware.OutputTest do
  use TswIo.DataCase, async: false

  alias TswIo.Hardware
  alias TswIo.Hardware.Output

  describe "changeset/2" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      %{device: device}
    end

    test "valid changeset with required fields", %{device: device} do
      attrs = %{pin: 13, device_id: device.id}
      changeset = Output.changeset(%Output{}, attrs)

      assert changeset.valid?
    end

    test "valid changeset with name", %{device: device} do
      attrs = %{pin: 13, name: "Brake Warning LED", device_id: device.id}
      changeset = Output.changeset(%Output{}, attrs)

      assert changeset.valid?
    end

    test "invalid without pin", %{device: device} do
      attrs = %{name: "LED", device_id: device.id}
      changeset = Output.changeset(%Output{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).pin
    end

    test "invalid without device_id" do
      attrs = %{pin: 13}
      changeset = Output.changeset(%Output{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).device_id
    end

    test "invalid with negative pin", %{device: device} do
      attrs = %{pin: -1, device_id: device.id}
      changeset = Output.changeset(%Output{}, attrs)

      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).pin
    end

    test "invalid with pin > 255", %{device: device} do
      attrs = %{pin: 256, device_id: device.id}
      changeset = Output.changeset(%Output{}, attrs)

      refute changeset.valid?
      assert "must be less than 256" in errors_on(changeset).pin
    end

    test "valid with pin 0", %{device: device} do
      attrs = %{pin: 0, device_id: device.id}
      changeset = Output.changeset(%Output{}, attrs)

      assert changeset.valid?
    end

    test "valid with pin 255", %{device: device} do
      attrs = %{pin: 255, device_id: device.id}
      changeset = Output.changeset(%Output{}, attrs)

      assert changeset.valid?
    end

    test "invalid with name > 100 characters", %{device: device} do
      long_name = String.duplicate("a", 101)
      attrs = %{pin: 13, name: long_name, device_id: device.id}
      changeset = Output.changeset(%Output{}, attrs)

      refute changeset.valid?
      assert "should be at most 100 character(s)" in errors_on(changeset).name
    end
  end

  describe "unique constraint" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      %{device: device}
    end

    test "cannot create duplicate pin for same device", %{device: device} do
      {:ok, _output} = Hardware.create_output(device.id, %{pin: 13})
      {:error, changeset} = Hardware.create_output(device.id, %{pin: 13})

      # The unique constraint error appears on device_id because the constraint is on [:device_id, :pin]
      errors = errors_on(changeset)

      assert "has already been taken" in errors.device_id or
               "has already been taken" in Map.get(errors, :pin, [])
    end

    test "can use same pin on different devices" do
      {:ok, device1} = Hardware.create_device(%{name: "Device 1"})
      {:ok, device2} = Hardware.create_device(%{name: "Device 2"})

      {:ok, output1} = Hardware.create_output(device1.id, %{pin: 13})
      {:ok, output2} = Hardware.create_output(device2.id, %{pin: 13})

      assert output1.pin == 13
      assert output2.pin == 13
    end
  end
end
