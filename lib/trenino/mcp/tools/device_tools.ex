defmodule Trenino.MCP.Tools.DeviceTools do
  @moduledoc """
  MCP tools for listing connected hardware devices, inputs, and outputs.
  """

  alias Trenino.Hardware

  def tools do
    [
      %{
        name: "list_devices",
        description:
          "List all connected hardware devices. Returns id, name, and connection status for each device.",
        input_schema: %{
          type: "object",
          properties: %{}
        }
      },
      %{
        name: "list_device_inputs",
        description:
          "List all inputs (buttons and analog sensors) for a specific device. " <>
            "Use this to find input IDs when creating button bindings.",
        input_schema: %{
          type: "object",
          properties: %{
            device_id: %{type: "integer", description: "Device ID from list_devices"}
          },
          required: ["device_id"]
        }
      },
      %{
        name: "list_hardware_outputs",
        description:
          "List all available hardware outputs (LEDs, relays) across all devices. " <>
            "Use this to find output IDs when creating output bindings.",
        input_schema: %{
          type: "object",
          properties: %{}
        }
      }
    ]
  end

  def execute("list_devices", _args) do
    devices = Hardware.list_configurations()

    {:ok,
     %{
       devices:
         Enum.map(devices, fn d ->
           %{id: d.id, name: d.name}
         end)
     }}
  end

  def execute("list_device_inputs", %{"device_id" => device_id}) do
    {:ok, inputs} = Hardware.list_inputs(device_id)

    {:ok,
     %{
       inputs:
         Enum.map(inputs, fn i ->
           %{
             id: i.id,
             name: i.name,
             pin: i.pin,
             input_type: i.input_type
           }
         end)
     }}
  end

  def execute("list_hardware_outputs", _args) do
    devices = Hardware.list_configurations(preload: [:outputs])

    outputs =
      Enum.flat_map(devices, fn device ->
        Enum.map(device.outputs, fn output ->
          %{
            id: output.id,
            name: output.name,
            pin: output.pin,
            device_name: device.name,
            device_id: device.id
          }
        end)
      end)

    {:ok, %{outputs: outputs}}
  end
end
