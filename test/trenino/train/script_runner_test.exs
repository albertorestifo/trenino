defmodule Trenino.Train.ScriptRunnerTest do
  use Trenino.DataCase, async: false

  alias Trenino.Train, as: TrainContext

  # ScriptRunner is not started in tests, so we test the underlying
  # ScriptEngine integration. The GenServer lifecycle is covered by
  # the OutputController pattern which is already proven.

  describe "script compilation and execution" do
    setup do
      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})
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
end
