defmodule Trenino.Hardware.InputTest do
  use Trenino.DataCase, async: true

  alias Trenino.Hardware.Input

  describe "changeset/2 - BLDC lever" do
    setup do
      device = insert_device()
      %{device: device}
    end

    test "valid BLDC lever changeset", %{device: device} do
      attrs = bldc_attrs()
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      assert changeset.valid?
    end

    test "BLDC lever requires all hardware fields except enable pins", %{device: device} do
      attrs = %{
        input_type: :bldc_lever,
        pin: 10,
        motor_pin_a: 5
      }

      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      refute changeset.valid?
      assert errors_on(changeset).motor_pin_b
    end

    test "BLDC lever is valid without enable pin", %{device: device} do
      attrs = Map.delete(bldc_attrs(), :motor_enable)

      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      assert changeset.valid?
    end

    test "BLDC lever validates pole_pairs > 0", %{device: device} do
      attrs = bldc_attrs(pole_pairs: 0)
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      refute changeset.valid?
      assert errors_on(changeset).pole_pairs
    end

    test "BLDC lever validates voltage > 0", %{device: device} do
      attrs = bldc_attrs(voltage: 0)
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      refute changeset.valid?
      assert errors_on(changeset).voltage
    end

    test "BLDC lever validates encoder_bits > 0", %{device: device} do
      attrs = bldc_attrs(encoder_bits: 0)
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      refute changeset.valid?
      assert errors_on(changeset).encoder_bits
    end

    test "BLDC lever validates values are 0-255", %{device: device} do
      attrs = bldc_attrs(motor_pin_a: 256)
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      refute changeset.valid?
      assert errors_on(changeset).motor_pin_a
    end

    test "analog changeset still works", %{device: device} do
      attrs = %{input_type: :analog, pin: 0, sensitivity: 5}
      changeset = Input.changeset(%Input{device_id: device.id}, attrs)
      assert changeset.valid?
    end
  end

  defp bldc_attrs(overrides \\ []) do
    Map.merge(
      %{
        input_type: :bldc_lever,
        pin: 10,
        motor_pin_a: 5,
        motor_pin_b: 6,
        motor_pin_c: 9,
        motor_enable: 7,
        encoder_cs: 10,
        pole_pairs: 11,
        voltage: 120,
        current_limit: 0.0,
        encoder_bits: 14
      },
      Map.new(overrides)
    )
  end

  defp insert_device do
    {:ok, device} =
      Trenino.Hardware.create_device(%{
        name: "Test Device",
        config_id: :rand.uniform(999_999)
      })

    device
  end
end
