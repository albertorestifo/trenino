defmodule Trenino.Train.TrainIdentifierMatchingTest do
  use Trenino.DataCase, async: true

  alias Trenino.Train, as: TrainContext

  test "matches any unrelated identifier owned by the same profile" do
    {:ok, train} =
      create_train("BR 423", ["RVM_FSN_DB_BR423", "RVM_OTHER_DB_BR423"])

    assert {:ok, %{id: train_id}} =
             TrainContext.get_train_by_identifier("RVM_OTHER_DB_BR423_VARIANT")

    assert train_id == train.id
  end

  test "keeps prefix matching for every stored identifier" do
    {:ok, train} = create_train("BR 423", ["RVM_FSN_DB_BR423"])

    assert {:ok, %{id: train_id}} =
             TrainContext.get_train_by_identifier("RVM_FSN_DB_BR423_RED")

    assert train_id == train.id
  end

  test "keeps identifier matching case-sensitive" do
    {:ok, _train} = create_train("BR 423", ["RVM_OTHER_DB_BR423"])

    assert {:error, :not_found} =
             TrainContext.get_train_by_identifier("rvm_other_db_br423_variant")
  end

  test "deduplicates overlapping identifiers owned by one profile" do
    {:ok, train} = create_train("BR 423", ["RVM_DB_BR423", "RVM_DB_BR423_RED"])

    assert {:ok, %{id: train_id}} =
             TrainContext.get_train_by_identifier("RVM_DB_BR423_RED_VARIANT")

    assert train_id == train.id
  end

  test "returns ambiguity when overlapping identifiers belong to different profiles" do
    {:ok, first} = create_train("BR 423", ["RVM_DB_BR423"])
    {:ok, second} = create_train("BR 423 Red", ["RVM_DB_BR423_RED"])

    assert {:error, {:multiple_matches, matches}} =
             TrainContext.get_train_by_identifier("RVM_DB_BR423_RED_VARIANT")

    assert Enum.sort(Enum.map(matches, & &1.id)) == Enum.sort([first.id, second.id])
  end

  describe "SimRail" do
    test "a class identifier covers its vehicles, not other classes" do
      {:ok, eu07} = create_train("EU07", ["4e/eu07"], :simrail)

      assert {:ok, %{id: id}} = TrainContext.get_train_by_identifier("4e/eu07-193", :simrail)
      assert id == eu07.id
      assert {:ok, _} = TrainContext.get_train_by_identifier("4e/eu07", :simrail)

      assert {:error, :not_found} =
               TrainContext.get_train_by_identifier("4e/eu07a-001", :simrail)
    end

    test "a family identifier covers its classes" do
      {:ok, family} = create_train("Pendolino", ["pendolino"], :simrail)

      assert {:ok, %{id: id}} =
               TrainContext.get_train_by_identifier("pendolino/ed250-018 variant", :simrail)

      assert id == family.id
      assert {:error, :not_found} = TrainContext.get_train_by_identifier("pendolinox/a-1")
    end

    test "only trains of the requested simulator match" do
      {:ok, _tsw} = create_train("TSW", ["4e/eu07"], :tsw)
      assert {:error, :not_found} = TrainContext.get_train_by_identifier("4e/eu07-1", :simrail)
      assert {:ok, _} = TrainContext.get_train_by_identifier("4e/eu07a-1", :tsw)
    end
  end

  defp create_train(name, identifiers, simulator \\ :tsw) do
    TrainContext.create_train(%{
      name: name,
      simulator: simulator,
      identifiers: Enum.map(identifiers, &%{identifier: &1})
    })
  end
end
