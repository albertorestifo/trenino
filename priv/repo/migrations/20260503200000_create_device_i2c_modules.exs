defmodule Trenino.Repo.Migrations.CreateDeviceI2cModules do
  use Ecto.Migration

  def change do
    create table(:device_i2c_modules) do
      add :device_id, references(:devices, on_delete: :delete_all), null: false
      add :name, :string
      add :module_chip, :string, null: false
      add :i2c_address, :integer, null: false
      add :brightness, :integer, null: false, default: 8
      add :num_digits, :integer, null: false, default: 4
      timestamps(type: :utc_datetime)
    end

    create index(:device_i2c_modules, [:device_id])
    create unique_index(:device_i2c_modules, [:device_id, :i2c_address])
  end
end
