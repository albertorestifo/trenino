CREATE TABLE "app_settings" ("key" TEXT PRIMARY KEY, "value" TEXT NOT NULL);

CREATE TABLE "button_input_bindings" (
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
, "keystroke" TEXT);

CREATE TABLE "device_i2c_modules" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "device_id" INTEGER NOT NULL CONSTRAINT "device_i2c_modules_device_id_fkey" REFERENCES "devices"("id") ON DELETE CASCADE, "name" TEXT, "module_chip" TEXT NOT NULL, "i2c_address" INTEGER NOT NULL, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "params" TEXT);

CREATE TABLE "device_input_calibrations" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "max_hardware_value" INTEGER, "min_value" INTEGER, "max_value" INTEGER, "has_rollover" INTEGER DEFAULT false NOT NULL, "is_inverted" INTEGER DEFAULT false NOT NULL, "input_id" INTEGER CONSTRAINT "device_input_calibrations_input_id_fkey" REFERENCES "device_inputs"("id"), "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);

CREATE TABLE "device_input_matrix_pins" (
  id INTEGER PRIMARY KEY,
  pin INTEGER NOT NULL,
  pin_type TEXT NOT NULL,
  position INTEGER NOT NULL,
  matrix_id INTEGER NOT NULL REFERENCES device_matrices(id) ON DELETE CASCADE,
  inserted_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE "device_inputs" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "pin" INTEGER, "input_type" TEXT, "sensitivity" INTEGER, "device_id" INTEGER CONSTRAINT "device_inputs_device_id_fkey" REFERENCES "devices"("id"), "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "debounce" INTEGER, "matrix_id" INTEGER CONSTRAINT "device_inputs_matrix_id_fkey" REFERENCES "device_matrices"("id") ON DELETE CASCADE, "name" TEXT);

CREATE TABLE "device_matrices" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, "device_id" INTEGER NOT NULL CONSTRAINT "device_matrices_device_id_fkey" REFERENCES "devices"("id") ON DELETE CASCADE, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);

CREATE TABLE "device_outputs" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "pin" INTEGER NOT NULL, "name" TEXT, "device_id" INTEGER NOT NULL CONSTRAINT "device_outputs_device_id_fkey" REFERENCES "devices"("id") ON DELETE CASCADE, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);

CREATE TABLE "devices" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "name" TEXT, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "config_id" INTEGER, "description" TEXT);

CREATE TABLE "firmware_files" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "firmware_release_id" INTEGER NOT NULL CONSTRAINT "firmware_files_firmware_release_id_fkey" REFERENCES "firmware_releases"("id") ON DELETE CASCADE, "board_type" TEXT NOT NULL, "download_url" TEXT NOT NULL, "file_size" INTEGER, "checksum_sha256" TEXT, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "environment" TEXT);

CREATE TABLE "firmware_releases" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "version" TEXT NOT NULL, "tag_name" TEXT NOT NULL, "release_url" TEXT, "release_notes" TEXT, "published_at" TEXT, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "manifest_json" TEXT);

CREATE TABLE "firmware_update_checks" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "checked_at" TEXT NOT NULL, "found_updates" INTEGER DEFAULT false, "latest_version" TEXT, "error_message" TEXT, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);

CREATE TABLE "firmware_upload_history" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "upload_id" TEXT NOT NULL, "port" TEXT NOT NULL, "board_type" TEXT NOT NULL, "firmware_file_id" INTEGER CONSTRAINT "firmware_upload_history_firmware_file_id_fkey" REFERENCES "firmware_files"("id") ON DELETE SET NULL, "status" TEXT NOT NULL, "error_message" TEXT, "avrdude_output" TEXT, "duration_ms" INTEGER, "started_at" TEXT, "completed_at" TEXT, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);

CREATE TABLE "lever_input_bindings" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "lever_config_id" INTEGER NOT NULL CONSTRAINT "lever_input_bindings_lever_config_id_fkey" REFERENCES "train_lever_configs"("id") ON DELETE CASCADE, "input_id" INTEGER NOT NULL CONSTRAINT "lever_input_bindings_input_id_fkey" REFERENCES "device_inputs"("id") ON DELETE CASCADE, "enabled" INTEGER DEFAULT true NOT NULL, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);

CREATE TABLE "schema_migrations" ("version" INTEGER PRIMARY KEY, "inserted_at" TEXT);

CREATE TABLE "scripts" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "train_id" INTEGER NOT NULL CONSTRAINT "scripts_train_id_fkey" REFERENCES "trains"("id") ON DELETE CASCADE, "name" TEXT NOT NULL, "enabled" INTEGER DEFAULT true NOT NULL, "code" TEXT DEFAULT '' NOT NULL, "triggers" TEXT DEFAULT '[]' NOT NULL, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);

CREATE TABLE "sequence_commands" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "sequence_id" INTEGER NOT NULL CONSTRAINT "sequence_commands_sequence_id_fkey" REFERENCES "sequences"("id") ON DELETE CASCADE, "position" INTEGER NOT NULL, "endpoint" TEXT NOT NULL, "value" NUMERIC NOT NULL, "delay_ms" INTEGER DEFAULT 0 NOT NULL, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);

CREATE TABLE "sequences" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, "train_id" INTEGER NOT NULL CONSTRAINT "sequences_train_id_fkey" REFERENCES "trains"("id") ON DELETE CASCADE, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);

CREATE TABLE "train_display_bindings" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "train_id" INTEGER NOT NULL CONSTRAINT "train_display_bindings_train_id_fkey" REFERENCES "trains"("id") ON DELETE CASCADE, "i2c_module_id" INTEGER NOT NULL CONSTRAINT "train_display_bindings_i2c_module_id_fkey" REFERENCES "device_i2c_modules"("id") ON DELETE CASCADE, "name" TEXT, "endpoint" TEXT NOT NULL, "format_string" TEXT DEFAULT '{value}' NOT NULL, "enabled" INTEGER DEFAULT true NOT NULL, "script_id" INTEGER CONSTRAINT "train_display_bindings_script_id_fkey" REFERENCES "scripts"("id") ON DELETE SET NULL, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);

CREATE TABLE "train_elements" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "train_id" INTEGER NOT NULL CONSTRAINT "train_elements_train_id_fkey" REFERENCES "trains"("id") ON DELETE CASCADE, "type" TEXT NOT NULL, "name" TEXT NOT NULL, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);

CREATE TABLE "train_identifiers" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "train_id" INTEGER NOT NULL CONSTRAINT "train_identifiers_train_id_fkey" REFERENCES "trains"("id") ON DELETE CASCADE, "identifier" TEXT NOT NULL, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);

CREATE TABLE "train_lever_configs" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "element_id" INTEGER NOT NULL CONSTRAINT "train_lever_configs_element_id_fkey" REFERENCES "train_elements"("id") ON DELETE CASCADE, "min_endpoint" TEXT NOT NULL, "max_endpoint" TEXT NOT NULL, "value_endpoint" TEXT NOT NULL, "notch_count_endpoint" TEXT, "notch_index_endpoint" TEXT, "calibrated_at" TEXT, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "lever_type" TEXT, "inverted" INTEGER DEFAULT false NOT NULL);

CREATE TABLE "train_lever_notches" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "lever_config_id" INTEGER NOT NULL CONSTRAINT "train_lever_notches_lever_config_id_fkey" REFERENCES "train_lever_configs"("id") ON DELETE CASCADE, "index" INTEGER NOT NULL, "type" TEXT NOT NULL, "value" NUMERIC, "min_value" NUMERIC, "max_value" NUMERIC, "description" TEXT, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL, "input_min" NUMERIC, "input_max" NUMERIC, "sim_input_min" NUMERIC, "sim_input_max" NUMERIC);

CREATE TABLE "train_output_bindings" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "train_id" INTEGER NOT NULL CONSTRAINT "train_output_bindings_new_train_id_fkey" REFERENCES "trains"("id") ON DELETE CASCADE, "name" TEXT NOT NULL, "output_type" TEXT DEFAULT 'led' NOT NULL, "output_id" INTEGER NOT NULL CONSTRAINT "train_output_bindings_new_output_id_fkey" REFERENCES "device_outputs"("id") ON DELETE CASCADE, "endpoint" TEXT NOT NULL, "operator" TEXT NOT NULL, "value_a" NUMERIC NULL, "value_b" NUMERIC, "enabled" INTEGER DEFAULT true NOT NULL, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);

CREATE TABLE "trains" ("id" INTEGER PRIMARY KEY AUTOINCREMENT, "name" TEXT NOT NULL, "description" TEXT, "inserted_at" TEXT NOT NULL, "updated_at" TEXT NOT NULL);

CREATE TABLE virtual_joystick_configurations (
  id INTEGER PRIMARY KEY,
  enabled BOOLEAN NOT NULL DEFAULT FALSE,
  device_index INTEGER NOT NULL DEFAULT 1,
  inserted_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  CONSTRAINT virtual_joystick_configurations_singleton CHECK (id = 1),
  CONSTRAINT virtual_joystick_configurations_device_index_check CHECK (device_index BETWEEN 1 AND 16)
);

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
  CONSTRAINT virtual_joystick_mappings_device_index_check CHECK (device_index BETWEEN 1 AND 16),
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
);

CREATE UNIQUE INDEX "button_input_bindings_element_id_index" ON "button_input_bindings" ("element_id");

CREATE INDEX "button_input_bindings_input_id_index" ON "button_input_bindings" ("input_id");

CREATE UNIQUE INDEX "device_i2c_modules_device_id_i2c_address_index" ON "device_i2c_modules" ("device_id", "i2c_address");

CREATE INDEX "device_i2c_modules_device_id_index" ON "device_i2c_modules" ("device_id");

CREATE INDEX "device_input_calibrations_input_id_index" ON "device_input_calibrations" ("input_id");

CREATE INDEX "device_input_matrix_pins_matrix_id_index" ON "device_input_matrix_pins" ("matrix_id");

CREATE UNIQUE INDEX "device_input_matrix_pins_matrix_id_pin_type_position_index" ON "device_input_matrix_pins" ("matrix_id", "pin_type", "position");

CREATE INDEX "device_inputs_device_id_index" ON "device_inputs" ("device_id");

CREATE UNIQUE INDEX "device_inputs_device_id_pin_index" ON "device_inputs" ("device_id", "pin");

CREATE INDEX "device_inputs_matrix_id_index" ON "device_inputs" ("matrix_id");

CREATE INDEX "device_matrices_device_id_index" ON "device_matrices" ("device_id");

CREATE INDEX "device_outputs_device_id_index" ON "device_outputs" ("device_id");

CREATE UNIQUE INDEX "device_outputs_device_id_pin_index" ON "device_outputs" ("device_id", "pin");

CREATE UNIQUE INDEX "devices_config_id_index" ON "devices" ("config_id");

CREATE INDEX "firmware_files_board_type_index" ON "firmware_files" ("board_type");

CREATE INDEX "firmware_files_environment_index" ON "firmware_files" ("environment");

CREATE UNIQUE INDEX "firmware_files_firmware_release_id_board_type_index" ON "firmware_files" ("firmware_release_id", "board_type");

CREATE UNIQUE INDEX "firmware_releases_tag_name_index" ON "firmware_releases" ("tag_name");

CREATE INDEX "firmware_update_checks_checked_at_index" ON "firmware_update_checks" ("checked_at");

CREATE INDEX "firmware_upload_history_started_at_index" ON "firmware_upload_history" ("started_at");

CREATE INDEX "firmware_upload_history_status_index" ON "firmware_upload_history" ("status");

CREATE INDEX "lever_input_bindings_input_id_index" ON "lever_input_bindings" ("input_id");

CREATE UNIQUE INDEX "lever_input_bindings_lever_config_id_index" ON "lever_input_bindings" ("lever_config_id");

CREATE INDEX "scripts_train_id_index" ON "scripts" ("train_id");

CREATE UNIQUE INDEX "scripts_train_id_name_index" ON "scripts" ("train_id", "name");

CREATE INDEX "sequence_commands_sequence_id_index" ON "sequence_commands" ("sequence_id");

CREATE UNIQUE INDEX "sequence_commands_sequence_id_position_index" ON "sequence_commands" ("sequence_id", "position");

CREATE INDEX "sequences_train_id_index" ON "sequences" ("train_id");

CREATE UNIQUE INDEX "sequences_train_id_name_index" ON "sequences" ("train_id", "name");

CREATE UNIQUE INDEX "train_display_bindings_train_id_i2c_module_id_index" ON "train_display_bindings" ("train_id", "i2c_module_id");

CREATE INDEX "train_display_bindings_train_id_index" ON "train_display_bindings" ("train_id");

CREATE INDEX "train_elements_train_id_index" ON "train_elements" ("train_id");

CREATE UNIQUE INDEX "train_identifiers_identifier_index" ON "train_identifiers" ("identifier");

CREATE INDEX "train_identifiers_train_id_index" ON "train_identifiers" ("train_id");

CREATE UNIQUE INDEX "train_lever_configs_element_id_index" ON "train_lever_configs" ("element_id");

CREATE INDEX "train_lever_notches_lever_config_id_index" ON "train_lever_notches" ("lever_config_id");

CREATE UNIQUE INDEX "train_lever_notches_lever_config_id_index_index" ON "train_lever_notches" ("lever_config_id", "index");

CREATE INDEX "train_output_bindings_train_id_index" ON "train_output_bindings" ("train_id");

CREATE UNIQUE INDEX "train_output_bindings_train_id_output_id_index" ON "train_output_bindings" ("train_id", "output_id");

CREATE UNIQUE INDEX "virtual_joystick_mappings_device_index_axis_index" ON "virtual_joystick_mappings" ("device_index", "axis") WHERE target_type = 'axis';

CREATE UNIQUE INDEX "virtual_joystick_mappings_device_index_button_index" ON "virtual_joystick_mappings" ("device_index", "button") WHERE target_type = 'button';

CREATE UNIQUE INDEX "virtual_joystick_mappings_input_id_index" ON "virtual_joystick_mappings" ("input_id");

CREATE TABLE rust_schema_migrations (version INTEGER PRIMARY KEY, name TEXT NOT NULL, applied_at TEXT NOT NULL);
