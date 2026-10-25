use tempfile::tempdir;
use trenino_core::{AppError, ConfigId, EntityId, Epoch, Revision, Snapshot, Topic};
use trenino_runtime::{
    paths,
    settings::Settings,
    storage::{Database, StorageError},
};

#[test]
fn entity_ids_are_decimal_strings_and_config_ids_are_distinct() {
    let id = EntityId(i64::MAX);
    let json = serde_json::to_string(&id).unwrap();
    assert_eq!(json, format!("\"{}\"", i64::MAX));
    assert_eq!(serde_json::from_str::<EntityId>(&json).unwrap(), id);
    assert_eq!(ConfigId::new(1).unwrap().get(), 1);
}
#[test]
fn snapshots_carry_epoch_topic_and_revision() {
    let snapshot = Snapshot::new(Epoch(7), Topic::Settings, Revision(4), "value");
    assert_eq!(snapshot.value, "value");
    assert_eq!(snapshot.topic, Topic::Settings);
    let _: AppError = AppError::internal("safe message");
}
#[test]
fn settings_consent_is_unset_until_explicit_choice_and_api_key_is_redacted() {
    let dir = tempdir().unwrap();
    let db = Database::open(dir.path().join("settings.db")).unwrap();
    let settings = Settings::new(db);
    assert_eq!(settings.error_reporting_consent().unwrap(), None);
    settings.set_error_reporting_consent(true).unwrap();
    assert_eq!(settings.error_reporting_consent().unwrap(), Some(true));
    settings.set_api_key("sensitive-token").unwrap();
    let debug = format!("{:?}", settings.public_snapshot().unwrap());
    assert!(!debug.contains("sensitive-token"));
    assert_eq!(
        settings.api_key().unwrap().as_deref(),
        Some("sensitive-token")
    );
}
#[test]
fn database_refuses_unknown_or_newer_schema_without_mutation() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("newer.db");
    {
        let conn = rusqlite::Connection::open(&path).unwrap();
        conn.pragma_update(None, "user_version", 999).unwrap();
    }
    assert!(matches!(
        Database::open(&path),
        Err(StorageError::UnsupportedSchema { .. })
    ));
    let conn = rusqlite::Connection::open(&path).unwrap();
    assert_eq!(
        conn.query_row("PRAGMA user_version", [], |r| r.get::<_, i64>(0))
            .unwrap(),
        999
    );
    assert_eq!(
        conn.query_row(
            "SELECT count(*) FROM sqlite_master WHERE type='table'",
            [],
            |r| r.get::<_, i64>(0)
        )
        .unwrap(),
        0
    );
}
#[test]
fn concurrent_settings_updates_are_serialized_and_transactional() {
    let dir = tempdir().unwrap();
    let settings = Settings::new(Database::open(dir.path().join("concurrent.db")).unwrap());
    let mut threads = Vec::new();
    for i in 0..12 {
        let settings = settings.clone();
        threads.push(std::thread::spawn(move || {
            settings.set_value(&format!("k{i}"), &format!("v{i}"))
        }));
    }
    for handle in threads {
        handle.join().unwrap().unwrap();
    }
    assert_eq!(settings.count().unwrap(), 12);
}
#[test]
fn data_paths_are_injectable_and_database_override_takes_precedence() {
    let result = paths::resolve(
        "linux",
        &[
            ("HOME", "/home/test"),
            ("XDG_DATA_HOME", "/data"),
            ("DATABASE_PATH", "/db/custom.sqlite"),
        ],
    );
    assert_eq!(result.data_dir, std::path::PathBuf::from("/data/trenino"));
    assert_eq!(
        result.database_path,
        std::path::PathBuf::from("/db/custom.sqlite")
    );
}
#[test]
fn profiles_are_typed_and_child_settings_cascade_on_delete() {
    let dir = tempdir().unwrap();
    let db = Database::open(dir.path().join("profiles.db")).unwrap();
    let profile = db.create_profile("Main").unwrap();
    assert_eq!(db.get_profile(profile.id).unwrap().unwrap().name, "Main");
    db.set_profile_value(profile.id, "theme", "dark").unwrap();
    assert_eq!(
        db.profile_value(profile.id, "theme").unwrap().as_deref(),
        Some("dark")
    );
    db.delete_profile(profile.id).unwrap();
    assert_eq!(db.profile_value(profile.id, "theme").unwrap(), None);
}

#[test]
fn operation_and_revision_ids_serialize_as_lossless_decimal_strings() {
    let operation = trenino_core::OperationId(u128::MAX);
    let revision = trenino_core::Revision(u64::MAX);
    assert_eq!(
        serde_json::to_string(&operation).unwrap(),
        format!("\"{}\"", u128::MAX)
    );
    assert_eq!(
        serde_json::to_string(&revision).unwrap(),
        format!("\"{}\"", u64::MAX)
    );
}

#[test]
fn current_ecto_schema_opens_read_only_and_reads_device_profile() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("legacy.db");
    {
        let conn = rusqlite::Connection::open(&path).unwrap();
        conn.pragma_update(None, "foreign_keys", "OFF").unwrap();
        conn.execute_batch(include_str!("fixtures/storage/ecto-current.sql"))
            .unwrap();
    }
    let db = Database::open(&path).unwrap();
    assert!(db.is_legacy_read_only());
    assert_eq!(
        db.get_profile(EntityId(7)).unwrap().unwrap().name,
        "Desktop"
    );
    assert_eq!(
        db.get("simulator_url").unwrap().as_deref(),
        Some("http://fixture.invalid")
    );
    assert!(matches!(
        db.set("simulator_url", "changed"),
        Err(StorageError::ReadOnlyLegacy)
    ));
    let conn = rusqlite::Connection::open(&path).unwrap();
    assert_eq!(
        conn.query_row(
            "SELECT value FROM app_settings WHERE key='simulator_url'",
            [],
            |r| r.get::<_, String>(0)
        )
        .unwrap(),
        "http://fixture.invalid"
    );
}

#[test]
fn malformed_ecto_schema_is_refused_without_writes() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("malformed.db");
    let conn = rusqlite::Connection::open(&path).unwrap();
    conn.execute_batch("CREATE TABLE schema_migrations(version INTEGER PRIMARY KEY); CREATE TABLE app_settings(key TEXT PRIMARY KEY); CREATE TABLE devices(id INTEGER PRIMARY KEY,name TEXT); CREATE TABLE train_identifiers(id INTEGER PRIMARY KEY); INSERT INTO schema_migrations VALUES(20260927000000);").unwrap();
    drop(conn);
    assert!(matches!(
        Database::open(&path),
        Err(StorageError::UnsupportedSchema { .. })
    ));
}

#[test]
fn config_ids_deserialize_only_inside_the_checked_firmware_range() {
    for invalid in ["0", "2147483648", "-1", "4294967296"] {
        assert!(
            serde_json::from_str::<ConfigId>(invalid).is_err(),
            "accepted {invalid}"
        );
    }
    for valid in [1, i32::MAX as u32] {
        let id = ConfigId::new(valid).unwrap();
        let json = serde_json::to_string(&id).unwrap();
        assert_eq!(serde_json::from_str::<ConfigId>(&json).unwrap(), id);
    }
}

#[test]
fn acknowledged_database_close_releases_ownership_even_while_service_clones_survive() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("retained-clones.db");
    let db = Database::open_full(&path).unwrap();
    db.allocate_epoch().unwrap();
    let retained = db.clone();
    db.set_user_setting("simulator_url", "http://localhost:31270")
        .unwrap();
    assert!(matches!(
        Database::open_full(&path),
        Err(StorageError::AlreadyRunning)
    ));
    db.close_worker(std::time::Duration::from_secs(2)).unwrap();
    retained
        .close_worker(std::time::Duration::from_secs(2))
        .unwrap();
    assert!(matches!(
        retained.get("simulator_url"),
        Err(StorageError::WorkerStopped)
    ));
    let reopened = Database::open_full(&path).unwrap();
    assert_eq!(
        reopened.get("simulator_url").unwrap().as_deref(),
        Some("http://localhost:31270")
    );
}
