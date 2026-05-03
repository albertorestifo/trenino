defmodule Trenino.MCP.Tools.ScriptToolsTest do
  use Trenino.DataCase, async: true

  alias Trenino.MCP.Tools.ScriptTools
  alias Trenino.Train, as: TrainContext

  @sample_code ~s|function on_change(event)\n  print(event.value)\nend|

  setup do
    {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})
    %{train: train}
  end

  describe "tools/0" do
    test "returns 5 tool definitions" do
      assert length(ScriptTools.tools()) == 5
    end

    test "all tools have required fields" do
      for tool <- ScriptTools.tools() do
        assert Map.has_key?(tool, :name)
        assert Map.has_key?(tool, :description)
        assert Map.has_key?(tool, :input_schema)
      end
    end
  end

  describe "list_scripts" do
    test "returns empty list when no scripts", %{train: train} do
      assert {:ok, %{scripts: []}} =
               ScriptTools.execute("list_scripts", %{"train_id" => train.id})
    end

    test "returns all scripts for a train", %{train: train} do
      {:ok, _} = TrainContext.create_script(train.id, %{name: "Script A", code: @sample_code})
      {:ok, _} = TrainContext.create_script(train.id, %{name: "Script B", code: @sample_code})

      assert {:ok, %{scripts: scripts}} =
               ScriptTools.execute("list_scripts", %{"train_id" => train.id})

      assert length(scripts) == 2
      names = Enum.map(scripts, & &1.name)
      assert "Script A" in names
      assert "Script B" in names
    end

    test "does not include code in list response", %{train: train} do
      {:ok, _} = TrainContext.create_script(train.id, %{name: "Script A", code: @sample_code})

      assert {:ok, %{scripts: [script]}} =
               ScriptTools.execute("list_scripts", %{"train_id" => train.id})

      refute Map.has_key?(script, :code)
    end
  end

  describe "get_script" do
    test "returns script with full code", %{train: train} do
      {:ok, created} =
        TrainContext.create_script(train.id, %{
          name: "Speed Warning",
          code: @sample_code,
          triggers: ["CurrentDrivableActor.Function.HUD_GetSpeed"]
        })

      assert {:ok, %{script: script}} =
               ScriptTools.execute("get_script", %{"id" => created.id})

      assert script.name == "Speed Warning"
      assert script.code == @sample_code
      assert script.triggers == ["CurrentDrivableActor.Function.HUD_GetSpeed"]
      assert script.enabled == true
    end

    test "returns error for missing script" do
      assert {:error, message} = ScriptTools.execute("get_script", %{"id" => -1})
      assert message =~ "not found"
    end
  end

  describe "create_script" do
    test "creates a script with all fields", %{train: train} do
      args = %{
        "train_id" => train.id,
        "name" => "Speed Warning",
        "code" => @sample_code,
        "triggers" => ["CurrentDrivableActor.Function.HUD_GetSpeed"],
        "enabled" => false
      }

      assert {:ok, %{script: script}} = ScriptTools.execute("create_script", args)
      assert script.name == "Speed Warning"
      assert script.code == @sample_code
      assert script.triggers == ["CurrentDrivableActor.Function.HUD_GetSpeed"]
      assert script.enabled == false
    end

    test "creates a script with defaults", %{train: train} do
      args = %{
        "train_id" => train.id,
        "name" => "Simple Script",
        "code" => @sample_code
      }

      assert {:ok, %{script: script}} = ScriptTools.execute("create_script", args)
      assert script.enabled == true
      assert script.triggers == []
    end

    test "returns error for invalid data", %{train: train} do
      args = %{"train_id" => train.id, "name" => "", "code" => ""}

      assert {:error, message} = ScriptTools.execute("create_script", args)
      assert message =~ "Validation failed"
    end
  end

  describe "update_script" do
    test "updates script name", %{train: train} do
      {:ok, script} =
        TrainContext.create_script(train.id, %{name: "Old Name", code: @sample_code})

      assert {:ok, %{script: updated}} =
               ScriptTools.execute("update_script", %{"id" => script.id, "name" => "New Name"})

      assert updated.name == "New Name"
      assert updated.code == @sample_code
    end

    test "updates script code", %{train: train} do
      {:ok, script} =
        TrainContext.create_script(train.id, %{name: "Test", code: @sample_code})

      new_code = "function on_change(event)\n  api.set('Horn.InputValue', 1)\nend"

      assert {:ok, %{script: updated}} =
               ScriptTools.execute("update_script", %{"id" => script.id, "code" => new_code})

      assert updated.code == new_code
    end

    test "updates triggers and enabled", %{train: train} do
      {:ok, script} =
        TrainContext.create_script(train.id, %{name: "Test", code: @sample_code})

      assert {:ok, %{script: updated}} =
               ScriptTools.execute("update_script", %{
                 "id" => script.id,
                 "triggers" => ["NewEndpoint.Value"],
                 "enabled" => false
               })

      assert updated.triggers == ["NewEndpoint.Value"]
      assert updated.enabled == false
    end

    test "returns error for missing script" do
      assert {:error, message} =
               ScriptTools.execute("update_script", %{"id" => -1, "name" => "X"})

      assert message =~ "not found"
    end
  end

  describe "delete_script" do
    test "deletes an existing script", %{train: train} do
      {:ok, script} =
        TrainContext.create_script(train.id, %{name: "To Delete", code: @sample_code})

      assert {:ok, %{deleted: true, id: id}} =
               ScriptTools.execute("delete_script", %{"id" => script.id})

      assert id == script.id
      assert {:error, :not_found} = TrainContext.get_script(script.id)
    end

    test "returns error for missing script" do
      assert {:error, message} = ScriptTools.execute("delete_script", %{"id" => -1})
      assert message =~ "not found"
    end
  end
end
