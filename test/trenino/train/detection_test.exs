defmodule Trenino.Train.DetectionTest do
  use Trenino.DataCase, async: false
  use Mimic

  alias Trenino.Simulator.Client
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
          identifier: "BR_Class_66_"
        })

      # Test the matching logic through the context
      {:ok, found} = TrainContext.get_train_by_identifier("BR_Class_66_")
      assert found.id == train.id
    end

    test "returns not_found for unknown identifier" do
      assert {:error, :not_found} = TrainContext.get_train_by_identifier("Unknown_Train_")
    end
  end

  describe "grace period" do
    setup do
      # Create a train to detect
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Class 66",
          identifier: "BR_Class_66"
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
