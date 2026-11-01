defmodule Trenino.Repo.Migrations.AddI2cModuleToDeviceInputs do
  use Ecto.Migration

  def change do
    alter table(:device_inputs) do
      add :i2c_module_id, references(:device_i2c_modules, on_delete: :nothing)
      add :i2c_channel, :integer
    end

    create index(:device_inputs, [:i2c_module_id])
    create unique_index(:device_inputs, [:i2c_module_id, :i2c_channel])
  end
end
