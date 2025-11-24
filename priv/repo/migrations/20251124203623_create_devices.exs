defmodule TswIo.Repo.Migrations.CreateDevices do
  use Ecto.Migration

  def change do
    create table(:devices) do
      add :name, :string

      timestamps(type: :utc_datetime)
    end
  end
end
