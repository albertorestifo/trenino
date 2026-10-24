defmodule StorageMigrationFixture.Repo do
  use Ecto.Repo,
    otp_app: :storage_migration_fixture,
    adapter: Ecto.Adapters.SQLite3
end

Application.ensure_all_started(:ecto_sqlite3)
Application.put_env(:storage_migration_fixture, StorageMigrationFixture.Repo,
  database: System.fetch_env!("MIGRATION_FIXTURE_V074_DB"),
  pool: DBConnection.ConnectionPool,
  pool_size: 1
)
{:ok, pid} = StorageMigrationFixture.Repo.start_link()
directory = System.fetch_env!("MIGRATION_FIXTURE_V074_DIR") |> String.replace("\\", "/")
versions = Ecto.Migrator.run(StorageMigrationFixture.Repo, [directory], :up, all: true)
GenServer.stop(pid)
IO.inspect({length(versions), List.last(versions)}, label: "v0.7.4 migrations")
unless length(versions) == 36 and List.last(versions) == 20260503114723 do
  raise "unexpected v0.7.4 migration inventory"
end
