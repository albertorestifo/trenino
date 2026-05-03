defmodule Trenino.Repo.Migrations.MigrateSimulatorConfigsToAppSettings do
  use Ecto.Migration

  import Ecto.Query

  def up do
    flush()

    repo = repo()

    rows =
      repo.all(
        from(c in "simulator_configs",
          select: %{
            url: c.url,
            api_key: c.api_key,
            auto_detected: c.auto_detected
          }
        )
      )

    Enum.each(rows, fn row ->
      if row.auto_detected == false do
        upsert(repo, "simulator_url", row.url)
        upsert(repo, "simulator_api_key", row.api_key)
      end
    end)

    drop table(:simulator_configs)
  end

  def down do
    create table(:simulator_configs) do
      add :url, :string, null: false
      add :api_key, :string, null: false
      add :auto_detected, :boolean, default: false, null: false
      timestamps(type: :utc_datetime)
    end
  end

  defp upsert(repo, key, value) when is_binary(value) and value != "" do
    repo.insert_all(
      "app_settings",
      [%{key: key, value: value}],
      on_conflict: {:replace, [:value]},
      conflict_target: :key
    )
  end

  defp upsert(_repo, _key, _value), do: :ok
end
