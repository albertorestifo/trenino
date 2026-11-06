defmodule Trenino.Train.ActionTest do
  use ExUnit.Case, async: true

  alias Trenino.Train.{Action, SelectorPosition, Sequence, SequenceCommand}

  defp sequence do
    %Sequence{
      id: 7,
      commands: [
        %SequenceCommand{position: 0, endpoint: "A.InputValue", value: 1.0, delay_ms: 100},
        %SequenceCommand{position: 1, endpoint: "B.InputValue", value: 0.0, delay_ms: 0}
      ]
    }
  end

  test "builds a set_value enter action" do
    position = %SelectorPosition{
      enter_kind: :set_value,
      enter_endpoint: "Lights.InputValue",
      enter_value: 0.5
    }

    assert %Action{kind: :set_value, endpoint: "Lights.InputValue", value: 0.5} =
             Action.from_position(position, :enter)
  end

  test "builds a keystroke exit action" do
    position = %SelectorPosition{exit_kind: :keystroke, exit_keystroke: "CTRL+L"}

    assert %Action{kind: :keystroke, keystroke: "CTRL+L"} = Action.from_position(position, :exit)
  end

  test "builds a sequence action with its commands" do
    position = %SelectorPosition{
      enter_kind: :sequence,
      enter_sequence_id: 7,
      enter_sequence: sequence()
    }

    assert %Action{
             kind: :sequence,
             sequence_id: 7,
             commands: [
               %{endpoint: "A.InputValue", value: 1.0, delay_ms: 100},
               %{endpoint: "B.InputValue", value: +0.0, delay_ms: 0}
             ]
           } = Action.from_position(position, :enter)
  end

  test "returns nil for :none" do
    assert Action.from_position(%SelectorPosition{enter_kind: :none}, :enter) == nil
    assert Action.from_position(%SelectorPosition{}, :exit) == nil
  end

  test "returns nil for a sequence action without a loaded sequence" do
    position = %SelectorPosition{enter_kind: :sequence, enter_sequence_id: nil}
    assert Action.from_position(position, :enter) == nil

    not_loaded = %SelectorPosition{exit_kind: :sequence, exit_sequence_id: 3}
    assert Action.from_position(not_loaded, :exit) == nil
  end
end
