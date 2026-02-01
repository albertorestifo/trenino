defmodule TreninoWeb.Api.OutputApiController do
  use TreninoWeb, :controller

  alias Trenino.Hardware

  def index(conn, _params) do
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

    json(conn, %{outputs: outputs})
  end
end
