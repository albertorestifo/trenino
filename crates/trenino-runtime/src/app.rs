//! Application-facing repositories and committed UI snapshots.
use fs2::FileExt;
use std::{
    collections::BTreeMap,
    fs::{File, OpenOptions},
    path::{Path, PathBuf},
    sync::{
        atomic::{AtomicBool, AtomicU64, Ordering},
        Arc, Mutex, MutexGuard,
    },
};

use crate::hardware::repository::DatabaseHardwareRepository;
use crate::hardware::service::HardwareRepository;
use crate::storage::bindings::{
    BindOptions, ButtonBindingDraft, ButtonBindingPatch, ButtonBindingRecord, DisplayBindingDraft,
    DisplayBindingPatch, DisplayBindingRecord, OutputBindingDraft, OutputBindingPatch,
    OutputBindingRecord,
};
use crate::storage::firmware_records::{
    CatalogUpsert, FirmwareFileRecord, UpdateCheckDraft, UploadHistoryRecord,
    UploadStatus as UploadStatusRecord,
};
use crate::storage::scripts::{ScriptDraft, ScriptPatch, ScriptRecord};
use crate::storage::sequences::{SequenceCommandDraft, SequenceDraft, SequencePatch};
use crate::storage::trains::{
    ElementDraft, ElementKind, LeverConfigDraft, LeverConfigPatch, LeverType, NotchDraft,
    NotchPatch, RangesValidation, TrainDraft, TrainPatch, TrainRecord as TrainRecordFull,
};
use crate::storage::{
    ConfigurationRecord, Database, DeviceDraft, DevicePatch, DeviceRecord, HardwareSnapshot,
    Ht16k33Params, I2cModuleDraft, InputDraft, InputKind, InputRecord, MatrixDraft, OutputDraft,
    RuntimeMetadata, StorageError, TrainRecord,
};
use crate::vjoy::store::{MappingDraft, MappingRecord, Target};
use trenino_core::ui::{
    BindingsView, ButtonBindingView, CalibrationView, ConfigurationSummaryView, ConsentState,
    DeviceDetailView, DisplayBindingView, ElementView, FirmwareFileView, FirmwareReleaseView,
    FirmwareView, Ht16k33ParamsView, I2cModuleView, InputView, LeverBindingView, LeverConfigView,
    MatrixPinView, MatrixView, NotchRangeGapView, NotchRangesValidationView, NotchView,
    OutputBindingView, OutputView, ScriptView, ScriptsView, SequenceCommandView, SequenceView,
    SettingsView, SimulatorSettingsView, TrainDetailView, TrainSummaryView, UiSnapshot,
    UpdateCheckView, UploadHistoryView, VjoyMappingView, VjoyView,
};
use trenino_core::{AppError, ConfigId, EntityId, Epoch, ErrorCode, OperationId, Revision, Topic};
const DEFAULT_SIMULATOR_URL: &str = "http://localhost:31270";

/// Parameters for [`AppServices::create_input`].
pub struct CreateInputParams {
    pub device_id: EntityId,
    pub pin: i32,
    pub kind: String,
    pub sensitivity: Option<i32>,
    pub debounce: Option<i32>,
    pub name: Option<String>,
    pub matrix_id: Option<EntityId>,
}

/// Parameters for [`AppServices::create_lever`].
pub struct CreateLeverParams {
    pub element_id: EntityId,
    pub min_endpoint: String,
    pub max_endpoint: String,
    pub value_endpoint: String,
    pub notch_count_endpoint: Option<String>,
    pub notch_index_endpoint: Option<String>,
    pub lever_type: Option<String>,
    pub inverted: bool,
}

/// Parameters for [`AppServices::update_lever`].
pub struct UpdateLeverParams {
    pub lever_config_id: EntityId,
    pub min_endpoint: Option<String>,
    pub max_endpoint: Option<String>,
    pub value_endpoint: Option<String>,
    pub notch_count_endpoint: Option<Option<String>>,
    pub notch_index_endpoint: Option<Option<String>>,
    pub lever_type: Option<Option<String>>,
    pub inverted: Option<bool>,
}

pub struct AppServices {
    db: Arc<Database>,
    api_key_file: Option<PathBuf>,
    epoch: u64,
    operations: Mutex<()>,
    next_operation_id: AtomicU64,
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
            db: Arc::new(db),
            api_key_file,
            epoch,
            operations: Mutex::new(()),
            next_operation_id: AtomicU64::new(1),
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
            Topic::Bindings => {
                serde_json::to_value(self.get_bindings_snapshot()?).map_err(|_| internal_failure())
            }
            Topic::Scripts => {
                serde_json::to_value(self.get_scripts_snapshot()?).map_err(|_| internal_failure())
            }
            Topic::Firmware => {
                serde_json::to_value(self.get_firmware_snapshot()?).map_err(|_| internal_failure())
            }
            Topic::Vjoy => {
                serde_json::to_value(self.get_vjoy_snapshot()?).map_err(|_| internal_failure())
            }
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
        device_id: record.id,
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
        StorageError::Constraint { detail } | StorageError::InvalidHardware { detail } => {
            AppError {
                code: ErrorCode::Validation,
                message: "Check the highlighted field.".into(),
                field_errors: BTreeMap::from([("base".into(), detail)]),
                retryable: false,
            }
        }
        _ => internal_failure(),
    }
}

impl AppServices {
    /// Shared database handle for runtime services (hardware repository,
    /// vJoy store, firmware upload history). All mutations performed through
    /// the returned handle bypass the AppServices admission guard; runtime
    /// services must register with the shutdown coordinator instead.
    pub fn database(&self) -> Arc<Database> {
        self.db.clone()
    }

    /// Run one read-only or service-owned database operation under the
    /// epoch/admission guard. Use for command paths that need direct storage
    /// access (for example the firmware upload history port).
    pub fn database_op<T>(
        &self,
        operation: impl FnOnce(&Database) -> Result<T, AppError>,
    ) -> Result<T, AppError> {
        let _guard = self.begin_operation()?;
        operation(&self.db)
    }

    // ----- Read snapshots -------------------------------------------------

    pub fn get_hardware_detail(
        &self,
        device_id: EntityId,
    ) -> Result<UiSnapshot<DeviceDetailView>, AppError> {
        let _guard = self.begin_operation()?;
        self.hardware_detail_unguarded(device_id)
    }

    /// Resolves a device by its public firmware ConfigId (the Elixir route
    /// parameter) and returns the same detail snapshot as
    /// [`AppServices::get_hardware_detail`].
    pub fn get_hardware_detail_by_config(
        &self,
        config_id: ConfigId,
    ) -> Result<UiSnapshot<DeviceDetailView>, AppError> {
        let _guard = self.begin_operation()?;
        let device = self
            .database()
            .get_device_by_config_id(config_id)
            .map_err(to_app_error)?
            .ok_or_else(not_found("config_id"))?;
        self.hardware_detail_unguarded(device.id)
    }

    pub fn get_train_detail(
        &self,
        train_id: EntityId,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        let _guard = self.begin_operation()?;
        self.train_detail_unguarded(train_id)
    }

    pub fn get_bindings_snapshot(&self) -> Result<UiSnapshot<BindingsView>, AppError> {
        let _guard = self.begin_operation()?;
        self.bindings_snapshot_unguarded()
    }

    pub fn get_scripts_snapshot(&self) -> Result<UiSnapshot<ScriptsView>, AppError> {
        let _guard = self.begin_operation()?;
        self.scripts_snapshot_unguarded()
    }

    pub fn get_firmware_snapshot(&self) -> Result<UiSnapshot<FirmwareView>, AppError> {
        let _guard = self.begin_operation()?;
        self.firmware_snapshot_unguarded()
    }

    pub fn get_vjoy_snapshot(&self) -> Result<UiSnapshot<VjoyView>, AppError> {
        let _guard = self.begin_operation()?;
        self.vjoy_snapshot_unguarded()
    }

    /// Validates the stored notch input ranges of one lever
    /// (`Trenino.Train.validate_notch_ranges/1`): `:ok | {:error, :gaps_detected, gaps}`.
    pub fn validate_notch_ranges(
        &self,
        lever_config_id: EntityId,
    ) -> Result<UiSnapshot<NotchRangesValidationView>, AppError> {
        let _guard = self.begin_operation()?;
        let validation = self
            .db
            .validate_notch_ranges(lever_config_id)
            .map_err(to_app_error)?
            .ok_or_else(|| AppError {
                code: ErrorCode::NotFound,
                message: "The requested lever was not found.".into(),
                field_errors: BTreeMap::new(),
                retryable: false,
            })?;
        let revision = self.db.revision("trains").map_err(to_app_error)?;
        let value = match validation {
            RangesValidation::Valid => NotchRangesValidationView {
                valid: true,
                gaps: Vec::new(),
            },
            RangesValidation::Gaps(gaps) => NotchRangesValidationView {
                valid: false,
                gaps: gaps
                    .into_iter()
                    .map(|(from, to)| NotchRangeGapView { from, to })
                    .collect(),
            },
        };
        Ok(UiSnapshot {
            epoch: Epoch(self.epoch),
            topic: Topic::Trains,
            revision: Revision(revision),
            value,
        })
    }

    // ----- Unguarded readers (call with the operations guard held) --------

    fn configurations_snapshot_unguarded(
        &self,
    ) -> Result<UiSnapshot<Vec<ConfigurationSummaryView>>, AppError> {
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

    fn trains_snapshot_unguarded(&self) -> Result<UiSnapshot<Vec<TrainSummaryView>>, AppError> {
        let (records, metadata) = self.db.trains_snapshot().map_err(to_app_error)?;
        let value = records.into_iter().map(train_view).collect();
        Ok(UiSnapshot {
            epoch: Epoch(self.epoch),
            topic: Topic::Trains,
            revision: Revision(metadata.revision),
            value,
        })
    }

    fn hardware_detail_unguarded(
        &self,
        device_id: EntityId,
    ) -> Result<UiSnapshot<DeviceDetailView>, AppError> {
        let (snapshot, metadata) = self.db.hardware_snapshot().map_err(to_app_error)?;
        let device = snapshot
            .devices
            .iter()
            .find(|device| device.id == device_id)
            .ok_or_else(|| AppError {
                code: ErrorCode::NotFound,
                message: "The requested configuration was not found.".into(),
                field_errors: BTreeMap::new(),
                retryable: false,
            })?;
        let value = device_detail_view(device, &snapshot);
        Ok(UiSnapshot {
            epoch: Epoch(self.epoch),
            topic: Topic::Hardware,
            revision: Revision(metadata.revision),
            value,
        })
    }

    fn train_detail_unguarded(
        &self,
        train_id: EntityId,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        let record = self
            .db
            .get_train(train_id)
            .map_err(to_app_error)?
            .ok_or_else(|| AppError {
                code: ErrorCode::NotFound,
                message: "The requested train was not found.".into(),
                field_errors: BTreeMap::new(),
                retryable: false,
            })?;
        let revision = self.db.revision("trains").map_err(to_app_error)?;
        let value = train_detail_view(&self.db, record)?;
        Ok(UiSnapshot {
            epoch: Epoch(self.epoch),
            topic: Topic::Trains,
            revision: Revision(revision),
            value,
        })
    }

    fn bindings_snapshot_unguarded(&self) -> Result<UiSnapshot<BindingsView>, AppError> {
        let revision = self.db.revision("bindings").map_err(to_app_error)?;
        let mut view = BindingsView::default();
        for train in self.db.list_trains().map_err(to_app_error)? {
            for record in self
                .db
                .list_lever_bindings_for_train(train.id)
                .map_err(to_app_error)?
            {
                view.lever.push(LeverBindingView {
                    id: record.id,
                    lever_config_id: record.lever_config_id,
                    input_id: record.input_id,
                    enabled: record.enabled,
                });
            }
            for record in self
                .db
                .list_button_bindings_for_train(train.id)
                .map_err(to_app_error)?
            {
                view.button.push(button_binding_view(record));
            }
            for record in self
                .db
                .list_output_bindings(train.id)
                .map_err(to_app_error)?
            {
                view.output.push(output_binding_view(record));
            }
            for record in self
                .db
                .list_display_bindings(train.id)
                .map_err(to_app_error)?
            {
                view.display.push(display_binding_view(record));
            }
        }
        Ok(UiSnapshot {
            epoch: Epoch(self.epoch),
            topic: Topic::Bindings,
            revision: Revision(revision),
            value: view,
        })
    }

    fn scripts_snapshot_unguarded(&self) -> Result<UiSnapshot<ScriptsView>, AppError> {
        let revision = self.db.revision("scripts").map_err(to_app_error)?;
        let mut scripts = Vec::new();
        for train in self.db.list_trains().map_err(to_app_error)? {
            for record in self.db.list_scripts(train.id).map_err(to_app_error)? {
                scripts.push(script_view(record));
            }
        }
        Ok(UiSnapshot {
            epoch: Epoch(self.epoch),
            topic: Topic::Scripts,
            revision: Revision(revision),
            value: ScriptsView { scripts },
        })
    }

    fn firmware_snapshot_unguarded(&self) -> Result<UiSnapshot<FirmwareView>, AppError> {
        let metadata = self.db.firmware_metadata().map_err(to_app_error)?;
        let revision = metadata.revision;
        let mut releases = Vec::new();
        for release in self.db.list_firmware_releases().map_err(to_app_error)? {
            let files = self
                .db
                .firmware_files_for_release(release.id)
                .map_err(to_app_error)?
                .into_iter()
                .map(firmware_file_view)
                .collect();
            releases.push(FirmwareReleaseView {
                id: release.id,
                version: release.version,
                tag_name: release.tag_name,
                release_url: release.release_url,
                release_notes: release.release_notes,
                published_at: release.published_at,
                files,
            });
        }
        let update_checks = self
            .db
            .list_update_checks(10)
            .map_err(to_app_error)?
            .into_iter()
            .map(|row| UpdateCheckView {
                id: row.id,
                checked_at: row.checked_at,
                found_updates: row.found_updates,
                latest_version: row.latest_version,
                error_message: row.error_message,
            })
            .collect();
        let upload_history = self
            .db
            .list_upload_history(Some(50))
            .map_err(to_app_error)?
            .into_iter()
            .map(upload_history_view)
            .collect();
        Ok(UiSnapshot {
            epoch: Epoch(self.epoch),
            topic: Topic::Firmware,
            revision: Revision(revision),
            value: FirmwareView {
                releases,
                update_checks,
                upload_history,
            },
        })
    }

    fn vjoy_snapshot_unguarded(&self) -> Result<UiSnapshot<VjoyView>, AppError> {
        let revision = self.db.revision("vjoy").map_err(to_app_error)?;
        let configuration = self.db.vjoy_configuration().map_err(to_app_error)?;
        let selected_devices = self.db.vjoy_selected_devices().map_err(to_app_error)?;
        let mappings = self
            .db
            .vjoy_list_mappings()
            .map_err(to_app_error)?
            .into_iter()
            .map(vjoy_mapping_view)
            .collect();
        Ok(UiSnapshot {
            epoch: Epoch(self.epoch),
            topic: Topic::Vjoy,
            revision: Revision(revision),
            value: VjoyView {
                enabled: configuration.enabled,
                device_index: configuration.device_index,
                selected_devices,
                mappings,
            },
        })
    }

    // ----- Hardware configuration (device) CRUD ---------------------------

    pub fn create_configuration(
        &self,
        name: &str,
        description: Option<String>,
    ) -> Result<UiSnapshot<Vec<ConfigurationSummaryView>>, AppError> {
        validate_name(name, "name")?;
        let _guard = self.begin_operation()?;
        self.db
            .create_device(
                self.next_operation(),
                DeviceDraft {
                    name: name.trim().to_owned(),
                    description,
                    config_id: None,
                },
            )
            .map_err(to_app_error)?;
        self.configurations_snapshot_unguarded()
    }

    pub fn update_configuration(
        &self,
        device_id: EntityId,
        name: Option<String>,
        description: Option<Option<String>>,
    ) -> Result<UiSnapshot<Vec<ConfigurationSummaryView>>, AppError> {
        if let Some(name) = &name {
            validate_name(name, "name")?;
        }
        let _guard = self.begin_operation()?;
        self.db
            .update_device(
                self.next_operation(),
                device_id,
                DevicePatch {
                    name: name.map(|value| value.trim().to_owned()),
                    description,
                    config_id: None,
                },
            )
            .map_err(to_app_error)?;
        self.configurations_snapshot_unguarded()
    }

    /// Deletes one configuration and all of its child rows atomically.
    /// The hardware runtime's fail-closed deletion fence is enforced by the
    /// runtime service; at the storage boundary this commit is unconditional.
    pub fn delete_configuration(
        &self,
        device_id: EntityId,
    ) -> Result<UiSnapshot<Vec<ConfigurationSummaryView>>, AppError> {
        let _guard = self.begin_operation()?;
        DatabaseHardwareRepository::new(self.db.clone())
            .delete_device_unchecked(device_id)
            .map_err(|detail| constraint_error("base", &detail))?;
        self.configurations_snapshot_unguarded()
    }

    // ----- Hardware inputs / outputs / matrices / I2C ----------------------

    pub fn create_input(
        &self,
        CreateInputParams {
            device_id,
            pin,
            kind,
            sensitivity,
            debounce,
            name,
            matrix_id,
        }: CreateInputParams,
    ) -> Result<UiSnapshot<DeviceDetailView>, AppError> {
        let kind = parse_input_kind(&kind)?;
        let _guard = self.begin_operation()?;
        self.db
            .create_input(
                self.next_operation(),
                device_id,
                InputDraft {
                    pin,
                    kind,
                    sensitivity,
                    debounce,
                    name,
                    matrix_id,
                },
            )
            .map_err(to_app_error)?;
        self.hardware_detail_unguarded(device_id)
    }

    pub fn update_input(
        &self,
        input_id: EntityId,
        pin: i32,
        kind: &str,
        sensitivity: Option<i32>,
        debounce: Option<i32>,
        name: Option<String>,
    ) -> Result<UiSnapshot<DeviceDetailView>, AppError> {
        let kind = parse_input_kind(kind)?;
        let _guard = self.begin_operation()?;
        let existing = self
            .db
            .get_input(input_id)
            .map_err(to_app_error)?
            .ok_or_else(not_found("input"))?;
        let device_id = self.device_of_input(input_id)?;
        self.db
            .update_input(
                self.next_operation(),
                input_id,
                InputDraft {
                    pin,
                    kind,
                    sensitivity,
                    debounce,
                    name,
                    matrix_id: existing.matrix_id,
                },
            )
            .map_err(to_app_error)?;
        self.hardware_detail_unguarded(device_id)
    }

    pub fn delete_input(
        &self,
        input_id: EntityId,
    ) -> Result<UiSnapshot<DeviceDetailView>, AppError> {
        let _guard = self.begin_operation()?;
        let device_id = self.device_of_input(input_id)?;
        self.db
            .delete_input(self.next_operation(), input_id)
            .map_err(to_app_error)?;
        self.hardware_detail_unguarded(device_id)
    }

    pub fn create_output(
        &self,
        device_id: EntityId,
        pin: i32,
        name: Option<String>,
    ) -> Result<UiSnapshot<DeviceDetailView>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .create_output(self.next_operation(), device_id, OutputDraft { pin, name })
            .map_err(to_app_error)?;
        self.hardware_detail_unguarded(device_id)
    }

    pub fn update_output(
        &self,
        output_id: EntityId,
        pin: i32,
        name: Option<String>,
    ) -> Result<UiSnapshot<DeviceDetailView>, AppError> {
        let _guard = self.begin_operation()?;
        let device_id = self
            .db
            .get_output(output_id)
            .map_err(to_app_error)?
            .ok_or_else(not_found("output"))?
            .device_id;
        self.db
            .update_output(self.next_operation(), output_id, OutputDraft { pin, name })
            .map_err(to_app_error)?;
        self.hardware_detail_unguarded(device_id)
    }

    pub fn delete_output(
        &self,
        output_id: EntityId,
    ) -> Result<UiSnapshot<DeviceDetailView>, AppError> {
        let _guard = self.begin_operation()?;
        let device_id = self
            .db
            .get_output(output_id)
            .map_err(to_app_error)?
            .ok_or_else(not_found("output"))?
            .device_id;
        self.db
            .delete_output(self.next_operation(), output_id)
            .map_err(to_app_error)?;
        self.hardware_detail_unguarded(device_id)
    }

    pub fn create_matrix(
        &self,
        device_id: EntityId,
        name: &str,
        row_pins: Vec<i32>,
        col_pins: Vec<i32>,
    ) -> Result<UiSnapshot<DeviceDetailView>, AppError> {
        validate_name(name, "name")?;
        let _guard = self.begin_operation()?;
        self.db
            .create_matrix(
                self.next_operation(),
                device_id,
                MatrixDraft {
                    name: name.trim().to_owned(),
                    row_pins,
                    col_pins,
                },
            )
            .map_err(to_app_error)?;
        self.hardware_detail_unguarded(device_id)
    }

    pub fn update_matrix(
        &self,
        matrix_id: EntityId,
        row_pins: Vec<i32>,
        col_pins: Vec<i32>,
    ) -> Result<UiSnapshot<DeviceDetailView>, AppError> {
        let _guard = self.begin_operation()?;
        let device_id = self
            .db
            .get_matrix(matrix_id)
            .map_err(to_app_error)?
            .ok_or_else(not_found("matrix"))?
            .device_id;
        self.db
            .replace_matrix_children(self.next_operation(), matrix_id, row_pins, col_pins)
            .map_err(to_app_error)?;
        self.hardware_detail_unguarded(device_id)
    }

    pub fn delete_matrix(
        &self,
        matrix_id: EntityId,
    ) -> Result<UiSnapshot<DeviceDetailView>, AppError> {
        let _guard = self.begin_operation()?;
        let device_id = self
            .db
            .get_matrix(matrix_id)
            .map_err(to_app_error)?
            .ok_or_else(not_found("matrix"))?
            .device_id;
        self.db
            .delete_matrix(self.next_operation(), matrix_id)
            .map_err(to_app_error)?;
        self.hardware_detail_unguarded(device_id)
    }

    pub fn create_i2c_module(
        &self,
        device_id: EntityId,
        name: Option<String>,
        module_chip: &str,
        i2c_address: i32,
        params: Option<Ht16k33Params>,
    ) -> Result<UiSnapshot<DeviceDetailView>, AppError> {
        validate_name(module_chip, "module_chip")?;
        let _guard = self.begin_operation()?;
        self.db
            .create_i2c_module(
                self.next_operation(),
                device_id,
                I2cModuleDraft {
                    name,
                    module_chip: module_chip.trim().to_owned(),
                    i2c_address,
                    params,
                },
            )
            .map_err(to_app_error)?;
        self.hardware_detail_unguarded(device_id)
    }

    pub fn update_i2c_module(
        &self,
        module_id: EntityId,
        name: Option<String>,
        module_chip: &str,
        i2c_address: i32,
        params: Option<Ht16k33Params>,
    ) -> Result<UiSnapshot<DeviceDetailView>, AppError> {
        validate_name(module_chip, "module_chip")?;
        let _guard = self.begin_operation()?;
        let (snapshot, _) = self.db.hardware_snapshot().map_err(to_app_error)?;
        let device_id = snapshot
            .i2c_modules
            .iter()
            .find(|module| module.id == module_id)
            .ok_or_else(not_found("i2c_module"))?
            .device_id;
        self.db
            .update_i2c_module(
                self.next_operation(),
                module_id,
                I2cModuleDraft {
                    name,
                    module_chip: module_chip.trim().to_owned(),
                    i2c_address,
                    params,
                },
            )
            .map_err(to_app_error)?;
        self.hardware_detail_unguarded(device_id)
    }

    pub fn delete_i2c_module(
        &self,
        module_id: EntityId,
    ) -> Result<UiSnapshot<DeviceDetailView>, AppError> {
        let _guard = self.begin_operation()?;
        let (snapshot, _) = self.db.hardware_snapshot().map_err(to_app_error)?;
        let device_id = snapshot
            .i2c_modules
            .iter()
            .find(|module| module.id == module_id)
            .ok_or_else(not_found("i2c_module"))?
            .device_id;
        self.db
            .delete_i2c_module(self.next_operation(), module_id)
            .map_err(to_app_error)?;
        self.hardware_detail_unguarded(device_id)
    }

    // ----- Trains ---------------------------------------------------------

    pub fn create_train_entry(
        &self,
        name: &str,
        description: Option<String>,
        identifiers: Vec<String>,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        validate_name(name, "name")?;
        let identifiers = validate_identifiers(identifiers)?;
        let _guard = self.begin_operation()?;
        let mutation = self
            .db
            .create_train(
                self.next_operation(),
                TrainDraft {
                    name: name.trim().to_owned(),
                    description,
                    identifiers,
                },
            )
            .map_err(to_app_error)?;
        self.train_detail_unguarded(mutation.record.id)
    }

    pub fn update_train_entry(
        &self,
        train_id: EntityId,
        name: Option<String>,
        description: Option<Option<String>>,
        identifiers: Option<Vec<String>>,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        if let Some(name) = &name {
            validate_name(name, "name")?;
        }
        let identifiers = identifiers.map(validate_identifiers).transpose()?;
        let _guard = self.begin_operation()?;
        self.db
            .update_train(
                self.next_operation(),
                train_id,
                TrainPatch {
                    name: name.map(|value| value.trim().to_owned()),
                    description,
                    identifiers,
                },
            )
            .map_err(to_app_error)?;
        self.train_detail_unguarded(train_id)
    }

    pub fn delete_train_entry(
        &self,
        train_id: EntityId,
    ) -> Result<UiSnapshot<Vec<TrainSummaryView>>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .delete_train(self.next_operation(), train_id)
            .map_err(to_app_error)?;
        self.trains_snapshot_unguarded()
    }

    pub fn create_element(
        &self,
        train_id: EntityId,
        kind: &str,
        name: &str,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        let kind = parse_element_kind(kind)?;
        validate_name(name, "name")?;
        let _guard = self.begin_operation()?;
        self.db
            .create_train_element(
                self.next_operation(),
                train_id,
                ElementDraft {
                    kind,
                    name: name.trim().to_owned(),
                },
            )
            .map_err(to_app_error)?;
        self.train_detail_unguarded(train_id)
    }

    pub fn delete_element(
        &self,
        element_id: EntityId,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        let _guard = self.begin_operation()?;
        let train_id = self.train_of_element(element_id)?;
        self.db
            .delete_train_element(self.next_operation(), element_id)
            .map_err(to_app_error)?;
        self.train_detail_unguarded(train_id)
    }

    pub fn create_lever(
        &self,
        CreateLeverParams {
            element_id,
            min_endpoint,
            max_endpoint,
            value_endpoint,
            notch_count_endpoint,
            notch_index_endpoint,
            lever_type,
            inverted,
        }: CreateLeverParams,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        let lever_type = match lever_type.as_deref() {
            Some(value) => Some(parse_lever_type(value)?),
            None => None,
        };
        let _guard = self.begin_operation()?;
        let train_id = self.train_of_element(element_id)?;
        self.db
            .create_lever_config(
                self.next_operation(),
                element_id,
                LeverConfigDraft {
                    min_endpoint,
                    max_endpoint,
                    value_endpoint,
                    notch_count_endpoint,
                    notch_index_endpoint,
                    lever_type,
                    inverted,
                },
            )
            .map_err(to_app_error)?;
        self.train_detail_unguarded(train_id)
    }

    pub fn update_lever(
        &self,
        UpdateLeverParams {
            lever_config_id,
            min_endpoint,
            max_endpoint,
            value_endpoint,
            notch_count_endpoint,
            notch_index_endpoint,
            lever_type,
            inverted,
        }: UpdateLeverParams,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        let lever_type = match lever_type {
            Some(Some(value)) => Some(Some(parse_lever_type(&value)?)),
            Some(None) => Some(None),
            None => None,
        };
        let _guard = self.begin_operation()?;
        let train_id = self.train_of_lever(lever_config_id)?;
        self.db
            .update_lever_config(
                self.next_operation(),
                lever_config_id,
                LeverConfigPatch {
                    min_endpoint,
                    max_endpoint,
                    value_endpoint,
                    notch_count_endpoint,
                    notch_index_endpoint,
                    lever_type,
                    inverted,
                    calibrated_at: None,
                },
            )
            .map_err(to_app_error)?;
        self.train_detail_unguarded(train_id)
    }

    pub fn create_notch_entry(
        &self,
        lever_config_id: EntityId,
        draft: NotchDraft,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        let draft = round_notch_draft(draft);
        let _guard = self.begin_operation()?;
        let train_id = self.train_of_lever(lever_config_id)?;
        self.db
            .create_notch(self.next_operation(), lever_config_id, draft)
            .map_err(to_app_error)?;
        self.train_detail_unguarded(train_id)
    }

    pub fn update_notch_entry(
        &self,
        notch_id: EntityId,
        patch: NotchPatch,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        let patch = round_notch_patch(patch);
        let _guard = self.begin_operation()?;
        let train_id = self.train_of_notch(notch_id)?;
        self.db
            .update_notch(self.next_operation(), notch_id, patch)
            .map_err(to_app_error)?;
        self.train_detail_unguarded(train_id)
    }

    pub fn delete_notch_entry(
        &self,
        notch_id: EntityId,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        let _guard = self.begin_operation()?;
        let train_id = self.train_of_notch(notch_id)?;
        self.db
            .delete_notch(self.next_operation(), notch_id)
            .map_err(to_app_error)?;
        self.train_detail_unguarded(train_id)
    }

    /// Saves the full ordered notch list for one lever, assigning positions
    /// by list order (`Trenino.Train.save_notches/2`).
    pub fn save_notches(
        &self,
        lever_config_id: EntityId,
        notches: Vec<NotchDraft>,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        let notches = notches.into_iter().map(round_notch_draft).collect();
        let _guard = self.begin_operation()?;
        let train_id = self.train_of_lever(lever_config_id)?;
        self.db
            .save_notches(self.next_operation(), lever_config_id, notches)
            .map_err(to_app_error)?;
        self.train_detail_unguarded(train_id)
    }

    pub fn auto_distribute_notches(
        &self,
        lever_config_id: EntityId,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        let _guard = self.begin_operation()?;
        let train_id = self.train_of_lever(lever_config_id)?;
        self.db
            .auto_distribute_input_ranges(self.next_operation(), lever_config_id)
            .map_err(to_app_error)?;
        self.train_detail_unguarded(train_id)
    }

    // ----- Sequences ------------------------------------------------------

    pub fn create_sequence_entry(
        &self,
        train_id: EntityId,
        name: &str,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        validate_name(name, "name")?;
        let _guard = self.begin_operation()?;
        self.db
            .create_sequence(
                self.next_operation(),
                train_id,
                SequenceDraft {
                    name: name.trim().to_owned(),
                },
            )
            .map_err(to_app_error)?;
        self.train_detail_unguarded(train_id)
    }

    pub fn update_sequence_entry(
        &self,
        sequence_id: EntityId,
        name: Option<String>,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        if let Some(name) = &name {
            validate_name(name, "name")?;
        }
        let _guard = self.begin_operation()?;
        let train_id = self.train_of_sequence(sequence_id)?;
        self.db
            .update_sequence(
                self.next_operation(),
                sequence_id,
                SequencePatch {
                    name: name.map(|value| value.trim().to_owned()),
                },
            )
            .map_err(to_app_error)?;
        self.train_detail_unguarded(train_id)
    }

    pub fn delete_sequence_entry(
        &self,
        sequence_id: EntityId,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        let _guard = self.begin_operation()?;
        let train_id = self.train_of_sequence(sequence_id)?;
        self.db
            .delete_sequence(self.next_operation(), sequence_id)
            .map_err(to_app_error)?;
        self.train_detail_unguarded(train_id)
    }

    pub fn set_sequence_commands_entry(
        &self,
        sequence_id: EntityId,
        drafts: Vec<SequenceCommandDraft>,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        let drafts = drafts
            .into_iter()
            .map(|draft| SequenceCommandDraft {
                endpoint: draft.endpoint,
                value: round2(draft.value),
                delay_ms: draft.delay_ms,
            })
            .collect();
        let _guard = self.begin_operation()?;
        let train_id = self.train_of_sequence(sequence_id)?;
        self.db
            .set_sequence_commands(self.next_operation(), sequence_id, drafts)
            .map_err(to_app_error)?;
        self.train_detail_unguarded(train_id)
    }

    pub fn add_sequence_command_entry(
        &self,
        sequence_id: EntityId,
        draft: SequenceCommandDraft,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        let draft = SequenceCommandDraft {
            endpoint: draft.endpoint,
            value: round2(draft.value),
            delay_ms: draft.delay_ms,
        };
        let _guard = self.begin_operation()?;
        let train_id = self.train_of_sequence(sequence_id)?;
        self.db
            .add_sequence_command(self.next_operation(), sequence_id, draft)
            .map_err(to_app_error)?;
        self.train_detail_unguarded(train_id)
    }

    pub fn delete_sequence_command_entry(
        &self,
        command_id: EntityId,
    ) -> Result<UiSnapshot<TrainDetailView>, AppError> {
        let _guard = self.begin_operation()?;
        let sequence = self.sequence_of_command(command_id)?;
        self.db
            .delete_sequence_command(self.next_operation(), command_id)
            .map_err(to_app_error)?;
        self.train_detail_unguarded(sequence)
    }

    // ----- Bindings -------------------------------------------------------

    pub fn bind_lever(
        &self,
        lever_config_id: EntityId,
        input_id: EntityId,
        replace: bool,
    ) -> Result<UiSnapshot<BindingsView>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .bind_lever_input_with(
                self.next_operation(),
                lever_config_id,
                input_id,
                BindOptions { replace },
            )
            .map_err(to_app_error)?;
        self.bindings_snapshot_unguarded()
    }

    pub fn unbind_lever(
        &self,
        lever_config_id: EntityId,
    ) -> Result<UiSnapshot<BindingsView>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .unbind_lever_input(self.next_operation(), lever_config_id)
            .map_err(to_app_error)?;
        self.bindings_snapshot_unguarded()
    }

    pub fn set_lever_binding_enabled_entry(
        &self,
        lever_config_id: EntityId,
        enabled: bool,
    ) -> Result<UiSnapshot<BindingsView>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .set_lever_binding_enabled(self.next_operation(), lever_config_id, enabled)
            .map_err(to_app_error)?;
        self.bindings_snapshot_unguarded()
    }

    pub fn put_button_binding(
        &self,
        element_id: EntityId,
        input_id: EntityId,
        draft: ButtonBindingDraft,
        replace: bool,
    ) -> Result<UiSnapshot<BindingsView>, AppError> {
        let draft = round_button_draft(draft);
        let _guard = self.begin_operation()?;
        let existing = self
            .db
            .get_button_binding(element_id)
            .map_err(to_app_error)?;
        if existing.is_some() {
            self.db
                .update_button_binding_with(
                    self.next_operation(),
                    existing.expect("checked").id,
                    ButtonBindingPatch {
                        input_id: Some(input_id),
                        endpoint: draft.endpoint.map(Some),
                        on_value: draft.on_value,
                        off_value: draft.off_value,
                        enabled: draft.enabled,
                        mode: draft.mode,
                        hardware_type: draft.hardware_type,
                        repeat_interval_ms: draft.repeat_interval_ms,
                        keystroke: draft.keystroke.map(Some),
                        on_sequence_id: draft.on_sequence_id.map(Some),
                        off_sequence_id: draft.off_sequence_id.map(Some),
                    },
                    BindOptions { replace },
                )
                .map_err(to_app_error)?;
        } else {
            self.db
                .create_button_binding_with(
                    self.next_operation(),
                    element_id,
                    input_id,
                    draft,
                    BindOptions { replace },
                )
                .map_err(to_app_error)?;
        }
        self.bindings_snapshot_unguarded()
    }

    pub fn delete_button_binding_entry(
        &self,
        element_id: EntityId,
    ) -> Result<UiSnapshot<BindingsView>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .delete_button_binding(self.next_operation(), element_id)
            .map_err(to_app_error)?;
        self.bindings_snapshot_unguarded()
    }

    pub fn create_output_binding_entry(
        &self,
        train_id: EntityId,
        draft: OutputBindingDraft,
    ) -> Result<UiSnapshot<BindingsView>, AppError> {
        let draft = round_output_draft(draft);
        let _guard = self.begin_operation()?;
        self.db
            .create_output_binding(self.next_operation(), train_id, draft)
            .map_err(to_app_error)?;
        self.bindings_snapshot_unguarded()
    }

    pub fn update_output_binding_entry(
        &self,
        binding_id: EntityId,
        patch: OutputBindingPatch,
    ) -> Result<UiSnapshot<BindingsView>, AppError> {
        let patch = round_output_patch(patch);
        let _guard = self.begin_operation()?;
        self.db
            .update_output_binding(self.next_operation(), binding_id, patch)
            .map_err(to_app_error)?;
        self.bindings_snapshot_unguarded()
    }

    pub fn delete_output_binding_entry(
        &self,
        binding_id: EntityId,
    ) -> Result<UiSnapshot<BindingsView>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .delete_output_binding(self.next_operation(), binding_id)
            .map_err(to_app_error)?;
        self.bindings_snapshot_unguarded()
    }

    pub fn create_display_binding_entry(
        &self,
        train_id: EntityId,
        draft: DisplayBindingDraft,
    ) -> Result<UiSnapshot<BindingsView>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .create_display_binding(self.next_operation(), train_id, draft)
            .map_err(to_app_error)?;
        self.bindings_snapshot_unguarded()
    }

    pub fn update_display_binding_entry(
        &self,
        binding_id: EntityId,
        patch: DisplayBindingPatch,
    ) -> Result<UiSnapshot<BindingsView>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .update_display_binding(self.next_operation(), binding_id, patch)
            .map_err(to_app_error)?;
        self.bindings_snapshot_unguarded()
    }

    pub fn delete_display_binding_entry(
        &self,
        binding_id: EntityId,
    ) -> Result<UiSnapshot<BindingsView>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .delete_display_binding(self.next_operation(), binding_id)
            .map_err(to_app_error)?;
        self.bindings_snapshot_unguarded()
    }

    // ----- Scripts --------------------------------------------------------

    pub fn create_script_entry(
        &self,
        train_id: EntityId,
        name: &str,
        code: &str,
        triggers: Vec<String>,
    ) -> Result<UiSnapshot<ScriptsView>, AppError> {
        validate_name(name, "name")?;
        if code.trim().is_empty() {
            return Err(validation_error("code", "Script code cannot be empty."));
        }
        let triggers = validate_triggers(triggers)?;
        let _guard = self.begin_operation()?;
        self.db
            .create_script(
                self.next_operation(),
                train_id,
                ScriptDraft {
                    name: name.trim().to_owned(),
                    enabled: true,
                    code: code.to_owned(),
                    triggers,
                },
            )
            .map_err(to_app_error)?;
        self.scripts_snapshot_unguarded()
    }

    pub fn update_script_entry(
        &self,
        script_id: EntityId,
        patch: ScriptPatch,
    ) -> Result<UiSnapshot<ScriptsView>, AppError> {
        if let Some(name) = &patch.name {
            validate_name(name, "name")?;
        }
        if let Some(code) = &patch.code {
            if code.trim().is_empty() {
                return Err(validation_error("code", "Script code cannot be empty."));
            }
        }
        if let Some(triggers) = &patch.triggers {
            validate_triggers(triggers.clone())?;
        }
        let _guard = self.begin_operation()?;
        self.db
            .update_script(self.next_operation(), script_id, patch)
            .map_err(to_app_error)?;
        self.scripts_snapshot_unguarded()
    }

    pub fn delete_script_entry(
        &self,
        script_id: EntityId,
    ) -> Result<UiSnapshot<ScriptsView>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .delete_script(self.next_operation(), script_id)
            .map_err(to_app_error)?;
        self.scripts_snapshot_unguarded()
    }

    /// Re-reads the scripts topic. The per-train Lua engine subscribes to
    /// script-topic revisions and hot-reloads compiled scripts; wave-3
    /// controllers consume this same revision, so publication of the returned
    /// snapshot is the reload trigger.
    pub fn reload_scripts(&self) -> Result<UiSnapshot<ScriptsView>, AppError> {
        let _guard = self.begin_operation()?;
        self.scripts_snapshot_unguarded()
    }

    // ----- Virtual joystick ----------------------------------------------

    pub fn put_vjoy_mapping_entry(
        &self,
        input_id: EntityId,
        draft: MappingDraft,
        replace: bool,
    ) -> Result<UiSnapshot<VjoyView>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .vjoy_put_mapping(self.next_operation(), input_id, draft, replace)
            .map_err(to_app_error)?;
        self.vjoy_snapshot_unguarded()
    }

    pub fn delete_vjoy_mapping_entry(
        &self,
        mapping_id: EntityId,
    ) -> Result<UiSnapshot<VjoyView>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .vjoy_delete_mapping(self.next_operation(), mapping_id)
            .map_err(to_app_error)?;
        self.vjoy_snapshot_unguarded()
    }

    pub fn set_vjoy_selection(&self, devices: Vec<u8>) -> Result<UiSnapshot<VjoyView>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .vjoy_set_selected_devices(self.next_operation(), &devices)
            .map_err(to_app_error)?;
        self.vjoy_snapshot_unguarded()
    }

    /// Persists the requested-enable flag. Only call after the runtime vJoy
    /// manager confirmed the acquire/release transition (persist-after-confirm).
    pub fn confirm_vjoy_enabled(&self, enabled: bool) -> Result<UiSnapshot<VjoyView>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .vjoy_confirm_enabled(self.next_operation(), enabled)
            .map_err(to_app_error)?;
        self.vjoy_snapshot_unguarded()
    }

    // ----- Firmware -------------------------------------------------------

    /// Commits one catalog refresh (release + per-board files) fetched over
    /// the network by the caller (`Firmware.upsert_catalog/1`).
    pub fn refresh_firmware_catalog(
        &self,
        entries: Vec<CatalogUpsert>,
    ) -> Result<UiSnapshot<FirmwareView>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .upsert_catalog(self.next_operation(), entries)
            .map_err(to_app_error)?;
        self.firmware_snapshot_unguarded()
    }

    pub fn record_firmware_update_check(
        &self,
        draft: UpdateCheckDraft,
    ) -> Result<UiSnapshot<FirmwareView>, AppError> {
        let _guard = self.begin_operation()?;
        self.db
            .record_update_check(self.next_operation(), draft)
            .map_err(to_app_error)?;
        self.firmware_snapshot_unguarded()
    }

    // ----- Internal lookups (guard held) ----------------------------------

    fn next_operation(&self) -> OperationId {
        let sequence = self.next_operation_id.fetch_add(1, Ordering::Relaxed);
        OperationId(((self.epoch as u128) << 64) | sequence as u128)
    }

    fn device_of_input(&self, input_id: EntityId) -> Result<EntityId, AppError> {
        let input = self
            .db
            .get_input(input_id)
            .map_err(to_app_error)?
            .ok_or_else(not_found("input"))?;
        if let Some(device_id) = input.device_id {
            return Ok(device_id);
        }
        let matrix_id = input
            .matrix_id
            .ok_or_else(|| AppError::internal("A saved input has no owning device."))?;
        Ok(self
            .db
            .get_matrix(matrix_id)
            .map_err(to_app_error)?
            .ok_or_else(not_found("matrix"))?
            .device_id)
    }

    fn train_of_element(&self, element_id: EntityId) -> Result<EntityId, AppError> {
        Ok(self
            .db
            .get_train_element(element_id)
            .map_err(to_app_error)?
            .ok_or_else(not_found("element"))?
            .train_id)
    }

    fn train_of_lever(&self, lever_config_id: EntityId) -> Result<EntityId, AppError> {
        for train in self.db.list_trains().map_err(to_app_error)? {
            for element in train.elements {
                if element
                    .lever_config
                    .as_ref()
                    .is_some_and(|config| config.id == lever_config_id)
                {
                    return Ok(train.id);
                }
            }
        }
        Err(not_found("lever")())
    }

    fn train_of_notch(&self, notch_id: EntityId) -> Result<EntityId, AppError> {
        for train in self.db.list_trains().map_err(to_app_error)? {
            for element in train.elements {
                if let Some(config) = &element.lever_config {
                    if config.notches.iter().any(|notch| notch.id == notch_id) {
                        return Ok(train.id);
                    }
                }
            }
        }
        Err(not_found("notch")())
    }

    fn train_of_sequence(&self, sequence_id: EntityId) -> Result<EntityId, AppError> {
        for train in self.db.list_trains().map_err(to_app_error)? {
            if self
                .db
                .list_sequences(train.id)
                .map_err(to_app_error)?
                .iter()
                .any(|sequence| sequence.id == sequence_id)
            {
                return Ok(train.id);
            }
        }
        Err(not_found("sequence")())
    }

    fn sequence_of_command(&self, command_id: EntityId) -> Result<EntityId, AppError> {
        for train in self.db.list_trains().map_err(to_app_error)? {
            for sequence in self.db.list_sequences(train.id).map_err(to_app_error)? {
                if self
                    .db
                    .sequence_commands(sequence.id)
                    .map_err(to_app_error)?
                    .iter()
                    .any(|command| command.id == command_id)
                {
                    return Ok(train.id);
                }
            }
        }
        Err(not_found("sequence_command")())
    }
}

// ----- View mappers -------------------------------------------------------

fn device_detail_view(device: &DeviceRecord, snapshot: &HardwareSnapshot) -> DeviceDetailView {
    DeviceDetailView {
        id: device.id,
        name: device.name.clone(),
        description: device.description.clone(),
        config_id: device.config_id,
        inputs: snapshot
            .inputs
            .iter()
            .filter(|input| input.device_id == Some(device.id))
            .map(input_view)
            .collect(),
        outputs: snapshot
            .outputs
            .iter()
            .filter(|output| output.device_id == device.id)
            .map(|output| OutputView {
                id: output.id,
                pin: output.pin,
                name: output.name.clone(),
            })
            .collect(),
        matrices: snapshot
            .matrices
            .iter()
            .filter(|matrix| matrix.device_id == device.id)
            .map(|matrix| MatrixView {
                id: matrix.id,
                name: matrix.name.clone(),
                row_pins: matrix
                    .row_pins
                    .iter()
                    .map(|pin| MatrixPinView {
                        id: pin.id,
                        pin: pin.pin,
                        pin_type: pin.pin_type.as_db().to_owned(),
                        position: pin.position,
                    })
                    .collect(),
                col_pins: matrix
                    .col_pins
                    .iter()
                    .map(|pin| MatrixPinView {
                        id: pin.id,
                        pin: pin.pin,
                        pin_type: pin.pin_type.as_db().to_owned(),
                        position: pin.position,
                    })
                    .collect(),
                buttons: matrix.buttons.iter().map(input_view).collect(),
            })
            .collect(),
        i2c_modules: snapshot
            .i2c_modules
            .iter()
            .filter(|module| module.device_id == device.id)
            .map(|module| I2cModuleView {
                id: module.id,
                name: module.name.clone(),
                module_chip: module.module_chip.clone(),
                i2c_address: module.i2c_address,
                params: module.params.as_ref().map(|params| Ht16k33ParamsView {
                    brightness: params.brightness,
                    num_digits: params.num_digits,
                    display_type: serde_json::to_value(params.display_type)
                        .ok()
                        .and_then(|value| value.as_str().map(str::to_owned))
                        .unwrap_or_else(|| "seven_segment".into()),
                    has_dot: params.has_dot,
                    align_right: params.align_right,
                    min_value: params.min_value,
                }),
            })
            .collect(),
    }
}

fn input_view(input: &InputRecord) -> InputView {
    InputView {
        id: input.id,
        pin: input.pin,
        kind: match input.kind {
            Some(InputKind::Button) => "button".into(),
            _ => "analog".into(),
        },
        sensitivity: input.sensitivity,
        debounce: input.debounce,
        name: input.name.clone(),
        calibration: input.calibration.as_ref().map(|row| CalibrationView {
            min_value: row.value.min_value,
            max_value: row.value.max_value,
            has_rollover: row.value.has_rollover,
            is_inverted: row.value.is_inverted,
        }),
    }
}

fn train_detail_view(db: &Database, record: TrainRecordFull) -> Result<TrainDetailView, AppError> {
    let mut sequences = Vec::new();
    for sequence in db.list_sequences(record.id).map_err(to_app_error)? {
        let commands = db
            .sequence_commands(sequence.id)
            .map_err(to_app_error)?
            .into_iter()
            .map(|command| SequenceCommandView {
                id: command.id,
                position: command.position,
                endpoint: command.endpoint,
                value: command.value,
                delay_ms: command.delay_ms,
            })
            .collect();
        sequences.push(SequenceView {
            id: sequence.id,
            train_id: sequence.train_id,
            name: sequence.name,
            commands,
        });
    }
    Ok(TrainDetailView {
        id: record.id,
        name: record.name,
        description: record.description,
        identifiers: record.identifiers,
        elements: record
            .elements
            .into_iter()
            .map(|element| ElementView {
                id: element.id,
                kind: element.kind.as_db().to_owned(),
                name: element.name,
                lever_config: element.lever_config.map(|config| LeverConfigView {
                    id: config.id,
                    min_endpoint: config.min_endpoint,
                    max_endpoint: config.max_endpoint,
                    value_endpoint: config.value_endpoint,
                    notch_count_endpoint: config.notch_count_endpoint,
                    notch_index_endpoint: config.notch_index_endpoint,
                    lever_type: config.lever_type.map(|value| value.as_db().to_owned()),
                    inverted: config.inverted,
                    calibrated_at: config.calibrated_at,
                    notches: config
                        .notches
                        .into_iter()
                        .map(|notch| NotchView {
                            id: notch.id,
                            index: notch.index,
                            kind: notch.kind.as_db().to_owned(),
                            value: notch.value,
                            min_value: notch.min_value,
                            max_value: notch.max_value,
                            input_min: notch.input_min,
                            input_max: notch.input_max,
                            sim_input_min: notch.sim_input_min,
                            sim_input_max: notch.sim_input_max,
                            description: notch.description,
                        })
                        .collect(),
                }),
            })
            .collect(),
        sequences,
    })
}

fn button_binding_view(record: ButtonBindingRecord) -> ButtonBindingView {
    ButtonBindingView {
        id: record.id,
        element_id: record.element_id,
        input_id: record.input_id,
        endpoint: record.endpoint,
        on_value: record.on_value,
        off_value: record.off_value,
        enabled: record.enabled,
        mode: record.mode.as_db().to_owned(),
        hardware_type: record.hardware_type.as_db().to_owned(),
        repeat_interval_ms: record.repeat_interval_ms,
        keystroke: record.keystroke,
        on_sequence_id: record.on_sequence_id,
        off_sequence_id: record.off_sequence_id,
    }
}

fn output_binding_view(record: OutputBindingRecord) -> OutputBindingView {
    OutputBindingView {
        id: record.id,
        train_id: record.train_id,
        name: record.name,
        output_type: record.output_type.as_db().to_owned(),
        output_id: record.output_id,
        endpoint: record.endpoint,
        operator: record.operator.as_db().to_owned(),
        value_a: record.value_a,
        value_b: record.value_b,
        enabled: record.enabled,
    }
}

fn display_binding_view(record: DisplayBindingRecord) -> DisplayBindingView {
    DisplayBindingView {
        id: record.id,
        train_id: record.train_id,
        i2c_module_id: record.i2c_module_id,
        name: record.name,
        endpoint: record.endpoint,
        format_string: record.format_string,
        enabled: record.enabled,
        script_id: record.script_id,
    }
}

fn script_view(record: ScriptRecord) -> ScriptView {
    ScriptView {
        id: record.id,
        train_id: record.train_id,
        name: record.name,
        enabled: record.enabled,
        code: record.code,
        triggers: record.triggers,
    }
}

fn firmware_file_view(record: FirmwareFileRecord) -> FirmwareFileView {
    FirmwareFileView {
        id: record.id,
        release_id: record.release_id,
        board_type: record.board_type,
        environment: record.environment,
        download_url: record.download_url,
        file_size: record.file_size,
        checksum_sha256: record.checksum_sha256,
    }
}

fn upload_history_view(record: UploadHistoryRecord) -> UploadHistoryView {
    let status = match record.status {
        UploadStatusRecord::Started => "running",
        UploadStatusRecord::Completed => "success",
        UploadStatusRecord::Failed => "failed",
        UploadStatusRecord::Cancelled => "cancelled",
    };
    UploadHistoryView {
        id: record.id,
        upload_id: record.upload_id,
        port: record.port,
        board_type: record.board_type,
        firmware_file_id: record.firmware_file_id,
        status: status.to_owned(),
        error_message: record.error_message,
        duration_ms: record.duration_ms,
        started_at: record.started_at,
        completed_at: record.completed_at,
    }
}

fn vjoy_mapping_view(record: MappingRecord) -> VjoyMappingView {
    let target = match record.target {
        Target::Axis(axis) => format!("axis/{}", axis.as_db()),
        Target::Button(number) => format!("button/{number}"),
    };
    VjoyMappingView {
        id: record.id,
        input_id: record.input_id,
        device_index: record.device_index,
        target,
        inverted: record.inverted,
        input_kind: match record.input_kind {
            InputKind::Button => "button".into(),
            InputKind::Analog => "analog".into(),
        },
        input_pin: record.input_pin,
        input_device: record.input_device,
        input_name: record.input_name,
    }
}

// ----- Input parsing / validation -----------------------------------------

fn round2(value: f64) -> f64 {
    (value * 100.0).round() / 100.0
}

fn round_opt2(value: Option<f64>) -> Option<f64> {
    value.map(round2)
}

fn round_notch_draft(draft: NotchDraft) -> NotchDraft {
    NotchDraft {
        index: draft.index,
        kind: draft.kind,
        value: round_opt2(draft.value),
        min_value: round_opt2(draft.min_value),
        max_value: round_opt2(draft.max_value),
        input_min: round_opt2(draft.input_min),
        input_max: round_opt2(draft.input_max),
        sim_input_min: round_opt2(draft.sim_input_min),
        sim_input_max: round_opt2(draft.sim_input_max),
        description: draft.description,
    }
}

fn round_notch_patch(patch: NotchPatch) -> NotchPatch {
    NotchPatch {
        index: patch.index,
        kind: patch.kind,
        value: patch.value.map(round_opt2),
        min_value: patch.min_value.map(round_opt2),
        max_value: patch.max_value.map(round_opt2),
        input_min: patch.input_min.map(round_opt2),
        input_max: patch.input_max.map(round_opt2),
        sim_input_min: patch.sim_input_min.map(round_opt2),
        sim_input_max: patch.sim_input_max.map(round_opt2),
    }
}

fn round_button_draft(draft: ButtonBindingDraft) -> ButtonBindingDraft {
    ButtonBindingDraft {
        on_value: draft.on_value.map(round2),
        off_value: draft.off_value.map(round2),
        ..draft
    }
}

fn round_output_draft(draft: OutputBindingDraft) -> OutputBindingDraft {
    OutputBindingDraft {
        value_a: round_opt2(draft.value_a),
        value_b: round_opt2(draft.value_b),
        ..draft
    }
}

fn round_output_patch(patch: OutputBindingPatch) -> OutputBindingPatch {
    OutputBindingPatch {
        value_a: patch.value_a.map(round_opt2),
        value_b: patch.value_b.map(round_opt2),
        ..patch
    }
}

fn validate_name(value: &str, field: &str) -> Result<(), AppError> {
    let trimmed = value.trim();
    if trimmed.is_empty() || value.chars().count() > 100 {
        return Err(validation_error(
            field,
            "Enter between 1 and 100 characters.",
        ));
    }
    Ok(())
}

fn validate_identifiers(values: Vec<String>) -> Result<Vec<String>, AppError> {
    let cleaned = values
        .into_iter()
        .map(|value| value.trim().to_owned())
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>();
    if cleaned.is_empty() {
        return Err(validation_error(
            "identifiers",
            "Add at least one train identifier.",
        ));
    }
    Ok(cleaned)
}

fn validate_triggers(values: Vec<String>) -> Result<Vec<String>, AppError> {
    for value in &values {
        if value.trim().is_empty() {
            return Err(validation_error(
                "triggers",
                "Triggers must be non-empty endpoint path strings.",
            ));
        }
    }
    Ok(values)
}

fn parse_input_kind(value: &str) -> Result<InputKind, AppError> {
    match value {
        "analog" => Ok(InputKind::Analog),
        "button" => Ok(InputKind::Button),
        _ => Err(validation_error(
            "kind",
            "Input kind must be \"analog\" or \"button\".",
        )),
    }
}

fn parse_element_kind(value: &str) -> Result<ElementKind, AppError> {
    match value {
        "lever" => Ok(ElementKind::Lever),
        "button" => Ok(ElementKind::Button),
        _ => Err(validation_error(
            "kind",
            "Element kind must be \"lever\" or \"button\".",
        )),
    }
}

fn parse_lever_type(value: &str) -> Result<LeverType, AppError> {
    match value {
        "discrete" => Ok(LeverType::Discrete),
        "continuous" => Ok(LeverType::Continuous),
        "hybrid" => Ok(LeverType::Hybrid),
        _ => Err(validation_error(
            "lever_type",
            "Lever type must be \"discrete\", \"continuous\" or \"hybrid\".",
        )),
    }
}

fn not_found(field: &str) -> impl Fn() -> AppError + '_ {
    move || AppError {
        code: ErrorCode::NotFound,
        message: format!("The requested {field} was not found."),
        field_errors: BTreeMap::new(),
        retryable: false,
    }
}

fn constraint_error(field: &str, detail: &str) -> AppError {
    AppError {
        code: ErrorCode::Validation,
        message: "Check the highlighted field.".into(),
        field_errors: BTreeMap::from([(field.into(), detail.into())]),
        retryable: false,
    }
}
