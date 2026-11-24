defmodule Trenino.Repo.Migrations.AddSensorToDeviceInputs do
  @moduledoc """
  Analog inputs can be read by an MT6701 magnetic angle sensor over I2C (firmware 3.4.0)
  instead of the Arduino ADC. Existing inputs keep `sensor = "adc"`.
  """
  use Ecto.Migration

  def change do
    alter table(:device_inputs) do
      add :sensor, :string, null: false, default: "adc"
      add :i2c_address, :integer
    end
  end
end
