defmodule Trenino.Repo.Migrations.ReplaceStepperAxesWithGauges do
  @moduledoc """
  Firmware 3.3.0 removed the stepper axis extension (PCA9685 shield, messages 16/17) and
  added X27 gauge modules. The old axes, their dial calibrations and the train bindings on
  them cannot run on the new firmware, so they are dropped, not converted: gauges are set up
  again on the new tables. Irreversible.
  """
  use Ecto.Migration

  def up do
    drop table(:train_gauge_bindings)
    drop table(:hardware_stepper_dial_calibrations)
    drop table(:hardware_stepper_axes)

    create table(:hardware_gauges) do
      add :device_id, references(:devices, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :driver, :string, null: false
      add :pins, {:array, :integer}, null: false
      add :travel, :integer, null: false
      add :max_speed, :integer, null: false
      add :acceleration, :integer, null: false
      add :reverse, :boolean, null: false, default: false
      timestamps(type: :utc_datetime)
    end

    create index(:hardware_gauges, [:device_id])

    create table(:hardware_dial_calibrations) do
      add :gauge_id, references(:hardware_gauges, on_delete: :delete_all), null: false
      add :output_unit, :string, null: false, default: "raw"
      add :valid, :boolean, null: false, default: true
      add :reviewed, :boolean, null: false, default: false
      add :points, :map, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:hardware_dial_calibrations, [:gauge_id])

    create table(:train_gauge_bindings) do
      add :train_id, references(:trains, on_delete: :delete_all), null: false
      add :gauge_id, references(:hardware_gauges, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :endpoint, :string, null: false
      add :value_key, :string
      add :input_unit, :string, null: false
      add :multiplier, :float, null: false, default: 1.0
      add :offset, :float, null: false, default: 0.0
      add :absolute_value, :boolean, null: false, default: false
      add :out_of_range, :string, null: false
      add :stale_after_ms, :integer, null: false, default: 2000
      add :enabled, :boolean, null: false, default: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:train_gauge_bindings, [:train_id, :gauge_id])
    create index(:train_gauge_bindings, [:gauge_id])
  end

  def down do
    raise Ecto.MigrationError,
          "replace_stepper_axes_with_gauges is irreversible: the old stepper axis data is gone"
  end
end
