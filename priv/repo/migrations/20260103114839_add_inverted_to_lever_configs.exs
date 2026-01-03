defmodule TswIo.Repo.Migrations.AddInvertedToLeverConfigs do
  use Ecto.Migration

  def change do
    alter table(:train_lever_configs) do
      # When true, inverts the hardware input value before mapping to simulator
      # Use when hardware min = simulator max (lever direction is opposite)
      add :inverted, :boolean, default: false, null: false
    end
  end
end
