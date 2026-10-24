//! Dedicated SQLite owner with strict schema admission and owned results.
use rusqlite::{Connection, OptionalExtension};
use std::{
    path::Path,
    sync::{mpsc, Arc, Mutex},
    thread,
};
use trenino_core::EntityId;

const APP_ID: i64 = 0x54524E52; // "TRNR"
const SCHEMA_VERSION: i64 = 1;
const LEGACY_CURRENT_VERSION: i64 = 20260927000000;
const QUEUE_BOUND: usize = 64;
const SETTINGS_SCHEMA: &str =
    "CREATE TABLE app_settings(key TEXT PRIMARY KEY NOT NULL,value TEXT NOT NULL)";
const PROFILES_SCHEMA: &str =
    "CREATE TABLE profiles(id INTEGER PRIMARY KEY,name TEXT NOT NULL UNIQUE)";
const PROFILE_SETTINGS_SCHEMA: &str = "CREATE TABLE profile_settings(profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,key TEXT NOT NULL,value TEXT NOT NULL,PRIMARY KEY(profile_id,key))";

#[derive(Debug)]
pub enum StorageError {
    Sqlite(rusqlite::Error),
    Conflict { detail: String },
    ForeignKey { detail: String },
    Constraint { detail: String },
    UnsupportedSchema { application_id: i64, version: i64 },
    ReadOnlyLegacy,
    WorkerStopped,
    NotFound,
}

impl From<rusqlite::Error> for StorageError {
    fn from(error: rusqlite::Error) -> Self {
        match error {
            rusqlite::Error::SqliteFailure(code, detail) => {
                let message = detail.unwrap_or_else(|| code.to_string());
                match code.extended_code {
                    rusqlite::ffi::SQLITE_CONSTRAINT_UNIQUE
                    | rusqlite::ffi::SQLITE_CONSTRAINT_PRIMARYKEY => {
                        Self::Conflict { detail: message }
                    }
                    rusqlite::ffi::SQLITE_CONSTRAINT_FOREIGNKEY => {
                        Self::ForeignKey { detail: message }
                    }
                    code if code & 0xff == rusqlite::ffi::SQLITE_CONSTRAINT => {
                        Self::Constraint { detail: message }
                    }
                    _ => Self::Sqlite(rusqlite::Error::SqliteFailure(code, Some(message))),
                }
            }
            other => Self::Sqlite(other),
        }
    }
}

impl std::fmt::Display for StorageError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Sqlite(error) => write!(f, "database error: {error}"),
            Self::Conflict { .. } => f.write_str("database conflict"),
            Self::ForeignKey { .. } => f.write_str("related record does not exist"),
            Self::Constraint { .. } => f.write_str("database constraint failed"),
            Self::UnsupportedSchema {
                application_id,
                version,
            } => write!(
                f,
                "unsupported database schema (application_id={application_id}, version={version})"
            ),
            Self::ReadOnlyLegacy => {
                f.write_str("legacy database is read-only until migration support is enabled")
            }
            Self::WorkerStopped => f.write_str("database worker stopped"),
            Self::NotFound => f.write_str("profile not found"),
        }
    }
}
impl std::error::Error for StorageError {}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Profile {
    pub id: EntityId,
    pub name: String,
}

type DbResult<T> = Result<T, StorageError>;
type Reply<T> = mpsc::Sender<DbResult<T>>;

enum Request {
    Get(String, Reply<Option<String>>),
    Set(String, String, Reply<()>),
    Count(Reply<u64>),
    CreateProfile(String, Reply<Profile>),
    GetProfile(EntityId, Reply<Option<Profile>>),
    DeleteProfile(EntityId, Reply<()>),
    SetProfileValue(EntityId, String, String, Reply<()>),
    ProfileValue(EntityId, String, Reply<Option<String>>),
}

struct Worker {
    tx: Mutex<Option<mpsc::SyncSender<Request>>>,
    join: Mutex<Option<thread::JoinHandle<()>>>,
}

impl Drop for Worker {
    fn drop(&mut self) {
        self.tx.get_mut().ok().and_then(Option::take);
        if let Some(join) = self.join.get_mut().ok().and_then(Option::take) {
            let _ = join.join();
        }
    }
}

#[derive(Clone)]
pub struct Database {
    worker: Arc<Worker>,
    read_only: bool,
}

impl Database {
    /// Open the isolated Rust schema or recognize the exact latest Ecto schema as read-only.
    pub fn open(path: impl AsRef<Path>) -> Result<Self, StorageError> {
        let path = path.as_ref().to_owned();
        let path_exists = path.exists();
        let (ready_tx, ready_rx) = mpsc::channel();
        let (request_tx, request_rx) = mpsc::sync_channel(QUEUE_BOUND);
        let join = thread::Builder::new()
            .name("trenino-db".into())
            .spawn(move || {
                let opened = open_connection(&path, path_exists);
                let (mut connection, legacy_read_only) = match opened {
                    Ok(opened) => opened,
                    Err(error) => {
                        let _ = ready_tx.send(Err(error));
                        return;
                    }
                };
                let _ = ready_tx.send(Ok(legacy_read_only));
                for request in request_rx {
                    handle_request(&mut connection, legacy_read_only, request);
                }
            })
            .map_err(|_| StorageError::WorkerStopped)?;

        let read_only = ready_rx.recv().map_err(|_| StorageError::WorkerStopped)??;
        Ok(Self {
            worker: Arc::new(Worker {
                tx: Mutex::new(Some(request_tx)),
                join: Mutex::new(Some(join)),
            }),
            read_only,
        })
    }

    pub fn is_legacy_read_only(&self) -> bool {
        self.read_only
    }

    pub fn get(&self, key: &str) -> Result<Option<String>, StorageError> {
        self.request(|reply| Request::Get(key.into(), reply))
    }

    pub fn set(&self, key: &str, value: &str) -> Result<(), StorageError> {
        self.ensure_writable()?;
        self.request(|reply| Request::Set(key.into(), value.into(), reply))
    }

    pub fn count(&self) -> Result<u64, StorageError> {
        self.request(Request::Count)
    }

    pub fn create_profile(&self, name: &str) -> Result<Profile, StorageError> {
        self.ensure_writable()?;
        self.request(|reply| Request::CreateProfile(name.into(), reply))
    }

    pub fn get_profile(&self, id: EntityId) -> Result<Option<Profile>, StorageError> {
        self.request(|reply| Request::GetProfile(id, reply))
    }

    pub fn delete_profile(&self, id: EntityId) -> Result<(), StorageError> {
        self.ensure_writable()?;
        self.request(|reply| Request::DeleteProfile(id, reply))
    }

    pub fn set_profile_value(
        &self,
        id: EntityId,
        key: &str,
        value: &str,
    ) -> Result<(), StorageError> {
        self.ensure_writable()?;
        self.request(|reply| Request::SetProfileValue(id, key.into(), value.into(), reply))
    }

    pub fn profile_value(&self, id: EntityId, key: &str) -> Result<Option<String>, StorageError> {
        self.request(|reply| Request::ProfileValue(id, key.into(), reply))
    }

    fn ensure_writable(&self) -> Result<(), StorageError> {
        if self.read_only {
            Err(StorageError::ReadOnlyLegacy)
        } else {
            Ok(())
        }
    }

    fn request<T>(&self, build: impl FnOnce(Reply<T>) -> Request) -> Result<T, StorageError> {
        let (reply_tx, reply_rx) = mpsc::channel();
        self.worker
            .tx
            .lock()
            .map_err(|_| StorageError::WorkerStopped)?
            .as_ref()
            .ok_or(StorageError::WorkerStopped)?
            .send(build(reply_tx))
            .map_err(|_| StorageError::WorkerStopped)?;
        reply_rx.recv().map_err(|_| StorageError::WorkerStopped)?
    }
}

fn open_connection(path: &Path, path_exists: bool) -> DbResult<(Connection, bool)> {
    let flags = if path_exists {
        rusqlite::OpenFlags::SQLITE_OPEN_READ_WRITE
    } else {
        rusqlite::OpenFlags::SQLITE_OPEN_READ_WRITE | rusqlite::OpenFlags::SQLITE_OPEN_CREATE
    };
    let mut connection = Connection::open_with_flags(path, flags)?;
    connection.pragma_update(None, "foreign_keys", "ON")?;
    let application_id: i64 =
        connection.pragma_query_value(None, "application_id", |row| row.get(0))?;
    let version: i64 = connection.pragma_query_value(None, "user_version", |row| row.get(0))?;

    if application_id == 0 && version == 0 {
        let object_count = count_user_objects(&connection)?;
        if object_count == 0 {
            create_rust_schema(&mut connection)?;
            return Ok((connection, false));
        }
        if is_current_ecto_schema(&connection)? {
            connection.pragma_update(None, "query_only", "ON")?;
            return Ok((connection, true));
        }
    } else if application_id == APP_ID
        && version == SCHEMA_VERSION
        && validate_rust_schema(&connection)?
    {
        return Ok((connection, false));
    }

    Err(StorageError::UnsupportedSchema {
        application_id,
        version,
    })
}

fn count_user_objects(connection: &Connection) -> DbResult<i64> {
    Ok(connection.query_row(
        "SELECT count(*) FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
        [],
        |row| row.get(0),
    )?)
}

fn create_rust_schema(connection: &mut Connection) -> DbResult<()> {
    let transaction = connection.transaction()?;
    transaction.execute_batch(&format!(
        "{SETTINGS_SCHEMA}; {PROFILES_SCHEMA}; {PROFILE_SETTINGS_SCHEMA};"
    ))?;
    transaction.pragma_update(None, "application_id", APP_ID)?;
    transaction.pragma_update(None, "user_version", SCHEMA_VERSION)?;
    transaction.commit()?;
    Ok(())
}

fn validate_rust_schema(connection: &Connection) -> DbResult<bool> {
    let mut statement = connection.prepare(
        "SELECT type, name, sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type,name",
    )?;
    let actual = statement
        .query_map([], |row| {
            Ok((
                row.get::<_, String>(0)?,
                row.get::<_, String>(1)?,
                row.get::<_, String>(2)?,
            ))
        })?
        .collect::<Result<Vec<_>, _>>()?;
    let expected = [
        ("table", "app_settings", SETTINGS_SCHEMA),
        ("table", "profile_settings", PROFILE_SETTINGS_SCHEMA),
        ("table", "profiles", PROFILES_SCHEMA),
    ];
    if actual.len() != expected.len() {
        return Ok(false);
    }
    for (kind, name, schema) in expected {
        let Some((actual_kind, _, actual_schema)) = actual
            .iter()
            .find(|(_, actual_name, _)| actual_name == name)
        else {
            return Ok(false);
        };
        if actual_kind != kind || normalize_schema(actual_schema) != normalize_schema(schema) {
            return Ok(false);
        }
    }
    Ok(true)
}

fn normalize_schema(schema: &str) -> String {
    schema
        .chars()
        .filter(|character| !character.is_whitespace() && *character != '"' && *character != '`')
        .flat_map(char::to_uppercase)
        .collect()
}

fn is_current_ecto_schema(connection: &Connection) -> DbResult<bool> {
    let exists: i64 = connection.query_row(
        "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='schema_migrations'",
        [],
        |row| row.get(0),
    )?;
    if exists == 0 {
        return Ok(false);
    }
    let latest: Option<i64> =
        connection.query_row("SELECT max(version) FROM schema_migrations", [], |row| {
            row.get(0)
        })?;
    if latest != Some(LEGACY_CURRENT_VERSION) {
        return Ok(false);
    }
    let tables: i64 = connection.query_row(
        "SELECT count(*) FROM sqlite_master WHERE type='table' AND name IN ('devices','app_settings','train_identifiers')",
        [],
        |row| row.get(0),
    )?;
    if tables != 3 {
        return Ok(false);
    }
    let settings_columns = table_columns(connection, "app_settings")?;
    let device_columns = table_columns(connection, "devices")?;
    Ok(settings_columns.contains(&"key".to_owned())
        && settings_columns.contains(&"value".to_owned())
        && device_columns.contains(&"id".to_owned())
        && device_columns.contains(&"name".to_owned()))
}

fn table_columns(connection: &Connection, table: &str) -> DbResult<Vec<String>> {
    let mut statement = connection.prepare(&format!("PRAGMA table_info({table})"))?;
    let rows = statement.query_map([], |row| row.get(1))?;
    Ok(rows.collect::<Result<_, _>>()?)
}

fn handle_request(connection: &mut Connection, legacy_read_only: bool, request: Request) {
    match request {
        Request::Get(key, reply) => {
            let result = connection
                .query_row(
                    "SELECT value FROM app_settings WHERE key=?1",
                    [&key],
                    |row| row.get(0),
                )
                .optional()
                .map_err(StorageError::from);
            let _ = reply.send(result);
        }
        Request::Set(key, value, reply) => {
            let result = if legacy_read_only {
                Err(StorageError::ReadOnlyLegacy)
            } else {
                set_value(connection, &key, &value)
            };
            let _ = reply.send(result);
        }
        Request::Count(reply) => {
            let result = connection
                .query_row("SELECT count(*) FROM app_settings", [], |row| {
                    row.get::<_, u64>(0)
                })
                .map_err(StorageError::from);
            let _ = reply.send(result);
        }
        Request::CreateProfile(name, reply) => {
            let result = if legacy_read_only {
                Err(StorageError::ReadOnlyLegacy)
            } else {
                create_profile(connection, name)
            };
            let _ = reply.send(result);
        }
        Request::GetProfile(id, reply) => {
            let table = if legacy_read_only {
                "devices"
            } else {
                "profiles"
            };
            let sql = format!("SELECT id,name FROM {table} WHERE id=?1");
            let result = connection
                .query_row(&sql, [id.0], |row| {
                    Ok(Profile {
                        id: EntityId(row.get(0)?),
                        name: row.get(1)?,
                    })
                })
                .optional()
                .map_err(StorageError::from);
            let _ = reply.send(result);
        }
        Request::DeleteProfile(id, reply) => {
            let result = if legacy_read_only {
                Err(StorageError::ReadOnlyLegacy)
            } else {
                delete_profile(connection, id)
            };
            let _ = reply.send(result);
        }
        Request::SetProfileValue(id, key, value, reply) => {
            let result = if legacy_read_only {
                Err(StorageError::ReadOnlyLegacy)
            } else {
                set_profile_value(connection, id, &key, &value)
            };
            let _ = reply.send(result);
        }
        Request::ProfileValue(id, key, reply) => {
            let result = connection
                .query_row(
                    "SELECT value FROM profile_settings WHERE profile_id=?1 AND key=?2",
                    (id.0, &key),
                    |row| row.get(0),
                )
                .optional()
                .map_err(StorageError::from);
            let _ = reply.send(result);
        }
    }
}

fn set_value(connection: &mut Connection, key: &str, value: &str) -> DbResult<()> {
    let transaction = connection.transaction()?;
    transaction.execute(
        "INSERT INTO app_settings(key,value) VALUES(?1,?2) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        (key, value),
    )?;
    transaction.commit()?;
    Ok(())
}

fn create_profile(connection: &mut Connection, name: String) -> DbResult<Profile> {
    let transaction = connection.transaction()?;
    transaction.execute("INSERT INTO profiles(name) VALUES(?1)", [&name])?;
    let profile = Profile {
        id: EntityId(transaction.last_insert_rowid()),
        name,
    };
    transaction.commit()?;
    Ok(profile)
}

fn delete_profile(connection: &mut Connection, id: EntityId) -> DbResult<()> {
    let transaction = connection.transaction()?;
    let changed = transaction.execute("DELETE FROM profiles WHERE id=?1", [id.0])?;
    if changed == 0 {
        return Err(StorageError::NotFound);
    }
    transaction.commit()?;
    Ok(())
}

fn set_profile_value(
    connection: &mut Connection,
    id: EntityId,
    key: &str,
    value: &str,
) -> DbResult<()> {
    let transaction = connection.transaction()?;
    transaction.execute(
        "INSERT INTO profile_settings(profile_id,key,value) VALUES(?1,?2,?3) ON CONFLICT(profile_id,key) DO UPDATE SET value=excluded.value",
        (id.0, key, value),
    )?;
    transaction.commit()?;
    Ok(())
}
