defmodule Trenino.Train.OutputBindingContextTest do
  @moduledoc """
  Tests for output binding context functions in Trenino.Train module.
  """
  use Trenino.DataCase, async: false

  alias Trenino.Hardware
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.OutputBinding

  describe "list_output_bindings/1" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, output1} = Hardware.create_output(device.id, %{pin: 13, name: "LED 1"})
      {:ok, output2} = Hardware.create_output(device.id, %{pin: 14, name: "LED 2"})
      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})

      %{output1: output1, output2: output2, train: train, device: device}
    end

    test "returns empty list when no bindings exist", %{train: train} do
      assert [] == TrainContext.list_output_bindings(train.id)
    end

    test "returns all bindings for a train", %{train: train, output1: output1, output2: output2} do
      {:ok, _binding1} =
        TrainContext.create_output_binding(train.id, %{
          output_id: output1.id,
          name: "Speed Warning",
          endpoint: "Speed",
          operator: :gt,
          value_a: 50.0
        })

      {:ok, _binding2} =
        TrainContext.create_output_binding(train.id, %{
          output_id: output2.id,
          name: "Brake Warning",
          endpoint: "Brake",
          operator: :lt,
          value_a: 10.0
        })

      bindings = TrainContext.list_output_bindings(train.id)

      assert length(bindings) == 2
    end

    test "returns bindings ordered by name", %{train: train, output1: output1, output2: output2} do
      {:ok, _binding1} =
        TrainContext.create_output_binding(train.id, %{
          output_id: output1.id,
          name: "Zebra",
          endpoint: "Speed",
          operator: :gt,
          value_a: 50.0
        })

      {:ok, _binding2} =
        TrainContext.create_output_binding(train.id, %{
          output_id: output2.id,
          name: "Alpha",
          endpoint: "Brake",
          operator: :lt,
          value_a: 10.0
        })

      bindings = TrainContext.list_output_bindings(train.id)

      assert [%{name: "Alpha"}, %{name: "Zebra"}] = bindings
    end

    test "preloads output and device associations", %{train: train, output1: output1} do
      {:ok, _binding} =
        TrainContext.create_output_binding(train.id, %{
          output_id: output1.id,
          name: "Speed Warning",
          endpoint: "Speed",
          operator: :gt,
          value_a: 50.0
        })

      [binding] = TrainContext.list_output_bindings(train.id)

      assert binding.output.name == "LED 1"
      assert binding.output.device.name == "Test Device"
    end

    test "does not return bindings from other trains", %{
      train: train,
      output1: output1,
      output2: output2
    } do
      {:ok, other_train} =
        TrainContext.create_train(%{name: "Other Train", identifier: "other_train"})

      {:ok, _binding1} =
        TrainContext.create_output_binding(train.id, %{
          output_id: output1.id,
          name: "Train 1 Binding",
          endpoint: "Speed",
          operator: :gt,
          value_a: 50.0
        })

      {:ok, _binding2} =
        TrainContext.create_output_binding(other_train.id, %{
          output_id: output2.id,
          name: "Train 2 Binding",
          endpoint: "Brake",
          operator: :lt,
          value_a: 10.0
        })

      bindings = TrainContext.list_output_bindings(train.id)

      assert length(bindings) == 1
      assert hd(bindings).name == "Train 1 Binding"
    end
  end

  describe "list_enabled_output_bindings/1" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, output1} = Hardware.create_output(device.id, %{pin: 13, name: "LED 1"})
      {:ok, output2} = Hardware.create_output(device.id, %{pin: 14, name: "LED 2"})
      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})

      %{output1: output1, output2: output2, train: train}
    end

    test "returns only enabled bindings", %{train: train, output1: output1, output2: output2} do
      {:ok, _enabled} =
        TrainContext.create_output_binding(train.id, %{
          output_id: output1.id,
          name: "Enabled",
          endpoint: "Speed",
          operator: :gt,
          value_a: 50.0,
          enabled: true
        })

      {:ok, _disabled} =
        TrainContext.create_output_binding(train.id, %{
          output_id: output2.id,
          name: "Disabled",
          endpoint: "Brake",
          operator: :lt,
          value_a: 10.0,
          enabled: false
        })

      bindings = TrainContext.list_enabled_output_bindings(train.id)

      assert length(bindings) == 1
      assert hd(bindings).name == "Enabled"
    end
  end

  describe "get_output_binding/1" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, output} = Hardware.create_output(device.id, %{pin: 13, name: "LED 1"})
      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})

      %{output: output, train: train}
    end

    test "returns binding by id", %{train: train, output: output} do
      {:ok, created} =
        TrainContext.create_output_binding(train.id, %{
          output_id: output.id,
          name: "Speed Warning",
          endpoint: "Speed",
          operator: :gt,
          value_a: 50.0
        })

      assert {:ok, %OutputBinding{} = found} = TrainContext.get_output_binding(created.id)
      assert found.id == created.id
      assert found.name == "Speed Warning"
    end

    test "returns error when binding not found" do
      assert {:error, :not_found} = TrainContext.get_output_binding(999_999)
    end

    test "preloads output and device", %{train: train, output: output} do
      {:ok, created} =
        TrainContext.create_output_binding(train.id, %{
          output_id: output.id,
          name: "Speed Warning",
          endpoint: "Speed",
          operator: :gt,
          value_a: 50.0
        })

      {:ok, found} = TrainContext.get_output_binding(created.id)

      assert found.output.name == "LED 1"
      assert found.output.device.name == "Test Device"
    end
  end

  describe "create_output_binding/2" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, output} = Hardware.create_output(device.id, %{pin: 13, name: "LED 1"})
      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})

      %{output: output, train: train}
    end

    test "creates binding with valid attributes", %{train: train, output: output} do
      attrs = %{
        output_id: output.id,
        name: "Speed Warning",
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        operator: :gt,
        value_a: 50.0
      }

      assert {:ok, %OutputBinding{} = binding} =
               TrainContext.create_output_binding(train.id, attrs)

      assert binding.name == "Speed Warning"
      assert binding.train_id == train.id
      assert binding.operator == :gt
      assert binding.value_a == 50.0
    end

    test "returns error with invalid attributes", %{train: train} do
      attrs = %{name: "Missing output_id"}

      assert {:error, changeset} = TrainContext.create_output_binding(train.id, attrs)
      assert %{output_id: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_output_binding/2" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, output} = Hardware.create_output(device.id, %{pin: 13, name: "LED 1"})
      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})

      {:ok, binding} =
        TrainContext.create_output_binding(train.id, %{
          output_id: output.id,
          name: "Original Name",
          endpoint: "Speed",
          operator: :gt,
          value_a: 50.0
        })

      %{binding: binding, train: train}
    end

    test "updates binding with valid attributes", %{binding: binding} do
      attrs = %{name: "Updated Name", value_a: 75.0}

      assert {:ok, updated} = TrainContext.update_output_binding(binding, attrs)
      assert updated.name == "Updated Name"
      assert updated.value_a == 75.0
    end

    test "can update operator to between with value_b", %{binding: binding} do
      attrs = %{operator: :between, value_a: 30.0, value_b: 60.0}

      assert {:ok, updated} = TrainContext.update_output_binding(binding, attrs)
      assert updated.operator == :between
      assert updated.value_b == 60.0
    end

    test "can toggle enabled state", %{binding: binding} do
      assert {:ok, updated} = TrainContext.update_output_binding(binding, %{enabled: false})
      assert updated.enabled == false

      assert {:ok, updated2} = TrainContext.update_output_binding(updated, %{enabled: true})
      assert updated2.enabled == true
    end
  end

  describe "delete_output_binding/1" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, output} = Hardware.create_output(device.id, %{pin: 13, name: "LED 1"})
      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})

      {:ok, binding} =
        TrainContext.create_output_binding(train.id, %{
          output_id: output.id,
          name: "To Delete",
          endpoint: "Speed",
          operator: :gt,
          value_a: 50.0
        })

      %{binding: binding, train: train}
    end

    test "deletes the binding", %{binding: binding} do
      assert {:ok, _deleted} = TrainContext.delete_output_binding(binding)
      assert {:error, :not_found} = TrainContext.get_output_binding(binding.id)
    end
  end
end
