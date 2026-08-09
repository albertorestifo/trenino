defmodule Trenino.CI.MigrationModuleIsolationTest do
  use ExUnit.Case, async: false

  alias Trenino.Test.MigrationModuleIsolation

  test "purges migration modules loaded by the Mix test alias" do
    module = Trenino.Repo.Migrations.WarningRegressionFixture

    Module.create(module, quote(do: def(change, do: :ok)), Macro.Env.location(__ENV__))
    assert Code.ensure_loaded?(module)

    purged = MigrationModuleIsolation.purge_loaded()

    assert module in purged
    assert Enum.all?(purged, &(Code.ensure_loaded?(&1) == false))
  end
end
