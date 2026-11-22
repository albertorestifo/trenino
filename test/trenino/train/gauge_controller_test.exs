defmodule Trenino.Train.GaugeControllerTest do
  use Trenino.DataCase, async: false
  import Trenino.GaugeFixtures
  alias Trenino.Hardware
  alias Trenino.Simulator
  alias Trenino.Simulator.{Client, ConnectionState, Watcher}
  alias Trenino.Train
  alias Trenino.Train.GaugeController
  setup :set_mimic_global

  # The calibrated fixture maps value 0 to step 0 and value 100 to step 1890.
  @half 945
  @full 1890

  setup do
    owner = self()
    client = %Client{base_url: "http://fake", api_key: "fake"}
    value = start_supervised!({Agent, fn -> 50 end}, id: :simulator_value)

    Mimic.stub(Simulator.Connection, :get_status, fn ->
      %ConnectionState{status: :connected, client: client}
    end)

    # The simulator answers every watched path with the current value; :missing leaves
    # them out, as a simulator that cannot read them does.
    Mimic.stub(Simulator, :read, fn paths ->
      send(owner, {:read, paths})

      case Agent.get(value, & &1) do
        :missing -> {:ok, %{}}
        v -> {:ok, Map.new(paths, &{&1, v})}
      end
    end)

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
    start_supervised!(Watcher)
    %{device: device, gauge: gauge, train: train, binding: binding, value: value}
  end

  defp set_value(%{value: agent}, v), do: Agent.update(agent, fn _ -> v end)

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
    assert_receive {:read, ["Speed"]}, 500
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

  test "an unchanged target is not resent every sample, only after the refresh window", %{
    train: train,
    binding: b
  } do
    pid = start_controller(train)
    assert_receive {:target, _, _, @half}, 500
    # Several 200 ms samples of the same value go by without another command.
    refute_receive {:target, _, _, _}, 700

    :sys.replace_state(pid, fn s ->
      put_in(s.sent[b.id].at, System.monotonic_time(:millisecond) - 5000)
    end)

    assert_receive {:target, _, _, @half}, 500
  end

  test "a changed target is sent immediately", %{train: train} = ctx do
    pid = start_controller(train)
    assert_receive {:target, _, _, @half}, 500
    set_value(ctx, 100)
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

    # A failed link is cached too: the next samples do not look it up again.
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

    test "a hold taken while running stops further sends", %{train: train, gauge: gauge} = ctx do
      start_controller(train)
      assert_receive {:target, _, _, @half}, 500

      GaugeController.hold_manual(gauge.id, owner: self())
      set_value(ctx, 100)
      refute_receive {:target, _, _, _}, 500
    end

    test "release_manual resends the train's target at once", %{train: train, gauge: gauge} do
      start_supervised!(GaugeController)
      GaugeController.hold_manual(gauge.id, owner: self())
      send(GaugeController, {:train_changed, train})
      assert_receive {:read, ["Speed"]}, 500
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

  test "stale input holds the needle: nothing is sent, not even zero",
       %{train: train, binding: b} = ctx do
    GaugeController.subscribe(train.id)
    pid = start_controller(train)
    assert_receive {:target, _, _, @half}, 500
    set_value(ctx, :missing)

    id = b.id
    assert_receive {:gauge_binding_updated, ^id, %{stale: true, target: @half}}, 1000
    refute_receive {:target, _, _, _}, 500
    refute Map.has_key?(:sys.get_state(pid).sent, b.id)
  end

  test "a fresh sample after going stale moves the needle again",
       %{train: train, binding: b} = ctx do
    GaugeController.subscribe(train.id)
    start_controller(train)
    assert_receive {:target, _, _, @half}, 500
    set_value(ctx, :missing)
    id = b.id
    assert_receive {:gauge_binding_updated, ^id, %{stale: true}}, 1000

    set_value(ctx, 50)
    assert_receive {:target, _, _, @half}, 500
    assert_receive {:gauge_binding_updated, ^id, %{stale: false}}, 500
  end

  test "value selection is strict and never arbitrarily chooses a key" do
    assert {:ok, 3} = GaugeController.sample(3, nil)
    assert {:ok, 3} = GaugeController.sample(%{"Speed" => 3}, nil)
    assert {:ok, 4} = GaugeController.sample(%{"Speed" => 3, "Other" => 4}, "Other")
    assert {:error, _} = GaugeController.sample(%{"Speed" => 3, "Other" => 4}, nil)
    assert {:error, _} = GaugeController.sample(%{"Speed" => 3, "Other" => 4}, "Missing")

    for value <- [nil, "3", false, %{}],
        do: assert({:error, _} = GaugeController.sample(%{"Speed" => value}, nil))

    for value <- [nil, "3", false, %{}],
        do: assert({:error, _} = GaugeController.sample(value, nil))
  end

  test "a multi-value endpoint uses the binding's value key", %{train: train, binding: b} do
    {:ok, _} = Train.update_gauge_binding(b, %{value_key: "Other"})

    Mimic.stub(Simulator, :read, fn paths ->
      {:ok, Map.new(paths, &{&1, %{"Speed" => 0, "Other" => 100}})}
    end)

    start_controller(train)
    assert_receive {:target, _, _, @full}, 500
  end

  test "an unusable value is reported as the binding's failure", %{train: train, binding: b} do
    Mimic.stub(Simulator, :read, fn paths -> {:ok, Map.new(paths, &{&1, "fast"})} end)
    GaugeController.subscribe(train.id)
    start_controller(train)
    id = b.id

    assert_receive {:gauge_binding_updated, ^id,
                    %{failure: {:error, :invalid_or_ambiguous_sample}}},
                   500

    assert {:error, :invalid_or_ambiguous_sample} =
             GaugeController.runtime(train.id).controller.last_error
  end

  test "deactivating the train stops watching and sending", %{train: train} do
    pid = start_controller(train)
    assert_receive {:target, _, _, @half}, 500
    send(pid, {:train_changed, nil})
    :sys.get_state(pid)
    # Nothing is watched any more, so nothing is polled for the gauge.
    assert :sys.get_state(Watcher).watchers == %{}
    send(pid, {:simulator_values, %{"Speed" => 100}})
    :sys.get_state(pid)
    refute_received {:target, _, _, @full}
    assert GaugeController.snapshot(train.id) == %{}
  end

  test "reload with unchanged endpoints keeps the samples and resends", %{
    train: train,
    binding: b
  } do
    pid = start_controller(train)
    assert_receive {:target, _, _, @half}, 500
    send(pid, {:gauge_bindings_changed, train.id})
    assert Map.has_key?(:sys.get_state(pid).status, b.id)
    assert_receive {:target, _, _, @half}, 500
  end

  test "reload with changed endpoints watches the new endpoint", %{train: train, binding: b} do
    pid = start_controller(train)
    assert_receive {:read, ["Speed"]}, 500
    {:ok, _} = Train.update_gauge_binding(b, %{endpoint: "Other"})
    send(pid, {:gauge_bindings_changed, train.id})
    # Older reads of "Speed" stay in the mailbox; the pattern skips them.
    assert_receive {:read, ["Other"]}, 1000
    # The update also broadcasts a reload; let it finish its database read before the
    # test's sandbox goes away.
    :sys.get_state(pid)
  end

  test "a simulator disconnect forgets the samples", %{train: train, binding: b} do
    pid = start_controller(train)
    assert_receive {:target, _, _, @half}, 500
    send(pid, {:simulator_status_changed, %ConnectionState{status: :disconnected}})
    state = :sys.get_state(pid)
    refute state.connected
    refute Map.has_key?(state.status, b.id)
  end

  test "runtime exposes sample, target, failures and controller state", %{
    train: train,
    binding: b
  } do
    start_controller(train)
    assert_receive {:target, _, _, @half}, 500
    runtime = GaugeController.runtime(train.id)

    assert %{simulator_connected: true, last_error: nil, watched_endpoints: ["Speed"]} =
             runtime.controller

    assert %{sample: 50.0, target: @half, stale: false, failure: nil} = runtime.bindings[b.id]
    assert GaugeController.runtime(-1) == nil
  end
end
