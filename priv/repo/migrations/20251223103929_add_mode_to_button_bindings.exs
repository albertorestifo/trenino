defmodule Trenino.Repo.Migrations.AddModeToButtonBindings do
  use Ecto.Migration

  def change do
    alter table(:button_input_bindings) do
      # Mode: simple (default), momentary (repeat while held), sequence (execute sequence)
      add :mode, :string, null: false, default: "simple"
      # Hardware type: momentary (spring-loaded), latching (stays in position)
      add :hardware_type, :string, null: false, default: "momentary"
      # Repeat interval for momentary mode (ms)
      add :repeat_interval_ms, :integer, null: false, default: 100
    end

    # Note: SQLite doesn't support ALTER TABLE ADD CONSTRAINT
    # Validation is handled at the application level by Ecto.Enum
  end
end
