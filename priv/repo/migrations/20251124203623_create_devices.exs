defmodule TswIo.Repo.Migrations.CreateDeviceConfigs do
  use Ecto.Migration

  def change do
    create table(:devices) do
      add :name, :string
      add :config_id, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:devices, [:config_id], unique: true)
  end
end
