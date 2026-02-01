defmodule Trenino.MCP.Tools.SequenceToolsTest do
  use Trenino.DataCase, async: false

  alias Trenino.MCP.Tools.SequenceTools
  alias Trenino.Train, as: TrainContext

  setup do
    {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})
    %{train: train}
  end

  describe "list_sequences" do
    test "returns empty list when no sequences", %{train: train} do
      assert {:ok, %{sequences: []}} =
               SequenceTools.execute("list_sequences", %{"train_id" => train.id})
    end

    test "returns all sequences for a train", %{train: train} do
      {:ok, _} = TrainContext.create_sequence(train.id, %{name: "Startup"})
      {:ok, _} = TrainContext.create_sequence(train.id, %{name: "Shutdown"})

      assert {:ok, %{sequences: sequences}} =
               SequenceTools.execute("list_sequences", %{"train_id" => train.id})

      assert length(sequences) == 2
      names = Enum.map(sequences, & &1.name)
      assert "Startup" in names
      assert "Shutdown" in names
    end
  end

  describe "create_sequence" do
    test "creates a sequence with commands", %{train: train} do
      args = %{
        "train_id" => train.id,
        "name" => "Startup",
        "commands" => [
          %{"endpoint" => "Battery.InputValue", "value" => 1.0, "delay_ms" => 500},
          %{"endpoint" => "Pantograph.InputValue", "value" => 1.0, "delay_ms" => 1000},
          %{"endpoint" => "MainBreaker.InputValue", "value" => 1.0}
        ]
      }

      assert {:ok, %{sequence: sequence}} = SequenceTools.execute("create_sequence", args)
      assert sequence.name == "Startup"
      assert length(sequence.commands) == 3

      first_cmd = Enum.find(sequence.commands, &(&1.position == 0))
      assert first_cmd.endpoint == "Battery.InputValue"
      assert first_cmd.value == 1.0
      assert first_cmd.delay_ms == 500
    end

    test "creates a sequence without commands", %{train: train} do
      args = %{
        "train_id" => train.id,
        "name" => "Empty Sequence",
        "commands" => []
      }

      assert {:ok, %{sequence: sequence}} = SequenceTools.execute("create_sequence", args)
      assert sequence.name == "Empty Sequence"
      assert sequence.commands == []
    end

    test "returns error for invalid data", %{train: train} do
      args = %{"train_id" => train.id, "name" => "", "commands" => []}

      assert {:error, message} = SequenceTools.execute("create_sequence", args)
      assert message =~ "Validation failed"
    end
  end

  describe "update_sequence" do
    test "updates sequence name", %{train: train} do
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Old Name"})

      assert {:ok, %{sequence: updated}} =
               SequenceTools.execute("update_sequence", %{
                 "id" => sequence.id,
                 "name" => "New Name"
               })

      assert updated.name == "New Name"
    end

    test "replaces commands", %{train: train} do
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Test"})

      TrainContext.set_sequence_commands(sequence, [
        %{position: 0, endpoint: "Old.Value", value: 1.0}
      ])

      assert {:ok, %{sequence: updated}} =
               SequenceTools.execute("update_sequence", %{
                 "id" => sequence.id,
                 "commands" => [
                   %{"endpoint" => "New.Value", "value" => 2.0, "delay_ms" => 100}
                 ]
               })

      assert length(updated.commands) == 1
      assert hd(updated.commands).endpoint == "New.Value"
      assert hd(updated.commands).value == 2.0
    end

    test "returns error for missing sequence" do
      assert {:error, message} =
               SequenceTools.execute("update_sequence", %{"id" => -1, "name" => "X"})

      assert message =~ "not found"
    end
  end

  describe "delete_sequence" do
    test "deletes an existing sequence", %{train: train} do
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "To Delete"})

      assert {:ok, %{deleted: true, id: id}} =
               SequenceTools.execute("delete_sequence", %{"id" => sequence.id})

      assert id == sequence.id
      assert {:error, :not_found} = TrainContext.get_sequence(sequence.id)
    end

    test "returns error for missing sequence" do
      assert {:error, message} = SequenceTools.execute("delete_sequence", %{"id" => -1})
      assert message =~ "not found"
    end
  end
end
