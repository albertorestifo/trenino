defmodule TswIo.Repo.Migrations.AddButtonMatrixInputTypes do
  use Ecto.Migration

  def change do
    # Add debounce column for button inputs (nullable, only used by button type)
    alter table(:device_inputs) do
      add :debounce, :integer
    end

    # Create matrix pins table for matrix input configurations
    create table(:device_input_matrix_pins) do
      add :input_id, references(:device_inputs, on_delete: :delete_all), null: false
      add :pin_type, :string, null: false
      add :pin, :integer, null: false
      add :position, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:device_input_matrix_pins, [:input_id])
    create unique_index(:device_input_matrix_pins, [:input_id, :pin_type, :position])
  end
end
