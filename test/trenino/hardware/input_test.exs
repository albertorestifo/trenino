defmodule Trenino.Hardware.InputTest do
  use Trenino.DataCase, async: true

  alias Trenino.Hardware.Input

  describe "changeset/2" do
    setup do
      {:ok, device} =
        Trenino.Hardware.create_device(%{
          name: "Test Device",
          config_id: :rand.uniform(999_999)
        })

      %{device: device}
    end

    test "valid analog changeset", %{device: device} do
      attrs = %{input_type: :analog, pin: 0, sensitivity: 5}
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      assert changeset.valid?
    end

    test "an MT6701 input takes its report pin from the I2C address", %{device: device} do
      for {address, pin} <- [{0x06, 240}, {0x46, 241}] do
        attrs = %{input_type: :analog, sensor: :mt6701, i2c_address: address, sensitivity: 5}
        changeset = Input.changeset(%Input{device_id: device.id}, attrs)
        assert changeset.valid?
        assert Ecto.Changeset.get_field(changeset, :pin) == pin
      end
    end

    test "an MT6701 input needs a supported address", %{device: device} do
      attrs = %{input_type: :analog, sensor: :mt6701, sensitivity: 5}
      refute Input.changeset(%Input{device_id: device.id}, attrs).valid?

      changeset =
        Input.changeset(%Input{device_id: device.id}, Map.put(attrs, :i2c_address, 0x70))

      refute changeset.valid?
      assert %{i2c_address: [_]} = errors_on(changeset)
    end

    test "an MT6701 can't be a button", %{device: device} do
      attrs = %{input_type: :button, sensor: :mt6701, i2c_address: 0x06, pin: 3, debounce: 20}
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      refute changeset.valid?
      assert %{sensor: [_]} = errors_on(changeset)
    end

    test "an ADC input drops a stray I2C address and defaults to the ADC", %{device: device} do
      attrs = %{input_type: :analog, pin: 14, sensitivity: 5, i2c_address: 0x06}
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :sensor) == :adc
      assert Ecto.Changeset.get_field(changeset, :i2c_address) == nil
    end

    test "valid button changeset", %{device: device} do
      attrs = %{input_type: :button, pin: 0, debounce: 20}
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      assert changeset.valid?
    end
  end

  describe "max_raw_value/1" do
    test "is 10-bit for the ADC and 14-bit for an MT6701" do
      assert Input.max_raw_value(%Input{sensor: :adc}) == 1023
      assert Input.max_raw_value(%Input{sensor: :mt6701}) == 16_383
    end
  end
end
