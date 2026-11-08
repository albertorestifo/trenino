defmodule Trenino.Hardware.GaugesTest do
  use Trenino.DataCase, async: true

  import Trenino.GaugeFixtures

  alias Trenino.Hardware
  alias Trenino.Hardware.Gauge
  alias Trenino.Serial.Protocol.{SetGaugePosition, ZeroGauge}

  setup do
    {:ok, device} = Hardware.create_device(%{name: "Gauge board"})
    %{device: device}
  end

  describe "create_gauge/2" do
    test "fills the driver defaults", %{device: device} do
      assert {:ok, %Gauge{travel: 3780, max_speed: 5000, acceleration: 50_000}} =
               Hardware.create_gauge(device.id, %{name: "A", pins: [8, 7, 6, 255]})

      assert {:ok, %Gauge{driver: :direct, travel: 945, max_speed: 1800, acceleration: 1500}} =
               Hardware.create_gauge(device.id, %{
                 "name" => "Direct",
                 "driver" => "direct",
                 "pins" => [18, 19, 10, 15]
               })
    end

    test "validates ranges per driver", %{device: device} do
      assert {:error, cs} =
               Hardware.create_gauge(device.id, %{
                 name: "Fast",
                 driver: :direct,
                 pins: [4, 5, 6, 7],
                 max_speed: 2000
               })

      assert %{max_speed: [_]} = errors_on(cs)

      assert {:error, cs} =
               Hardware.create_gauge(device.id, %{
                 name: "Long",
                 pins: [8, 7, 6, 255],
                 travel: 4001
               })

      assert %{travel: [_]} = errors_on(cs)
    end

    test "validates the pin layout", %{device: device} do
      for pins <- [[8, 8, 6, 255], [8, 7, 6, 9], [8, 255, 6, 255], [8, 7, 6]] do
        assert {:error, cs} = Hardware.create_gauge(device.id, %{name: "G", pins: pins})
        assert %{pins: [_ | _]} = errors_on(cs), "expected #{inspect(pins)} to be rejected"
      end

      assert {:ok, %Gauge{}} =
               Hardware.create_gauge(device.id, %{name: "No reset", pins: [8, 7, 255, 255]})
    end

    test "gauges on one VID6606 share RESET_N but nothing else", %{device: device} do
      gauge_fixture(device.id, %{name: "A", pins: [8, 7, 6, 255]})

      assert {:ok, _} = Hardware.create_gauge(device.id, %{name: "B", pins: [14, 16, 6, 255]})

      assert {:error, cs} = Hardware.create_gauge(device.id, %{name: "C", pins: [8, 20, 6, 255]})
      assert %{pins: ["pin 8 is used by another gauge"]} = errors_on(cs)

      # A gauge's STEP may not be another gauge's RESET_N.
      assert {:error, cs} = Hardware.create_gauge(device.id, %{name: "D", pins: [6, 20, 9, 255]})
      assert %{pins: ["pin 6 is used by another gauge"]} = errors_on(cs)

      # Nor may its RESET_N be another gauge's STEP or DIR.
      assert {:error, cs} = Hardware.create_gauge(device.id, %{name: "E", pins: [21, 20, 7, 255]})
      assert %{pins: ["pin 7 is used by another gauge"]} = errors_on(cs)
    end

    test "rejects pins used by inputs and outputs", %{device: device} do
      {:ok, _} = Hardware.create_input(device.id, %{pin: 8, input_type: :button, debounce: 20})
      {:ok, _} = Hardware.create_output(device.id, %{pin: 4, name: "Lamp"})

      assert {:error, cs} = Hardware.create_gauge(device.id, %{name: "A", pins: [8, 7, 6, 255]})
      assert %{pins: ["pin 8 is used by an input"]} = errors_on(cs)

      assert {:error, cs} = Hardware.create_gauge(device.id, %{name: "D", pins: [5, 4, 6, 255]})
      assert %{pins: ["pin 4 is used by an output"]} = errors_on(cs)
    end

    test "allows at most four gauges per device", %{device: device} do
      for {pins, i} <-
            Enum.with_index([[8, 7, 6, 255], [14, 16, 6, 255], [21, 20, 6, 255], [5, 4, 6, 255]]) do
        gauge_fixture(device.id, %{name: "G#{i}", pins: pins})
      end

      assert {:error, cs} =
               Hardware.create_gauge(device.id, %{name: "Fifth", pins: [9, 10, 255, 255]})

      assert %{device_id: [_]} = errors_on(cs)
    end

    test "a blank required pin is reported as missing", %{device: device} do
      assert {:error, cs} = Hardware.create_gauge(device.id, %{name: "G", pins: [8, nil, 6, 255]})
      assert %{pins: ["are missing a required pin"]} = errors_on(cs)
    end

    test "switching driver on update moves untouched defaults to the new driver's", %{
      device: device
    } do
      gauge = gauge_fixture(device.id)

      assert {:ok, %Gauge{driver: :direct, travel: 945, max_speed: 1800, acceleration: 1500}} =
               Hardware.update_gauge(gauge, %{"driver" => "direct", "pins" => [4, 5, 9, 10]})

      tuned = gauge_fixture(device.id, %{name: "Tuned", pins: [14, 16, 6, 255], max_speed: 1000})

      assert {:ok, %Gauge{max_speed: 1000, travel: 945}} =
               Hardware.update_gauge(tuned, %{driver: :direct, pins: [18, 19, 20, 21]})
    end

    test "editing a gauge does not clash with itself", %{device: device} do
      gauge = gauge_fixture(device.id)
      assert {:ok, %Gauge{name: "Renamed"}} = Hardware.update_gauge(gauge, %{name: "Renamed"})
    end
  end

  describe "gauge_link/1" do
    test "is not connected when no device runs the configuration", %{device: device} do
      Mimic.stub(Trenino.Serial.Connection, :list_devices, fn -> [] end)
      assert {:error, :device_not_connected} = Hardware.gauge_link(device.id)
    end

    test "needs firmware 3.3.0 and the applied configuration", %{device: device} do
      gauge_fixture(device.id)

      connected = fn version ->
        Mimic.stub(Trenino.Serial.Connection, :list_devices, fn ->
          [
            %{
              port: "COM3",
              status: :connected,
              device_config_id: device.config_id,
              device_version: version
            }
          ]
        end)
      end

      connected.("3.2.1")
      assert {:error, :firmware_update_required} = Hardware.gauge_link(device.id)

      connected.("3.3.0")
      assert {:error, :needs_apply} = Hardware.gauge_link(device.id)

      {:ok, _} =
        Hardware.confirm_configuration(
          device.id,
          device.config_id,
          Hardware.device_fingerprint(device.id)
        )

      assert {:ok, "COM3"} = Hardware.gauge_link(device.id)
    end
  end

  test "set_gauge_position/3 clamps to travel and addresses the first pin", %{device: device} do
    gauge = gauge_fixture(device.id)
    test_pid = self()

    Mimic.stub(Trenino.Serial.Connection, :send_message, fn port, message ->
      send(test_pid, {:sent, port, message})
      :ok
    end)

    assert :ok = Hardware.set_gauge_position("COM3", gauge, 5000)
    assert_receive {:sent, "COM3", %SetGaugePosition{pin: 8, position: 3780}}

    assert :ok = Hardware.set_gauge_position("COM3", gauge, -5)
    assert_receive {:sent, "COM3", %SetGaugePosition{pin: 8, position: 0}}

    assert :ok = Hardware.zero_gauge("COM3", gauge)
    assert_receive {:sent, "COM3", %ZeroGauge{pin: 8}}
  end

  test "deleting a device deletes its gauges", %{device: device} do
    gauge = calibrated_gauge_fixture(device.id)
    {:ok, _} = Hardware.delete_device(device)
    assert {:error, :not_found} = Hardware.get_gauge(gauge.id)
    assert {:error, :not_found} = Hardware.get_dial_calibration(gauge.id)
  end
end
