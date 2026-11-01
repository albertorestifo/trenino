defmodule Trenino.Repo.Migrations.CreateTrainGaugeBindings do
  use Ecto.Migration

  def change do
    create table(:train_gauge_bindings) do
      add :train_id, references(:trains, on_delete: :delete_all), null: false

      add :stepper_axis_id, references(:hardware_stepper_axes, on_delete: :delete_all),
        null: false

      for field <- [
            :name,
            :endpoint,
            :input_unit,
            :output_unit,
            :out_of_range,
            :inactive_behavior
          ],
          do: add(field, :string, null: false)

      add :value_key, :string
      add :multiplier, :float, null: false, default: 1.0
      add :offset, :float, null: false, default: 0.0
      add :absolute_value, :boolean, null: false, default: false
      add :enabled, :boolean, null: false, default: false
      add :calibration_valid, :boolean, null: false, default: true
      add :stale_after_ms, :integer, null: false, default: 2000
      add :points, :map, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:train_gauge_bindings, [:train_id, :stepper_axis_id])
  end
end
