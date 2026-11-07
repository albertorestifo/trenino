defmodule Trenino.Train.OutputControllerRuntimeTest do
  use Trenino.DataCase, async: false

  alias Trenino.Hardware
  alias Trenino.Hardware.ConfigurationManager
  alias Trenino.Simulator.{Client, ConnectionState}
  alias Trenino.Train
  alias Trenino.Train.OutputController

  setup :set_mimic_global

  @endpoint "CurrentDrivableActor/PassengerDoor_FL.Function.GetNormalisedOutputValue"

  setup do
    owner = self()
    client = %Client{base_url: "http://fake", api_key: "fake"}

    Mimic.stub(Trenino.Simulator.Connection, :get_status, fn ->
      %ConnectionState{status: :connected, client: client}
    end)

    Mimic.stub(Client, :unsubscribe, fn _, id ->
      send(owner, {:unsubscribed, id})
      {:error, {:http_error, 400, %{"errorCode" => "dtg.comm.NoSuchSubscription"}}}
    end)

    Mimic.stub(Client, :subscribe, fn _, endpoint, id ->
      send(owner, {:subscribed, endpoint, id})
      {:ok, %{}}
    end)

    Mimic.stub(Client, :get_subscription, fn _, _ -> door_value(1.0) end)
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

  defp door_value(value),
    do:
      {:ok,
       %{
         "Entries" => [
           %{"NodeValid" => true, "Values" => %{"ReturnValue" => value}}
         ]
       }}

  test "a subscribe that fails at train load is retried until the LED lights", %{train: train} do
    owner = self()
    counter = start_supervised!({Agent, fn -> 0 end}, id: :subscribe_counter)

    Mimic.stub(Client, :subscribe, fn _, endpoint, id ->
      attempt = Agent.get_and_update(counter, &{&1, &1 + 1})
      send(owner, {:subscribe_attempt, endpoint, id})

      if attempt == 0,
        do: {:error, %Req.TransportError{reason: :closed}},
        else: {:ok, %{}}
    end)

    pid = start_supervised!(OutputController)
    send(pid, {:train_changed, train})

    assert_receive {:subscribe_attempt, @endpoint, 1000}, 500
    refute_receive {:output, _, _, :high}, 300
    assert_receive {:subscribe_attempt, @endpoint, 1000}, 1500
    assert_receive {:output, "COM1", 7, :high}, 500
  end

  test "a stale subscription ID is cleared before subscribing", %{train: train} do
    pid = start_supervised!(OutputController)
    send(pid, {:train_changed, train})

    assert_receive {:unsubscribed, 1000}, 500
    assert_receive {:subscribed, @endpoint, 1000}, 500
  end

  test "a subscription the simulator lost is resubscribed", %{train: train} do
    pid = start_supervised!(OutputController)
    send(pid, {:train_changed, train})
    assert_receive {:subscribed, @endpoint, 1000}, 500
    assert_receive {:output, "COM1", 7, :high}, 500

    Mimic.stub(Client, :get_subscription, fn _, _ ->
      {:error, {:http_error, 400, %{"errorCode" => "dtg.comm.NoSuchSubscription"}}}
    end)

    refute_receive {:subscribed, _, _}, 300
    Mimic.stub(Client, :get_subscription, fn _, _ -> door_value(1.0) end)
    assert_receive {:subscribed, @endpoint, 1000}, 1500
  end

  test "bindings load while the simulator is offline and subscribe once it connects", %{
    train: train
  } do
    Mimic.stub(Trenino.Simulator.Connection, :get_status, fn ->
      %ConnectionState{status: :disconnected, client: nil}
    end)

    pid = start_supervised!(OutputController)
    send(pid, {:train_changed, train})
    refute_receive {:subscribed, _, _}, 300

    client = %Client{base_url: "http://fake", api_key: "fake"}
    connected = %ConnectionState{status: :connected, client: client}
    Mimic.stub(Trenino.Simulator.Connection, :get_status, fn -> connected end)
    send(pid, {:simulator_status_changed, connected})

    assert_receive {:subscribed, @endpoint, 1000}, 500
    assert_receive {:output, "COM1", 7, :high}, 500
  end

  test "a simulator disconnect switches lit outputs off", %{train: train} do
    pid = start_supervised!(OutputController)
    send(pid, {:train_changed, train})
    assert_receive {:output, "COM1", 7, :high}, 500

    send(pid, {:simulator_status_changed, %ConnectionState{status: :disconnected}})
    assert_receive {:output, "COM1", 7, :low}, 500
  end
end
