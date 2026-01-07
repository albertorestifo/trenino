defmodule Trenino.Repo.Migrations.AllowNullableValueAForBooleanOperators do
  use Ecto.Migration

  def change do
    # SQLite doesn't support ALTER COLUMN, so we recreate the table
    # Allow value_a to be null for boolean operators (eq_true, eq_false)

    # Create new table with nullable value_a
    create table(:train_output_bindings_new) do
      add :train_id, references(:trains, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :output_type, :string, null: false, default: "led"
      add :output_id, references(:device_outputs, on_delete: :delete_all), null: false
      add :endpoint, :string, null: false
      add :operator, :string, null: false
      add :value_a, :float, null: true
      add :value_b, :float

      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    # Copy data
    execute """
    INSERT INTO train_output_bindings_new (id, train_id, name, output_type, output_id, endpoint, operator, value_a, value_b, enabled, inserted_at, updated_at)
    SELECT id, train_id, name, output_type, output_id, endpoint, operator, value_a, value_b, enabled, inserted_at, updated_at
    FROM train_output_bindings
    """

    # Drop old table
    drop table(:train_output_bindings)

    # Rename new table
    rename table(:train_output_bindings_new), to: table(:train_output_bindings)

    # Recreate indexes
    create index(:train_output_bindings, [:train_id])
    create unique_index(:train_output_bindings, [:train_id, :output_id])
  end
end
