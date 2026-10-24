//! Application-facing repositories and committed UI snapshots.
use crate::storage::{ConfigurationRecord, Database, RuntimeMetadata, StorageError, TrainRecord};
use fs2::FileExt;
use std::{
    collections::BTreeMap,
    fs::{File, OpenOptions},
    path::{Path, PathBuf},
    sync::{
        atomic::{AtomicBool, Ordering},
        Mutex, MutexGuard,
    },
};
use trenino_core::ui::{
    ConfigurationSummaryView, ConsentState, SettingsView, SimulatorSettingsView, TrainSummaryView,
    UiSnapshot,
};
use trenino_core::{AppError, ConfigId, Epoch, ErrorCode, Revision, Topic};

const DEFAULT_SIMULATOR_URL: &str = "http://localhost:31270";

pub struct AppServices {
    db: Database,
    api_key_file: Option<PathBuf>,
    epoch: u64,
    operations: Mutex<()>,
    closed: AtomicBool,
    _instance_lock: File,
}

impl AppServices {
    /// Open a selected full-v2 database and start a new durable UI epoch.
    /// Fresh empty paths are initialized; any existing older schema is refused.
    pub fn open_full(
        path: impl AsRef<Path>,
        api_key_file: Option<PathBuf>,
    ) -> Result<Self, StorageError> {
        let path = path.as_ref();
        if let Some(parent) = path
            .parent()
            .filter(|parent| !parent.as_os_str().is_empty())
        {
            std::fs::create_dir_all(parent).map_err(|error| StorageError::Backup {
                detail: error.to_string(),
            })?;
        }
        let instance_lock = acquire_instance_lock(path)?;
        let db = Database::open_full(path)?;
        let epoch = db.allocate_epoch()?;
        Ok(Self {
            db,
            api_key_file,
            epoch,
            operations: Mutex::new(()),
            closed: AtomicBool::new(false),
            _instance_lock: instance_lock,
        })
    }

    pub fn epoch(&self) -> Epoch {
        Epoch(self.epoch)
    }

    pub fn get_settings(&self) -> Result<UiSnapshot<SettingsView>, AppError> {
        let _guard = self.begin_operation()?;
        let (values, metadata) = self.db.settings_snapshot().map_err(to_app_error)?;
        Ok(settings_snapshot(
            self.epoch,
            metadata,
            &values,
            self.discovered_api_key().is_some(),
        ))
    }

    pub fn set_consent(&self, enabled: bool) -> Result<UiSnapshot<SettingsView>, AppError> {
        let _guard = self.begin_operation()?;
        let metadata = self
            .db
            .set_with_revision(
                "error_reporting",
                if enabled { "enabled" } else { "disabled" },
                "settings",
            )
            .map_err(to_app_error)?;
        let (values, _) = self.db.settings_snapshot().map_err(to_app_error)?;
        Ok(settings_snapshot(
            self.epoch,
            metadata,
            &values,
            self.discovered_api_key().is_some(),
        ))
    }

    pub fn set_api_key(&self, key: &str) -> Result<UiSnapshot<SettingsView>, AppError> {
        let key = key.trim();
        if key.is_empty() {
            return Err(validation_error(
                "simulator_api_key",
                "API key cannot be empty.",
            ));
        }
        let _guard = self.begin_operation()?;
        let metadata = self
            .db
            .set_with_revision("simulator_api_key", key, "settings")
            .map_err(to_app_error)?;
        let (values, _) = self.db.settings_snapshot().map_err(to_app_error)?;
        Ok(settings_snapshot(self.epoch, metadata, &values, true))
    }

    /// Return the configured API key for a Rust simulator client. This method
    /// is internal service data and is never included in UI DTOs or errors.
    pub fn simulator_api_key(&self) -> Result<Option<String>, AppError> {
        let _guard = self.begin_operation()?;
        if let Some(key) = self.db.get("simulator_api_key").map_err(to_app_error)? {
            let key = key.trim().to_owned();
            if !key.is_empty() {
                return Ok(Some(key));
            }
        }
        Ok(self.api_key_file.as_deref().and_then(read_key))
    }

    pub fn set_simulator_url(&self, url: &str) -> Result<UiSnapshot<SettingsView>, AppError> {
        validate_simulator_url(url)?;
        let _guard = self.begin_operation()?;
        let metadata = self
            .db
            .set_with_revision("simulator_url", url.trim(), "settings")
            .map_err(to_app_error)?;
        let (values, _) = self.db.settings_snapshot().map_err(to_app_error)?;
        Ok(settings_snapshot(
            self.epoch,
            metadata,
            &values,
            self.discovered_api_key().is_some(),
        ))
    }

    pub fn list_configurations(
        &self,
    ) -> Result<UiSnapshot<Vec<ConfigurationSummaryView>>, AppError> {
        let _guard = self.begin_operation()?;
        let (records, metadata) = self.db.configurations_snapshot().map_err(to_app_error)?;
        let value = records
            .into_iter()
            .map(configuration_view)
            .collect::<Result<Vec<_>, _>>()?;
        Ok(UiSnapshot {
            epoch: Epoch(self.epoch),
            topic: Topic::Hardware,
            revision: Revision(metadata.revision),
            value,
        })
    }

    pub fn list_trains(&self) -> Result<UiSnapshot<Vec<TrainSummaryView>>, AppError> {
        let _guard = self.begin_operation()?;
        let (records, metadata) = self.db.trains_snapshot().map_err(to_app_error)?;
        let value = records.into_iter().map(train_view).collect();
        Ok(UiSnapshot {
            epoch: Epoch(self.epoch),
            topic: Topic::Trains,
            revision: Revision(metadata.revision),
            value,
        })
    }

    pub fn snapshot_json(&self, topic: Topic) -> Result<serde_json::Value, AppError> {
        match topic {
            Topic::Settings => {
                serde_json::to_value(self.get_settings()?).map_err(|_| internal_failure())
            }
            Topic::Hardware => {
                serde_json::to_value(self.list_configurations()?).map_err(|_| internal_failure())
            }
            Topic::Trains => {
                serde_json::to_value(self.list_trains()?).map_err(|_| internal_failure())
            }
            _ => Err(AppError {
                code: ErrorCode::Unavailable,
                message: "This section is not available in this version yet.".into(),
                field_errors: BTreeMap::new(),
                retryable: false,
            }),
        }
    }

    /// Stop admitting work and wait for an operation already inside the service
    /// boundary to finish. There are no hardware or network producers registered
    /// in this milestone; later services must join the app shutdown coordinator.
    pub fn quiesce(&self) {
        if let Ok(_guard) = self.operations.lock() {
            self.closed.store(true, Ordering::Release);
        } else {
            self.closed.store(true, Ordering::Release);
        }
    }

    fn begin_operation(&self) -> Result<MutexGuard<'_, ()>, AppError> {
        let guard = self.operations.lock().map_err(|_| internal_failure())?;
        if self.closed.load(Ordering::Acquire) {
            return Err(AppError {
                code: ErrorCode::Unavailable,
                message: "The application is shutting down.".into(),
                field_errors: BTreeMap::new(),
                retryable: true,
            });
        }
        Ok(guard)
    }

    fn discovered_api_key(&self) -> Option<String> {
        if let Some(path) = &self.api_key_file {
            return read_key(path);
        }
        None
    }
}

fn acquire_instance_lock(database_path: &Path) -> Result<File, StorageError> {
    let normalized = if database_path.exists() {
        std::fs::canonicalize(database_path)
    } else {
        let name = database_path
            .file_name()
            .ok_or_else(|| StorageError::Backup {
                detail: "database path must name a file".into(),
            })?;
        let parent = database_path
            .parent()
            .filter(|parent| !parent.as_os_str().is_empty())
            .unwrap_or_else(|| Path::new("."));
        std::fs::canonicalize(parent).map(|parent| parent.join(name))
    }
    .map_err(|error| StorageError::Backup {
        detail: error.to_string(),
    })?;
    let mut lock_name = normalized.as_os_str().to_owned();
    lock_name.push(".runtime.lock");
    let file = OpenOptions::new()
        .create(true)
        .truncate(false)
        .read(true)
        .write(true)
        .open(PathBuf::from(lock_name))
        .map_err(|error| StorageError::Backup {
            detail: error.to_string(),
        })?;
    file.try_lock_exclusive()
        .map_err(|_| StorageError::AlreadyRunning)?;
    Ok(file)
}

fn read_key(path: &Path) -> Option<String> {
    std::fs::read_to_string(path)
        .ok()
        .map(|key| key.trim().to_owned())
        .filter(|key| !key.is_empty())
}

fn settings_snapshot(
    epoch: u64,
    metadata: RuntimeMetadata,
    values: &BTreeMap<String, String>,
    file_key_configured: bool,
) -> UiSnapshot<SettingsView> {
    let consent = match values.get("error_reporting").map(String::as_str) {
        Some("enabled") => ConsentState::Enabled,
        Some("disabled") => ConsentState::Disabled,
        _ => ConsentState::Unset,
    };
    let url = values
        .get("simulator_url")
        .filter(|value| validate_simulator_url(value).is_ok())
        .cloned()
        .unwrap_or_else(|| DEFAULT_SIMULATOR_URL.to_owned());
    UiSnapshot {
        epoch: Epoch(epoch),
        topic: Topic::Settings,
        revision: Revision(metadata.revision),
        value: SettingsView {
            error_reporting: consent,
            simulator: SimulatorSettingsView {
                url,
                api_key_configured: file_key_configured
                    || values
                        .get("simulator_api_key")
                        .is_some_and(|key| !key.trim().is_empty()),
            },
        },
    }
}

fn configuration_view(record: ConfigurationRecord) -> Result<ConfigurationSummaryView, AppError> {
    let config_id = ConfigId::new(record.config_id)
        .map_err(|_| AppError::internal("A saved configuration has an invalid identifier."))?;
    Ok(ConfigurationSummaryView {
        config_id,
        name: record.name,
        input_count: record.input_count,
        description: record.description,
        active: false,
    })
}

fn train_view(record: TrainRecord) -> TrainSummaryView {
    TrainSummaryView {
        id: record.id,
        name: record.name,
        description: record.description,
        identifiers: record.identifiers,
        element_count: record.element_count,
        active: false,
    }
}

fn validate_simulator_url(value: &str) -> Result<(), AppError> {
    let parsed = reqwest::Url::parse(value.trim())
        .map_err(|_| validation_error("simulator_url", "Enter a valid HTTP or HTTPS URL."))?;
    if !matches!(parsed.scheme(), "http" | "https")
        || parsed.host_str().is_none()
        || !parsed.username().is_empty()
        || parsed.password().is_some()
        || parsed.query().is_some()
        || parsed.fragment().is_some()
    {
        return Err(validation_error(
            "simulator_url",
            "Enter a valid HTTP or HTTPS URL without credentials, query, or fragment.",
        ));
    }
    Ok(())
}

fn validation_error(field: &str, message: &str) -> AppError {
    AppError {
        code: ErrorCode::Validation,
        message: "Check the highlighted field.".into(),
        field_errors: BTreeMap::from([(field.into(), message.into())]),
        retryable: false,
    }
}

fn internal_failure() -> AppError {
    AppError::internal("The request could not be completed.")
}

fn to_app_error(error: StorageError) -> AppError {
    match error {
        StorageError::Conflict { .. } => AppError {
            code: ErrorCode::Conflict,
            message: "The saved data conflicts with another record.".into(),
            field_errors: BTreeMap::new(),
            retryable: false,
        },
        StorageError::NotFound => AppError {
            code: ErrorCode::NotFound,
            message: "The requested record was not found.".into(),
            field_errors: BTreeMap::new(),
            retryable: false,
        },
        StorageError::UnsupportedOperation { .. }
        | StorageError::ReadOnlyLegacy
        | StorageError::UnsupportedSchema { .. }
        | StorageError::BootstrapUpgradeRequired
        | StorageError::LegacyUpgradeRequired => AppError {
            code: ErrorCode::Unavailable,
            message: "This operation is unavailable for the selected database.".into(),
            field_errors: BTreeMap::new(),
            retryable: false,
        },
        _ => internal_failure(),
    }
}
