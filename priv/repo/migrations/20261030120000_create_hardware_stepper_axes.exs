defmodule Trenino.Repo.Migrations.CreateHardwareStepperAxes do
  use Ecto.Migration

  def change do
    create table(:hardware_stepper_axes) do
      add :device_id, references(:devices, on_delete: :delete_all), null: false
      add :name, :string, null: false

      for field <- [
            :driver,
            :mode,
            :idle_behavior,
            :host_loss_behavior,
            :reference_strategy,
            :startup_reference
          ] do
        add field, :string, null: false
      end

      for field <- [
            :axis_index,
            :shield_address,
            :motor_port,
            :min_position,
            :max_position,
            :max_speed,
            :acceleration,
            :home_direction,
            :home_steps,
            :home_speed,
            :home_timeout_ms,
            :home_position,
            :watchdog_ms,
            :home_backoff
          ] do
        add field, :integer, null: false
      end

      add :reverse, :boolean, null: false, default: false
      add :commissioned, :boolean, null: false, default: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:hardware_stepper_axes, [:device_id, :axis_index])
    create unique_index(:hardware_stepper_axes, [:device_id, :motor_port])
  end
end
