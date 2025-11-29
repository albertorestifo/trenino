defmodule TswIo.Repo.Migrations.CreateTrains do
  use Ecto.Migration

  def change do
    create table(:trains) do
      add :name, :string, null: false
      add :description, :string
      add :identifier, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:trains, [:identifier])
  end
end
