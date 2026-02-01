defmodule Trenino.Repo.Migrations.CreateScripts do
  use Ecto.Migration

  def change do
    create table(:scripts) do
      add :train_id, references(:trains, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :enabled, :boolean, null: false, default: true
      add :code, :text, null: false, default: ""
      add :triggers, :string, null: false, default: "[]"

      timestamps(type: :utc_datetime)
    end

    create index(:scripts, [:train_id])
    create unique_index(:scripts, [:train_id, :name])
  end
end
