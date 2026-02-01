defmodule Trenino.Train.ScriptTest do
  use Trenino.DataCase, async: false

  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.Script

  describe "changeset/2" do
    setup do
      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})
      %{train: train}
    end

    test "valid changeset with all fields", %{train: train} do
      attrs = %{
        train_id: train.id,
        name: "Speed Warning",
        code: "function on_change(event) end",
        triggers: ["CurrentDrivableActor.Function.HUD_GetSpeed"],
        enabled: true
      }

      changeset = Script.changeset(%Script{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with empty triggers", %{train: train} do
      attrs = %{
        train_id: train.id,
        name: "Manual Only",
        code: "function on_change(event) end",
        triggers: []
      }

      changeset = Script.changeset(%Script{}, attrs)
      assert changeset.valid?
    end

    test "invalid without name", %{train: train} do
      attrs = %{
        train_id: train.id,
        code: "function on_change(event) end"
      }

      changeset = Script.changeset(%Script{}, attrs)
      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without code", %{train: train} do
      attrs = %{
        train_id: train.id,
        name: "Test"
      }

      changeset = Script.changeset(%Script{}, attrs)
      refute changeset.valid?
      assert %{code: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid triggers with non-string elements", %{train: train} do
      attrs = %{
        train_id: train.id,
        name: "Test",
        code: "function on_change(event) end",
        triggers: [123, :atom]
      }

      changeset = Script.changeset(%Script{}, attrs)
      refute changeset.valid?
    end

    test "enforces unique name per train", %{train: train} do
      attrs = %{
        train_id: train.id,
        name: "My Script",
        code: "function on_change(event) end"
      }

      {:ok, _} = %Script{} |> Script.changeset(attrs) |> Repo.insert()

      {:error, changeset} = %Script{} |> Script.changeset(attrs) |> Repo.insert()
      assert %{train_id: ["has already been taken"]} = errors_on(changeset)
    end
  end
end
