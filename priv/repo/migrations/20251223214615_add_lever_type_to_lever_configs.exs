defmodule TswIo.Repo.Migrations.AddLeverTypeToLeverConfigs do
  use Ecto.Migration

  def change do
    alter table(:train_lever_configs) do
      # Lever type detected by LeverAnalyzer: discrete, continuous, or hybrid
      add :lever_type, :string
    end
  end
end
