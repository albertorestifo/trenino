defmodule TswIo.Repo.Migrations.CreateSimulatorConfigs do
  use Ecto.Migration

  def change do
    create table(:simulator_configs) do
      add :url, :string, null: false
      add :api_key, :string, null: false
      add :auto_detected, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
