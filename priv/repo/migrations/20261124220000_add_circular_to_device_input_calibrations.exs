defmodule Trenino.Repo.Migrations.AddCircularToDeviceInputCalibrations do
  @moduledoc """
  Calibrations of magnetic angle sensors are circular: the travel may cross the
  sensor's 0/max point anywhere. Existing ADC calibrations are not; any made for an
  MT6701 before this migration become circular.
  """
  use Ecto.Migration

  def change do
    alter table(:device_input_calibrations) do
      add :circular, :boolean, null: false, default: false
    end

    execute(
      """
      UPDATE device_input_calibrations SET circular = 1
      WHERE input_id IN (SELECT id FROM device_inputs WHERE sensor <> 'adc')
      """,
      "SELECT 1"
    )
  end
end
