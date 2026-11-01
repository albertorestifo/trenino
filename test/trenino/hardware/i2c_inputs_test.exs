defmodule Trenino.Hardware.I2cInputsTest do
  use Trenino.DataCase, async: true

  alias Trenino.Hardware

  setup do
    {:ok, device} = Hardware.create_device(%{name: "Chip Device", config_id: 4242})

    {:ok, module} =
      Hardware.create_i2c_module(device.id, %{
        module_chip: :ads1115,
        i2c_address: 0x48,
        params: %{channel_mask: 0x01, gain: 0}
      })

    {:ok, plain} =
      Hardware.create_input(device.id, %{pin: 1, input_type: :analog, sensitivity: 5})

    {:ok, chip} =
      Hardware.create_input(device.id, %{
        pin: 200,
        input_type: :analog,
        sensitivity: 5,
        i2c_module_id: module.id,
        i2c_channel: 0
      })

    {:ok, _matrix} =
      Hardware.create_matrix(device.id, %{name: "M", row_pins: [2, 3], col_pins: [4, 5]})

    for i <- [plain, chip] do
      {:ok, _} =
        Hardware.save_calibration(i.id, %{
          max_hardware_value: 1023,
          min_value: 0,
          max_value: 1000,
          has_rollover: false,
          is_inverted: false
        })
    end

    %{device: device, module: module, plain: plain, chip: chip}
  end

  test "chip input is persisted with its module and channel", %{chip: chip, module: module} do
    assert chip.i2c_module_id == module.id
    assert chip.i2c_channel == 0
  end

  test "channel is unique per module", %{device: device, module: module} do
    assert {:error, cs} =
             Hardware.create_input(device.id, %{
               pin: 201,
               input_type: :analog,
               sensitivity: 5,
               i2c_module_id: module.id,
               i2c_channel: 0
             })

    assert errors_on(cs)[:i2c_module_id] != nil or errors_on(cs)[:i2c_channel] != nil
  end

  test "list_inputs excludes chip inputs by default", %{device: device, chip: chip} do
    {:ok, inputs} = Hardware.list_inputs(device.id)
    refute chip.id in Enum.map(inputs, & &1.id)
  end

  test "list_inputs includes them with include_chip_inputs", %{device: device, chip: chip} do
    {:ok, inputs} = Hardware.list_inputs(device.id, include_chip_inputs: true)
    assert chip.id in Enum.map(inputs, & &1.id)
  end

  test "include_chip_inputs does not include matrix buttons", %{device: device} do
    {:ok, inputs} = Hardware.list_inputs(device.id, include_chip_inputs: true)
    refute Enum.any?(inputs, &(&1.matrix_id != nil))
  end

  test "list_inputs includes chip inputs with include_virtual_buttons", %{
    device: device,
    chip: chip
  } do
    {:ok, inputs} = Hardware.list_inputs(device.id, include_virtual_buttons: true)
    assert chip.id in Enum.map(inputs, & &1.id)
  end

  test "list_all_inputs filters the same way", %{chip: chip, plain: plain} do
    default = Enum.map(Hardware.list_all_inputs(), & &1.id)
    assert plain.id in default
    refute chip.id in default

    assert chip.id in Enum.map(Hardware.list_all_inputs(include_chip_inputs: true), & &1.id)

    assert chip.id in Enum.map(
             Hardware.list_all_inputs(include_virtual_buttons: true),
             & &1.id
           )
  end
end
