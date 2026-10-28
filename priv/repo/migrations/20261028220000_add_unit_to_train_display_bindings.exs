defmodule Trenino.Repo.Migrations.AddUnitToTrainDisplayBindings do
  use Ecto.Migration

  def change do
    alter table(:train_display_bindings) do
      add :unit, :string, null: false, default: "none"
    end
  end
end
