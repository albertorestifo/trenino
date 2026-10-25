# Current schema field dictionary

Source-extracted at `188f35e4108733358730e92ebd98f1912af5173a` (2026-10-25). This appendix lists every current persistent/embedded schema declaration, preserving exact enum/default/association options for rewrite traceability. See [data model](data-model.md) for SQL constraints, deletion rules and migration differences; feature documents explain validation and runtime use. A `has_one` declaration does not by itself create a unique SQL constraint. No database content was exported.

## firmware_files

Source: [lib/trenino/firmware/firmware_file.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/firmware_file.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `belongs_to firmware_release` | `FirmwareRelease` |
| `board_type` | `:string` |
| `environment` | `:string` |
| `download_url` | `:string` |
| `file_size` | `:integer` |
| `checksum_sha256` | `:string` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## firmware_releases

Source: [lib/trenino/firmware/firmware_release.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/firmware_release.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `version` | `:string` |
| `tag_name` | `:string` |
| `release_url` | `:string` |
| `release_notes` | `:string` |
| `published_at` | `:utc_datetime` |
| `manifest_json` | `:string` |
| `has_many firmware_files` | `FirmwareFile` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## firmware_update_checks

Source: [lib/trenino/firmware/update_check.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/update_check.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `checked_at` | `:utc_datetime` |
| `found_updates` | `:boolean, default: false` |
| `latest_version` | `:string` |
| `error_message` | `:string` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## firmware_upload_history

Source: [lib/trenino/firmware/upload_history.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/firmware/upload_history.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `upload_id` | `:string` |
| `port` | `:string` |
| `board_type` | `:string` |
| `status` | `Ecto.Enum, values: [:started, :completed, :failed, :cancelled]` |
| `error_message` | `:string` |
| `avrdude_output` | `:string` |
| `duration_ms` | `:integer` |
| `started_at` | `:utc_datetime` |
| `completed_at` | `:utc_datetime` |
| `belongs_to firmware_file` | `FirmwareFile` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## devices

Source: [lib/trenino/hardware/device.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/device.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `name` | `:string` |
| `description` | `:string` |
| `config_id` | `:integer` |
| `has_many inputs` | `Input` |
| `has_many outputs` | `Output` |
| `has_many i2c_modules` | `I2cModule` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## HT16K33 parameters (embedded)

Source: [lib/trenino/hardware/ht16k33/params.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/ht16k33/params.ex).

Primary key: `false`.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `brightness` | `:integer, default: 8` |
| `num_digits` | `:integer, default: 4` |
| `display_type` | `Ecto.Enum, values: [:seven_segment, :fourteen_segment], default: :fourteen_segment` |
| `has_dot` | `:boolean, default: false` |
| `align_right` | `:boolean, default: true` |
| `min_value` | `:float, default: 0.0` |

## device_i2c_modules

Source: [lib/trenino/hardware/i2c_module.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/i2c_module.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `name` | `:string` |
| `module_chip` | `Ecto.Enum, values: [:ht16k33]` |
| `i2c_address` | `:integer` |
| `polymorphic embedded params` | `polymorphic_embeds_one(:params, types: [ ht16k33: [ module: HT16K33Params, identify_by_fields: [:brightness, :num_digits, :display_type, :has_dot] ] ], on_type_not_found: :raise, on_replace: :update )` |
| `belongs_to device` | `Device` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## device_inputs

Source: [lib/trenino/hardware/input.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/input.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `pin` | `:integer` |
| `input_type` | `Ecto.Enum, values: [:analog, :button]` |
| `sensitivity` | `:integer` |
| `debounce` | `:integer` |
| `name` | `:string` |
| `belongs_to device` | `Device` |
| `belongs_to matrix` | `Matrix` |
| `has_one calibration` | `Calibration` |
| `has_many lever_bindings` | `LeverInputBinding` |
| `has_one virtual_joystick_mapping` | `Mapping` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## device_input_calibrations

Source: [lib/trenino/hardware/input/calibration.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/input/calibration.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `max_hardware_value` | `:integer` |
| `min_value` | `:integer` |
| `max_value` | `:integer` |
| `has_rollover` | `:boolean, default: false` |
| `is_inverted` | `:boolean, default: false` |
| `belongs_to input` | `Input` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## device_input_matrix_pins

Source: [lib/trenino/hardware/input/matrix_pin.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/input/matrix_pin.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `pin_type` | `Ecto.Enum, values: [:row, :col]` |
| `pin` | `:integer` |
| `position` | `:integer` |
| `belongs_to matrix` | `Matrix` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## device_matrices

Source: [lib/trenino/hardware/matrix.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/matrix.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `name` | `:string` |
| `belongs_to device` | `Device` |
| `has_many row_pins` | `MatrixPin, where: [pin_type: :row], preload_order: [asc: :position]` |
| `has_many col_pins` | `MatrixPin, where: [pin_type: :col], preload_order: [asc: :position]` |
| `has_many buttons` | `Input` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## device_outputs

Source: [lib/trenino/hardware/output.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/hardware/output.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `pin` | `:integer` |
| `name` | `:string` |
| `belongs_to device` | `Device` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## app_settings

Source: [lib/trenino/settings/setting.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/settings/setting.ex).

Primary key: `{:key, :string, autogenerate: false}`.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `value` | `:string` |

## button_input_bindings

Source: [lib/trenino/train/button_input_binding.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/button_input_binding.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `endpoint` | `:string` |
| `on_value` | `:float, default: 1.0` |
| `off_value` | `:float, default: 0.0` |
| `enabled` | `:boolean, default: true` |
| `mode` | `Ecto.Enum, values: [:simple, :momentary, :sequence, :keystroke], default: :simple` |
| `keystroke` | `:string` |
| `hardware_type` | `Ecto.Enum, values: [:momentary, :latching], default: :momentary` |
| `repeat_interval_ms` | `:integer, default: 100` |
| `belongs_to element` | `Element` |
| `belongs_to input` | `Input` |
| `belongs_to on_sequence` | `Sequence` |
| `belongs_to off_sequence` | `Sequence` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## train_display_bindings

Source: [lib/trenino/train/display_binding.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/display_binding.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `name` | `:string` |
| `endpoint` | `:string` |
| `format_string` | `:string, default: "{value}"` |
| `enabled` | `:boolean, default: true` |
| `script_id` | `:integer` |
| `belongs_to train` | `Train` |
| `belongs_to i2c_module` | `I2cModule` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## train_elements

Source: [lib/trenino/train/element.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/element.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `type` | `Ecto.Enum, values: [:lever, :button]` |
| `name` | `:string` |
| `belongs_to train` | `Train` |
| `has_one lever_config` | `LeverConfig` |
| `has_one button_binding` | `ButtonInputBinding` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## train_lever_configs

Source: [lib/trenino/train/lever_config.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/lever_config.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `min_endpoint` | `:string` |
| `max_endpoint` | `:string` |
| `value_endpoint` | `:string` |
| `notch_count_endpoint` | `:string` |
| `notch_index_endpoint` | `:string` |
| `lever_type` | `Ecto.Enum, values: [:discrete, :continuous, :hybrid]` |
| `inverted` | `:boolean, default: false` |
| `calibrated_at` | `:utc_datetime` |
| `belongs_to element` | `Element` |
| `has_many notches` | `Notch, on_delete: :delete_all` |
| `has_one input_binding` | `LeverInputBinding, on_delete: :delete_all` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## lever_input_bindings

Source: [lib/trenino/train/lever_input_binding.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/lever_input_binding.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `enabled` | `:boolean, default: true` |
| `belongs_to lever_config` | `LeverConfig` |
| `belongs_to input` | `Input` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## train_lever_notches

Source: [lib/trenino/train/notch.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/notch.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `index` | `:integer` |
| `type` | `Ecto.Enum, values: [:gate, :linear]` |
| `value` | `:float` |
| `min_value` | `:float` |
| `max_value` | `:float` |
| `input_min` | `:float` |
| `input_max` | `:float` |
| `sim_input_min` | `:float` |
| `sim_input_max` | `:float` |
| `description` | `:string` |
| `belongs_to lever_config` | `LeverConfig` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## train_output_bindings

Source: [lib/trenino/train/output_binding.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/output_binding.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `name` | `:string` |
| `output_type` | `Ecto.Enum, values: [:led], default: :led` |
| `endpoint` | `:string` |
| `operator` | `Ecto.Enum, values: [:gt, :gte, :lt, :lte, :between, :eq_true, :eq_false]` |
| `value_a` | `:float` |
| `value_b` | `:float` |
| `enabled` | `:boolean, default: true` |
| `belongs_to train` | `Train` |
| `belongs_to output` | `Output` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## scripts

Source: [lib/trenino/train/script.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/script.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `name` | `:string` |
| `enabled` | `:boolean, default: true` |
| `code` | `:string, default: ""` |
| `triggers` | `Trenino.Train.Script.TriggersType, default: []` |
| `belongs_to train` | `Train` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## sequences

Source: [lib/trenino/train/sequence.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/sequence.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `name` | `:string` |
| `belongs_to train` | `Train` |
| `has_many commands` | `SequenceCommand, preload_order: [asc: :position]` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## sequence_commands

Source: [lib/trenino/train/sequence_command.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/sequence_command.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `position` | `:integer` |
| `endpoint` | `:string` |
| `value` | `:float` |
| `delay_ms` | `:integer, default: 0` |
| `belongs_to sequence` | `Sequence` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## trains

Source: [lib/trenino/train/train.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/train.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `name` | `:string` |
| `description` | `:string` |
| `has_many elements` | `Element` |
| `has_many identifiers` | `TrainIdentifier, on_replace: :delete` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## train_identifiers

Source: [lib/trenino/train/train_identifier.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/train/train_identifier.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `identifier` | `:string` |
| `belongs_to train` | `Train` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## virtual_joystick_configurations

Source: [lib/trenino/virtual_joystick/configuration.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/virtual_joystick/configuration.ex).

Primary key: `{:id, :integer, autogenerate: false}`.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `enabled` | `:boolean, default: false` |
| `device_index` | `:integer, default: 1` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |

## virtual_joystick_mappings

Source: [lib/trenino/virtual_joystick/mapping.ex](https://github.com/albertorestifo/trenino/blob/188f35e4108733358730e92ebd98f1912af5173a/lib/trenino/virtual_joystick/mapping.ex).

Default Ecto integer `id` primary key.

| Declaration | Type, default, enum, or relationship options |
|---|---|
| `device_index` | `:integer, default: 1` |
| `target_type` | `Ecto.Enum, values: [:axis, :button]` |
| `axis` | `Ecto.Enum, values: @axes` |
| `button` | `:integer` |
| `inverted` | `:boolean, default: false` |
| `belongs_to input` | `Input` |
| `timestamps` | `inserted_at / updated_at, UTC datetime` |
