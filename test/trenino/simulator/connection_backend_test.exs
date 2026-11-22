defmodule Trenino.Simulator.ConnectionBackendTest do
  @moduledoc """
  `Simulator.Connection` with the backend chosen in settings, using a stub
  backend in place of SimRail.
  """

  use Trenino.SerialSafetyCase, async: false

  alias Trenino.Settings
  alias Trenino.Simulator.Connection
  alias Trenino.Simulator.ConnectionState

  defmodule StubBackend do
    @moduledoc false
    @behaviour Trenino.Simulator.Backend

    # Replies come from the test process, which also receives every call.
    defp test_pid, do: Application.fetch_env!(:trenino, :stub_backend_test_pid)

    defp reply(key, default) do
      :trenino |> Application.get_env(:stub_backend_replies, %{}) |> Map.get(key, default)
    end

    @impl true
    def id, do: :simrail

    @impl true
    def capabilities, do: [:push_values, :control_catalog, :vehicle_events]

    @impl true
    def connect(config) do
      send(test_pid(), {:backend_connect, config})
      reply(:connect, {:ok, {:stub_handle, make_ref()}})
    end

    @impl true
    def check(handle) do
      send(test_pid(), {:backend_check, handle})
      reply(:check, {:ok, %{"bridge" => "0.2.0"}})
    end

    @impl true
    def disconnect(handle) do
      send(test_pid(), {:backend_disconnect, handle})
      :ok
    end

    @impl true
    def get(_handle, _path), do: {:error, :not_implemented}

    @impl true
    def read(_handle, _paths), do: {:ok, %{}}

    @impl true
    def set(_handle, _path, _value), do: :ok

    @impl true
    def vehicle_id(_handle), do: {:ok, "4e/eu07-193"}
  end

  setup :set_mimic_global
  setup :verify_on_exit!

  setup do
    previous_backends = Application.get_env(:trenino, :simulator_backends)
    Application.put_env(:trenino, :simulator_backends, %{simrail: StubBackend})
    Application.put_env(:trenino, :stub_backend_test_pid, self())
    Application.put_env(:trenino, :stub_backend_replies, %{})

    on_exit(fn ->
      restore_env(:simulator_backends, previous_backends)
      Application.delete_env(:trenino, :stub_backend_test_pid)
      Application.delete_env(:trenino, :stub_backend_replies)
    end)

    stub(Settings, :simulator, fn -> :simrail end)
    stub(Settings, :simrail_url, fn -> "http://127.0.0.1:31275" end)
    stub(Settings, :simrail_token, fn -> nil end)

    Connection.subscribe()
    :ok
  end

  defp restore_env(key, nil), do: Application.delete_env(:trenino, key)
  defp restore_env(key, value), do: Application.put_env(:trenino, key, value)

  defp put_reply(key, value) do
    replies = Application.get_env(:trenino, :stub_backend_replies, %{})
    Application.put_env(:trenino, :stub_backend_replies, Map.put(replies, key, value))
  end

  defp start_connected do
    start_supervised!({Connection, []})
    assert_receive {:backend_connect, _config}
    assert_receive {:simulator_status_changed, %ConnectionState{status: :connected}}, 1_000
    assert_receive {:backend_check, handle}
    handle
  end

  test "connects through the chosen backend" do
    handle = start_connected()

    state = Connection.get_status()
    assert state.backend == StubBackend
    assert state.client == handle
    assert state.info == %{"bridge" => "0.2.0"}
  end

  test "passes the stored SimRail URL and token" do
    stub(Settings, :simrail_token, fn -> "bridge-token" end)
    stub(Settings, :simrail_url, fn -> "http://192.168.1.20:31275" end)
    start_supervised!({Connection, []})

    assert_receive {:backend_connect,
                    %{url: "http://192.168.1.20:31275", api_key: "bridge-token"}}
  end

  test "the default config reaches connect/1" do
    start_supervised!({Connection, []})
    assert_receive {:backend_connect, %{url: "http://127.0.0.1:31275", api_key: nil}}
  end

  test "needs configuration only when the SimRail URL is missing" do
    stub(Settings, :simrail_url, fn -> "  " end)
    start_supervised!({Connection, []})

    assert_receive {:simulator_status_changed, %ConnectionState{status: :needs_config}}, 1_000
    refute_received {:backend_connect, _}
  end

  test "a rejected token is reported as an invalid key" do
    put_reply(:check, {:error, :unauthorized})
    start_supervised!({Connection, []})

    assert_receive {:simulator_status_changed,
                    %ConnectionState{status: :error, last_error: :invalid_key}},
                   1_000
  end

  test "an unreachable bridge is a connection failure" do
    put_reply(:check, {:error, :econnrefused})
    start_supervised!({Connection, []})

    assert_receive {:simulator_status_changed,
                    %ConnectionState{status: :error, last_error: :connection_failed}},
                   1_000
  end

  test "health checks use check/1 and tolerate transient failures" do
    handle = start_connected()

    put_reply(:check, {:error, :timeout})
    send(Process.whereis(Connection), :health_check)
    assert_receive {:backend_check, ^handle}

    state = Connection.get_status()
    assert state.status == :connected
    assert state.health_failures == 1

    put_reply(:check, {:ok, %{"bridge" => "0.2.0"}})
    send(Process.whereis(Connection), :health_check)
    assert_receive {:backend_check, ^handle}
    assert %ConnectionState{status: :connected, health_failures: 0} = Connection.get_status()
  end

  test "disconnect releases the handle" do
    handle = start_connected()

    Connection.disconnect()

    assert_receive {:backend_disconnect, ^handle}
    assert_receive {:simulator_status_changed, %ConnectionState{status: :disconnected}}, 1_000
    assert Connection.get_status().client == nil
  end

  test "reconfigure releases the handle and connects again" do
    handle = start_connected()

    Connection.reconfigure()

    assert_receive {:backend_disconnect, ^handle}
    assert_receive {:backend_connect, _config}, 1_000
    assert_receive {:simulator_status_changed, %ConnectionState{status: :connected}}, 1_000
    assert_receive {:backend_check, new_handle}
    refute new_handle == handle
  end
end
