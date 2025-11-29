defmodule TswIo.Repo.Migrations.CreateTrainLeverConfigs do
  use Ecto.Migration

  def change do
    create table(:train_lever_configs) do
      add :element_id, references(:train_elements, on_delete: :delete_all), null: false
      add :min_endpoint, :string, null: false
      add :max_endpoint, :string, null: false
      add :value_endpoint, :string, null: false
      add :notch_count_endpoint, :string
      add :notch_index_endpoint, :string
      add :calibrated_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:train_lever_configs, [:element_id])
  end
end
