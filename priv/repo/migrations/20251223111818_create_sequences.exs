defmodule TswIo.Repo.Migrations.CreateSequences do
  use Ecto.Migration

  def change do
    # Create sequences table
    create table(:sequences) do
      add :name, :string, null: false
      add :train_id, references(:trains, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:sequences, [:train_id])
    create unique_index(:sequences, [:train_id, :name])

    # Create sequence_commands table
    create table(:sequence_commands) do
      add :sequence_id, references(:sequences, on_delete: :delete_all), null: false
      add :position, :integer, null: false
      add :endpoint, :string, null: false
      add :value, :float, null: false
      add :delay_ms, :integer, null: false, default: 0
      timestamps(type: :utc_datetime)
    end

    create index(:sequence_commands, [:sequence_id])
    create unique_index(:sequence_commands, [:sequence_id, :position])

    # Add sequence references to button_input_bindings
    alter table(:button_input_bindings) do
      add :on_sequence_id, references(:sequences, on_delete: :nilify_all)
      add :off_sequence_id, references(:sequences, on_delete: :nilify_all)
    end

    create index(:button_input_bindings, [:on_sequence_id])
    create index(:button_input_bindings, [:off_sequence_id])
  end
end
