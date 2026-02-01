defmodule Trenino.MCP.Tools.DeviceToolsTest do
  use Trenino.DataCase, async: false

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
end
