defmodule Trenino.Train.ScriptRunnerServerTest do
  use Trenino.DataCase, async: false

  alias Trenino.Hardware
  alias Trenino.Serial.Connection
  alias Trenino.Simulator.Connection, as: SimulatorConnection
  alias Trenino.Simulator.ConnectionState
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
end
