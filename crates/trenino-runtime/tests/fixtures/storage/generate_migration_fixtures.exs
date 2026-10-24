Application.ensure_all_started(:ecto_sqlite3)

repo_config = Application.fetch_env!(:trenino, Trenino.Repo)
repo_config = Keyword.put(repo_config, :pool, DBConnection.ConnectionPool)
repo_config = Keyword.put(repo_config, :pool_size, 1)

migrate = fn database, directory ->
  Application.put_env(:trenino, Trenino.Repo, Keyword.put(repo_config, :database, database))
  {:ok, pid} = Trenino.Repo.start_link()
  # Elixir's Path.wildcard treats backslashes in a Windows path as escapes.
  directory = String.replace(directory, "\\", "/")
  versions = Ecto.Migrator.run(Trenino.Repo, [directory], :up, all: true)
  GenServer.stop(pid)
  versions
end

v074 =
  migrate.(
    System.fetch_env!("MIGRATION_FIXTURE_V074_DB"),
    System.fetch_env!("MIGRATION_FIXTURE_V074_DIR")
  )

current =
  migrate.(
    System.fetch_env!("MIGRATION_FIXTURE_CURRENT_DB"),
    System.fetch_env!("MIGRATION_FIXTURE_CURRENT_DIR")
  )

IO.inspect({length(v074), List.last(v074), length(current), List.last(current)})
