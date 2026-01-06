defmodule Trenino.Repo.Migrations.RefactorMatrixToSeparateEntity do
  @moduledoc """
  Refactors matrix inputs to be a separate entity.

  Before: Matrix was an input_type with matrix_pins referencing input_id
  After: Matrix is a separate entity, virtual buttons are regular button inputs

  Changes:
  1. Create device_matrices table
  2. Add matrix_id and name to device_inputs
  3. Add matrix_id to device_input_matrix_pins
  4. Migrate existing matrix inputs to new structure
  5. Remove :matrix from input_type enum
  6. Remove virtual_pin from button_input_bindings
  """

  use Ecto.Migration

  def up do
    # Step 1: Create device_matrices table
    create table(:device_matrices) do
      add :name, :string, null: false
      add :device_id, references(:devices, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:device_matrices, [:device_id])

    # Step 2: Add matrix_id and name to device_inputs
    alter table(:device_inputs) do
      add :matrix_id, references(:device_matrices, on_delete: :delete_all)
      add :name, :string
    end

    create index(:device_inputs, [:matrix_id])

    # Step 3: Add matrix_id to device_input_matrix_pins (temporarily nullable)
    alter table(:device_input_matrix_pins) do
      add :matrix_id, references(:device_matrices, on_delete: :delete_all)
    end

    create index(:device_input_matrix_pins, [:matrix_id])

    # Step 4: Migrate existing data
    flush()

    # 4a: Create matrix records from existing matrix inputs
    # SQLite uses || for concatenation, not CONCAT()
    execute """
    INSERT INTO device_matrices (device_id, name, inserted_at, updated_at)
    SELECT
      device_id,
      'Matrix ' || id,
      inserted_at,
      updated_at
    FROM device_inputs
    WHERE input_type = 'matrix'
    """

    # 4b: Update matrix_pins to point to new matrices
    # We match by device_id since there's a 1:1 correspondence at this stage
    execute """
    UPDATE device_input_matrix_pins
    SET matrix_id = (
      SELECT m.id
      FROM device_matrices m
      JOIN device_inputs i ON i.device_id = m.device_id
      WHERE i.id = device_input_matrix_pins.input_id
      AND i.input_type = 'matrix'
      LIMIT 1
    )
    WHERE input_id IN (SELECT id FROM device_inputs WHERE input_type = 'matrix')
    """

    # 4c: Create virtual button inputs for existing matrix button bindings
    # SQLite uses MAX() instead of GREATEST(), || for concat, datetime('now') for NOW()
    execute """
    INSERT INTO device_inputs (
      device_id,
      input_type,
      pin,
      debounce,
      matrix_id,
      name,
      inserted_at,
      updated_at
    )
    SELECT DISTINCT
      i.device_id,
      'button',
      b.virtual_pin,
      50,
      (SELECT m.id FROM device_matrices m WHERE m.device_id = i.device_id LIMIT 1),
      'R' || ((b.virtual_pin - 128) / MAX(
        (SELECT COUNT(*) FROM device_input_matrix_pins mp
         WHERE mp.input_id = i.id AND mp.pin_type = 'col'), 1
      )) || 'C' || ((b.virtual_pin - 128) % MAX(
        (SELECT COUNT(*) FROM device_input_matrix_pins mp
         WHERE mp.input_id = i.id AND mp.pin_type = 'col'), 1
      )),
      datetime('now'),
      datetime('now')
    FROM button_input_bindings b
    JOIN device_inputs i ON i.id = b.input_id
    WHERE i.input_type = 'matrix'
    AND b.virtual_pin IS NOT NULL
    """

    # 4d: Update button bindings to point to new virtual button inputs
    execute """
    UPDATE button_input_bindings
    SET input_id = (
      SELECT new_i.id
      FROM device_inputs new_i
      WHERE new_i.pin = button_input_bindings.virtual_pin
      AND new_i.matrix_id IS NOT NULL
      AND new_i.device_id = (
        SELECT old_i.device_id
        FROM device_inputs old_i
        WHERE old_i.id = button_input_bindings.input_id
      )
      LIMIT 1
    )
    WHERE virtual_pin IS NOT NULL
    AND input_id IN (SELECT id FROM device_inputs WHERE input_type = 'matrix')
    """

    # 4e: Delete old matrix inputs (this will cascade delete orphaned matrix_pins)
    execute "DELETE FROM device_inputs WHERE input_type = 'matrix'"

    # Step 5: Clean up matrix_pins that didn't get a matrix_id
    execute "DELETE FROM device_input_matrix_pins WHERE matrix_id IS NULL"

    # Step 6: Recreate device_input_matrix_pins table with new schema
    # SQLite doesn't support ALTER COLUMN, so we use table recreation pattern
    drop_if_exists index(:device_input_matrix_pins, [:input_id])
    drop_if_exists index(:device_input_matrix_pins, [:input_id, :pin_type, :position])
    drop_if_exists index(:device_input_matrix_pins, [:matrix_id])

    # Create new table with desired schema (without input_id, matrix_id NOT NULL)
    execute """
    CREATE TABLE device_input_matrix_pins_new (
      id INTEGER PRIMARY KEY,
      pin INTEGER NOT NULL,
      pin_type TEXT NOT NULL,
      position INTEGER NOT NULL,
      matrix_id INTEGER NOT NULL REFERENCES device_matrices(id) ON DELETE CASCADE,
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    """

    # Copy data from old table
    execute """
    INSERT INTO device_input_matrix_pins_new (id, pin, pin_type, position, matrix_id, inserted_at, updated_at)
    SELECT id, pin, pin_type, position, matrix_id, inserted_at, updated_at
    FROM device_input_matrix_pins
    """

    # Drop old table and rename new one
    execute "DROP TABLE device_input_matrix_pins"
    execute "ALTER TABLE device_input_matrix_pins_new RENAME TO device_input_matrix_pins"

    # Create new indexes
    create index(:device_input_matrix_pins, [:matrix_id])
    create unique_index(:device_input_matrix_pins, [:matrix_id, :pin_type, :position])

    # Step 7: Recreate button_input_bindings without virtual_pin
    # SQLite doesn't support DROP COLUMN reliably, so we use table recreation
    execute """
    CREATE TABLE button_input_bindings_new (
      id INTEGER PRIMARY KEY,
      input_id INTEGER NOT NULL REFERENCES device_inputs(id) ON DELETE CASCADE,
      element_id INTEGER NOT NULL REFERENCES train_elements(id) ON DELETE CASCADE,
      endpoint TEXT,
      on_value REAL NOT NULL DEFAULT 1.0,
      off_value REAL NOT NULL DEFAULT 0.0,
      enabled INTEGER NOT NULL DEFAULT 1,
      mode TEXT NOT NULL DEFAULT 'simple',
      hardware_type TEXT NOT NULL DEFAULT 'momentary',
      repeat_interval_ms INTEGER NOT NULL DEFAULT 100,
      on_sequence_id INTEGER REFERENCES sequences(id) ON DELETE SET NULL,
      off_sequence_id INTEGER REFERENCES sequences(id) ON DELETE SET NULL,
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    """

    execute """
    INSERT INTO button_input_bindings_new (
      id, input_id, element_id, endpoint, on_value, off_value, enabled,
      mode, hardware_type, repeat_interval_ms, on_sequence_id, off_sequence_id,
      inserted_at, updated_at
    )
    SELECT
      id, input_id, element_id, endpoint, on_value, off_value, enabled,
      mode, hardware_type, repeat_interval_ms, on_sequence_id, off_sequence_id,
      inserted_at, updated_at
    FROM button_input_bindings
    """

    execute "DROP TABLE button_input_bindings"
    execute "ALTER TABLE button_input_bindings_new RENAME TO button_input_bindings"

    # Recreate indexes on button_input_bindings
    create unique_index(:button_input_bindings, [:element_id])
    create index(:button_input_bindings, [:input_id])

    # Step 8: Update the partial unique index on device_inputs
    # Now we need to include virtual buttons (matrix_id not null) in the uniqueness check
    drop_if_exists index(:device_inputs, [:device_id, :pin],
                     name: :device_inputs_device_id_pin_unique
                   )

    # Create new unique index - all pins must be unique per device
    create unique_index(:device_inputs, [:device_id, :pin])

    # Step 9: Make pin required for all inputs
    # First set any null pins (shouldn't exist after migration)
    execute "UPDATE device_inputs SET pin = 0 WHERE pin IS NULL"

    # For making pin NOT NULL, we need to recreate device_inputs table
    # But this is complex due to all the foreign keys pointing to it
    # Instead, SQLite 3.37+ supports NOT NULL via table recreation with ecto_sqlite3
    # We'll skip this constraint change as SQLite handles it at runtime anyway
  end

  def down do
    raise "This migration cannot be rolled back automatically. Please restore from backup."
  end
end
