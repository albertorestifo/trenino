defmodule Trenino.Train.ActionExecutorTest do
  use Trenino.DataCase, async: true

  alias Trenino.Keyboard
  alias Trenino.Simulator.Client
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
  alias Trenino.Train.{Action, ActionExecutor}

  @client %Client{base_url: "http://localhost:31270", api_key: "test"}

  setup do
    test_pid = self()

    stub(SimulatorConnection, :get_status, fn ->
      %ConnectionState{status: :connected, client: @client}
    end)

    stub(Client, :set, fn @client, endpoint, value ->
      send(test_pid, {:set, endpoint, value})
      {:ok, %{"Result" => "Success"}}
    end)

    stub(Keyboard, :tap, fn keystroke ->
      send(test_pid, {:tap, keystroke})
      :ok
    end)

    :ok
  end

  defp sequence(commands), do: %Action{kind: :sequence, commands: commands}

  describe "run/2" do
    test "sets a simulator value" do
      assert :ok = ActionExecutor.run(%Action{kind: :set_value, endpoint: "A", value: 1.0})
      assert_received {:set, "A", 1.0}
    end

    test "taps a keystroke" do
      assert :ok = ActionExecutor.run(%Action{kind: :keystroke, keystroke: "L"})
      assert_received {:tap, "L"}
    end

    test "returns the keystroke error" do
      stub(Keyboard, :tap, fn _ -> {:error, :keystroke_not_found} end)

      assert {:error, :keystroke_not_found} =
               ActionExecutor.run(%Action{kind: :keystroke, keystroke: "L"})
    end

    test "returns not_connected when the simulator is down" do
      stub(SimulatorConnection, :get_status, fn -> ConnectionState.new() end)

      assert {:error, :not_connected} =
               ActionExecutor.run(%Action{kind: :set_value, endpoint: "A", value: 1.0})

      refute_received {:set, _, _}
    end

    test "returns the simulator error" do
      stub(Client, :set, fn _, _, _ -> {:error, :timeout} end)

      assert {:error, :timeout} =
               ActionExecutor.run(%Action{kind: :set_value, endpoint: "A", value: 1.0})
    end

    test "runs sequence commands in order with their delays" do
      action =
        sequence([
          %{endpoint: "A", value: 1.0, delay_ms: 30},
          %{endpoint: "B", value: 2.0, delay_ms: 0}
        ])

      started = System.monotonic_time(:millisecond)
      assert :ok = ActionExecutor.run(action)

      assert System.monotonic_time(:millisecond) - started >= 30
      assert_received {:set, "A", 1.0}
      assert_received {:set, "B", 2.0}
    end

    test "keeps running a sequence after a failed command" do
      stub(Client, :set, fn
        _, "A", _ ->
          {:error, :timeout}

        _, endpoint, value ->
          send(self(), {:set, endpoint, value})
          {:ok, %{}}
      end)

      action =
        sequence([
          %{endpoint: "A", value: 1.0, delay_ms: 0},
          %{endpoint: "B", value: 2.0, delay_ms: 0}
        ])

      assert {:error, :timeout} = ActionExecutor.run(action)
      assert_received {:set, "B", 2.0}
    end

    test "skips a command without an endpoint" do
      action = sequence([%{endpoint: nil, value: 1.0, delay_ms: 0}])

      assert {:error, :invalid_command} = ActionExecutor.run(action)
      refute_received {:set, _, _}
    end

    test "stops a sequence when its owner goes down" do
      owner = spawn(fn -> Process.sleep(:infinity) end)

      action =
        sequence([
          %{endpoint: "A", value: 1.0, delay_ms: 200},
          %{endpoint: "B", value: 2.0, delay_ms: 0}
        ])

      task = Task.async(fn -> ActionExecutor.run(action, owner: owner) end)

      assert_receive {:set, "A", 1.0}
      Process.exit(owner, :kill)

      assert {:error, :owner_down} = Task.await(task)
      refute_received {:set, "B", _}
    end
  end

  describe "run_all/2" do
    test "runs every action in order" do
      actions = [
        %Action{kind: :keystroke, keystroke: "X"},
        %Action{kind: :set_value, endpoint: "A", value: 1.0}
      ]

      assert :ok = ActionExecutor.run_all(actions)

      assert_received {:tap, "X"}
      assert_received {:set, "A", 1.0}
    end

    test "continues after a failure and returns the error" do
      stub(Keyboard, :tap, fn _ -> {:error, :boom} end)

      actions = [
        %Action{kind: :keystroke, keystroke: "X"},
        %Action{kind: :set_value, endpoint: "A", value: 1.0}
      ]

      assert {:error, :boom} = ActionExecutor.run_all(actions)
      assert_received {:set, "A", 1.0}
    end

    test "returns :ok for no actions" do
      assert :ok = ActionExecutor.run_all([])
    end
  end
end
