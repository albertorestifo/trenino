defmodule TreninoWeb.AngleSensorSetupTest do
  use TreninoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Trenino.Hardware
  alias Trenino.Serial.Connection
  alias Trenino.Serial.Connection.DeviceConnection

  setup :set_mimic_global

  @port "/dev/cu.usbmodem-angle"

  setup do
    Mimic.stub(Circuits.UART, :enumerate, fn -> %{} end)
    {:ok, device} = Hardware.create_device(%{name: "Gate lever"})
    %{device: device}
  end

  defp connected(config_id, version \\ "3.4.0") do
    %DeviceConnection{
      port: @port,
      status: :connected,
      device_config_id: config_id,
      device_version: version
    }
  end

  defp add_mt6701(view) do
    view |> element("#add-input") |> render_click()

    view
    |> form("#add-input-form", input: %{input_type: "analog", sensor: "mt6701"})
    |> render_change()

    view |> form("#add-input-form") |> render_submit()
  end

  test "adding MT6701 sensors fills in the next free address", %{conn: conn, device: device} do
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")

    view |> element("#add-input") |> render_click()

    html =
      view
      |> form("#add-input-form", input: %{input_type: "analog", sensor: "mt6701"})
      |> render_change()

    assert html =~ "Every MT6701 ships at 0x06"
    assert has_element?(view, "#add-input-form option[selected][value='6']")
    refute has_element?(view, "#add-input-form input[name='input[pin]']")

    view |> form("#add-input-form") |> render_submit()
    assert has_element?(view, "#inputs td", "I2C 0x06")
    assert has_element?(view, "#inputs td", "MT6701")

    add_mt6701(view)
    assert has_element?(view, "#inputs td", "I2C 0x46")

    {:ok, inputs} = Hardware.list_inputs(device.id)
    assert inputs |> Enum.map(&{&1.i2c_address, &1.pin}) |> Enum.sort() == [{6, 240}, {70, 241}]
  end

  test "warns in the form when the controller's firmware can't read the sensor", %{
    conn: conn,
    device: device
  } do
    Mimic.stub(Connection, :connected_devices, fn -> [connected(device.config_id, "3.3.2")] end)
    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
    send(view.pid, {:devices_updated, [connected(device.config_id, "3.3.2")]})

    view |> element("#add-input") |> render_click()

    view
    |> form("#add-input-form", input: %{input_type: "analog", sensor: "mt6701"})
    |> render_change()

    assert has_element?(view, "#input-firmware-warning", "firmware 3.3.2")
    assert has_element?(view, "#input-firmware-warning", "3.4.0 or newer")
  end

  test "a sensor that did not answer shows as not responding until it reads again", %{
    conn: conn,
    device: device
  } do
    {:ok, input} =
      Hardware.create_input(device.id, %{
        input_type: :analog,
        sensor: :mt6701,
        i2c_address: 0x46,
        sensitivity: 5
      })

    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
    send(view.pid, {:devices_updated, [connected(device.config_id)]})

    send(view.pid, {:i2c_module_failed, @port, 0x46, true})
    assert has_element?(view, "#input-not-responding-#{input.id}", "Not responding")
    assert render(view) =~ "The MT6701 at 0x46 did not answer"
    assert render(view) =~ "set to 0x46 with the setup sketch"

    send(view.pid, {:input_value_updated, @port, input.pin, 4096})
    refute has_element?(view, "#input-not-responding-#{input.id}")
    assert has_element?(view, "#inputs td", "90.00°")
  end

  test "a module error from another controller is ignored", %{conn: conn, device: device} do
    {:ok, input} =
      Hardware.create_input(device.id, %{
        input_type: :analog,
        sensor: :mt6701,
        i2c_address: 0x06,
        sensitivity: 5
      })

    {:ok, view, _} = live(conn, ~p"/configurations/#{device.config_id}")
    send(view.pid, {:devices_updated, [connected(device.config_id)]})
    send(view.pid, {:i2c_module_failed, "/dev/other", 0x06, true})

    refute has_element?(view, "#input-not-responding-#{input.id}")
  end
end
