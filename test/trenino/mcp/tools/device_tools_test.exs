defmodule Trenino.MCP.Tools.DeviceToolsTest do
  use Trenino.DataCase, async: true

  alias Trenino.Hardware
  alias Trenino.MCP.Tools.DeviceTools

  describe "list_devices" do
    test "returns empty list when no devices" do
      assert {:ok, %{devices: []}} = DeviceTools.execute("list_devices", %{})
    end

    test "returns all devices" do
      {:ok, device} = Hardware.create_device(%{name: "Arduino Uno"})

      assert {:ok, %{devices: devices}} = DeviceTools.execute("list_devices", %{})
      assert [%{id: id, name: "Arduino Uno"}] = devices
      assert id == device.id
    end
  end

  describe "list_device_inputs" do
    test "returns inputs for a device" do
      {:ok, device} = Hardware.create_device(%{name: "Arduino Uno"})

      {:ok, _} =
        Hardware.create_input(device.id, %{
          pin: 0,
          input_type: :analog,
          name: "Throttle",
          sensitivity: 5
        })

      {:ok, _} =
        Hardware.create_input(device.id, %{
          pin: 5,
          input_type: :button,
          name: "Horn",
          debounce: 20
        })

      assert {:ok, %{inputs: inputs}} =
               DeviceTools.execute("list_device_inputs", %{"device_id" => device.id})

      assert length(inputs) == 2
      names = Enum.map(inputs, & &1.name)
      assert "Throttle" in names
      assert "Horn" in names
    end

    test "returns input fields" do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{
          pin: 3,
          input_type: :button,
          name: "Button 3",
          debounce: 20
        })

      {:ok, %{inputs: [result]}} =
        DeviceTools.execute("list_device_inputs", %{"device_id" => device.id})

      assert result.id == input.id
      assert result.name == "Button 3"
      assert result.pin == 3
      assert result.input_type == :button
    end
  end

  describe "list_hardware_outputs" do
    test "returns empty list when no outputs" do
      assert {:ok, %{outputs: []}} = DeviceTools.execute("list_hardware_outputs", %{})
    end

    test "returns all outputs across devices" do
      {:ok, device1} = Hardware.create_device(%{name: "Arduino Uno"})
      {:ok, device2} = Hardware.create_device(%{name: "Arduino Mega"})
      {:ok, _} = Hardware.create_output(device1.id, %{pin: 13, name: "Red LED"})
      {:ok, _} = Hardware.create_output(device2.id, %{pin: 5, name: "Green LED"})

      assert {:ok, %{outputs: outputs}} = DeviceTools.execute("list_hardware_outputs", %{})
      assert length(outputs) == 2

      names = Enum.map(outputs, & &1.name)
      assert "Red LED" in names
      assert "Green LED" in names
    end

    test "includes device info with outputs" do
      {:ok, device} = Hardware.create_device(%{name: "Arduino Uno"})
      {:ok, output} = Hardware.create_output(device.id, %{pin: 13, name: "Red LED"})

      {:ok, %{outputs: [result]}} = DeviceTools.execute("list_hardware_outputs", %{})

      assert result.id == output.id
      assert result.name == "Red LED"
      assert result.pin == 13
      assert result.device_name == "Arduino Uno"
      assert result.device_id == device.id
    end
  end

  describe "create_i2c_module" do
    test "persists chip params including orientation" do
      {:ok, device} = Hardware.create_device(%{name: "Arduino Uno"})

      assert {:ok, %{i2c_module: mod}} =
               DeviceTools.execute("create_i2c_module", %{
                 "device_id" => device.id,
                 "module_chip" => "ht16k33",
                 "i2c_address" => "0x70",
                 "name" => "Speed display",
                 "brightness" => 5,
                 "num_digits" => 8,
                 "orientation" => "rotated_180"
               })

      assert mod.brightness == 5
      assert mod.num_digits == 8
      assert mod.orientation == :rotated_180
      assert mod.display_type == :fourteen_segment
      assert mod.has_dot == false
    end

    test "applies param defaults when none are given" do
      {:ok, device} = Hardware.create_device(%{name: "Arduino Uno"})

      assert {:ok, %{i2c_module: mod}} =
               DeviceTools.execute("create_i2c_module", %{
                 "device_id" => device.id,
                 "module_chip" => "ht16k33",
                 "i2c_address" => "112"
               })

      assert mod.brightness == 8
      assert mod.num_digits == 4
      assert mod.orientation == :normal
    end
  end

  describe "update_i2c_module" do
    test "updates orientation without clobbering other params" do
      {:ok, device} = Hardware.create_device(%{name: "Arduino Uno"})

      {:ok, %{i2c_module: created}} =
        DeviceTools.execute("create_i2c_module", %{
          "device_id" => device.id,
          "module_chip" => "ht16k33",
          "i2c_address" => "0x70",
          "brightness" => 5,
          "num_digits" => 8
        })

      assert {:ok, %{i2c_module: updated} = result} =
               DeviceTools.execute("update_i2c_module", %{
                 "id" => created.id,
                 "orientation" => "flipped_vertical"
               })

      refute Map.has_key?(result, :removed)

      assert updated.orientation == :flipped_vertical
      assert updated.brightness == 5
      assert updated.num_digits == 8
    end
  end

  describe "list_i2c_modules" do
    test "serializes orientation" do
      {:ok, device} = Hardware.create_device(%{name: "Arduino Uno"})

      {:ok, _} =
        DeviceTools.execute("create_i2c_module", %{
          "device_id" => device.id,
          "module_chip" => "ht16k33",
          "i2c_address" => "0x70",
          "orientation" => "flipped_horizontal"
        })

      assert {:ok, %{i2c_modules: [mod]}} = DeviceTools.execute("list_i2c_modules", %{})
      assert mod.orientation == :flipped_horizontal
    end
  end

  describe "input chips" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Arduino Uno"})
      %{device: device}
    end

    test "add_i2c_module creates an MCP23017 with masks", %{device: device} do
      assert {:ok, %{i2c_module: mod}} =
               DeviceTools.execute("create_i2c_module", %{
                 "device_id" => device.id,
                 "module_chip" => "mcp23017",
                 "i2c_address" => "0x20",
                 "direct_mask" => 0b1111
               })

      assert mod.module_chip == :mcp23017
      assert mod.direct_mask == 15
      assert mod.row_mask == 0
      assert length(mod.inputs) == 4
      assert Enum.all?(mod.inputs, &(&1.input_type == :button))
    end

    test "creates an ADS1115 with a reference", %{device: device} do
      assert {:ok, %{i2c_module: mod}} =
               DeviceTools.execute("create_i2c_module", %{
                 "device_id" => device.id,
                 "module_chip" => "ads1115",
                 "i2c_address" => "0x48",
                 "channel_mask" => 0b0111,
                 "ref_channel" => 3,
                 "channels" => %{"0" => %{"name" => "Throttle", "sensitivity" => 7}}
               })

      assert mod.ref_channel == 3
      assert mod.gain == 0
      assert length(mod.inputs) == 3
      assert Enum.any?(mod.inputs, &(&1.name == "Throttle" and &1.sensitivity == 7))
    end

    test "update changes chip params and channel names", %{device: device} do
      {:ok, %{i2c_module: created}} =
        DeviceTools.execute("create_i2c_module", %{
          "device_id" => device.id,
          "module_chip" => "ads1115",
          "i2c_address" => "0x48",
          "channel_mask" => 3
        })

      assert {:ok, %{i2c_module: updated}} =
               DeviceTools.execute("update_i2c_module", %{
                 "id" => created.id,
                 "channel_mask" => 7,
                 "channels" => %{"1" => %{"name" => "Brake"}}
               })

      assert updated.channel_mask == 7
      assert length(updated.inputs) == 3
      assert Enum.any?(updated.inputs, &(&1.name == "Brake"))
    end

    test "update and delete report the bindings removed", %{device: device} do
      {:ok, %{i2c_module: created}} =
        DeviceTools.execute("create_i2c_module", %{
          "device_id" => device.id,
          "module_chip" => "ads1115",
          "i2c_address" => "0x48",
          "channel_mask" => 3
        })

      {:ok, mod} = Hardware.get_i2c_module(created.id)
      [_, second] = Hardware.list_i2c_module_inputs(mod)
      {:ok, _} = Trenino.VirtualJoystick.put_mapping(second.id, %{target_type: :axis, axis: :x})

      assert {:ok, %{removed: [%{input_id: id, binding: "Virtual joystick axis x"}]}} =
               DeviceTools.execute("update_i2c_module", %{
                 "id" => created.id,
                 "channel_mask" => 1
               })

      assert id == second.id

      assert {:ok, %{removed: []}} =
               DeviceTools.execute("delete_i2c_module", %{"id" => created.id})
    end

    test "list_i2c_modules includes channels and pins", %{device: device} do
      {:ok, _} =
        DeviceTools.execute("create_i2c_module", %{
          "device_id" => device.id,
          "module_chip" => "mcp23017",
          "i2c_address" => "0x20",
          "direct_mask" => 0b11
        })

      assert {:ok, %{i2c_modules: [mod]}} = DeviceTools.execute("list_i2c_modules", %{})
      assert mod.direct_mask == 3
      assert [%{label: "MCP 0x20 GPA0"}, %{label: "MCP 0x20 GPA1"}] = mod.inputs
      assert Enum.all?(mod.inputs, &(is_integer(&1.pin) and is_integer(&1.i2c_channel)))
    end

    test "list_device_inputs includes chip inputs with labels", %{device: device} do
      {:ok, _} =
        DeviceTools.execute("create_i2c_module", %{
          "device_id" => device.id,
          "module_chip" => "mcp23017",
          "i2c_address" => "0x20",
          "direct_mask" => 1
        })

      assert {:ok, %{inputs: [input]}} =
               DeviceTools.execute("list_device_inputs", %{"device_id" => device.id})

      assert input.label == "MCP 0x20 GPA0"
      assert input.input_type == :button
      assert is_integer(input.pin)
    end

    test "the GPA7 rule returns a readable error", %{device: device} do
      assert {:error, message} =
               DeviceTools.execute("create_i2c_module", %{
                 "device_id" => device.id,
                 "module_chip" => "mcp23017",
                 "i2c_address" => "0x20",
                 "direct_mask" => 0x80
               })

      assert message =~ "GPA7 and GPB7 are output-only"
    end
  end
end
