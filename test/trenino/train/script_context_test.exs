defmodule Trenino.Train.ScriptContextTest do
  use Trenino.DataCase, async: false

  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.Script

  setup do
    {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})
    %{train: train}
  end

  describe "list_scripts/1" do
    test "returns empty list when no scripts", %{train: train} do
      assert TrainContext.list_scripts(train.id) == []
    end

    test "returns scripts ordered by name", %{train: train} do
      {:ok, _} = TrainContext.create_script(train.id, %{name: "Zebra", code: "function on_change(event) end"})
      {:ok, _} = TrainContext.create_script(train.id, %{name: "Alpha", code: "function on_change(event) end"})

      scripts = TrainContext.list_scripts(train.id)
      assert [%Script{name: "Alpha"}, %Script{name: "Zebra"}] = scripts
    end
  end

  describe "list_enabled_scripts/1" do
    test "returns only enabled scripts", %{train: train} do
      {:ok, _} = TrainContext.create_script(train.id, %{name: "Enabled", code: "function on_change(event) end", enabled: true})
      {:ok, _} = TrainContext.create_script(train.id, %{name: "Disabled", code: "function on_change(event) end", enabled: false})

      scripts = TrainContext.list_enabled_scripts(train.id)
      assert length(scripts) == 1
      assert hd(scripts).name == "Enabled"
    end
  end

  describe "get_script/1" do
    test "returns script by id", %{train: train} do
      {:ok, created} = TrainContext.create_script(train.id, %{name: "Test", code: "function on_change(event) end"})

      assert {:ok, %Script{name: "Test"}} = TrainContext.get_script(created.id)
    end

    test "returns error for missing id" do
      assert {:error, :not_found} = TrainContext.get_script(-1)
    end
  end

  describe "create_script/2" do
    test "creates script with valid attrs", %{train: train} do
      attrs = %{name: "My Script", code: "function on_change(event) end", triggers: ["Endpoint.A"]}

      assert {:ok, %Script{name: "My Script", triggers: ["Endpoint.A"]}} =
               TrainContext.create_script(train.id, attrs)
    end

    test "fails with invalid attrs", %{train: train} do
      assert {:error, %Ecto.Changeset{}} = TrainContext.create_script(train.id, %{})
    end
  end

  describe "update_script/2" do
    test "updates script fields", %{train: train} do
      {:ok, script} = TrainContext.create_script(train.id, %{name: "Old", code: "function on_change(event) end"})

      assert {:ok, %Script{name: "New"}} = TrainContext.update_script(script, %{name: "New"})
    end
  end

  describe "delete_script/1" do
    test "deletes a script", %{train: train} do
      {:ok, script} = TrainContext.create_script(train.id, %{name: "ToDelete", code: "function on_change(event) end"})

      assert {:ok, _} = TrainContext.delete_script(script)
      assert {:error, :not_found} = TrainContext.get_script(script.id)
    end
  end
end
