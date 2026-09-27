defmodule Trenino.Repo.Migrations.CreateTrainIdentifiers do
  use Ecto.Migration

  def up do
    execute(&validate_legacy_identifiers!/0)

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
    SELECT id, TRIM(identifier), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
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

  defp validate_legacy_identifiers! do
    case repo().query!("SELECT identifier FROM trains WHERE TRIM(identifier) = '' LIMIT 1").rows do
      [] -> :ok
      _rows -> raise "cannot migrate a blank train identifier; update it before upgrading"
    end

    collision_query = """
    SELECT TRIM(identifier)
    FROM trains
    GROUP BY TRIM(identifier)
    HAVING COUNT(*) > 1
    LIMIT 1
    """

    case repo().query!(collision_query).rows do
      [] ->
        :ok

      [[identifier]] ->
        raise "cannot migrate: multiple trains have the same normalized identifier " <>
                "#{inspect(identifier)}; resolve the whitespace collision before upgrading"
    end
  end
end
