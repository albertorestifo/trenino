//! Dedicated SQLite owner with strict schema admission and owned results.
mod domain;
mod hardware;
mod migration;

pub use domain::*;
pub use hardware::*;
pub use migration::{LegacySchema, MigrationReport};

#[cfg(unix)]
use fs2::FileExt;
use rusqlite::{Connection, OptionalExtension};
use std::{
    collections::BTreeMap,
    fs::{File, OpenOptions},
    path::Path,
    sync::{mpsc, Arc, Mutex},
    thread,
};
use trenino_core::EntityId;

const APP_ID: i64 = 0x54524E52; // "TRNR"
const SCHEMA_VERSION: i64 = 1;
const FULL_SCHEMA_VERSION: i64 = 2;
const QUEUE_BOUND: usize = 64;
const SETTINGS_SCHEMA: &str =
    "CREATE TABLE app_settings(key TEXT PRIMARY KEY NOT NULL,value TEXT NOT NULL)";
const PROFILES_SCHEMA: &str =
    "CREATE TABLE profiles(id INTEGER PRIMARY KEY,name TEXT NOT NULL UNIQUE)";
const PROFILE_SETTINGS_SCHEMA: &str = "CREATE TABLE profile_settings(profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,key TEXT NOT NULL,value TEXT NOT NULL,PRIMARY KEY(profile_id,key))";
const FULL_SCHEMA: &str = include_str!("schema/rust-full-v2.sql");

#[derive(Debug)]
pub enum StorageError {
    Sqlite(rusqlite::Error),
    Conflict { detail: String },
    ForeignKey { detail: String },
    Constraint { detail: String },
    UnsupportedSchema { application_id: i64, version: i64 },
    BootstrapUpgradeRequired,
    LegacyUpgradeRequired,
    AlreadyRunning,
    ReadOnlyLegacy,
    InvalidLegacyData { detail: String },
    BackupAlreadyExists,
    InvalidBackupPath,
    Backup { detail: String },
    UnsupportedOperation { operation: &'static str },
    InvalidHardware { detail: String },
    InvalidSetting { key: &'static str },
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
            Self::BootstrapUpgradeRequired => f.write_str(
                "bootstrap-v1 data needs an explicit preservation-aware upgrade before Rust runtime startup",
            ),
            Self::LegacyUpgradeRequired => f.write_str(
                "legacy database needs an explicit maintenance upgrade with a recoverable backup before Rust runtime startup",
            ),
            Self::AlreadyRunning => f.write_str("this database path is already owned by another runtime instance"),
            Self::ReadOnlyLegacy => {
                f.write_str("legacy database is read-only until migration support is enabled")
            }
            Self::InvalidLegacyData { detail } => {
                write!(f, "legacy data cannot be migrated: {detail}")
            }
            Self::BackupAlreadyExists => f.write_str("database backup path already exists"),
            Self::InvalidBackupPath => {
                f.write_str("database backup path must differ from the source database")
            }
            Self::Backup { detail } => write!(f, "could not create database backup: {detail}"),
            Self::UnsupportedOperation { operation } => write!(
                f,
                "{operation} is not supported by the migrated database API"
            ),
            Self::InvalidHardware { detail } => write!(f, "invalid hardware record: {detail}"),
            Self::InvalidSetting { key } => write!(f, "invalid value for setting {key}"),
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

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ConfigurationRecord {
    pub config_id: u32,
    pub name: String,
    pub description: Option<String>,
    pub input_count: u32,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct TrainRecord {
    pub id: EntityId,
    pub name: String,
    pub description: Option<String>,
    pub identifiers: Vec<String>,
    pub element_count: u32,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RuntimeMetadata {
    pub epoch: u64,
    pub revision: u64,
}

type DbResult<T> = Result<T, StorageError>;
type Reply<T> = mpsc::Sender<DbResult<T>>;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum SchemaMode {
    Bootstrap,
    LegacyReadOnly,
    Full,
}

enum Request {
    Get(String, Reply<Option<String>>),
    Set(String, String, Reply<()>),
    SetAndBump(String, String, String, Reply<RuntimeMetadata>),
    Count(Reply<u64>),
    CreateProfile(String, Reply<Profile>),
    GetProfile(EntityId, Reply<Option<Profile>>),
    DeleteProfile(EntityId, Reply<()>),
    SetProfileValue(EntityId, String, String, Reply<()>),
    ProfileValue(EntityId, String, Reply<Option<String>>),
    AllocateEpoch(Reply<u64>),
    Revision(String, Reply<u64>),
    BumpRevision(String, Reply<RuntimeMetadata>),
    SettingsSnapshot(Reply<(BTreeMap<String, String>, RuntimeMetadata)>),
    ConfigurationsSnapshot(Reply<(Vec<ConfigurationRecord>, RuntimeMetadata)>),
    TrainsSnapshot(Reply<(Vec<TrainRecord>, RuntimeMetadata)>),
    Hardware(HardwareJob),
}

type HardwareJob = Box<dyn FnOnce(&mut Connection, SchemaMode) + Send>;

struct Worker {
    tx: Mutex<Option<mpsc::SyncSender<Request>>>,
    join: Mutex<Option<thread::JoinHandle<()>>>,
}

#[cfg(unix)]
struct DatabaseOwnership {
    /// Pins the database inode so its identity cannot be recycled while open.
    _identity_file: File,
    lock_file: File,
    locked: bool,
}

#[cfg(windows)]
struct DatabaseOwnership {
    _identity_file: File,
    mutex: windows_sys::Win32::Foundation::HANDLE,
    locked: bool,
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
    full_schema: bool,
}

impl Database {
    /// Open the isolated Rust schema or recognize the exact latest Ecto schema as read-only.
    pub fn open(path: impl AsRef<Path>) -> Result<Self, StorageError> {
        Self::open_with_schema(path.as_ref(), false)
    }

    /// Open an explicitly selected Rust full-v2 database. A fresh empty path is
    /// initialized with the canonical full schema. Existing bootstrap-v1 data
    /// is rejected so its profiles and settings cannot be silently discarded.
    pub fn open_full(path: impl AsRef<Path>) -> Result<Self, StorageError> {
        Self::open_with_schema(path.as_ref(), true)
    }

    fn open_with_schema(path: &Path, require_full: bool) -> Result<Self, StorageError> {
        let path = path.to_owned();
        let path_exists = path.exists();
        let (ready_tx, ready_rx) = mpsc::channel();
        let (request_tx, request_rx) = mpsc::sync_channel(QUEUE_BOUND);
        let join = thread::Builder::new()
            .name("trenino-db".into())
            .spawn(move || {
                let mut ownership = match DatabaseOwnership::acquire(&path) {
                    Ok(file) => file,
                    Err(error) => {
                        let _ = ready_tx.send(Err(error));
                        return;
                    }
                };
                let opened = open_connection(&path, path_exists, require_full);
                let (mut connection, mode) = match opened {
                    Ok(opened) => opened,
                    Err(error) => {
                        let _ = ready_tx.send(Err(error));
                        return;
                    }
                };
                if mode == SchemaMode::LegacyReadOnly && ownership.unlock().is_err() {
                    let _ = ready_tx.send(Err(StorageError::WorkerStopped));
                    return;
                }
                let _ = ready_tx.send(Ok(mode));
                for request in request_rx {
                    handle_request(&mut connection, mode, request);
                }
                drop(connection);
                if mode != SchemaMode::LegacyReadOnly {
                    drop(ownership);
                }
            })
            .map_err(|_| StorageError::WorkerStopped)?;

        let mode = ready_rx.recv().map_err(|_| StorageError::WorkerStopped)??;
        Ok(Self {
            worker: Arc::new(Worker {
                tx: Mutex::new(Some(request_tx)),
                join: Mutex::new(Some(join)),
            }),
            read_only: mode == SchemaMode::LegacyReadOnly,
            full_schema: mode == SchemaMode::Full,
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

    /// Update a named user preference. Full-v2 routes it through the same
    /// validation and revision transaction used by AppServices; bootstrap
    /// databases retain their explicit legacy setter behavior.
    pub fn set_user_setting(&self, key: &str, value: &str) -> Result<(), StorageError> {
        if self.full_schema {
            self.set_with_revision(key, value, "settings").map(|_| ())
        } else {
            self.set(key, value)
        }
    }

    pub fn count(&self) -> Result<u64, StorageError> {
        self.request(Request::Count)
    }

    /// Increase the durable epoch under exclusive startup ownership. Topic
    /// revisions are reset in the same transaction; exhaustion refuses startup.
    pub fn allocate_epoch(&self) -> Result<u64, StorageError> {
        self.request(Request::AllocateEpoch)
    }

    pub fn revision(&self, topic: &str) -> Result<u64, StorageError> {
        self.request(|reply| Request::Revision(topic.into(), reply))
    }

    pub fn bump_revision(&self, topic: &str) -> Result<RuntimeMetadata, StorageError> {
        self.request(|reply| Request::BumpRevision(topic.into(), reply))
    }

    pub fn settings_snapshot(
        &self,
    ) -> Result<(BTreeMap<String, String>, RuntimeMetadata), StorageError> {
        self.request(Request::SettingsSnapshot)
    }

    pub fn configurations_snapshot(
        &self,
    ) -> Result<(Vec<ConfigurationRecord>, RuntimeMetadata), StorageError> {
        self.request(Request::ConfigurationsSnapshot)
    }

    pub fn trains_snapshot(&self) -> Result<(Vec<TrainRecord>, RuntimeMetadata), StorageError> {
        self.request(Request::TrainsSnapshot)
    }

    /// Commit a user-visible setting and its topic revision together.
    pub fn set_with_revision(
        &self,
        key: &str,
        value: &str,
        topic: &str,
    ) -> Result<RuntimeMetadata, StorageError> {
        self.request(|reply| Request::SetAndBump(key.into(), value.into(), topic.into(), reply))
    }

    pub fn create_profile(&self, name: &str) -> Result<Profile, StorageError> {
        self.ensure_profile_api("create_profile")?;
        self.request(|reply| Request::CreateProfile(name.into(), reply))
    }

    pub fn get_profile(&self, id: EntityId) -> Result<Option<Profile>, StorageError> {
        self.request(|reply| Request::GetProfile(id, reply))
    }

    pub fn delete_profile(&self, id: EntityId) -> Result<(), StorageError> {
        self.ensure_profile_api("delete_profile")?;
        self.request(|reply| Request::DeleteProfile(id, reply))
    }

    pub fn set_profile_value(
        &self,
        id: EntityId,
        key: &str,
        value: &str,
    ) -> Result<(), StorageError> {
        self.ensure_profile_api("set_profile_value")?;
        self.request(|reply| Request::SetProfileValue(id, key.into(), value.into(), reply))
    }

    pub fn profile_value(&self, id: EntityId, key: &str) -> Result<Option<String>, StorageError> {
        if self.full_schema || self.read_only {
            return Err(StorageError::UnsupportedOperation {
                operation: "profile_value",
            });
        }
        self.request(|reply| Request::ProfileValue(id, key.into(), reply))
    }

    fn ensure_writable(&self) -> Result<(), StorageError> {
        if self.read_only {
            Err(StorageError::ReadOnlyLegacy)
        } else {
            Ok(())
        }
    }

    fn ensure_profile_api(&self, operation: &'static str) -> Result<(), StorageError> {
        if self.full_schema {
            Err(StorageError::UnsupportedOperation { operation })
        } else {
            self.ensure_writable()
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

impl DatabaseOwnership {
    #[cfg(unix)]
    fn acquire(path: &Path) -> DbResult<Self> {
        let identity_file = open_database_identity_file(path)?;
        #[cfg(target_os = "macos")]
        let lock_file = {
            // Darwin implements flock() on the same lock manager as SQLite's
            // fcntl locks, so a held flock on the database file itself makes
            // every SQLite write fail with SQLITE_BUSY. Lock an inode-keyed
            // sidecar in the fixed /var/tmp directory instead: hard links and
            // symlinks to the same database still contend, ownership stays
            // independent of TMPDIR, and the lock dies with the process.
            use std::os::unix::fs::MetadataExt;
            let metadata = identity_file
                .metadata()
                .map_err(|_| StorageError::WorkerStopped)?;
            let lock_path = Path::new("/var/tmp").join(format!(
                "trenino-db-{:x}-{:x}.lock",
                metadata.dev(),
                metadata.ino()
            ));
            let file = OpenOptions::new()
                .read(true)
                .write(true)
                .create(true)
                .truncate(false)
                .open(&lock_path)
                .map_err(|_| StorageError::WorkerStopped)?;
            file
        };
        #[cfg(not(target_os = "macos"))]
        // flock is keyed by the opened inode, so hard links contend here too.
        let lock_file = identity_file
            .try_clone()
            .map_err(|_| StorageError::WorkerStopped)?;
        lock_file
            .try_lock_exclusive()
            .map_err(|_| StorageError::AlreadyRunning)?;
        Ok(Self {
            _identity_file: identity_file,
            lock_file,
            locked: true,
        })
    }

    #[cfg(windows)]
    fn acquire(path: &Path) -> DbResult<Self> {
        use std::{ffi::OsStr, os::windows::ffi::OsStrExt, ptr};
        use windows_sys::Win32::{
            Foundation::{WAIT_ABANDONED, WAIT_OBJECT_0, WAIT_TIMEOUT},
            System::Threading::{CreateMutexW, WaitForSingleObject},
        };

        let identity_file = open_database_identity_file(path)?;
        let identity = database_file_identity(&identity_file)?;
        // Use the global kernel-object namespace rather than a path under TMP.
        let name = OsStr::new(&format!("Global\\TreninoRuntimeDb-{identity}"))
            .encode_wide()
            .chain(Some(0))
            .collect::<Vec<_>>();
        let mutex = unsafe { CreateMutexW(ptr::null(), 0, name.as_ptr()) };
        if mutex.is_null() {
            return Err(StorageError::WorkerStopped);
        }
        let wait = unsafe { WaitForSingleObject(mutex, 0) };
        if wait == WAIT_TIMEOUT {
            unsafe { windows_sys::Win32::Foundation::CloseHandle(mutex) };
            return Err(StorageError::AlreadyRunning);
        }
        // WAIT_ABANDONED transfers ownership after a crashed worker exits.
        if wait != WAIT_OBJECT_0 && wait != WAIT_ABANDONED {
            unsafe { windows_sys::Win32::Foundation::CloseHandle(mutex) };
            return Err(StorageError::WorkerStopped);
        }
        Ok(Self {
            _identity_file: identity_file,
            mutex,
            locked: true,
        })
    }

    fn unlock(&mut self) -> DbResult<()> {
        if !self.locked {
            return Ok(());
        }
        #[cfg(unix)]
        FileExt::unlock(&self.lock_file).map_err(|_| StorageError::WorkerStopped)?;
        #[cfg(windows)]
        if unsafe { windows_sys::Win32::System::Threading::ReleaseMutex(self.mutex) } == 0 {
            return Err(StorageError::WorkerStopped);
        }
        self.locked = false;
        Ok(())
    }
}

#[cfg(windows)]
impl Drop for DatabaseOwnership {
    fn drop(&mut self) {
        if self.locked {
            let _ = unsafe { windows_sys::Win32::System::Threading::ReleaseMutex(self.mutex) };
        }
        let _ = unsafe { windows_sys::Win32::Foundation::CloseHandle(self.mutex) };
    }
}

fn open_database_identity_file(path: &Path) -> DbResult<File> {
    OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(false)
        .open(path)
        .map_err(|_| StorageError::WorkerStopped)
}

#[cfg(windows)]
fn database_file_identity(file: &File) -> DbResult<String> {
    use std::{mem::MaybeUninit, os::windows::io::AsRawHandle};
    use windows_sys::Win32::{
        Foundation::HANDLE,
        Storage::FileSystem::{GetFileInformationByHandle, BY_HANDLE_FILE_INFORMATION},
    };
    let mut information = MaybeUninit::<BY_HANDLE_FILE_INFORMATION>::uninit();
    let succeeded = unsafe {
        GetFileInformationByHandle(file.as_raw_handle() as HANDLE, information.as_mut_ptr())
    };
    if succeeded == 0 {
        return Err(StorageError::WorkerStopped);
    }
    let information = unsafe { information.assume_init() };
    Ok(format!(
        "{:08x}-{:08x}{:08x}",
        information.dwVolumeSerialNumber, information.nFileIndexHigh, information.nFileIndexLow
    ))
}

#[cfg(not(any(unix, windows)))]
struct DatabaseOwnership;

#[cfg(not(any(unix, windows)))]
impl DatabaseOwnership {
    fn acquire(_path: &Path) -> DbResult<Self> {
        Err(StorageError::UnsupportedOperation {
            operation: "database file ownership on this platform",
        })
    }

    fn unlock(&mut self) -> DbResult<()> {
        Err(StorageError::UnsupportedOperation {
            operation: "database file ownership on this platform",
        })
    }
}

fn open_connection(
    path: &Path,
    path_exists: bool,
    require_full: bool,
) -> DbResult<(Connection, SchemaMode)> {
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
            if require_full {
                create_full_schema(&mut connection)?;
                return Ok((connection, SchemaMode::Full));
            }
            create_rust_schema(&mut connection)?;
            return Ok((connection, SchemaMode::Bootstrap));
        }
        if migration::is_supported_legacy_schema(&connection)?.is_some() {
            if require_full {
                return Err(StorageError::LegacyUpgradeRequired);
            }
            connection.pragma_update(None, "query_only", "ON")?;
            return Ok((connection, SchemaMode::LegacyReadOnly));
        }
    } else if application_id == APP_ID
        && version == SCHEMA_VERSION
        && validate_rust_schema(&connection)?
    {
        if require_full {
            return Err(StorageError::BootstrapUpgradeRequired);
        }
        return Ok((connection, SchemaMode::Bootstrap));
    } else if application_id == APP_ID
        && version == FULL_SCHEMA_VERSION
        && migration::validate_full_schema(&connection)?
    {
        return Ok((connection, SchemaMode::Full));
    }

    Err(StorageError::UnsupportedSchema {
        application_id,
        version,
    })
}

fn create_full_schema(connection: &mut Connection) -> DbResult<()> {
    let transaction = connection.transaction()?;
    transaction.execute_batch(FULL_SCHEMA)?;
    transaction.execute(
        "INSERT INTO rust_schema_migrations(version,name,applied_at) VALUES(2,'rust-full-v2-fresh',strftime('%Y-%m-%dT%H:%M:%fZ','now'))",
        [],
    )?;
    transaction.pragma_update(None, "application_id", APP_ID)?;
    transaction.pragma_update(None, "user_version", FULL_SCHEMA_VERSION)?;
    transaction.commit()?;
    Ok(())
}

fn count_user_objects(connection: &Connection) -> DbResult<i64> {
    Ok(connection.query_row(
        "SELECT count(*) FROM sqlite_master WHERE name NOT GLOB 'sqlite_*'",
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
        "SELECT type, name, sql FROM sqlite_master WHERE name NOT GLOB 'sqlite_*' ORDER BY type,name",
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
        if actual_kind != kind || actual_schema != schema {
            return Ok(false);
        }
    }
    Ok(true)
}

fn handle_request(connection: &mut Connection, mode: SchemaMode, request: Request) {
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
            let result = match mode {
                SchemaMode::LegacyReadOnly => Err(StorageError::ReadOnlyLegacy),
                SchemaMode::Full => Err(StorageError::UnsupportedOperation {
                    operation: "raw full-v2 setting mutation",
                }),
                SchemaMode::Bootstrap => set_value(connection, &key, &value),
            };
            let _ = reply.send(result);
        }
        Request::SetAndBump(key, value, topic, reply) => {
            let result = if mode != SchemaMode::Full {
                Err(StorageError::UnsupportedOperation {
                    operation: "set_with_revision",
                })
            } else {
                validate_full_setting(&key, &value, &topic)
                    .and_then(|()| set_and_bump(connection, &key, &value, &topic))
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
            let result = if mode != SchemaMode::Bootstrap {
                Err(StorageError::ReadOnlyLegacy)
            } else {
                create_profile(connection, name)
            };
            let _ = reply.send(result);
        }
        Request::GetProfile(id, reply) => {
            let table = if mode != SchemaMode::Bootstrap {
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
            let result = if mode != SchemaMode::Bootstrap {
                Err(StorageError::ReadOnlyLegacy)
            } else {
                delete_profile(connection, id)
            };
            let _ = reply.send(result);
        }
        Request::SetProfileValue(id, key, value, reply) => {
            let result = if mode != SchemaMode::Bootstrap {
                Err(StorageError::ReadOnlyLegacy)
            } else {
                set_profile_value(connection, id, &key, &value)
            };
            let _ = reply.send(result);
        }
        Request::ProfileValue(id, key, reply) => {
            let result = connection
                .query_row(
                    if mode == SchemaMode::Bootstrap {
                        "SELECT value FROM profile_settings WHERE profile_id=?1 AND key=?2"
                    } else {
                        "SELECT NULL WHERE 0"
                    },
                    (id.0, &key),
                    |row| row.get(0),
                )
                .optional()
                .map_err(StorageError::from);
            let _ = reply.send(result);
        }
        Request::AllocateEpoch(reply) => {
            let result = if mode != SchemaMode::Full {
                Err(StorageError::UnsupportedOperation {
                    operation: "allocate_epoch",
                })
            } else {
                allocate_epoch(connection)
            };
            let _ = reply.send(result);
        }
        Request::Revision(topic, reply) => {
            let result = if mode != SchemaMode::Full {
                Err(StorageError::UnsupportedOperation {
                    operation: "revision",
                })
            } else {
                revision(connection, &topic).map(|metadata| metadata.revision)
            };
            let _ = reply.send(result);
        }
        Request::BumpRevision(topic, reply) => {
            let result = if mode != SchemaMode::Full {
                Err(StorageError::UnsupportedOperation {
                    operation: "bump_revision",
                })
            } else {
                bump_revision(connection, &topic)
            };
            let _ = reply.send(result);
        }
        Request::SettingsSnapshot(reply) => {
            let result = if mode != SchemaMode::Full {
                Err(StorageError::UnsupportedOperation {
                    operation: "settings_snapshot",
                })
            } else {
                settings_snapshot(connection)
            };
            let _ = reply.send(result);
        }
        Request::ConfigurationsSnapshot(reply) => {
            let result = if mode != SchemaMode::Full {
                Err(StorageError::UnsupportedOperation {
                    operation: "configurations_snapshot",
                })
            } else {
                configurations_snapshot(connection)
            };
            let _ = reply.send(result);
        }
        Request::TrainsSnapshot(reply) => {
            let result = if mode != SchemaMode::Full {
                Err(StorageError::UnsupportedOperation {
                    operation: "trains_snapshot",
                })
            } else {
                trains_snapshot(connection)
            };
            let _ = reply.send(result);
        }
        Request::Hardware(job) => job(connection, mode),
    }
}

fn metadata_key(topic: &str) -> DbResult<String> {
    match topic {
        "settings" | "hardware" | "trains" | "bindings" | "scripts" | "firmware" => {
            Ok(format!("__runtime.revision.{topic}"))
        }
        _ => Err(StorageError::UnsupportedOperation {
            operation: "unknown_topic",
        }),
    }
}

fn read_u64(connection: &Connection, key: &str, default: u64) -> DbResult<u64> {
    let value: Option<String> = connection
        .query_row(
            "SELECT value FROM app_settings WHERE key=?1",
            [key],
            |row| row.get(0),
        )
        .optional()?;
    match value {
        Some(value) => parse_u64_metadata(&value),
        None => Ok(default),
    }
}

fn metadata(connection: &Connection, topic: &str) -> DbResult<RuntimeMetadata> {
    Ok(RuntimeMetadata {
        epoch: read_u64(connection, "__runtime.epoch", 0)?,
        revision: read_u64(connection, &metadata_key(topic)?, 0)?,
    })
}

fn revision(connection: &Connection, topic: &str) -> DbResult<RuntimeMetadata> {
    metadata(connection, topic)
}

fn allocate_epoch(connection: &mut Connection) -> DbResult<u64> {
    let transaction = connection.transaction()?;
    let current = validate_runtime_metadata(&transaction)?;
    let current = current.map_or(0, |metadata| metadata.epoch);
    let next = current
        .checked_add(1)
        .ok_or_else(|| StorageError::InvalidLegacyData {
            detail: "runtime epoch counter is exhausted".into(),
        })?;
    transaction.execute(
        "INSERT INTO app_settings(key,value) VALUES('__runtime.epoch',?1) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        [next.to_string()],
    )?;
    for topic in [
        "settings", "hardware", "trains", "bindings", "scripts", "firmware",
    ] {
        transaction.execute(
            "INSERT INTO app_settings(key,value) VALUES(?1,'0') ON CONFLICT(key) DO UPDATE SET value='0'",
            [metadata_key(topic)?],
        )?;
    }
    transaction.commit()?;
    Ok(next)
}

fn parse_u64_metadata(value: &str) -> DbResult<u64> {
    let parsed = value
        .parse::<u64>()
        .map_err(|_| StorageError::InvalidLegacyData {
            detail: "runtime metadata is malformed".into(),
        })?;
    if parsed.to_string() != value {
        return Err(StorageError::InvalidLegacyData {
            detail: "runtime metadata is malformed".into(),
        });
    }
    Ok(parsed)
}

fn validate_runtime_metadata(connection: &Connection) -> DbResult<Option<RuntimeMetadata>> {
    let rows = connection
        .prepare("SELECT key,value FROM app_settings WHERE key LIKE '__runtime.%'")?
        .query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
        })?
        .collect::<Result<Vec<_>, _>>()?;
    if rows.is_empty() {
        return Ok(None);
    }
    let mut known = BTreeMap::new();
    known.insert("__runtime.epoch".to_owned(), None);
    for topic in [
        "settings", "hardware", "trains", "bindings", "scripts", "firmware",
    ] {
        known.insert(format!("__runtime.revision.{topic}"), None);
    }
    for (key, value) in rows {
        let Some(slot) = known.get_mut(&key) else {
            return Err(StorageError::InvalidLegacyData {
                detail: "runtime metadata is incomplete or unknown".into(),
            });
        };
        if slot.replace(parse_u64_metadata(&value)?).is_some() {
            return Err(StorageError::InvalidLegacyData {
                detail: "runtime metadata is duplicated".into(),
            });
        }
    }
    if known.values().any(Option::is_none) {
        return Err(StorageError::InvalidLegacyData {
            detail: "runtime metadata is incomplete".into(),
        });
    }
    let epoch = known["__runtime.epoch"].unwrap();
    if epoch == 0 {
        return Err(StorageError::InvalidLegacyData {
            detail: "runtime epoch has not been initialized".into(),
        });
    }
    Ok(Some(RuntimeMetadata { epoch, revision: 0 }))
}

fn validate_full_setting(key: &str, value: &str, topic: &str) -> DbResult<()> {
    if topic != "settings" {
        return Err(StorageError::UnsupportedOperation {
            operation: "setting revision topic",
        });
    }
    match key {
        "error_reporting" if matches!(value, "enabled" | "disabled") => Ok(()),
        "simulator_url" => {
            let parsed = reqwest::Url::parse(value.trim()).ok();
            if parsed.as_ref().is_some_and(|parsed| {
                matches!(parsed.scheme(), "http" | "https")
                    && parsed.host_str().is_some()
                    && parsed.username().is_empty()
                    && parsed.password().is_none()
                    && parsed.query().is_none()
                    && parsed.fragment().is_none()
            }) {
                Ok(())
            } else {
                Err(StorageError::InvalidSetting {
                    key: "simulator_url",
                })
            }
        }
        "simulator_api_key" if !value.trim().is_empty() && !value.contains('\0') => Ok(()),
        "error_reporting" | "simulator_api_key" => Err(StorageError::InvalidSetting {
            key: if key == "error_reporting" {
                "error_reporting"
            } else {
                "simulator_api_key"
            },
        }),
        _ if key.starts_with("__runtime.") => Err(StorageError::UnsupportedOperation {
            operation: "reserved runtime metadata mutation",
        }),
        _ => Err(StorageError::UnsupportedOperation {
            operation: "unknown full-v2 setting",
        }),
    }
}

fn bump_revision(connection: &mut Connection, topic: &str) -> DbResult<RuntimeMetadata> {
    let key = metadata_key(topic)?;
    if validate_runtime_metadata(connection)?.is_none() {
        return Err(StorageError::InvalidLegacyData {
            detail: "runtime metadata has not been initialized".into(),
        });
    }
    let transaction = connection.transaction()?;
    let current = read_u64(&transaction, &key, 0)?;
    let next = current
        .checked_add(1)
        .ok_or_else(|| StorageError::InvalidLegacyData {
            detail: "topic revision counter is exhausted".into(),
        })?;
    transaction.execute(
        "INSERT INTO app_settings(key,value) VALUES(?1,?2) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        (&key, next.to_string()),
    )?;
    let epoch = read_u64(&transaction, "__runtime.epoch", 0)?;
    transaction.commit()?;
    Ok(RuntimeMetadata {
        epoch,
        revision: next,
    })
}

fn set_and_bump(
    connection: &mut Connection,
    key: &str,
    value: &str,
    topic: &str,
) -> DbResult<RuntimeMetadata> {
    let revision_key = metadata_key(topic)?;
    if validate_runtime_metadata(connection)?.is_none() {
        return Err(StorageError::InvalidLegacyData {
            detail: "runtime metadata has not been initialized".into(),
        });
    }
    let transaction = connection.transaction()?;
    transaction.execute(
        "INSERT INTO app_settings(key,value) VALUES(?1,?2) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        (key, value),
    )?;
    let revision = read_u64(&transaction, &revision_key, 0)?;
    let next = revision
        .checked_add(1)
        .ok_or_else(|| StorageError::InvalidLegacyData {
            detail: "topic revision counter is exhausted".into(),
        })?;
    transaction.execute(
        "INSERT INTO app_settings(key,value) VALUES(?1,?2) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
        (&revision_key, next.to_string()),
    )?;
    let epoch = read_u64(&transaction, "__runtime.epoch", 0)?;
    transaction.commit()?;
    Ok(RuntimeMetadata {
        epoch,
        revision: next,
    })
}

fn settings_snapshot(
    connection: &Connection,
) -> DbResult<(BTreeMap<String, String>, RuntimeMetadata)> {
    let mut statement = connection.prepare(
        "SELECT key,value FROM app_settings WHERE key NOT LIKE '__runtime.%' ORDER BY key",
    )?;
    let rows = statement.query_map([], |row| Ok((row.get(0)?, row.get(1)?)))?;
    let values = rows.collect::<Result<BTreeMap<String, String>, _>>()?;
    Ok((values, metadata(connection, "settings")?))
}

fn configurations_snapshot(
    connection: &Connection,
) -> DbResult<(Vec<ConfigurationRecord>, RuntimeMetadata)> {
    let mut statement = connection.prepare(
        "SELECT config_id,COALESCE(name,''),description,(SELECT COUNT(*) FROM device_inputs WHERE device_id=devices.id) FROM devices WHERE config_id IS NOT NULL ORDER BY config_id",
    )?;
    let rows = statement.query_map([], |row| {
        Ok(ConfigurationRecord {
            config_id: row.get(0)?,
            name: row.get(1)?,
            description: row.get(2)?,
            input_count: row.get(3)?,
        })
    })?;
    Ok((
        rows.collect::<Result<Vec<_>, _>>()?,
        metadata(connection, "hardware")?,
    ))
}

fn trains_snapshot(connection: &Connection) -> DbResult<(Vec<TrainRecord>, RuntimeMetadata)> {
    let mut statement = connection.prepare(
        "SELECT t.id,t.name,t.description,COUNT(DISTINCT e.id) FROM trains t LEFT JOIN train_elements e ON e.train_id=t.id GROUP BY t.id ORDER BY t.id",
    )?;
    let rows = statement.query_map([], |row| {
        Ok((
            EntityId(row.get(0)?),
            row.get::<_, String>(1)?,
            row.get::<_, Option<String>>(2)?,
            row.get::<_, u32>(3)?,
        ))
    })?;
    let mut trains = Vec::new();
    for row in rows {
        let (id, name, description, element_count) = row?;
        let mut identifiers = connection.prepare(
            "SELECT identifier FROM train_identifiers WHERE train_id=?1 ORDER BY identifier",
        )?;
        let identifiers = identifiers
            .query_map([id.0], |row| row.get(0))?
            .collect::<Result<Vec<String>, _>>()?;
        trains.push(TrainRecord {
            id,
            name,
            description,
            identifiers,
            element_count,
        });
    }
    Ok((trains, metadata(connection, "trains")?))
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
