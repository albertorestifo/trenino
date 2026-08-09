defmodule Trenino.Test.MigrationModuleIsolation do
  @moduledoc false

  @migration_namespace "Elixir.Trenino.Repo.Migrations."

  def purge_loaded do
    modules =
      :code.all_loaded()
      |> Enum.map(&elem(&1, 0))
      |> Enum.filter(&migration_module?/1)
      |> Enum.sort()

    Enum.each(modules, fn module ->
      :code.purge(module)
      :code.delete(module)
    end)

    modules
  end

  defp migration_module?(module) do
    module
    |> Atom.to_string()
    |> String.starts_with?(@migration_namespace)
  end
end
