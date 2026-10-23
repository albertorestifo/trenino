defmodule Trenino.Train.TrainIdentifierTest do
  use ExUnit.Case, async: true

  alias Trenino.Train.TrainIdentifier

  test "clearing an identifier returns a required-field error instead of raising" do
    for blank <- ["", "   ", nil] do
      changeset =
        TrainIdentifier.changeset(%TrainIdentifier{identifier: "OldPrefix"}, %{
          identifier: blank
        })

      refute changeset.valid?
      assert {"can't be blank", _} = changeset.errors[:identifier]
    end
  end

  test "trims surrounding whitespace from a nonempty identifier" do
    changeset = TrainIdentifier.changeset(%TrainIdentifier{}, %{identifier: "  NewPrefix  "})
    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :identifier) == "NewPrefix"
  end
end
