defmodule Trenino.Repo.Migrations.AddSimulatorToTrains do
  use Ecto.Migration

  # Every existing train profile was made for Train Sim World.
  def change do
    alter table(:trains) do
      add :simulator, :string, null: false, default: "tsw"
    end

    create index(:trains, [:simulator])
  end
end
