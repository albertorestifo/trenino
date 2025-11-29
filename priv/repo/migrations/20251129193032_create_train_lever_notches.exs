defmodule TswIo.Repo.Migrations.CreateTrainLeverNotches do
  use Ecto.Migration

  def change do
    create table(:train_lever_notches) do
      add :lever_config_id, references(:train_lever_configs, on_delete: :delete_all), null: false
      add :index, :integer, null: false
      add :type, :string, null: false
      add :value, :float
      add :min_value, :float
      add :max_value, :float
      add :description, :string

      timestamps(type: :utc_datetime)
    end

    create index(:train_lever_notches, [:lever_config_id])
    create unique_index(:train_lever_notches, [:lever_config_id, :index])
  end
end
