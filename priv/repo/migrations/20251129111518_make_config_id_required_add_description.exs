defmodule TswIo.Repo.Migrations.MakeConfigIdRequiredAddDescription do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :description, :text
    end
  end
end
