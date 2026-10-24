use tempfile::tempdir;
use trenino_core::{ui::ConsentState, Topic};
use trenino_runtime::app::AppServices;
use trenino_runtime::settings::resolve_api_key_file;
use trenino_runtime::settings::Settings;

#[test]
fn writable_database_owner_is_shared_across_processes_with_different_temp_dirs() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("cross-process-owner.db");
    let child_temp = dir.path().join("child-temp");
    std::fs::create_dir_all(&child_temp).unwrap();
    let alias_dir = dir.path().join("alias-directory");
    std::fs::create_dir_all(&alias_dir).unwrap();
    let alias = alias_dir.join("owner-alias.db");
    let services = AppServices::open_full(&path, None).unwrap();
    let committed = services.set_consent(true).unwrap();

    run_cross_process_owner_probe(&path, &child_temp);
    std::fs::hard_link(&path, &alias).unwrap();
    run_cross_process_owner_probe(&alias, &child_temp);

    assert_eq!(services.get_settings().unwrap(), committed);
    assert_runtime_counters(&path, "1", "1");
    drop(services);
    assert_eq!(AppServices::open_full(&path, None).unwrap().epoch().0, 2);
}

fn run_cross_process_owner_probe(path: &std::path::Path, child_temp: &std::path::Path) {
    let output = std::process::Command::new(std::env::current_exe().unwrap())
        .arg("--exact")
        .arg("cross_process_owner_child_probe")
        .arg("--nocapture")
        .env("TRENINO_TEST_OWNER_DB", path)
        .env("TRENINO_TEST_CHILD_TEMP", child_temp)
        .env("TMP", child_temp)
        .env("TEMP", child_temp)
        .env("TMPDIR", child_temp)
        .output()
        .unwrap();
    assert!(
        output.status.success(),
        "child probe failed:\n{}\n{}",
        String::from_utf8_lossy(&output.stdout),
        String::from_utf8_lossy(&output.stderr)
    );
}

fn assert_runtime_counters(path: &std::path::Path, epoch: &str, revision: &str) {
    let conn = rusqlite::Connection::open(path).unwrap();
    assert_eq!(
        conn.query_row(
            "SELECT value FROM app_settings WHERE key='__runtime.epoch'",
            [],
            |row| row.get::<_, String>(0),
        )
        .unwrap(),
        epoch
    );
    assert_eq!(
        conn.query_row(
            "SELECT value FROM app_settings WHERE key='__runtime.revision.settings'",
            [],
            |row| row.get::<_, String>(0),
        )
        .unwrap(),
        revision
    );
}

#[test]
fn cross_process_owner_child_probe() {
    let Ok(path) = std::env::var("TRENINO_TEST_OWNER_DB") else {
        return;
    };
    assert_eq!(
        std::env::temp_dir(),
        std::path::PathBuf::from(std::env::var_os("TRENINO_TEST_CHILD_TEMP").unwrap())
    );
    match trenino_runtime::storage::Database::open_full(path) {
        Err(trenino_runtime::storage::StorageError::AlreadyRunning) => {}
        Err(error) => panic!("child got unexpected open error: {error}"),
        Ok(db) => {
            let epoch = db.allocate_epoch().unwrap();
            panic!("child admitted a second owner and advanced epoch to {epoch}");
        }
    }
}

#[test]
fn fresh_trial_database_uses_full_schema_and_publishes_database_backed_snapshots() {
    let dir = tempdir().unwrap();
    let services = AppServices::open_full(dir.path().join("trial.db"), None).unwrap();

    let initial_settings = services.get_settings().unwrap();
    assert_eq!(initial_settings.topic, Topic::Settings);
    assert_eq!(initial_settings.epoch.0, 1);
    assert_eq!(initial_settings.revision.0, 0);
    assert_eq!(initial_settings.value.error_reporting, ConsentState::Unset);
    assert_eq!(
        initial_settings.value.simulator.url,
        "http://localhost:31270"
    );

    let changed = services.set_consent(true).unwrap();
    assert_eq!(changed.topic, Topic::Settings);
    assert_eq!(changed.epoch, initial_settings.epoch);
    assert_eq!(changed.revision.0, 1);
    assert_eq!(changed.value.error_reporting, ConsentState::Enabled);

    let read_back = services.get_settings().unwrap();
    assert_eq!(read_back.revision, changed.revision);
    assert_eq!(read_back.value, changed.value);

    let hardware = services.list_configurations().unwrap();
    assert_eq!(hardware.topic, Topic::Hardware);
    assert!(hardware.value.is_empty());
    let trains = services.list_trains().unwrap();
    assert_eq!(trains.topic, Topic::Trains);
    assert!(trains.value.is_empty());
}

#[test]
fn full_schema_can_be_reopened_with_a_new_epoch() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("reopen.db");
    let first = AppServices::open_full(&path, None).unwrap();
    assert_eq!(first.epoch().0, 1);
    drop(first);
    let second = AppServices::open_full(&path, None).unwrap();
    assert_eq!(second.epoch().0, 2);
}

#[test]
fn unknown_full_schema_ledger_metadata_is_rejected_without_epoch_change() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("ledger.db");
    let first = AppServices::open_full(&path, None).unwrap();
    let epoch = first.epoch().0;
    drop(first);
    let conn = rusqlite::Connection::open(&path).unwrap();
    conn.execute(
        "UPDATE rust_schema_migrations SET name='unknown-baseline' WHERE version=2",
        [],
    )
    .unwrap();
    drop(conn);

    assert!(matches!(
        AppServices::open_full(&path, None),
        Err(trenino_runtime::storage::StorageError::UnsupportedSchema { .. })
    ));
    let conn = rusqlite::Connection::open(&path).unwrap();
    assert_eq!(
        conn.query_row(
            "SELECT value FROM app_settings WHERE key='__runtime.epoch'",
            [],
            |row| row.get::<_, String>(0),
        )
        .unwrap(),
        epoch.to_string()
    );
}

#[test]
fn bootstrap_v1_is_rejected_without_losing_profiles_or_settings() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("bootstrap.db");
    {
        let db = trenino_runtime::storage::Database::open(&path).unwrap();
        let profile = db.create_profile("kept profile").unwrap();
        db.set_profile_value(profile.id, "kept", "value").unwrap();
        db.set("simulator_url", "http://kept.invalid").unwrap();
    }

    let result = AppServices::open_full(&path, None);
    assert!(result.is_err());
    let db = trenino_runtime::storage::Database::open(&path).unwrap();
    assert_eq!(db.count().unwrap(), 1);
    assert_eq!(
        db.get("simulator_url").unwrap().as_deref(),
        Some("http://kept.invalid")
    );
    let conn = rusqlite::Connection::open(&path).unwrap();
    assert_eq!(
        conn.query_row("SELECT name FROM profiles", [], |row| row
            .get::<_, String>(0))
            .unwrap(),
        "kept profile"
    );
}

#[test]
fn selecting_a_legacy_ecto_database_fails_actionably_without_migrating_it() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("legacy.db");
    let conn = rusqlite::Connection::open(&path).unwrap();
    conn.pragma_update(None, "foreign_keys", "OFF").unwrap();
    conn.execute_batch(include_str!("fixtures/storage/ecto-current.sql"))
        .unwrap();
    drop(conn);

    let error = AppServices::open_full(&path, None).err().unwrap();
    assert!(matches!(
        error,
        trenino_runtime::storage::StorageError::LegacyUpgradeRequired
    ));
    let conn = rusqlite::Connection::open(&path).unwrap();
    assert_eq!(
        conn.query_row("PRAGMA user_version", [], |row| row.get::<_, i64>(0))
            .unwrap(),
        0
    );
    assert_eq!(
        conn.query_row("SELECT name FROM devices WHERE id=7", [], |row| row
            .get::<_, String>(0))
            .unwrap(),
        "Desktop"
    );
}

#[test]
fn configured_api_key_path_and_database_key_are_never_returned_in_snapshots() {
    let dir = tempdir().unwrap();
    let key_path = dir.path().join("tsw7.key");
    std::fs::write(&key_path, "file-secret\n").unwrap();
    let services = AppServices::open_full(dir.path().join("trial.db"), Some(key_path)).unwrap();
    services.set_api_key("db-secret").unwrap();
    assert_eq!(
        services.simulator_api_key().unwrap().as_deref(),
        Some("db-secret")
    );

    let snapshot = services.get_settings().unwrap();
    assert!(snapshot.value.simulator.api_key_configured);
    let encoded = serde_json::to_string(&snapshot).unwrap();
    assert!(!encoded.contains("db-secret"));
    assert!(!encoded.contains("file-secret"));
}

#[test]
fn configuration_and_train_lists_read_full_schema_rows() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("lists.db");
    let services = AppServices::open_full(&path, None).unwrap();
    let conn = rusqlite::Connection::open(&path).unwrap();
    conn.execute(
        "INSERT INTO devices(name,inserted_at,updated_at,config_id,description) VALUES('Panel','now','now',42,'Cab panel')",
        [],
    )
    .unwrap();
    conn.execute(
        "INSERT INTO device_inputs(pin,device_id,inserted_at,updated_at) VALUES(3,1,'now','now')",
        [],
    )
    .unwrap();
    conn.execute(
        "INSERT INTO trains(name,description,inserted_at,updated_at) VALUES('Class 47','Freight','now','now')",
        [],
    )
    .unwrap();
    conn.execute(
        "INSERT INTO train_elements(train_id,type,name,inserted_at,updated_at) VALUES(1,'lever','Throttle','now','now')",
        [],
    )
    .unwrap();
    conn.execute(
        "INSERT INTO train_identifiers(train_id,identifier,inserted_at,updated_at) VALUES(1,'RVM-47','now','now')",
        [],
    )
    .unwrap();
    drop(conn);

    let configs = services.list_configurations().unwrap();
    assert_eq!(configs.value.len(), 1);
    assert_eq!(configs.value[0].config_id.get(), 42);
    assert_eq!(configs.value[0].input_count, 1);
    assert_eq!(configs.value[0].description.as_deref(), Some("Cab panel"));
    let trains = services.list_trains().unwrap();
    assert_eq!(trains.value.len(), 1);
    assert_eq!(trains.value[0].identifiers, ["RVM-47"]);
    assert_eq!(trains.value[0].element_count, 1);
}

#[test]
fn url_validation_and_durable_epoch_overflow_are_reported() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("epoch.db");
    let services = AppServices::open_full(&path, None).unwrap();
    assert!(services.set_simulator_url("file:///etc/passwd").is_err());
    let valid = services
        .set_simulator_url("https://127.0.0.1:31270/")
        .unwrap();
    assert_eq!(valid.value.simulator.url, "https://127.0.0.1:31270/");
    drop(services);

    let conn = rusqlite::Connection::open(&path).unwrap();
    conn.execute(
        "UPDATE app_settings SET value=?1 WHERE key='__runtime.epoch'",
        [u64::MAX.to_string()],
    )
    .unwrap();
    drop(conn);
    assert!(AppServices::open_full(&path, None).is_err());
}

#[test]
fn shutdown_stops_new_service_operations() {
    let dir = tempdir().unwrap();
    let services = AppServices::open_full(dir.path().join("shutdown.db"), None).unwrap();
    services.quiesce();
    let error = services.get_settings().unwrap_err();
    assert_eq!(error.code, trenino_core::ErrorCode::Unavailable);
}

#[test]
fn exhausted_settings_revision_refuses_mutation_without_changing_consent() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("revision.db");
    let services = AppServices::open_full(&path, None).unwrap();
    let conn = rusqlite::Connection::open(&path).unwrap();
    conn.execute(
        "UPDATE app_settings SET value=?1 WHERE key='__runtime.revision.settings'",
        [u64::MAX.to_string()],
    )
    .unwrap();
    drop(conn);
    assert!(services.set_consent(true).is_err());
    assert_eq!(
        services.get_settings().unwrap().value.error_reporting,
        ConsentState::Unset
    );
}

#[test]
fn concurrent_consent_changes_keep_committed_values_paired_with_unique_revisions() {
    let directory = tempdir().unwrap();
    let services = std::sync::Arc::new(
        AppServices::open_full(directory.path().join("concurrent.db"), None).unwrap(),
    );
    let mut writers = Vec::new();
    for index in 0..12 {
        let services = services.clone();
        writers.push(std::thread::spawn(move || {
            let enabled = index % 2 == 0;
            let snapshot = services.set_consent(enabled).unwrap();
            (snapshot.revision.0, enabled, snapshot.value.error_reporting)
        }));
    }
    let mut observations = writers
        .into_iter()
        .map(|writer| writer.join().unwrap())
        .collect::<Vec<_>>();
    observations.sort_by_key(|observation| observation.0);

    for (offset, (revision, enabled, consent)) in observations.iter().enumerate() {
        assert_eq!(*revision, offset as u64 + 1);
        assert_eq!(
            *consent,
            if *enabled {
                ConsentState::Enabled
            } else {
                ConsentState::Disabled
            }
        );
    }
    let latest = services.get_settings().unwrap();
    assert_eq!(latest.revision.0, 12);
    assert_eq!(latest.value.error_reporting, observations.last().unwrap().2);
}

#[test]
fn simulator_key_discovery_prefers_manual_then_tsw7_then_tsw6() {
    let dir = tempdir().unwrap();
    let documents = dir.path().join("Documents");
    let tsw6 = documents.join("My Games/TrainSimWorld6/Saved/Config/CommAPIKey.txt");
    let tsw7 = documents.join("My Games/TrainSimWorld7/Saved/Config/CommAPIKey.txt");
    std::fs::create_dir_all(tsw6.parent().unwrap()).unwrap();
    std::fs::create_dir_all(tsw7.parent().unwrap()).unwrap();
    std::fs::write(&tsw6, "six").unwrap();
    assert_eq!(resolve_api_key_file(&documents, None), Some(tsw6.clone()));
    std::fs::write(&tsw7, "seven").unwrap();
    assert_eq!(resolve_api_key_file(&documents, None), Some(tsw7));
    let manual = dir.path().join("manual.txt");
    assert_eq!(
        resolve_api_key_file(&documents, Some(manual.clone())),
        Some(manual)
    );
}

#[test]
fn full_runtime_owns_database_path_for_its_lifetime() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("owned.db");
    let first = AppServices::open_full(&path, None).unwrap();
    assert!(AppServices::open_full(&path, None).is_err());
    drop(first);
    AppServices::open_full(&path, None).unwrap();
}

#[test]
fn direct_database_open_cannot_admit_a_second_full_v2_writer() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("direct-owner.db");
    let services = AppServices::open_full(&path, None).unwrap();
    services.set_consent(true).unwrap();

    assert!(matches!(
        trenino_runtime::storage::Database::open_full(&path),
        Err(trenino_runtime::storage::StorageError::AlreadyRunning)
    ));
    assert!(matches!(
        trenino_runtime::storage::Database::open(&path),
        Err(trenino_runtime::storage::StorageError::AlreadyRunning)
    ));
    assert_eq!(services.get_settings().unwrap().revision.0, 1);
}

#[test]
fn hard_link_alias_cannot_admit_a_second_full_v2_writer() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("primary.db");
    let alias_dir = dir.path().join("separate-directory");
    std::fs::create_dir_all(&alias_dir).unwrap();
    let alias = alias_dir.join("alias.db");
    let services = AppServices::open_full(&path, None).unwrap();
    services.set_consent(true).unwrap();
    std::fs::hard_link(&path, &alias).unwrap();

    assert!(matches!(
        AppServices::open_full(&alias, None),
        Err(trenino_runtime::storage::StorageError::AlreadyRunning)
    ));
    assert!(matches!(
        trenino_runtime::storage::Database::open(&alias),
        Err(trenino_runtime::storage::StorageError::AlreadyRunning)
    ));
    assert_eq!(services.get_settings().unwrap().revision.0, 1);
}

#[test]
fn partial_or_malformed_runtime_metadata_is_rejected_without_rewrites() {
    for (name, key, value) in [
        ("missing-epoch", "__runtime.epoch", None),
        ("missing-revision", "__runtime.revision.settings", None),
        ("malformed-epoch", "__runtime.epoch", Some("not-a-counter")),
        (
            "malformed-revision",
            "__runtime.revision.settings",
            Some("01"),
        ),
    ] {
        let dir = tempdir().unwrap();
        let path = dir.path().join(format!("{name}.db"));
        drop(AppServices::open_full(&path, None).unwrap());
        let conn = rusqlite::Connection::open(&path).unwrap();
        if let Some(value) = value {
            conn.execute(
                "UPDATE app_settings SET value=?1 WHERE key=?2",
                (value, key),
            )
            .unwrap();
        } else {
            conn.execute("DELETE FROM app_settings WHERE key=?1", [key])
                .unwrap();
        }
        let before = conn
            .prepare("SELECT key,value FROM app_settings WHERE key LIKE '__runtime.%' ORDER BY key")
            .unwrap()
            .query_map([], |row| {
                Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
            })
            .unwrap()
            .collect::<Result<Vec<_>, _>>()
            .unwrap();
        drop(conn);

        assert!(AppServices::open_full(&path, None).is_err(), "{name}");
        let conn = rusqlite::Connection::open(&path).unwrap();
        let found = conn
            .prepare("SELECT key,value FROM app_settings WHERE key LIKE '__runtime.%' ORDER BY key")
            .unwrap()
            .query_map([], |row| {
                Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
            })
            .unwrap()
            .collect::<Result<Vec<_>, _>>()
            .unwrap();
        assert_eq!(found, before, "{name}");
    }
}

#[test]
fn legacy_settings_and_raw_setting_mutations_cannot_bypass_full_v2_revisions() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("settings-boundary.db");
    let db = trenino_runtime::storage::Database::open_full(&path).unwrap();
    db.allocate_epoch().unwrap();
    let settings = Settings::new(db.clone());

    settings.set_error_reporting_consent(true).unwrap();
    assert!(settings.set_simulator_url("file:///etc/passwd").is_err());
    settings.set_api_key("secret").unwrap();
    assert!(db.set("simulator_url", "file:///etc/passwd").is_err());
    assert!(db.set("__runtime.epoch", "99").is_err());
    assert!(settings.set_value("__runtime.epoch", "99").is_err());
    assert!(settings
        .set_value("simulator_url", "file:///etc/passwd")
        .is_err());
    assert!(db
        .set_with_revision("simulator_url", "file:///etc/passwd", "settings")
        .is_err());
    assert!(db
        .set_with_revision("error_reporting", "true", "settings")
        .is_err());
    assert!(db
        .set_with_revision("error_reporting", "enabled", "hardware")
        .is_err());
    assert!(db
        .set_with_revision("__runtime.epoch", "99", "settings")
        .is_err());

    let (values, metadata) = db.settings_snapshot().unwrap();
    assert_eq!(metadata.epoch, 1);
    assert_eq!(metadata.revision, 2);
    assert_eq!(values["error_reporting"], "enabled");
    assert_eq!(values["simulator_api_key"], "secret");
    assert!(!values.contains_key("simulator_url"));
}
