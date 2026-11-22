defmodule Trenino.Train.ScriptRunnerServerTest do
  use Trenino.DataCase, async: false

  alias Trenino.Hardware
  alias Trenino.Serial.Connection
  alias Trenino.Simulator
  alias Trenino.Simulator.{Client, ConnectionState, Watcher}
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.ScriptRunner

  setup :set_mimic_global

  setup do
    {:ok, device} = Hardware.create_device(%{name: "Panel"})
    {:ok, output} = Hardware.create_output(device.id, %{pin: 13})

    {:ok, train} =
      TrainContext.create_train(%{name: "Script Train", identifiers: [%{identifier: "script"}]})

    {:ok, script} =
      TrainContext.create_script(train.id, %{
        name: "Lamp",
        code: "function on_change(event) output.set(#{output.id}, true) end",
        triggers: []
      })

    test_pid = self()

    Mimic.stub(SimulatorConnection, :get_status, fn -> %ConnectionState{status: :disconnected} end)

    Mimic.stub(Connection, :connected_devices, fn ->
      [%{port: "script-port", device_config_id: device.config_id}]
    end)

    Mimic.stub(Hardware, :set_output, fn port, pin, value ->
      send(test_pid, {:set_output, port, pin, value})
      :ok
    end)

    Mimic.stub(Hardware, :get_output, fn id ->
      send(test_pid, {:output_lookup, id})
      Mimic.call_original(Hardware, :get_output, [id])
    end)

    runner = start_supervised!(ScriptRunner)
    send(runner, {:train_changed, train})

    %{runner: runner, output: output, script: script}
  end

  test "output effects look the output up once until a configuration is applied", ctx do
    pin = ctx.output.pin

    ScriptRunner.run_script(ctx.script.id)
    assert_receive {:set_output, "script-port", ^pin, :high}, 500
    ScriptRunner.run_script(ctx.script.id)
    assert_receive {:set_output, "script-port", ^pin, :high}, 500

    assert_received {:output_lookup, _}
    refute_received {:output_lookup, _}

    send(ctx.runner, {:configuration_applied, "script-port", nil, 1})
    ScriptRunner.run_script(ctx.script.id)
    assert_receive {:set_output, "script-port", ^pin, :high}, 500
    assert_received {:output_lookup, _}
  end

  describe "trigger endpoints" do
    setup ctx do
      test_pid = self()

      {:ok, _} =
        TrainContext.update_script(ctx.script, %{
          triggers: ["Speed"],
          code: """
          function on_change(event)
            api.set("Horn", event.value)
            if event.data then api.set("Data", event.data.B) end
          end
          """
        })

      Mimic.stub(Simulator, :set, fn path, value ->
        send(test_pid, {:simulator_set, path, value})
        :ok
      end)

      ScriptRunner.reload_scripts()
      :sys.get_state(ctx.runner)
      :ok
    end

    test "watched values run the script once per change and api.set writes through the facade",
         ctx do
      send(ctx.runner, {:simulator_values, %{"Speed" => 5}})
      assert_receive {:simulator_set, "Horn", 5}, 500

      send(ctx.runner, {:simulator_values, %{"Speed" => 5}})
      refute_receive {:simulator_set, _, _}, 200

      send(ctx.runner, {:simulator_values, %{"Speed" => 6, "Unrelated" => 1}})
      assert_receive {:simulator_set, "Horn", 6}, 500
      refute_receive {:simulator_set, _, _}, 200
    end

    test "an endpoint with several values passes the first as value and all as data", ctx do
      send(ctx.runner, {:simulator_values, %{"Speed" => %{"A" => 1, "B" => 2}}})
      assert_receive {:simulator_set, "Horn", 1}, 500
      assert_receive {:simulator_set, "Data", 2}, 500
    end

    test "the trigger endpoints are watched", ctx do
      Mimic.stub(SimulatorConnection, :get_status, fn ->
        %ConnectionState{status: :connected, client: %Client{base_url: "http://x", api_key: "k"}}
      end)

      Mimic.stub(Simulator, :read, fn paths -> {:ok, Map.new(paths, &{&1, 9})} end)
      start_supervised!(Watcher)
      assert_receive {:simulator_set, "Horn", 9}, 1000
      assert ctx.runner
    end
  end
end
