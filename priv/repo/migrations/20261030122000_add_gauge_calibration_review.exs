defmodule Trenino.Repo.Migrations.AddGaugeCalibrationReview do
  use Ecto.Migration

  def change do
    alter table(:train_gauge_bindings) do
      add :calibration_reviewed, :boolean, null: false, default: false
    end
  end
end
