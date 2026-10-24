//! Durable application preferences. API keys are never included in public snapshots.
use crate::storage::{Database, StorageError};
use std::{collections::BTreeMap, path::PathBuf};
const DEFAULT_SIMULATOR_URL: &str = "http://localhost:31270";
#[derive(Clone)]
pub struct Settings {
    db: Database,
    api_key_file: Option<PathBuf>,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct PublicSettings {
    pub error_reporting_consent: Option<bool>,
    pub simulator_url: String,
    pub simulator_api_key_configured: bool,
    pub values: BTreeMap<String, String>,
}
impl Settings {
    pub fn new(db: Database) -> Self {
        Self {
            db,
            api_key_file: None,
        }
    }
    /// Configure the legacy discovered key file path. An explicitly stored key always wins.
    pub fn with_api_key_file(mut self, path: impl Into<PathBuf>) -> Self {
        self.api_key_file = Some(path.into());
        self
    }
    /// `None` means the user has not chosen; telemetry must remain disabled until then.
    pub fn error_reporting_consent(&self) -> Result<Option<bool>, StorageError> {
        match self.db.get("error_reporting")?.as_deref() {
            None => Ok(None),
            Some("enabled") => Ok(Some(true)),
            Some("disabled") => Ok(Some(false)),
            Some(_) => Ok(None),
        }
    }
    pub fn set_error_reporting_consent(&self, enabled: bool) -> Result<(), StorageError> {
        self.db.set(
            "error_reporting",
            if enabled { "enabled" } else { "disabled" },
        )
    }
    pub fn simulator_url(&self) -> Result<String, StorageError> {
        Ok(self
            .db
            .get("simulator_url")?
            .unwrap_or_else(|| DEFAULT_SIMULATOR_URL.to_owned()))
    }
    pub fn set_simulator_url(&self, url: &str) -> Result<(), StorageError> {
        self.db.set("simulator_url", url)
    }
    pub fn set_api_key(&self, key: &str) -> Result<(), StorageError> {
        self.db.set("simulator_api_key", key)
    }
    pub fn api_key(&self) -> Result<Option<String>, StorageError> {
        if let Some(value) = self.db.get("simulator_api_key")? {
            return Ok(Some(value));
        }
        Ok(self
            .api_key_file
            .as_ref()
            .and_then(|path| std::fs::read_to_string(path).ok())
            .map(|s| s.trim().to_owned())
            .filter(|s| !s.is_empty()))
    }
    pub fn public_snapshot(&self) -> Result<PublicSettings, StorageError> {
        Ok(PublicSettings {
            error_reporting_consent: self.error_reporting_consent()?,
            simulator_url: self.simulator_url()?,
            simulator_api_key_configured: self.api_key()?.is_some(),
            values: BTreeMap::new(),
        })
    }
    /// Store an arbitrary non-secret setting in the same transaction path.
    pub fn set_value(&self, key: &str, value: &str) -> Result<(), StorageError> {
        self.db.set(key, value)
    }
    pub fn count(&self) -> Result<u64, StorageError> {
        self.db.count()
    }
}
