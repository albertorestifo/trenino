defmodule Trenino.Simulator.WatcherTest do
  use Trenino.DataCase, async: false

  alias Trenino.Simulator
  alias Trenino.Simulator.{Backend, Client, ConnectionState, Watcher}

  setup :set_mimic_global

  defmodule PushBackend do
    @moduledoc false
    # Reports every watch/3 call to the test process named in the handle.
    def id, do: :simrail
    def capabilities, do: [:push_values, :vehicle_events]

    # `{:test, owner, stream}`: also names `stream` as the process serving the
    # watches. `{:failing, owner}`: watch/3 fails while the owner's
    # `:fail_watch` flag in `:persistent_term` is set.
    def watch({:failing, owner}, paths, pid) do
      send(owner, {:backend_watch, paths, pid})

      if :persistent_term.get({__MODULE__, owner}, false),
        do: {:error, :offline},
        else: :ok
    end

    def watch(handle, paths, pid) do
      send(elem(handle, 1), {:backend_watch, paths, pid})
      :ok
    end

    def watch_process({:test, _owner, stream}), do: stream
    def watch_process(_handle), do: nil
  end

  defp tsw_connected,
    do: %ConnectionState{
      status: :connected,
      backend: Backend.TSW,
      client: %Client{base_url: "http://fake", api_key: "fake"}
    }

  defp push_connected(owner),
    do: %ConnectionState{status: :connected, backend: PushBackend, client: {:test, owner}}

  defp watcher_with(status) do
    Mimic.stub(Simulator.Connection, :get_status, fn -> status end)
    start_supervised!(Watcher)
  end

  describe "polling backends" do
    setup do
      owner = self()

      Mimic.stub(Simulator, :read, fn paths ->
        send(owner, {:read, paths})
        {:ok, Map.new(paths, &{&1, 1.5})}
      end)

      :ok
    end

    test "every watcher gets its own paths from one shared poll" do
      watcher_with(tsw_connected())
      owner = self()

      other =
        spawn_link(fn ->
          Watcher.watch(["B", "C"])
          send(owner, :other_watching)

          receive do
            {:simulator_values, values} -> send(owner, {:other_got, values})
          end

          Process.sleep(:infinity)
        end)

      assert_receive :other_watching
      :ok = Watcher.watch(["A", "B"])

      assert_receive {:read, ["A", "B", "C"]}, 500
      assert_receive {:simulator_values, %{"A" => 1.5, "B" => 1.5} = mine}, 500
      refute Map.has_key?(mine, "C")
      assert_receive {:other_got, theirs}
      refute Map.has_key?(theirs, "A")
      assert Process.alive?(other)
    end

    test "unchanged values keep arriving on every poll" do
      watcher_with(tsw_connected())
      :ok = Watcher.watch(["A"])
      assert_receive {:simulator_values, %{"A" => 1.5}}, 500
      assert_receive {:simulator_values, %{"A" => 1.5}}, 500
    end

    test "a path the simulator cannot read is left out" do
      Mimic.stub(Simulator, :read, fn _paths -> {:ok, %{"A" => 2}} end)
      watcher_with(tsw_connected())
      :ok = Watcher.watch(["A", "Missing"])
      assert_receive {:simulator_values, values}, 500
      assert values == %{"A" => 2}
    end

    test "unwatch, and the watcher exiting, stop polling those paths" do
      pid = watcher_with(tsw_connected())
      owner = self()

      other =
        spawn(fn ->
          Watcher.watch(["B"])
          send(owner, :ok)
          Process.sleep(:infinity)
        end)

      assert_receive :ok
      :ok = Watcher.watch(["A"])
      assert_receive {:read, ["A", "B"]}, 500

      Process.exit(other, :kill)
      :ok = Watcher.unwatch(["A"])
      :ok = Watcher.watch(["Z"])
      # Older reads stay in the mailbox; the pattern skips them.
      assert_receive {:read, ["Z"]}, 1000

      # With nothing watched there is nothing left to poll.
      :ok = Watcher.unwatch_all()
      assert %{watchers: watchers, values: values} = :sys.get_state(pid)
      assert watchers == %{}
      assert values == %{}
    end

    test "nothing is polled while the simulator is disconnected, and polling resumes on connect" do
      pid = watcher_with(%ConnectionState{status: :disconnected})
      :ok = Watcher.watch(["A"])
      refute_receive {:read, _}, 400

      send(pid, {:simulator_status_changed, tsw_connected()})
      assert_receive {:simulator_values, %{"A" => 1.5}}, 500
    end

    test "a path that becomes unreadable is not handed to new watchers" do
      readable = start_supervised!({Agent, fn -> true end}, id: :readable)

      Mimic.stub(Simulator, :read, fn paths ->
        if Agent.get(readable, & &1), do: {:ok, Map.new(paths, &{&1, 1})}, else: {:ok, %{}}
      end)

      pid = watcher_with(tsw_connected())
      :ok = Watcher.watch(["A"])
      assert_receive {:simulator_values, %{"A" => 1}}, 500

      Agent.update(readable, fn _ -> false end)
      # Wait for a poll that started after the path became unreadable.
      wait_until(fn -> :sys.get_state(pid).values == %{} end)

      owner = self()

      spawn_link(fn ->
        Watcher.watch(["A"])
        send(owner, {:new_watcher_mailbox, Process.info(self(), :messages)})
      end)

      assert_receive {:new_watcher_mailbox, {:messages, []}}, 200
    end

    test "a failed poll delivers nothing and the next one is tried" do
      counter = start_supervised!({Agent, fn -> 0 end})

      Mimic.stub(Simulator, :read, fn paths ->
        if Agent.get_and_update(counter, &{&1, &1 + 1}) == 0,
          do: {:error, :timeout},
          else: {:ok, Map.new(paths, &{&1, 3})}
      end)

      watcher_with(tsw_connected())
      :ok = Watcher.watch(["A"])
      assert_receive {:simulator_values, %{"A" => 3}}, 1000
    end
  end

  describe "push backends" do
    test "the watched set is handed to the backend and pushes are forwarded" do
      pid = watcher_with(push_connected(self()))
      :ok = Watcher.watch(["A", "B"])
      assert_receive {:backend_watch, ["A", "B"], ^pid}, 500

      send(pid, {:simulator_values, %{"A" => 1, "Unwatched" => 2}})
      assert_receive {:simulator_values, %{"A" => 1} = values}, 200
      refute Map.has_key?(values, "Unwatched")

      :ok = Watcher.unwatch(["A"])
      assert_receive {:backend_watch, ["B"], ^pid}, 200
    end

    test "known values are repeated on every tick, and given at once to a new watcher" do
      pid = watcher_with(push_connected(self()))
      :ok = Watcher.watch(["A"])
      send(pid, {:simulator_values, %{"A" => 1}})
      assert_receive {:simulator_values, %{"A" => 1}}, 200
      assert_receive {:simulator_values, %{"A" => 1}}, 500

      owner = self()

      spawn_link(fn ->
        Watcher.watch(["A"])

        receive do
          {:simulator_values, values} -> send(owner, {:new_watcher_got, values})
        end
      end)

      assert_receive {:new_watcher_got, %{"A" => 1}}, 100
    end

    test "a reconnect and a vehicle change hand the paths to the backend again" do
      Watcher.subscribe()
      pid = watcher_with(push_connected(self()))
      assert_receive :simulator_watcher_started
      :ok = Watcher.watch(["A"])
      assert_receive {:backend_watch, ["A"], ^pid}, 200

      send(pid, {:simulator_vehicle, "4e/eu07-193"})
      assert_receive {:simulator_vehicle, "4e/eu07-193"}, 200
      assert_receive {:backend_watch, ["A"], ^pid}, 200

      send(pid, {:simulator_status_changed, %ConnectionState{status: :error}})
      send(pid, {:simulator_status_changed, push_connected(self())})
      assert_receive {:backend_watch, ["A"], ^pid}, 200
    end

    test "the same connection reported again does not re-watch" do
      pid = watcher_with(push_connected(self()))
      :ok = Watcher.watch(["A"])
      assert_receive {:backend_watch, ["A"], ^pid}, 200
      send(pid, {:simulator_status_changed, push_connected(self())})
      refute_receive {:backend_watch, _, _}, 300
    end

    test "when the process serving the push stops, the paths are pushed again" do
      stream = spawn(fn -> Process.sleep(:infinity) end)

      status = %ConnectionState{
        status: :connected,
        backend: PushBackend,
        client: {:test, self(), stream}
      }

      pid = watcher_with(status)
      :ok = Watcher.watch(["A"])
      assert_receive {:backend_watch, ["A"], ^pid}, 200
      assert %{watch_ref: ref} = :sys.get_state(pid)
      assert is_reference(ref)

      Process.exit(stream, :kill)
      assert_receive {:backend_watch, ["A"], ^pid}, 1000
    end

    test "after a failed push, an emptied watch set is still sent to the backend" do
      owner = self()
      on_exit(fn -> :persistent_term.erase({PushBackend, owner}) end)
      :persistent_term.put({PushBackend, owner}, true)

      status = %ConnectionState{
        status: :connected,
        backend: PushBackend,
        client: {:failing, owner}
      }

      pid = watcher_with(status)
      :ok = Watcher.watch(["A"])
      assert_receive {:backend_watch, ["A"], ^pid}, 200
      assert %{pushed: nil} = :sys.get_state(pid)

      :ok = Watcher.unwatch_all()
      assert_receive {:backend_watch, [], ^pid}, 200
    end
  end

  # Checks `check` up to 50 times, 20 ms apart; always ends.
  defp wait_until(check, attempts \\ 50) do
    cond do
      check.() ->
        :ok

      attempts == 0 ->
        flunk("condition not reached")

      true ->
        receive do
        after
          20 -> wait_until(check, attempts - 1)
        end
    end
  end

  test "calls are no-ops when the watcher is not running" do
    assert :ok = Watcher.watch(["A"])
    assert :ok = Watcher.unwatch(["A"])
    assert :ok = Watcher.unwatch_all()
  end
end
