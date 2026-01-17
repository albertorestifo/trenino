defmodule Trenino.Repo.Migrations.AddManifestSupport do
  @moduledoc """
  Adds support for dynamic device loading from firmware release manifests.

  This migration:
  1. Adds manifest_json field to firmware_releases for storing release.json
  2. Adds environment field to firmware_files for PlatformIO environment names
  3. Migrates existing board_type values to environment values
  4. Creates index on environment for fast lookups
  """

  use Ecto.Migration

  def change do
    # Add manifest_json to firmware_releases
    alter table(:firmware_releases) do
      add :manifest_json, :text
    end

    # Add environment to firmware_files
    alter table(:firmware_files) do
      add :environment, :string
    end

    # Create index on environment for fast lookups
    create index(:firmware_files, [:environment])

    # Migrate existing board_type values to environment
    # The mapping from board_type (Ecto.Enum atom strings) to PlatformIO environments
    execute(
      """
      UPDATE firmware_files
      SET environment =
        CASE board_type
          WHEN 'uno' THEN 'uno'
          WHEN 'nano' THEN 'nanoatmega328'
          WHEN 'leonardo' THEN 'leonardo'
          WHEN 'micro' THEN 'micro'
          WHEN 'mega2560' THEN 'megaatmega2560'
          WHEN 'sparkfun_pro_micro' THEN 'sparkfun_promicro16'
        END
      WHERE board_type IN ('uno', 'nano', 'leonardo', 'micro', 'mega2560', 'sparkfun_pro_micro')
      """,
      # Rollback: clear environment field
      "UPDATE firmware_files SET environment = NULL"
    )
  end
end
