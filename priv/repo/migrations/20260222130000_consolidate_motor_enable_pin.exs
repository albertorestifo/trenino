defmodule Trenino.Repo.Migrations.ConsolidateMotorEnablePin do
  use Ecto.Migration

  def up do
    alter table(:device_inputs) do
      add :motor_enable, :integer
    end

    execute("UPDATE device_inputs SET motor_enable = motor_enable_a WHERE motor_enable_a IS NOT NULL")

    alter table(:device_inputs) do
      remove :motor_enable_a
      remove :motor_enable_b
    end
  end

  def down do
    alter table(:device_inputs) do
      add :motor_enable_a, :integer
      add :motor_enable_b, :integer
    end

    execute("UPDATE device_inputs SET motor_enable_a = motor_enable WHERE motor_enable IS NOT NULL")

    alter table(:device_inputs) do
      remove :motor_enable
    end
  end
end
