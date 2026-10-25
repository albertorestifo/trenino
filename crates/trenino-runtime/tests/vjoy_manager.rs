//! vJoy manager + store integration tests against a disposable tempfile
//! database, a loopback resource arbiter and the event-logging fake adapter.
//!
//! Mirrored Elixir tests:
//! - store/CRUD: `test/trenino/virtual_joystick_test.exs`
//!   ("get_configuration creates the singleton configuration with its
//!   defaults", "put_mapping maps a calibrated analog input to an axis…",
//!   "maps a button input to a button target", "rejects an analog input
//!   mapped to a button", "rejects a button input mapped to an axis",
//!   "rejects device indexes other than 1" — superseded by the explicit
//!   1..=16 selection policy, "rejects button targets outside 1 through 32",
//!   "updates an existing input mapping rather than creating a second
//!   mapping", "enforces one mapping per input",
//!   "enforces a unique axis target for device 1",
//!   "enforces a unique button target for device 1",
//!   "rejects a virtual axis mapping for an API-bound input unless
//!   replacement removes every enabled lever binding", "rejects a virtual
//!   button mapping for an API-bound input unless replacement removes
//!   enabled button bindings", "keeps simulator bindings when a replacement
//!   mapping is invalid")
//! - lifecycle: `test/trenino/virtual_joystick/manager_test.exs`
//!   ("startup reconciliation covers unsupported and every requested/device
//!   pair", "enable … persists only after bridge ready", "failure after
//!   creation offers cleanup without persisting enabled", "disable resets and
//!   shuts down before deletion and persists only on confirmed removal",
//!   "remove leftover retries deletion and retry starts setup explicitly",
//!   "terminate resets and shuts down enabled bridge without deleting device")

use std::path::Path;
use std::sync::{Arc, Mutex};

use rusqlite::Connection;
use tempfile::tempdir;
use trenino_core::{ConfigId, EntityId, OperationId};
use trenino_runtime::resource::{LeaseKind, ResourceArbiter, ResourceConsumers};
use trenino_runtime::storage::{Database, DeviceDraft, InputDraft, InputKind, StorageError};
use trenino_runtime::vjoy::{
    neutral_axis_value, AdapterEvent, DeviceDescriptor, FakeDevice, FakeVjoyAdapter, MappingDraft,
    Target, VjoyAxis, VjoyConfiguration, VjoyDeviceStatus, VjoyError, VjoyManager, VjoyStatus,
    REQUIRED_DESCRIPTOR,
};

/// Loopback arbiter consumers: every callback succeeds so lease acquire/release
/// behaves as in production wiring.
struct NoopConsumers;

impl ResourceConsumers for NoopConsumers {
    fn suspend_actuation(&self, _port: &str) -> Result<(), String> {
        Ok(())
    }
    fn cancel_calibration(&self, _port: &str) -> Result<(), String> {
        Ok(())
    }
    fn source_lost(&self, _port: &str, _generation: u64) -> Result<(), String> {
        Ok(())
    }
    fn resume_after_fresh_sample(&self, _port: &str) -> Result<(), String> {
        Ok(())
    }
}

fn database() -> (tempfile::TempDir, Database) {
    let dir = tempdir().unwrap();
    let db = Database::open_full(dir.path().join("vjoy.db")).unwrap();
    db.allocate_epoch().unwrap();
    (dir, db)
}

fn arbiter() -> Arc<ResourceArbiter> {
    Arc::new(ResourceArbiter::new(Arc::new(NoopConsumers)))
}

fn analog_input(db: &Database, name: &str, config_id: u32, pin: i32) -> EntityId {
    let device = db
        .create_device(
            OperationId(1),
            DeviceDraft {
                name: name.to_owned(),
                description: None,
                config_id: Some(ConfigId::new(config_id).unwrap()),
            },
        )
        .unwrap();
    db.create_input(
        OperationId(2),
        device.record.id,
        InputDraft {
            pin,
            kind: InputKind::Analog,
            sensitivity: Some(10),
            debounce: None,
            name: Some(name.into()),
            matrix_id: None,
        },
    )
    .unwrap()
    .record
    .id
}

fn button_input(db: &Database, name: &str, config_id: u32, pin: i32) -> EntityId {
    let device = db
        .create_device(
            OperationId(3),
            DeviceDraft {
                name: name.to_owned(),
                description: None,
                config_id: Some(ConfigId::new(config_id).unwrap()),
            },
        )
        .unwrap();
    db.create_input(
        OperationId(4),
        device.record.id,
        InputDraft {
            pin,
            kind: InputKind::Button,
            sensitivity: None,
            debounce: Some(50),
            name: Some(name.into()),
            matrix_id: None,
        },
    )
    .unwrap()
    .record
    .id
}

type SharedFake = Arc<Mutex<FakeVjoyAdapter>>;

fn fake() -> SharedFake {
    Arc::new(Mutex::new(FakeVjoyAdapter::new()))
}

fn manager(
    db: &Database,
    arbiter: &Arc<ResourceArbiter>,
    adapter: SharedFake,
) -> VjoyManager<SharedFake> {
    VjoyManager::new(db.clone(), arbiter.clone(), adapter)
}

fn events(fake: &SharedFake) -> Vec<AdapterEvent> {
    fake.lock().unwrap().events().to_vec()
}

fn clear_events(fake: &SharedFake) {
    fake.lock().unwrap().clear_events()
}

fn count(fake: &SharedFake, event: &AdapterEvent) -> usize {
    events(fake).iter().filter(|e| *e == event).count()
}

fn acquired(fake: &SharedFake) -> Vec<u8> {
    fake.lock().unwrap().acquired().iter().copied().collect()
}

fn missing_device() -> FakeDevice {
    FakeDevice {
        status: VjoyDeviceStatus::Missing,
        ..FakeDevice::default()
    }
}

fn axis_draft(axis: VjoyAxis) -> MappingDraft {
    MappingDraft {
        device_index: 1,
        target: Target::Axis(axis),
        inverted: false,
    }
}

fn button_draft(button: u8) -> MappingDraft {
    MappingDraft {
        device_index: 1,
        target: Target::Button(button),
        inverted: false,
    }
}

// ---------------------------------------------------------------- store ----

/// Mirrors "creates the singleton configuration with its defaults".
#[test]
fn configuration_singleton_created_with_defaults() {
    let (_dir, db) = database();
    assert_eq!(
        db.vjoy_configuration().unwrap(),
        VjoyConfiguration {
            enabled: false,
            device_index: 1,
        }
    );
    // Second read is stable and creates no duplicate row.
    assert_eq!(db.vjoy_configuration().unwrap().device_index, 1);
}

/// Acceptance: selection persistence round-trip. The default seeds from the
/// singleton configuration's device index (existing device-1 rows migrate
/// without adopting other devices); explicit sets persist sorted and deduped.
#[test]
fn selection_round_trips_and_validates() {
    let (_dir, db) = database();
    assert_eq!(db.vjoy_selected_devices().unwrap(), vec![1]);

    let before = db.vjoy_topic_metadata().unwrap().revision;
    let mutation = db
        .vjoy_set_selected_devices(OperationId(10), &[3, 1, 3, 16])
        .unwrap();
    assert_eq!(mutation.record, vec![1, 3, 16]);
    assert_eq!(db.vjoy_selected_devices().unwrap(), vec![1, 3, 16]);
    let after = db.vjoy_topic_metadata().unwrap().revision;
    assert_eq!(after, before + 1, "one revision per committed selection");

    match db.vjoy_set_selected_devices(OperationId(11), &[]) {
        Err(StorageError::Constraint { detail }) => {
            assert_eq!(detail, "selected device set must not be empty")
        }
        other => panic!("expected empty-set rejection, got {other:?}"),
    }
    match db.vjoy_set_selected_devices(OperationId(12), &[17]) {
        Err(StorageError::Constraint { detail }) => {
            assert_eq!(detail, "device_index must be between 1 and 16")
        }
        other => panic!("expected range rejection, got {other:?}"),
    }
    // Invalid attempts changed neither content nor revision.
    assert_eq!(db.vjoy_selected_devices().unwrap(), vec![1, 3, 16]);
    assert_eq!(db.vjoy_topic_metadata().unwrap().revision, after);
}

/// Mirrors "maps a calibrated analog input to an axis…", "maps a button input
/// to a button target" and "lists mappings with their inputs preloaded and
/// deletes a mapping" (ordering: device, target type, axis, button).
#[test]
fn mapping_crud_lists_ordered_and_joins_input() {
    let (_dir, db) = database();
    let device = db
        .create_device(
            OperationId(20),
            DeviceDraft {
                name: "Panel".into(),
                description: None,
                config_id: Some(ConfigId::new(120).unwrap()),
            },
        )
        .unwrap();
    let analog = db
        .create_input(
            OperationId(21),
            device.record.id,
            InputDraft {
                pin: 5,
                kind: InputKind::Analog,
                sensitivity: Some(10),
                debounce: None,
                name: Some("Lever".into()),
                matrix_id: None,
            },
        )
        .unwrap()
        .record
        .id;
    let button = db
        .create_input(
            OperationId(22),
            device.record.id,
            InputDraft {
                pin: 6,
                kind: InputKind::Button,
                sensitivity: None,
                debounce: Some(50),
                name: Some("Horn".into()),
                matrix_id: None,
            },
        )
        .unwrap()
        .record
        .id;

    let axis = db
        .vjoy_put_mapping(
            OperationId(23),
            analog,
            axis_draft(VjoyAxis::Slider1),
            false,
        )
        .unwrap();
    assert_eq!(axis.record.device_index, 1);
    assert_eq!(axis.record.target, Target::Axis(VjoyAxis::Slider1));
    assert!(!axis.record.inverted);
    assert_eq!(axis.record.input_id, analog);
    assert_eq!(axis.record.input_kind, InputKind::Analog);
    assert_eq!(axis.record.input_pin, Some(5));
    assert_eq!(axis.record.input_device, Some(device.record.id));
    assert_eq!(axis.record.input_name.as_deref(), Some("Lever"));

    let button_mapping = db
        .vjoy_put_mapping(OperationId(24), button, button_draft(32), false)
        .unwrap();
    assert_eq!(button_mapping.record.target, Target::Button(32));
    assert_eq!(button_mapping.record.input_kind, InputKind::Button);

    let analog2 = analog_input(&db, "Throttle", 121, 6);
    let other_device_axis = MappingDraft {
        device_index: 2,
        target: Target::Axis(VjoyAxis::X),
        inverted: true,
    };
    db.vjoy_put_mapping(OperationId(25), analog2, other_device_axis, false)
        .unwrap();

    let listed = db.vjoy_list_mappings().unwrap();
    let order: Vec<(u8, u8, Option<VjoyAxis>)> = listed
        .iter()
        .map(|m| {
            (
                m.device_index,
                match m.target {
                    Target::Axis(_) => 0,
                    Target::Button(_) => 1,
                },
                match m.target {
                    Target::Axis(axis) => Some(axis),
                    Target::Button(_) => None,
                },
            )
        })
        .collect();
    // device 1 axis < device 1 button < device 2 axis (Elixir list order).
    assert_eq!(
        order,
        vec![
            (1, 0, Some(VjoyAxis::Slider1)),
            (1, 1, None),
            (2, 0, Some(VjoyAxis::X))
        ]
    );
    assert!(listed.iter().any(|m| m.inverted));

    let fetched = db.vjoy_get_mapping(axis.record.id).unwrap().unwrap();
    assert_eq!(fetched.input_id, analog);

    let deleted = db
        .vjoy_delete_mapping(OperationId(26), axis.record.id)
        .unwrap();
    assert_eq!(deleted.record.id, axis.record.id);
    assert!(db.vjoy_get_mapping(axis.record.id).unwrap().is_none());
    assert!(matches!(
        db.vjoy_delete_mapping(OperationId(27), axis.record.id),
        Err(StorageError::NotFound)
    ));
}

/// Mirrors "updates an existing input mapping rather than creating a second
/// mapping"; the input is always the call's argument, never a draft field.
#[test]
fn mapping_updates_in_place_per_input() {
    let (_dir, db) = database();
    let analog = analog_input(&db, "Lever", 120, 5);

    let first = db
        .vjoy_put_mapping(OperationId(30), analog, axis_draft(VjoyAxis::X), false)
        .unwrap();
    let inverted = MappingDraft {
        inverted: true,
        ..axis_draft(VjoyAxis::Y)
    };
    let second = db
        .vjoy_put_mapping(OperationId(31), analog, inverted, false)
        .unwrap();
    assert_eq!(first.record.id, second.record.id);
    assert_eq!(second.record.target, Target::Axis(VjoyAxis::Y));
    assert!(second.record.inverted);
    let all = db.vjoy_list_mappings().unwrap();
    assert_eq!(all.len(), 1);
    assert_eq!(all[0].input_id, analog);
}

/// Mirrors "rejects an analog input mapped to a button" and "rejects a button
/// input mapped to an axis".
#[test]
fn mapping_kind_mismatch_rejected() {
    let (_dir, db) = database();
    let analog = analog_input(&db, "Lever", 120, 5);
    let button = button_input(&db, "Horn", 121, 6);
    match db.vjoy_put_mapping(OperationId(40), analog, button_draft(1), false) {
        Err(StorageError::Constraint { detail }) => {
            assert_eq!(detail, "target_type must target an axis")
        }
        other => panic!("expected analog rejection, got {other:?}"),
    }
    match db.vjoy_put_mapping(OperationId(41), button, axis_draft(VjoyAxis::X), false) {
        Err(StorageError::Constraint { detail }) => {
            assert_eq!(detail, "target_type must target a button")
        }
        other => panic!("expected button rejection, got {other:?}"),
    }
    assert!(db.vjoy_list_mappings().unwrap().is_empty());
}

/// Mirrors "rejects device indexes other than 1" (superseded by explicit
/// 1..=16 selection) and "rejects button targets outside 1 through 32".
#[test]
fn mapping_domains_rejected() {
    let (_dir, db) = database();
    let analog = analog_input(&db, "Lever", 120, 5);
    let button = button_input(&db, "Horn", 121, 6);
    let out_of_range = MappingDraft {
        device_index: 17,
        ..axis_draft(VjoyAxis::X)
    };
    match db.vjoy_put_mapping(OperationId(50), analog, out_of_range, false) {
        Err(StorageError::Constraint { detail }) => {
            assert_eq!(detail, "device_index must be between 1 and 16")
        }
        other => panic!("expected device index rejection, got {other:?}"),
    }
    match db.vjoy_put_mapping(OperationId(51), button, button_draft(33), false) {
        Err(StorageError::Constraint { detail }) => {
            assert_eq!(detail, "button must be between 1 and 32")
        }
        other => panic!("expected button rejection, got {other:?}"),
    }
}

/// Mirrors "enforces a unique axis target for device 1" and "enforces a unique
/// button target for device 1" — per device, per the schema partial indexes;
/// the same target on another device is a different destination, and moving an
/// input to a new target frees the old one.
#[test]
fn mapping_target_uniqueness_per_device() {
    let (_dir, db) = database();
    let analog = analog_input(&db, "Lever", 120, 5);
    let button = button_input(&db, "Horn", 121, 6);
    let analog2 = analog_input(&db, "Second", 122, 5);
    let button2 = button_input(&db, "Second", 123, 6);

    db.vjoy_put_mapping(OperationId(60), analog, axis_draft(VjoyAxis::Rx), false)
        .unwrap();
    match db.vjoy_put_mapping(OperationId(61), analog2, axis_draft(VjoyAxis::Rx), false) {
        Err(StorageError::Conflict { detail }) => {
            assert_eq!(detail, "axis has already been taken")
        }
        other => panic!("expected axis conflict, got {other:?}"),
    }
    db.vjoy_put_mapping(OperationId(62), button, button_draft(1), false)
        .unwrap();
    match db.vjoy_put_mapping(OperationId(63), button2, button_draft(1), false) {
        Err(StorageError::Conflict { detail }) => {
            assert_eq!(detail, "button has already been taken")
        }
        other => panic!("expected button conflict, got {other:?}"),
    }
    // The same target on another device is allowed.
    let other_device = MappingDraft {
        device_index: 2,
        ..axis_draft(VjoyAxis::Rx)
    };
    db.vjoy_put_mapping(OperationId(64), analog2, other_device, false)
        .unwrap();
    // Retargeting the first input frees its previous axis.
    db.vjoy_put_mapping(OperationId(65), analog, axis_draft(VjoyAxis::Y), false)
        .unwrap();
    db.vjoy_put_mapping(OperationId(66), analog, axis_draft(VjoyAxis::Rx), false)
        .unwrap();
}

/// Mirrors the context's `{:error, :not_found}` for a missing input.
#[test]
fn mapping_missing_input_rejected() {
    let (_dir, db) = database();
    match db.vjoy_put_mapping(
        OperationId(70),
        EntityId(999),
        axis_draft(VjoyAxis::X),
        false,
    ) {
        Err(StorageError::NotFound) => {}
        other => panic!("expected not found, got {other:?}"),
    }
}

/// Seeds enabled simulator bindings through a side connection, like the
/// Elixir fixtures that insert `LeverInputBinding`/`ButtonInputBinding` rows
/// directly (the bindings repository track owns the typed API).
fn seed_enabled_binding(path: &Path, sql: &str) {
    let conn = Connection::open(path).unwrap();
    conn.busy_timeout(std::time::Duration::from_secs(5))
        .unwrap();
    conn.execute_batch(sql).unwrap();
}

fn binding_count(path: &Path, table: &str, input: EntityId) -> i64 {
    let conn = Connection::open(path).unwrap();
    conn.query_row(
        &format!("SELECT count(*) FROM {table} WHERE input_id=?1 AND enabled=1"),
        [input.0],
        |row| row.get(0),
    )
    .unwrap()
}

/// Mirrors "rejects a virtual axis mapping for an API-bound input unless
/// replacement removes every enabled lever binding" and "keeps simulator
/// bindings when a replacement mapping is invalid": the mapping refuses with
/// `destination_conflict`, an invalid replacement keeps the bindings, and a
/// valid replacement deletes exactly this input's enabled bindings in the
/// same transaction.
#[test]
fn mapping_destination_conflict_with_lever_binding_and_replacement() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("vjoy.db");
    let db = Database::open_full(&path).unwrap();
    db.allocate_epoch().unwrap();
    let input = analog_input(&db, "Lever", 130, 5);
    let unrelated = analog_input(&db, "Other", 131, 5);
    let now = "2026-10-25T00:00:00Z";
    seed_enabled_binding(
        &path,
        &format!(
            "INSERT INTO trains(id,name,inserted_at,updated_at) VALUES(900,'T','{now}','{now}');\
             INSERT INTO train_elements(id,train_id,type,name,inserted_at,updated_at) VALUES\
               (900,900,'lever','First','{now}','{now}'),\
               (901,900,'lever','Unrelated','{now}','{now}');\
             INSERT INTO train_lever_configs(id,element_id,min_endpoint,max_endpoint,value_endpoint,inserted_at,updated_at) VALUES\
               (900,900,'a.Min','a.Max','a.Value','{now}','{now}'),\
               (901,901,'b.Min','b.Max','b.Value','{now}','{now}');\
             INSERT INTO lever_input_bindings(id,lever_config_id,input_id,enabled,inserted_at,updated_at) VALUES\
               (900,900,{},1,'{now}','{now}'),\
               (901,901,{},1,'{now}','{now}');",
            input.0, unrelated.0
        ),
    );

    match db.vjoy_put_mapping(OperationId(100), input, axis_draft(VjoyAxis::X), false) {
        Err(StorageError::Conflict { detail }) => assert_eq!(detail, "destination_conflict"),
        other => panic!("expected destination conflict, got {other:?}"),
    }
    match db.vjoy_put_mapping(OperationId(101), input, button_draft(1), true) {
        Err(StorageError::Constraint { detail }) => {
            assert_eq!(detail, "target_type must target an axis")
        }
        other => panic!("expected kind rejection, got {other:?}"),
    }
    assert_eq!(
        binding_count(&path, "lever_input_bindings", input),
        1,
        "invalid replacement keeps the enabled bindings"
    );

    db.vjoy_put_mapping(OperationId(102), input, axis_draft(VjoyAxis::X), true)
        .unwrap();
    assert_eq!(binding_count(&path, "lever_input_bindings", input), 0);
    assert_eq!(binding_count(&path, "lever_input_bindings", unrelated), 1);
}

/// Mirrors "rejects a virtual button mapping for an API-bound input unless
/// replacement removes enabled button bindings".
#[test]
fn mapping_destination_conflict_with_button_binding_and_replacement() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("vjoy.db");
    let db = Database::open_full(&path).unwrap();
    db.allocate_epoch().unwrap();
    let input = button_input(&db, "Horn", 132, 6);
    let unrelated = button_input(&db, "Bell", 133, 7);
    let now = "2026-10-25T00:00:00Z";
    seed_enabled_binding(
        &path,
        &format!(
            "INSERT INTO trains(id,name,inserted_at,updated_at) VALUES(901,'B','{now}','{now}');\
             INSERT INTO train_elements(id,train_id,type,name,inserted_at,updated_at) VALUES\
               (902,901,'button','Horn','{now}','{now}'),\
               (903,901,'button','Bell','{now}','{now}');\
             INSERT INTO button_input_bindings(id,input_id,element_id,endpoint,enabled,inserted_at,updated_at) VALUES\
               (900,{},902,'Horn.InputValue',1,'{now}','{now}'),\
               (901,{},903,'Bell.InputValue',1,'{now}','{now}');",
            input.0, unrelated.0
        ),
    );

    match db.vjoy_put_mapping(OperationId(110), input, button_draft(1), false) {
        Err(StorageError::Conflict { detail }) => assert_eq!(detail, "destination_conflict"),
        other => panic!("expected destination conflict, got {other:?}"),
    }
    db.vjoy_put_mapping(OperationId(111), input, button_draft(1), true)
        .unwrap();
    assert_eq!(binding_count(&path, "button_input_bindings", input), 0);
    assert_eq!(binding_count(&path, "button_input_bindings", unrelated), 1);
}

/// Acceptance: cascade when a bound input is deleted (schema
/// `ON DELETE CASCADE` on `virtual_joystick_mappings.input_id`).
#[test]
fn mapping_cascades_when_input_deleted() {
    let (_dir, db) = database();
    let device = db
        .create_device(
            OperationId(80),
            DeviceDraft {
                name: "Panel".into(),
                description: None,
                config_id: Some(ConfigId::new(120).unwrap()),
            },
        )
        .unwrap();
    let analog = db
        .create_input(
            OperationId(81),
            device.record.id,
            InputDraft {
                pin: 5,
                kind: InputKind::Analog,
                sensitivity: Some(10),
                debounce: None,
                name: None,
                matrix_id: None,
            },
        )
        .unwrap()
        .record
        .id;
    let button = db
        .create_input(
            OperationId(82),
            device.record.id,
            InputDraft {
                pin: 6,
                kind: InputKind::Button,
                sensitivity: None,
                debounce: Some(50),
                name: None,
                matrix_id: None,
            },
        )
        .unwrap()
        .record
        .id;
    db.vjoy_put_mapping(OperationId(83), analog, axis_draft(VjoyAxis::Z), false)
        .unwrap();
    db.vjoy_put_mapping(OperationId(84), button, button_draft(7), false)
        .unwrap();
    assert_eq!(db.vjoy_list_mappings().unwrap().len(), 2);

    db.delete_input(OperationId(85), analog).unwrap();
    let remaining = db.vjoy_list_mappings().unwrap();
    assert_eq!(remaining.len(), 1);
    assert_eq!(remaining[0].input_id, button);
}

/// The neutral center uses the widened midpoint (plan correction over the
/// legacy rounded midpoint: 16383, not 16384).
#[test]
fn neutral_axis_value_is_the_widened_midpoint() {
    assert_eq!(neutral_axis_value(0, 32767), 16383);
    assert_eq!(neutral_axis_value(-32768, 32767), -1);
    assert_eq!(neutral_axis_value(i32::MIN, i32::MAX), -1);
    assert_eq!(neutral_axis_value(5, 5), 5);
}

// ------------------------------------------------------------- manager ----

/// Mirrors the `unsupported` row of "startup reconciliation covers unsupported
/// and every requested/device pair": no adapter call beyond `supported`.
#[test]
fn unsupported_platform_never_touches_the_adapter() {
    let (_dir, db) = database();
    let arbiter = arbiter();
    let fake = fake();
    fake.lock().unwrap().set_supported(false);
    let manager = manager(&db, &arbiter, fake.clone());
    assert_eq!(manager.status(), VjoyStatus::Unsupported);
    assert!(events(&fake).is_empty());
    assert!(matches!(manager.enable(), Err(VjoyError::Unsupported)));
    assert!(events(&fake).is_empty());
}

/// Mirrors the not-requested rows of the startup reconciliation table: all
/// missing → off; free → needs_cleanup (leftover); busy → error; driver
/// missing → error.
#[test]
fn startup_reconciliation_not_requested() {
    let (_dir, db) = database();
    let arbiter = arbiter();

    let missing = fake();
    missing.lock().unwrap().set_device(1, missing_device());
    let off_manager = manager(&db, &arbiter, missing);
    assert_eq!(off_manager.status(), VjoyStatus::Off);

    let leftover = fake();
    let leftover_manager = manager(&db, &arbiter, leftover);
    assert_eq!(leftover_manager.status(), VjoyStatus::NeedsCleanup);

    let busy = fake();
    busy.lock().unwrap().set_device(
        1,
        FakeDevice {
            status: VjoyDeviceStatus::Busy,
            ..FakeDevice::default()
        },
    );
    let busy_manager = manager(&db, &arbiter, busy);
    assert_eq!(busy_manager.status(), VjoyStatus::Error);
    assert!(matches!(
        busy_manager.status_details().1,
        Some(VjoyError::DeviceBusy(1))
    ));

    let broken_driver = fake();
    broken_driver
        .lock()
        .unwrap()
        .set_driver_available(false, "vJoyInterface.dll not found");
    let driver_manager = manager(&db, &arbiter, broken_driver);
    assert_eq!(driver_manager.status(), VjoyStatus::Error);
    assert!(matches!(
        driver_manager.status_details().1,
        Some(VjoyError::DriverUnavailable(_))
    ));
}

/// Acceptance: acquire-only-selected invariant. With selection {2,5} the
/// manager acquires exactly those devices in ascending order, neutralizes
/// each after acquisition, and persists `enabled` only once all succeeded
/// (mirrors "enable … persists only after bridge ready").
#[test]
fn enable_acquires_only_selected_devices_and_persists_after_success() {
    let (_dir, db) = database();
    let arbiter = arbiter();
    let fake = fake();
    let manager = manager(&db, &arbiter, fake.clone());
    manager.set_selection(OperationId(90), &[5, 2]).unwrap();
    assert_eq!(manager.selection(), vec![2, 5]);
    clear_events(&fake);

    manager.enable().unwrap();
    assert_eq!(manager.status(), VjoyStatus::Active);
    assert_eq!(acquired(&fake), vec![2, 5]);
    for unselected in [1u8, 3, 4, 6, 16] {
        assert_eq!(count(&fake, &AdapterEvent::Acquire(unselected)), 0);
    }
    assert_eq!(
        events(&fake),
        vec![
            AdapterEvent::DriverCheck,
            AdapterEvent::Status(2),
            AdapterEvent::Descriptor(2),
            AdapterEvent::Acquire(2),
            AdapterEvent::Neutralize {
                device: 2,
                center: 16383,
            },
            AdapterEvent::Status(5),
            AdapterEvent::Descriptor(5),
            AdapterEvent::Acquire(5),
            AdapterEvent::Neutralize {
                device: 5,
                center: 16383,
            },
        ]
    );
    assert!(db.vjoy_configuration().unwrap().enabled);
}

/// Acceptance: failed-acquire quarantine + retry. A failed acquire quarantines
/// its device, rolls every earlier acquisition back (neutralized, then
/// released), refuses further enables without adapter acquisition attempts,
/// and an explicit retry recovers.
#[test]
fn failed_acquire_quarantines_rolls_back_and_retry_recovers() {
    let (_dir, db) = database();
    let arbiter = arbiter();
    let fake = fake();
    let manager = manager(&db, &arbiter, fake.clone());
    manager.set_selection(OperationId(91), &[1, 3]).unwrap();
    fake.lock().unwrap().set_device(
        3,
        FakeDevice {
            acquire_error: Some("driver refused".into()),
            ..FakeDevice::default()
        },
    );
    clear_events(&fake);

    let error = manager.enable().unwrap_err();
    assert!(matches!(
        &error,
        VjoyError::AcquireFailed(3, detail) if detail == "driver refused"
    ));
    assert_eq!(manager.status(), VjoyStatus::Error);
    assert!(acquired(&fake).is_empty());
    // Device 1 was acquired then rolled back: neutralized before release.
    let log = events(&fake);
    let acquire_one = log
        .iter()
        .position(|e| *e == AdapterEvent::Acquire(1))
        .unwrap();
    let neutralize_one = log
        .iter()
        .position(|e| matches!(e, AdapterEvent::Neutralize { device: 1, .. }))
        .unwrap();
    let release_one = log
        .iter()
        .position(|e| *e == AdapterEvent::Release(1))
        .unwrap();
    assert!(acquire_one < neutralize_one);
    assert!(neutralize_one < release_one);
    assert!(!db.vjoy_configuration().unwrap().enabled);

    // Quarantine blocks re-enable without touching the adapter.
    let acquires_before = count(&fake, &AdapterEvent::Acquire(1));
    let quarantined = manager.quarantined();
    assert!(matches!(
        quarantined.get(&3),
        Some(VjoyError::AcquireFailed(3, _))
    ));
    assert!(matches!(
        manager.enable().unwrap_err(),
        VjoyError::Quarantined(3, _)
    ));
    assert_eq!(count(&fake, &AdapterEvent::Acquire(1)), acquires_before);
    assert_eq!(manager.status(), VjoyStatus::Error);

    // Repair the scripted failure and retry explicitly.
    fake.lock().unwrap().set_device(3, FakeDevice::default());
    manager.retry().unwrap();
    assert_eq!(manager.status(), VjoyStatus::Active);
    assert_eq!(acquired(&fake), vec![1, 3]);
    assert!(manager.quarantined().is_empty());
    assert!(db.vjoy_configuration().unwrap().enabled);
}

/// Mirrors "failure after creation offers cleanup without persisting enabled"
/// for the descriptor gate: an incompatible device refuses before acquisition
/// and nothing is owned.
#[test]
fn incompatible_descriptor_refused_before_acquisition() {
    let (_dir, db) = database();
    let arbiter = arbiter();
    let fake = fake();
    fake.lock().unwrap().set_device(
        1,
        FakeDevice {
            descriptor: DeviceDescriptor {
                axes: REQUIRED_DESCRIPTOR.axes,
                buttons: REQUIRED_DESCRIPTOR.buttons,
                povs: 1,
                force_feedback: false,
            },
            ..FakeDevice::default()
        },
    );
    let manager = manager(&db, &arbiter, fake.clone());
    let error = manager.enable().unwrap_err();
    assert!(matches!(&error, VjoyError::IncompatibleDevice(1, _)));
    assert_eq!(manager.status(), VjoyStatus::Error);
    assert!(acquired(&fake).is_empty());
    assert!(!db.vjoy_configuration().unwrap().enabled);
}

/// Acceptance: neutralize on release. Disable neutralizes every acquired
/// device (widened midpoint) before releasing it and persists `enabled=false`
/// only after the releases (mirrors "disable resets and shuts down before
/// deletion and persists only on confirmed removal").
#[test]
fn disable_neutralizes_before_release_and_persists_off() {
    let (_dir, db) = database();
    let arbiter = arbiter();
    let fake = fake();
    let manager = manager(&db, &arbiter, fake.clone());
    manager.enable().unwrap();
    assert_eq!(manager.status(), VjoyStatus::Active);
    clear_events(&fake);

    manager.disable().unwrap();
    assert_eq!(manager.status(), VjoyStatus::Off);
    assert!(acquired(&fake).is_empty());
    assert_eq!(
        events(&fake),
        vec![
            AdapterEvent::Neutralize {
                device: 1,
                center: 16383,
            },
            AdapterEvent::Release(1),
        ]
    );
    assert!(!db.vjoy_configuration().unwrap().enabled);
    // Idempotent off.
    manager.disable().unwrap();
    assert_eq!(manager.status(), VjoyStatus::Off);
}

/// Mirrors "remove leftover retries deletion and retry starts setup
/// explicitly" for the missing-device path: a selected but unconfigured device
/// lands in needs_setup without persisting enable, and retry re-attempts.
#[test]
fn missing_device_reaches_needs_setup_and_retry_recover() {
    let (_dir, db) = database();
    let arbiter = arbiter();
    let fake = fake();
    fake.lock().unwrap().set_device(1, missing_device());
    let manager = manager(&db, &arbiter, fake.clone());
    let error = manager.enable().unwrap_err();
    assert!(matches!(error, VjoyError::DeviceMissing(1)));
    assert_eq!(manager.status(), VjoyStatus::NeedsSetup);
    assert!(!db.vjoy_configuration().unwrap().enabled);
    assert!(matches!(manager.retry(), Err(VjoyError::DeviceMissing(1))));

    fake.lock().unwrap().set_device(1, FakeDevice::default());
    manager.retry().unwrap();
    assert_eq!(manager.status(), VjoyStatus::Active);
    assert!(db.vjoy_configuration().unwrap().enabled);
}

/// Acceptance: arbiter lease respected. While the shared arbiter holds a
/// calibration lease the manager refuses activation without touching any
/// device; after release the same enable succeeds.
#[test]
fn arbiter_lease_respected_during_enable() {
    let (_dir, db) = database();
    let arbiter = arbiter();
    let fake = fake();
    let manager = manager(&db, &arbiter, fake.clone());
    clear_events(&fake);

    let token = arbiter
        .acquire(LeaseKind::Calibration {
            port: "COM3".into(),
            generation: 1,
        })
        .unwrap();
    assert!(arbiter.is_suspended());
    assert!(matches!(
        manager.enable().unwrap_err(),
        VjoyError::ArbiterBusy
    ));
    // The refused enable is not a transition: the reconciled status stands
    // (the default fake reports the selected device as Free, so startup
    // reconciliation put the manager in needs_cleanup).
    assert_eq!(manager.status(), VjoyStatus::NeedsCleanup);
    assert!(events(&fake).is_empty());
    assert!(!db.vjoy_configuration().unwrap().enabled);

    arbiter.release(token).unwrap();
    manager.enable().unwrap();
    assert_eq!(manager.status(), VjoyStatus::Active);
    assert_eq!(acquired(&fake), vec![1]);
}

/// Mirrors "terminate resets and shuts down enabled bridge without deleting
/// device": dropping the manager neutralizes and releases what it owns, in
/// reverse acquisition order.
#[test]
fn drop_neutralizes_and_releases_owned_devices() {
    let (_dir, db) = database();
    let arbiter = arbiter();
    let fake = fake();
    let manager = manager(&db, &arbiter, fake.clone());
    manager.set_selection(OperationId(92), &[1, 2]).unwrap();
    manager.enable().unwrap();
    clear_events(&fake);

    drop(manager);
    assert_eq!(
        events(&fake),
        vec![
            AdapterEvent::Neutralize {
                device: 2,
                center: 16383,
            },
            AdapterEvent::Release(2),
            AdapterEvent::Neutralize {
                device: 1,
                center: 16383,
            },
            AdapterEvent::Release(1),
        ]
    );
    assert!(acquired(&fake).is_empty());
}

/// Startup with a persisted `enabled` re-acquires automatically (mirrors the
/// `{true, true, :compatible, :active}` reconciliation row); the persisted
/// flag survives a failed reconciliation.
#[test]
fn startup_with_persisted_enable_reacquires_or_records_failure() {
    let (dir, db) = database();
    let arbiter = arbiter();
    {
        let fake = fake();
        let manager = manager(&db, &arbiter, fake);
        manager.enable().unwrap();
    }
    drop(db);

    {
        let fake = fake();
        let reopened = Database::open_full(dir.path().join("vjoy.db")).unwrap();
        let manager = manager(&reopened, &arbiter, fake.clone());
        assert_eq!(manager.status(), VjoyStatus::Active);
        assert_eq!(acquired(&fake), vec![1]);
    }

    // With the device gone, reconciliation lands in needs_setup and keeps the
    // persisted requested flag.
    let failing = fake();
    failing.lock().unwrap().set_device(1, missing_device());
    let reopened = Database::open_full(dir.path().join("vjoy.db")).unwrap();
    let manager = manager(&reopened, &arbiter, failing);
    assert_eq!(manager.status(), VjoyStatus::NeedsSetup);
    assert!(reopened.vjoy_configuration().unwrap().enabled);
}

/// The manager's mapping pass-through honors the persistence contract
/// (validation and conflicts identical to the store API).
#[test]
fn manager_mapping_passthrough_rejects_conflicts() {
    let (_dir, db) = database();
    let arbiter = arbiter();
    let manager = manager(&db, &arbiter, fake());
    let analog = analog_input(&db, "Lever", 120, 5);
    let analog2 = analog_input(&db, "Second", 121, 5);

    let record = manager
        .put_mapping(OperationId(93), analog, axis_draft(VjoyAxis::X), false)
        .unwrap();
    assert_eq!(record.input_id, analog);
    assert_eq!(manager.mappings().unwrap().len(), 1);

    assert!(matches!(
        manager.put_mapping(OperationId(94), analog2, axis_draft(VjoyAxis::X), false),
        Err(VjoyError::Storage(detail)) if detail.contains("axis has already been taken")
    ));
}

/// Selection changes are refused while active so ownership never shifts under
/// a live device; after disable a new selection applies.
#[test]
fn selection_changes_refused_while_active() {
    let (_dir, db) = database();
    let arbiter = arbiter();
    let fake = fake();
    let manager = manager(&db, &arbiter, fake.clone());
    manager.enable().unwrap();
    assert!(matches!(
        manager.set_selection(OperationId(95), &[2]),
        Err(VjoyError::InvalidState(
            "selection cannot change while active"
        ))
    ));
    manager.disable().unwrap();
    assert_eq!(
        manager.set_selection(OperationId(96), &[4]).unwrap(),
        vec![4]
    );
    manager.enable().unwrap();
    assert_eq!(acquired(&fake), vec![4]);
}
