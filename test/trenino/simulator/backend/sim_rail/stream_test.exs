defmodule Trenino.Simulator.Backend.SimRail.StreamTest do
  # A real WebSocket server on a random loopback port stands in for the bridge.
  use Trenino.DataCase, async: true

  alias Trenino.SimRailFixtures
  alias Trenino.Simulator.Backend.SimRail
  alias Trenino.Simulator.Backend.SimRail.Stream

  defmodule FakeBridge do
    @moduledoc false
    @behaviour WebSock

    @impl true
    def init(%{test: test} = state) do
      send(test, {:bridge_connected, self(), state.authorization})
      {:push, {:text, Jason.encode!(%{op: "hello", api: "1", bridge: "test"})}, state}
    end

    @impl true
    def handle_in({text, opcode: :text}, state) do
      send(state.test, {:bridge_received, Jason.decode!(text)})
      {:ok, state}
    end

    @impl true
    def handle_info({:push, message}, state), do: {:push, {:text, Jason.encode!(message)}, state}
    def handle_info(:close, state), do: {:stop, :normal, state}
  end

  defmodule FakeBridgePlug do
    @moduledoc false
    @behaviour Plug

    @impl true
    def init(test), do: test

    @impl true
    def call(%Plug.Conn{request_path: "/api/v1/stream"} = conn, test) do
      authorization = conn |> Plug.Conn.get_req_header("authorization") |> List.first()

      conn
      |> WebSockAdapter.upgrade(FakeBridge, %{test: test, authorization: authorization}, [])
      |> Plug.Conn.halt()
    end
  end

  setup do
    server =
      start_supervised!(
        {Bandit, plug: {FakeBridgePlug, self()}, ip: :loopback, port: 0, startup_log: false}
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)
    %{port: port}
  end

  defp connect(port, api_key \\ nil) do
    {:ok, handle} =
      SimRail.connect(%{
        url: "http://127.0.0.1:#{port}",
        api_key: api_key,
        stream_opts: [backoff_ms: 10, max_backoff_ms: 50]
      })

    on_exit(fn -> SimRail.disconnect(handle) end)
    handle
  end

  # Wait for the stream to connect, then answer its subscribe with `values`.
  defp await_subscribe(values \\ %{}) do
    assert_receive {:bridge_connected, bridge, _auth}, 1_000
    assert_receive {:bridge_received, %{"op" => "subscribe", "id" => id} = request}, 1_000
    send(bridge, {:push, %{id: id, ok: true, values: values}})
    {bridge, request}
  end

  # A watcher process that forwards everything it receives to the test.
  defp watcher do
    test = self()
    spawn_link(fn -> forward(test) end)
  end

  defp forward(test) do
    receive do
      :stop ->
        :ok

      message ->
        send(test, {:watcher, self(), message})
        forward(test)
    end
  end

  test "subscribes the watched paths and delivers current and pushed values", %{port: port} do
    handle = connect(port)
    path = "Physics_Input_EN57.maincontroller_a"

    assert SimRail.watch(handle, [path], self()) == :ok

    {bridge, request} = await_subscribe(%{path => 2})
    assert request["paths"] == [path]
    assert request["maxHz"] == 30

    assert_receive {:simulator_values, %{^path => 2.0}}, 1_000

    send(bridge, {:push, %{op: "values", t: 1, values: %{path => 3, "Other.value" => 1}}})
    assert_receive {:simulator_values, values}, 1_000
    assert values == %{path => 3.0}
  end

  test "sends the token on the upgrade when set", %{port: port} do
    handle = connect(port, "secret")
    :ok = SimRail.watch(handle, ["A.b"], self())

    assert_receive {:bridge_connected, _bridge, "Bearer secret"}, 1_000
  end

  test "no token, no authorization header", %{port: port} do
    handle = connect(port)
    :ok = SimRail.watch(handle, ["A.b"], self())

    assert_receive {:bridge_connected, _bridge, nil}, 1_000
  end

  test "delivers each watcher only its own paths, patterns included", %{port: port} do
    handle = connect(port)
    other = watcher()

    :ok = SimRail.watch(handle, ["Physics_Output_EN57.velocity"], self())
    {bridge, _} = await_subscribe()

    :ok = SimRail.watch(handle, ["Physics_Input_EN57.*"], other)

    assert_receive {:bridge_received,
                    %{"op" => "subscribe", "paths" => ["Physics_Input_EN57.*"]}},
                   1_000

    send(
      bridge,
      {:push,
       %{
         op: "values",
         values: %{"Physics_Output_EN57.velocity" => 12.5, "Physics_Input_EN57.mainbrake_a" => 4}
       }}
    )

    assert_receive {:simulator_values, mine}, 1_000
    assert mine == %{"Physics_Output_EN57.velocity" => 12.5}

    assert_receive {:watcher, ^other, {:simulator_values, theirs}}, 1_000
    assert theirs == %{"Physics_Input_EN57.mainbrake_a" => 4.0}
  end

  test "replacing and clearing the watched set unsubscribes unused paths", %{port: port} do
    handle = connect(port)

    :ok = SimRail.watch(handle, ["A.a", "A.b"], self())
    await_subscribe()

    :ok = SimRail.watch(handle, ["A.b", "A.c"], self())
    assert_receive {:bridge_received, %{"op" => "unsubscribe", "paths" => ["A.a"]}}, 1_000
    assert_receive {:bridge_received, %{"op" => "subscribe", "paths" => ["A.c"]}}, 1_000

    :ok = SimRail.watch(handle, [], self())
    assert_receive {:bridge_received, %{"op" => "unsubscribe", "paths" => paths}}, 1_000
    assert Enum.sort(paths) == ["A.b", "A.c"]
  end

  test "keeps paths another watcher still wants", %{port: port} do
    handle = connect(port)
    other = watcher()

    :ok = SimRail.watch(handle, ["A.a"], self())
    await_subscribe()
    :ok = SimRail.watch(handle, ["A.a"], other)
    assert_receive {:bridge_received, %{"op" => "subscribe", "paths" => ["A.a"]}}, 1_000

    :ok = SimRail.watch(handle, [], self())
    refute_receive {:bridge_received, %{"op" => "unsubscribe"}}, 100
  end

  test "drops a watcher that exits", %{port: port} do
    handle = connect(port)
    other = watcher()

    :ok = SimRail.watch(handle, ["A.a"], other)
    await_subscribe()

    send(other, :stop)
    assert_receive {:bridge_received, %{"op" => "unsubscribe", "paths" => ["A.a"]}}, 1_000
  end

  test "reports vehicle changes with the vehicle name", %{port: port} do
    handle = connect(port)
    :ok = SimRail.watch(handle, ["Physics_Input_General.*"], self())
    {bridge, _} = await_subscribe()

    eu07 = SimRailFixtures.schema("4e_eu07-193")
    send(bridge, {:push, %{op: "vehicle", vehicle: eu07}})
    assert_receive {:simulator_vehicle, "4e/eu07-193"}, 1_000

    # Watchers reset on vehicle messages: current values are requested again.
    assert_receive {:bridge_received,
                    %{"op" => "subscribe", "paths" => ["Physics_Input_General.*"]}},
                   1_000

    # The same vehicle again is not a change.
    send(bridge, {:push, %{op: "vehicle", vehicle: eu07}})
    refute_receive {:simulator_vehicle, _}, 100

    # A new vehicle: reported, and the watched paths are resubscribed for fresh values.
    send(bridge, {:push, %{op: "vehicle", vehicle: SimRailFixtures.schema("en57_en57-047")}})
    assert_receive {:simulator_vehicle, "en57/en57-047"}, 1_000

    assert_receive {:bridge_received,
                    %{"op" => "subscribe", "paths" => ["Physics_Input_General.*"]}},
                   1_000

    send(bridge, {:push, %{op: "vehicle", vehicle: nil}})
    assert_receive {:simulator_vehicle, nil}, 1_000
  end

  test "tells a new watcher the current vehicle", %{port: port} do
    handle = connect(port)
    :ok = SimRail.watch(handle, ["A.a"], self())
    {bridge, _} = await_subscribe()

    send(bridge, {:push, %{op: "vehicle", vehicle: SimRailFixtures.schema("en57_en57-047")}})
    assert_receive {:simulator_vehicle, "en57/en57-047"}, 1_000

    other = watcher()
    :ok = SimRail.watch(handle, ["A.b"], other)

    assert_receive {:watcher, ^other, {:simulator_vehicle, "en57/en57-047"}}, 1_000
  end

  test "reconnects after the connection drops and resubscribes", %{port: port} do
    handle = connect(port)
    :ok = SimRail.watch(handle, ["A.a"], self())
    {bridge, _} = await_subscribe(%{"A.a" => 1})
    assert_receive {:simulator_values, %{"A.a" => 1.0}}, 1_000

    send(bridge, :close)

    {_bridge, request} = await_subscribe(%{"A.a" => 5})
    assert request["paths"] == ["A.a"]
    assert_receive {:simulator_values, %{"A.a" => 5.0}}, 1_000
  end

  test "keeps retrying until the bridge comes up" do
    {:ok, listener} = :gen_tcp.listen(0, ip: {127, 0, 0, 1})
    {:ok, port} = :inet.port(listener)
    :ok = :gen_tcp.close(listener)

    handle = connect(port)
    :ok = SimRail.watch(handle, ["A.a"], self())
    stream = Stream.whereis(handle.ref)
    assert %Stream.State{status: :disconnected} = :sys.get_state(stream)

    start_supervised!(
      {Bandit, plug: {FakeBridgePlug, self()}, ip: :loopback, port: port, startup_log: false},
      id: :late_bridge
    )

    {_bridge, request} = await_subscribe()
    assert request["paths"] == ["A.a"]
  end

  test "gives up on an upgrade the bridge never answers and reconnects" do
    {:ok, listener} = :gen_tcp.listen(0, ip: {127, 0, 0, 1}, active: false)
    {:ok, port} = :inet.port(listener)

    {:ok, handle} =
      SimRail.connect(%{
        url: "http://127.0.0.1:#{port}",
        api_key: nil,
        stream_opts: [backoff_ms: 10, max_backoff_ms: 50, upgrade_timeout_ms: 50]
      })

    on_exit(fn -> SimRail.disconnect(handle) end)
    :ok = SimRail.watch(handle, ["A.a"], self())

    # Accept and never answer; the stream must come back with a new socket.
    assert {:ok, first} = :gen_tcp.accept(listener, 1_000)
    assert {:ok, second} = :gen_tcp.accept(listener, 1_000)
    assert first != second
  end

  test "exposes the stream pid so watchers can monitor it", %{port: port} do
    handle = connect(port)
    refute SimRail.watch_process(handle)

    :ok = SimRail.watch(handle, ["A.a"], self())
    assert is_pid(SimRail.watch_process(handle))
    assert SimRail.watch_process(handle) == Stream.whereis(handle.ref)
  end

  test "keeps the token out of the stream state's inspect output", %{port: port} do
    handle = connect(port, "secret-token")
    :ok = SimRail.watch(handle, ["A.a"], self())

    refute handle |> SimRail.watch_process() |> :sys.get_state() |> inspect() =~ "secret-token"
  end

  test "one stream per handle, stopped by disconnect", %{port: port} do
    handle = connect(port)
    refute Stream.whereis(handle.ref)

    :ok = SimRail.watch(handle, ["A.a"], self())
    stream = Stream.whereis(handle.ref)
    :ok = SimRail.watch(handle, ["A.b"], self())
    assert Stream.whereis(handle.ref) == stream

    ref = Process.monitor(stream)
    assert SimRail.disconnect(handle) == :ok
    assert_receive {:DOWN, ^ref, :process, ^stream, _}, 1_000
    refute Stream.whereis(handle.ref)
  end

  test "watching nothing does not start a stream", %{port: port} do
    handle = connect(port)
    assert SimRail.watch(handle, [], self()) == :ok
    refute Stream.whereis(handle.ref)
  end
end
