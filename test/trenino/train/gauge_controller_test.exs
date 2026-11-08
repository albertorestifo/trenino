defmodule Trenino.Train.GaugeControllerTest do
  use Trenino.DataCase, async: false
  import Trenino.GaugeFixtures
  alias Trenino.Hardware
  alias Trenino.Simulator.{Client, ConnectionState}
  alias Trenino.Train
  alias Trenino.Train.GaugeController
  setup :set_mimic_global

  # The calibrated fixture maps value 0 to step 0 and value 100 to step 1890.
  @half 945
  @full 1890

  defp sample(value),
    do: {:ok, %{"Entries" => [%{"NodeValid" => true, "Values" => %{"Speed" => value}}]}}

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

    Mimic.stub(Client, :get_subscription, fn _, _ -> sample(50) end)

    Mimic.stub(Hardware, :gauge_link, fn device_id ->
      send(owner, {:link, device_id})
      {:ok, "/dev/gauges"}
    end)

    Mimic.stub(Hardware, :set_gauge_position, fn port, gauge, target ->
      send(owner, {:target, port, gauge.id, target})
      :ok
    end)

    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    gauge = calibrated_gauge_fixture(device.id)
    {:ok, train} = Train.create_train(%{name: "Train", identifiers: [%{identifier: "GaugeTest"}]})

    attrs = %{
      gauge_id: gauge.id,
      name: "Speed",
      endpoint: "Speed",
      enabled: true,
      stale_after_ms: 500
    }

    {:ok, binding} = Train.create_gauge_binding(train.id, attrs)
    %{device: device, gauge: gauge, train: train, binding: binding}
  end

  defp start_controller(train) do
    pid = start_supervised!(GaugeController)
    send(pid, {:train_changed, train})
    pid
  end

  test "fresh samples send the mapped position to the gauge's port", %{
    train: train,
    gauge: gauge,
    device: device
  } do
    start_controller(train)
    assert_receive {:subscribed, "Speed", 4000}, 500
    assert_receive {:link, device_id}, 500
    assert device_id == device.id
    assert_receive {:target, "/dev/gauges", gauge_id, @half}, 500
    assert gauge_id == gauge.id
  end

  test "the link is looked up once per device, not on every send", %{train: train} do
    pid = start_controller(train)
    assert_receive {:target, _, _, @half}, 500
    assert_receive {:link, _}

    # Past the refresh window the target is resent through the cached link.
    :sys.replace_state(pid, fn s ->
      Map.update!(s, :sent, fn sent ->
        Map.new(sent, fn {id, entry} -> {id, %{entry | at: entry.at - 5000}} end)
      end)
    end)

    assert_receive {:target, _, _, @half}, 500
    refute_received {:link, _}
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
        sample(50)
      end
    end)

    pid = start_controller(train)
    assert_receive :poll_blocked, 500
    state = :sys.get_state(pid)
    send(pid, {:poll_timeout, state.task.ref})
    assert_receive {:unsubscribed, 4000}, 500
    assert_receive {:target, _, _, @half}, 700
  end

  test "an unchanged target is not resent every poll, only after the refresh window", %{
    train: train,
    binding: b
  } do
    pid = start_controller(train)
    assert_receive {:target, _, _, @half}, 500
    # Several 200 ms polls of the same sample go by without another command.
    refute_receive {:target, _, _, _}, 700

    :sys.replace_state(pid, fn s ->
      put_in(s.sent[b.id].at, System.monotonic_time(:millisecond) - 5000)
    end)

    assert_receive {:target, _, _, @half}, 500
  end

  test "a changed target is sent immediately", %{train: train} do
    counter = start_supervised!({Agent, fn -> 50 end})
    Mimic.stub(Client, :get_subscription, fn _, _ -> sample(Agent.get(counter, & &1)) end)

    pid = start_controller(train)
    assert_receive {:target, _, _, @half}, 500
    Agent.update(counter, fn _ -> 100 end)
    assert_receive {:target, _, _, @full}, 500
    assert Process.alive?(pid)
  end

  test "an applied configuration re-zeros the gauges, so the link is refreshed and the target resent",
       %{train: train, device: device} do
    pid = start_controller(train)
    assert_receive {:link, _}, 500
    assert_receive {:target, _, _, @half}, 500
    refute_receive {:target, _, _, _}, 300

    send(pid, {:configuration_applied, "/dev/gauges", device, 7})
    assert_receive {:link, _}, 500
    assert_receive {:target, _, _, @half}, 500
  end

  test "a device list change refreshes the link and resends the target", %{train: train} do
    pid = start_controller(train)
    assert_receive {:link, _}, 500
    assert_receive {:target, _, _, @half}, 500
    refute_receive {:target, _, _, _}, 300

    send(pid, {:devices_updated, []})
    assert_receive {:link, _}, 500
    assert_receive {:target, _, _, @half}, 500
  end

  test "a link error is reported as the binding's failure and clears once the device is applied",
       %{train: train, binding: b, device: device} do
    owner = self()

    Mimic.stub(Hardware, :gauge_link, fn device_id ->
      send(owner, {:link, device_id})
      {:error, :needs_apply}
    end)

    GaugeController.subscribe(train.id)
    pid = start_controller(train)
    id = b.id

    assert_receive {:gauge_binding_updated, ^id, %{failure: :needs_apply, target: @half}}, 500
    refute_received {:target, _, _, _}

    # A failed link is cached too: the next polls do not look it up again.
    assert_receive {:gauge_binding_updated, ^id, %{failure: :needs_apply}}, 500
    assert_receive {:link, _}
    refute_received {:link, _}

    Mimic.stub(Hardware, :gauge_link, fn _ -> {:ok, "/dev/gauges"} end)
    send(pid, {:configuration_applied, "/dev/gauges", device, 1})
    assert_receive {:target, _, _, @half}, 500
    assert_receive {:gauge_binding_updated, ^id, %{failure: nil}}, 500
  end

  test "a rejected send is retried on the next sample and reported", %{train: train, binding: b} do
    owner = self()

    Mimic.stub(Hardware, :set_gauge_position, fn _, _, target ->
      send(owner, {:target_attempt, target})
      {:error, :not_connected}
    end)

    GaugeController.subscribe(train.id)
    pid = start_controller(train)
    id = b.id
    assert_receive {:target_attempt, @half}, 500
    assert_receive {:target_attempt, @half}, 500
    assert_receive {:gauge_binding_updated, ^id, %{failure: :not_connected}}, 500
    assert Process.alive?(pid)
  end

  describe "manual control" do
    test "an owner's hold blocks train samples and ends when the owner dies", %{
      train: train,
      gauge: gauge,
      binding: b
    } do
      holder = spawn(fn -> Process.sleep(:infinity) end)
      GaugeController.subscribe(train.id)
      pid = start_supervised!(GaugeController)

      assert :ok = GaugeController.hold_manual(gauge.id, owner: holder)
      assert GaugeController.manual?(gauge.id)

      send(pid, {:train_changed, train})
      id = b.id

      assert_receive {:gauge_binding_updated, ^id, %{failure: :manual_control, target: @half}},
                     500

      refute_receive {:target, _, _, _}, 500

      Process.exit(holder, :kill)
      assert_receive {:target, _, _, @half}, 500
      refute GaugeController.manual?(gauge.id)
      assert_receive {:gauge_binding_updated, ^id, %{failure: nil}}, 500
    end

    test "a hold taken while running stops further sends", %{train: train, gauge: gauge} do
      counter = start_supervised!({Agent, fn -> 50 end})
      Mimic.stub(Client, :get_subscription, fn _, _ -> sample(Agent.get(counter, & &1)) end)

      start_controller(train)
      assert_receive {:target, _, _, @half}, 500

      GaugeController.hold_manual(gauge.id, owner: self())
      Agent.update(counter, fn _ -> 100 end)
      refute_receive {:target, _, _, _}, 500
    end

    test "release_manual resends the train's target at once", %{train: train, gauge: gauge} do
      start_supervised!(GaugeController)
      GaugeController.hold_manual(gauge.id, owner: self())
      send(GaugeController, {:train_changed, train})
      assert_receive {:subscribed, "Speed", _}, 500
      refute_receive {:target, _, _, _}, 500

      assert :ok = GaugeController.release_manual(gauge.id)
      refute GaugeController.manual?(gauge.id)
      assert_receive {:target, _, _, @half}, 500
    end

    test "a ttl hold expires on its own", %{train: train, gauge: gauge} do
      start_supervised!(GaugeController)
      GaugeController.hold_manual(gauge.id, ttl_ms: 400)
      send(GaugeController, {:train_changed, train})
      refute_receive {:target, _, _, _}, 300
      assert_receive {:target, _, _, @half}, 1000
      refute GaugeController.manual?(gauge.id)
    end

    test "a timed hold does not replace a hold owned by a live process", %{gauge: gauge} do
      start_supervised!(GaugeController)
      holder = spawn(fn -> Process.sleep(:infinity) end)
      assert :ok = GaugeController.hold_manual(gauge.id, owner: holder)
      assert :ok = GaugeController.hold_manual(gauge.id, ttl_ms: 1)
      Process.sleep(5)
      assert GaugeController.manual?(gauge.id)
      Process.exit(holder, :kill)
    end

    test "holds work with no active train and are no-ops without the controller", %{gauge: gauge} do
      assert :ok = GaugeController.hold_manual(gauge.id, owner: self())
      refute GaugeController.manual?(gauge.id)

      start_supervised!(GaugeController)
      assert :ok = GaugeController.hold_manual(gauge.id, owner: self())
      assert GaugeController.manual?(gauge.id)
      assert :ok = GaugeController.release_manual(gauge.id)
      refute GaugeController.manual?(gauge.id)
    end
  end

  test "stale input holds the needle: nothing is sent, not even zero", %{
    train: train,
    binding: b
  } do
    GaugeController.subscribe(train.id)
    pid = start_controller(train)
    assert_receive {:target, _, _, @half}, 500
    Mimic.stub(Client, :get_subscription, fn _, _ -> {:error, :offline} end)

    :sys.replace_state(pid, fn s ->
      put_in(s.status[b.id].received_at, System.monotonic_time(:millisecond) - 1000)
    end)

    send(pid, {:poll, :sys.get_state(pid).generation})
    id = b.id
    assert_receive {:gauge_binding_updated, ^id, %{stale: true, target: @half}}, 500
    refute_receive {:target, _, _, _}, 500
    refute Map.has_key?(:sys.get_state(pid).sent, b.id)
  end

  test "cleanup rejection blocks ID reuse and retries safely", %{train: train} do
    counter = start_supervised!({Agent, fn -> 0 end})

    Mimic.stub(Client, :unsubscribe, fn _, _ ->
      # Call 0 is the pre-subscribe clear; call 1 is the first cleanup attempt.
      if Agent.get_and_update(counter, &{&1, &1 + 1}) == 1,
        do: {:error, :offline},
        else: {:ok, %{}}
    end)

    pid = start_controller(train)
    assert_receive {:target, _, _, _}, 500
    assert_receive {:subscribed, _, _}, 100
    send(pid, {:train_changed, train})
    refute_receive {:subscribed, _, _}, 400
    assert_receive {:subscribed, "Speed", 4000}, 1000
  end

  test "cleanup of an already-missing subscription completes and polling resumes", %{
    train: train
  } do
    Mimic.stub(Client, :unsubscribe, fn _, _ ->
      {:error,
       {:http_error, 400,
        %{
          "errorCode" => "dtg.comm.NoSuchSubscription",
          "errorMessage" => "Could not find requested subscription ID"
        }}}
    end)

    pid = start_controller(train)
    assert_receive {:target, _, _, @half}, 500
    assert_receive {:subscribed, "Speed", 4000}, 100

    send(pid, {:train_changed, train})

    assert_receive {:subscribed, "Speed", 4000}, 500
    refute :sys.get_state(pid).cleaning
  end

  test "the subscription ID is cleared before its first subscribe, even on a fresh start", %{
    train: train
  } do
    start_controller(train)
    assert_receive {:subscribed, "Speed", 4000}, 500
    # Same task, so mailbox order is call order: unsubscribe must come first.
    assert {:messages, [{:unsubscribed, 4000} | _]} = Process.info(self(), :messages)
  end

  test "a failed GET drops the subscription and resubscribes after backoff", %{train: train} do
    counter = start_supervised!({Agent, fn -> 0 end})

    Mimic.stub(Client, :get_subscription, fn _, _ ->
      if Agent.get_and_update(counter, &{&1, &1 + 1}) == 0,
        do: {:error, {:http_error, 400, %{"errorCode" => "dtg.comm.NoSuchSubscription"}}},
        else: sample(50)
    end)

    start_controller(train)
    assert_receive {:subscribed, "Speed", 4000}, 500
    refute_receive {:subscribed, "Speed", 4000}, 500
    assert_receive {:subscribed, "Speed", 4000}, 1500
    assert_receive {:target, _, _, @half}, 500
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

  test "deactivating the train unsubscribes and stops sending", %{train: train} do
    pid = start_controller(train)
    assert_receive {:subscribed, "Speed", 4000}, 500
    assert_receive {:target, _, _, @half}, 500
    send(pid, {:train_changed, nil})
    assert_receive {:unsubscribed, 4000}, 200
    refute_receive {:target, _, _, _}, 400
    assert GaugeController.snapshot(train.id) == %{}
  end

  test "slow HTTP cannot block train switch and old completion cannot move", %{train: train} do
    owner = self()

    Mimic.stub(Client, :get_subscription, fn _, _ ->
      send(owner, {:poll_entered, self()})

      receive do
        :continue -> sample(100)
      end
    end)

    pid = start_controller(train)
    assert_receive {:poll_entered, worker}, 500
    old = :sys.get_state(pid)
    send(pid, {:train_changed, nil})
    send(worker, :continue)
    send(pid, {old.task.ref, {old.generation, %{subscriptions: %{}, values: %{}, retries: %{}}}})
    refute_receive {:target, _, _, _}, 250
    assert GaugeController.snapshot(train.id) == %{}
  end

  test "subscription cleanup completes before identifiers can be reused", %{train: train} do
    owner = self()

    pid = start_controller(train)
    assert_receive {:target, _, _, _}, 500
    assert_receive {:subscribed, "Speed", 4000}, 100

    Mimic.stub(Client, :unsubscribe, fn _, id ->
      send(owner, {:cleanup_waiting, self(), id})

      receive do
        :complete_cleanup -> {:ok, %{}}
      end
    end)

    send(pid, {:train_changed, train})
    assert_receive {:cleanup_waiting, cleanup, 4000}, 200
    refute_receive {:subscribed, _, _}, 250
    Mimic.stub(Client, :unsubscribe, fn _, _ -> {:ok, %{}} end)
    send(cleanup, :complete_cleanup)
    assert_receive {:subscribed, "Speed", 4000}, 500
  end

  test "failed subscriptions back off instead of retrying every tick", %{train: train} do
    owner = self()

    Mimic.stub(Client, :subscribe, fn _, _, _ ->
      send(owner, :subscribe_failed)
      {:error, :offline}
    end)

    start_controller(train)
    assert_receive :subscribe_failed, 500
    refute_receive :subscribe_failed, 600
    assert_receive :subscribe_failed, 700
  end

  test "persistent cleanup failure is bounded, then polling resumes on fresh IDs", %{train: train} do
    pid = start_controller(train)
    assert_receive {:subscribed, "Speed", 4000}, 500
    Mimic.stub(Client, :unsubscribe, fn _, _ -> {:error, :offline} end)
    send(pid, {:train_changed, train})
    refute_receive {:subscribed, _, _}, 1500

    assert %{controller: %{cleaning: true, last_error: {:cleanup_failed, _}}} =
             GaugeController.runtime(train.id)

    assert_receive {:subscribed, "Speed", id}, 3000
    assert id != 4000
    assert_receive {:target, _, _, @half}, 500
    refute :sys.get_state(pid).cleaning
  end

  test "reload with unchanged endpoints keeps the healthy subscription and resends", %{
    train: train
  } do
    pid = start_controller(train)
    assert_receive {:subscribed, "Speed", 4000}, 500
    assert_receive {:target, _, _, @half}, 500
    GaugeController.reload_bindings()
    send(pid, {:gauge_bindings_changed, train.id})
    :sys.get_state(pid)
    # The one unsubscribe before the first subscribe is expected; nothing after it.
    assert_receive {:unsubscribed, 4000}
    refute_receive {:unsubscribed, _}, 300
    refute_receive {:subscribed, _, _}, 10
    assert_receive {:target, _, _, @half}, 500
  end

  test "reload with changed endpoints resubscribes", %{train: train, binding: b} do
    pid = start_controller(train)
    assert_receive {:subscribed, "Speed", 4000}, 500
    {:ok, _} = Train.update_gauge_binding(b, %{endpoint: "Other"})
    send(pid, {:gauge_bindings_changed, train.id})
    assert_receive {:unsubscribed, 4000}, 500
    assert_receive {:subscribed, "Other", 4000}, 500
  end

  test "runtime exposes sample, target, failures and controller state", %{
    train: train,
    binding: b
  } do
    start_controller(train)
    assert_receive {:target, _, _, @half}, 500
    runtime = GaugeController.runtime(train.id)
    assert %{simulator_connected: true, cleaning: false, last_error: nil} = runtime.controller
    assert %{sample: 50.0, target: @half, stale: false, failure: nil} = runtime.bindings[b.id]
    assert GaugeController.runtime(-1) == nil
  end

  test "subscribe and poll failures are reported", %{train: train, binding: b} do
    id = b.id
    GaugeController.subscribe(train.id)
    Mimic.stub(Client, :subscribe, fn _, _, _ -> {:error, :offline} end)
    pid = start_controller(train)

    assert_receive {:gauge_binding_updated, ^id, %{failure: {:subscribe_failed, _}}}, 500

    assert {:subscribe_failed, {:error, :offline}} =
             GaugeController.runtime(train.id).controller.last_error

    Mimic.stub(Client, :subscribe, fn _, _, _ -> {:ok, %{}} end)
    Mimic.stub(Client, :get_subscription, fn _, _ -> {:error, :boom} end)
    send(pid, {:train_changed, train})
    assert_receive {:gauge_binding_updated, ^id, %{failure: {:poll_failed, :boom}}}, 1500
  end
end
