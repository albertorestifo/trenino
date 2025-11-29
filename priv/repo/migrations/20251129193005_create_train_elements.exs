defmodule TswIo.Repo.Migrations.CreateTrainElements do
  use Ecto.Migration

  def change do
    create table(:train_elements) do
      add :train_id, references(:trains, on_delete: :delete_all), null: false
      add :type, :string, null: false
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:train_elements, [:train_id])
  end
end
