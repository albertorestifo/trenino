defmodule Trenino.Train.OutputControllerRuntimeTest do
  use Trenino.DataCase, async: false

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Simulator
  alias Trenino.Simulator.{Client, ConnectionState, Watcher}
  alias Trenino.Train
  alias Trenino.Train.OutputController

  setup :set_mimic_global

  @endpoint "CurrentDrivableActor/PassengerDoor_FL.Function.GetNormalisedOutputValue"
  @connected %ConnectionState{
    status: :connected,
    client: %Client{base_url: "http://fake", api_key: "fake"}
  }

  setup do
    owner = self()

    Mimic.stub(Simulator, :read, fn paths ->
      send(owner, {:read, paths})
      {:ok, Map.new(paths, &{&1, 1.0})}
    end)

    Mimic.stub(ConfigurationManager, :config_id_to_port, fn _ -> "COM1" end)

    Mimic.stub(Hardware, :set_output, fn port, pin, value ->
      send(owner, {:output, port, pin, value})
      :ok
    end)

    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, output} = Hardware.create_output(device.id, %{pin: 7, name: "Door LED"})

    {:ok, train} =
      Train.create_train(%{name: "Train", identifiers: [%{identifier: "OutputRuntimeTest"}]})

    {:ok, _} =
      Train.create_output_binding(train.id, %{
        output_id: output.id,
        name: "Left doors open",
        endpoint: @endpoint,
        operator: :gt,
        value_a: 0.0,
        enabled: true
      })

    %{train: train}
  end

  defp start_watcher(status) do
    Mimic.stub(Trenino.Simulator.Connection, :get_status, fn -> status end)
    start_supervised!(Watcher)
  end

  test "values from the watcher light the LED", %{train: train} do
    start_watcher(@connected)
    pid = start_supervised!(OutputController)
    send(pid, {:train_changed, train})

    assert_receive {:read, [@endpoint]}, 500
    assert_receive {:output, "COM1", 7, :high}, 500
  end

  test "an endpoint the simulator cannot read leaves the LED off until it can", %{train: train} do
    Mimic.stub(Simulator, :read, fn _ -> {:ok, %{}} end)
    start_watcher(@connected)
    pid = start_supervised!(OutputController)
    send(pid, {:train_changed, train})
    refute_receive {:output, _, _, :high}, 400

    Mimic.stub(Simulator, :read, fn paths -> {:ok, Map.new(paths, &{&1, 1.0})} end)
    assert_receive {:output, "COM1", 7, :high}, 500
  end

  test "bindings load while the simulator is offline and light once it connects", %{
    train: train
  } do
    watcher = start_watcher(%ConnectionState{status: :disconnected, client: nil})
    pid = start_supervised!(OutputController)
    send(pid, {:train_changed, train})
    refute_receive {:read, _}, 300

    send(watcher, {:simulator_status_changed, @connected})
    send(pid, {:simulator_status_changed, @connected})
    assert_receive {:output, "COM1", 7, :high}, 500
  end

  test "a simulator disconnect switches lit outputs off", %{train: train} do
    start_watcher(@connected)
    pid = start_supervised!(OutputController)
    send(pid, {:train_changed, train})
    assert_receive {:output, "COM1", 7, :high}, 500

    send(pid, {:simulator_status_changed, %ConnectionState{status: :disconnected}})
    assert_receive {:output, "COM1", 7, :low}, 500
  end

  test "endpoints are watched again after the watcher restarts", %{train: train} do
    pid = start_supervised!(OutputController)
    send(pid, {:train_changed, train})
    refute_receive {:output, _, _, :high}, 200

    start_watcher(@connected)
    assert_receive {:output, "COM1", 7, :high}, 500
  end

  test "values the controller receives are rounded before comparison", %{train: train} do
    pid = start_supervised!(OutputController)
    send(pid, {:train_changed, train})
    send(pid, {:simulator_values, %{@endpoint => 0.004}})
    refute_receive {:output, _, _, :high}, 200
    send(pid, {:simulator_values, %{@endpoint => 0.005}})
    assert_receive {:output, "COM1", 7, :high}, 200
  end
end
