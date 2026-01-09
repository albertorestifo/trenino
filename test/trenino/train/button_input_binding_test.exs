defmodule Trenino.Train.ButtonInputBindingTest do
  use Trenino.DataCase, async: false

  alias Trenino.Hardware
  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.ButtonInputBinding

  describe "changeset/2" do
    setup do
      # Create required associations
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})

      %{input: input, element: element}
    end

    test "valid changeset with all required fields", %{input: input, element: element} do
      attrs = %{
        element_id: element.id,
        input_id: input.id,
        endpoint: "CurrentDrivableActor/Horn.InputValue"
      }

      changeset = ButtonInputBinding.changeset(%ButtonInputBinding{}, attrs)

      assert changeset.valid?
    end

    test "valid changeset with custom on/off values", %{input: input, element: element} do
      attrs = %{
        element_id: element.id,
        input_id: input.id,
        endpoint: "CurrentDrivableActor/Horn.InputValue",
        on_value: 100.0,
        off_value: -50.0
      }

      changeset = ButtonInputBinding.changeset(%ButtonInputBinding{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :on_value) == 100.0
      assert Ecto.Changeset.get_field(changeset, :off_value) == -50.0
    end

    test "defaults on_value to 1.0 and off_value to 0.0", %{input: input, element: element} do
      attrs = %{
        element_id: element.id,
        input_id: input.id,
        endpoint: "CurrentDrivableActor/Horn.InputValue"
      }

      changeset = ButtonInputBinding.changeset(%ButtonInputBinding{}, attrs)

      assert Ecto.Changeset.get_field(changeset, :on_value) == 1.0
      assert Ecto.Changeset.get_field(changeset, :off_value) == 0.0
    end

    test "defaults enabled to true", %{input: input, element: element} do
      attrs = %{
        element_id: element.id,
        input_id: input.id,
        endpoint: "CurrentDrivableActor/Horn.InputValue"
      }

      changeset = ButtonInputBinding.changeset(%ButtonInputBinding{}, attrs)

      assert Ecto.Changeset.get_field(changeset, :enabled) == true
    end

    test "invalid changeset without element_id", %{input: input} do
      attrs = %{
        input_id: input.id,
        endpoint: "CurrentDrivableActor/Horn.InputValue"
      }

      changeset = ButtonInputBinding.changeset(%ButtonInputBinding{}, attrs)

      refute changeset.valid?
      assert %{element_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset without input_id", %{element: element} do
      attrs = %{
        element_id: element.id,
        endpoint: "CurrentDrivableActor/Horn.InputValue"
      }

      changeset = ButtonInputBinding.changeset(%ButtonInputBinding{}, attrs)

      refute changeset.valid?
      assert %{input_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid changeset without endpoint", %{input: input, element: element} do
      attrs = %{
        element_id: element.id,
        input_id: input.id
      }

      changeset = ButtonInputBinding.changeset(%ButtonInputBinding{}, attrs)

      refute changeset.valid?
      assert %{endpoint: ["can't be blank"]} = errors_on(changeset)
    end

    test "allows updating enabled field", %{input: input, element: element} do
      attrs = %{
        element_id: element.id,
        input_id: input.id,
        endpoint: "CurrentDrivableActor/Horn.InputValue",
        enabled: false
      }

      changeset = ButtonInputBinding.changeset(%ButtonInputBinding{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :enabled) == false
    end
  end

  describe "database constraints" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "test_train"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})

      %{input: input, element: element, train: train}
    end

    test "enforces unique element_id constraint", %{input: input, element: element} do
      attrs = %{
        element_id: element.id,
        input_id: input.id,
        endpoint: "CurrentDrivableActor/Horn.InputValue"
      }

      # Insert first binding
      {:ok, _binding} =
        %ButtonInputBinding{}
        |> ButtonInputBinding.changeset(attrs)
        |> Repo.insert()

      # Attempt to insert duplicate
      {:error, changeset} =
        %ButtonInputBinding{}
        |> ButtonInputBinding.changeset(attrs)
        |> Repo.insert()

      assert %{element_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows same input bound to different elements", %{input: input, train: train} do
      {:ok, element1} = TrainContext.create_element(train.id, %{name: "Horn", type: :button})
      {:ok, element2} = TrainContext.create_element(train.id, %{name: "Bell", type: :button})

      attrs1 = %{
        element_id: element1.id,
        input_id: input.id,
        endpoint: "CurrentDrivableActor/Horn.InputValue"
      }

      attrs2 = %{
        element_id: element2.id,
        input_id: input.id,
        endpoint: "CurrentDrivableActor/Bell.InputValue"
      }

      {:ok, _binding1} =
        %ButtonInputBinding{}
        |> ButtonInputBinding.changeset(attrs1)
        |> Repo.insert()

      {:ok, _binding2} =
        %ButtonInputBinding{}
        |> ButtonInputBinding.changeset(attrs2)
        |> Repo.insert()
    end

    test "cascades delete when element is deleted", %{input: input, element: element} do
      attrs = %{
        element_id: element.id,
        input_id: input.id,
        endpoint: "CurrentDrivableActor/Horn.InputValue"
      }

      {:ok, binding} =
        %ButtonInputBinding{}
        |> ButtonInputBinding.changeset(attrs)
        |> Repo.insert()

      # Delete the element
      TrainContext.delete_element(element)

      # Binding should be deleted too
      assert Repo.get(ButtonInputBinding, binding.id) == nil
    end

    test "cascades delete when input is deleted", %{input: input, element: element} do
      attrs = %{
        element_id: element.id,
        input_id: input.id,
        endpoint: "CurrentDrivableActor/Horn.InputValue"
      }

      {:ok, binding} =
        %ButtonInputBinding{}
        |> ButtonInputBinding.changeset(attrs)
        |> Repo.insert()

      # Delete the input
      Hardware.delete_input(input.id)

      # Binding should be deleted too
      assert Repo.get(ButtonInputBinding, binding.id) == nil
    end
  end

  describe "sequence mode validation" do
    setup do
      {:ok, device} = Hardware.create_device(%{name: "Test Device"})

      {:ok, input} =
        Hardware.create_input(device.id, %{pin: 5, input_type: :button, debounce: 20})

      {:ok, train} = TrainContext.create_train(%{name: "Test Train", identifier: "seq_test"})
      {:ok, element} = TrainContext.create_element(train.id, %{name: "Door", type: :button})
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Open Door"})
      {:ok, sequence2} = TrainContext.create_sequence(train.id, %{name: "Close Door"})

      %{input: input, element: element, sequence: sequence, sequence2: sequence2}
    end

    test "valid with on_sequence_id only (momentary hardware)", %{
      input: input,
      element: element,
      sequence: sequence
    } do
      attrs = %{
        element_id: element.id,
        input_id: input.id,
        mode: :sequence,
        hardware_type: :momentary,
        on_sequence_id: sequence.id
      }

      changeset = ButtonInputBinding.changeset(%ButtonInputBinding{}, attrs)
      assert changeset.valid?
    end

    test "valid with on_sequence_id only (latching hardware)", %{
      input: input,
      element: element,
      sequence: sequence
    } do
      attrs = %{
        element_id: element.id,
        input_id: input.id,
        mode: :sequence,
        hardware_type: :latching,
        on_sequence_id: sequence.id
      }

      changeset = ButtonInputBinding.changeset(%ButtonInputBinding{}, attrs)
      assert changeset.valid?
    end

    test "valid with off_sequence_id only (latching hardware)", %{
      input: input,
      element: element,
      sequence: sequence
    } do
      attrs = %{
        element_id: element.id,
        input_id: input.id,
        mode: :sequence,
        hardware_type: :latching,
        off_sequence_id: sequence.id
      }

      changeset = ButtonInputBinding.changeset(%ButtonInputBinding{}, attrs)
      assert changeset.valid?
    end

    test "valid with both sequences (latching hardware)", %{
      input: input,
      element: element,
      sequence: sequence,
      sequence2: sequence2
    } do
      attrs = %{
        element_id: element.id,
        input_id: input.id,
        mode: :sequence,
        hardware_type: :latching,
        on_sequence_id: sequence.id,
        off_sequence_id: sequence2.id
      }

      changeset = ButtonInputBinding.changeset(%ButtonInputBinding{}, attrs)
      assert changeset.valid?
    end

    test "invalid without any sequence", %{input: input, element: element} do
      attrs = %{
        element_id: element.id,
        input_id: input.id,
        mode: :sequence,
        hardware_type: :momentary
      }

      changeset = ButtonInputBinding.changeset(%ButtonInputBinding{}, attrs)
      refute changeset.valid?
      assert %{on_sequence_id: ["at least one sequence is required"]} = errors_on(changeset)
    end

    test "invalid with off_sequence_id on momentary hardware", %{
      input: input,
      element: element,
      sequence: sequence
    } do
      attrs = %{
        element_id: element.id,
        input_id: input.id,
        mode: :sequence,
        hardware_type: :momentary,
        on_sequence_id: sequence.id,
        off_sequence_id: sequence.id
      }

      changeset = ButtonInputBinding.changeset(%ButtonInputBinding{}, attrs)
      refute changeset.valid?
      assert %{off_sequence_id: ["is only valid for latching hardware"]} = errors_on(changeset)
    end

    test "invalid with off_sequence_id when mode is not sequence", %{
      input: input,
      element: element,
      sequence: sequence
    } do
      attrs = %{
        element_id: element.id,
        input_id: input.id,
        mode: :simple,
        endpoint: "Test.Endpoint",
        off_sequence_id: sequence.id
      }

      changeset = ButtonInputBinding.changeset(%ButtonInputBinding{}, attrs)
      refute changeset.valid?
      assert %{off_sequence_id: ["is only valid in sequence mode"]} = errors_on(changeset)
    end
  end
end
