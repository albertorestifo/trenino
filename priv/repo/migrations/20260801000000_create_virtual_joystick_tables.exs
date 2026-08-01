defmodule Trenino.Repo.Migrations.CreateVirtualJoystickTables do
  use Ecto.Migration

  def up do
    # SQLite only supports CHECK constraints inside CREATE TABLE. Named
    # constraints retain Ecto changeset error translation without ALTER TABLE.
    execute """
    CREATE TABLE virtual_joystick_configurations (
      id INTEGER PRIMARY KEY,
      enabled BOOLEAN NOT NULL DEFAULT FALSE,
      device_index INTEGER NOT NULL DEFAULT 1,
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      CONSTRAINT virtual_joystick_configurations_singleton CHECK (id = 1),
      CONSTRAINT virtual_joystick_configurations_device_index_check CHECK (device_index = 1)
    )
    """

    execute """
    CREATE TABLE virtual_joystick_mappings (
      id INTEGER PRIMARY KEY,
      input_id INTEGER NOT NULL REFERENCES device_inputs(id) ON DELETE CASCADE,
      device_index INTEGER NOT NULL DEFAULT 1,
      target_type TEXT NOT NULL,
      axis TEXT,
      button INTEGER,
      inverted BOOLEAN NOT NULL DEFAULT FALSE,
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      CONSTRAINT virtual_joystick_mappings_device_index_check CHECK (device_index = 1),
      CONSTRAINT virtual_joystick_mappings_target_shape_check CHECK (
        (target_type = 'axis' AND axis IS NOT NULL AND button IS NULL) OR
        (target_type = 'button' AND axis IS NULL AND button IS NOT NULL)
      ),
      CONSTRAINT virtual_joystick_mappings_axis_check CHECK (
        axis IS NULL OR axis IN ('x', 'y', 'z', 'rx', 'ry', 'rz', 'slider_1', 'slider_2')
      ),
      CONSTRAINT virtual_joystick_mappings_button_check CHECK (
        button IS NULL OR button BETWEEN 1 AND 32
      )
    )
    """

    create unique_index(:virtual_joystick_mappings, [:input_id])

    create unique_index(:virtual_joystick_mappings, [:device_index, :axis],
             where: "target_type = 'axis'"
           )

    create unique_index(:virtual_joystick_mappings, [:device_index, :button],
             where: "target_type = 'button'"
           )
  end

  def down do
    drop table(:virtual_joystick_mappings)
    drop table(:virtual_joystick_configurations)
  end
end
