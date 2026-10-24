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

    // Leave a deleted AUTOINCREMENT ID above the live rows. The upgrade must
    // preserve SQLite's legitimate high-water mark.
    let high_water = Connection::open(&path).unwrap();
    high_water.execute(
        "INSERT INTO trains(id,name,description,identifier,inserted_at,updated_at) VALUES(500,'Deleted high-water',NULL,'DELETED_HIGH_WATER','2026-05-01T12:00:00Z','2026-05-01T12:00:00Z')",
        [],
    ).unwrap();
    high_water
        .execute("DELETE FROM trains WHERE id=500", [])
        .unwrap();
    drop(high_water);

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
                "SELECT id,code,triggers,inserted_at,updated_at FROM scripts WHERE id=87",
                [],
                |row| Ok((
                    row.get::<_, i64>(0)?,
                    row.get::<_, String>(1)?,
                    row.get::<_, String>(2)?,
                    row.get::<_, String>(3)?,
                    row.get::<_, String>(4)?
                ))
            )
            .unwrap(),
        (
            87,
            "return true".to_owned(),
            "[\"manual\"]".to_owned(),
            "2026-05-01T12:00:00Z".to_owned(),
            "2026-05-01T12:00:00Z".to_owned()
        )
    );
    assert_eq!(
        upgraded
            .query_row(
                "SELECT seq FROM sqlite_sequence WHERE name='trains'",
                [],
                |row| row.get::<_, i64>(0)
            )
            .unwrap(),
        500
    );
    upgraded.execute(
        "INSERT INTO trains(name,description,inserted_at,updated_at) VALUES('After migration',NULL,'2026-05-01T12:00:00Z','2026-05-01T12:00:00Z')",
        [],
    ).unwrap();
    assert_eq!(upgraded.last_insert_rowid(), 501);
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
        connection.query_row("SELECT id,device_id,name,module_chip,i2c_address,inserted_at,updated_at FROM device_i2c_modules WHERE id=57", [], |row| Ok((row.get::<_, i64>(0)?,row.get::<_, i64>(1)?,row.get::<_, String>(2)?,row.get::<_, String>(3)?,row.get::<_, i64>(4)?,row.get::<_, String>(5)?,row.get::<_, String>(6)?))).unwrap(),
        (57, 7, "Cab display".to_owned(), "ht16k33".to_owned(), 112, "2026-05-01T12:00:00Z".to_owned(), "2026-05-01T12:00:00Z".to_owned())
    );
    assert_eq!(
        connection.query_row("SELECT id,train_id,name,enabled,code,triggers,inserted_at,updated_at FROM scripts WHERE id=87", [], |row| Ok((row.get::<_, i64>(0)?,row.get::<_, i64>(1)?,row.get::<_, String>(2)?,row.get::<_, i64>(3)?,row.get::<_, String>(4)?,row.get::<_, String>(5)?,row.get::<_, String>(6)?,row.get::<_, String>(7)?))).unwrap(),
        (87, 37, "Automation".to_owned(), 1, "return true".to_owned(), "[\"manual\"]".to_owned(), "2026-05-01T12:00:00Z".to_owned(), "2026-05-01T12:00:00Z".to_owned())
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
fn invalid_train_identifier_is_refused_before_backup_and_mutation() {
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
    assert!(!backup.exists());
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
    assert!(!backup.exists());
}

#[test]
fn rejects_reserved_source_sidecar_backup_paths_before_mutation() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("source.db");
    fixture(&path, CURRENT_FIXTURE);
    let connection = Connection::open(&path).unwrap();
    connection
        .pragma_update(None, "journal_mode", "DELETE")
        .unwrap();
    drop(connection);
    let expected_bytes = std::fs::read(&path).unwrap();

    for suffix in ["-journal", "-wal", "-shm"] {
        let backup = dir.path().join(format!("source.db{suffix}"));
        assert!(matches!(
            Database::migrate_legacy(&path, &backup),
            Err(StorageError::InvalidBackupPath)
        ));
        assert!(!backup.exists());
        assert_eq!(std::fs::read(&path).unwrap(), expected_bytes);
        assert_eq!(
            Connection::open(&path)
                .unwrap()
                .query_row("PRAGMA user_version", [], |row| row.get::<_, i64>(0))
                .unwrap(),
            0
        );
    }
    #[cfg(windows)]
    {
        let backup = dir.path().join("SOURCE.DB-WAL");
        assert!(matches!(
            Database::migrate_legacy(&path, &backup),
            Err(StorageError::InvalidBackupPath)
        ));
        assert!(!backup.exists());
        assert_eq!(std::fs::read(&path).unwrap(), expected_bytes);
    }
}

#[test]
fn bare_relative_backup_filename_is_supported_and_source_alias_is_refused() {
    use std::time::{SystemTime, UNIX_EPOCH};

    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let source_name = format!("storage-relative-{nonce}.db");
    let backup_name = format!("storage-relative-{nonce}.backup.db");
    let source = std::path::PathBuf::from(&source_name);
    fixture(&source, CURRENT_FIXTURE);
    let backup = std::path::PathBuf::from(&backup_name);
    Database::migrate_legacy(&source, &backup).unwrap();
    assert!(backup.exists());
    std::fs::remove_file(&backup).unwrap();
    std::fs::remove_file(&source).unwrap();

    let source = std::path::PathBuf::from(&source_name);
    fixture(&source, CURRENT_FIXTURE);
    assert!(matches!(
        Database::migrate_legacy(&source, &source),
        Err(StorageError::InvalidBackupPath)
    ));
    let relative_sidecar = std::path::PathBuf::from(format!("{source_name}-wal"));
    assert!(matches!(
        Database::migrate_legacy(&source, &relative_sidecar),
        Err(StorageError::InvalidBackupPath)
    ));
    assert_eq!(
        Connection::open(&source)
            .unwrap()
            .query_row("PRAGMA user_version", [], |row| row.get::<_, i64>(0))
            .unwrap(),
        0
    );
    std::fs::remove_file(source).unwrap();
}

#[test]
fn malformed_domain_json_is_refused_before_backup_without_echoing_payload() {
    for (table, column, id) in [
        ("scripts", "triggers", 87),
        ("device_i2c_modules", "params", 57),
    ] {
        let dir = tempdir().unwrap();
        let path = dir.path().join("bad-json.db");
        let backup = dir.path().join("bad-json.backup.db");
        fixture(&path, CURRENT_FIXTURE);
        let conn = Connection::open(&path).unwrap();
        let sql = format!("UPDATE {table} SET {column}='SENSITIVE_MALFORMED_PAYLOAD' WHERE id=?1");
        conn.execute(&sql, [id]).unwrap();
        drop(conn);

        let error = Database::migrate_legacy(&path, &backup).unwrap_err();
        match error {
            StorageError::InvalidLegacyData { detail } => {
                assert!(detail.contains(table));
                assert!(detail.contains(column));
                assert!(detail.contains(&id.to_string()));
                assert!(!detail.contains("SENSITIVE_MALFORMED_PAYLOAD"));
            }
            other => panic!("unexpected error: {other}"),
        }
        assert!(!backup.exists());
        let unchanged = Connection::open(&path).unwrap();
        assert_eq!(
            unchanged
                .query_row(
                    &format!("SELECT {column} FROM {table} WHERE id=?1"),
                    [id],
                    |row| row.get::<_, String>(0)
                )
                .unwrap(),
            "SENSITIVE_MALFORMED_PAYLOAD"
        );
        assert_eq!(
            unchanged
                .query_row("PRAGMA user_version", [], |row| row.get::<_, i64>(0))
                .unwrap(),
            0
        );
    }
}

#[test]
fn nullable_params_and_valid_json_payloads_are_preserved_exactly() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("nullable.db");
    let backup = dir.path().join("nullable.backup.db");
    fixture(&path, CURRENT_FIXTURE);
    let conn = Connection::open(&path).unwrap();
    conn.execute("UPDATE device_i2c_modules SET params=NULL WHERE id=57", [])
        .unwrap();
    conn.execute(
        "UPDATE scripts SET triggers='[\"manual\",\"startup\"]' WHERE id=87",
        [],
    )
    .unwrap();
    drop(conn);

    Database::migrate_legacy(&path, &backup).unwrap();
    let upgraded = Connection::open(path).unwrap();
    assert_eq!(
        upgraded
            .query_row(
                "SELECT params FROM device_i2c_modules WHERE id=57",
                [],
                |row| row.get::<_, Option<String>>(0)
            )
            .unwrap(),
        None
    );
    assert_eq!(
        upgraded
            .query_row("SELECT triggers FROM scripts WHERE id=87", [], |row| row
                .get::<_, String>(
                0
            ))
            .unwrap(),
        "[\"manual\",\"startup\"]"
    );
}

#[test]
fn current_train_without_identifier_is_refused_before_backup() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("missing-identifier.db");
    let backup = dir.path().join("missing-identifier.backup.db");
    fixture(&path, CURRENT_FIXTURE);
    let conn = Connection::open(&path).unwrap();
    conn.execute("DELETE FROM train_identifiers WHERE train_id=37", [])
        .unwrap();
    drop(conn);

    assert!(
        matches!(Database::migrate_legacy(&path, &backup), Err(StorageError::InvalidLegacyData { detail }) if detail.contains("train_identifiers"))
    );
    assert!(!backup.exists());
    assert_eq!(
        Connection::open(&path)
            .unwrap()
            .query_row(
                "SELECT count(*) FROM train_identifiers WHERE train_id=37",
                [],
                |row| row.get::<_, i64>(0)
            )
            .unwrap(),
        0
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
