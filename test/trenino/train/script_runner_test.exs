defmodule Trenino.Train.ScriptRunnerTest do
  use Trenino.DataCase, async: true

  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.ScriptEngine
  alias Trenino.Train.ScriptRunner
  alias Trenino.Train.ScriptRunner.{ScriptState, State}

  # ScriptRunner is not started in tests, so we test the underlying
  # ScriptEngine integration. The GenServer lifecycle is covered by
  # the OutputController pattern which is already proven.

  describe "script compilation and execution" do
    setup do
      {:ok, train} =
        TrainContext.create_train(%{
          name: "Test Train",
          identifiers: [%{identifier: "test_train"}]
        })

      %{train: train}
    end

    test "scripts are created and retrievable", %{train: train} do
      {:ok, script} =
        TrainContext.create_script(train.id, %{
          name: "Test",
          code: "function on_change(event) print('hello') end",
          triggers: ["Endpoint.A"]
        })

      assert script.name == "Test"
      assert script.triggers == ["Endpoint.A"]
      assert script.enabled == true
    end

    test "disabled scripts are filtered out", %{train: train} do
      {:ok, _} =
        TrainContext.create_script(train.id, %{
          name: "Enabled",
          code: "function on_change(event) end",
          enabled: true
        })

      {:ok, _} =
        TrainContext.create_script(train.id, %{
          name: "Disabled",
          code: "function on_change(event) end",
          enabled: false
        })

      enabled = TrainContext.list_enabled_scripts(train.id)
      assert length(enabled) == 1
      assert hd(enabled).name == "Enabled"
    end
  end

  describe "display.set" do
    test "script display.set on an input chip address warns and does not crash" do
      {:ok, device} = Trenino.Hardware.create_device(%{name: "Dev"})

      {:ok, _} =
        Trenino.Hardware.create_i2c_module(device.id, %{
          module_chip: :mcp23017,
          i2c_address: 0x20,
          params: %{direct_mask: 1, row_mask: 0, col_mask: 0}
        })

      {:ok, lua} =
        ScriptEngine.new("function on_change(event) display.set(32, 'hi') end")

      script_state = %ScriptState{
        script: %Trenino.Train.Script{id: 1, name: "S"},
        lua: lua
      }

      state = %State{scripts: %{1 => script_state}}

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          assert {:noreply, _} =
                   ScriptRunner.handle_info({:scheduled_run, 1}, state)
        end)

      assert log =~ "No i2c module found at address 32"
    end
  end
end
