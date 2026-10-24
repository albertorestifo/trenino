use rusqlite::{Connection, OpenFlags};
use tempfile::tempdir;
use trenino_runtime::storage::{Database, LegacySchema, StorageError};

const V074_FIXTURE: &str = include_str!("fixtures/storage/ecto-0.7.4.sql");
const CURRENT_FIXTURE: &str = include_str!("fixtures/storage/ecto-current.sql");
const APP_ID: i64 = 0x54524E52;
const RUST_SCHEMA_VERSION: i64 = 2;

fn fixture(path: &std::path::Path, sql: &str) {
    let connection = Connection::open(path).unwrap();
    connection
        .pragma_update(None, "foreign_keys", "OFF")
        .unwrap();
    connection.execute_batch(sql).unwrap();
    connection
        .pragma_update(None, "foreign_keys", "ON")
        .unwrap();
    connection
        .pragma_update(None, "journal_mode", "WAL")
        .unwrap();
}

#[test]
fn v074_upgrade_keeps_domain_ids_relations_settings_and_wal_backup() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("v074.db");
    let backup = dir.path().join("v074.pre-rust.db");
    fixture(&path, V074_FIXTURE);

    // Keep a second handle open so this committed setting remains in the WAL
    // when the migration takes its SQLite backup.
    let wal_anchor = Connection::open(&path).unwrap();
    wal_anchor
        .execute(
            "INSERT INTO app_settings(key,value) VALUES('wal_fixture','committed')",
            [],
        )
        .unwrap();
    assert!(dir.path().join("v074.db-wal").exists());

    let report = Database::migrate_legacy(&path, &backup).unwrap();
    assert_eq!(report.source, LegacySchema::V074);
    assert_eq!(report.backup_path, backup);

    let upgraded = Connection::open(&path).unwrap();
    assert_eq!(
        upgraded
            .pragma_query_value(None, "application_id", |row| row.get::<_, i64>(0))
            .unwrap(),
        APP_ID
    );
    assert_eq!(
        upgraded
            .pragma_query_value(None, "user_version", |row| row.get::<_, i64>(0))
            .unwrap(),
        RUST_SCHEMA_VERSION
    );
    assert_eq!(
        upgraded
            .query_row(
                "SELECT id,name,config_id FROM devices WHERE id=7",
                [],
                |row| {
                    Ok((
                        row.get::<_, i64>(0)?,
                        row.get::<_, String>(1)?,
                        row.get::<_, i64>(2)?,
                    ))
                }
            )
            .unwrap(),
        (7, "Desktop".to_owned(), 42)
    );
    assert_eq!(
        upgraded
            .query_row(
                "SELECT c.id,c.input_id,c.max_hardware_value,i.device_id FROM device_input_calibrations c JOIN device_inputs i ON i.id=c.input_id WHERE c.id=27",
                [],
                |row| Ok((row.get::<_, i64>(0)?, row.get::<_, i64>(1)?, row.get::<_, i64>(2)?, row.get::<_, i64>(3)?)),
            )
            .unwrap(),
        (27, 17, 1023, 7)
    );
    assert_eq!(
        upgraded
            .query_row(
                "SELECT t.id,ti.identifier,e.id,lc.id,n.id,lb.id,s.id FROM trains t JOIN train_identifiers ti ON ti.train_id=t.id JOIN train_elements e ON e.train_id=t.id JOIN train_lever_configs lc ON lc.element_id=e.id JOIN train_lever_notches n ON n.lever_config_id=lc.id JOIN lever_input_bindings lb ON lb.lever_config_id=lc.id JOIN scripts s ON s.train_id=t.id WHERE t.id=37",
                [],
                |row| Ok((row.get::<_, i64>(0)?, row.get::<_, String>(1)?, row.get::<_, i64>(2)?, row.get::<_, i64>(3)?, row.get::<_, i64>(4)?, row.get::<_, i64>(5)?, row.get::<_, i64>(6)?)),
            )
            .unwrap(),
        (37, "RVM_FIXTURE".to_owned(), 47, 57, 67, 77, 87)
    );
    assert_eq!(
        upgraded
            .query_row(
                "SELECT value FROM app_settings WHERE key='wal_fixture'",
                [],
                |row| row.get::<_, String>(0)
            )
            .unwrap(),
        "committed"
    );
    assert_eq!(
        upgraded
            .query_row(
                "SELECT value FROM app_settings WHERE key='simulator_url'",
                [],
                |row| row.get::<_, String>(0)
            )
            .unwrap(),
        "http://fixture.invalid"
    );

    let restored = Connection::open_with_flags(&backup, OpenFlags::SQLITE_OPEN_READ_ONLY).unwrap();
    assert_eq!(
        restored
            .query_row("SELECT identifier FROM trains WHERE id=37", [], |row| {
                row.get::<_, String>(0)
            })
            .unwrap(),
        "  RVM_FIXTURE  "
    );
    assert_eq!(
        restored
            .query_row(
                "SELECT value FROM app_settings WHERE key='wal_fixture'",
                [],
                |row| row.get::<_, String>(0)
            )
            .unwrap(),
        "committed"
    );
    drop(wal_anchor);
}

#[test]
fn current_ecto_upgrade_preserves_vjoy_state_and_allows_devices_one_through_sixteen() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("current.db");
    let backup = dir.path().join("current.pre-rust.db");
    fixture(&path, CURRENT_FIXTURE);

    let report = Database::migrate_legacy(&path, &backup).unwrap();
    assert_eq!(report.source, LegacySchema::Current);

    let connection = Connection::open(&path).unwrap();
    assert_eq!(
        connection
            .query_row(
                "SELECT m.id,m.input_id,m.device_index,m.axis,c.id,c.device_index FROM virtual_joystick_mappings m CROSS JOIN virtual_joystick_configurations c WHERE m.id=59 AND c.id=1",
                [],
                |row| Ok((row.get::<_, i64>(0)?, row.get::<_, i64>(1)?, row.get::<_, i64>(2)?, row.get::<_, String>(3)?, row.get::<_, i64>(4)?, row.get::<_, i64>(5)?)),
            )
            .unwrap(),
        (59, 17, 1, "x".to_owned(), 1, 1)
    );
    assert_eq!(
        connection
            .query_row(
                "SELECT count(*) FROM virtual_joystick_configurations",
                [],
                |row| row.get::<_, i64>(0)
            )
            .unwrap(),
        1
    );
    connection
        .execute(
            "UPDATE virtual_joystick_configurations SET device_index=16 WHERE id=1",
            [],
        )
        .unwrap();
    connection
        .execute(
            "UPDATE virtual_joystick_mappings SET device_index=16 WHERE id=59",
            [],
        )
        .unwrap();
    connection
        .execute(
            "INSERT INTO device_inputs(id,pin,input_type,sensitivity,device_id,inserted_at,updated_at,debounce,matrix_id,name) VALUES(18,1,'analog',3,7,'now','now',NULL,NULL,'Brake')",
            [],
        )
        .unwrap();
    assert!(connection
        .execute(
            "INSERT INTO virtual_joystick_mappings(input_id,device_index,target_type,axis,button,inverted,inserted_at,updated_at) VALUES(18,16,'axis','x',NULL,0,'now','now')",
            [],
        )
        .is_err());
    assert_eq!(
        connection
            .query_row(
                "SELECT params FROM device_i2c_modules WHERE id=57",
                [],
                |row| row.get::<_, String>(0)
            )
            .unwrap(),
        r#"{"brightness":5,"num_digits":6,"display_type":"fourteen_segment","has_dot":false,"align_right":true,"min_value":0.0}"#
    );
    assert_eq!(
        connection
            .query_row(
                "SELECT script_id FROM train_display_bindings WHERE id=58",
                [],
                |row| row.get::<_, i64>(0)
            )
            .unwrap(),
        87
    );
}

#[test]
fn failed_data_transform_rolls_back_original_and_keeps_recoverable_backup() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("invalid.db");
    let backup = dir.path().join("invalid.pre-rust.db");
    fixture(&path, V074_FIXTURE);
    let before = Connection::open(&path).unwrap();
    before
        .execute("UPDATE trains SET identifier='   ' WHERE id=37", [])
        .unwrap();
    drop(before);

    assert!(matches!(
        Database::migrate_legacy(&path, &backup),
        Err(StorageError::InvalidLegacyData { .. })
    ));

    let original = Connection::open(&path).unwrap();
    assert_eq!(
        original
            .query_row("PRAGMA user_version", [], |row| row.get::<_, i64>(0))
            .unwrap(),
        0
    );
    assert_eq!(
        original
            .query_row("SELECT identifier FROM trains WHERE id=37", [], |row| {
                row.get::<_, String>(0)
            })
            .unwrap(),
        "   "
    );
    assert_eq!(
        original
            .query_row("SELECT count(*) FROM sqlite_master WHERE type='table' AND name='rust_schema_migrations'", [], |row| row.get::<_, i64>(0))
            .unwrap(),
        0
    );
    let backup_db = Connection::open(&backup).unwrap();
    assert_eq!(
        backup_db
            .query_row("SELECT identifier FROM trains WHERE id=37", [], |row| {
                row.get::<_, String>(0)
            })
            .unwrap(),
        "   "
    );
}

#[test]
fn normalized_train_identifier_collisions_are_refused_before_transforming_rows() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("collision.db");
    let backup = dir.path().join("collision.pre-rust.db");
    fixture(&path, V074_FIXTURE);
    let connection = Connection::open(&path).unwrap();
    connection
        .execute(
            "INSERT INTO trains(name,description,identifier,inserted_at,updated_at) VALUES('Duplicate',NULL,'RVM_FIXTURE','2026-05-01T12:00:00Z','2026-05-01T12:00:00Z')",
            [],
        )
        .unwrap();
    drop(connection);

    assert!(matches!(
        Database::migrate_legacy(&path, &backup),
        Err(StorageError::InvalidLegacyData { .. })
    ));
    let unchanged = Connection::open(&path).unwrap();
    assert_eq!(
        unchanged
            .query_row("SELECT identifier FROM trains WHERE id=37", [], |row| {
                row.get::<_, String>(0)
            })
            .unwrap(),
        "  RVM_FIXTURE  "
    );
    assert_eq!(
        unchanged
            .query_row("SELECT count(*) FROM trains", [], |row| row
                .get::<_, i64>(0))
            .unwrap(),
        2
    );
    assert_eq!(
        Connection::open(&backup)
            .unwrap()
            .query_row("SELECT count(*) FROM trains", [], |row| row
                .get::<_, i64>(0))
            .unwrap(),
        2
    );
}

#[test]
fn unsupported_schema_is_refused_before_backup_or_mutation() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("unknown.db");
    let backup = dir.path().join("unknown.pre-rust.db");
    fixture(&path, CURRENT_FIXTURE);
    let connection = Connection::open(&path).unwrap();
    connection
        .execute_batch(
            "CREATE TABLE user_extension(payload TEXT); INSERT INTO user_extension VALUES('keep');",
        )
        .unwrap();
    drop(connection);

    assert!(matches!(
        Database::migrate_legacy(&path, &backup),
        Err(StorageError::UnsupportedSchema { .. })
    ));
    assert!(!backup.exists());
    let unchanged = Connection::open(&path).unwrap();
    assert_eq!(
        unchanged
            .query_row("SELECT payload FROM user_extension", [], |row| row
                .get::<_, String>(0))
            .unwrap(),
        "keep"
    );
    assert_eq!(
        unchanged
            .query_row("PRAGMA application_id", [], |row| row.get::<_, i64>(0))
            .unwrap(),
        0
    );
}

#[test]
fn existing_backup_is_never_overwritten() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("current.db");
    let backup = dir.path().join("current.pre-rust.db");
    fixture(&path, CURRENT_FIXTURE);
    std::fs::write(&backup, b"existing backup must survive").unwrap();

    assert!(matches!(
        Database::migrate_legacy(&path, &backup),
        Err(StorageError::BackupAlreadyExists)
    ));
    assert_eq!(
        std::fs::read(&backup).unwrap(),
        b"existing backup must survive"
    );
    let source = Connection::open(&path).unwrap();
    assert_eq!(
        source
            .pragma_query_value(None, "user_version", |row| row.get::<_, i64>(0))
            .unwrap(),
        0
    );
}

#[test]
fn migrated_full_database_opens_writable_without_auto_migrating_legacy_open() {
    let dir = tempdir().unwrap();
    let legacy = dir.path().join("legacy.db");
    let backup = dir.path().join("legacy.pre-rust.db");
    fixture(&legacy, CURRENT_FIXTURE);
    assert!(Database::open(&legacy).unwrap().is_legacy_read_only());

    Database::migrate_legacy(&legacy, &backup).unwrap();
    let db = Database::open(&legacy).unwrap();
    assert!(!db.is_legacy_read_only());
    assert_eq!(
        db.get("simulator_url").unwrap().as_deref(),
        Some("http://fixture.invalid")
    );
    db.set("simulator_url", "http://rust.invalid").unwrap();
    assert_eq!(
        db.get("simulator_url").unwrap().as_deref(),
        Some("http://rust.invalid")
    );
    assert_eq!(
        db.get_profile(trenino_core::EntityId(7))
            .unwrap()
            .unwrap()
            .name,
        "Desktop"
    );
    assert!(matches!(
        db.create_profile("not-applicable"),
        Err(StorageError::UnsupportedOperation {
            operation: "create_profile"
        })
    ));
}
