//! Dedicated SQLite owner. The Rust bootstrap schema is isolated; current Ecto DBs are read-only.
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
#[derive(Debug)]
pub enum StorageError {
    Sqlite(rusqlite::Error),
    DatabaseFailure(String),
    UnsupportedSchema { application_id: i64, version: i64 },
    ReadOnlyLegacy,
    WorkerStopped,
    NotFound,
}
impl From<rusqlite::Error> for StorageError {
    fn from(e: rusqlite::Error) -> Self {
        Self::Sqlite(e)
    }
}
impl std::fmt::Display for StorageError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Sqlite(e) => write!(f, "database error: {e}"),
            Self::DatabaseFailure(e) => write!(f, "database operation failed: {e}"),
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
type Reply<T> = mpsc::Sender<Result<T, String>>;
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
    /// Open the isolated Rust test schema, or recognize the exact latest Ecto schema as read-only.
    pub fn open(path: impl AsRef<Path>) -> Result<Self, StorageError> {
        let path = path.as_ref().to_owned();
        let exists = path.exists();
        let (ready_tx, ready_rx) = mpsc::channel();
        let (tx, rx) = mpsc::sync_channel(QUEUE_BOUND);
        let join=thread::Builder::new().name("trenino-db".into()).spawn(move||{
            let result=(||->Result<(Connection,bool),StorageError>{
                let mut conn=if exists{Connection::open_with_flags(&path,rusqlite::OpenFlags::SQLITE_OPEN_READ_WRITE)?}else{Connection::open_with_flags(&path,rusqlite::OpenFlags::SQLITE_OPEN_READ_WRITE|rusqlite::OpenFlags::SQLITE_OPEN_CREATE)?};
                conn.pragma_update(None,"foreign_keys","ON")?;
                let app:i64=conn.pragma_query_value(None,"application_id",|r|r.get(0))?;let version:i64=conn.pragma_query_value(None,"user_version",|r|r.get(0))?;
                if app==0&&version==0{
                    let objects:i64=conn.query_row("SELECT count(*) FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",[],|r|r.get(0))?;
                    if objects==0{
                        let tx=conn.transaction()?;
                        tx.execute_batch("CREATE TABLE app_settings(key TEXT PRIMARY KEY NOT NULL,value TEXT NOT NULL); CREATE TABLE profiles(id INTEGER PRIMARY KEY,name TEXT NOT NULL UNIQUE); CREATE TABLE profile_settings(profile_id INTEGER NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,key TEXT NOT NULL,value TEXT NOT NULL,PRIMARY KEY(profile_id,key));")?;
                        tx.pragma_update(None,"application_id",APP_ID)?;tx.pragma_update(None,"user_version",SCHEMA_VERSION)?;tx.commit()?;return Ok((conn,false));
                    }
                    if is_current_ecto_schema(&conn)? {conn.pragma_update(None,"query_only","ON")?;return Ok((conn,true));}
                    return Err(StorageError::UnsupportedSchema{application_id:app,version});
                }
                if app==APP_ID&&version==SCHEMA_VERSION{return Ok((conn,false));}
                Err(StorageError::UnsupportedSchema{application_id:app,version})
            })();
            let(mut conn,legacy)=match result{Ok(v)=>v,Err(e)=>{let _=ready_tx.send(Err(e));return}};let _=ready_tx.send(Ok(legacy));
            for req in rx{match req{
                Request::Get(k,r)=>{let x=conn.query_row("SELECT value FROM app_settings WHERE key=?1",[&k],|q|q.get(0)).optional().map_err(|e|e.to_string());let _=r.send(x);}
                Request::Set(k,v,r)=>{let x=(||->rusqlite::Result<()>{let tx=conn.transaction()?;tx.execute("INSERT INTO app_settings(key,value) VALUES(?1,?2) ON CONFLICT(key) DO UPDATE SET value=excluded.value",(&k,&v))?;tx.commit()})().map_err(|e|e.to_string());let _=r.send(x);}
                Request::Count(r)=>{let x=conn.query_row("SELECT count(*) FROM app_settings",[],|q|q.get::<_,u64>(0)).map_err(|e|e.to_string());let _=r.send(x);}
                Request::CreateProfile(name,r)=>{let x=(||->rusqlite::Result<Profile>{let tx=conn.transaction()?;tx.execute("INSERT INTO profiles(name) VALUES(?1)",[&name])?;let id=tx.last_insert_rowid();tx.commit()?;Ok(Profile{id:EntityId(id),name})})().map_err(|e|e.to_string());let _=r.send(x);}
                Request::GetProfile(id,r)=>{let sql=if legacy{"SELECT id,name FROM devices WHERE id=?1"}else{"SELECT id,name FROM profiles WHERE id=?1"};let x=conn.query_row(sql,[id.0],|q|Ok(Profile{id:EntityId(q.get(0)?),name:q.get(1)?})).optional().map_err(|e|e.to_string());let _=r.send(x);}
                Request::DeleteProfile(id,r)=>{let x=conn.execute("DELETE FROM profiles WHERE id=?1",[id.0]).map_err(|e|e.to_string()).and_then(|n|if n==0{Err("profile not found".into())}else{Ok(())});let _=r.send(x);}
                Request::SetProfileValue(id,k,v,r)=>{let x=(||->rusqlite::Result<()>{let tx=conn.transaction()?;tx.execute("INSERT INTO profile_settings(profile_id,key,value) VALUES(?1,?2,?3) ON CONFLICT(profile_id,key) DO UPDATE SET value=excluded.value",(id.0,&k,&v))?;tx.commit()})().map_err(|e|e.to_string());let _=r.send(x);}
                Request::ProfileValue(id,k,r)=>{let x=conn.query_row("SELECT value FROM profile_settings WHERE profile_id=?1 AND key=?2",(id.0,&k),|q|q.get(0)).optional().map_err(|e|e.to_string());let _=r.send(x);}
            }}
        }).map_err(|_|StorageError::WorkerStopped)?;
        let read_only = ready_rx.recv().map_err(|_| StorageError::WorkerStopped)??;
        Ok(Self {
            worker: Arc::new(Worker {
                tx: Mutex::new(Some(tx)),
                join: Mutex::new(Some(join)),
            }),
            read_only,
        })
    }
    pub fn is_legacy_read_only(&self) -> bool {
        self.read_only
    }
    pub fn get(&self, k: &str) -> Result<Option<String>, StorageError> {
        self.request(|r| Request::Get(k.into(), r))
    }
    pub fn set(&self, k: &str, v: &str) -> Result<(), StorageError> {
        if self.read_only {
            return Err(StorageError::ReadOnlyLegacy);
        }
        self.request(|r| Request::Set(k.into(), v.into(), r))
    }
    pub fn count(&self) -> Result<u64, StorageError> {
        self.request(Request::Count)
    }
    pub fn create_profile(&self, n: &str) -> Result<Profile, StorageError> {
        if self.read_only {
            return Err(StorageError::ReadOnlyLegacy);
        }
        self.request(|r| Request::CreateProfile(n.into(), r))
    }
    pub fn get_profile(&self, id: EntityId) -> Result<Option<Profile>, StorageError> {
        self.request(|r| Request::GetProfile(id, r))
    }
    pub fn delete_profile(&self, id: EntityId) -> Result<(), StorageError> {
        if self.read_only {
            return Err(StorageError::ReadOnlyLegacy);
        }
        self.request(|r| Request::DeleteProfile(id, r))
    }
    pub fn set_profile_value(&self, id: EntityId, k: &str, v: &str) -> Result<(), StorageError> {
        if self.read_only {
            return Err(StorageError::ReadOnlyLegacy);
        }
        self.request(|r| Request::SetProfileValue(id, k.into(), v.into(), r))
    }
    pub fn profile_value(&self, id: EntityId, k: &str) -> Result<Option<String>, StorageError> {
        self.request(|r| Request::ProfileValue(id, k.into(), r))
    }
    fn request<T>(&self, build: impl FnOnce(Reply<T>) -> Request) -> Result<T, StorageError> {
        let (tx, rx) = mpsc::channel();
        self.worker
            .tx
            .lock()
            .map_err(|_| StorageError::WorkerStopped)?
            .as_ref()
            .ok_or(StorageError::WorkerStopped)?
            .send(build(tx))
            .map_err(|_| StorageError::WorkerStopped)?;
        rx.recv()
            .map_err(|_| StorageError::WorkerStopped)?
            .map_err(StorageError::DatabaseFailure)
    }
}
fn is_current_ecto_schema(conn: &Connection) -> Result<bool, StorageError> {
    let exists: i64 = conn.query_row(
        "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='schema_migrations'",
        [],
        |r| r.get(0),
    )?;
    if exists == 0 {
        return Ok(false);
    }
    let latest: Option<i64> =
        conn.query_row("SELECT max(version) FROM schema_migrations", [], |r| {
            r.get(0)
        })?;
    if latest != Some(LEGACY_CURRENT_VERSION) {
        return Ok(false);
    }
    let tables:i64=conn.query_row("SELECT count(*) FROM sqlite_master WHERE type='table' AND name IN ('devices','app_settings','train_identifiers')",[],|r|r.get(0))?;
    if tables != 3 {
        return Ok(false);
    }
    let settings_cols: Vec<String> = {
        let mut stmt = conn.prepare("PRAGMA table_info(app_settings)")?;
        let rows = stmt.query_map([], |r| r.get(1))?;
        rows.collect::<Result<_, _>>()?
    };
    let device_cols: Vec<String> = {
        let mut stmt = conn.prepare("PRAGMA table_info(devices)")?;
        let rows = stmt.query_map([], |r| r.get(1))?;
        rows.collect::<Result<_, _>>()?
    };
    Ok(settings_cols.iter().any(|x| x == "key")
        && settings_cols.iter().any(|x| x == "value")
        && device_cols.iter().any(|x| x == "id")
        && device_cols.iter().any(|x| x == "name"))
}
