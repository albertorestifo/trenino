defmodule Trenino.Train.LeverControllerTest do
  # Shared sandbox: the controller process needs Sandbox.allow/3.
  use Trenino.DataCase, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias Trenino.Hardware
  alias Trenino.Serial.Connection.DeviceConnection
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.LeverController

  @endpoint "CurrentDrivableActor/Throttle(Lever).InputValue"
  setup :set_mimic_global

  setup do
    test_pid = self()

    Mimic.stub(Trenino.Serial.Connection, :list_devices, fn ->
      send(test_pid, {:list_devices_called, self()})

      receive do
        {:devices, devices} -> devices
      after
        1_000 -> []
      end
    end)

    Mimic.stub(Trenino.Serial.Connection, :subscribe, fn -> :ok end)

    {:ok, controller} = start_supervised(LeverController)
    assert_receive {:list_devices_called, ^controller}, 1_000
    send(controller, {:devices, []})

    Sandbox.allow(Trenino.Repo, self(), controller)

    :ok
  end

  describe "smooth lever updates" do
    setup %{test: test} do
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Latency Train",
          identifiers: [%{identifier: "latency_train_#{System.unique_integer([:positive])}"}]
        })

      {:ok, element} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      {:ok, lever_config} =
        TrainContext.create_lever_config(element.id, %{
          min_endpoint: "CurrentDrivableActor/Throttle(Lever).Min",
          max_endpoint: "CurrentDrivableActor/Throttle(Lever).Max",
          value_endpoint: @endpoint,
          lever_type: :continuous
        })

      {:ok, _notch} =
        TrainContext.create_notch(lever_config.id, %{
          index: 0,
          type: :linear,
          input_min: 0.0,
          input_max: 1.0,
          sim_input_min: 0.0,
          sim_input_max: 1.0,
          min_value: 0.0,
          max_value: 1.0
        })

      {:ok, device} = Hardware.create_device(%{name: "Pro Micro #{test}"})

      {:ok, input} =
        Hardware.create_input(device.id, %{
          pin: 2,
          input_type: :analog,
          sensitivity: 1,
          name: "Throttle pot"
        })

      {:ok, _calibration} =
        Hardware.save_calibration(input.id, %{
          max_hardware_value: 1023,
          min_value: 0,
          max_value: 1000,
          has_rollover: false,
          is_inverted: false
        })

      {:ok, _binding} = TrainContext.bind_input(lever_config.id, input.id)

      device_conn = %DeviceConnection{
        port: "/dev/cu.usbmodem#{System.unique_integer([:positive])}",
        status: :connected,
        device_config_id: device.config_id
      }

      send(Process.whereis(LeverController), {:train_changed, train})
      send(Process.whereis(LeverController), {:devices_updated, [device_conn]})
      assert_receive {:list_devices_called, controller}, 1_000
      send(controller, {:devices, [device_conn]})

      %{port: device_conn.port, pin: input.pin}
    end

    test "sends the latest jittered value instead of draining a FIFO of stale writes", %{
      port: port,
      pin: pin
    } do
      test_pid = self()
      client = %Client{base_url: "http://localhost:31270", api_key: "test"}

      Mimic.stub(Trenino.Simulator.Connection, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      Mimic.stub(Client, :set, fn ^client, @endpoint, value ->
        send(test_pid, {:set_started, value, self()})

        receive do
          :release_set -> {:ok, %{"Result" => "Success"}}
        after
          2_000 -> {:error, :timeout}
        end
      end)

      controller = Process.whereis(LeverController)

      # First sample blocks inside the slow simulator write.
      send(controller, {:input_value_updated, port, pin, 100})
      assert_receive {:set_started, 0.1, writer}, 1_000

      # Jitter arrives while that write is in flight. A FIFO would later send
      # every intermediate sample; the controller must keep only the latest.
      for raw <- [200, 400, 600, 800] do
        send(controller, {:input_value_updated, port, pin, raw})
      end

      send(writer, :release_set)
      assert_receive {:set_started, 0.8, writer}, 1_000
      send(writer, :release_set)

      refute_receive {:set_started, _}, 100
    end

    test "retries the current value when the simulator write fails", %{port: port, pin: pin} do
      test_pid = self()
      client = %Client{base_url: "http://localhost:31270", api_key: "test"}

      Mimic.stub(Trenino.Simulator.Connection, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      Mimic.stub(Client, :set, fn ^client, @endpoint, value ->
        send(test_pid, {:set_started, value, self()})
        receive do: (:release_set -> {:error, :disconnected})
      end)

      controller = Process.whereis(LeverController)
      send(controller, {:input_value_updated, port, pin, 500})
      assert_receive {:set_started, 0.5, writer}, 1_000

      send(writer, :release_set)
      assert_receive {:set_started, 0.5, writer}, 1_000
      send(writer, :release_set)
    end
  end
end
