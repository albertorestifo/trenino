defmodule Trenino.MCP.Tools.GaugeToolsTest do
  use Trenino.DataCase, async: true

  import Trenino.GaugeFixtures

  alias Trenino.Hardware
  alias Trenino.MCP.Tools.GaugeTools
  alias Trenino.Serial.Protocol.{SetGaugePosition, ZeroGauge}

  setup do
    {:ok, device} = Hardware.create_device(%{name: "Gauge board"})
    %{device: device}
  end

  test "lists the seven gauge tools" do
    assert Enum.map(GaugeTools.tools(), & &1.name) ==
             ~w(list_gauges create_gauge update_gauge delete_gauge apply_device_configuration move_gauge zero_gauge)
  end

  test "creates, lists, updates and deletes a gauge", %{device: device} do
    assert {:ok, %{gauge: gauge, next_steps: _}} =
             GaugeTools.execute("create_gauge", %{
               "device_id" => device.id,
               "name" => "Speed",
               "pins" => [8, 7, 6, 255]
             })

    assert %{driver: :vid6606, travel: 3780, pins: [8, 7, 6, 255], dial: nil} = gauge
    assert {:ok, _} = Jason.encode(gauge)

    assert {:ok, %{gauges: [%{id: id}]}} =
             GaugeTools.execute("list_gauges", %{"device_id" => device.id})

    assert {:ok, %{gauge: %{reverse: true}}} =
             GaugeTools.execute("update_gauge", %{"id" => id, "reverse" => true})

    assert {:ok, %{deleted: true}} = GaugeTools.execute("delete_gauge", %{"id" => id})
    assert {:ok, %{gauges: []}} = GaugeTools.execute("list_gauges", %{"device_id" => device.id})
  end

  test "reports validation errors as JSON", %{device: device} do
    assert {:error, message} =
             GaugeTools.execute("create_gauge", %{
               "device_id" => device.id,
               "name" => "Bad",
               "pins" => [8, 8, 6, 255]
             })

    assert message =~ "pins"
  end

  test "move_gauge sends the position once the device runs the configuration", %{device: device} do
    gauge = gauge_fixture(device.id)
    test_pid = self()

    Mimic.stub(Hardware, :gauge_link, fn _ -> {:ok, "COM3"} end)

    Mimic.stub(Trenino.Serial.Connection, :send_message, fn port, message ->
      send(test_pid, {:sent, port, message})
      :ok
    end)

    assert {:ok, %{sent: true, position: 3780}} =
             GaugeTools.execute("move_gauge", %{"id" => gauge.id, "position" => 9999})

    assert_receive {:sent, "COM3", %SetGaugePosition{pin: 8, position: 3780}}

    assert {:ok, %{sent: true}} = GaugeTools.execute("zero_gauge", %{"id" => gauge.id})
    assert_receive {:sent, "COM3", %ZeroGauge{pin: 8}}

    assert {:ok, %{released: true}} =
             GaugeTools.execute("move_gauge", %{"id" => gauge.id, "release" => true})
  end

  test "move_gauge without a position says what to pass", %{device: device} do
    gauge = gauge_fixture(device.id)
    assert {:error, message} = GaugeTools.execute("move_gauge", %{"id" => gauge.id})
    assert message =~ "position"
  end

  test "move_gauge explains why it cannot move", %{device: device} do
    gauge = gauge_fixture(device.id)
    Mimic.stub(Hardware, :gauge_link, fn _ -> {:error, :needs_apply} end)

    assert {:error, message} =
             GaugeTools.execute("move_gauge", %{"id" => gauge.id, "position" => 100})

    assert message =~ "apply_device_configuration"
  end
end
