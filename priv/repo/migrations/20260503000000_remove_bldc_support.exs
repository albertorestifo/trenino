defmodule Trenino.Repo.Migrations.RemoveBldcSupport do
  use Ecto.Migration

  @bldc_notch_cols ~w(bldc_detent_strength bldc_damping bldc_engagement bldc_hold bldc_exit bldc_spring_back)
  @bldc_input_cols ~w(motor_pin_a motor_pin_b motor_pin_c motor_enable_a motor_enable_b motor_enable encoder_cs pole_pairs voltage current_limit encoder_bits)
  @bldc_config_cols ~w(bldc_snap_point bldc_endstop_strength)

  def up do
    execute "UPDATE train_lever_configs SET lever_type = NULL WHERE lever_type = 'bldc'"

    drop_if_exists index(:device_inputs, [:device_id],
                     name: :device_inputs_one_bldc_per_device
                   )

    drop_cols_if_exist("device_inputs", @bldc_input_cols)
    drop_cols_if_exist("train_lever_notches", @bldc_notch_cols)
    drop_cols_if_exist("train_lever_configs", @bldc_config_cols)
  end

  def down do
    raise "Irreversible migration: BLDC support has been permanently removed"
  end

  defp drop_cols_if_exist(table, cols) do
    {:ok, %{rows: rows}} = repo().query("PRAGMA table_info(#{table})")
    existing_cols = Enum.map(rows, fn [_cid, name | _] -> name end)

    for col <- cols, col in existing_cols do
      repo().query!("ALTER TABLE #{table} DROP COLUMN #{col}")
    end
  end
end
