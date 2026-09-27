defmodule Trenino.Train.TrainIdentifierPersistenceTest do
  use Trenino.DataCase, async: true

  alias Trenino.Train, as: TrainContext
  alias Trenino.Train.Train

  test "creates a profile with trimmed equivalent identifiers" do
    attrs = %{
      name: "BR 423",
      identifiers: [
        %{identifier: " RVM_OTHER_DB_BR423 "},
        %{identifier: "RVM_FSN_DB_BR423"}
      ]
    }

    assert {:ok, train} = TrainContext.create_train(attrs)

    assert ["RVM_FSN_DB_BR423", "RVM_OTHER_DB_BR423"] ==
             train |> Repo.preload(:identifiers) |> Train.identifier_values()
  end

  test "requires at least one identifier" do
    assert {:error, changeset} =
             TrainContext.create_train(%{name: "BR 423", identifiers: []})

    assert %{identifiers: ["must have at least one identifier"]} = errors_on(changeset)
  end

  test "refuses to remove the last persisted identifier" do
    assert {:ok, train} =
             TrainContext.create_train(%{
               name: "BR 423",
               identifiers: [%{identifier: "RVM_FSN_DB_BR423"}]
             })

    train = Repo.preload(train, :identifiers)

    assert {:error, changeset} =
             TrainContext.update_train(train, %{identifiers: []})

    assert %{identifiers: ["must have at least one identifier"]} = errors_on(changeset)

    assert {:ok, reloaded} = TrainContext.get_train(train.id, preload: [:identifiers])
    assert Train.identifier_values(reloaded) == ["RVM_FSN_DB_BR423"]
  end

  test "rejects a whitespace-only identifier" do
    assert {:error, changeset} =
             TrainContext.create_train(%{
               name: "BR 423",
               identifiers: [%{identifier: "   "}]
             })

    assert %{identifiers: [%{identifier: ["can't be blank"]}]} = errors_on(changeset)
  end

  test "rejects duplicate identifiers within one profile" do
    assert {:error, changeset} =
             TrainContext.create_train(%{
               name: "BR 423",
               identifiers: [
                 %{identifier: "RVM_FSN_DB_BR423"},
                 %{identifier: " RVM_FSN_DB_BR423 "}
               ]
             })

    assert %{identifiers: ["must be unique within a train profile"]} = errors_on(changeset)
  end

  test "rejects an identifier owned by another profile" do
    assert {:ok, _train} =
             TrainContext.create_train(%{
               name: "First",
               identifiers: [%{identifier: "RVM_FSN_DB_BR423"}]
             })

    assert {:error, changeset} =
             TrainContext.create_train(%{
               name: "Second",
               identifiers: [%{identifier: "RVM_FSN_DB_BR423"}]
             })

    assert %{identifiers: [%{identifier: ["has already been taken"]}]} =
             errors_on(changeset)
  end

  test "reordering identifiers preserves the same set" do
    assert {:ok, train} =
             TrainContext.create_train(%{
               name: "BR 423",
               identifiers: [
                 %{identifier: "RVM_FSN_DB_BR423"},
                 %{identifier: "RVM_OTHER_DB_BR423"}
               ]
             })

    train = Repo.preload(train, :identifiers)
    [first, second] = train.identifiers

    assert {:ok, updated} =
             TrainContext.update_train(train, %{
               identifiers: [
                 %{id: second.id, identifier: second.identifier},
                 %{id: first.id, identifier: first.identifier}
               ]
             })

    assert ["RVM_FSN_DB_BR423", "RVM_OTHER_DB_BR423"] ==
             updated |> Repo.preload(:identifiers, force: true) |> Train.identifier_values()
  end

  test "a conflicting update preserves the previous identifier set" do
    assert {:ok, _first} =
             TrainContext.create_train(%{
               name: "First",
               identifiers: [%{identifier: "RVM_FSN_DB_BR423"}]
             })

    assert {:ok, second} =
             TrainContext.create_train(%{
               name: "Second",
               identifiers: [%{identifier: "RVM_OTHER_DB_BR423"}]
             })

    second = Repo.preload(second, :identifiers)
    [identifier] = second.identifiers

    assert {:error, _changeset} =
             TrainContext.update_train(second, %{
               identifiers: [%{id: identifier.id, identifier: "RVM_FSN_DB_BR423"}]
             })

    assert {:ok, reloaded} = TrainContext.get_train(second.id, preload: [:identifiers])
    assert Train.identifier_values(reloaded) == ["RVM_OTHER_DB_BR423"]
  end
end
