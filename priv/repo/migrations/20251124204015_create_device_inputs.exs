defmodule Trenino.Repo.Migrations.CreateDeviceInputs do
  use Ecto.Migration

  def change do
    create table(:device_inputs) do
      add :pin, :integer
      add :input_type, :string
      add :sensitivity, :integer
      add :device_id, references(:devices, on_delete: :nothing)

      timestamps(type: :utc_datetime)
    end

    create index(:device_inputs, [:device_id])
  end
end
