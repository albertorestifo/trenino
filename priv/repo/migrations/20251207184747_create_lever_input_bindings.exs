defmodule Trenino.Repo.Migrations.CreateLeverInputBindings do
  use Ecto.Migration

  def change do
    # Create lever input bindings table
    create table(:lever_input_bindings) do
      add :lever_config_id, references(:train_lever_configs, on_delete: :delete_all), null: false
      add :input_id, references(:device_inputs, on_delete: :delete_all), null: false
      add :enabled, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    # One binding per lever config
    create unique_index(:lever_input_bindings, [:lever_config_id])
    # For querying bindings by input
    create index(:lever_input_bindings, [:input_id])

    # Add input range fields to notches
    alter table(:train_lever_notches) do
      add :input_min, :float
      add :input_max, :float
    end
  end
end
