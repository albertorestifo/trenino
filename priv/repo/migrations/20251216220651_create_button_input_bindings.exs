defmodule TswIo.Repo.Migrations.CreateButtonInputBindings do
  use Ecto.Migration

  def change do
    create table(:button_input_bindings) do
      add :input_id, references(:device_inputs, on_delete: :delete_all), null: false
      add :element_id, references(:train_elements, on_delete: :delete_all), null: false
      add :endpoint, :string, null: false
      add :on_value, :float, null: false, default: 1.0
      add :off_value, :float, null: false, default: 0.0
      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:button_input_bindings, [:element_id])
    create index(:button_input_bindings, [:input_id])
  end
end
