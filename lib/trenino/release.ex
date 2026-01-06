defmodule Trenino.Release do
  @moduledoc """
  Release tasks for running migrations without Mix.

  Used by the application to run migrations on startup in production,
  and can also be invoked manually via the release binary:

      bin/trenino eval "Trenino.Release.migrate()"
  """

  @app :trenino

  @doc """
  Runs all pending database migrations.
  """
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc """
  Rolls back the database by one migration.
  """
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end
