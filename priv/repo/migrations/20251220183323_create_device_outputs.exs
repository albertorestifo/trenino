defmodule TswIo.Repo.Migrations.CreateDeviceOutputs do
  use Ecto.Migration

  def change do
    create table(:device_outputs) do
      add :pin, :integer, null: false
      add :name, :string
      add :device_id, references(:devices, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:device_outputs, [:device_id])
    create unique_index(:device_outputs, [:device_id, :pin])
  end
end
