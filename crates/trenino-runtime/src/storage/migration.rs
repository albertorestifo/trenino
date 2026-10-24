use super::{Database, DbResult, StorageError, APP_ID, FULL_SCHEMA_VERSION};
use rusqlite::{
    backup::Backup, Connection, OpenFlags, OptionalExtension, Transaction, TransactionBehavior,
};
use std::{
    collections::{BTreeMap, BTreeSet},
    fs::{self, OpenOptions},
    path::{Path, PathBuf},
    thread,
    time::{Duration, Instant},
};

const V074_SCHEMA: &str = include_str!("schema/ecto-0.7.4.sql");
const CURRENT_SCHEMA: &str = include_str!("schema/ecto-current.sql");
const FULL_SCHEMA: &str = include_str!("schema/rust-full-v2.sql");
const ECTO_VERSION_074: &[i64] = &[
    20251124203623,
    20251124204015,
    20251124212404,
    20251128125215,
    20251129103558,
    20251129111518,
    20251129112341,
    20251129192949,
    20251129193005,
    20251129193018,
    20251129193032,
    20251207184747,
    20251210154430,
    20251210165321,
    20251210215004,
    20251216212504,
    20251216220651,
    20251220183323,
    20251221173532,
    20251221194910,
    20251223103929,
    20251223111818,
    20251223112836,
    20251223210242,
    20251223214615,
    20260101201704,
    20260103114839,
    20260103194112,
    20260106154322,
    20260107181338,
    20260107220815,
    20260117101411,
    20260201154004,
    20260503000000,
    20260503101628,
    20260503114723,
];
const ECTO_VERSION_CURRENT: &[i64] = &[
    20251124203623,
    20251124204015,
    20251124212404,
    20251128125215,
    20251129103558,
    20251129111518,
    20251129112341,
    20251129192949,
    20251129193005,
    20251129193018,
    20251129193032,
    20251207184747,
    20251210154430,
    20251210165321,
    20251210215004,
    20251216212504,
    20251216220651,
    20251220183323,
    20251221173532,
    20251221194910,
    20251223103929,
    20251223111818,
    20251223112836,
    20251223210242,
    20251223214615,
    20260101201704,
    20260103114839,
    20260103194112,
    20260106154322,
    20260107181338,
    20260107220815,
    20260117101411,
    20260201154004,
    20260503000000,
    20260503101628,
    20260503114723,
    20260503200000,
    20260503200001,
    20260503220000,
    20260801000000,
    20260927000000,
];
const POST_074_VERSIONS: &[i64] = &[
    20260503200000,
    20260503200001,
    20260503220000,
    20260801000000,
    20260927000000,
];

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LegacySchema {
    V074,
    Current,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct MigrationReport {
    pub source: LegacySchema,
    pub backup_path: PathBuf,
}

impl Database {
    /// Explicitly migrate a supported Ecto database to the Rust-owned schema.
    ///
    /// This is a blocking operation. Call it during exclusive startup on a
    /// dedicated blocking owner, before starting ordinary database workers or
    /// allowing legacy writers. It does not coordinate with existing
    /// [`Database`] handles; callers must ensure there are no active handles.
    /// `open` never calls this method and remains read-only for legacy schemas.
    pub fn migrate_legacy(
        source_path: impl AsRef<Path>,
        backup_path: impl AsRef<Path>,
    ) -> Result<MigrationReport, StorageError> {
        migrate_legacy(source_path.as_ref(), backup_path.as_ref())
    }
}

fn migrate_legacy(source_path: &Path, backup_path: &Path) -> Result<MigrationReport, StorageError> {
    migrate_legacy_with_hooks(source_path, backup_path, None, false)
}

fn migrate_legacy_with_hooks(
    source_path: &Path,
    backup_path: &Path,
    before_reservation: Option<Box<dyn FnOnce() + Send>>,
    fail_after_upgrade: bool,
) -> Result<MigrationReport, StorageError> {
    if !source_path.exists() {
        return Err(StorageError::UnsupportedSchema {
            application_id: 0,
            version: 0,
        });
    }
    let source_canonical =
        fs::canonicalize(source_path).map_err(|detail| StorageError::Backup {
            detail: detail.to_string(),
        })?;
    let reported_backup_path = backup_path.to_owned();
    let backup_path =
        normalize_backup_path(backup_path).map_err(|detail| StorageError::Backup {
            detail: detail.to_string(),
        })?;
    if conflicts_with_source_or_sidecar(&source_canonical, &backup_path)? {
        return Err(StorageError::InvalidBackupPath);
    }
    if backup_path.exists() {
        return Err(StorageError::BackupAlreadyExists);
    }

    let mut source = Connection::open_with_flags(source_path, OpenFlags::SQLITE_OPEN_READ_WRITE)?;
    source.busy_timeout(Duration::from_secs(30))?;
    source.pragma_update(None, "foreign_keys", "ON")?;
    // Acquire the reservation before admission. No legacy writer can commit
    // between recognizing the schema, validating its data, taking the backup,
    // and applying the transformation.
    if let Some(before_reservation) = before_reservation {
        before_reservation();
    }
    let transaction = source.transaction_with_behavior(TransactionBehavior::Immediate)?;
    let app_id: i64 = transaction.pragma_query_value(None, "application_id", |row| row.get(0))?;
    let user_version: i64 =
        transaction.pragma_query_value(None, "user_version", |row| row.get(0))?;
    let Some(schema) = is_supported_legacy_schema(&transaction)? else {
        return Err(StorageError::UnsupportedSchema {
            application_id: app_id,
            version: user_version,
        });
    };
    validate_legacy_data(&transaction, schema)?;
    let snapshot = Connection::open_with_flags(source_path, OpenFlags::SQLITE_OPEN_READ_ONLY)?;
    snapshot.busy_timeout(Duration::from_secs(30))?;
    create_backup(&snapshot, &backup_path)?;
    drop(snapshot);
    apply_upgrade(&transaction, schema)?;
    if fail_after_upgrade {
        return Err(StorageError::InvalidLegacyData {
            detail: "injected failure after schema transformation".to_owned(),
        });
    }
    verify_foreign_keys(&transaction)?;
    transaction.pragma_update(None, "application_id", APP_ID)?;
    transaction.pragma_update(None, "user_version", FULL_SCHEMA_VERSION)?;
    let target_app_id: i64 =
        transaction.pragma_query_value(None, "application_id", |row| row.get(0))?;
    let target_version: i64 =
        transaction.pragma_query_value(None, "user_version", |row| row.get(0))?;
    if target_app_id != APP_ID
        || target_version != FULL_SCHEMA_VERSION
        || !validate_full_schema(&transaction)?
    {
        return Err(StorageError::InvalidLegacyData {
            detail: "upgraded schema failed its integrity fingerprint".to_owned(),
        });
    }
    transaction.commit()?;
    Ok(MigrationReport {
        source: schema,
        backup_path: reported_backup_path,
    })
}

fn normalize_backup_path(path: &Path) -> std::io::Result<PathBuf> {
    let parent = path
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));
    let parent = fs::canonicalize(parent)?;
    let file_name = path.file_name().ok_or_else(|| {
        std::io::Error::new(
            std::io::ErrorKind::InvalidInput,
            "backup path has no file name",
        )
    })?;
    let candidate = parent.join(file_name);
    if candidate.exists() {
        fs::canonicalize(candidate)
    } else {
        Ok(candidate)
    }
}

fn conflicts_with_source_or_sidecar(source: &Path, backup: &Path) -> Result<bool, StorageError> {
    let mut reserved = vec![source.to_owned()];
    let Some(name) = source.file_name() else {
        return Err(StorageError::InvalidBackupPath);
    };
    for suffix in ["-journal", "-wal", "-shm"] {
        let mut sidecar = name.to_os_string();
        sidecar.push(suffix);
        reserved.push(source.with_file_name(sidecar));
    }
    let backup_key = path_comparison_key(backup);
    Ok(reserved
        .iter()
        .any(|path| path_comparison_key(path) == backup_key))
}

fn path_comparison_key(path: &Path) -> String {
    let mut key = path.to_string_lossy().replace('\\', "/");
    if cfg!(windows) {
        key = key
            .strip_prefix("//?/")
            .unwrap_or(&key)
            .to_owned()
            .to_lowercase();
        key = key
            .split('/')
            .map(|part| part.trim_end_matches([' ', '.']))
            .collect::<Vec<_>>()
            .join("/");
    }
    key
}

fn create_backup(source: &Connection, backup_path: &Path) -> Result<(), StorageError> {
    let created = OpenOptions::new()
        .write(true)
        .create_new(true)
        .open(backup_path)
        .map_err(|error| {
            if error.kind() == std::io::ErrorKind::AlreadyExists {
                StorageError::BackupAlreadyExists
            } else {
                StorageError::Backup {
                    detail: error.to_string(),
                }
            }
        })?;
    drop(created);

    let result = (|| {
        let mut destination =
            Connection::open_with_flags(backup_path, OpenFlags::SQLITE_OPEN_READ_WRITE)?;
        let backup = Backup::new(source, &mut destination)?;
        let started = Instant::now();
        loop {
            match backup.step(64).map_err(StorageError::from)? {
                rusqlite::backup::StepResult::Done => return Ok(()),
                rusqlite::backup::StepResult::More => {}
                rusqlite::backup::StepResult::Busy | rusqlite::backup::StepResult::Locked => {
                    if started.elapsed() >= Duration::from_secs(30) {
                        return Err(StorageError::Backup {
                            detail: "SQLite remained busy while creating the snapshot".to_owned(),
                        });
                    }
                    thread::sleep(Duration::from_millis(50));
                }
                _ => {
                    return Err(StorageError::Backup {
                        detail: "SQLite backup returned an unsupported step result".to_owned(),
                    })
                }
            }
        }
    })();
    if let Err(error) = result {
        let _ = fs::remove_file(backup_path);
        return Err(match error {
            StorageError::Sqlite(_) => StorageError::Backup {
                detail: error.to_string(),
            },
            other => other,
        });
    }
    Ok(())
}

pub(super) fn is_supported_legacy_schema(
    connection: &Connection,
) -> DbResult<Option<LegacySchema>> {
    if connection.pragma_query_value(None, "application_id", |row| row.get::<_, i64>(0))? != 0
        || connection.pragma_query_value(None, "user_version", |row| row.get::<_, i64>(0))? != 0
    {
        return Ok(None);
    }
    if schema_matches(connection, V074_SCHEMA)?
        && ecto_versions_match(connection, ECTO_VERSION_074)?
        && foreign_keys_are_valid(connection)?
    {
        return Ok(Some(LegacySchema::V074));
    }
    if schema_matches(connection, CURRENT_SCHEMA)?
        && ecto_versions_match(connection, ECTO_VERSION_CURRENT)?
        && foreign_keys_are_valid(connection)?
    {
        return Ok(Some(LegacySchema::Current));
    }
    Ok(None)
}

pub(super) fn validate_full_schema(connection: &Connection) -> DbResult<bool> {
    if !schema_matches(connection, FULL_SCHEMA)? {
        return Ok(false);
    }
    let mut statement =
        connection.prepare("SELECT version,name FROM rust_schema_migrations ORDER BY version")?;
    let ledger = statement
        .query_map([], |row| {
            Ok((row.get::<_, i64>(0)?, row.get::<_, String>(1)?))
        })?
        .collect::<Result<Vec<_>, _>>()?;
    Ok(ledger == [(1, "ecto-full-to-rust-v1".to_owned())]
        && ecto_versions_match(connection, ECTO_VERSION_CURRENT)?
        && foreign_keys_are_valid(connection)?)
}

fn validate_legacy_data(connection: &Connection, schema: LegacySchema) -> DbResult<()> {
    if schema == LegacySchema::V074 {
        let blank: bool = connection.query_row(
            "SELECT EXISTS(SELECT 1 FROM trains WHERE TRIM(identifier)='')",
            [],
            |row| row.get(0),
        )?;
        if blank {
            return Err(StorageError::InvalidLegacyData {
                detail: "trains.identifier contains a blank value after trimming".to_owned(),
            });
        }
        let collision: bool = connection.query_row(
            "SELECT EXISTS(SELECT 1 FROM (SELECT TRIM(identifier) FROM trains GROUP BY TRIM(identifier) HAVING COUNT(*)>1))",
            [],
            |row| row.get(0),
        )?;
        if collision {
            return Err(StorageError::InvalidLegacyData {
                detail: "trains.identifier contains duplicate normalized values".to_owned(),
            });
        }
    } else {
        let missing: Option<i64> = connection
            .query_row(
                "SELECT t.id FROM trains t WHERE NOT EXISTS (SELECT 1 FROM train_identifiers i WHERE i.train_id=t.id) ORDER BY t.id LIMIT 1",
                [],
                |row| row.get(0),
            )
            .optional()?;
        if let Some(train_id) = missing {
            return Err(StorageError::InvalidLegacyData {
                detail: format!("trains row {train_id} has no train_identifiers row"),
            });
        }
    }

    validate_json_column(connection, "scripts", "triggers", true)?;
    validate_json_column(connection, "device_i2c_modules", "params", false)?;
    Ok(())
}

fn validate_json_column(
    connection: &Connection,
    table: &str,
    column: &str,
    string_array: bool,
) -> DbResult<()> {
    // These identifiers are constants at the call sites, never database input.
    let present: bool = connection.query_row(
        "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE type='table' AND name=?1)",
        [table],
        |row| row.get(0),
    )?;
    if !present {
        return Ok(());
    }
    let sql = format!("SELECT id,{column} FROM {table} WHERE {column} IS NOT NULL ORDER BY id");
    let mut statement = connection.prepare(&sql)?;
    let rows = statement.query_map([], |row| {
        Ok((row.get::<_, i64>(0)?, row.get::<_, String>(1)?))
    })?;
    for row in rows {
        let (id, encoded) = row?;
        let parsed: serde_json::Value =
            serde_json::from_str(&encoded).map_err(|_| StorageError::InvalidLegacyData {
                detail: format!("{table}.{column} row {id} contains malformed JSON"),
            })?;
        let valid_shape = if string_array {
            parsed
                .as_array()
                .is_some_and(|items| items.iter().all(serde_json::Value::is_string))
        } else {
            parsed.is_object()
        };
        if !valid_shape {
            return Err(StorageError::InvalidLegacyData {
                detail: format!("{table}.{column} row {id} has an unsupported JSON value"),
            });
        }
    }
    Ok(())
}

fn ecto_versions_match(connection: &Connection, expected: &[i64]) -> DbResult<bool> {
    let mut statement =
        connection.prepare("SELECT version FROM schema_migrations ORDER BY version")?;
    let versions = statement
        .query_map([], |row| row.get::<_, i64>(0))?
        .collect::<Result<Vec<_>, _>>()?;
    Ok(versions == expected)
}

fn schema_matches(connection: &Connection, expected_sql: &str) -> DbResult<bool> {
    Ok(schema_objects(connection)? == reference_objects(expected_sql)?)
}

fn schema_objects(connection: &Connection) -> DbResult<BTreeMap<(String, String), String>> {
    let mut statement = connection.prepare(
        "SELECT type,name,sql FROM sqlite_master WHERE name NOT GLOB 'sqlite_*' AND sql IS NOT NULL",
    )?;
    let rows = statement.query_map([], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, String>(1)?,
            row.get::<_, String>(2)?,
        ))
    })?;
    rows.map(|row| {
        let (kind, name, sql) = row?;
        Ok(((kind, name), sql))
    })
    .collect()
}

fn reference_objects(sql: &str) -> DbResult<BTreeMap<(String, String), String>> {
    let connection = Connection::open_in_memory()?;
    connection.execute_batch(sql)?;
    schema_objects(&connection)
}

fn foreign_keys_are_valid(connection: &Connection) -> DbResult<bool> {
    let mut statement = connection.prepare("PRAGMA foreign_key_check")?;
    let has_violations = statement.query([])?.next()?.is_some();
    Ok(!has_violations)
}

fn verify_foreign_keys(connection: &Connection) -> DbResult<()> {
    if foreign_keys_are_valid(connection)? {
        Ok(())
    } else {
        Err(StorageError::InvalidLegacyData {
            detail: "foreign-key integrity check failed".to_owned(),
        })
    }
}

fn apply_upgrade(transaction: &Transaction<'_>, schema: LegacySchema) -> DbResult<()> {
    if schema == LegacySchema::V074 {
        migrate_train_identifiers(transaction)?;
    } else {
        rebuild_virtual_joystick_tables(transaction)?;
    }

    create_missing_target_objects(transaction)?;

    if schema == LegacySchema::V074 {
        for version in POST_074_VERSIONS {
            transaction.execute(
                "INSERT INTO schema_migrations(version,inserted_at) VALUES(?1,NULL)",
                [version],
            )?;
        }
    }

    transaction.execute_batch(
        "CREATE TABLE rust_schema_migrations (version INTEGER PRIMARY KEY, name TEXT NOT NULL, applied_at TEXT NOT NULL);",
    )?;
    transaction.execute(
        "INSERT INTO rust_schema_migrations(version,name,applied_at) VALUES(1,'ecto-full-to-rust-v1',strftime('%Y-%m-%dT%H:%M:%fZ','now'))",
        [],
    )?;
    Ok(())
}

fn migrate_train_identifiers(transaction: &Transaction<'_>) -> DbResult<()> {
    transaction.execute_batch(
        "CREATE TEMP TABLE rust_legacy_train_identifiers AS SELECT id AS train_id,identifier FROM trains",
    )?;
    transaction.execute("DROP INDEX trains_identifier_index", [])?;
    transaction.execute("ALTER TABLE trains DROP COLUMN identifier", [])?;
    let target = reference_objects(CURRENT_SCHEMA)?;
    let create = target
        .get(&("table".to_owned(), "train_identifiers".to_owned()))
        .ok_or_else(|| StorageError::InvalidLegacyData {
            detail: "train identifier target schema is unavailable".to_owned(),
        })?;
    transaction.execute(create, [])?;
    transaction.execute(
        "INSERT INTO train_identifiers(train_id,identifier,inserted_at,updated_at) SELECT train_id,TRIM(identifier),CURRENT_TIMESTAMP,CURRENT_TIMESTAMP FROM rust_legacy_train_identifiers",
        [],
    )?;
    transaction.execute_batch("DROP TABLE rust_legacy_train_identifiers")?;
    Ok(())
}

fn rebuild_virtual_joystick_tables(transaction: &Transaction<'_>) -> DbResult<()> {
    for name in [
        "virtual_joystick_configurations",
        "virtual_joystick_mappings",
    ] {
        let target = reference_objects(FULL_SCHEMA)?;
        let create = target
            .get(&("table".to_owned(), name.to_owned()))
            .ok_or_else(|| StorageError::InvalidLegacyData {
                detail: "virtual joystick target schema is unavailable".to_owned(),
            })?;
        let temp_name = format!("{name}_rust_migration");
        let marker = format!("CREATE TABLE {name} (");
        let replacement = format!("CREATE TABLE {temp_name} (");
        let temp_sql = create.replacen(&marker, &replacement, 1);
        if temp_sql == *create {
            return Err(StorageError::InvalidLegacyData {
                detail: "virtual joystick table definition is unexpected".to_owned(),
            });
        }
        transaction.execute_batch(&temp_sql)?;
        let columns = column_names(transaction, name)?;
        let joined = columns
            .iter()
            .map(|column| format!("\"{column}\""))
            .collect::<Vec<_>>()
            .join(",");
        transaction.execute_batch(&format!(
            "INSERT INTO \"{temp_name}\" ({joined}) SELECT {joined} FROM \"{name}\"; DROP TABLE \"{name}\";"
        ))?;
        transaction.execute(create, [])?;
        transaction.execute_batch(&format!(
            "INSERT INTO \"{name}\" ({joined}) SELECT {joined} FROM \"{temp_name}\"; DROP TABLE \"{temp_name}\";"
        ))?;
    }
    Ok(())
}

fn column_names(connection: &Connection, table: &str) -> DbResult<Vec<String>> {
    let mut statement = connection.prepare(&format!("PRAGMA table_info(\"{table}\")"))?;
    let columns = statement
        .query_map([], |row| row.get::<_, String>(1))?
        .collect::<Result<_, _>>()?;
    Ok(columns)
}

fn create_missing_target_objects(transaction: &Transaction<'_>) -> DbResult<()> {
    let expected = reference_objects(FULL_SCHEMA)?;
    let actual = schema_objects(transaction)?;
    let actual_names = actual.keys().cloned().collect::<BTreeSet<_>>();
    for ((kind, name), sql) in expected
        .iter()
        .filter(|((kind, name), _)| kind == "table" && name != "rust_schema_migrations")
    {
        if !actual_names.contains(&(kind.clone(), name.clone())) {
            transaction.execute(sql, [])?;
        }
    }
    for ((kind, name), sql) in expected.iter().filter(|((kind, _), _)| kind == "index") {
        if !actual_names.contains(&(kind.clone(), name.clone())) {
            transaction.execute(sql, [])?;
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::mpsc;
    use tempfile::tempdir;

    const CURRENT_FIXTURE: &str = include_str!("../../tests/fixtures/storage/ecto-current.sql");
    const V074_FIXTURE: &str = include_str!("../../tests/fixtures/storage/ecto-0.7.4.sql");

    fn fixture(path: &Path) {
        let connection = Connection::open(path).unwrap();
        connection
            .pragma_update(None, "foreign_keys", "OFF")
            .unwrap();
        connection.execute_batch(CURRENT_FIXTURE).unwrap();
    }

    #[test]
    fn transform_failure_rolls_back_source_and_keeps_openable_pre_upgrade_backup() {
        let dir = tempdir().unwrap();
        let source_path = dir.path().join("rollback.db");
        let backup_path = dir.path().join("rollback.backup.db");
        let connection = Connection::open(&source_path).unwrap();
        connection
            .pragma_update(None, "foreign_keys", "OFF")
            .unwrap();
        connection.execute_batch(V074_FIXTURE).unwrap();
        drop(connection);

        assert!(matches!(
            migrate_legacy_with_hooks(&source_path, &backup_path, None, true),
            Err(StorageError::InvalidLegacyData { .. })
        ));
        let source = Connection::open(&source_path).unwrap();
        assert_eq!(
            source
                .pragma_query_value(None, "user_version", |row| row.get::<_, i64>(0))
                .unwrap(),
            0
        );
        assert!(schema_matches(&source, V074_SCHEMA).unwrap());
        assert_eq!(
            source
                .query_row("SELECT identifier FROM trains WHERE id=37", [], |row| {
                    row.get::<_, String>(0)
                })
                .unwrap(),
            "  RVM_FIXTURE  "
        );
        let backup =
            Connection::open_with_flags(&backup_path, OpenFlags::SQLITE_OPEN_READ_ONLY).unwrap();
        assert_eq!(
            backup
                .query_row("SELECT identifier FROM trains WHERE id=37", [], |row| {
                    row.get::<_, String>(0)
                })
                .unwrap(),
            "  RVM_FIXTURE  "
        );
        assert_eq!(
            backup
                .pragma_query_value(None, "user_version", |row| row.get::<_, i64>(0))
                .unwrap(),
            0
        );
    }

    #[test]
    fn admission_waits_for_writer_then_refuses_new_ledger_version_without_backup() {
        let dir = tempdir().unwrap();
        let source_path = dir.path().join("writer-race.db");
        let backup_path = dir.path().join("writer-race.backup.db");
        fixture(&source_path);
        let mut writer = Connection::open(&source_path).unwrap();
        let writer_tx = writer
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .unwrap();

        let (ready_tx, ready_rx) = mpsc::channel();
        let (continue_tx, continue_rx) = mpsc::channel();
        let source_for_migration = source_path.clone();
        let backup_for_migration = backup_path.clone();
        let migration = thread::spawn(move || {
            migrate_legacy_with_hooks(
                &source_for_migration,
                &backup_for_migration,
                Some(Box::new(move || {
                    let _ = ready_tx.send(());
                    let _ = continue_rx.recv();
                })),
                false,
            )
        });
        ready_rx.recv_timeout(Duration::from_secs(5)).unwrap();
        writer_tx
            .execute(
                "INSERT INTO schema_migrations(version,inserted_at) VALUES(20990101000000,NULL)",
                [],
            )
            .unwrap();
        writer_tx.commit().unwrap();
        continue_tx.send(()).unwrap();

        assert!(matches!(
            migration.join().unwrap(),
            Err(StorageError::UnsupportedSchema { .. })
        ));
        assert!(!backup_path.exists());
        let check = Connection::open(source_path).unwrap();
        assert_eq!(
            check
                .query_row(
                    "SELECT count(*) FROM schema_migrations WHERE version=20990101000000",
                    [],
                    |row| row.get::<_, i64>(0),
                )
                .unwrap(),
            1
        );
        assert_eq!(
            check
                .pragma_query_value(None, "user_version", |row| row.get::<_, i64>(0))
                .unwrap(),
            0
        );
    }

    #[test]
    fn backup_and_transform_include_data_committed_by_waiting_writer() {
        let dir = tempdir().unwrap();
        let source_path = dir.path().join("data-race.db");
        let backup_path = dir.path().join("data-race.backup.db");
        fixture(&source_path);
        let mut writer = Connection::open(&source_path).unwrap();
        let writer_tx = writer
            .transaction_with_behavior(TransactionBehavior::Immediate)
            .unwrap();

        let (ready_tx, ready_rx) = mpsc::channel();
        let (continue_tx, continue_rx) = mpsc::channel();
        let source_for_migration = source_path.clone();
        let backup_for_migration = backup_path.clone();
        let migration = thread::spawn(move || {
            migrate_legacy_with_hooks(
                &source_for_migration,
                &backup_for_migration,
                Some(Box::new(move || {
                    let _ = ready_tx.send(());
                    let _ = continue_rx.recv();
                })),
                false,
            )
        });
        ready_rx.recv_timeout(Duration::from_secs(5)).unwrap();
        writer_tx
            .execute(
                "INSERT INTO app_settings(key,value) VALUES('raced_writer','committed')",
                [],
            )
            .unwrap();
        writer_tx.commit().unwrap();
        continue_tx.send(()).unwrap();

        assert_eq!(
            migration.join().unwrap().unwrap().source,
            LegacySchema::Current
        );
        for path in [&source_path, &backup_path] {
            assert_eq!(
                Connection::open(path)
                    .unwrap()
                    .query_row(
                        "SELECT value FROM app_settings WHERE key='raced_writer'",
                        [],
                        |row| row.get::<_, String>(0),
                    )
                    .unwrap(),
                "committed"
            );
        }
    }
}
