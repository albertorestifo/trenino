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

    # Reset Detection state by simulating a disconnect
    send(detection_pid, {:simulator_status_changed, %ConnectionState{status: :disconnected}})

    # Give time for state reset
    Process.sleep(10)

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
end
