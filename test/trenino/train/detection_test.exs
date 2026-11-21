defmodule Trenino.Train.DetectionTest do
  use Trenino.DataCase, async: false

  alias Trenino.Simulator.Client
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.Detection
  alias Trenino.Train.Detection.State
  alias Trenino.Train.Identifier

  setup :verify_on_exit!

  setup do
    # Allow the Detection process to use our Identifier mock
    detection_pid = Process.whereis(Detection)
    Mimic.allow(Identifier, self(), detection_pid)

    # Reset Detection state directly to avoid grace period interference
    :sys.replace_state(detection_pid, fn _state -> %State{} end)

    :ok
  end

  describe "get_active_train/0" do
    test "returns nil when no train is detected" do
      assert Detection.get_active_train() == nil
    end
  end

  describe "get_current_identifier/0" do
    test "returns nil when no identifier detected" do
      assert Detection.get_current_identifier() == nil
    end
  end

  describe "get_state/0" do
    test "returns the current state" do
      state = Detection.get_state()

      assert %State{} = state
      assert state.active_train == nil
      assert state.current_identifier == nil
      assert state.polling_enabled == false
    end
  end

  describe "subscribe/0" do
    test "subscribes to train detection events" do
      assert :ok = Detection.subscribe()
    end
  end

  describe "simulator connection events" do
    test "clears state and broadcasts train_changed nil on disconnect" do
      Detection.subscribe()

      # First simulate that we have a train detected by setting up state
      # This is a workaround since we can't easily mock SimulatorConnection
      # We'll manually test the disconnect behavior
      send(
        Process.whereis(Detection),
        {:simulator_status_changed, %ConnectionState{status: :disconnected}}
      )

      assert_receive {:train_changed, nil}, 1000

      state = Detection.get_state()
      assert state.active_train == nil
      assert state.current_identifier == nil
      assert state.polling_enabled == false
    end

    test "enables polling on connect" do
      Detection.subscribe()

      # Simulate connect
      send(
        Process.whereis(Detection),
        {:simulator_status_changed,
         %ConnectionState{status: :connected, client: Client.new("http://test", "key")}}
      )

      # Allow state update
      Process.sleep(50)

      state = Detection.get_state()
      assert state.polling_enabled == true
    end

    test "disables polling on disconnect" do
      Detection.subscribe()

      # First connect
      send(
        Process.whereis(Detection),
        {:simulator_status_changed,
         %ConnectionState{status: :connected, client: Client.new("http://test", "key")}}
      )

      Process.sleep(50)
      assert Detection.get_state().polling_enabled == true

      # Then disconnect
      send(
        Process.whereis(Detection),
        {:simulator_status_changed, %ConnectionState{status: :disconnected}}
      )

      Process.sleep(50)
      state = Detection.get_state()
      assert state.polling_enabled == false
    end
  end

  describe "train matching" do
    test "matches detected identifier to stored train configuration" do
      # Create a train configuration
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Class 66",
          identifiers: [%{identifier: "BR_Class_66_"}]
        })

      # Test the matching logic through the context
      {:ok, found} = TrainContext.get_train_by_identifier("BR_Class_66_")
      assert found.id == train.id
    end

    test "returns not_found for unknown identifier" do
      assert {:error, :not_found} = TrainContext.get_train_by_identifier("Unknown_Train_")
    end
  end

  describe "reads while the simulator is slow" do
    setup do
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Class 66",
          identifiers: [%{identifier: "BR_Class_66"}]
        })

      Detection.subscribe()

      # Detection only polls when Simulator.Connection is registered, and it isn't
      # started in tests. Stand in for it so the regular poll path runs.
      true = Process.register(self(), SimulatorConnection)
      Mimic.allow(SimulatorConnection, self(), Process.whereis(Detection))
      client = Client.new("http://test", "key")

      stub(SimulatorConnection, :get_status, fn ->
        %ConnectionState{status: :connected, client: client}
      end)

      %{train: train, client: client}
    end

    # Blocks every formation request until the test sends :release to the task.
    defp stub_hung_simulator(result) do
      test_pid = self()

      stub(Identifier, :derive_from_formation, fn _client ->
        send(test_pid, {:simulator_request, self()})

        receive do
          :release -> result
        end
      end)
    end

    test "get_active_train answers while a poll is waiting on the simulator", %{
      train: train,
      client: client
    } do
      stub_hung_simulator({:ok, "BR_Class_66"})

      send(
        Process.whereis(Detection),
        {:simulator_status_changed, %ConnectionState{status: :connected, client: client}}
      )

      assert_receive {:simulator_request, request_pid}

      assert GenServer.call(Detection, :get_active_train, 100) == nil
      assert GenServer.call(Detection, :get_current_identifier, 100) == nil
      assert %State{polling_enabled: true} = GenServer.call(Detection, :get_state, 100)

      send(request_pid, :release)

      assert_receive {:train_changed, %{id: train_id}}
      assert train_id == train.id
      assert Detection.get_active_train().id == train.id
      assert Detection.get_current_identifier() == "BR_Class_66"
    end

    test "runs one formation request at a time", %{client: client} do
      stub_hung_simulator({:ok, "BR_Class_66"})
      detection_pid = Process.whereis(Detection)

      send(
        detection_pid,
        {:simulator_status_changed, %ConnectionState{status: :connected, client: client}}
      )

      assert_receive {:simulator_request, request_pid}

      send(detection_pid, :poll)
      Detection.sync()
      # The call is processed after the poll and the sync, so they had their chance.
      _ = Detection.get_state()

      refute_received {:simulator_request, _}

      send(request_pid, :release)
      assert_receive {:train_detected, %{identifier: "BR_Class_66"}}
    end

    test "drops a pending result when the simulator disconnects", %{client: client} do
      stub_hung_simulator({:ok, "BR_Class_66"})
      detection_pid = Process.whereis(Detection)

      send(
        detection_pid,
        {:simulator_status_changed, %ConnectionState{status: :connected, client: client}}
      )

      assert_receive {:simulator_request, request_pid}
      ref = Process.monitor(request_pid)

      send(detection_pid, {:simulator_status_changed, %ConnectionState{status: :disconnected}})

      assert_receive {:train_changed, nil}
      assert_receive {:DOWN, ^ref, :process, ^request_pid, _reason}

      state = Detection.get_state()
      assert state.active_train == nil
      assert state.current_identifier == nil
      refute_received {:train_detected, _}
    end

    test "get_active_train answers while a grace poll is waiting on the simulator", %{
      train: train,
      client: client
    } do
      detection_pid = Process.whereis(Detection)

      :sys.replace_state(detection_pid, fn _state ->
        %State{
          active_train: train,
          current_identifier: "BR_Class_66",
          polling_enabled: true,
          last_successful_contact: System.monotonic_time(:millisecond),
          last_client: client
        }
      end)

      stub_hung_simulator({:ok, "BR_Class_66"})

      send(detection_pid, {:simulator_status_changed, %ConnectionState{status: :disconnected}})

      assert_receive {:simulator_request, request_pid}, 1_000
      assert GenServer.call(Detection, :get_active_train, 100).id == train.id

      test_pid = self()

      stub(Identifier, :derive_from_formation, fn _client ->
        send(test_pid, :grace_polled)
        {:ok, "BR_Class_66"}
      end)

      send(request_pid, :release)

      # Grace polling continues after the slow request completes
      assert_receive :grace_polled, 1_000
      assert Detection.get_active_train().id == train.id
      refute_received {:train_changed, nil}
    end

    test "a sync cut short by a disconnect runs again in the grace period", %{
      train: train,
      client: client
    } do
      detection_pid = Process.whereis(Detection)

      :sys.replace_state(detection_pid, fn _state ->
        %State{
          active_train: train,
          current_identifier: "BR_Class_66",
          polling_enabled: true,
          last_successful_contact: System.monotonic_time(:millisecond),
          last_client: client
        }
      end)

      stub_hung_simulator({:ok, "BR_Class_66"})

      Detection.sync()
      assert_receive {:simulator_request, sync_pid}
      ref = Process.monitor(sync_pid)

      send(detection_pid, {:simulator_status_changed, %ConnectionState{status: :disconnected}})

      assert_receive {:DOWN, ^ref, :process, ^sync_pid, _reason}
      # The sync is redone with the grace client instead of being dropped
      assert_receive {:simulator_request, grace_pid}

      assert %State{task_kind: :grace_detect, current_identifier: nil} =
               Detection.get_state()

      send(grace_pid, :release)
      assert_receive {:train_detected, %{identifier: "BR_Class_66"}}
    end

    test "the grace period expires while a grace detection hangs", %{
      train: train,
      client: client
    } do
      detection_pid = Process.whereis(Detection)

      :sys.replace_state(detection_pid, fn _state ->
        %State{
          active_train: train,
          current_identifier: "BR_Class_66",
          polling_enabled: true,
          last_successful_contact: System.monotonic_time(:millisecond),
          last_client: client
        }
      end)

      stub_hung_simulator({:ok, "BR_Class_66"})

      # A sync cut short by the disconnect is redone as a grace detection
      Detection.sync()
      assert_receive {:simulator_request, _sync_pid}
      send(detection_pid, {:simulator_status_changed, %ConnectionState{status: :disconnected}})
      assert_receive {:simulator_request, grace_pid}
      ref = Process.monitor(grace_pid)

      # The test grace period is 200ms; the hung request must not keep it open
      assert_receive {:train_changed, nil}, 2_000
      assert_receive {:DOWN, ^ref, :process, ^grace_pid, _reason}

      assert %State{active_train: nil, grace_client: nil, task: nil} = Detection.get_state()
    end
  end

  describe "grace period" do
    setup do
      # Create a train to detect
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Class 66",
          identifiers: [%{identifier: "BR_Class_66"}]
        })

      Detection.subscribe()

      %{train: train}
    end

    defp setup_active_train(detection_pid, train) do
      client = Client.new("http://test", "key")

      # Inject active train state directly into the Detection GenServer
      :sys.replace_state(detection_pid, fn _state ->
        %State{
          active_train: train,
          current_identifier: "BR_Class_66",
          last_check: DateTime.utc_now(),
          polling_enabled: true,
          detection_error: nil,
          last_successful_contact: System.monotonic_time(:millisecond),
          last_client: client,
          grace_client: nil,
          grace_timer: nil
        }
      end)

      client
    end

    test "enters grace period instead of deactivating on disconnect", %{train: train} do
      detection_pid = Process.whereis(Detection)
      _client = setup_active_train(detection_pid, train)

      # Mock Identifier for grace poll success
      stub(Identifier, :derive_from_formation, fn _client ->
        {:ok, "BR_Class_66"}
      end)

      # Simulate disconnect (non-connected status)
      send(
        detection_pid,
        {:simulator_status_changed,
         %ConnectionState{status: :error, last_error: :connection_failed}}
      )

      Process.sleep(50)

      # Train should still be active (grace period)
      state = Detection.get_state()
      assert state.active_train != nil
      assert state.grace_client != nil
      assert state.polling_enabled == false

      # Should NOT have received train_changed nil
      refute_received {:train_changed, nil}
    end

    test "grace poll success keeps train active", %{train: train} do
      detection_pid = Process.whereis(Detection)
      _client = setup_active_train(detection_pid, train)

      # Mock Identifier for grace poll success
      stub(Identifier, :derive_from_formation, fn _client ->
        {:ok, "BR_Class_66"}
      end)

      # Simulate disconnect
      send(
        detection_pid,
        {:simulator_status_changed,
         %ConnectionState{status: :error, last_error: :connection_failed}}
      )

      Process.sleep(50)

      # Grace polls should succeed (Identifier is stubbed to succeed)
      # Wait for a grace poll cycle
      Process.sleep(300)

      state = Detection.get_state()
      assert state.active_train != nil
      refute_received {:train_changed, nil}
    end

    test "grace period expires after timeout and deactivates", %{train: train} do
      detection_pid = Process.whereis(Detection)
      _client = setup_active_train(detection_pid, train)

      # Make Identifier fail during grace period
      stub(Identifier, :derive_from_formation, fn _client ->
        {:error, {:request_failed, :timeout}}
      end)

      # Simulate disconnect
      send(
        detection_pid,
        {:simulator_status_changed,
         %ConnectionState{status: :error, last_error: :connection_failed}}
      )

      # Wait for grace period to expire (200ms in test config + some buffer)
      assert_receive {:train_changed, nil}, 1_000

      state = Detection.get_state()
      assert state.active_train == nil
      assert state.grace_client == nil
    end

    test "connection recovery during grace exits grace cleanly", %{train: train} do
      detection_pid = Process.whereis(Detection)
      client = setup_active_train(detection_pid, train)

      # Mock Identifier for grace poll success
      stub(Identifier, :derive_from_formation, fn _client ->
        {:ok, "BR_Class_66"}
      end)

      # Simulate disconnect to enter grace
      send(
        detection_pid,
        {:simulator_status_changed,
         %ConnectionState{status: :error, last_error: :connection_failed}}
      )

      Process.sleep(50)
      state = Detection.get_state()
      assert state.grace_client != nil

      # Simulate reconnection
      send(
        detection_pid,
        {:simulator_status_changed, %ConnectionState{status: :connected, client: client}}
      )

      Process.sleep(50)

      state = Detection.get_state()
      assert state.grace_client == nil
      assert state.polling_enabled == true
      assert state.active_train != nil
    end

    test "multiple disconnect messages during grace don't re-enter", %{train: train} do
      detection_pid = Process.whereis(Detection)
      _client = setup_active_train(detection_pid, train)

      # Mock Identifier for grace poll success
      stub(Identifier, :derive_from_formation, fn _client ->
        {:ok, "BR_Class_66"}
      end)

      # Simulate first disconnect
      send(
        detection_pid,
        {:simulator_status_changed,
         %ConnectionState{status: :error, last_error: :connection_failed}}
      )

      Process.sleep(50)
      state1 = Detection.get_state()
      assert state1.grace_client != nil

      # Send another disconnect
      send(
        detection_pid,
        {:simulator_status_changed, %ConnectionState{status: :disconnected}}
      )

      Process.sleep(50)
      state2 = Detection.get_state()
      # Should still be in grace, not re-entered
      assert state2.grace_client != nil
      assert state2.active_train != nil
    end

    test "no grace period when no active train" do
      detection_pid = Process.whereis(Detection)

      # Simulate disconnect without ever having an active train
      send(
        detection_pid,
        {:simulator_status_changed,
         %ConnectionState{status: :error, last_error: :connection_failed}}
      )

      assert_receive {:train_changed, nil}, 1_000

      state = Detection.get_state()
      assert state.active_train == nil
      assert state.grace_client == nil
    end

    test "sync during grace period works", %{train: train} do
      detection_pid = Process.whereis(Detection)
      _client = setup_active_train(detection_pid, train)

      # Mock Identifier for grace poll success
      stub(Identifier, :derive_from_formation, fn _client ->
        {:ok, "BR_Class_66"}
      end)

      # Simulate disconnect
      send(
        detection_pid,
        {:simulator_status_changed,
         %ConnectionState{status: :error, last_error: :connection_failed}}
      )

      Process.sleep(50)
      state = Detection.get_state()
      assert state.grace_client != nil

      # Trigger sync while in grace period
      Detection.sync()
      Process.sleep(100)

      # Should still have active train (sync uses grace client)
      state = Detection.get_state()
      assert state.active_train != nil
    end
  end
end
