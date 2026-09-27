defmodule Trenino.Migrations.CreateTrainIdentifiersTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL
  alias Trenino.Repo
  alias Trenino.Test.MigrationModuleIsolation

  @previous_version 20_260_801_000_000
  @migration_version 20_260_927_000_000

  setup do
    database =
      Path.join(
        System.tmp_dir!(),
        "trenino-identifier-migration-#{System.unique_integer([:positive])}.db"
      )

    {:ok, repo} =
      Repo.start_link(
        name: nil,
        database: database,
        pool: DBConnection.ConnectionPool,
        pool_size: 1
      )

    previous_repo = Repo.get_dynamic_repo()
    migrations = Application.app_dir(:trenino, "priv/repo/migrations")

    without_module_conflict_warnings(fn ->
      Ecto.Migrator.run(Repo, migrations, :up,
        to: @previous_version,
        dynamic_repo: repo,
        log: false
      )
    end)

    MigrationModuleIsolation.purge_loaded()

    Repo.put_dynamic_repo(repo)

    on_exit(fn ->
      Repo.put_dynamic_repo(previous_repo)

      if Process.alive?(repo) do
        try do
          GenServer.stop(repo)
        catch
          :exit, _reason -> :ok
        end
      end

      File.rm(database)
      File.rm(database <> "-shm")
      File.rm(database <> "-wal")
    end)

    %{migrations: migrations, repo: repo}
  end

  test "moves existing identifiers and refuses lossy rollback", ctx do
    SQL.query!(
      ctx.repo,
      "INSERT INTO trains (name, identifier, inserted_at, updated_at) VALUES (?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)",
      ["BR 423", "RVM_FSN_DB_BR423"]
    )

    [[train_id]] = SQL.query!(ctx.repo, "SELECT id FROM trains", []).rows

    without_module_conflict_warnings(fn ->
      Ecto.Migrator.run(Repo, ctx.migrations, :up,
        to: @migration_version,
        dynamic_repo: ctx.repo,
        log: false
      )
    end)

    Repo.put_dynamic_repo(ctx.repo)

    assert [["RVM_FSN_DB_BR423"]] ==
             SQL.query!(
               ctx.repo,
               "SELECT identifier FROM train_identifiers WHERE train_id = ?",
               [train_id]
             ).rows

    columns = SQL.query!(ctx.repo, "PRAGMA table_info(trains)", []).rows
    refute "identifier" in Enum.map(columns, &Enum.at(&1, 1))

    assert_raise RuntimeError, ~r/cannot.*primary identifier/i, fn ->
      without_module_conflict_warnings(fn ->
        Ecto.Migrator.run(Repo, ctx.migrations, :down,
          step: 1,
          dynamic_repo: ctx.repo,
          log: false
        )
      end)
    end
  end

  defp without_module_conflict_warnings(fun) do
    compiler_options = Code.compiler_options()

    try do
      Code.compiler_options(ignore_module_conflict: true)
      fun.()
    after
      Code.compiler_options(compiler_options)
    end
  end
end
