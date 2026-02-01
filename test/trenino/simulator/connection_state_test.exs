defmodule Trenino.Simulator.ConnectionStateTest do
  use ExUnit.Case, async: true

  alias Trenino.Simulator.Client
  alias Trenino.Simulator.ConnectionState

  describe "new/0" do
    test "creates a state with needs_config status" do
      state = ConnectionState.new()

      assert %ConnectionState{status: :needs_config} = state
      assert state.client == nil
      assert state.last_error == nil
      assert state.last_check == nil
      assert state.info == nil
      assert state.health_failures == 0
    end
  end

  describe "mark_connecting/2" do
    test "sets status to connecting and stores client" do
      state = ConnectionState.new()
      client = Client.new("http://localhost:31270", "test-key")

      new_state = ConnectionState.mark_connecting(state, client)

      assert new_state.status == :connecting
      assert new_state.client == client
      assert new_state.last_error == nil
    end

    test "clears previous error" do
      state = %ConnectionState{status: :error, last_error: :timeout}
      client = Client.new("http://localhost:31270", "test-key")

      new_state = ConnectionState.mark_connecting(state, client)

      assert new_state.last_error == nil
    end
  end

  describe "mark_connected/2" do
    test "sets status to connected and stores info" do
      client = Client.new("http://localhost:31270", "test-key")
      state = %ConnectionState{status: :connecting, client: client}
      info = %{"version" => "1.0"}

      new_state = ConnectionState.mark_connected(state, info)

      assert new_state.status == :connected
      assert new_state.info == info
      assert new_state.last_error == nil
      assert %DateTime{} = new_state.last_check
    end
  end

  describe "mark_disconnected/1" do
    test "resets state to disconnected" do
      client = Client.new("http://localhost:31270", "test-key")

      state = %ConnectionState{
        status: :connected,
        client: client,
        info: %{"version" => "1.0"},
        last_check: DateTime.utc_now()
      }

      new_state = ConnectionState.mark_disconnected(state)

      assert new_state.status == :disconnected
      assert new_state.client == nil
      assert new_state.info == nil
      assert new_state.last_check == nil
    end
  end

  describe "mark_needs_config/1" do
    test "resets state to needs_config" do
      state = %ConnectionState{
        status: :error,
        last_error: :connection_failed,
        last_check: DateTime.utc_now()
      }

      new_state = ConnectionState.mark_needs_config(state)

      assert new_state.status == :needs_config
      assert new_state.client == nil
      assert new_state.last_error == nil
      assert new_state.last_check == nil
      assert new_state.info == nil
    end
  end

  describe "mark_error/2" do
    test "sets status to error with reason" do
      client = Client.new("http://localhost:31270", "test-key")
      state = %ConnectionState{status: :connecting, client: client}

      new_state = ConnectionState.mark_error(state, :timeout)

      assert new_state.status == :error
      assert new_state.last_error == :timeout
      assert %DateTime{} = new_state.last_check
      # Client should be preserved
      assert new_state.client == client
    end

    test "handles various error reasons" do
      state = ConnectionState.new()

      for reason <- [:invalid_key, :connection_failed, :timeout, {:http_error, 500}] do
        new_state = ConnectionState.mark_error(state, reason)
        assert new_state.last_error == reason
      end
    end

    test "resets health_failures counter" do
      state = %ConnectionState{status: :connected, health_failures: 2}

      new_state = ConnectionState.mark_error(state, :connection_failed)

      assert new_state.health_failures == 0
    end
  end

  describe "record_health_failure/2" do
    test "increments health_failures counter" do
      state = %ConnectionState{status: :connected, health_failures: 0}

      new_state = ConnectionState.record_health_failure(state, :connection_failed)

      assert new_state.health_failures == 1
    end

    test "records error and timestamp" do
      state = %ConnectionState{status: :connected, health_failures: 0}

      new_state = ConnectionState.record_health_failure(state, :connection_failed)

      assert new_state.last_error == :connection_failed
      assert %DateTime{} = new_state.last_check
    end

    test "preserves status unchanged" do
      state = %ConnectionState{status: :connected, health_failures: 0}

      new_state = ConnectionState.record_health_failure(state, :connection_failed)

      assert new_state.status == :connected
    end

    test "increments counter across multiple failures" do
      state = %ConnectionState{status: :connected, health_failures: 0}

      state = ConnectionState.record_health_failure(state, :connection_failed)
      assert state.health_failures == 1

      state = ConnectionState.record_health_failure(state, :connection_failed)
      assert state.health_failures == 2

      state = ConnectionState.record_health_failure(state, :connection_failed)
      assert state.health_failures == 3
    end
  end

  describe "health_failures reset" do
    test "mark_connected/2 resets health_failures" do
      state = %ConnectionState{status: :connected, health_failures: 2}

      new_state = ConnectionState.mark_connected(state, %{"version" => "1.0"})

      assert new_state.health_failures == 0
    end

    test "mark_disconnected/1 resets health_failures" do
      state = %ConnectionState{status: :connected, health_failures: 2}

      new_state = ConnectionState.mark_disconnected(state)

      assert new_state.health_failures == 0
    end

    test "mark_needs_config/1 resets health_failures" do
      state = %ConnectionState{status: :error, health_failures: 2}

      new_state = ConnectionState.mark_needs_config(state)

      assert new_state.health_failures == 0
    end
  end
end
