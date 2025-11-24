defmodule TswIo.Repo.Migrations.CreateDeviceInputCalibrations do
  use Ecto.Migration

  def change do
    create table(:device_input_calibrations) do
      add :max_hardware_value, :integer
      add :min_value, :integer
      add :max_value, :integer
      add :has_rollover, :boolean, default: false, null: false
      add :is_inverted, :boolean, default: false, null: false
      add :input_id, references(:device_inputs, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:device_input_calibrations, [:input_id])
  end
end
