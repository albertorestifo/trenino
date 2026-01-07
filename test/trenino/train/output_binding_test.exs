defmodule Trenino.Train.OutputBindingTest do
  use Trenino.DataCase, async: false

  alias Trenino.Hardware
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.OutputBinding

  describe "changeset/2" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, output} = Hardware.create_output(device.id, %{pin: 13, name: "Speed LED"})
      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})

      %{output: output, train: train, device: device}
    end

    test "valid changeset with all required fields", %{output: output, train: train} do
      attrs = %{
        train_id: train.id,
        output_id: output.id,
        name: "Speed Warning",
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        operator: :gt,
        value_a: 50.0
      }

      changeset = OutputBinding.changeset(%OutputBinding{}, attrs)

      assert changeset.valid?
    end

    test "valid changeset with between operator and both values", %{output: output, train: train} do
      attrs = %{
        train_id: train.id,
        output_id: output.id,
        name: "Speed Range",
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        operator: :between,
        value_a: 30.0,
        value_b: 60.0
      }

      changeset = OutputBinding.changeset(%OutputBinding{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :value_a) == 30.0
      assert Ecto.Changeset.get_field(changeset, :value_b) == 60.0
    end

    test "invalid changeset - between operator without value_b", %{output: output, train: train} do
      attrs = %{
        train_id: train.id,
        output_id: output.id,
        name: "Speed Range",
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        operator: :between,
        value_a: 30.0
      }

      changeset = OutputBinding.changeset(%OutputBinding{}, attrs)

      refute changeset.valid?
      assert %{value_b: ["can't be blank"]} = errors_on(changeset)
    end

    test "value_b not required for non-between operators", %{output: output, train: train} do
      for operator <- [:gt, :gte, :lt, :lte] do
        attrs = %{
          train_id: train.id,
          output_id: output.id,
          name: "Test Binding",
          endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
          operator: operator,
          value_a: 50.0
        }

        changeset = OutputBinding.changeset(%OutputBinding{}, attrs)

        assert changeset.valid?, "Expected #{operator} to not require value_b"
      end
    end

    test "defaults output_type to :led", %{output: output, train: train} do
      attrs = %{
        train_id: train.id,
        output_id: output.id,
        name: "Test",
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        operator: :gt,
        value_a: 50.0
      }

      changeset = OutputBinding.changeset(%OutputBinding{}, attrs)

      assert Ecto.Changeset.get_field(changeset, :output_type) == :led
    end

    test "defaults enabled to true", %{output: output, train: train} do
      attrs = %{
        train_id: train.id,
        output_id: output.id,
        name: "Test",
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        operator: :gt,
        value_a: 50.0
      }

      changeset = OutputBinding.changeset(%OutputBinding{}, attrs)

      assert Ecto.Changeset.get_field(changeset, :enabled) == true
    end

    test "rounds float values to 2 decimal places", %{output: output, train: train} do
      attrs = %{
        train_id: train.id,
        output_id: output.id,
        name: "Test",
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        operator: :between,
        value_a: 50.12345,
        value_b: 75.98765
      }

      changeset = OutputBinding.changeset(%OutputBinding{}, attrs)

      assert Ecto.Changeset.get_field(changeset, :value_a) == 50.12
      assert Ecto.Changeset.get_field(changeset, :value_b) == 75.99
    end

    test "invalid changeset without train_id", %{output: output} do
      attrs = %{
        output_id: output.id,
        name: "Test",
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        operator: :gt,
        value_a: 50.0
      }

      changeset = OutputBinding.changeset(%OutputBinding{}, attrs)

      refute changeset.valid?
      assert %{train_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset without output_id", %{train: train} do
      attrs = %{
        train_id: train.id,
        name: "Test",
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        operator: :gt,
        value_a: 50.0
      }

      changeset = OutputBinding.changeset(%OutputBinding{}, attrs)

      refute changeset.valid?
      assert %{output_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset without name", %{output: output, train: train} do
      attrs = %{
        train_id: train.id,
        output_id: output.id,
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        operator: :gt,
        value_a: 50.0
      }

      changeset = OutputBinding.changeset(%OutputBinding{}, attrs)

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset without endpoint", %{output: output, train: train} do
      attrs = %{
        train_id: train.id,
        output_id: output.id,
        name: "Test",
        operator: :gt,
        value_a: 50.0
      }

      changeset = OutputBinding.changeset(%OutputBinding{}, attrs)

      refute changeset.valid?
      assert %{endpoint: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset without operator", %{output: output, train: train} do
      attrs = %{
        train_id: train.id,
        output_id: output.id,
        name: "Test",
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        value_a: 50.0
      }

      changeset = OutputBinding.changeset(%OutputBinding{}, attrs)

      refute changeset.valid?
      assert %{operator: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset without value_a", %{output: output, train: train} do
      attrs = %{
        train_id: train.id,
        output_id: output.id,
        name: "Test",
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        operator: :gt
      }

      changeset = OutputBinding.changeset(%OutputBinding{}, attrs)

      refute changeset.valid?
      assert %{value_a: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "database constraints" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})
      {:ok, output} = Hardware.create_output(device.id, %{pin: 13, name: "Speed LED"})
      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})

      %{output: output, train: train, device: device}
    end

    test "enforces unique train_id + output_id constraint", %{output: output, train: train} do
      attrs = %{
        train_id: train.id,
        output_id: output.id,
        name: "Speed Warning",
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        operator: :gt,
        value_a: 50.0
      }

      {:ok, _binding} =
        %OutputBinding{}
        |> OutputBinding.changeset(attrs)
        |> Repo.insert()

      # Attempt to insert duplicate
      {:error, changeset} =
        %OutputBinding{}
        |> OutputBinding.changeset(Map.put(attrs, :name, "Different Name"))
        |> Repo.insert()

      assert %{train_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows same output for different trains", %{output: output, train: train} do
      {:ok, train2} =
        TrainContext.create_train(%{name: "Another Train", identifier: "another_train"})

      attrs1 = %{
        train_id: train.id,
        output_id: output.id,
        name: "Speed Warning 1",
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        operator: :gt,
        value_a: 50.0
      }

      attrs2 = %{
        train_id: train2.id,
        output_id: output.id,
        name: "Speed Warning 2",
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        operator: :gt,
        value_a: 60.0
      }

      {:ok, _binding1} =
        %OutputBinding{}
        |> OutputBinding.changeset(attrs1)
        |> Repo.insert()

      {:ok, _binding2} =
        %OutputBinding{}
        |> OutputBinding.changeset(attrs2)
        |> Repo.insert()
    end

    test "cascades delete when train is deleted", %{output: output, train: train} do
      attrs = %{
        train_id: train.id,
        output_id: output.id,
        name: "Speed Warning",
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        operator: :gt,
        value_a: 50.0
      }

      {:ok, binding} =
        %OutputBinding{}
        |> OutputBinding.changeset(attrs)
        |> Repo.insert()

      TrainContext.delete_train(train)

      assert Repo.get(OutputBinding, binding.id) == nil
    end

    test "cascades delete when output is deleted", %{output: output, train: train} do
      attrs = %{
        train_id: train.id,
        output_id: output.id,
        name: "Speed Warning",
        endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed",
        operator: :gt,
        value_a: 50.0
      }

      {:ok, binding} =
        %OutputBinding{}
        |> OutputBinding.changeset(attrs)
        |> Repo.insert()

      Hardware.delete_output(output.id)

      assert Repo.get(OutputBinding, binding.id) == nil
    end
  end
end
