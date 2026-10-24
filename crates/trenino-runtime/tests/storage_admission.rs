use rusqlite::Connection;
use tempfile::tempdir;
use trenino_core::EntityId;
use trenino_runtime::storage::{Database, StorageError};

const APP_ID: i64 = 0x54524E52;
const VERSION: i64 = 1;

fn row_counts(connection: &Connection) -> Vec<(String, i64)> {
    let mut statement = connection
        .prepare("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
        .unwrap();
    let tables = statement
        .query_map([], |row| row.get::<_, String>(0))
        .unwrap()
        .collect::<Result<Vec<_>, _>>()
        .unwrap();
    tables
        .into_iter()
        .map(|table| {
            let escaped_name = table.replace('"', "\"\"");
            let count = connection
                .query_row(
                    &format!("SELECT count(*) FROM \"{escaped_name}\""),
                    [],
                    |row| row.get(0),
                )
                .unwrap();
            (table, count)
        })
        .collect()
}

fn stamped_rust_schema(path: &std::path::Path, mutation: &str) {
    let conn = Connection::open(path).unwrap();
    let base = match mutation {
        "missing_profile_settings" => "CREATE TABLE app_settings(key TEXT PRIMARY KEY NOT NULL,value TEXT NOT NULL); CREATE TABLE profiles(id INTEGER PRIMARY KEY,name TEXT NOT NULL UNIQUE);",
        "missing_value_column" => "CREATE TABLE app_settings(key TEXT PRIMARY KEY NOT NULL); CREATE TABLE profiles(id INTEGER PRIMARY KEY,name TEXT NOT NULL UNIQUE); CREATE TABLE profile_settings(profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,key TEXT NOT NULL,value TEXT NOT NULL,PRIMARY KEY(profile_id,key));",
        "missing_name_unique" => "CREATE TABLE app_settings(key TEXT PRIMARY KEY NOT NULL,value TEXT NOT NULL); CREATE TABLE profiles(id INTEGER PRIMARY KEY,name TEXT NOT NULL); CREATE TABLE profile_settings(profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,key TEXT NOT NULL,value TEXT NOT NULL,PRIMARY KEY(profile_id,key));",
        "missing_fk" => "CREATE TABLE app_settings(key TEXT PRIMARY KEY NOT NULL,value TEXT NOT NULL); CREATE TABLE profiles(id INTEGER PRIMARY KEY,name TEXT NOT NULL UNIQUE); CREATE TABLE profile_settings(profile_id INTEGER NOT NULL,key TEXT NOT NULL,value TEXT NOT NULL,PRIMARY KEY(profile_id,key));",
        "missing_cascade" => "CREATE TABLE app_settings(key TEXT PRIMARY KEY NOT NULL,value TEXT NOT NULL); CREATE TABLE profiles(id INTEGER PRIMARY KEY,name TEXT NOT NULL UNIQUE); CREATE TABLE profile_settings(profile_id INTEGER NOT NULL REFERENCES profiles(id),key TEXT NOT NULL,value TEXT NOT NULL,PRIMARY KEY(profile_id,key));",
        _ => "CREATE TABLE app_settings(key TEXT PRIMARY KEY NOT NULL,value TEXT NOT NULL); CREATE TABLE profiles(id INTEGER PRIMARY KEY,name TEXT NOT NULL UNIQUE); CREATE TABLE profile_settings(profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,key TEXT NOT NULL,value TEXT NOT NULL,PRIMARY KEY(profile_id,key));",
    };
    conn.execute_batch(base).unwrap();
    if mutation == "missing_value_column" {
        conn.execute("INSERT INTO app_settings(key) VALUES('keep')", [])
            .unwrap();
    } else {
        conn.execute(
            "INSERT INTO app_settings(key,value) VALUES('keep','me')",
            [],
        )
        .unwrap();
    }
    conn.execute("INSERT INTO profiles(name) VALUES('kept profile')", [])
        .unwrap();
    if mutation == "missing_fk" {
        conn.execute(
            "INSERT INTO profile_settings(profile_id,key,value) VALUES(999,'orphan','kept')",
            [],
        )
        .unwrap();
    } else if mutation != "missing_profile_settings" {
        conn.execute(
            "INSERT INTO profile_settings(profile_id,key,value) VALUES(1,'theme','kept')",
            [],
        )
        .unwrap();
    }
    if mutation == "unexpected_object" {
        conn.execute_batch("CREATE TABLE unrelated(payload TEXT);")
            .unwrap();
        conn.execute("INSERT INTO unrelated(payload) VALUES('kept')", [])
            .unwrap();
    }
    conn.pragma_update(None, "application_id", APP_ID).unwrap();
    conn.pragma_update(None, "user_version", VERSION).unwrap();
}

#[test]
fn stamped_but_malformed_rust_schemas_are_refused_without_mutation() {
    for mutation in [
        "missing_profile_settings",
        "missing_value_column",
        "missing_name_unique",
        "missing_fk",
        "missing_cascade",
        "unexpected_object",
    ] {
        let dir = tempdir().unwrap();
        let path = dir.path().join("malformed.db");
        stamped_rust_schema(&path, mutation);
        let before = Connection::open(&path).unwrap().query_row("SELECT group_concat(name, ',') FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY name", [], |r| r.get::<_, Option<String>>(0)).unwrap();
        let data_before = row_counts(&Connection::open(&path).unwrap());
        assert!(
            matches!(
                Database::open(&path),
                Err(StorageError::UnsupportedSchema { .. })
            ),
            "accepted mutation {mutation}"
        );
        let conn = Connection::open(&path).unwrap();
        let after = conn.query_row("SELECT group_concat(name, ',') FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY name", [], |r| r.get::<_, Option<String>>(0)).unwrap();
        assert_eq!(after, before, "schema changed for {mutation}");
        assert_eq!(
            row_counts(&conn),
            data_before,
            "data changed for {mutation}"
        );
        assert_eq!(
            conn.query_row("PRAGMA user_version", [], |r| r.get::<_, i64>(0))
                .unwrap(),
            VERSION
        );
    }
}

#[test]
fn storage_errors_keep_not_found_conflict_and_foreign_key_categories_and_worker_recovers() {
    let dir = tempdir().unwrap();
    let db = Database::open(dir.path().join("errors.db")).unwrap();
    assert!(matches!(
        db.delete_profile(EntityId(999)),
        Err(StorageError::NotFound)
    ));
    let profile = db.create_profile("Main").unwrap();
    assert!(matches!(
        db.create_profile("Main"),
        Err(StorageError::Conflict { .. })
    ));
    assert!(matches!(
        db.set_profile_value(EntityId(999), "theme", "dark"),
        Err(StorageError::ForeignKey { .. })
    ));
    assert_eq!(db.profile_value(profile.id, "theme").unwrap(), None);
    db.set_profile_value(profile.id, "theme", "dark").unwrap();
    assert_eq!(
        db.profile_value(profile.id, "theme").unwrap().as_deref(),
        Some("dark")
    );
    assert_eq!(
        db.create_profile("After failures").unwrap().name,
        "After failures"
    );
}

#[test]
fn exact_rust_schema_reopens_as_writable_and_keeps_data() {
    let dir = tempdir().unwrap();
    let path = dir.path().join("reopen.db");
    {
        let db = Database::open(&path).unwrap();
        db.set("mode", "active").unwrap();
    }
    let reopened = Database::open(&path).unwrap();
    assert!(!reopened.is_legacy_read_only());
    assert_eq!(reopened.get("mode").unwrap().as_deref(), Some("active"));
    reopened.set("mode", "updated").unwrap();
}
