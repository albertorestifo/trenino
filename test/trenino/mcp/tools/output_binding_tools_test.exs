defmodule Trenino.MCP.Tools.OutputBindingToolsTest do
  use Trenino.DataCase, async: false

  alias Trenino.Hardware
  alias Trenino.MCP.Tools.OutputBindingTools
  alias Trenino.Train, as: TrainContext

  setup do
    {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})
    {:ok, device} = Hardware.create_device(%{name: "Arduino Uno"})
    {:ok, output} = Hardware.create_output(device.id, %{pin: 13, name: "Red LED"})
    %{train: train, output: output}
  end

  describe "list_output_bindings" do
    test "returns empty list when no bindings", %{train: train} do
      assert {:ok, %{output_bindings: []}} =
               OutputBindingTools.execute("list_output_bindings", %{"train_id" => train.id})
    end

    test "returns existing bindings", %{train: train, output: output} do
      {:ok, _} =
        TrainContext.create_output_binding(train.id, %{
          name: "Speed warning",
          output_id: output.id,
          endpoint: "Speed.Value",
          operator: :gt,
          value_a: 50.0
        })

      assert {:ok, %{output_bindings: [binding]}} =
               OutputBindingTools.execute("list_output_bindings", %{"train_id" => train.id})

      assert binding.name == "Speed warning"
      assert binding.operator == :gt
      assert binding.value_a == 50.0
    end
  end

  describe "create_output_binding" do
    test "creates a binding with valid data", %{train: train, output: output} do
      args = %{
        "train_id" => train.id,
        "name" => "Brake warning",
        "output_id" => output.id,
        "endpoint" => "Brake.Value",
        "operator" => "gt",
        "value_a" => 0.5
      }

      assert {:ok, %{output_binding: binding}} =
               OutputBindingTools.execute("create_output_binding", args)

      assert binding.name == "Brake warning"
      assert binding.endpoint == "Brake.Value"
      assert binding.operator == :gt
      assert binding.value_a == 0.5
      assert binding.enabled == true
    end

    test "creates a binding with between operator", %{train: train, output: output} do
      args = %{
        "train_id" => train.id,
        "name" => "Speed range",
        "output_id" => output.id,
        "endpoint" => "Speed.Value",
        "operator" => "between",
        "value_a" => 30.0,
        "value_b" => 60.0
      }

      assert {:ok, %{output_binding: binding}} =
               OutputBindingTools.execute("create_output_binding", args)

      assert binding.operator == :between
      assert binding.value_a == 30.0
      assert binding.value_b == 60.0
    end

    test "creates a binding with boolean operator", %{train: train, output: output} do
      args = %{
        "train_id" => train.id,
        "name" => "Door open indicator",
        "output_id" => output.id,
        "endpoint" => "Door.IsOpen",
        "operator" => "eq_true"
      }

      assert {:ok, %{output_binding: binding}} =
               OutputBindingTools.execute("create_output_binding", args)

      assert binding.operator == :eq_true
    end

    test "returns error for invalid data", %{train: train} do
      args = %{
        "train_id" => train.id,
        "name" => "",
        "output_id" => -1,
        "endpoint" => "",
        "operator" => "gt"
      }

      assert {:error, message} = OutputBindingTools.execute("create_output_binding", args)
      assert message =~ "Validation failed"
    end
  end

  describe "update_output_binding" do
    test "updates binding fields", %{train: train, output: output} do
      {:ok, binding} =
        TrainContext.create_output_binding(train.id, %{
          name: "Old name",
          output_id: output.id,
          endpoint: "Speed.Value",
          operator: :gt,
          value_a: 50.0
        })

      assert {:ok, %{output_binding: updated}} =
               OutputBindingTools.execute("update_output_binding", %{
                 "id" => binding.id,
                 "name" => "New name",
                 "value_a" => 75.0
               })

      assert updated.name == "New name"
      assert updated.value_a == 75.0
      assert updated.endpoint == "Speed.Value"
    end

    test "returns error for missing binding" do
      assert {:error, message} =
               OutputBindingTools.execute("update_output_binding", %{"id" => -1, "name" => "X"})

      assert message =~ "not found"
    end
  end

  describe "delete_output_binding" do
    test "deletes an existing binding", %{train: train, output: output} do
      {:ok, binding} =
        TrainContext.create_output_binding(train.id, %{
          name: "To delete",
          output_id: output.id,
          endpoint: "Speed.Value",
          operator: :gt,
          value_a: 50.0
        })

      assert {:ok, %{deleted: true, id: id}} =
               OutputBindingTools.execute("delete_output_binding", %{"id" => binding.id})

      assert id == binding.id
      assert {:error, :not_found} = TrainContext.get_output_binding(binding.id)
    end

    test "returns error for missing binding" do
      assert {:error, message} =
               OutputBindingTools.execute("delete_output_binding", %{"id" => -1})

      assert message =~ "not found"
    end
  end
end
