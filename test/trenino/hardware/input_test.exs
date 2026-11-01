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

    test "valid button changeset", %{device: device} do
      attrs = %{input_type: :button, pin: 0, debounce: 20}
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      assert changeset.valid?
    end

    test "chip input needs a pin in 128-255", %{device: device} do
      attrs = %{input_type: :button, debounce: 5, i2c_module_id: 1, i2c_channel: 0}

      refute Input.changeset(%Input{device_id: device.id}, Map.put(attrs, :pin, 5)).valid?
      assert Input.changeset(%Input{device_id: device.id}, Map.put(attrs, :pin, 128)).valid?
    end

    test "chip input needs an i2c_channel", %{device: device} do
      attrs = %{input_type: :button, debounce: 5, i2c_module_id: 1, pin: 128}
      cs = Input.changeset(%Input{device_id: device.id}, attrs)
      assert errors_on(cs).i2c_channel != []
    end

    test "i2c_channel without an i2c module is rejected", %{device: device} do
      attrs = %{input_type: :button, debounce: 5, pin: 3, i2c_channel: 0}
      refute Input.changeset(%Input{device_id: device.id}, attrs).valid?
    end

    test "an input cannot have both matrix and i2c module", %{device: device} do
      attrs = %{
        input_type: :button,
        debounce: 5,
        pin: 128,
        matrix_id: 1,
        i2c_module_id: 1,
        i2c_channel: 0
      }

      refute Input.changeset(%Input{device_id: device.id}, attrs).valid?
    end
  end

  describe "virtual?/1 and chip_input?/1" do
    test "classify inputs" do
      assert Input.virtual?(%Input{matrix_id: 1})
      assert Input.virtual?(%Input{i2c_module_id: 1})
      refute Input.virtual?(%Input{})
      assert Input.chip_input?(%Input{i2c_module_id: 1})
      refute Input.chip_input?(%Input{matrix_id: 1})
    end
  end
end
