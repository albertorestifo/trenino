defmodule Trenino.Repo.Migrations.AddBldcLeverInputType do
  use Ecto.Migration

  def change do
    # Add BLDC hardware parameter columns
    alter table(:device_inputs) do
      add :motor_pin_a, :integer
      add :motor_pin_b, :integer
      add :motor_pin_c, :integer
      add :motor_enable_a, :integer
      add :motor_enable_b, :integer
      add :encoder_cs, :integer
      add :pole_pairs, :integer
      add :voltage, :integer
      add :current_limit, :integer
      add :encoder_bits, :integer
    end

    # Enforce one BLDC lever per device
    create unique_index(:device_inputs, [:device_id],
      where: "input_type = 'bldc_lever'",
      name: :device_inputs_one_bldc_per_device
    )
  end
end
