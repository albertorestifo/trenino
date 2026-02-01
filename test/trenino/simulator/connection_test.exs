defmodule Trenino.Simulator.ConnectionTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Trenino.Simulator.AutoConfig
  alias Trenino.Simulator.Config
  alias Trenino.Simulator.Connection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train.Identifier

  setup :set_mimic_global
  setup :verify_on_exit!

  @url "http://localhost:31270"
  @api_key "test-api-key"

  setup do
    # Mock AutoConfig to return a valid config
    stub(AutoConfig, :ensure_config, fn ->
      {:ok, %Config{url: @url, api_key: @api_key}}
    end)

    # Default stub: all Req requests succeed (handles background health checks, polls, etc.)
    stub(Req, :request, fn _req, _opts ->
      {:ok, %Req.Response{status: 200, body: %{"commands" => ["info"]}}}
    end)

    # Prevent Detection from consuming Req expects via Identifier calls
    stub(Identifier, :derive_from_formation, fn _client ->
      {:error, :stubbed_for_connection_test}
    end)

    # Subscribe to connection state changes
    Connection.subscribe()

    # Start Connection GenServer
    pid = start_supervised!({Connection, []})

    # Wait for initial connection to succeed (async task completes)
    assert_receive {:simulator_status_changed, %ConnectionState{status: :connected}}, 3_000

    # Drain any additional status messages from startup
    drain_status_messages()

    {:ok, pid: pid}
  end

  defp drain_status_messages do
    receive do
      {:simulator_status_changed, _} -> drain_status_messages()
    after
      100 -> :ok
    end
  end

  describe "health check tolerance" do
    test "single transient failure does not change status to error" do
      expect(Req, :request, fn _req, _opts ->
        {:error, %Mint.TransportError{reason: :timeout}}
      end)

      send(Process.whereis(Connection), :health_check)
      Process.sleep(100)

      state = Connection.get_status()
      assert state.status == :connected
      assert state.health_failures == 1
    end

    test "3 consecutive failures trigger error broadcast" do
      expect(Req, :request, 3, fn _req, _opts ->
        {:error, %Mint.TransportError{reason: :timeout}}
      end)

      # Trigger health checks manually. After each transient failure with
      # health_failures < 3, a fast health check (2s) is scheduled.
      # We send manually to avoid waiting.
      send(Process.whereis(Connection), :health_check)
      Process.sleep(100)
      send(Process.whereis(Connection), :health_check)
      Process.sleep(100)
      send(Process.whereis(Connection), :health_check)

      assert_receive {:simulator_status_changed, %ConnectionState{status: :error}}, 1_000
    end

    test "invalid_key error is permanent and triggers immediate error" do
      expect(Req, :request, fn _req, _opts ->
        {:ok,
         %Req.Response{
           status: 403,
           body: %{"errorCode" => "dtg.comm.InvalidKey"}
         }}
      end)

      send(Process.whereis(Connection), :health_check)

      assert_receive {:simulator_status_changed, %ConnectionState{status: :error}}, 1_000

      state = Connection.get_status()
      assert state.last_error == :invalid_key
    end

    test "recovery after failures resets counter" do
      # First health check fails
      expect(Req, :request, fn _req, _opts ->
        {:error, %Mint.TransportError{reason: :timeout}}
      end)

      send(Process.whereis(Connection), :health_check)
      Process.sleep(100)

      state = Connection.get_status()
      assert state.health_failures == 1

      # Second health check succeeds (expect takes priority over stub)
      expect(Req, :request, fn _req, _opts ->
        {:ok, %Req.Response{status: 200, body: %{"commands" => ["info"]}}}
      end)

      send(Process.whereis(Connection), :health_check)
      Process.sleep(100)

      state = Connection.get_status()
      assert state.status == :connected
      assert state.health_failures == 0
    end
  end
end
