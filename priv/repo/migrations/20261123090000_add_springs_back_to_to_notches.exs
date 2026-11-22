defmodule Trenino.Repo.Migrations.AddSpringsBackToToNotches do
  use Ecto.Migration

  # The notch index a cab lever springs back to from this notch (SimRail's
  # momentary positions), or nil when it holds. Used only to design notch
  # disks and explain the mapping; runtime treats every notch the same.
  def change do
    alter table(:train_lever_notches) do
      add :springs_back_to, :integer
    end
  end
end
