defmodule Trenino.Repo.Migrations.AddBldcSupport do
  use Ecto.Migration

  def change do
    # Add BLDC haptic parameter fields to notches table with inline CHECK constraints
    alter table(:train_lever_notches) do
      add :bldc_engagement, :integer,
        check: %{
          name: "bldc_engagement_range",
          expr: "bldc_engagement IS NULL OR (bldc_engagement >= 0 AND bldc_engagement <= 255)"
        }

      add :bldc_hold, :integer,
        check: %{
          name: "bldc_hold_range",
          expr: "bldc_hold IS NULL OR (bldc_hold >= 0 AND bldc_hold <= 255)"
        }

      add :bldc_exit, :integer,
        check: %{
          name: "bldc_exit_range",
          expr: "bldc_exit IS NULL OR (bldc_exit >= 0 AND bldc_exit <= 255)"
        }

      add :bldc_spring_back, :integer,
        check: %{
          name: "bldc_spring_back_range",
          expr: "bldc_spring_back IS NULL OR (bldc_spring_back >= 0 AND bldc_spring_back <= 255)"
        }

      add :bldc_damping, :integer,
        check: %{
          name: "bldc_damping_range",
          expr: "bldc_damping IS NULL OR (bldc_damping >= 0 AND bldc_damping <= 255)"
        }
    end
  end
end
