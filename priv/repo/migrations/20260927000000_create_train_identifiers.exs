defmodule Trenino.Repo.Migrations.CreateTrainIdentifiers do
  use Ecto.Migration

  def up do
    create table(:train_identifiers) do
      add :train_id, references(:trains, on_delete: :delete_all), null: false
      add :identifier, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:train_identifiers, [:train_id])
    create unique_index(:train_identifiers, [:identifier])

    flush()

    execute """
    INSERT INTO train_identifiers (train_id, identifier, inserted_at, updated_at)
    SELECT id, identifier, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    FROM trains
    """

    drop unique_index(:trains, [:identifier])

    alter table(:trains) do
      remove :identifier
    end
  end

  def down do
    raise "cannot restore trains.identifier without inventing a primary identifier and discarding data"
  end
end
