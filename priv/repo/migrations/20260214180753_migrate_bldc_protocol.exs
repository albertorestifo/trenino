defmodule Trenino.Repo.Migrations.MigrateBldcProtocol do
  use Ecto.Migration

  def up do
    # Add new column to notches
    alter table(:train_lever_notches) do
      add :bldc_detent_strength, :integer
    end

    # Migrate data: use old bldc_hold as the new bldc_detent_strength
    execute(
      "UPDATE train_lever_notches SET bldc_detent_strength = bldc_hold WHERE bldc_hold IS NOT NULL"
    )

    # Remove old columns from notches
    alter table(:train_lever_notches) do
      remove :bldc_engagement
      remove :bldc_hold
      remove :bldc_exit
      remove :bldc_spring_back
    end

    # Add new profile-level fields to lever_configs
    alter table(:train_lever_configs) do
      add :bldc_snap_point, :integer
      add :bldc_endstop_strength, :integer
    end
  end

  def down do
    # Remove new columns from lever_configs
    alter table(:train_lever_configs) do
      remove :bldc_endstop_strength
      remove :bldc_snap_point
    end

    # Re-add old columns to notches
    alter table(:train_lever_notches) do
      add :bldc_engagement, :integer
      add :bldc_hold, :integer
      add :bldc_exit, :integer
      add :bldc_spring_back, :integer
    end

    # Migrate data back: use bldc_detent_strength as bldc_hold
    execute(
      "UPDATE train_lever_notches SET bldc_hold = bldc_detent_strength WHERE bldc_detent_strength IS NOT NULL"
    )

    # Remove new column
    alter table(:train_lever_notches) do
      remove :bldc_detent_strength
    end
  end
end
