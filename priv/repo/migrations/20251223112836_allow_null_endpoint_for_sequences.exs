defmodule TswIo.Repo.Migrations.AllowNullEndpointForSequences do
  use Ecto.Migration

  @doc """
  In sequence mode, the endpoint is not used (sequences define their own endpoints).
  This migration changes the endpoint column to allow NULL values.

  SQLite doesn't support ALTER COLUMN directly, so we recreate the table.
  """
  def change do
    # SQLite: recreate table to allow NULL on endpoint
    execute(
      """
      CREATE TABLE button_input_bindings_new (
        id INTEGER PRIMARY KEY,
        input_id INTEGER NOT NULL REFERENCES device_inputs(id) ON DELETE CASCADE,
        element_id INTEGER NOT NULL REFERENCES train_elements(id) ON DELETE CASCADE,
        endpoint TEXT,
        on_value REAL NOT NULL DEFAULT 1.0,
        off_value REAL NOT NULL DEFAULT 0.0,
        enabled INTEGER NOT NULL DEFAULT 1,
        virtual_pin INTEGER,
        mode TEXT NOT NULL DEFAULT 'simple',
        hardware_type TEXT NOT NULL DEFAULT 'momentary',
        repeat_interval_ms INTEGER NOT NULL DEFAULT 100,
        on_sequence_id INTEGER REFERENCES sequences(id) ON DELETE SET NULL,
        off_sequence_id INTEGER REFERENCES sequences(id) ON DELETE SET NULL,
        inserted_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      """,
      """
      CREATE TABLE button_input_bindings_new (
        id INTEGER PRIMARY KEY,
        input_id INTEGER NOT NULL REFERENCES device_inputs(id) ON DELETE CASCADE,
        element_id INTEGER NOT NULL REFERENCES train_elements(id) ON DELETE CASCADE,
        endpoint TEXT NOT NULL,
        on_value REAL NOT NULL DEFAULT 1.0,
        off_value REAL NOT NULL DEFAULT 0.0,
        enabled INTEGER NOT NULL DEFAULT 1,
        virtual_pin INTEGER,
        mode TEXT NOT NULL DEFAULT 'simple',
        hardware_type TEXT NOT NULL DEFAULT 'momentary',
        repeat_interval_ms INTEGER NOT NULL DEFAULT 100,
        on_sequence_id INTEGER REFERENCES sequences(id) ON DELETE SET NULL,
        off_sequence_id INTEGER REFERENCES sequences(id) ON DELETE SET NULL,
        inserted_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
      """
    )

    execute(
      """
      INSERT INTO button_input_bindings_new
      SELECT id, input_id, element_id, endpoint, on_value, off_value, enabled,
             virtual_pin, mode, hardware_type, repeat_interval_ms,
             on_sequence_id, off_sequence_id, inserted_at, updated_at
      FROM button_input_bindings
      """,
      """
      INSERT INTO button_input_bindings_new
      SELECT id, input_id, element_id, endpoint, on_value, off_value, enabled,
             virtual_pin, mode, hardware_type, repeat_interval_ms,
             on_sequence_id, off_sequence_id, inserted_at, updated_at
      FROM button_input_bindings
      """
    )

    execute("DROP TABLE button_input_bindings", "DROP TABLE button_input_bindings")

    execute(
      "ALTER TABLE button_input_bindings_new RENAME TO button_input_bindings",
      "ALTER TABLE button_input_bindings_new RENAME TO button_input_bindings"
    )

    # Recreate indexes
    execute(
      "CREATE UNIQUE INDEX button_input_bindings_element_id_index ON button_input_bindings(element_id)",
      "CREATE UNIQUE INDEX button_input_bindings_element_id_index ON button_input_bindings(element_id)"
    )

    execute(
      "CREATE INDEX button_input_bindings_input_id_index ON button_input_bindings(input_id)",
      "CREATE INDEX button_input_bindings_input_id_index ON button_input_bindings(input_id)"
    )
  end
end
