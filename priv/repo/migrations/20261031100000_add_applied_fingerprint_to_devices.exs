defmodule Trenino.Repo.Migrations.AddAppliedFingerprintToDevices do
  use Ecto.Migration

  def change do
    alter table(:devices) do
      add :applied_fingerprint, :string
    end
  end
end
