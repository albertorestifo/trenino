//! Integration tests for the `bindings` topic persistence, mirroring the
//! Elixir binding coverage:
//! - `test/trenino/train_test.exs` (button binding describes)
//! - `test/trenino/train/button_input_binding_test.exs` (changeset + constraints)
//! - `test/trenino/train/output_binding_test.exs` and
//!   `output_binding_context_test.exs`
//! - `test/trenino/train/display_formatter_test.exs` (format validation)
//! - `test/trenino/virtual_joystick_test.exs` "exclusive input destinations"
//!
//! Each test cites the mirrored Elixir test in a comment. Fixtures use a
//! disposable tempfile database; trains/elements/lever configs/sequences/
//! scripts and vJoy mapping rows are seeded through a second connection
//! because their domain modules belong to other tracks.
use tempfile::tempdir;
use trenino_core::{EntityId, OperationId};
use trenino_runtime::storage::bindings::{
    BindOptions, ButtonBindingDraft, ButtonBindingPatch, ButtonHardwareType, ButtonMode,
    DisplayBindingDraft, DisplayBindingPatch, OutputBindingDraft, OutputBindingOperator,
    OutputBindingPatch, OutputType,
};
use trenino_runtime::storage::{
    Database, DeviceDraft, DisplayType, Ht16k33Params, I2cModuleDraft, InputDraft, InputKind,
    OutputDraft, StorageError,
};

fn database() -> (tempfile::TempDir, Database, Fixtures) {
    let dir = tempdir().unwrap();
    let path = dir.path().join("bindings.db");
    let db = Database::open_full(&path).unwrap();
    db.allocate_epoch().unwrap();
    let fixtures = Fixtures { path };
    (dir, db, fixtures)
}

/// Raw SQL fixture access for tables owned by other tracks.
struct Fixtures {
    path: std::path::PathBuf,
}

impl Fixtures {
    fn conn(&self) -> rusqlite::Connection {
        let conn = rusqlite::Connection::open(&self.path).unwrap();
        conn.pragma_update(None, "foreign_keys", "ON").unwrap();
        conn
    }

    fn insert(&self, sql: &str, params: &[&dyn rusqlite::ToSql]) -> EntityId {
        let conn = self.conn();
        conn.execute(sql, params).unwrap();
        EntityId(conn.last_insert_rowid())
    }

    fn train(&self, name: &str) -> EntityId {
        self.insert(
            "INSERT INTO trains(name,inserted_at,updated_at) VALUES(?1,'2026-01-01T00:00:00Z','2026-01-01T00:00:00Z')",
            &[&name],
        )
    }

    fn element(&self, train: EntityId, element_type: &str, name: &str) -> EntityId {
        self.insert(
            "INSERT INTO train_elements(train_id,type,name,inserted_at,updated_at) VALUES(?1,?2,?3,'2026-01-01T00:00:00Z','2026-01-01T00:00:00Z')",
            &[&train.0, &element_type, &name],
        )
    }

    fn lever_config(&self, element: EntityId) -> EntityId {
        self.insert(
            "INSERT INTO train_lever_configs(element_id,min_endpoint,max_endpoint,value_endpoint,inserted_at,updated_at) VALUES(?1,'Throttle.MinValue','Throttle.MaxValue','Throttle.InputValue','2026-01-01T00:00:00Z','2026-01-01T00:00:00Z')",
            &[&element.0],
        )
    }

    fn sequence(&self, train: EntityId, name: &str) -> EntityId {
        self.insert(
            "INSERT INTO sequences(name,train_id,inserted_at,updated_at) VALUES(?1,?2,'2026-01-01T00:00:00Z','2026-01-01T00:00:00Z')",
            &[&name, &train.0],
        )
    }

    fn script(&self, train: EntityId, name: &str) -> EntityId {
        self.insert(
            "INSERT INTO scripts(train_id,name,inserted_at,updated_at) VALUES(?1,?2,'2026-01-01T00:00:00Z','2026-01-01T00:00:00Z')",
            &[&train.0, &name],
        )
    }

    /// The Elixir vJoy test seeds a disabled lever binding with `Repo.insert`
    /// (virtual_joystick_test.exs l.376); the Rust test seeds it directly.
    fn disabled_lever_binding(&self, config: EntityId, input: EntityId) -> EntityId {
        self.insert(
            "INSERT INTO lever_input_bindings(lever_config_id,input_id,enabled,inserted_at,updated_at) VALUES(?1,?2,0,'2026-01-01T00:00:00Z','2026-01-01T00:00:00Z')",
            &[&config.0, &input.0],
        )
    }

    fn vjoy_axis_mapping(&self, input: EntityId, axis: &str) -> EntityId {
        self.insert(
            "INSERT INTO virtual_joystick_mappings(input_id,target_type,axis,inserted_at,updated_at) VALUES(?1,'axis',?2,'2026-01-01T00:00:00Z','2026-01-01T00:00:00Z')",
            &[&input.0, &axis],
        )
    }

    fn row_exists(&self, sql: &str, id: EntityId) -> bool {
        self.conn()
            .query_row(sql, [id.0], |row| row.get::<_, i64>(0))
            .is_ok()
    }

    fn delete(&self, table: &str, id: EntityId) {
        self.conn()
            .execute(&format!("DELETE FROM {table} WHERE id=?1"), [id.0])
            .unwrap();
    }

    fn exec(&self, sql: &str, params: &[&dyn rusqlite::ToSql]) {
        self.conn().execute(sql, params).unwrap();
    }
}

fn new_device(db: &Database, op: &mut u128) -> EntityId {
    let device = db
        .create_device(
            OperationId(*op),
            DeviceDraft {
                name: "Panel".into(),
                description: None,
                config_id: None,
            },
        )
        .unwrap();
    *op += 1;
    device.record.id
}

fn new_input(
    db: &Database,
    op: &mut u128,
    device: EntityId,
    pin: i32,
    kind: InputKind,
) -> EntityId {
    let input = db
        .create_input(
            OperationId(*op),
            device,
            InputDraft {
                pin,
                kind,
                sensitivity: (kind == InputKind::Analog).then_some(5),
                debounce: (kind == InputKind::Button).then_some(20),
                name: None,
                matrix_id: None,
            },
        )
        .unwrap();
    *op += 1;
    input.record.id
}

fn new_output(db: &Database, op: &mut u128, device: EntityId, pin: i32) -> EntityId {
    let output = db
        .create_output(
            OperationId(*op),
            device,
            OutputDraft {
                pin,
                name: Some("LED".into()),
            },
        )
        .unwrap();
    *op += 1;
    output.record.id
}

fn new_i2c_module(db: &Database, op: &mut u128, device: EntityId, address: i32) -> EntityId {
    let module = db
        .create_i2c_module(
            OperationId(*op),
            device,
            I2cModuleDraft {
                name: Some("Display".into()),
                module_chip: "ht16k33".into(),
                i2c_address: address,
                params: Some(Ht16k33Params {
                    brightness: 8,
                    num_digits: 4,
                    display_type: DisplayType::SevenSegment,
                    has_dot: false,
                    align_right: false,
                    min_value: None,
                }),
            },
        )
        .unwrap();
    *op += 1;
    module.record.id
}

fn constraint_detail(error: StorageError) -> String {
    match error {
        StorageError::Constraint { detail } => detail,
        other => panic!("expected Constraint error, got {other:?}"),
    }
}

fn conflict(error: &StorageError) -> String {
    match error {
        StorageError::Conflict { detail } => detail.clone(),
        other => panic!("expected Conflict error, got {other:?}"),
    }
}

// =====================
// Lever input bindings
// =====================

/// Mirrors train.ex `get_binding/1`, `bind_input/2,3`, `unbind_input/1`,
/// `set_binding_enabled/2` (usage asserted in virtual_joystick_test.exs
/// l.233-236 and train_edit_live_test.exs l.429).
#[test]
fn lever_binding_lifecycle() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let input1 = new_input(&db, &mut op, device, 2, InputKind::Analog);
    let input2 = new_input(&db, &mut op, device, 3, InputKind::Analog);
    let train = fx.train("Class 66");
    let element = fx.element(train, "lever", "Throttle");
    let config = fx.lever_config(element);

    assert!(db.get_lever_binding(config).unwrap().is_none());

    let bind_operation = op;
    let bound = db
        .bind_lever_input(OperationId(bind_operation), config, input1)
        .unwrap();
    op += 1;
    assert_eq!(bound.record.lever_config_id, config);
    assert_eq!(bound.record.input_id, input1);
    assert!(bound.record.enabled);
    assert_eq!(bound.receipt.metadata.revision, 1);
    assert_eq!(bound.receipt.operation_id, OperationId(bind_operation));

    // set_binding_enabled/2 disables.
    let disabled = db
        .set_lever_binding_enabled(OperationId(op), config, false)
        .unwrap();
    op += 1;
    assert!(!disabled.record.enabled);
    assert_eq!(disabled.receipt.metadata.revision, 2);

    // bind_input on an existing binding rebinds, preserving enabled state.
    let rebound = db
        .bind_lever_input(OperationId(op), config, input2)
        .unwrap();
    op += 1;
    assert_eq!(rebound.record.id, bound.record.id);
    assert_eq!(rebound.record.input_id, input2);
    assert!(!rebound.record.enabled);

    let found = db.get_lever_binding(config).unwrap().unwrap();
    assert_eq!(found, rebound.record);

    // unbind_input/1 → :ok | {:error, :not_found}.
    let deleted = db.unbind_lever_input(OperationId(op), config).unwrap();
    op += 1;
    assert_eq!(deleted.record.id, bound.record.id);
    assert!(db.get_lever_binding(config).unwrap().is_none());
    assert!(matches!(
        db.unbind_lever_input(OperationId(op), config),
        Err(StorageError::NotFound)
    ));
    assert!(matches!(
        db.set_lever_binding_enabled(OperationId(op), config, true),
        Err(StorageError::NotFound)
    ));
}

/// Mirrors the `foreign_key_constraint(:lever_config_id)` /
/// `foreign_key_constraint(:input_id)` declarations of
/// LeverInputBinding.changeset/2: binding to missing rows is a foreign-key
/// error and consumes no revision.
#[test]
fn lever_binding_foreign_key_errors_keep_revision() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let input = new_input(&db, &mut op, device, 2, InputKind::Analog);
    let train = fx.train("Class 66");
    let element = fx.element(train, "lever", "Throttle");
    let config = fx.lever_config(element);

    assert!(matches!(
        db.bind_lever_input(OperationId(op), config, EntityId(999_999)),
        Err(StorageError::ForeignKey { .. })
    ));
    assert!(matches!(
        db.bind_lever_input(OperationId(op), EntityId(999_998), input),
        Err(StorageError::ForeignKey { .. })
    ));

    let bound = db.bind_lever_input(OperationId(op), config, input).unwrap();
    assert_eq!(bound.receipt.metadata.revision, 1);
}

/// Mirrors virtual_joystick_test.exs l.268-285
/// "binding a lever input mapped to vJoy requires replacement and preserves
/// unrelated mappings".
#[test]
fn lever_binding_mapped_input_conflicts_unless_replaced() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let mapped_input = new_input(&db, &mut op, device, 2, InputKind::Analog);
    let unrelated_input = new_input(&db, &mut op, device, 3, InputKind::Analog);
    let train = fx.train("Class 66");
    let element = fx.element(train, "lever", "Throttle");
    let config = fx.lever_config(element);

    let mapping = fx.vjoy_axis_mapping(mapped_input, "x");
    let unrelated_mapping = fx.vjoy_axis_mapping(unrelated_input, "y");

    let error = db
        .bind_lever_input(OperationId(op), config, mapped_input)
        .unwrap_err();
    op += 1;
    assert!(conflict(&error).contains("destination conflict"));
    assert!(db.get_lever_binding(config).unwrap().is_none());

    let bound = db
        .bind_lever_input_with(
            OperationId(op),
            config,
            mapped_input,
            BindOptions { replace: true },
        )
        .unwrap();
    assert_eq!(bound.record.input_id, mapped_input);
    // The conflicting mapping is deleted; the unrelated one is preserved.
    assert!(!fx.row_exists(
        "SELECT id FROM virtual_joystick_mappings WHERE id=?1",
        mapping
    ));
    assert!(fx.row_exists(
        "SELECT id FROM virtual_joystick_mappings WHERE id=?1",
        unrelated_mapping
    ));
}

/// Mirrors virtual_joystick_test.exs l.368-391 "enabling an inactive lever
/// binding mapped to vJoy requires replacement".
#[test]
fn lever_binding_enable_mapped_input_requires_replacement() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let input = new_input(&db, &mut op, device, 2, InputKind::Analog);
    let train = fx.train("Class 66");
    let element = fx.element(train, "lever", "Throttle");
    let config = fx.lever_config(element);

    let mapping = fx.vjoy_axis_mapping(input, "x");
    fx.disabled_lever_binding(config, input);
    assert!(!db.get_lever_binding(config).unwrap().unwrap().enabled);

    assert!(matches!(
        db.set_lever_binding_enabled(OperationId(op), config, true),
        Err(StorageError::Conflict { .. })
    ));
    op += 1;
    assert!(!db.get_lever_binding(config).unwrap().unwrap().enabled);

    let enabled = db
        .set_lever_binding_enabled_with(
            OperationId(op),
            config,
            true,
            BindOptions { replace: true },
        )
        .unwrap();
    assert!(enabled.record.enabled);
    assert!(!fx.row_exists(
        "SELECT id FROM virtual_joystick_mappings WHERE id=?1",
        mapping
    ));
}

/// Mirrors the `if enabled?` guard of `persist_binding/4` (train.ex l.915-919):
/// a binding that stays disabled never conflicts with vJoy mappings.
#[test]
fn lever_binding_disabled_rebind_to_mapped_input_is_allowed() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let input1 = new_input(&db, &mut op, device, 2, InputKind::Analog);
    let input2 = new_input(&db, &mut op, device, 3, InputKind::Analog);
    let train = fx.train("Class 66");
    let element = fx.element(train, "lever", "Throttle");
    let config = fx.lever_config(element);

    db.bind_lever_input(OperationId(op), config, input1)
        .unwrap();
    op += 1;
    db.set_lever_binding_enabled(OperationId(op), config, false)
        .unwrap();
    op += 1;

    let mapping = fx.vjoy_axis_mapping(input2, "x");
    let rebound = db
        .bind_lever_input(OperationId(op), config, input2)
        .unwrap();
    assert_eq!(rebound.record.input_id, input2);
    assert!(!rebound.record.enabled);
    assert!(fx.row_exists(
        "SELECT id FROM virtual_joystick_mappings WHERE id=?1",
        mapping
    ));
}

/// Mirrors train.ex `list_bindings_for_train/1` (join through lever configs
/// and elements to the train).
#[test]
fn lever_bindings_list_for_train_scopes_by_train() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let input = new_input(&db, &mut op, device, 2, InputKind::Analog);
    let train1 = fx.train("Class 66");
    let train2 = fx.train("Voyager");
    let empty_train = fx.train("Empty");

    let e1 = fx.element(train1, "lever", "Throttle");
    let c1 = fx.lever_config(e1);
    let e2 = fx.element(train1, "lever", "Brake");
    let c2 = fx.lever_config(e2);
    let e3 = fx.element(train2, "lever", "Power");
    let c3 = fx.lever_config(e3);

    db.bind_lever_input(OperationId(op), c1, input).unwrap();
    op += 1;
    db.bind_lever_input(OperationId(op), c2, input).unwrap();
    op += 1;
    db.bind_lever_input(OperationId(op), c3, input).unwrap();

    // The same input may drive several lever configs (LeverInputBinding docs).
    let first_train = db.list_lever_bindings_for_train(train1).unwrap();
    let ids: Vec<EntityId> = first_train.iter().map(|b| b.lever_config_id).collect();
    assert_eq!(ids, vec![c1, c2]);
    assert_eq!(db.list_lever_bindings_for_train(train2).unwrap().len(), 1);
    assert!(db
        .list_lever_bindings_for_train(empty_train)
        .unwrap()
        .is_empty());
}

// =====================
// Button input bindings
// =====================

/// Mirrors train_test.exs l.724-750 (create defaults and custom on/off
/// values) and button_input_binding_test.exs l.39-78 (changeset defaults),
/// including the two-decimal rounding of round_float_fields/2.
#[test]
fn button_binding_create_defaults_custom_values_and_rounding() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let input = new_input(&db, &mut op, device, 5, InputKind::Button);
    let train = fx.train("Class 66");
    let element = fx.element(train, "button", "Horn");

    let created = db
        .create_button_binding(
            OperationId(op),
            element,
            input,
            ButtonBindingDraft {
                endpoint: Some("CurrentDrivableActor/Horn.InputValue".into()),
                ..Default::default()
            },
        )
        .unwrap();
    op += 1;
    let record = &created.record;
    assert_eq!(record.element_id, element);
    assert_eq!(record.input_id, input);
    assert_eq!(
        record.endpoint.as_deref(),
        Some("CurrentDrivableActor/Horn.InputValue")
    );
    assert_eq!(record.on_value, 1.0);
    assert_eq!(record.off_value, 0.0);
    assert!(record.enabled);
    assert_eq!(record.mode, ButtonMode::Simple);
    assert_eq!(record.hardware_type, ButtonHardwareType::Momentary);
    assert_eq!(record.repeat_interval_ms, 100);
    assert_eq!(record.keystroke, None);
    assert_eq!(record.on_sequence_id, None);
    assert_eq!(record.off_sequence_id, None);

    // Custom values are rounded to two decimals (output_binding-style
    // rounding also applies to button on/off values).
    let custom = db
        .create_button_binding(
            OperationId(op),
            fx.element(train, "button", "Bell"),
            input,
            ButtonBindingDraft {
                endpoint: Some("Bell.InputValue".into()),
                on_value: Some(100.123),
                off_value: Some(-50.987),
                ..Default::default()
            },
        )
        .unwrap();
    assert_eq!(custom.record.on_value, 100.12);
    assert_eq!(custom.record.off_value, -50.99);
}

/// Mirrors button_input_binding_test.exs l.237-373 (sequence mode validation)
/// plus the mode/keystroke/repeat rules of ButtonInputBinding.changeset/2 and
/// the mcp/tools/button_binding_tools_test.exs creation shapes.
#[test]
fn button_binding_mode_and_sequence_validation() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let input = new_input(&db, &mut op, device, 5, InputKind::Button);
    let train = fx.train("Class 66");
    let horn = fx.element(train, "button", "Horn");
    let bell = fx.element(train, "button", "Bell");
    let door = fx.element(train, "button", "Door");
    let lamp = fx.element(train, "button", "Lamp");
    let pane = fx.element(train, "button", "Pane");
    let whis = fx.element(train, "button", "Whistle");
    let knob = fx.element(train, "button", "Knob");
    let sequence = fx.sequence(train, "Open Door");
    let sequence2 = fx.sequence(train, "Close Door");

    // Simple mode without endpoint (train_test.exs l.752-756).
    let error = db
        .create_button_binding(OperationId(op), horn, input, ButtonBindingDraft::default())
        .unwrap_err();
    assert_eq!(constraint_detail(error), "endpoint can't be blank");
    // Whitespace-only endpoint counts as blank for validate_required/3.
    let error = db
        .create_button_binding(
            OperationId(op),
            horn,
            input,
            ButtonBindingDraft {
                endpoint: Some("   ".into()),
                ..Default::default()
            },
        )
        .unwrap_err();
    assert_eq!(constraint_detail(error), "endpoint can't be blank");
    op += 1;

    // Momentary mode with endpoint and repeat interval (mcp tools test l.107).
    db.create_button_binding(
        OperationId(op),
        horn,
        input,
        ButtonBindingDraft {
            endpoint: Some("Horn.InputValue".into()),
            mode: Some(ButtonMode::Momentary),
            repeat_interval_ms: Some(200),
            ..Default::default()
        },
    )
    .unwrap();
    op += 1;

    // Keystroke mode requires the keystroke field.
    let error = db
        .create_button_binding(
            OperationId(op),
            bell,
            input,
            ButtonBindingDraft {
                mode: Some(ButtonMode::Keystroke),
                ..Default::default()
            },
        )
        .unwrap_err();
    assert_eq!(constraint_detail(error), "keystroke can't be blank");
    db.create_button_binding(
        OperationId(op),
        bell,
        input,
        ButtonBindingDraft {
            mode: Some(ButtonMode::Keystroke),
            keystroke: Some("W".into()),
            ..Default::default()
        },
    )
    .unwrap();
    op += 1;

    // Sequence mode requires at least one sequence (l.324-335).
    let error = db
        .create_button_binding(
            OperationId(op),
            door,
            input,
            ButtonBindingDraft {
                mode: Some(ButtonMode::Sequence),
                ..Default::default()
            },
        )
        .unwrap_err();
    assert_eq!(
        constraint_detail(error),
        "on_sequence_id at least one sequence is required"
    );

    // on_sequence only is valid for momentary and latching hardware (l.254-286).
    db.create_button_binding(
        OperationId(op),
        door,
        input,
        ButtonBindingDraft {
            mode: Some(ButtonMode::Sequence),
            hardware_type: Some(ButtonHardwareType::Latching),
            on_sequence_id: Some(sequence),
            ..Default::default()
        },
    )
    .unwrap();
    op += 1;

    // off_sequence only is valid for latching hardware (l.288-303).
    db.create_button_binding(
        OperationId(op),
        lamp,
        input,
        ButtonBindingDraft {
            mode: Some(ButtonMode::Sequence),
            hardware_type: Some(ButtonHardwareType::Latching),
            off_sequence_id: Some(sequence),
            ..Default::default()
        },
    )
    .unwrap();
    op += 1;

    // Both sequences on latching hardware (l.305-322).
    db.create_button_binding(
        OperationId(op),
        pane,
        input,
        ButtonBindingDraft {
            mode: Some(ButtonMode::Sequence),
            hardware_type: Some(ButtonHardwareType::Latching),
            on_sequence_id: Some(sequence),
            off_sequence_id: Some(sequence2),
            ..Default::default()
        },
    )
    .unwrap();
    op += 1;

    // off_sequence on momentary hardware in sequence mode (l.337-354).
    let error = db
        .create_button_binding(
            OperationId(op),
            whis,
            input,
            ButtonBindingDraft {
                mode: Some(ButtonMode::Sequence),
                on_sequence_id: Some(sequence),
                off_sequence_id: Some(sequence2),
                ..Default::default()
            },
        )
        .unwrap_err();
    assert_eq!(
        constraint_detail(error),
        "off_sequence_id is only valid for latching hardware"
    );

    // off_sequence outside sequence mode (l.356-372).
    let error = db
        .create_button_binding(
            OperationId(op),
            whis,
            input,
            ButtonBindingDraft {
                endpoint: Some("Test.Endpoint".into()),
                off_sequence_id: Some(sequence),
                ..Default::default()
            },
        )
        .unwrap_err();
    assert_eq!(
        constraint_detail(error),
        "off_sequence_id is only valid in sequence mode"
    );

    // repeat_interval_ms bounds (validate_number greater_than/less_than_or_equal_to).
    let error = db
        .create_button_binding(
            OperationId(op),
            whis,
            input,
            ButtonBindingDraft {
                endpoint: Some("Test.Endpoint".into()),
                repeat_interval_ms: Some(0),
                ..Default::default()
            },
        )
        .unwrap_err();
    assert_eq!(
        constraint_detail(error),
        "repeat_interval_ms must be greater than 0"
    );
    let error = db
        .create_button_binding(
            OperationId(op),
            whis,
            input,
            ButtonBindingDraft {
                endpoint: Some("Test.Endpoint".into()),
                repeat_interval_ms: Some(5001),
                ..Default::default()
            },
        )
        .unwrap_err();
    assert_eq!(
        constraint_detail(error),
        "repeat_interval_ms must be less than or equal to 5000"
    );
    db.create_button_binding(
        OperationId(op),
        whis,
        input,
        ButtonBindingDraft {
            endpoint: Some("Test.Endpoint".into()),
            mode: Some(ButtonMode::Momentary),
            repeat_interval_ms: Some(5000),
            ..Default::default()
        },
    )
    .unwrap();
    assert!(db.get_button_binding(whis).unwrap().is_some());
    assert!(db.get_button_binding(knob).unwrap().is_none());
}

/// Mirrors button_input_binding_test.exs l.149-196: unique element_id, shared
/// input across elements allowed.
#[test]
fn button_binding_unique_element_and_shared_input() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let input = new_input(&db, &mut op, device, 5, InputKind::Button);
    let input2 = new_input(&db, &mut op, device, 6, InputKind::Button);
    let train = fx.train("Class 66");
    let horn = fx.element(train, "button", "Horn");
    let bell = fx.element(train, "button", "Bell");

    db.create_button_binding(
        OperationId(op),
        horn,
        input,
        ButtonBindingDraft {
            endpoint: Some("Horn.InputValue".into()),
            ..Default::default()
        },
    )
    .unwrap();
    op += 1;

    // Same element again → unique index violation ("has already been taken").
    assert!(matches!(
        db.create_button_binding(
            OperationId(op),
            horn,
            input2,
            ButtonBindingDraft {
                endpoint: Some("Horn.InputValue".into()),
                ..Default::default()
            },
        ),
        Err(StorageError::Conflict { .. })
    ));

    // Same input on another element is fine.
    db.create_button_binding(
        OperationId(op),
        bell,
        input,
        ButtonBindingDraft {
            endpoint: Some("Bell.InputValue".into()),
            ..Default::default()
        },
    )
    .unwrap();
}

/// Mirrors train_test.exs l.759-803 (update_button_binding) plus the Ecto
/// partial-update semantics of cast/3.
#[test]
fn button_binding_update_fields_and_validation() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let input = new_input(&db, &mut op, device, 5, InputKind::Button);
    let input2 = new_input(&db, &mut op, device, 6, InputKind::Button);
    let train = fx.train("Class 66");
    let horn = fx.element(train, "button", "Horn");

    let created = db
        .create_button_binding(
            OperationId(op),
            horn,
            input,
            ButtonBindingDraft {
                endpoint: Some("Horn.InputValue".into()),
                ..Default::default()
            },
        )
        .unwrap()
        .record;
    op += 1;

    let updated = db
        .update_button_binding(
            OperationId(op),
            created.id,
            ButtonBindingPatch {
                endpoint: Some(Some("CurrentDrivableActor/Bell.InputValue".into())),
                on_value: Some(5.0),
                off_value: Some(-5.0),
                ..Default::default()
            },
        )
        .unwrap();
    op += 1;
    assert_eq!(
        updated.record.endpoint.as_deref(),
        Some("CurrentDrivableActor/Bell.InputValue")
    );
    assert_eq!(updated.record.on_value, 5.0);
    assert_eq!(updated.record.off_value, -5.0);
    assert!(updated.record.enabled);

    let disabled = db
        .update_button_binding(
            OperationId(op),
            created.id,
            ButtonBindingPatch {
                enabled: Some(false),
                ..Default::default()
            },
        )
        .unwrap();
    op += 1;
    assert!(!disabled.record.enabled);

    let rebound = db
        .update_button_binding(
            OperationId(op),
            created.id,
            ButtonBindingPatch {
                input_id: Some(input2),
                ..Default::default()
            },
        )
        .unwrap();
    op += 1;
    assert_eq!(rebound.record.input_id, input2);

    // Clearing the endpoint of a simple binding fails validate_required(:endpoint).
    let error = db
        .update_button_binding(
            OperationId(op),
            created.id,
            ButtonBindingPatch {
                endpoint: Some(None),
                ..Default::default()
            },
        )
        .unwrap_err();
    assert_eq!(constraint_detail(error), "endpoint can't be blank");

    assert!(matches!(
        db.update_button_binding(
            OperationId(op),
            EntityId(999_999),
            ButtonBindingPatch::default(),
        ),
        Err(StorageError::NotFound)
    ));
}

/// Mirrors train_test.exs l.805-877 (delete_button_binding and
/// set_button_binding_enabled, including the :not_found paths).
#[test]
fn button_binding_delete_and_enabled_toggle() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let input = new_input(&db, &mut op, device, 5, InputKind::Button);
    let train = fx.train("Class 66");
    let horn = fx.element(train, "button", "Horn");

    db.create_button_binding(
        OperationId(op),
        horn,
        input,
        ButtonBindingDraft {
            endpoint: Some("Horn.InputValue".into()),
            ..Default::default()
        },
    )
    .unwrap();
    op += 1;

    let disabled = db
        .set_button_binding_enabled(OperationId(op), horn, false)
        .unwrap();
    op += 1;
    assert!(!disabled.record.enabled);

    let enabled = db
        .set_button_binding_enabled(OperationId(op), horn, true)
        .unwrap();
    op += 1;
    assert!(enabled.record.enabled);

    assert!(matches!(
        db.set_button_binding_enabled(OperationId(op), EntityId(999_999), true),
        Err(StorageError::NotFound)
    ));

    db.delete_button_binding(OperationId(op), horn).unwrap();
    op += 1;
    assert!(db.get_button_binding(horn).unwrap().is_none());
    assert!(matches!(
        db.delete_button_binding(OperationId(op), horn),
        Err(StorageError::NotFound)
    ));
}

/// Mirrors button_input_binding_test.exs l.198-234: cascades when the element
/// or the input is deleted.
#[test]
fn button_binding_cascades_on_element_and_input_delete() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let input = new_input(&db, &mut op, device, 5, InputKind::Button);
    let input2 = new_input(&db, &mut op, device, 6, InputKind::Button);
    let train = fx.train("Class 66");
    let horn = fx.element(train, "button", "Horn");
    let bell = fx.element(train, "button", "Bell");

    db.create_button_binding(
        OperationId(op),
        horn,
        input,
        ButtonBindingDraft {
            endpoint: Some("Horn.InputValue".into()),
            ..Default::default()
        },
    )
    .unwrap();
    db.create_button_binding(
        OperationId(op),
        bell,
        input2,
        ButtonBindingDraft {
            endpoint: Some("Bell.InputValue".into()),
            ..Default::default()
        },
    )
    .unwrap();

    // Element delete cascades (ON DELETE CASCADE on element_id).
    fx.delete("train_elements", horn);
    assert!(db.get_button_binding(horn).unwrap().is_none());

    // Input delete cascades (ON DELETE CASCADE on input_id).
    db.delete_input(OperationId(op), input2).unwrap();
    assert!(db.get_button_binding(bell).unwrap().is_none());
}

/// Mirrors the ON DELETE SET NULL foreign keys for on/off sequences declared
/// by ButtonInputBinding (belongs_to :on_sequence/:off_sequence).
#[test]
fn button_binding_sequence_delete_sets_references_null() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let input = new_input(&db, &mut op, device, 5, InputKind::Button);
    let train = fx.train("Class 66");
    let door = fx.element(train, "button", "Door");
    let on_sequence = fx.sequence(train, "Open Door");
    let off_sequence = fx.sequence(train, "Close Door");

    let created = db
        .create_button_binding(
            OperationId(op),
            door,
            input,
            ButtonBindingDraft {
                mode: Some(ButtonMode::Sequence),
                hardware_type: Some(ButtonHardwareType::Latching),
                on_sequence_id: Some(on_sequence),
                off_sequence_id: Some(off_sequence),
                ..Default::default()
            },
        )
        .unwrap()
        .record;

    fx.delete("sequences", on_sequence);
    let found = db.get_button_binding(door).unwrap().unwrap();
    assert_eq!(found.id, created.id);
    assert_eq!(found.on_sequence_id, None);
    assert_eq!(found.off_sequence_id, Some(off_sequence));

    fx.delete("sequences", off_sequence);
    let found = db.get_button_binding(door).unwrap().unwrap();
    assert_eq!(found.on_sequence_id, None);
    assert_eq!(found.off_sequence_id, None);
}

/// Mirrors virtual_joystick_test.exs l.287-337 (creating/updating button
/// bindings on vJoy-mapped inputs requires replacement), l.354-366 (an
/// invalid replacement keeps the mapping), and train_test.exs l.879-898
/// (enabling a disabled binding mapped to vJoy requires replacement).
#[test]
fn button_binding_vjoy_destination_rules() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let mapped_input = new_input(&db, &mut op, device, 5, InputKind::Button);
    let unrelated_input = new_input(&db, &mut op, device, 6, InputKind::Button);
    let current_input = new_input(&db, &mut op, device, 7, InputKind::Button);
    let spare_input = new_input(&db, &mut op, device, 8, InputKind::Button);
    let spare2_input = new_input(&db, &mut op, device, 9, InputKind::Button);
    let train = fx.train("Class 66");
    let horn = fx.element(train, "button", "Horn");
    let bell = fx.element(train, "button", "Bell");

    // Creation conflicts without replacement, replaces with it.
    let mapping = fx.vjoy_axis_mapping(mapped_input, "x");
    let unrelated_mapping = fx.vjoy_axis_mapping(unrelated_input, "y");
    assert!(matches!(
        db.create_button_binding(
            OperationId(op),
            horn,
            mapped_input,
            ButtonBindingDraft {
                endpoint: Some("Horn.InputValue".into()),
                ..Default::default()
            },
        ),
        Err(StorageError::Conflict { .. })
    ));
    db.create_button_binding_with(
        OperationId(op),
        horn,
        mapped_input,
        ButtonBindingDraft {
            endpoint: Some("Horn.InputValue".into()),
            ..Default::default()
        },
        BindOptions { replace: true },
    )
    .unwrap();
    op += 1;
    assert!(!fx.row_exists(
        "SELECT id FROM virtual_joystick_mappings WHERE id=?1",
        mapping
    ));
    assert!(fx.row_exists(
        "SELECT id FROM virtual_joystick_mappings WHERE id=?1",
        unrelated_mapping
    ));

    // Rebinding to a mapped input conflicts without replacement.
    let mapped2 = fx.vjoy_axis_mapping(current_input, "z");
    let existing = db.get_button_binding(horn).unwrap().unwrap();
    assert!(matches!(
        db.update_button_binding(
            OperationId(op),
            existing.id,
            ButtonBindingPatch {
                input_id: Some(current_input),
                ..Default::default()
            },
        ),
        Err(StorageError::Conflict { .. })
    ));
    let rebound = db
        .update_button_binding_with(
            OperationId(op),
            existing.id,
            ButtonBindingPatch {
                input_id: Some(current_input),
                ..Default::default()
            },
            BindOptions { replace: true },
        )
        .unwrap();
    op += 1;
    assert_eq!(rebound.record.input_id, current_input);
    assert!(!fx.row_exists(
        "SELECT id FROM virtual_joystick_mappings WHERE id=?1",
        mapped2
    ));

    // An invalid replacement attempt keeps the mapping (transaction rollback).
    let mapping3 = fx.vjoy_axis_mapping(spare_input, "rx");
    let error = db
        .create_button_binding_with(
            OperationId(op),
            bell,
            spare_input,
            ButtonBindingDraft::default(), // missing endpoint → invalid changeset
            BindOptions { replace: true },
        )
        .unwrap_err();
    assert_eq!(constraint_detail(error), "endpoint can't be blank");
    assert!(fx.row_exists(
        "SELECT id FROM virtual_joystick_mappings WHERE id=?1",
        mapping3
    ));
    assert!(db.get_button_binding(bell).unwrap().is_none());

    // A disabled binding bypasses the check; enabling it conflicts until replaced.
    let mapping4 = fx.vjoy_axis_mapping(spare2_input, "ry");
    db.create_button_binding(
        OperationId(op),
        bell,
        spare2_input,
        ButtonBindingDraft {
            endpoint: Some("Bell.InputValue".into()),
            enabled: Some(false),
            ..Default::default()
        },
    )
    .unwrap();
    op += 1;
    assert!(fx.row_exists(
        "SELECT id FROM virtual_joystick_mappings WHERE id=?1",
        mapping4
    ));
    assert!(matches!(
        db.set_button_binding_enabled(OperationId(op), bell, true),
        Err(StorageError::Conflict { .. })
    ));
    assert!(!db.get_button_binding(bell).unwrap().unwrap().enabled);
    let enabled = db
        .set_button_binding_enabled_with(OperationId(op), bell, true, BindOptions { replace: true })
        .unwrap();
    assert!(enabled.record.enabled);
    assert!(!fx.row_exists(
        "SELECT id FROM virtual_joystick_mappings WHERE id=?1",
        mapping4
    ));
}

/// Mirrors train_test.exs l.902-991 (list_button_bindings_for_train).
#[test]
fn button_bindings_list_for_train_scopes_by_train() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let input1 = new_input(&db, &mut op, device, 5, InputKind::Button);
    let input3 = new_input(&db, &mut op, device, 6, InputKind::Button);
    let train = fx.train("Class 66");
    let other_train = fx.train("Other Train");

    assert!(db.list_button_bindings_for_train(train).unwrap().is_empty());

    let horn = fx.element(train, "button", "Horn");
    let bell = fx.element(train, "button", "Bell");
    let other_horn = fx.element(other_train, "button", "Other Horn");
    db.create_button_binding(
        OperationId(op),
        horn,
        input1,
        ButtonBindingDraft {
            endpoint: Some("Horn.InputValue".into()),
            ..Default::default()
        },
    )
    .unwrap();
    db.create_button_binding(
        OperationId(op),
        bell,
        input1,
        ButtonBindingDraft {
            endpoint: Some("Bell.InputValue".into()),
            ..Default::default()
        },
    )
    .unwrap();
    db.create_button_binding(
        OperationId(op),
        other_horn,
        input3,
        ButtonBindingDraft {
            endpoint: Some("Horn.InputValue".into()),
            ..Default::default()
        },
    )
    .unwrap();

    let bindings = db.list_button_bindings_for_train(train).unwrap();
    let mut ids: Vec<EntityId> = bindings.iter().map(|b| b.element_id).collect();
    ids.sort();
    let mut expected = vec![horn, bell];
    expected.sort();
    assert_eq!(ids, expected);
}

// =====================
// Output bindings
// =====================

/// Mirrors output_binding_test.exs l.21-167 (changeset rules and rounding)
/// and output_binding_context_test.exs l.173-338 (context CRUD).
#[test]
fn output_binding_crud_roundtrip() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let output = new_output(&db, &mut op, device, 13);
    let train = fx.train("Class 66");

    let created = db
        .create_output_binding(
            OperationId(op),
            train,
            OutputBindingDraft {
                name: "Speed Warning".into(),
                output_id: output,
                endpoint: "CurrentDrivableActor.Function.HUD_GetSpeed".into(),
                operator: OutputBindingOperator::Gt,
                value_a: Some(50.0),
                output_type: None,
                value_b: None,
                enabled: None,
            },
        )
        .unwrap();
    op += 1;
    assert_eq!(created.record.train_id, train);
    assert_eq!(created.record.name, "Speed Warning");
    assert_eq!(created.record.operator, OutputBindingOperator::Gt);
    assert_eq!(created.record.value_a, Some(50.0));
    assert_eq!(created.record.output_type, OutputType::Led);
    assert!(created.record.enabled);
    assert_eq!(created.receipt.metadata.revision, 1);

    let found = db.get_output_binding(created.record.id).unwrap().unwrap();
    assert_eq!(found, created.record);
    assert!(db.get_output_binding(EntityId(999_999)).unwrap().is_none());

    // Update name/value_a, then switch to between with value_b.
    let updated = db
        .update_output_binding(
            OperationId(op),
            created.record.id,
            OutputBindingPatch {
                name: Some("Updated Name".into()),
                value_a: Some(Some(75.0)),
                ..Default::default()
            },
        )
        .unwrap();
    op += 1;
    assert_eq!(updated.record.name, "Updated Name");
    assert_eq!(updated.record.value_a, Some(75.0));

    let between = db
        .update_output_binding(
            OperationId(op),
            created.record.id,
            OutputBindingPatch {
                operator: Some(OutputBindingOperator::Between),
                value_a: Some(Some(30.12345)),
                value_b: Some(Some(60.98765)),
                ..Default::default()
            },
        )
        .unwrap();
    op += 1;
    assert_eq!(between.record.operator, OutputBindingOperator::Between);
    assert_eq!(between.record.value_a, Some(30.12));
    assert_eq!(between.record.value_b, Some(60.99));

    // Enabled toggle.
    let disabled = db
        .update_output_binding(
            OperationId(op),
            created.record.id,
            OutputBindingPatch {
                enabled: Some(false),
                ..Default::default()
            },
        )
        .unwrap();
    op += 1;
    assert!(!disabled.record.enabled);
    let enabled = db
        .update_output_binding(
            OperationId(op),
            created.record.id,
            OutputBindingPatch {
                enabled: Some(true),
                ..Default::default()
            },
        )
        .unwrap();
    assert!(enabled.record.enabled);

    db.delete_output_binding(OperationId(op), created.record.id)
        .unwrap();
    assert!(db.get_output_binding(created.record.id).unwrap().is_none());
    assert!(matches!(
        db.delete_output_binding(OperationId(op), created.record.id),
        Err(StorageError::NotFound)
    ));
}

/// Mirrors output_binding_test.exs l.55-120 and l.199-257 (operator value
/// requirements and required fields).
#[test]
fn output_binding_validation() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let output = new_output(&db, &mut op, device, 13);
    let output2 = new_output(&db, &mut op, device, 14);
    let output3 = new_output(&db, &mut op, device, 15);
    let train = fx.train("Class 66");

    fn draft(
        output: EntityId,
        name: &str,
        endpoint: &str,
        operator: OutputBindingOperator,
        value_a: Option<f64>,
    ) -> OutputBindingDraft {
        OutputBindingDraft {
            name: name.into(),
            output_id: output,
            endpoint: endpoint.into(),
            operator,
            value_a,
            output_type: None,
            value_b: None,
            enabled: None,
        }
    }

    // Numeric operators require value_a (l.244-257).
    let error = db
        .create_output_binding(
            OperationId(op),
            train,
            draft(output, "Test", "Speed", OutputBindingOperator::Gt, None),
        )
        .unwrap_err();
    assert_eq!(constraint_detail(error), "value_a can't be blank");

    // between requires value_b (l.55-69).
    let error = db
        .create_output_binding(
            OperationId(op),
            train,
            OutputBindingDraft {
                name: "Speed Range".into(),
                output_id: output,
                endpoint: "Speed".into(),
                operator: OutputBindingOperator::Between,
                value_a: Some(30.0),
                value_b: None,
                output_type: None,
                enabled: None,
            },
        )
        .unwrap_err();
    assert_eq!(constraint_detail(error), "value_b can't be blank");

    // Boolean operators need no value_a (l.88-120); each needs its own
    // output because (train_id, output_id) is unique.
    for (operator, output_id) in [
        (OutputBindingOperator::EqTrue, output),
        (OutputBindingOperator::EqFalse, output2),
    ] {
        db.create_output_binding(
            OperationId(op),
            train,
            draft(output_id, "Warning", "WarningStateVisual", operator, None),
        )
        .unwrap();
    }
    op += 1;

    // Blank name and endpoint behave like missing (l.199-227).
    let error = db
        .create_output_binding(
            OperationId(op),
            train,
            draft(output, "   ", "Speed", OutputBindingOperator::Gt, Some(1.0)),
        )
        .unwrap_err();
    assert_eq!(constraint_detail(error), "name can't be blank");
    let error = db
        .create_output_binding(
            OperationId(op),
            train,
            draft(output, "Test", "  ", OutputBindingOperator::Gt, Some(1.0)),
        )
        .unwrap_err();
    assert_eq!(constraint_detail(error), "endpoint can't be blank");

    // Updating to between without value_b fails on the effective record.
    let created = db
        .create_output_binding(
            OperationId(op),
            train,
            draft(
                output3,
                "Guard",
                "Speed",
                OutputBindingOperator::Gt,
                Some(10.0),
            ),
        )
        .unwrap();
    let error = db
        .update_output_binding(
            OperationId(op),
            created.record.id,
            OutputBindingPatch {
                operator: Some(OutputBindingOperator::Between),
                ..Default::default()
            },
        )
        .unwrap_err();
    assert_eq!(constraint_detail(error), "value_b can't be blank");
}

/// Mirrors output_binding_test.exs l.274-332 (unique train_id+output_id, same
/// output allowed for different trains).
#[test]
fn output_binding_unique_train_output_pair() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let output = new_output(&db, &mut op, device, 13);
    let train = fx.train("Class 66");
    let other_train = fx.train("Voyager");

    let draft = || OutputBindingDraft {
        name: "Speed Warning".into(),
        output_id: output,
        endpoint: "Speed".into(),
        operator: OutputBindingOperator::Gt,
        value_a: Some(50.0),
        output_type: None,
        value_b: None,
        enabled: None,
    };
    db.create_output_binding(OperationId(op), train, draft())
        .unwrap();
    op += 1;

    let error = db
        .create_output_binding(
            OperationId(op),
            train,
            OutputBindingDraft {
                name: "Different Name".into(),
                ..draft()
            },
        )
        .unwrap_err();
    let detail = conflict(&error);
    assert!(detail.contains("UNIQUE") || detail.contains("unique"));

    db.create_output_binding(OperationId(op), other_train, draft())
        .unwrap();
}

/// Mirrors output_binding_test.exs l.334-372: cascades on train and output
/// deletion. FK violations on missing train/output mirror the
/// foreign_key_constraint declarations.
#[test]
fn output_binding_cascades_and_foreign_keys() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let output = new_output(&db, &mut op, device, 13);
    let output2 = new_output(&db, &mut op, device, 14);
    let train = fx.train("Class 66");
    let train2 = fx.train("Voyager");

    let draft = |output_id: EntityId| OutputBindingDraft {
        name: "Speed Warning".into(),
        output_id,
        endpoint: "Speed".into(),
        operator: OutputBindingOperator::Gt,
        value_a: Some(50.0),
        output_type: None,
        value_b: None,
        enabled: None,
    };
    assert!(matches!(
        db.create_output_binding(OperationId(op), EntityId(999_999), draft(output)),
        Err(StorageError::ForeignKey { .. })
    ));
    assert!(matches!(
        db.create_output_binding(OperationId(op), train, draft(EntityId(999_998))),
        Err(StorageError::ForeignKey { .. })
    ));

    let a = db
        .create_output_binding(OperationId(op), train, draft(output))
        .unwrap();
    let b = db
        .create_output_binding(OperationId(op), train2, draft(output2))
        .unwrap();

    // Deleting the train cascades the binding away.
    fx.delete("trains", train);
    assert!(db.get_output_binding(a.record.id).unwrap().is_none());

    // Deleting the output cascades the binding away.
    db.delete_output(OperationId(op), output2).unwrap();
    assert!(db.get_output_binding(b.record.id).unwrap().is_none());
}

/// Mirrors output_binding_context_test.exs l.11-171 (listing, name ordering,
/// enabled filter, train scoping).
#[test]
fn output_binding_list_order_and_enabled_filter() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let output1 = new_output(&db, &mut op, device, 13);
    let output2 = new_output(&db, &mut op, device, 14);
    let output3 = new_output(&db, &mut op, device, 15);
    let train = fx.train("Class 66");
    let other_train = fx.train("Voyager");

    assert!(db.list_output_bindings(train).unwrap().is_empty());

    let draft = |name: &str, output_id: EntityId, enabled: Option<bool>| OutputBindingDraft {
        name: name.into(),
        output_id,
        endpoint: "Speed".into(),
        operator: OutputBindingOperator::Gt,
        value_a: Some(50.0),
        output_type: None,
        value_b: None,
        enabled,
    };
    db.create_output_binding(OperationId(op), train, draft("Zebra", output1, None))
        .unwrap();
    db.create_output_binding(OperationId(op), train, draft("Alpha", output2, None))
        .unwrap();
    db.create_output_binding(
        OperationId(op),
        train,
        draft("Disabled", output3, Some(false)),
    )
    .unwrap();
    db.create_output_binding(OperationId(op), other_train, draft("Other", output1, None))
        .unwrap();

    let names: Vec<String> = db
        .list_output_bindings(train)
        .unwrap()
        .into_iter()
        .map(|b| b.name)
        .collect();
    assert_eq!(names, vec!["Alpha", "Disabled", "Zebra"]);

    let mut enabled_names: Vec<String> = db
        .list_enabled_output_bindings(train)
        .unwrap()
        .into_iter()
        .map(|b| b.name)
        .collect();
    // The Elixir query has no order_by for the enabled list.
    enabled_names.sort();
    assert_eq!(enabled_names, vec!["Alpha", "Zebra"]);
}

// =====================
// Display bindings
// =====================

/// Mirrors train.ex display binding functions as exercised by
/// display_controller_test.exs l.137-143 and display_setup_test.exs
/// l.195-227 (create with defaults, update name/format).
#[test]
fn display_binding_crud_roundtrip() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let module = new_i2c_module(&db, &mut op, device, 0x70);
    let train = fx.train("Class 66");

    let created = db
        .create_display_binding(
            OperationId(op),
            train,
            DisplayBindingDraft {
                i2c_module_id: module,
                name: Some("Speed".into()),
                endpoint: "CurrentDrivableActor/Speed".into(),
                format_string: None,
                enabled: None,
            },
        )
        .unwrap();
    op += 1;
    assert_eq!(created.record.train_id, train);
    assert_eq!(created.record.i2c_module_id, module);
    assert_eq!(created.record.endpoint, "CurrentDrivableActor/Speed");
    assert_eq!(created.record.format_string, "{value}");
    assert!(created.record.enabled);
    assert_eq!(created.record.script_id, None);

    let found = db.get_display_binding(created.record.id).unwrap().unwrap();
    assert_eq!(found, created.record);
    assert!(db.get_display_binding(EntityId(999_999)).unwrap().is_none());

    // display_setup_test.exs l.221-227: renaming and re-formatting.
    let updated = db
        .update_display_binding(
            OperationId(op),
            created.record.id,
            DisplayBindingPatch {
                name: Some(Some("Precise speed".into())),
                format_string: Some("{value:.3f}".into()),
                ..Default::default()
            },
        )
        .unwrap();
    op += 1;
    assert_eq!(updated.record.name.as_deref(), Some("Precise speed"));
    assert_eq!(updated.record.format_string, "{value:.3f}");

    let disabled = db
        .update_display_binding(
            OperationId(op),
            created.record.id,
            DisplayBindingPatch {
                enabled: Some(false),
                ..Default::default()
            },
        )
        .unwrap();
    assert!(!disabled.record.enabled);
    assert!(db.list_enabled_display_bindings(train).unwrap().is_empty());
    assert_eq!(db.list_display_bindings(train).unwrap().len(), 1);

    db.delete_display_binding(OperationId(op), created.record.id)
        .unwrap();
    assert!(db.get_display_binding(created.record.id).unwrap().is_none());
    assert!(matches!(
        db.delete_display_binding(OperationId(op), created.record.id),
        Err(StorageError::NotFound)
    ));
}

/// Mirrors display_formatter_test.exs l.42-78: accepted/forbidden value
/// tokens plus the changeset length rules of DisplayBinding.
#[test]
fn display_binding_format_validation() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let module = new_i2c_module(&db, &mut op, device, 0x70);
    let train = fx.train("Class 66");

    let create = |op: u128, format: Option<String>| {
        db.create_display_binding(
            OperationId(op),
            train,
            DisplayBindingDraft {
                i2c_module_id: module,
                name: None,
                endpoint: "Speed".into(),
                format_string: format,
                enabled: None,
            },
        )
    };

    for format in [
        "literal",
        "{value}",
        "{value:.0f}",
        "{value:.10f}",
        "V:{value:.1f}",
    ] {
        // The (train, module) pair is unique, so delete between iterations.
        let created = create(op, Some(format.into())).unwrap();
        op += 1;
        assert_eq!(created.record.format_string, format);
        db.delete_display_binding(OperationId(op), created.record.id)
            .unwrap();
        op += 1;
    }

    for format in [
        "{value:.11f}",
        "{value:.999999999999999999999999f}",
        "{value:.2g}",
        "{value:bad}",
        "{value",
        "{value:.2f",
    ] {
        let error = create(op, Some(format.into())).unwrap_err();
        assert!(
            constraint_detail(error).contains("Use {value}"),
            "format {format:?} should be rejected"
        );
    }

    // Required endpoint/format_string and length limits.
    let error = create(op, Some("   ".into())).unwrap_err();
    assert_eq!(constraint_detail(error), "format_string can't be blank");
    let error = db
        .create_display_binding(
            OperationId(op),
            train,
            DisplayBindingDraft {
                i2c_module_id: module,
                name: None,
                endpoint: "   ".into(),
                format_string: None,
                enabled: None,
            },
        )
        .unwrap_err();
    assert_eq!(constraint_detail(error), "endpoint can't be blank");
    let error = create(op, Some("{".repeat(201))).unwrap_err();
    assert_eq!(
        constraint_detail(error),
        "format_string should be at most 200 characters"
    );
    let error = db
        .create_display_binding(
            OperationId(op),
            train,
            DisplayBindingDraft {
                i2c_module_id: module,
                name: Some("n".repeat(101)),
                endpoint: "Speed".into(),
                format_string: None,
                enabled: None,
            },
        )
        .unwrap_err();
    assert_eq!(
        constraint_detail(error),
        "name should be at most 100 characters"
    );
}

/// Mirrors the unique (train_id, i2c_module_id) index and the
/// foreign_key_constraint declarations of DisplayBinding.changeset/2.
#[test]
fn display_binding_uniqueness_and_foreign_keys() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let module = new_i2c_module(&db, &mut op, device, 0x70);
    let module2 = new_i2c_module(&db, &mut op, device, 0x71);
    let train = fx.train("Class 66");
    let other_train = fx.train("Voyager");

    let draft = |module: EntityId| DisplayBindingDraft {
        i2c_module_id: module,
        name: None,
        endpoint: "Speed".into(),
        format_string: None,
        enabled: None,
    };
    assert!(matches!(
        db.create_display_binding(OperationId(op), EntityId(999_999), draft(module)),
        Err(StorageError::ForeignKey { .. })
    ));
    assert!(matches!(
        db.create_display_binding(OperationId(op), train, draft(EntityId(999_998))),
        Err(StorageError::ForeignKey { .. })
    ));

    db.create_display_binding(OperationId(op), train, draft(module))
        .unwrap();
    op += 1;
    // Same train + module is unique; another train may reuse the module.
    assert!(matches!(
        db.create_display_binding(OperationId(op), train, draft(module)),
        Err(StorageError::Conflict { .. })
    ));
    db.create_display_binding(OperationId(op), other_train, draft(module))
        .unwrap();
    // A second module on the same train is fine.
    db.create_display_binding(OperationId(op), train, draft(module2))
        .unwrap();
}

/// Mirrors the ON DELETE behavior of the display binding foreign keys:
/// CASCADE for train and i2c_module, SET NULL for the reserved script_id.
#[test]
fn display_binding_cascades_and_script_set_null() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let module = new_i2c_module(&db, &mut op, device, 0x70);
    let module2 = new_i2c_module(&db, &mut op, device, 0x71);
    let train = fx.train("Class 66");
    let train2 = fx.train("Voyager");

    let a = db
        .create_display_binding(
            OperationId(op),
            train,
            DisplayBindingDraft {
                i2c_module_id: module,
                name: None,
                endpoint: "Speed".into(),
                format_string: None,
                enabled: None,
            },
        )
        .unwrap();
    let b = db
        .create_display_binding(
            OperationId(op),
            train2,
            DisplayBindingDraft {
                i2c_module_id: module2,
                name: None,
                endpoint: "Speed".into(),
                format_string: None,
                enabled: None,
            },
        )
        .unwrap();

    // Reserved script reference: written by the fixture like an Elixir-era
    // row would carry it; deleting the script sets it NULL without touching
    // the binding.
    let script = fx.script(train, "speed-format");
    fx.exec(
        "UPDATE train_display_bindings SET script_id=?1 WHERE id=?2",
        &[&script.0, &a.record.id.0],
    );
    fx.delete("scripts", script);
    let found = db.get_display_binding(a.record.id).unwrap().unwrap();
    assert_eq!(found.script_id, None);

    // Train delete cascades.
    fx.delete("trains", train);
    assert!(db.get_display_binding(a.record.id).unwrap().is_none());

    // I2C module delete cascades.
    db.delete_i2c_module(OperationId(op), module2).unwrap();
    assert!(db.get_display_binding(b.record.id).unwrap().is_none());
}

/// Mirrors the storage_hardware.rs revision contract: every committed
/// mutation (across all four families) bumps the shared `bindings` topic by
/// exactly one, failures and not-found results bump nothing.
#[test]
fn binding_mutations_share_one_topic_revision() {
    let (_dir, db, fx) = database();
    let mut op = 1u128;
    let device = new_device(&db, &mut op);
    let input = new_input(&db, &mut op, device, 5, InputKind::Analog);
    let button_input = new_input(&db, &mut op, device, 6, InputKind::Button);
    let output = new_output(&db, &mut op, device, 13);
    let module = new_i2c_module(&db, &mut op, device, 0x70);
    let train = fx.train("Class 66");
    let lever_element = fx.element(train, "lever", "Throttle");
    let config = fx.lever_config(lever_element);
    let button_element = fx.element(train, "button", "Horn");

    let lever = db.bind_lever_input(OperationId(op), config, input).unwrap();
    assert_eq!(lever.receipt.metadata.revision, 1);
    op += 1;

    // Failed mutations consume no revision.
    assert!(matches!(
        db.bind_lever_input(OperationId(op), config, EntityId(999_999)),
        Err(StorageError::ForeignKey { .. })
    ));
    assert!(matches!(
        db.unbind_lever_input(OperationId(op), EntityId(999_997)),
        Err(StorageError::NotFound)
    ));

    let button = db
        .create_button_binding(
            OperationId(op),
            button_element,
            button_input,
            ButtonBindingDraft {
                endpoint: Some("Horn.InputValue".into()),
                ..Default::default()
            },
        )
        .unwrap();
    assert_eq!(button.receipt.metadata.revision, 2);
    op += 1;

    let output_binding = db
        .create_output_binding(
            OperationId(op),
            train,
            OutputBindingDraft {
                name: "Speed".into(),
                output_id: output,
                endpoint: "Speed".into(),
                operator: OutputBindingOperator::Gt,
                value_a: Some(1.0),
                output_type: None,
                value_b: None,
                enabled: None,
            },
        )
        .unwrap();
    assert_eq!(output_binding.receipt.metadata.revision, 3);
    op += 1;

    let display = db
        .create_display_binding(
            OperationId(op),
            train,
            DisplayBindingDraft {
                i2c_module_id: module,
                name: None,
                endpoint: "Speed".into(),
                format_string: None,
                enabled: None,
            },
        )
        .unwrap();
    assert_eq!(display.receipt.metadata.revision, 4);
    assert_eq!(display.receipt.operation_id, OperationId(op));
    op += 1;

    let unbound = db.unbind_lever_input(OperationId(op), config).unwrap();
    assert_eq!(unbound.receipt.metadata.revision, 5);
}

// Ecto validate_length(:name, max: 100) counts graphemes (String.length/1),
// like core/train/display.rs — a combining-mark name of two codepoints per
// character must fit 100 (parity audit P2-25).
#[test]
fn display_binding_name_length_counts_graphemes() {
    let (_dir, db, fx) = database();
    let mut op = 987_000u128;
    let device = new_device(&db, &mut op);
    let module = new_i2c_module(&db, &mut op, device, 0x70);
    let train = fx.train("Class 66");
    let combining: String = "e\u{301}".repeat(100); // 200 codepoints, 100 graphemes
    let created = db
        .create_display_binding(
            OperationId(op),
            train,
            DisplayBindingDraft {
                i2c_module_id: module,
                name: Some(combining),
                endpoint: "CurrentDrivableActor/Speed".into(),
                format_string: None,
                enabled: None,
            },
        )
        .unwrap();
    assert_eq!(
        created
            .record
            .name
            .as_deref()
            .map(|name| name.chars().count()),
        Some(200)
    );

    let too_long: String = "e\u{301}".repeat(100) + "x"; // 101 graphemes
    let error = db
        .create_display_binding(
            OperationId(op + 1),
            train,
            DisplayBindingDraft {
                i2c_module_id: module,
                name: Some(too_long),
                endpoint: "CurrentDrivableActor/Speed".into(),
                format_string: None,
                enabled: None,
            },
        )
        .unwrap_err();
    assert_eq!(
        constraint_detail(error),
        "name should be at most 100 characters"
    );
}
