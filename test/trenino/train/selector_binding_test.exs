defmodule Trenino.Train.SelectorBindingTest do
  use Trenino.DataCase, async: true

  import Trenino.VirtualJoystickFixtures

  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.{SelectorMapper, SelectorPosition}
  alias Trenino.VirtualJoystick

  setup do
    {:ok, train} =
      TrainContext.create_train(%{name: "Test Train", identifiers: [%{identifier: "test_train"}]})

    {:ok, element} =
      TrainContext.create_element(train.id, %{name: "Lights selector", type: :selector})

    %{train: train, element: element, input: analog_input_fixture()}
  end

  defp set_value(endpoint, value),
    do: %{enter_kind: :set_value, enter_endpoint: endpoint, enter_value: value}

  defp three_positions do
    3
    |> SelectorMapper.even_split()
    |> Enum.map(fn range ->
      Map.merge(range, set_value("CurrentDrivableActor/Headlights.InputValue", range.index * 1.0))
    end)
  end

  describe "SelectorPosition.changeset/2" do
    defp position_changeset(attrs) do
      SelectorPosition.changeset(
        %SelectorPosition{},
        Map.merge(%{index: 0, input_min: 0.0, input_max: 0.3}, attrs)
      )
    end

    test "accepts a set_value enter action" do
      assert position_changeset(set_value("A.InputValue", 1.0)).valid?
    end

    test "allows a position with no actions" do
      changeset = position_changeset(%{})

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :enter_kind) == :none
      assert Ecto.Changeset.get_field(changeset, :exit_kind) == :none
    end

    test "accepts a single-point range" do
      assert position_changeset(%{input_min: 0.5, input_max: 0.5}).valid?
    end

    test "requires the fields of each action kind" do
      assert %{enter_endpoint: _, enter_value: _} =
               errors_on(position_changeset(%{enter_kind: :set_value}))

      assert %{enter_sequence_id: _} = errors_on(position_changeset(%{enter_kind: :sequence}))
      assert %{enter_keystroke: _} = errors_on(position_changeset(%{enter_kind: :keystroke}))

      assert %{exit_keystroke: _} =
               errors_on(
                 position_changeset(Map.merge(set_value("A", 1.0), %{exit_kind: :keystroke}))
               )

      assert %{exit_endpoint: _, exit_value: _} =
               errors_on(position_changeset(%{exit_kind: :set_value}))

      assert %{exit_sequence_id: _} = errors_on(position_changeset(%{exit_kind: :sequence}))
    end

    test "defaults the exit action to none" do
      changeset = position_changeset(set_value("A", 1.0))

      assert Ecto.Changeset.get_field(changeset, :exit_kind) == :none
    end

    test "clears fields that do not belong to the chosen kind" do
      changeset =
        position_changeset(%{enter_kind: :keystroke, enter_keystroke: "L", enter_endpoint: "A"})

      assert changeset.valid?
      assert Ecto.Changeset.get_field(changeset, :enter_endpoint) == nil
    end

    test "rounds floats to 2 decimals" do
      changeset =
        position_changeset(
          Map.merge(set_value("A", 0.333), %{input_min: 0.104, input_max: 0.2999})
        )

      assert Ecto.Changeset.get_field(changeset, :enter_value) == 0.33
      assert Ecto.Changeset.get_field(changeset, :input_min) == 0.1
      assert Ecto.Changeset.get_field(changeset, :input_max) == 0.3
    end

    test "validates the input range" do
      assert %{input_min: _} =
               errors_on(position_changeset(Map.merge(set_value("A", 1.0), %{input_min: 0.5})))

      assert %{input_max: _} =
               errors_on(position_changeset(Map.merge(set_value("A", 1.0), %{input_max: 1.5})))
    end
  end

  describe "save_selector/3" do
    test "creates a binding with ordered positions", %{element: element, input: input} do
      assert {:ok, binding} =
               TrainContext.save_selector(element.id, %{
                 input_id: input.id,
                 positions: Enum.reverse(three_positions())
               })

      assert binding.enabled
      assert binding.input.device
      assert Enum.map(binding.positions, & &1.index) == [0, 1, 2]
      assert Enum.map(binding.positions, & &1.enter_value) == [0.0, 1.0, 2.0]
    end

    test "accepts string-keyed params", %{element: element, input: input} do
      positions =
        Enum.map(three_positions(), fn position ->
          Map.new(position, fn {key, value} -> {to_string(key), value} end)
        end)

      assert {:ok, %{positions: [_, _, _]}} =
               TrainContext.save_selector(element.id, %{
                 "input_id" => input.id,
                 "positions" => positions
               })
    end

    test "replaces the whole position set", %{element: element, input: input} do
      {:ok, _} =
        TrainContext.save_selector(element.id, %{input_id: input.id, positions: three_positions()})

      positions =
        2
        |> SelectorMapper.even_split()
        |> Enum.map(&Map.merge(&1, %{enter_kind: :keystroke, enter_keystroke: "L"}))

      assert {:ok, binding} = TrainContext.save_selector(element.id, %{positions: positions})

      assert [%{enter_kind: :keystroke}, %{enter_kind: :keystroke}] = binding.positions
      assert {:ok, %{positions: [_, _]}} = TrainContext.get_selector_binding(element.id)
    end

    test "keeps positions when they are not given", %{element: element, input: input} do
      {:ok, _} =
        TrainContext.save_selector(element.id, %{input_id: input.id, positions: three_positions()})

      assert {:ok, %{enabled: false, positions: [_, _, _]}} =
               TrainContext.set_selector_binding_enabled(element.id, false)
    end

    test "rejects overlapping positions", %{element: element, input: input} do
      positions = [
        Map.merge(%{index: 0, input_min: 0.0, input_max: 0.5}, set_value("A", 0.0)),
        Map.merge(%{index: 1, input_min: 0.5, input_max: 1.0}, set_value("A", 1.0))
      ]

      assert {:error, changeset} =
               TrainContext.save_selector(element.id, %{input_id: input.id, positions: positions})

      assert ["must not overlap and need a gap of at least 0.02 between them"] =
               errors_on(changeset).positions
    end

    test "rejects duplicate indexes", %{element: element, input: input} do
      positions = Enum.map(three_positions(), &Map.put(&1, :index, 0))

      assert {:error, changeset} =
               TrainContext.save_selector(element.id, %{input_id: input.id, positions: positions})

      assert ["must have unique indexes"] = errors_on(changeset).positions
    end

    test "rejects too few or too many positions", %{element: element, input: input} do
      [one | _] = three_positions()

      assert {:error, changeset} =
               TrainContext.save_selector(element.id, %{input_id: input.id, positions: [one]})

      assert ["must have between 2 and 12 positions"] = errors_on(changeset).positions

      thirteen =
        13
        |> SelectorMapper.even_split()
        |> Enum.map(&Map.merge(&1, set_value("A", 1.0)))

      assert {:error, changeset} =
               TrainContext.save_selector(element.id, %{input_id: input.id, positions: thirteen})

      assert ["must have between 2 and 12 positions"] = errors_on(changeset).positions
    end

    test "rejects a gap narrower than 0.02", %{element: element, input: input} do
      positions = [
        Map.merge(%{index: 0, input_min: 0.0, input_max: 0.5}, set_value("A", 0.0)),
        Map.merge(%{index: 1, input_min: 0.51, input_max: 1.0}, set_value("A", 1.0))
      ]

      assert {:error, changeset} =
               TrainContext.save_selector(element.id, %{input_id: input.id, positions: positions})

      assert [_] = errors_on(changeset).positions

      positions = List.update_at(positions, 1, &Map.put(&1, :input_min, 0.52))

      assert {:ok, _} =
               TrainContext.save_selector(element.id, %{input_id: input.id, positions: positions})
    end

    test "rejects ranges that only touch after rounding", %{element: element, input: input} do
      positions = [
        Map.merge(%{index: 0, input_min: 0.0, input_max: 0.304}, set_value("A", 0.0)),
        Map.merge(%{index: 1, input_min: 0.306, input_max: 1.0}, set_value("A", 1.0))
      ]

      assert {:error, changeset} =
               TrainContext.save_selector(element.id, %{input_id: input.id, positions: positions})

      assert [_] = errors_on(changeset).positions
    end

    test "moves the binding to another input", %{element: element, input: input} do
      {:ok, _} =
        TrainContext.save_selector(element.id, %{input_id: input.id, positions: three_positions()})

      other = analog_input_fixture(%{pin: 7})

      assert {:ok, binding} = TrainContext.save_selector(element.id, %{input_id: other.id})
      assert binding.input_id == other.id
      assert length(binding.positions) == 3
    end

    test "rejects a button input", %{element: element} do
      button = button_input_fixture()

      assert {:error, changeset} =
               TrainContext.save_selector(element.id, %{
                 input_id: button.id,
                 positions: three_positions()
               })

      assert "must be an analog input" in errors_on(changeset).input_id
    end

    test "rejects an uncalibrated input", %{element: element} do
      {:ok, input} =
        Trenino.Hardware.create_input(device_fixture().id, %{
          pin: 9,
          input_type: :analog,
          sensitivity: 5
        })

      assert {:error, changeset} =
               TrainContext.save_selector(element.id, %{
                 input_id: input.id,
                 positions: three_positions()
               })

      assert "must be calibrated first" in errors_on(changeset).input_id
    end

    test "rejects a nil enabled flag", %{element: element, input: input} do
      {:ok, _} =
        TrainContext.save_selector(element.id, %{input_id: input.id, positions: three_positions()})

      assert {:error, changeset} = TrainContext.save_selector(element.id, %{enabled: nil})
      assert "can't be blank" in errors_on(changeset).enabled
    end

    test "rejects an element that is not a selector", %{train: train, input: input} do
      {:ok, lever} = TrainContext.create_element(train.id, %{name: "Throttle", type: :lever})

      assert {:error, changeset} =
               TrainContext.save_selector(lever.id, %{
                 input_id: input.id,
                 positions: three_positions()
               })

      assert "must be a selector element" in errors_on(changeset).element_id
    end

    test "rejects an input already used by another selector on the train",
         %{train: train, element: element, input: input} do
      {:ok, _} =
        TrainContext.save_selector(element.id, %{input_id: input.id, positions: three_positions()})

      {:ok, other} = TrainContext.create_element(train.id, %{name: "Wipers", type: :selector})

      assert {:error, changeset} =
               TrainContext.save_selector(other.id, %{
                 input_id: input.id,
                 positions: three_positions()
               })

      assert "is already used by another selector on this train" in errors_on(changeset).input_id
    end

    test "allows the same input on a selector of another train",
         %{element: element, input: input} do
      {:ok, _} =
        TrainContext.save_selector(element.id, %{input_id: input.id, positions: three_positions()})

      {:ok, other_train} =
        TrainContext.create_train(%{name: "Other", identifiers: [%{identifier: "other_train"}]})

      {:ok, other} =
        TrainContext.create_element(other_train.id, %{name: "Lights", type: :selector})

      assert {:ok, _} =
               TrainContext.save_selector(other.id, %{
                 input_id: input.id,
                 positions: three_positions()
               })
    end

    test "conflicts with a virtual joystick mapping unless replacing",
         %{element: element, input: input} do
      {:ok, _mapping} =
        VirtualJoystick.put_mapping(input.id, %{target_type: :axis, axis: :slider_1})

      attrs = %{input_id: input.id, positions: three_positions()}

      assert {:error, :destination_conflict} = TrainContext.save_selector(element.id, attrs)
      assert {:ok, _} = TrainContext.save_selector(element.id, attrs, replace?: true)
      assert VirtualJoystick.list_mappings() == []
    end

    test "blocks a virtual joystick mapping on its input", %{element: element, input: input} do
      {:ok, _} =
        TrainContext.save_selector(element.id, %{input_id: input.id, positions: three_positions()})

      assert {:error, :destination_conflict} =
               VirtualJoystick.put_mapping(input.id, %{target_type: :axis, axis: :slider_1})

      assert {:ok, _} =
               VirtualJoystick.put_mapping(input.id, %{target_type: :axis, axis: :slider_1},
                 replace?: true
               )

      assert {:error, :not_found} = TrainContext.get_selector_binding(element.id)
    end
  end

  describe "sequence actions" do
    setup %{train: train} do
      {:ok, sequence} = TrainContext.create_sequence(train.id, %{name: "Lights on"})
      %{sequence: sequence}
    end

    defp with_sequences(sequence_id) do
      List.update_at(
        three_positions(),
        0,
        &Map.merge(&1, %{
          enter_kind: :sequence,
          enter_sequence_id: sequence_id,
          exit_kind: :sequence,
          exit_sequence_id: sequence_id
        })
      )
    end

    test "resets actions to none when the sequence is deleted",
         %{element: element, input: input, sequence: sequence} do
      {:ok, _} =
        TrainContext.save_selector(element.id, %{
          input_id: input.id,
          positions: with_sequences(sequence.id)
        })

      assert {:ok, _} = TrainContext.delete_sequence(sequence)

      assert {:ok, %{positions: [first, second | _]} = binding} =
               TrainContext.get_selector_binding(element.id)

      assert %{enter_kind: :none, enter_sequence_id: nil} = first
      assert %{exit_kind: :none, exit_sequence_id: nil} = first
      assert second.enter_kind == :set_value

      # The reset positions are still a valid set
      positions = Enum.map(binding.positions, &Map.from_struct/1)
      assert {:ok, _} = TrainContext.save_selector(element.id, %{positions: positions})
    end

    test "rejects a sequence of another train", %{element: element, input: input} do
      {:ok, other_train} =
        TrainContext.create_train(%{name: "Other", identifiers: [%{identifier: "other_seq"}]})

      {:ok, foreign} = TrainContext.create_sequence(other_train.id, %{name: "Foreign"})

      assert {:error, changeset} =
               TrainContext.save_selector(element.id, %{
                 input_id: input.id,
                 positions: with_sequences(foreign.id)
               })

      assert "refer to a sequence that does not exist or belongs to another train" in errors_on(
               changeset
             ).positions
    end
  end

  describe "enabling and disabling" do
    test "returns not_found without a binding", %{element: element} do
      assert {:error, :not_found} = TrainContext.set_selector_binding_enabled(element.id, true)
    end

    test "a disabled binding can share its input with a virtual joystick mapping",
         %{element: element, input: input} do
      {:ok, _} = VirtualJoystick.put_mapping(input.id, %{target_type: :axis, axis: :slider_1})

      assert {:ok, %{enabled: false}} =
               TrainContext.save_selector(element.id, %{
                 input_id: input.id,
                 enabled: false,
                 positions: three_positions()
               })

      assert {:error, :destination_conflict} =
               TrainContext.set_selector_binding_enabled(element.id, true)

      assert {:ok, %{enabled: true}} =
               TrainContext.set_selector_binding_enabled(element.id, true, replace?: true)

      assert VirtualJoystick.list_mappings() == []
    end
  end

  describe "listing and deleting" do
    setup %{element: element, input: input} do
      {:ok, binding} =
        TrainContext.save_selector(element.id, %{input_id: input.id, positions: three_positions()})

      %{binding: binding}
    end

    test "list_selector_bindings_for_train/1 returns only the train's bindings",
         %{train: train, binding: binding, input: input} do
      {:ok, other_train} =
        TrainContext.create_train(%{name: "Other", identifiers: [%{identifier: "other_list"}]})

      {:ok, other} = TrainContext.create_element(other_train.id, %{name: "X", type: :selector})

      {:ok, _} =
        TrainContext.save_selector(other.id, %{input_id: input.id, positions: three_positions()})

      assert [listed] = TrainContext.list_selector_bindings_for_train(train.id)
      assert listed.id == binding.id
      assert listed.element.type == :selector
      assert length(listed.positions) == 3
    end

    test "list_elements/1 preloads the selector binding", %{train: train} do
      assert {:ok, [%{selector_binding: %{positions: [_, _, _]}}]} =
               TrainContext.list_elements(train.id)
    end

    test "delete_selector_binding/1 removes binding and positions", %{element: element} do
      assert :ok = TrainContext.delete_selector_binding(element.id)
      assert {:error, :not_found} = TrainContext.get_selector_binding(element.id)
      assert {:error, :not_found} = TrainContext.delete_selector_binding(element.id)
      assert Repo.aggregate(SelectorPosition, :count) == 0
    end

    test "deleting the element cascades", %{element: element} do
      {:ok, _} = TrainContext.delete_element(element)

      assert {:error, :not_found} = TrainContext.get_selector_binding(element.id)
      assert Repo.aggregate(SelectorPosition, :count) == 0
    end
  end
end
