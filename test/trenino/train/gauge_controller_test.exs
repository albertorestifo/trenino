defmodule Trenino.Train.GaugeControllerTest do
  use Trenino.DataCase, async: false
  alias Trenino.Hardware
  alias Trenino.Hardware.StepperManager
  alias Trenino.Simulator.{Client, ConnectionState}
  alias Trenino.Train
  alias Trenino.Train.GaugeController
  setup :set_mimic_global

  setup do
    owner = self()
    client = %Client{base_url: "http://fake", api_key: "fake"}

    Mimic.stub(Trenino.Simulator.Connection, :get_status, fn ->
      %ConnectionState{status: :connected, client: client}
    end)

    Mimic.stub(Client, :subscribe, fn _, endpoint, id ->
      send(owner, {:subscribed, endpoint, id})
      {:ok, %{}}
    end)

    Mimic.stub(Client, :unsubscribe, fn _, id ->
      send(owner, {:unsubscribed, id})
      {:ok, %{}}
    end)

    Mimic.stub(Client, :get_subscription, fn _, _ ->
      {:ok, %{"Entries" => [%{"NodeValid" => true, "Values" => %{"Speed" => 50}}]}}
    end)

    Mimic.stub(StepperManager, :set_target, fn id, target, train ->
      send(owner, {:target, id, target, train})
      :ok
    end)

    Mimic.stub(StepperManager, :inactive, fn id, behavior ->
      send(owner, {:inactive, id, behavior})
      :ok
    end)

    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, axis} = Hardware.create_stepper_axis(device.id, %{name: "Speed", commissioned: true})
    {:ok, train} = Train.create_train(%{name: "Train", identifiers: [%{identifier: "GaugeTest"}]})

    attrs = %{
      stepper_axis_id: axis.id,
      name: "Speed",
      endpoint: "Speed",
      enabled: true,
      calibration_reviewed: true,
      points: [%{value: 0, position: 0}, %{value: 100, position: 720}],
      stale_after_ms: 500
    }

    {:ok, binding} = Train.create_gauge_binding(train.id, attrs)
    %{axis: axis, train: train, binding: binding}
  end

  test "timed out HTTP poll cleans subscriptions and resumes fresh polling", %{train: train} do
    owner = self()
    counter = start_supervised!({Agent, fn -> 0 end})

    Mimic.stub(Client, :get_subscription, fn _, _ ->
      attempt = Agent.get_and_update(counter, &{&1, &1 + 1})

      if attempt == 0 do
        send(owner, :poll_blocked)

        receive do
          :never -> {:error, :cancelled}
        end
      else
        {:ok, %{"Entries" => [%{"NodeValid" => true, "Values" => %{"Speed" => 50}}]}}
      end
    end)

    pid = start_supervised!(GaugeController)
    send(pid, {:train_changed, train})
    assert_receive :poll_blocked, 500
    state = :sys.get_state(pid)
    send(pid, {:poll_timeout, state.task.ref})
    assert_receive {:unsubscribed, 4000}, 500
    assert_receive {:target, _, 360, _}, 700
  end

  test "stale input applies inactive policy once without inventing zero", %{
    train: train,
    binding: b
  } do
    pid = start_supervised!(GaugeController)
    send(pid, {:train_changed, train})
    assert_receive {:target, _, 360, _}, 500
    Mimic.stub(Client, :get_subscription, fn _, _ -> {:error, :offline} end)

    :sys.replace_state(pid, fn s ->
      put_in(s.status[b.id].received_at, System.monotonic_time(:millisecond) - 1000)
    end)

    send(pid, {:poll, :sys.get_state(pid).generation})
    assert_receive {:inactive, _, :hold}, 500
    refute_receive {:inactive, _, _}, 300
    refute_receive {:target, _, 0, _}, 20
  end

  test "cleanup rejection blocks ID reuse and retries safely", %{train: train} do
    owner = self()
    counter = start_supervised!({Agent, fn -> 0 end})

    Mimic.stub(Client, :unsubscribe, fn _, _ ->
      if Agent.get_and_update(counter, &{&1, &1 + 1}) == 0,
        do: {:error, :offline},
        else: {:ok, %{}}
    end)

    pid = start_supervised!(GaugeController)
    send(pid, {:train_changed, train})
    assert_receive {:target, _, _, _}, 500
    assert_receive {:subscribed, _, _}, 100
    send(pid, {:train_changed, train})
    refute_receive {:subscribed, _, _}, 400
    assert_receive {:subscribed, "Speed", 4000}, 1000
    send(owner, :cleanup_retried)
  end

  test "single numeric value selection is strict and never arbitrarily chooses a key" do
    data = fn values -> {:ok, %{"Entries" => [%{"NodeValid" => true, "Values" => values}]}} end
    assert {:ok, 3} = GaugeController.sample(data.(%{"Speed" => 3}), nil)
    assert {:ok, 4} = GaugeController.sample(data.(%{"Speed" => 3, "Other" => 4}), "Other")
    assert {:error, _} = GaugeController.sample(data.(%{"Speed" => 3, "Other" => 4}), nil)

    for value <- [nil, "3", false, %{}],
        do: assert({:error, _} = GaugeController.sample(data.(%{"Speed" => value}), nil))

    assert {:error, _} = GaugeController.sample({:ok, %{"Entries" => []}}, nil)

    assert {:error, _} =
             GaugeController.sample(
               {:ok, %{"Entries" => [%{"NodeValid" => false, "Values" => %{"Speed" => 1}}]}},
               nil
             )
  end

  test "fresh samples map targets and deactivation applies outgoing policy", %{
    train: train,
    axis: axis
  } do
    pid = start_supervised!(GaugeController)
    send(pid, {:train_changed, train})
    assert_receive {:subscribed, "Speed", 4000}, 500
    assert_receive {:target, id, 360, train_id}, 500
    assert id == axis.id and train_id == train.id
    send(pid, {:train_changed, nil})
    assert_receive {:inactive, ^id, :hold}, 200
    assert_receive {:unsubscribed, 4000}, 200
    refute_receive {:target, _, _, _}, 250
  end

  test "slow HTTP cannot block train switch and old completion cannot move", %{
    train: train,
    axis: axis
  } do
    owner = self()

    Mimic.stub(Client, :get_subscription, fn _, _ ->
      send(owner, {:poll_entered, self()})

      receive do
        :continue ->
          {:ok, %{"Entries" => [%{"NodeValid" => true, "Values" => %{"Speed" => 100}}]}}
      end
    end)

    pid = start_supervised!(GaugeController)
    send(pid, {:train_changed, train})
    assert_receive {:poll_entered, worker}, 500
    old = :sys.get_state(pid)
    send(pid, {:train_changed, nil})
    assert_receive {:inactive, id, :hold}, 200
    assert id == axis.id
    send(worker, :continue)
    send(pid, {old.task.ref, {old.generation, %{subscriptions: %{}, values: %{}, retries: %{}}}})
    refute_receive {:target, _, _, _}, 250
    assert GaugeController.snapshot(train.id) == %{}
  end

  test "subscription cleanup completes before identifiers can be reused", %{train: train} do
    owner = self()

    Mimic.stub(Client, :unsubscribe, fn _, id ->
      send(owner, {:cleanup_waiting, self(), id})

      receive do
        :complete_cleanup -> {:ok, %{}}
      end
    end)

    pid = start_supervised!(GaugeController)
    send(pid, {:train_changed, train})
    assert_receive {:target, _, _, _}, 500
    assert_receive {:subscribed, "Speed", 4000}, 100
    send(pid, {:train_changed, train})
    assert_receive {:cleanup_waiting, cleanup, 4000}, 200
    refute_receive {:subscribed, _, _}, 250
    send(cleanup, :complete_cleanup)
    assert_receive {:subscribed, "Speed", 4000}, 500
  end

  test "failed subscriptions back off instead of retrying every tick", %{train: train} do
    owner = self()

    Mimic.stub(Client, :subscribe, fn _, _, _ ->
      send(owner, :subscribe_failed)
      {:error, :offline}
    end)

    pid = start_supervised!(GaugeController)
    send(pid, {:train_changed, train})
    assert_receive :subscribe_failed, 500
    refute_receive :subscribe_failed, 600
    assert_receive :subscribe_failed, 700
  end
end
