defmodule Trenino.Repo.Migrations.CreateSelectors do
  use Ecto.Migration

  def change do
    create table(:selector_bindings) do
      add :element_id, references(:train_elements, on_delete: :delete_all), null: false
      add :input_id, references(:device_inputs, on_delete: :delete_all), null: false
      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create unique_index(:selector_bindings, [:element_id])
    create index(:selector_bindings, [:input_id])

    create table(:selector_positions) do
      add :selector_binding_id, references(:selector_bindings, on_delete: :delete_all),
        null: false

      add :index, :integer, null: false
      add :label, :string
      add :input_min, :float, null: false
      add :input_max, :float, null: false

      add :enter_kind, :string, null: false
      add :enter_endpoint, :string
      add :enter_value, :float
      add :enter_sequence_id, references(:sequences, on_delete: :nilify_all)
      add :enter_keystroke, :string

      add :exit_kind, :string, null: false, default: "none"
      add :exit_endpoint, :string
      add :exit_value, :float
      add :exit_sequence_id, references(:sequences, on_delete: :nilify_all)
      add :exit_keystroke, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:selector_positions, [:selector_binding_id, :index])
    create index(:selector_positions, [:enter_sequence_id])
    create index(:selector_positions, [:exit_sequence_id])
  end
end
