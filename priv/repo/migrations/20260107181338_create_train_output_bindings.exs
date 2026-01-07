defmodule Trenino.Repo.Migrations.CreateTrainOutputBindings do
  use Ecto.Migration

  def change do
    create table(:train_output_bindings) do
      add :train_id, references(:trains, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :output_type, :string, null: false, default: "led"
      add :output_id, references(:device_outputs, on_delete: :delete_all), null: false
      add :endpoint, :string, null: false
      add :operator, :string, null: false
      add :value_a, :float, null: false
      add :value_b, :float
      add :enabled, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:train_output_bindings, [:train_id])
    create unique_index(:train_output_bindings, [:train_id, :output_id])
  end
end
