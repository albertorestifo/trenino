defmodule TswIo.Repo.Migrations.AllowNullablePinForMatrixInputs do
  use Ecto.Migration

  def up do
    # Drop the existing unique constraint
    drop_if_exists unique_index(:device_inputs, [:device_id, :pin])

    # Add a partial unique index that only applies when pin is not null
    # This allows multiple matrix inputs (pin=null) while preventing
    # duplicate real GPIO pins on the same device
    create unique_index(:device_inputs, [:device_id, :pin],
             where: "pin IS NOT NULL",
             name: :device_inputs_device_id_pin_unique
           )

    # Update existing matrix inputs to have null pin
    execute "UPDATE device_inputs SET pin = NULL WHERE input_type = 'matrix'"
  end

  def down do
    # Set matrix inputs back to pin=-1 before recreating the constraint
    execute "UPDATE device_inputs SET pin = -1 WHERE input_type = 'matrix'"

    drop_if_exists unique_index(:device_inputs, [:device_id, :pin],
                     name: :device_inputs_device_id_pin_unique
                   )

    create unique_index(:device_inputs, [:device_id, :pin])
  end
end
