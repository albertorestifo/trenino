use std::{
    collections::HashMap,
    path::PathBuf,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    },
    time::{Duration, Instant},
};

use serde::Serialize;
use tauri::{AppHandle, Emitter, Manager, State, WebviewUrl, WebviewWindowBuilder};
use tauri_plugin_dialog::{DialogExt, MessageDialogButtons};
use trenino_core::ui::{SettingsView, UiChange, UiFailure, UiSnapshot};
use trenino_core::{AppError, Topic};
use trenino_runtime::lifecycle::{ShutdownCoordinator, ShutdownParticipant};
use trenino_runtime::{app::AppServices, settings::resolve_api_key_file};

#[cfg(feature = "desktop-updater")]
use crate::updater;

#[path = "runtime_firmware.rs"]
mod runtime_firmware;
#[path = "runtime_hardware.rs"]
mod runtime_hardware;
#[path = "runtime_mapping.rs"]
mod runtime_mapping;
#[path = "runtime_preview.rs"]
mod runtime_preview;
#[path = "runtime_sessions.rs"]
mod runtime_sessions;
#[path = "runtime_simulator.rs"]
mod runtime_simulator;
#[path = "runtime_upload.rs"]
mod runtime_upload;

use trenino_runtime::composition::hardware::LiveHardwareEffects;

#[path = "wire_patch.rs"]
mod wire_patch;
use wire_patch::NullableArg;

type ObserverMap = HashMap<String, Topic>;

pub(crate) struct RustAppState {
    services: Mutex<Option<Arc<AppServices>>>,
    observers: Mutex<HashMap<String, ObserverMap>>,
    publication: tokio::sync::Mutex<()>,
    shutdown_lock: Mutex<()>,
    shutdown: ShutdownCoordinator,
    stopping: AtomicBool,
    startup_failure_pending: AtomicBool,
    hardware: Mutex<Option<Arc<HardwareRuntime>>>,
    controls: Mutex<Option<Arc<trenino_runtime::composition::ControlRuntime>>>,
    vjoy: Mutex<Option<Arc<VjoyRuntime>>>,
    upload: Mutex<Option<Arc<trenino_runtime::firmware::UploadManager>>>,
    firmware: Mutex<Option<Arc<trenino_runtime::firmware::owner::FirmwareUpdateOwner>>>,
    /// Installed by the wave integrator via `install_mcp_server`.
    #[allow(dead_code)]
    mcp: Mutex<Option<Arc<trenino_runtime::mcp::server::McpServer>>>,
    telemetry_gate: crate::telemetry::TelemetryGate,
    telemetry_guard: Mutex<Option<sentry::ClientInitGuard>>,
}

impl RustAppState {
    fn empty() -> Self {
        Self {
            services: Mutex::new(None),
            observers: Mutex::new(HashMap::new()),
            publication: tokio::sync::Mutex::new(()),
            shutdown_lock: Mutex::new(()),
            shutdown: ShutdownCoordinator::default(),
            stopping: AtomicBool::new(false),
            startup_failure_pending: AtomicBool::new(false),
            hardware: Mutex::new(None),
            controls: Mutex::new(None),
            vjoy: Mutex::new(None),
            upload: Mutex::new(None),
            firmware: Mutex::new(None),
            mcp: Mutex::new(None),
            telemetry_gate: crate::telemetry::TelemetryGate::from_consent(None),
            telemetry_guard: Mutex::new(None),
        }
    }

    fn install(&self, services: AppServices) -> Result<(), String> {
        let mut slot = self
            .services
            .lock()
            .map_err(|_| "application state unavailable")?;
        if slot.is_some() {
            return Err("application services already initialized".into());
        }
        *slot = Some(Arc::new(services));
        Ok(())
    }

    fn services(&self) -> Result<Arc<AppServices>, UiFailure> {
        if self.stopping.load(Ordering::Acquire) {
            return Err(UiFailure::from(shutting_down_error()));
        }
        self.services
            .lock()
            .map_err(|_| UiFailure::from(AppError::internal("application state unavailable")))?
            .as_ref()
            .cloned()
            .ok_or_else(|| UiFailure::from(AppError::internal("application services unavailable")))
    }

    fn register(&self, window: &str, topic: Topic, id: &str) -> Result<(), UiFailure> {
        validate_subscription_id(id)?;
        if self.stopping.load(Ordering::Acquire) {
            return Err(UiFailure::from(shutting_down_error()));
        }
        let mut observers = self.observers.lock().map_err(|_| {
            UiFailure::from(AppError::internal("subscription registry unavailable"))
        })?;
        let by_window = observers.entry(window.to_owned()).or_default();
        match by_window.get(id) {
            Some(existing) if *existing == topic => Ok(()),
            Some(_) => Err(UiFailure {
                code: "conflict".into(),
                message: "This observer ID is already registered for another topic.".into(),
                field_errors: std::collections::BTreeMap::new(),
                retryable: false,
            }),
            None => {
                by_window.insert(id.to_owned(), topic);
                Ok(())
            }
        }
    }

    fn unregister(&self, window: &str, topic: Topic, id: &str) -> Result<(), UiFailure> {
        validate_subscription_id(id)?;
        let mut observers = self.observers.lock().map_err(|_| {
            UiFailure::from(AppError::internal("subscription registry unavailable"))
        })?;
        if let Some(by_window) = observers.get_mut(window) {
            if by_window
                .get(id)
                .is_some_and(|registered| *registered == topic)
            {
                by_window.remove(id);
            }
            if by_window.is_empty() {
                observers.remove(window);
            }
        }
        Ok(())
    }

    fn unregister_window(&self, window: &str) {
        if let Ok(mut observers) = self.observers.lock() {
            observers.remove(window);
        }
    }

    fn windows_for(&self, topic: Topic) -> Vec<String> {
        self.observers
            .lock()
            .map(|observers| {
                observers
                    .iter()
                    .filter(|(_, ids)| ids.values().any(|registered| *registered == topic))
                    .map(|(window, _)| window.clone())
                    .collect()
            })
            .unwrap_or_default()
    }

    /// Registers the MCP HTTP server as a shutdown participant and stores the
    /// handle for status queries. The wave integrator constructs the server
    /// with the storage-backed ports:
    /// `storage_ports::StoragePorts::new(database).into_ports()` handed to
    /// `mcp::server::McpServer::new`, then passes it here.
    #[allow(dead_code)]
    pub fn install_mcp_server(
        &self,
        server: Arc<trenino_runtime::mcp::server::McpServer>,
    ) -> Result<(), String> {
        self.shutdown
            .register(Arc::new(McpParticipant {
                server: server.clone(),
            }))
            .map_err(str::to_owned)?;
        let mut slot = self
            .mcp
            .lock()
            .map_err(|_| "mcp server registry unavailable")?;
        if slot.is_some() {
            return Err("mcp server already installed".into());
        }
        *slot = Some(server);
        Ok(())
    }

    #[allow(dead_code)]
    pub fn mcp_server(&self) -> Option<Arc<trenino_runtime::mcp::server::McpServer>> {
        self.mcp.lock().ok().and_then(|slot| slot.clone())
    }

    fn hardware_runtime(&self) -> Result<Arc<HardwareRuntime>, UiFailure> {
        self.hardware
            .lock()
            .map_err(|_| UiFailure::from(AppError::internal("hardware runtime unavailable")))?
            .clone()
            .ok_or_else(|| UiFailure::from(unavailable("The hardware runtime is not running.")))
    }

    fn vjoy_manager(
        &self,
    ) -> Result<Arc<trenino_runtime::vjoy::VjoyManager<PlatformVjoyAdapter>>, UiFailure> {
        self.vjoy
            .lock()
            .map_err(|_| UiFailure::from(AppError::internal("vjoy manager unavailable")))?
            .as_ref()
            .map(|runtime| runtime.manager.clone())
            .ok_or_else(|| UiFailure::from(unavailable("The vJoy manager is not running.")))
    }

    fn upload_manager(&self) -> Result<Arc<trenino_runtime::firmware::UploadManager>, UiFailure> {
        self.upload
            .lock()
            .map_err(|_| UiFailure::from(AppError::internal("upload manager unavailable")))?
            .clone()
            .ok_or_else(|| UiFailure::from(unavailable("The upload manager is not running.")))
    }

    /// Constructs the runtime services (hardware runtime, vJoy manager,
    /// firmware upload manager), registers every one as a shutdown
    /// participant, and stores handles for the command surface. None of these
    /// hold `Arc<AppServices>`; they hold `Database` clones, so the app
    /// shutdown strong-count drain contract holds. The MCP HTTP server is
    /// constructed and started here from the storage-backed ports
    /// (`mcp::storage_ports::StoragePorts`) and installed via
    /// `install_mcp_server`.
    fn wire_runtime_services(&self, app: &AppHandle, services: &AppServices) -> Result<(), String> {
        let database = services.database();

        let (consumers, _events) = AppHardwareConsumers::new(app.clone());
        let consumers = Arc::new(consumers);
        let repository = trenino_runtime::hardware::repository::DatabaseHardwareRepository::new(
            database.clone(),
        );
        let service = Arc::new(trenino_runtime::hardware::service::HardwareService::new(
            Arc::new(trenino_runtime::hardware::transport::NativeSerialTransport),
            trenino_runtime::hardware::discovery::DiscoveryTiming::default(),
            repository,
            consumers.clone(),
        ));
        let handle = service
            .start()
            .map_err(|error| wired_failure(&error.to_string()))?;
        let arbiter = handle.resource_arbiter();
        *consumers
            .arbiter
            .lock()
            .map_err(|_| "arbiter unavailable")? = Some(Arc::downgrade(&arbiter));
        let resolver = handle.resolver();
        let effects = Arc::new(LiveHardwareEffects::new(
            Arc::new(handle.command_port()),
            database.clone(),
            consumers.suspended.clone(),
        ));
        *consumers
            .effects
            .lock()
            .map_err(|_| "effects unavailable")? = Some(effects.clone());
        let hardware = Arc::new(HardwareRuntime {
            handle: Mutex::new(Some(handle)),
            effects: effects.clone(),
        });
        self.shutdown.register(hardware.clone())?;
        *self
            .hardware
            .lock()
            .map_err(|_| "hardware registry unavailable")? = Some(hardware.clone());

        #[cfg(windows)]
        let adapter = trenino_runtime::vjoy::windows::WindowsVjoyAdapter::with_resource_dir(
            app.path()
                .resource_dir()
                .map_err(|e| e.to_string())?
                .join("resources"),
        );
        #[cfg(not(windows))]
        let adapter = UnsupportedVjoyAdapter;
        let manager = Arc::new(trenino_runtime::vjoy::VjoyManager::new(
            (*database).clone(),
            arbiter.clone(),
            adapter,
        ));
        let vjoy = Arc::new(VjoyRuntime::start(
            manager.clone(),
            hardware.clone(),
            database.clone(),
        ));
        self.shutdown.register(vjoy.clone())?;
        *self.vjoy.lock().map_err(|_| "vjoy registry unavailable")? = Some(vjoy);
        let mut settings = trenino_runtime::settings::Settings::new((*database).clone());
        if let Some(path) = simulator_key_file(app) {
            settings = settings.with_api_key_file(path);
        }
        let probe = installed_keystroke_probe(
            std::env::current_exe()
                .ok()
                .and_then(|path| path.parent().map(std::path::Path::to_path_buf)),
        );
        let controls = Arc::new(trenino_runtime::composition::ControlRuntime::start(
            database.clone(),
            Arc::new(settings),
            resolver,
            arbiter.clone(),
            effects,
            Arc::new(trenino_runtime::composition::keyboard::NativeKeyboard::new(
                &probe,
            )),
        )?);
        self.shutdown.register(controls.clone())?;
        *consumers
            .controls
            .lock()
            .map_err(|_| "consumer controls unavailable")? = Some(Arc::downgrade(&controls));
        *consumers
            .vjoy
            .lock()
            .map_err(|_| "consumer vjoy unavailable")? = Some(Arc::downgrade(&manager));
        *self
            .controls
            .lock()
            .map_err(|_| "controls registry unavailable")? = Some(controls.clone());

        // MCP HTTP server: storage-backed tool ports plus the live vJoy
        // manager. Port choice (least-surprising default): the Elixir stack
        // served MCP from the Phoenix app, whose `PORT` env default is 4000,
        // so bind 127.0.0.1:4000 unless `TRENINO_MCP_PORT` overrides it.
        // A busy port stays non-fatal: `start` reports `Degraded` instead of
        // an error and app startup continues.
        let mcp_ports = trenino_runtime::mcp::storage_ports::StoragePorts::new(database.clone())
            .with_vjoy_runtime(manager.clone())
            .with_simulator(controls.simulator.clone())
            .with_detection(Arc::new(LiveDetection {
                hardware: Arc::downgrade(&hardware),
                db: database.clone(),
                app: app.clone(),
            }))
            .into_ports();
        let mcp_ports = Arc::new(mcp_ports);
        let exit_app = app.clone();
        let compatibility =
            trenino_runtime::http_api::CompatibilityApi::new(database.clone(), mcp_ports.clone())
                .with_shutdown(Arc::new(move || exit_app.exit(0)));
        let mcp_server = Arc::new(
            trenino_runtime::mcp::server::McpServer::new(mcp_ports, None)
                .with_server_version(env!("CARGO_PKG_VERSION"))
                .with_compatibility_api(compatibility),
        );
        let mcp_port: u16 = std::env::var("TRENINO_MCP_PORT")
            .ok()
            .and_then(|value| value.parse().ok())
            .unwrap_or(4000);
        let _ = mcp_server.start(([127, 0, 0, 1], mcp_port).into());
        self.install_mcp_server(mcp_server)?;

        let upload = Arc::new(
            trenino_runtime::firmware::UploadManager::new_with_serial_ownership(
                arbiter,
                Arc::new(trenino_runtime::hardware::transport::NativeSerialTransport),
                avrdude_tooling(app),
                trenino_runtime::firmware::UploadTimings::default(),
                Arc::new(DbUploadHistory {
                    db: (*database).clone(),
                }),
                runtime_upload::upload_hooks(app.clone(), Arc::downgrade(&hardware)),
                Arc::new(runtime_upload::RuntimeUploadOwnership::new(Arc::downgrade(
                    &hardware,
                ))),
            ),
        );
        self.shutdown.register(Arc::new(UploadParticipant {
            manager: upload.clone(),
        }))?;
        *self
            .upload
            .lock()
            .map_err(|_| "upload registry unavailable")? = Some(upload);
        let repository = Arc::new(DbFirmwareRepository {
            db: (*database).clone(),
        });
        let catalog = trenino_runtime::firmware::FirmwareCatalog::new(
            trenino_runtime::firmware::FirmwareHttpClient::new(Duration::from_secs(30))
                .map_err(|e| format!("{e:?}"))?,
            repository.clone(),
            trenino_core::firmware::FirmwareRequirement::parse(None)
                .map_err(|e| format!("{e:?}"))?,
        );
        let epoch_ms = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map_err(|e| e.to_string())?
            .as_millis() as u64;
        let weak_services = Arc::downgrade(&self.services().map_err(|e| e.message)?);
        let firmware_app = app.clone();
        let firmware = Arc::new(
            trenino_runtime::firmware::owner::FirmwareUpdateOwner::start_with_observer(
                repository,
                Arc::new(catalog),
                Arc::new(trenino_runtime::simulator::services::clock::SystemClock),
                epoch_ms,
                Default::default(),
                Arc::new(move || {
                    if let Some(services) = weak_services.upgrade() {
                        match services.get_firmware_snapshot() {
                            Ok(snapshot) => {
                                publish_change(&firmware_app, Topic::Firmware, &snapshot)
                            }
                            Err(error) => {
                                eprintln!("firmware snapshot publication failed: {error:?}")
                            }
                        }
                    }
                }),
            )?,
        );
        self.shutdown
            .register(Arc::new(runtime_firmware::FirmwareParticipant(
                firmware.clone(),
            )))?;
        *self
            .firmware
            .lock()
            .map_err(|_| "firmware registry unavailable")? = Some(firmware);

        Ok(())
    }

    #[cfg(feature = "desktop-updater")]
    pub(crate) fn accepts_work(&self) -> bool {
        !self.stopping.load(Ordering::Acquire)
            && self
                .services
                .lock()
                .is_ok_and(|services| services.is_some())
    }

    #[allow(dead_code)] // Real runtime services register here when they are owned by AppServices.
    pub fn register_shutdown_participant(
        &self,
        participant: Arc<dyn ShutdownParticipant>,
    ) -> Result<(), &'static str> {
        self.shutdown.register(participant)
    }

    /// Stop command admission, wait for current database work, then release the
    /// database and its path lock. Any registered service must be added to the
    /// coordinated shutdown before it can be exposed by this runtime.
    pub(crate) fn shutdown(&self) -> Result<(), String> {
        let _shutdown = self
            .shutdown_lock
            .lock()
            .map_err(|_| "application shutdown coordinator is unavailable")?;
        self.stopping.store(true, Ordering::Release);
        let result = self.shutdown.shutdown(|| {
            let mut slot = self
                .services
                .lock()
                .map_err(|_| "application state unavailable")?;
            let Some(services) = slot.as_ref().cloned() else {
                return Ok(());
            };
            let deadline = Instant::now() + Duration::from_secs(15);
            while Arc::strong_count(&services) > 2 {
                if Instant::now() >= deadline {
                    return Err(
                        "An application operation did not finish; database closure was refused."
                            .into(),
                    );
                }
                std::thread::sleep(Duration::from_millis(10));
            }
            services.quiesce();
            services.database().close_worker(Duration::from_secs(15))?;
            let owned = slot.take();
            drop(slot);
            drop(owned);
            drop(services);
            Ok(())
        });
        // A failed phase may already have stopped a subset of producers.
        // Keep admission fenced; another native exit/shutdown attempt can
        // retry cleanup using the retained service handles.
        result
    }
}

fn validate_subscription_id(id: &str) -> Result<(), UiFailure> {
    if id.is_empty() || id.len() > 128 || id.chars().any(char::is_control) {
        let mut fields = std::collections::BTreeMap::new();
        fields.insert(
            "subscription_id".into(),
            "Observer ID must contain 1 to 128 non-control characters.".into(),
        );
        return Err(UiFailure {
            code: "validation".into(),
            message: "Check the highlighted field.".into(),
            field_errors: fields,
            retryable: false,
        });
    }
    Ok(())
}

fn shutting_down_error() -> AppError {
    AppError {
        code: trenino_core::ErrorCode::Unavailable,
        message: "The application is shutting down.".into(),
        field_errors: Default::default(),
        retryable: true,
    }
}

fn trial_database_path(app: &tauri::AppHandle) -> Result<PathBuf, String> {
    let default_path = app
        .path()
        .app_local_data_dir()
        .map_err(|error| format!("Could not resolve app-local data directory: {error}"))?
        .join("rust-trial")
        .join("trenino.db");
    selected_trial_database_path(
        std::env::var_os("TRENINO_RUST_TRIAL_DB").map(PathBuf::from),
        default_path,
    )
}

fn selected_trial_database_path(
    override_path: Option<PathBuf>,
    default_path: PathBuf,
) -> Result<PathBuf, String> {
    if let Some(path) = override_path {
        if !path.is_absolute() {
            return Err(
                "TRENINO_RUST_TRIAL_DB must be an absolute, explicitly selected database path."
                    .into(),
            );
        }
        return Ok(path);
    }
    Ok(default_path)
}

fn dispatch_startup_failure(
    error: &trenino_runtime::storage::StorageError,
    present: impl FnOnce(&str),
) {
    let message = match error {
        trenino_runtime::storage::StorageError::LegacyUpgradeRequired => {
            "This database contains existing Trenino data. Keep using the current Trenino app, or create a backup and run the explicit maintenance upgrade before starting the Rust trial."
        }
        trenino_runtime::storage::StorageError::BootstrapUpgradeRequired => {
            "This database contains existing profile or settings data. It was preserved. Keep using the current Trenino app, or create a backup and run the explicit maintenance upgrade before starting the Rust trial."
        }
        trenino_runtime::storage::StorageError::AlreadyRunning => {
            "This Trenino database is already open in another application instance. Close that instance and try again."
        }
        _ => "The Rust trial could not open its local database. Check access to app-local data and try again.",
    };
    present(message);
}

fn show_startup_failure(app: &tauri::AppHandle, message: &str) {
    let exit_app = app.clone();
    if let Some(state) = app.try_state::<RustAppState>() {
        state.startup_failure_pending.store(true, Ordering::Release);
    }
    app.dialog()
        .message(message.to_owned())
        .buttons(MessageDialogButtons::Ok)
        .show(move |_| {
            if let Some(state) = exit_app.try_state::<RustAppState>() {
                state
                    .startup_failure_pending
                    .store(false, Ordering::Release);
            }
            exit_app.exit(1);
        });
}

fn simulator_key_file(app: &AppHandle) -> Option<PathBuf> {
    let manual = std::env::var_os("TRENINO_TSW_API_KEY_FILE").map(PathBuf::from);
    if manual.is_some() {
        return manual;
    }
    let documents = app
        .path()
        .document_dir()
        .ok()
        .or_else(|| {
            std::env::var_os("USERPROFILE")
                .map(PathBuf::from)
                .map(|profile| profile.join("Documents"))
        })
        .or_else(|| {
            std::env::var_os("HOME")
                .map(PathBuf::from)
                .map(|home| home.join("Documents"))
        })?;
    resolve_api_key_file(&documents, None)
}

#[tauri::command]
async fn ui_get_settings(
    state: State<'_, RustAppState>,
) -> Result<UiSnapshot<SettingsView>, UiFailure> {
    let services = state.services()?;
    tauri::async_runtime::spawn_blocking(move || services.get_settings())
        .await
        .map_err(|_| UiFailure::from(AppError::internal("settings task failed")))?
        .map_err(UiFailure::from)
}

#[tauri::command]
async fn ui_list_configurations(
    state: State<'_, RustAppState>,
) -> Result<UiSnapshot<Vec<trenino_core::ui::ConfigurationSummaryView>>, UiFailure> {
    let services = state.services()?;
    tauri::async_runtime::spawn_blocking(move || services.list_configurations())
        .await
        .map_err(|_| UiFailure::from(AppError::internal("configuration task failed")))?
        .map_err(UiFailure::from)
}

#[tauri::command]
async fn ui_list_trains(
    state: State<'_, RustAppState>,
) -> Result<UiSnapshot<Vec<trenino_core::ui::TrainSummaryView>>, UiFailure> {
    let services = state.services()?;
    tauri::async_runtime::spawn_blocking(move || services.list_trains())
        .await
        .map_err(|_| UiFailure::from(AppError::internal("train task failed")))?
        .map_err(UiFailure::from)
}

#[tauri::command(rename_all = "snake_case")]
async fn ui_set_consent<R: tauri::Runtime>(
    app: AppHandle<R>,
    state: State<'_, RustAppState>,
    value: String,
) -> Result<UiSnapshot<SettingsView>, UiFailure> {
    let enabled = match value.as_str() {
        "enabled" => true,
        "disabled" => false,
        _ => {
            let mut fields = std::collections::BTreeMap::new();
            fields.insert("value".into(), "Choose enabled or disabled.".into());
            return Err(UiFailure {
                code: "validation".into(),
                message: "Check the highlighted field.".into(),
                field_errors: fields,
                retryable: false,
            });
        }
    };
    let _publication = state.publication.lock().await;
    let services = state.services()?;
    let snapshot = tauri::async_runtime::spawn_blocking(move || services.set_consent(enabled))
        .await
        .map_err(|_| UiFailure::from(AppError::internal("consent task failed")))?
        .map_err(UiFailure::from)?;
    state.telemetry_gate.set_consent(enabled);
    publish_change(&app, Topic::Settings, &snapshot);
    Ok(snapshot)
}

#[tauri::command(rename_all = "snake_case")]
async fn ui_get_snapshot(
    state: State<'_, RustAppState>,
    topic: Topic,
) -> Result<serde_json::Value, UiFailure> {
    let services = state.services()?;
    tauri::async_runtime::spawn_blocking(move || services.snapshot_json(topic))
        .await
        .map_err(|_| UiFailure::from(AppError::internal("snapshot task failed")))?
        .map_err(UiFailure::from)
}

#[tauri::command(rename_all = "snake_case")]
fn ui_subscribe(
    window: tauri::WebviewWindow,
    state: State<'_, RustAppState>,
    topic: Topic,
    subscription_id: String,
) -> Result<(), UiFailure> {
    state.register(window.label(), topic, &subscription_id)
}

#[tauri::command(rename_all = "snake_case")]
fn ui_unsubscribe(
    window: tauri::WebviewWindow,
    state: State<'_, RustAppState>,
    topic: Topic,
    subscription_id: String,
) -> Result<(), UiFailure> {
    state.unregister(window.label(), topic, &subscription_id)
}

fn publish_change<R: tauri::Runtime, T: Serialize>(
    app: &AppHandle<R>,
    topic: Topic,
    snapshot: &UiSnapshot<T>,
) {
    let change = UiChange {
        epoch: snapshot.epoch,
        topic,
        revision: snapshot.revision,
        value: &snapshot.value,
    };
    let event = format!("ui://change/{}", topic_name(topic));
    if let Some(state) = app.try_state::<RustAppState>() {
        for window_label in state.windows_for(topic) {
            if let Some(window) = app.get_webview_window(&window_label) {
                let _ = window.emit(&event, &change);
            }
        }
    }
}

fn topic_name(topic: Topic) -> &'static str {
    match topic {
        Topic::Settings => "settings",
        Topic::Hardware => "hardware",
        Topic::Trains => "trains",
        Topic::Bindings => "bindings",
        Topic::Scripts => "scripts",
        Topic::Firmware => "firmware",
        Topic::Vjoy => "vjoy",
    }
}

pub(crate) fn run() {
    let builder = tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .manage(RustAppState::empty())
        .invoke_handler(tauri::generate_handler![
            ui_get_settings,
            ui_list_configurations,
            ui_list_trains,
            ui_set_consent,
            ui_subscribe,
            ui_get_snapshot,
            ui_unsubscribe,
            ui_set_api_key,
            ui_set_simulator_url,
            ui_test_simulator,
            ui_create_configuration,
            ui_update_configuration,
            ui_delete_configuration,
            ui_get_hardware_detail,
            ui_get_hardware_detail_by_config,
            ui_create_input,
            ui_update_input,
            ui_delete_input,
            ui_create_output,
            ui_update_output,
            ui_delete_output,
            ui_create_matrix,
            ui_update_matrix,
            ui_delete_matrix,
            ui_create_i2c_module,
            ui_update_i2c_module,
            ui_delete_i2c_module,
            ui_start_calibration,
            ui_advance_calibration,
            ui_cancel_calibration,
            ui_get_train_detail,
            ui_create_train,
            ui_update_train,
            ui_delete_train,
            ui_activate_train,
            ui_create_element,
            ui_delete_element,
            ui_create_lever,
            ui_update_lever,
            ui_create_notch,
            ui_update_notch,
            ui_delete_notch,
            ui_save_notches,
            runtime_mapping::ui_commit_lever_mapping,
            ui_auto_distribute_notches,
            ui_validate_notches,
            ui_create_sequence,
            ui_update_sequence,
            ui_delete_sequence,
            ui_set_sequence_commands,
            ui_add_sequence_command,
            ui_delete_sequence_command,
            ui_test_sequence,
            ui_create_script,
            ui_update_script,
            ui_delete_script,
            ui_reload_scripts,
            runtime_preview::ui_calibration_ceiling,
            runtime_preview::ui_preview_input,
            runtime_preview::ui_preview_notch_mapping,
            runtime_preview::ui_preview_display,
            runtime_preview::ui_preview_output_condition,
            runtime_simulator::ui_list_simulator_endpoints,
            runtime_simulator::ui_get_simulator_value,
            runtime_sessions::ui_start_control_detection,
            runtime_sessions::ui_control_detection_status,
            runtime_sessions::ui_cancel_control_detection,
            runtime_sessions::ui_start_lever_analysis,
            runtime_sessions::ui_lever_analysis_status,
            runtime_sessions::ui_cancel_lever_analysis,
            runtime_sessions::ui_start_lever_calibration,
            runtime_sessions::ui_lever_calibration_status,
            runtime_sessions::ui_cancel_lever_calibration,
            runtime_sessions::ui_resolve_lever_endpoints,
            runtime_sessions::ui_suggest_lever,
            runtime_sessions::ui_suggest_button,
            runtime_hardware::ui_serial_ports,
            runtime_hardware::ui_scan_devices,
            runtime_hardware::ui_disconnect_device,
            runtime_hardware::ui_set_physical_output,
            runtime_hardware::ui_test_display,
            runtime_hardware::ui_begin_apply_configuration,
            runtime_hardware::ui_configuration_status,
            ui_get_connected_devices,
            ui_get_simulator_status,
            ui_retry_simulator,
            ui_run_script,
            ui_get_script_log,
            ui_bind_lever,
            ui_unbind_lever,
            ui_set_lever_binding_enabled,
            ui_put_button_binding,
            ui_delete_button_binding,
            ui_create_output_binding,
            ui_update_output_binding,
            ui_delete_output_binding,
            ui_create_display_binding,
            ui_update_display_binding,
            ui_delete_display_binding,
            ui_get_vjoy,
            ui_vjoy_enable,
            ui_vjoy_disable,
            ui_set_vjoy_selection,
            ui_put_vjoy_mapping,
            ui_delete_vjoy_mapping,
            ui_vjoy_status,
            ui_vjoy_remove_leftover,
            ui_vjoy_repair,
            ui_check_firmware_updates,
            runtime_firmware::ui_firmware_update_status,
            runtime_firmware::ui_dismiss_firmware_update,
            ui_download_firmware,
            ui_start_firmware_upload,
            ui_cancel_firmware_upload,
            ui_firmware_history,
            ui_get_bindings,
            ui_get_scripts,
            ui_get_firmware,
        ])
        .setup(|app| {
            let db_path = match trial_database_path(app.handle()) {
                Ok(path) => path,
                Err(_) => {
                    show_startup_failure(
                        app.handle(),
                        "The Rust trial could not resolve its local data directory. Check your user profile permissions and try again.",
                    );
                    return Ok(());
                }
            };
            let services = match AppServices::open_full(db_path, simulator_key_file(app.handle())) {
                Ok(services) => services,
                Err(error) => {
                    dispatch_startup_failure(&error, |message| {
                        show_startup_failure(app.handle(), message)
                    });
                    return Ok(());
                }
            };
            let state = app.state::<RustAppState>();
            if state.install(services).is_err() {
                show_startup_failure(
                    app.handle(),
                    "The Rust trial could not initialize its application services. Restart the application and try again.",
                );
                return Ok(());
            }
            let Some(services) = state.services().ok() else {
                show_startup_failure(
                    app.handle(),
                    "The Rust trial could not initialize its application services. Restart the application and try again.",
                );
                return Ok(());
            };
            // Consent-gated error reporting: enable when a DSN is configured
            // (SENTRY_DSN overrides the project default; empty disables);
            // before_send drops every event unless consent is enabled.
            if let Ok(snapshot) = services.get_settings() {
                state.telemetry_gate.set_consent(
                    matches!(
                        snapshot.value.error_reporting,
                        trenino_core::ui::ConsentState::Enabled
                    ),
                );
            }
            if let Some(dsn) = crate::telemetry::resolve_dsn() {
                if let Some(guard) = crate::telemetry::init(&dsn, state.telemetry_gate.clone()) {
                    if let Ok(mut slot) = state.telemetry_guard.lock() {
                        *slot = Some(guard);
                    }
                }
            }
            if let Err(error) = state.wire_runtime_services(app.handle(), &services) {
                show_startup_failure(app.handle(), &error);
                return Ok(());
            }
            drop(services);

            #[cfg(feature = "desktop-updater")]
            updater::setup(app)?;

            WebviewWindowBuilder::new(app, "main", WebviewUrl::App("index.html".into()))
                .title("Trenino")
                .inner_size(1200.0, 800.0)
                .min_inner_size(800.0, 600.0)
                .build()?;
            Ok(())
        })
        .build(tauri::generate_context!())
        .expect("Error while building Trenino Rust trial");

    builder.run(|app_handle, event| match event {
        tauri::RunEvent::ExitRequested { api, .. } => {
            if let Some(state) = app_handle.try_state::<RustAppState>() {
                if state.startup_failure_pending.load(Ordering::Acquire)
                    || state.shutdown().is_err()
                {
                    api.prevent_exit();
                }
            }
        }
        tauri::RunEvent::Exit => {
            if let Some(state) = app_handle.try_state::<RustAppState>() {
                if let Ok(mut guard) = state.telemetry_guard.lock() {
                    // Tauri can exit the process without dropping managed state.
                    // Explicitly drain Sentry after runtime shutdown has finished.
                    drop(guard.take());
                }
            }
        }
        tauri::RunEvent::WindowEvent {
            label,
            event: tauri::WindowEvent::Destroyed,
            ..
        } => {
            if let Some(state) = app_handle.try_state::<RustAppState>() {
                state.unregister_window(&label);
            }
        }
        _ => {}
    });
}

// ============================ Wave-2 command surface ==========================
//
// Mirrors the LiveView pages in `lib/trenino_web/live/*.ex`: every mutation
// goes through `AppServices` (epoch-guarded), publishes the matching topic
// change under the publication lock, and maps `AppError` to `UiFailure` with
// field-level validation detail.

type HardwareHandle = trenino_runtime::hardware::service::HardwareServiceHandle<
    trenino_runtime::hardware::transport::NativeSerialTransport,
    trenino_runtime::hardware::repository::DatabaseHardwareRepository,
    AppHardwareConsumers,
>;

/// One authoritative input edge/sample, broadcast to hardware-topic observers
/// (matrix test wizard, calibration wizards, wave-3 controllers).
#[derive(Clone, Debug, serde::Serialize)]
pub(crate) struct HardwareInputEventView {
    pub port: String,
    pub device_id: String,
    pub input_id: String,
    pub pin: u8,
    pub value: i16,
    pub config_id: u32,
    pub port_generation: u64,
}

/// Forwards hardware input events to the UI event stream and (when the wave-3
/// controllers land) to the shared input resolver. The resolver handle is
/// attached after the service starts because it is created by the service.
pub(crate) struct AppHardwareConsumers {
    app: AppHandle,
    events: tokio::sync::broadcast::Sender<HardwareInputEventView>,
    suspended: Arc<Mutex<std::collections::HashSet<String>>>,
    effects: Mutex<Option<Arc<LiveHardwareEffects>>>,
    arbiter: Mutex<Option<std::sync::Weak<trenino_runtime::resource::ResourceArbiter>>>,
    controls: Mutex<Option<std::sync::Weak<trenino_runtime::composition::ControlRuntime>>>,
    vjoy: Mutex<Option<std::sync::Weak<trenino_runtime::vjoy::VjoyManager<PlatformVjoyAdapter>>>>,
}

impl AppHardwareConsumers {
    fn new(app: AppHandle) -> (Self, tokio::sync::broadcast::Sender<HardwareInputEventView>) {
        let (events, _) = tokio::sync::broadcast::channel(256);
        (
            Self {
                app,
                events: events.clone(),
                suspended: Arc::new(Mutex::new(std::collections::HashSet::new())),
                effects: Mutex::new(None),
                arbiter: Mutex::new(None),
                controls: Mutex::new(None),
                vjoy: Mutex::new(None),
            },
            events,
        )
    }
}

impl trenino_runtime::resource::ResourceConsumers for AppHardwareConsumers {
    fn suspend_actuation(&self, port: &str) -> Result<(), String> {
        if let Some(effects) = self
            .effects
            .lock()
            .map_err(|_| "effects poisoned")?
            .as_ref()
        {
            effects.suspend(port)?;
        }
        if let Some(controls) = self
            .controls
            .lock()
            .map_err(|_| "controls poisoned")?
            .as_ref()
            .and_then(std::sync::Weak::upgrade)
            .filter(|c| c.is_running())
        {
            controls.train.lever().suspend_port(port)?;
            controls.train.buttons().suspend_port(port)?;
        }
        if let Some(vjoy) = self
            .vjoy
            .lock()
            .map_err(|_| "vjoy poisoned")?
            .as_ref()
            .and_then(std::sync::Weak::upgrade)
        {
            vjoy.suspend_port(port).map_err(|e| e.to_string())?;
        }
        Ok(())
    }
    fn cancel_calibration(&self, _port: &str) -> Result<(), String> {
        Ok(())
    }
    fn source_lost(&self, port: &str, generation: u64) -> Result<(), String> {
        if let Some(effects) = self
            .effects
            .lock()
            .map_err(|_| "effects poisoned")?
            .as_ref()
        {
            let current = effects
                .command
                .connected_ports()
                .into_iter()
                .find(|p| p.port == port);
            if current.as_ref().is_some_and(|p| p.generation > generation) {
                return Ok(());
            }
            // Firmware handoff and failed-lease shutdown still have a live serial
            // generation: retry all outstanding LOW/blank reports before ACK.
            if current.as_ref().is_some_and(|p| p.generation == generation) {
                effects.suspend(port)?;
            }
        }
        self.suspended
            .lock()
            .map_err(|_| "output admission poisoned")?
            .insert(port.to_owned());
        if let Some(controls) = self
            .controls
            .lock()
            .map_err(|_| "controls poisoned")?
            .as_ref()
            .and_then(std::sync::Weak::upgrade)
            .filter(|c| c.is_running())
        {
            controls.train.lever().source_lost(port, generation)?;
            controls.train.buttons().source_lost(port, generation)?;
        }
        if let Some(vjoy) = self
            .vjoy
            .lock()
            .map_err(|_| "vjoy poisoned")?
            .as_ref()
            .and_then(std::sync::Weak::upgrade)
        {
            vjoy.source_lost(port, generation)
                .map_err(|e| e.to_string())?;
        }
        Ok(())
    }
    fn resume_after_fresh_sample(&self, port: &str) -> Result<(), String> {
        resume_suspended_port(&self.suspended, port, || {
            if let Some(controls) = self
                .controls
                .lock()
                .map_err(|_| "controls poisoned")?
                .as_ref()
                .and_then(std::sync::Weak::upgrade)
                .filter(|c| c.is_running())
            {
                controls.train.lever().resume_port(port)?;
                controls.train.buttons().resume_port(port)?;
                controls.hardware_resumed()?;
            }
            Ok(())
        })
    }
}

fn resume_suspended_port(
    suspended: &Mutex<std::collections::HashSet<String>>,
    port: &str,
    resume: impl FnOnce() -> Result<(), String>,
) -> Result<(), String> {
    resume()?;
    suspended
        .lock()
        .map_err(|_| "output admission poisoned")?
        .remove(port);
    Ok(())
}

impl trenino_runtime::hardware::service::HardwareConsumers for AppHardwareConsumers {
    fn dispatch_input(
        &self,
        identity: trenino_runtime::routing::InputIdentity,
        event: trenino_runtime::routing::InputEvent,
    ) -> Result<(), String> {
        self.dispatch_port_input("", identity, event)
    }
    fn dispatch_port_input(
        &self,
        port: &str,
        identity: trenino_runtime::routing::InputIdentity,
        event: trenino_runtime::routing::InputEvent,
    ) -> Result<(), String> {
        if self
            .app
            .try_state::<RustAppState>()
            .is_some_and(|s| s.stopping.load(Ordering::Acquire))
        {
            return Ok(());
        }
        let suspended = self
            .suspended
            .lock()
            .map_err(|_| "output admission poisoned")?
            .contains(port);
        let arbiter = self
            .arbiter
            .lock()
            .map_err(|_| "arbiter poisoned")?
            .as_ref()
            .and_then(std::sync::Weak::upgrade);
        let lease_active = arbiter
            .as_ref()
            .is_some_and(|a| a.port_is_leased(port) || a.port_neutralization_failed(port));
        // A failed aggregate resume must still let the sample reach the cache.
        let resume_error = if suspended && !lease_active {
            trenino_runtime::resource::ResourceConsumers::resume_after_fresh_sample(self, port)
                .err()
        } else {
            None
        };
        let cache_only = trenino_runtime::composition::input::port_is_fenced(
            port,
            &self.suspended,
            arbiter.as_deref(),
        )?;
        if let Some(controls) = self
            .controls
            .lock()
            .map_err(|_| "controls poisoned")?
            .as_ref()
            .and_then(std::sync::Weak::upgrade)
            .filter(|c| c.is_running())
        {
            trenino_runtime::composition::input::dispatch_control_input(
                controls.train.lever(),
                controls.train.buttons(),
                port,
                event,
                cache_only,
            )?;
        }
        if let Some(vjoy) = self
            .vjoy
            .lock()
            .map_err(|_| "vjoy poisoned")?
            .as_ref()
            .and_then(std::sync::Weak::upgrade)
        {
            vjoy.input_value(port, identity, event)
                .map_err(|e| e.to_string())?;
        }
        let view = HardwareInputEventView {
            port: port.to_owned(),
            device_id: identity.device_id.0.to_string(),
            input_id: identity.input_id.0.to_string(),
            pin: event.pin,
            value: event.value,
            config_id: event.config_id.get(),
            port_generation: event.port_generation,
        };
        // Broadcast for wave-3 controllers; emit for hardware-topic observers
        // (the matrix test wizard streams button presses through this event).
        let _ = self.events.send(view.clone());
        if let Some(state) = self.app.try_state::<RustAppState>() {
            for window_label in state.windows_for(Topic::Hardware) {
                if let Some(window) = self.app.get_webview_window(&window_label) {
                    let _ = window.emit("ui://hardware/input", &view);
                }
            }
        }
        resume_error.map_or(Ok(()), Err)
    }
    fn protocol_error(&self, port: &str, generation: u64, reason: &str) {
        eprintln!("hardware protocol error on {port} (generation {generation}): {reason}");
    }
    fn configuration_applied(
        &self,
        _port: &str,
        _generation: u64,
        _config_id: trenino_core::ConfigId,
    ) {
    }
    fn detection_outcome(
        &self,
        _id: trenino_core::SessionId,
        _outcome: trenino_runtime::hardware::sessions::DetectionOutcome,
    ) {
    }
    fn calibration_error(
        &self,
        _id: trenino_core::SessionId,
        _error: trenino_runtime::hardware::sessions::SessionError,
    ) {
    }
}

/// Owns the running hardware service handle so commands can borrow it and the
/// shutdown participant retains it until stop is acknowledged.
pub(crate) struct HardwareRuntime<H = HardwareHandle> {
    handle: Mutex<Option<H>>,
    effects: Arc<LiveHardwareEffects>,
}

impl HardwareRuntime {
    fn with_handle<T>(
        &self,
        operation: impl FnOnce(&HardwareHandle) -> Result<T, UiFailure>,
    ) -> Result<T, UiFailure> {
        let slot = self
            .handle
            .lock()
            .map_err(|_| UiFailure::from(AppError::internal("hardware runtime unavailable")))?;
        let handle = slot
            .as_ref()
            .ok_or_else(|| UiFailure::from(unavailable("The hardware runtime is not running.")))?;
        operation(handle)
    }
}

trait HardwareShutdown: Send {
    fn close_admission(&self);
    fn cancel_sessions(&self);
    fn close(&mut self) -> Result<(), String>;
}
impl HardwareShutdown for HardwareHandle {
    fn close_admission(&self) {
        self.sessions().close_admission();
    }
    fn cancel_sessions(&self) {
        self.sessions().shutdown();
    }
    fn close(&mut self) -> Result<(), String> {
        self.shutdown().map_err(|error| error.to_string())
    }
}
impl<H: HardwareShutdown> ShutdownParticipant for HardwareRuntime<H> {
    fn stop_admission(&self) -> Result<(), String> {
        self.effects.stop_admission();
        if let Some(handle) = self.handle.lock().expect("hardware runtime").as_ref() {
            handle.close_admission();
        }
        Ok(())
    }
    fn cancel_and_join_producers(&self) -> Result<(), String> {
        if let Some(handle) = self.handle.lock().expect("hardware runtime").as_ref() {
            handle.cancel_sessions();
        }
        Ok(())
    }
    fn neutralize_and_release_outputs(&self) -> Result<(), String> {
        self.effects.neutralize_all(Duration::from_secs(5))
    }
    fn close_ports_and_network(&self) -> Result<(), String> {
        let mut slot = self.handle.lock().expect("hardware runtime");
        if let Some(handle) = slot.as_mut() {
            handle.close()?;
            slot.take();
        }
        Ok(())
    }
}

/// Non-Windows platforms report the driver as unsupported; the manager then
/// stays in `VjoyStatus::Unsupported` without touching native code.
#[cfg(not(windows))]
pub(crate) struct UnsupportedVjoyAdapter;

#[cfg(not(windows))]
impl trenino_runtime::vjoy::VjoyAdapter for UnsupportedVjoyAdapter {
    fn supported(&self) -> bool {
        false
    }
    fn driver_available(&mut self) -> Result<(), trenino_runtime::vjoy::VjoyError> {
        Err(trenino_runtime::vjoy::VjoyError::Unsupported)
    }
    fn device_status(
        &mut self,
        device: u8,
    ) -> Result<trenino_runtime::vjoy::VjoyDeviceStatus, trenino_runtime::vjoy::VjoyError> {
        Err(trenino_runtime::vjoy::VjoyError::DeviceMissing(device))
    }
    fn descriptor(
        &mut self,
        device: u8,
    ) -> Result<trenino_runtime::vjoy::DeviceDescriptor, trenino_runtime::vjoy::VjoyError> {
        Err(trenino_runtime::vjoy::VjoyError::DeviceMissing(device))
    }
    fn acquire_device(&mut self, device: u8) -> Result<(), trenino_runtime::vjoy::VjoyError> {
        Err(trenino_runtime::vjoy::VjoyError::DeviceMissing(device))
    }
    fn neutralize_device(&mut self, device: u8) -> Result<(), trenino_runtime::vjoy::VjoyError> {
        Err(trenino_runtime::vjoy::VjoyError::DeviceMissing(device))
    }
    fn release_device(&mut self, _device: u8) {}
}

#[cfg(windows)]
type PlatformVjoyAdapter = trenino_runtime::vjoy::windows::WindowsVjoyAdapter;
#[cfg(not(windows))]
type PlatformVjoyAdapter = UnsupportedVjoyAdapter;

pub(crate) struct VjoyRuntime {
    manager: Arc<trenino_runtime::vjoy::VjoyManager<PlatformVjoyAdapter>>,
    stop: std::sync::mpsc::Sender<()>,
    host: Mutex<Option<std::thread::JoinHandle<()>>>,
}
impl VjoyRuntime {
    fn start(
        manager: Arc<trenino_runtime::vjoy::VjoyManager<PlatformVjoyAdapter>>,
        hardware: Arc<HardwareRuntime>,
        db: Arc<trenino_runtime::storage::Database>,
    ) -> Self {
        let (stop, stopped) = std::sync::mpsc::channel();
        let live = manager.clone();
        let host = std::thread::spawn(move || {
            let mut revision = (
                db.revision("vjoy").unwrap_or(0),
                db.revision("bindings").unwrap_or(0),
                db.revision("hardware").unwrap_or(0),
            );
            let mut ports = std::collections::HashSet::new();
            loop {
                let _ = hardware.with_handle(|h| {
                    for p in h.connected_ports() {
                        if let Some(config) = p.config_id {
                            if ports.insert((p.port.clone(), p.generation, config.get())) {
                                let samples = h
                                    .input_cache()
                                    .snapshot(&p.port, p.generation)
                                    .into_iter()
                                    .filter_map(|(pin, value)| {
                                        h.resolver()
                                            .resolve(&p.port, p.generation, config, pin)
                                            .map(|identity| (identity, pin, value))
                                    })
                                    .collect::<Vec<_>>();
                                if let Err(e) =
                                    live.seed_port(&p.port, p.generation, config, &samples)
                                {
                                    eprintln!("vjoy port: {e}");
                                }
                            }
                        }
                    }
                    Ok(())
                });
                let next = (
                    db.revision("vjoy").unwrap_or(0),
                    db.revision("bindings").unwrap_or(0),
                    db.revision("hardware").unwrap_or(0),
                );
                if next != revision {
                    if let Err(e) = live.reload_mappings() {
                        eprintln!("vjoy reload: {e}");
                    }
                    revision = next;
                }
                if let Err(e) = live.poll_recovery_at(Instant::now()) {
                    eprintln!("vjoy recovery: {e}");
                }
                if stopped.recv_timeout(Duration::from_millis(100))
                    != Err(std::sync::mpsc::RecvTimeoutError::Timeout)
                {
                    break;
                }
            }
        });
        Self {
            manager,
            stop,
            host: Mutex::new(Some(host)),
        }
    }
}

impl ShutdownParticipant for VjoyRuntime {
    fn stop_admission(&self) -> Result<(), String> {
        self.manager.stop_admission();
        Ok(())
    }
    fn cancel_and_join_producers(&self) -> Result<(), String> {
        let _ = self.stop.send(());
        if let Some(host) = self.host.lock().map_err(|_| "vjoy host poisoned")?.take() {
            host.join().map_err(|_| "vjoy host panicked")?;
        }
        Ok(())
    }
    fn neutralize_and_release_outputs(&self) -> Result<(), String> {
        self.manager
            .release_runtime()
            .map_err(|error| error.to_string())
    }
    fn close_ports_and_network(&self) -> Result<(), String> {
        Ok(()) // release_runtime acknowledged ownership release in the prior phase.
    }
}

/// Persists firmware upload history rows on the shared database worker. Holds
/// only a `Database` clone (never `Arc<AppServices>`) so the app shutdown
/// strong-count drain is unaffected.
pub(crate) struct DbUploadHistory {
    db: trenino_runtime::storage::Database,
}

fn history_operation_id() -> trenino_core::OperationId {
    let micros = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|duration| duration.as_micros())
        .unwrap_or(0);
    trenino_core::OperationId(micros)
}

fn history_error(error: trenino_runtime::storage::StorageError) -> String {
    format!("upload history persistence failed: {error}")
}

impl trenino_runtime::firmware::UploadHistoryPort for DbUploadHistory {
    fn record_started(
        &self,
        record: &trenino_runtime::firmware::UploadStartRecord,
    ) -> Result<(), String> {
        self.db
            .start_upload_history(
                history_operation_id(),
                trenino_runtime::storage::firmware_records::UploadStart {
                    upload_id: record.upload_id.clone(),
                    port: record.port.clone(),
                    board_type: record.board_type.clone(),
                    firmware_file_id: Some(record.firmware_file_id),
                },
            )
            .map(|_| ())
            .map_err(history_error)
    }
    fn record_completed(
        &self,
        upload_id: &str,
        avrdude_output: &str,
        _duration_ms: u64,
    ) -> Result<(), String> {
        let row = self
            .db
            .get_upload_history(upload_id)
            .map_err(history_error)?
            .ok_or_else(|| "upload history row missing".to_owned())?;
        self.db
            .complete_upload_history(
                history_operation_id(),
                row.id,
                Some(avrdude_output.to_owned()),
            )
            .map(|_| ())
            .map_err(history_error)
    }
    fn record_failed(
        &self,
        upload_id: &str,
        error_message: &str,
        avrdude_output: Option<&str>,
        _duration_ms: u64,
    ) -> Result<(), String> {
        let row = self
            .db
            .get_upload_history(upload_id)
            .map_err(history_error)?
            .ok_or_else(|| "upload history row missing".to_owned())?;
        self.db
            .fail_upload_history(
                history_operation_id(),
                row.id,
                error_message.to_owned(),
                avrdude_output.map(str::to_owned),
            )
            .map(|_| ())
            .map_err(history_error)
    }
    fn record_cancelled(&self, upload_id: &str, _duration_ms: u64) -> Result<(), String> {
        let row = self
            .db
            .get_upload_history(upload_id)
            .map_err(history_error)?
            .ok_or_else(|| "upload history row missing".to_owned())?;
        self.db
            .cancel_upload_history(history_operation_id(), row.id)
            .map(|_| ())
            .map_err(history_error)
    }
}

/// Stops the MCP HTTP listener during the "close ports and network" phase.
/// Built and started by the wave integrator via
/// `RustAppState::install_mcp_server` (the storage-backed `Ports` construction
/// lands in a sibling track).
pub(crate) struct McpParticipant {
    server: Arc<trenino_runtime::mcp::server::McpServer>,
}

impl ShutdownParticipant for McpParticipant {
    fn stop_admission(&self) -> Result<(), String> {
        self.server.stop_admission()?;
        self.server.stop()
    }
    fn cancel_and_join_producers(&self) -> Result<(), String> {
        Ok(())
    }
    fn neutralize_and_release_outputs(&self) -> Result<(), String> {
        Ok(())
    }
    fn close_ports_and_network(&self) -> Result<(), String> {
        self.server.stop()
    }
}

/// Cancels any in-flight avrdude upload before ports close.
pub(crate) struct UploadParticipant {
    manager: Arc<trenino_runtime::firmware::UploadManager>,
}

impl ShutdownParticipant for UploadParticipant {
    fn stop_admission(&self) -> Result<(), String> {
        Ok(())
    }
    fn cancel_and_join_producers(&self) -> Result<(), String> {
        if let Some(current) = self.manager.current_upload() {
            match self.manager.cancel_upload(&current.upload_id) {
                Ok(()) | Err(trenino_runtime::firmware::UploadCancelError::NotFound) => {}
                Err(e) => return Err(format!("upload cancellation: {e:?}")),
            }
        }
        self.manager.retry_cleanup()
    }
    fn neutralize_and_release_outputs(&self) -> Result<(), String> {
        Ok(())
    }
    fn close_ports_and_network(&self) -> Result<(), String> {
        Ok(())
    }
}

fn unavailable(message: &str) -> AppError {
    AppError {
        code: trenino_core::ErrorCode::Unavailable,
        message: message.into(),
        field_errors: Default::default(),
        retryable: true,
    }
}

fn parse_entity_id(field: &str, value: &str) -> Result<trenino_core::EntityId, UiFailure> {
    value
        .trim()
        .parse::<i64>()
        .ok()
        .map(trenino_core::EntityId)
        .ok_or_else(|| validation_failure(field, "Enter a valid record identifier."))
}

fn validation_failure(field: &str, message: &str) -> UiFailure {
    UiFailure {
        code: "validation".into(),
        message: "Check the highlighted field.".into(),
        field_errors: std::collections::BTreeMap::from([(field.into(), message.into())]),
        retryable: false,
    }
}

fn vjoy_failure(error: trenino_runtime::vjoy::VjoyError) -> UiFailure {
    use trenino_runtime::vjoy::{configurator::ConfiguratorError, VjoyError};
    let (code, retryable) = match &error {
        VjoyError::ArbiterBusy | VjoyError::DeviceBusy(_) => ("conflict", true),
        VjoyError::Configurator(error) => match error {
            ConfiguratorError::UacCancelled => ("cancelled", true),
            ConfiguratorError::Timeout => ("unavailable", true),
            ConfiguratorError::Busy | ConfiguratorError::ForeignDevice => ("conflict", true),
            ConfiguratorError::InvalidDevice => ("validation", false),
            ConfiguratorError::UntrustedResource | ConfiguratorError::Unsupported => {
                ("unavailable", false)
            }
            ConfiguratorError::CleanupIncomplete
            | ConfiguratorError::DriverMissing
            | ConfiguratorError::Incompatible
            | ConfiguratorError::ProcessExit(_)
            | ConfiguratorError::MarkerWriteFailed
            | ConfiguratorError::Native(_) => ("unavailable", true),
        },
        VjoyError::Unsupported
        | VjoyError::DriverUnavailable(_)
        | VjoyError::DeviceMissing(_)
        | VjoyError::IncompatibleDevice(_, _)
        | VjoyError::AcquireFailed(_, _)
        | VjoyError::NeutralizeFailed(_, _)
        | VjoyError::InvalidState(_)
        | VjoyError::Quarantined(_, _)
        | VjoyError::ReportFailed(_, _)
        | VjoyError::Storage(_) => ("unavailable", true),
    };
    UiFailure {
        code: code.into(),
        message: error.to_string(),
        field_errors: Default::default(),
        retryable,
    }
}

fn catalog_failure(error: trenino_runtime::firmware::CatalogError) -> UiFailure {
    let _ = error;
    UiFailure {
        code: "unavailable".into(),
        message: "The firmware catalog could not be reached; try again.".into(),
        field_errors: Default::default(),
        retryable: true,
    }
}

fn download_failure(error: trenino_runtime::firmware::DownloadError) -> UiFailure {
    let _ = error;
    UiFailure {
        code: "unavailable".into(),
        message: "The firmware file could not be downloaded; try again.".into(),
        field_errors: Default::default(),
        retryable: true,
    }
}

fn upload_failure(error: trenino_runtime::firmware::UploadStartError) -> UiFailure {
    use trenino_runtime::firmware::UploadStartError;
    let code = match error {
        UploadStartError::UploadInProgress | UploadStartError::FirmwareNotDownloaded => "conflict",
        _ => "unavailable",
    };
    UiFailure {
        code: code.into(),
        message: format!("The firmware upload could not start: {error:?}"),
        field_errors: Default::default(),
        retryable: true,
    }
}

/// Database-backed adapter for the firmware catalog port. Converts between the
/// storage rows and the catalog view, parsing the persisted manifest JSON.
struct DbFirmwareRepository {
    db: trenino_runtime::storage::Database,
}

fn repo_failure(
    error: trenino_runtime::storage::StorageError,
) -> trenino_runtime::firmware::RepositoryError {
    let _ = error;
    trenino_runtime::firmware::RepositoryError { code: "storage" }
}

fn row_to_release(
    record: &trenino_runtime::storage::firmware_records::FirmwareReleaseRecord,
    files: &[trenino_runtime::storage::firmware_records::FirmwareFileRecord],
) -> Result<trenino_runtime::firmware::CatalogRelease, trenino_runtime::firmware::RepositoryError> {
    use trenino_runtime::firmware::{CatalogRelease, FirmwareAsset, FirmwareDevice};
    let manifest: trenino_core::firmware::FirmwareManifest = match &record.manifest_json {
        Some(raw) => serde_json::from_str(raw)
            .map_err(|_| trenino_runtime::firmware::RepositoryError { code: "manifest" })?,
        None => trenino_core::firmware::FirmwareManifest {
            version: record.version.clone(),
            project: String::new(),
            devices: Vec::new(),
            release_date: None,
        },
    };
    let devices = manifest
        .devices
        .iter()
        .map(|device| FirmwareDevice {
            manifest: device.clone(),
            asset: files
                .iter()
                .find(|file| {
                    file.environment.as_deref() == Some(device.environment.as_str())
                        && device.firmware_file
                            == file.download_url.rsplit('/').next().unwrap_or_default()
                })
                .map(|file| FirmwareAsset {
                    id: file.id,
                    github_asset_id: None,
                    filename: file
                        .download_url
                        .rsplit('/')
                        .next()
                        .unwrap_or("firmware.hex")
                        .to_owned(),
                    download_url: reqwest::Url::parse(&file.download_url)
                        .unwrap_or_else(|_| reqwest::Url::parse("https://localhost/").unwrap()),
                    size: file.file_size.map(|size| size.max(0) as u64),
                    environment: file.environment.clone(),
                    board_type: file.board_type.clone(),
                }),
        })
        .collect();
    Ok(CatalogRelease {
        id: record.id,
        version: record.version.clone(),
        tag_name: record.tag_name.clone(),
        release_url: record
            .release_url
            .as_deref()
            .and_then(|value| reqwest::Url::parse(value).ok()),
        release_notes: record.release_notes.clone(),
        published_at: record.published_at.clone(),
        manifest,
        devices,
    })
}

impl trenino_runtime::firmware::FirmwareRepository for DbFirmwareRepository {
    fn upsert_catalog(
        &self,
        releases: &[trenino_runtime::firmware::ReleaseInput],
    ) -> Result<
        Vec<trenino_runtime::firmware::CatalogRelease>,
        trenino_runtime::firmware::RepositoryError,
    > {
        use trenino_runtime::storage::firmware_records::{FirmwareFileDraft, FirmwareReleaseDraft};
        let entries = releases
            .iter()
            .map(|release| {
                let files = release
                    .devices
                    .iter()
                    .filter_map(|device| {
                        device.asset.as_ref().map(|asset| FirmwareFileDraft {
                            board_type: asset.board_type.clone(),
                            environment: asset.environment.clone(),
                            download_url: asset.download_url.to_string(),
                            file_size: asset.size.map(|size| size.min(i64::MAX as u64) as i64),
                        })
                    })
                    .collect();
                trenino_runtime::storage::firmware_records::CatalogUpsert {
                    release: FirmwareReleaseDraft {
                        version: release.version.clone(),
                        tag_name: release.tag_name.clone(),
                        release_url: release.release_url.as_ref().map(ToString::to_string),
                        release_notes: release.release_notes.clone(),
                        published_at: release.published_at.clone(),
                        manifest_json: serde_json::to_string(&release.manifest).ok(),
                    },
                    files,
                }
            })
            .collect::<Vec<_>>();
        self.db
            .upsert_catalog(history_operation_id(), entries)
            .map_err(repo_failure)?;
        self.list_releases()
    }
    fn list_releases(
        &self,
    ) -> Result<
        Vec<trenino_runtime::firmware::CatalogRelease>,
        trenino_runtime::firmware::RepositoryError,
    > {
        let mut releases = Vec::new();
        for record in self.db.list_firmware_releases().map_err(repo_failure)? {
            let files = self
                .db
                .firmware_files_for_release(record.id)
                .map_err(repo_failure)?;
            releases.push(row_to_release(&record, &files)?);
        }
        Ok(releases)
    }
    fn get_release(
        &self,
        release_id: trenino_core::EntityId,
    ) -> Result<
        Option<trenino_runtime::firmware::CatalogRelease>,
        trenino_runtime::firmware::RepositoryError,
    > {
        let Some(record) = self
            .db
            .get_firmware_release(release_id)
            .map_err(repo_failure)?
        else {
            return Ok(None);
        };
        let files = self
            .db
            .firmware_files_for_release(record.id)
            .map_err(repo_failure)?;
        row_to_release(&record, &files).map(Some)
    }
    fn record_check(
        &self,
        record: &trenino_runtime::firmware::UpdateCheckRecord,
    ) -> Result<(), trenino_runtime::firmware::RepositoryError> {
        let checked_at = format_checked_at((record.checked_at_ms / 1000) as i64);
        self.db
            .record_update_check(
                history_operation_id(),
                trenino_runtime::storage::firmware_records::UpdateCheckDraft {
                    checked_at,
                    found_updates: record.found_updates,
                    latest_version: record.latest_version.clone(),
                    error_message: record.error_message.clone(),
                },
            )
            .map(|_| ())
            .map_err(repo_failure)
    }
    fn latest_check(
        &self,
    ) -> Result<
        Option<trenino_runtime::firmware::UpdateCheckRecord>,
        trenino_runtime::firmware::RepositoryError,
    > {
        self.db
            .latest_update_check()
            .map_err(repo_failure)?
            .map(|row| {
                Ok(trenino_runtime::firmware::UpdateCheckRecord {
                    checked_at_ms: runtime_firmware::checked_at_ms(&row.checked_at).ok_or(
                        trenino_runtime::firmware::RepositoryError {
                            code: "invalid_check_timestamp",
                        },
                    )?,
                    found_updates: row.found_updates,
                    latest_version: row.latest_version,
                    error_message: row.error_message,
                })
            })
            .transpose()
    }

    fn dismissed_notice(
        &self,
    ) -> Result<Option<String>, trenino_runtime::firmware::RepositoryError> {
        self.db
            .get("firmware_dismissed_notice")
            .map_err(repo_failure)
    }
    fn set_dismissed_notice(
        &self,
        version: Option<&str>,
    ) -> Result<(), trenino_runtime::firmware::RepositoryError> {
        match version {
            Some(version) => {
                self.db
                    .set_with_revision("firmware_dismissed_notice", version, "firmware")
            }
            None => self
                .db
                .set_with_revision("firmware_dismissed_notice", "", "firmware"),
        }
        .map(|_| ())
        .map_err(repo_failure)
    }
}

fn firmware_catalog(
    db: &trenino_runtime::storage::Database,
) -> Result<trenino_runtime::firmware::FirmwareCatalog<DbFirmwareRepository>, UiFailure> {
    let client =
        trenino_runtime::firmware::FirmwareHttpClient::new(std::time::Duration::from_secs(30))
            .map_err(|_| UiFailure::from(AppError::internal("firmware HTTP client unavailable")))?;
    let requirement = trenino_core::firmware::FirmwareRequirement::parse(None)
        .map_err(|_| UiFailure::from(AppError::internal("firmware requirement invalid")))?;
    Ok(trenino_runtime::firmware::FirmwareCatalog::new(
        client,
        Arc::new(DbFirmwareRepository { db: db.clone() }),
        requirement,
    ))
}

fn avrdude_tooling(app: &AppHandle) -> trenino_runtime::firmware::UploadTooling {
    avrdude_tooling_at(
        std::env::var_os("TRENINO_AVRDUDE_PATH").map(PathBuf::from),
        std::env::current_exe()
            .ok()
            .and_then(|path| path.parent().map(std::path::Path::to_path_buf)),
        app.path().resource_dir().ok(),
    )
}

fn avrdude_tooling_at(
    configured: Option<PathBuf>,
    executable_dir: Option<PathBuf>,
    resource_dir: Option<PathBuf>,
) -> trenino_runtime::firmware::UploadTooling {
    use trenino_runtime::{executable::ExecutableProbe, firmware::UploadTooling};
    let mut probe = ExecutableProbe::avrdude();
    probe.configured = configured.clone();
    probe.app_resource_dir = executable_dir.clone();
    // Missing tools do not prevent editing offline. Preserve a rejected
    // configured path (never silently choose another binary); otherwise use
    // the absolute installed location so upload admission reports it missing.
    let fallback = configured.unwrap_or_else(|| {
        executable_dir.unwrap_or_default().join(if cfg!(windows) {
            "avrdude.exe"
        } else {
            "avrdude"
        })
    });
    let mut tooling = UploadTooling::discover_avrdude(&probe).unwrap_or(UploadTooling {
        avrdude_path: fallback,
        avrdude_conf: None,
    });
    if let Some(resources) = resource_dir {
        let configuration = resources.join("binaries").join("avrdude.conf");
        if configuration.is_file() {
            tooling.avrdude_conf = Some(configuration);
        }
    }
    tooling
}

/// Second-precision UTC timestamp (`YYYY-MM-DDTHH:MM:SSZ`), the wire format
/// required by the update-check storage contract.
fn format_checked_at(seconds: i64) -> String {
    let days = seconds.div_euclid(86_400);
    let seconds_of_day = seconds.rem_euclid(86_400);
    let hour = seconds_of_day / 3_600;
    let minute = (seconds_of_day % 3_600) / 60;
    let second = seconds_of_day % 60;
    // Howard Hinnant's civil-from-days algorithm.
    let z = days + 719_468;
    let era = z.div_euclid(146_097);
    let day_of_era = z.rem_euclid(146_097);
    let year_of_era =
        (day_of_era - day_of_era / 1_460 + day_of_era / 36_524 - day_of_era / 146_096) / 365;
    let mut year = year_of_era + era * 400;
    let day_of_year = day_of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100);
    let mp = (5 * day_of_year + 2) / 153;
    let day = day_of_year - (153 * mp + 2) / 5 + 1;
    let month = if mp < 10 { mp + 3 } else { mp - 9 };
    if month <= 2 {
        year += 1;
    }
    format!("{year:04}-{month:02}-{day:02}T{hour:02}:{minute:02}:{second:02}Z")
}

fn wired_failure(error: &str) -> String {
    format!("The Rust trial could not start its hardware runtime: {error}")
}

// ---- Command input payloads ----------------------------------------------

#[derive(Clone, Debug, serde::Deserialize)]
struct NotchInput {
    index: i64,
    kind: String,
    value: Option<f64>,
    min_value: Option<f64>,
    max_value: Option<f64>,
    input_min: Option<f64>,
    input_max: Option<f64>,
    sim_input_min: Option<f64>,
    sim_input_max: Option<f64>,
    description: Option<String>,
}

#[derive(Clone, Debug, serde::Deserialize)]
struct SequenceCommandInput {
    endpoint: String,
    value: f64,
    delay_ms: i64,
}

fn notch_draft(
    input: NotchInput,
) -> Result<trenino_runtime::storage::trains::NotchDraft, UiFailure> {
    let kind = match input.kind.as_str() {
        "gate" => trenino_runtime::storage::trains::NotchKind::Gate,
        "linear" => trenino_runtime::storage::trains::NotchKind::Linear,
        _ => {
            return Err(validation_failure(
                "kind",
                "Notch kind must be \"gate\" or \"linear\".",
            ))
        }
    };
    Ok(trenino_runtime::storage::trains::NotchDraft {
        index: input.index,
        kind,
        value: input.value,
        min_value: input.min_value,
        max_value: input.max_value,
        input_min: input.input_min,
        input_max: input.input_max,
        sim_input_min: input.sim_input_min,
        sim_input_max: input.sim_input_max,
        description: input.description,
    })
}

fn command_draft(
    input: SequenceCommandInput,
) -> trenino_runtime::storage::sequences::SequenceCommandDraft {
    trenino_runtime::storage::sequences::SequenceCommandDraft {
        endpoint: input.endpoint,
        value: input.value,
        delay_ms: input.delay_ms,
    }
}

fn command_input(
    inputs: Vec<SequenceCommandInput>,
) -> Vec<trenino_runtime::storage::sequences::SequenceCommandDraft> {
    inputs.into_iter().map(command_draft).collect()
}

macro_rules! command {
    ($(#[$meta:meta])* $name:ident($state:ident $(, $arg:ident: $ty:ty)*) -> $ret:ty = $body:expr) => {
        $(#[$meta])*
        #[tauri::command(rename_all = "snake_case")]
        async fn $name($state: State<'_, RustAppState>, $($arg: $ty,)*) -> Result<$ret, UiFailure> {
            let services = $state.services()?;
            tauri::async_runtime::spawn_blocking(move || ($body)(services, $($arg,)*))
                .await
                .map_err(|_| UiFailure::from(AppError::internal("command task failed")))?
                .map_err(UiFailure::from)
        }
    };
}

struct MutationPublication<T> {
    result: T,
    canonical: Option<UiSnapshot<serde_json::Value>>,
}

fn mutation_publication<T>(
    services: Arc<AppServices>,
    topic: Topic,
    mutate: impl FnOnce(Arc<AppServices>) -> Result<T, AppError>,
) -> Result<MutationPublication<T>, AppError> {
    let result = mutate(services.clone())?;
    // Command responses can be detail views. Subscription payloads always
    // match ui_get_snapshot for the topic, independent of the command DTO.
    // A refresh failure after the commit must not turn its ACK into rollback.
    let canonical = services
        .snapshot_json(topic)
        .ok()
        .and_then(|value| serde_json::from_value(value).ok());
    Ok(MutationPublication { result, canonical })
}

macro_rules! publishing_command {
    ($name:ident($app:ident, $state:ident $(, $arg:ident: $ty:ty)*) -> $ret:ty, $topic:expr, $body:expr) => {
        // Flat arguments preserve the existing frontend IPC contract.
        #[allow(clippy::too_many_arguments)]
        #[tauri::command(rename_all = "snake_case")]
        async fn $name<R: tauri::Runtime>($app: AppHandle<R>, $state: State<'_, RustAppState>, $($arg: $ty,)*) -> Result<$ret, UiFailure> {
            let _publication = $state.publication.lock().await;
            let services = $state.services()?;
            let outcome = tauri::async_runtime::spawn_blocking(move || mutation_publication(services, $topic, |services| ($body)(services, $($arg,)*)))
                .await
                .map_err(|_| UiFailure::from(AppError::internal("command task failed")))?
                .map_err(UiFailure::from)?;
            if let Some(snapshot) = outcome.canonical { publish_change(&$app, $topic, &snapshot); }
            Ok(outcome.result)
        }
    };
}

// ---- Settings --------------------------------------------------------------

#[tauri::command(rename_all = "snake_case")]
async fn ui_set_api_key(
    app: AppHandle,
    state: State<'_, RustAppState>,
    value: String,
) -> Result<UiSnapshot<SettingsView>, UiFailure> {
    let _publication = state.publication.lock().await;
    let services = state.services()?;
    let snapshot = tauri::async_runtime::spawn_blocking(move || services.set_api_key(&value))
        .await
        .map_err(|_| UiFailure::from(AppError::internal("settings task failed")))?
        .map_err(UiFailure::from)?;
    publish_change(&app, Topic::Settings, &snapshot);
    Ok(snapshot)
}

#[tauri::command(rename_all = "snake_case")]
async fn ui_set_simulator_url(
    app: AppHandle,
    state: State<'_, RustAppState>,
    value: String,
) -> Result<UiSnapshot<SettingsView>, UiFailure> {
    let _publication = state.publication.lock().await;
    let services = state.services()?;
    let snapshot = tauri::async_runtime::spawn_blocking(move || services.set_simulator_url(&value))
        .await
        .map_err(|_| UiFailure::from(AppError::internal("settings task failed")))?
        .map_err(UiFailure::from)?;
    publish_change(&app, Topic::Settings, &snapshot);
    Ok(snapshot)
}

/// Probes the configured TSW API (`Settings.test_connection` oracle): returns
/// `true` when the simulator answers the info endpoint. Transport, key and
/// HTTP failures surface distinct, actionable messages instead of a bare
/// `false`, so the settings form never fails silently.
#[tauri::command]
async fn ui_test_simulator(state: State<'_, RustAppState>) -> Result<bool, UiFailure> {
    let services = state.services()?;
    let (url, key) = tauri::async_runtime::spawn_blocking(move || {
        let url = services
            .database_op(|db| {
                db.get("simulator_url")
                    .map_err(|_| AppError::internal("settings read failed"))
            })?
            .unwrap_or_else(|| "http://localhost:31270".into());
        let key = services.simulator_api_key()?;
        Ok::<_, AppError>((url, key))
    })
    .await
    .map_err(|_| UiFailure::from(AppError::internal("settings task failed")))?
    .map_err(UiFailure::from)?;
    let client =
        trenino_runtime::simulator::client::SimulatorClient::new(&url, &key.unwrap_or_default())
            .map_err(|_| {
                UiFailure::from(validation_failure_error(
                    "simulator_url",
                    "Enter a valid HTTP or HTTPS URL.",
                ))
            })?;
    match client.info().await {
        Ok(_) => Ok(true),
        Err(error) => Err(UiFailure::from(simulator_probe_error(&url, &error))),
    }
}

/// Maps a failed `/info` probe to a user-facing error with a distinct message
/// per failure class (unreachable host, rejected key, unexpected HTTP status).
fn simulator_probe_error(
    url: &str,
    error: &trenino_runtime::simulator::client::SimulatorError,
) -> AppError {
    use trenino_runtime::simulator::client::SimulatorError;
    let unavailable = |message: String| AppError {
        code: trenino_core::ErrorCode::Unavailable,
        message,
        field_errors: std::collections::BTreeMap::new(),
        retryable: true,
    };
    match error {
        SimulatorError::HttpStatus { status: 403, .. } => AppError {
            code: trenino_core::ErrorCode::Validation,
            message: "The simulator rejected the API key (HTTP 403). Re-copy the key from CommAPIKey.txt on the PC running Train Sim World.".into(),
            field_errors: std::collections::BTreeMap::new(),
            retryable: false,
        },
        SimulatorError::HttpStatus { status, .. } => unavailable(format!(
            "The simulator at {url} returned HTTP {status}."
        )),
        SimulatorError::Transport(detail) => unavailable(format!(
            "Could not reach the simulator at {url} within the timeout. Check that the PC is awake, Windows Firewall allows TCP 31270 from your network, and Train Sim World runs with the API enabled. ({detail})"
        )),
        SimulatorError::InvalidJson(detail) => unavailable(format!(
            "The simulator at {url} answered but the response could not be read. ({detail})"
        )),
        SimulatorError::InvalidKey => AppError {
            code: trenino_core::ErrorCode::Validation,
            message: "The saved API key contains characters that cannot be sent. Re-enter the key from CommAPIKey.txt.".into(),
            field_errors: std::collections::BTreeMap::new(),
            retryable: false,
        },
        other => unavailable(format!("The simulator probe failed: {other:?}.")),
    }
}

fn validation_failure_error(field: &str, message: &str) -> AppError {
    AppError {
        code: trenino_core::ErrorCode::Validation,
        message: "Check the highlighted field.".into(),
        field_errors: std::collections::BTreeMap::from([(field.into(), message.into())]),
        retryable: false,
    }
}

// ---- Hardware configuration CRUD -------------------------------------------

publishing_command!(ui_create_configuration(app, state, name: String, description: Option<String>) -> UiSnapshot<trenino_core::ui::DeviceDetailView>, Topic::Hardware,
    |services: Arc<AppServices>, name: String, description: Option<String>| services.create_configuration_detail(&name, description));

publishing_command!(ui_update_configuration(app, state, id: String, name: Option<String>, description: NullableArg<String>) -> UiSnapshot<Vec<trenino_core::ui::ConfigurationSummaryView>>, Topic::Hardware,
|services: Arc<AppServices>, id: String, name: Option<String>, description: NullableArg<String>| {
    let description = description.0;
    let id = parse_entity_id("id", &id).map_err(to_app_failure)?;
    services.update_configuration(id, name, description)
});

publishing_command!(ui_delete_configuration(app, state, id: String) -> UiSnapshot<Vec<trenino_core::ui::ConfigurationSummaryView>>, Topic::Hardware,
|services: Arc<AppServices>, id: String| {
    let id = parse_entity_id("id", &id).map_err(to_app_failure)?;
    services.delete_configuration(id)
});

command!(ui_get_hardware_detail(state, id: String) -> UiSnapshot<trenino_core::ui::DeviceDetailView> =
|services: Arc<AppServices>, id: String| {
    let id = parse_entity_id("id", &id).map_err(to_app_failure)?;
    services.get_hardware_detail(id)
});

command!(ui_get_hardware_detail_by_config(state, config_id: String) -> UiSnapshot<trenino_core::ui::DeviceDetailView> =
|services: Arc<AppServices>, config_id: String| {
    let raw: u32 = config_id.trim().parse().map_err(|_| validation_failure_error("config_id", "Configuration ID must be a number."))?;
    let config_id = trenino_core::ConfigId::new(raw).map_err(|e| validation_failure_error("config_id", e))?;
    services.get_hardware_detail_by_config(config_id)
});

publishing_command!(ui_create_input(app, state, device_id: String, pin: i32, kind: String, sensitivity: Option<i32>, debounce: Option<i32>, name: Option<String>, matrix_id: Option<String>) -> UiSnapshot<trenino_core::ui::DeviceDetailView>, Topic::Hardware,
|services: Arc<AppServices>, device_id: String, pin: i32, kind: String, sensitivity: Option<i32>, debounce: Option<i32>, name: Option<String>, matrix_id: Option<String>| {
    let device_id = parse_entity_id("device_id", &device_id).map_err(to_app_failure)?;
    let matrix_id = matrix_id
        .map(|value| parse_entity_id("matrix_id", &value))
        .transpose()
        .map_err(to_app_failure)?;
    services.create_input(trenino_runtime::app::CreateInputParams {
        device_id,
        pin,
        kind,
        sensitivity,
        debounce,
        name,
        matrix_id,
    })
});

publishing_command!(ui_update_input(app, state, id: String, pin: i32, kind: String, sensitivity: Option<i32>, debounce: Option<i32>, name: Option<String>) -> UiSnapshot<trenino_core::ui::DeviceDetailView>, Topic::Hardware,
|services: Arc<AppServices>, id: String, pin: i32, kind: String, sensitivity: Option<i32>, debounce: Option<i32>, name: Option<String>| {
    let id = parse_entity_id("id", &id).map_err(to_app_failure)?;
    services.update_input(id, pin, &kind, sensitivity, debounce, name)
});

publishing_command!(ui_delete_input(app, state, id: String) -> UiSnapshot<trenino_core::ui::DeviceDetailView>, Topic::Hardware,
|services: Arc<AppServices>, id: String| {
    services.delete_input(parse_entity_id("id", &id).map_err(to_app_failure)?)
});

publishing_command!(ui_create_output(app, state, device_id: String, pin: i32, name: Option<String>) -> UiSnapshot<trenino_core::ui::DeviceDetailView>, Topic::Hardware,
|services: Arc<AppServices>, device_id: String, pin: i32, name: Option<String>| {
    let device_id = parse_entity_id("device_id", &device_id).map_err(to_app_failure)?;
    services.create_output(device_id, pin, name)
});

publishing_command!(ui_update_output(app, state, id: String, pin: i32, name: Option<String>) -> UiSnapshot<trenino_core::ui::DeviceDetailView>, Topic::Hardware,
|services: Arc<AppServices>, id: String, pin: i32, name: Option<String>| {
    let id = parse_entity_id("id", &id).map_err(to_app_failure)?;
    services.update_output(id, pin, name)
});

publishing_command!(ui_delete_output(app, state, id: String) -> UiSnapshot<trenino_core::ui::DeviceDetailView>, Topic::Hardware,
|services: Arc<AppServices>, id: String| {
    services.delete_output(parse_entity_id("id", &id).map_err(to_app_failure)?)
});

publishing_command!(ui_create_matrix(app, state, device_id: String, name: String, row_pins: Vec<i32>, col_pins: Vec<i32>) -> UiSnapshot<trenino_core::ui::DeviceDetailView>, Topic::Hardware,
|services: Arc<AppServices>, device_id: String, name: String, row_pins: Vec<i32>, col_pins: Vec<i32>| {
    let device_id = parse_entity_id("device_id", &device_id).map_err(to_app_failure)?;
    services.create_matrix(device_id, &name, row_pins, col_pins)
});

publishing_command!(ui_update_matrix(app, state, id: String, name: Option<String>, row_pins: Vec<i32>, col_pins: Vec<i32>) -> UiSnapshot<trenino_core::ui::DeviceDetailView>, Topic::Hardware,
|services: Arc<AppServices>, id: String, name: Option<String>, row_pins: Vec<i32>, col_pins: Vec<i32>| {
    services.update_matrix(parse_entity_id("id", &id).map_err(to_app_failure)?, name.as_deref(), row_pins, col_pins)
});

publishing_command!(ui_delete_matrix(app, state, id: String) -> UiSnapshot<trenino_core::ui::DeviceDetailView>, Topic::Hardware,
|services: Arc<AppServices>, id: String| {
    services.delete_matrix(parse_entity_id("id", &id).map_err(to_app_failure)?)
});

fn i2c_params(
    params: Option<trenino_core::ui::Ht16k33ParamsView>,
    create: bool,
) -> Result<Option<trenino_runtime::storage::Ht16k33Params>, UiFailure> {
    use trenino_runtime::storage::{DisplayType, Ht16k33Params};
    let Some(params) = params else {
        return Ok(create.then_some(Ht16k33Params {
            brightness: 8,
            num_digits: 4,
            display_type: DisplayType::FourteenSegment,
            has_dot: false,
            align_right: true,
            min_value: Some(0.0),
        }));
    };
    let display_type = match params.display_type.as_str() {
        "seven_segment" => DisplayType::SevenSegment,
        "fourteen_segment" => DisplayType::FourteenSegment,
        _ => {
            return Err(validation_failure(
                "params.display_type",
                "Select seven_segment or fourteen_segment.",
            ))
        }
    };
    Ok(Some(Ht16k33Params {
        brightness: params.brightness,
        num_digits: params.num_digits,
        display_type,
        has_dot: params.has_dot,
        align_right: params.align_right,
        min_value: params.min_value,
    }))
}

publishing_command!(ui_create_i2c_module(app, state, device_id: String, name: Option<String>, module_chip: String, i2c_address: i32, params: Option<trenino_core::ui::Ht16k33ParamsView>) -> UiSnapshot<trenino_core::ui::DeviceDetailView>, Topic::Hardware,
|services: Arc<AppServices>, device_id: String, name: Option<String>, module_chip: String, i2c_address: i32, params: Option<trenino_core::ui::Ht16k33ParamsView>| {
    let device_id = parse_entity_id("device_id", &device_id).map_err(to_app_failure)?;
    let params = i2c_params(params, true).map_err(to_app_failure)?;
    services.create_i2c_module(device_id, name, &module_chip, i2c_address, params)
});

publishing_command!(ui_update_i2c_module(app, state, id: String, name: Option<String>, module_chip: String, i2c_address: i32, params: Option<trenino_core::ui::Ht16k33ParamsView>) -> UiSnapshot<trenino_core::ui::DeviceDetailView>, Topic::Hardware,
|services: Arc<AppServices>, id: String, name: Option<String>, module_chip: String, i2c_address: i32, params: Option<trenino_core::ui::Ht16k33ParamsView>| {
    let id = parse_entity_id("id", &id).map_err(to_app_failure)?;
    let params = i2c_params(params, false).map_err(to_app_failure)?;
    services.update_i2c_module(id, name, &module_chip, i2c_address, params)
});

publishing_command!(ui_delete_i2c_module(app, state, id: String) -> UiSnapshot<trenino_core::ui::DeviceDetailView>, Topic::Hardware,
|services: Arc<AppServices>, id: String| {
    services.delete_i2c_module(parse_entity_id("id", &id).map_err(to_app_failure)?)
});

// ---- Calibration sessions ----------------------------------------------------

#[tauri::command(rename_all = "snake_case")]
async fn ui_start_calibration(
    state: State<'_, RustAppState>,
    port: String,
    generation: i64,
    pin: u8,
    input_id: String,
    max_hardware_value: i32,
) -> Result<String, UiFailure> {
    let input_id = parse_entity_id("input_id", &input_id)?;
    let _requested_ceiling = max_hardware_value;
    let max_hardware_value =
        trenino_runtime::preview::calibration_ceiling(&state.services()?.database(), input_id)
            .map_err(|e| {
                UiFailure::from(unavailable(&format!("Calibration unavailable: {e:?}")))
            })?;
    let runtime = state.hardware_runtime()?;
    tauri::async_runtime::spawn_blocking(move || {
        runtime.with_handle(|handle| {
            let session = trenino_runtime::hardware::sessions::CalibrationSession::new(
                trenino_core::SessionId(
                    std::time::SystemTime::now()
                        .duration_since(std::time::UNIX_EPOCH)
                        .map(|duration| duration.as_micros())
                        .unwrap_or(0),
                ),
                input_id,
                port,
                generation.max(0) as u64,
                pin,
                max_hardware_value,
            );
            handle
                .start_calibration(session)
                .map(|started| {
                    started
                        .lock()
                        .map(|session| session.id.0.to_string())
                        .unwrap_or_default()
                })
                .map_err(|error| UiFailure {
                    code: "conflict".into(),
                    message: format!("Calibration could not start: {error:?}"),
                    field_errors: Default::default(),
                    retryable: true,
                })
        })
    })
    .await
    .map_err(|_| UiFailure::from(AppError::internal("calibration task failed")))?
}

#[tauri::command(rename_all = "snake_case")]
async fn ui_advance_calibration(
    state: State<'_, RustAppState>,
    session_id: String,
) -> Result<Option<trenino_core::ui::CalibrationView>, UiFailure> {
    let session_id = session_id
        .trim()
        .parse::<u128>()
        .ok()
        .map(trenino_core::SessionId)
        .ok_or_else(|| validation_failure("session_id", "Enter a valid calibration session."))?;
    let runtime = state.hardware_runtime()?;
    tauri::async_runtime::spawn_blocking(move || {
        runtime.with_handle(|handle| {
            handle
                .advance_calibration(session_id)
                .map(|calibration| {
                    calibration.map(|value| trenino_core::ui::CalibrationView {
                        min_value: Some(value.min_value),
                        max_value: Some(value.max_value),
                        has_rollover: value.rollover,
                        is_inverted: value.inverted,
                    })
                })
                .map_err(|error| UiFailure {
                    code: "unavailable".into(),
                    message: format!("Calibration could not advance: {error:?}"),
                    field_errors: Default::default(),
                    retryable: true,
                })
        })
    })
    .await
    .map_err(|_| UiFailure::from(AppError::internal("calibration task failed")))?
}

#[tauri::command(rename_all = "snake_case")]
async fn ui_cancel_calibration(
    state: State<'_, RustAppState>,
    session_id: String,
) -> Result<bool, UiFailure> {
    let session_id = session_id
        .trim()
        .parse::<u128>()
        .ok()
        .map(trenino_core::SessionId)
        .ok_or_else(|| validation_failure("session_id", "Enter a valid calibration session."))?;
    let runtime = state.hardware_runtime()?;
    tauri::async_runtime::spawn_blocking(move || {
        runtime.with_handle(|handle| {
            handle
                .cancel_calibration(session_id)
                .map_err(|error| UiFailure {
                    code: "conflict".into(),
                    message: format!("Calibration could not be cancelled: {error:?}"),
                    field_errors: Default::default(),
                    retryable: true,
                })
        })
    })
    .await
    .map_err(|_| UiFailure::from(AppError::internal("calibration task failed")))?
}

// ---- Trains ------------------------------------------------------------------

command!(ui_get_train_detail(state, id: String) -> UiSnapshot<trenino_core::ui::TrainDetailView> =
|services: Arc<AppServices>, id: String| {
    services.get_train_detail(parse_entity_id("id", &id).map_err(to_app_failure)?)
});

publishing_command!(ui_create_train(app, state, name: String, description: Option<String>, identifiers: Vec<String>) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
    |services: Arc<AppServices>, name: String, description: Option<String>, identifiers: Vec<String>|
    services.create_train_entry(&name, description, identifiers));

publishing_command!(ui_update_train(app, state, id: String, name: Option<String>, description: NullableArg<String>, identifiers: Option<Vec<String>>) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
|services: Arc<AppServices>, id: String, name: Option<String>, description: NullableArg<String>, identifiers: Option<Vec<String>>| {
    let description = description.0;
    let id = parse_entity_id("id", &id).map_err(to_app_failure)?;
    services.update_train_entry(id, name, description, identifiers)
});

fn validate_train_deletion(
    id: trenino_core::EntityId,
    active: Option<trenino_core::EntityId>,
) -> Result<(), AppError> {
    if active == Some(id) {
        return Err(AppError {
            code: trenino_core::ErrorCode::Conflict,
            message: "The active train cannot be deleted. Switch trains first.".into(),
            field_errors: Default::default(),
            retryable: true,
        });
    }
    Ok(())
}
#[tauri::command(rename_all = "snake_case")]
async fn ui_delete_train<R: tauri::Runtime>(
    app: AppHandle<R>,
    state: State<'_, RustAppState>,
    id: String,
) -> Result<UiSnapshot<Vec<trenino_core::ui::TrainSummaryView>>, UiFailure> {
    let id = parse_entity_id("id", &id)?;
    let _publication = state.publication.lock().await;
    let services = state.services()?;
    let runtime = state.controls.lock()
        .map_err(|_| UiFailure::from(unavailable("Active train status is unavailable.")))?
        .as_ref().filter(|runtime|runtime.is_running()).cloned()
        .ok_or_else(||UiFailure::from(unavailable("Active train status is unavailable. Try again when the control runtime is running.")))?;
    let outcome = tauri::async_runtime::spawn_blocking(move || {
        mutation_publication(services, Topic::Trains, |services| {
            if !runtime.is_running() {
                return Err(unavailable("The control runtime is shutting down."));
            }
            // Read accepted runtime state immediately before mutation; client-side
            // selection/status is never trusted for this guard.
            validate_train_deletion(id, runtime.train.snapshot().active_train_id)?;
            services.delete_train_entry(id)
        })
    })
    .await
    .map_err(|_| UiFailure::from(AppError::internal("Delete train task failed.")))?
    .map_err(UiFailure::from)?;
    if let Some(snapshot) = outcome.canonical {
        publish_change(&app, Topic::Trains, &snapshot);
    }
    Ok(outcome.result)
}

/// Payload contract for `ui_activate_train` (`ActivateTrainResult` in
/// `client.ts`): the trains page renders `error` inline, so activation
/// failures are reported in-band instead of rejecting the IPC promise.
#[derive(Serialize)]
struct TrainActivationView {
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

fn activation_failure_message(
    error: &trenino_runtime::train::service::ManualActivationError,
) -> String {
    use trenino_runtime::train::{detection::TrainConfigError, service::ManualActivationError};
    match error {
        ManualActivationError::Closed => "The train service is shutting down.".into(),
        ManualActivationError::Train(TrainConfigError::NotFound(_)) => {
            "The train could not be found. It may have been deleted.".into()
        }
        other => other.to_string(),
    }
}

/// Manual activation of one train profile. The frontend invokes with a
/// camelCase `trainId` key, so this command keeps the Tauri default casing
/// instead of the `rename_all = "snake_case"` used by most commands.
#[tauri::command]
async fn ui_activate_train(
    state: State<'_, RustAppState>,
    train_id: String,
) -> Result<TrainActivationView, UiFailure> {
    let id = parse_entity_id("train_id", &train_id)?;
    let runtime = state
        .controls
        .lock()
        .map_err(|_| UiFailure::from(unavailable("The train service is unavailable.")))?
        .as_ref()
        .filter(|runtime| runtime.is_running())
        .cloned()
        .ok_or_else(|| {
            UiFailure::from(unavailable(
                "The train service is not running. Try again when the control runtime is running.",
            ))
        })?;
    match runtime.train.activate_train(id).await {
        Ok(_) => Ok(TrainActivationView {
            ok: true,
            error: None,
        }),
        Err(error) => Ok(TrainActivationView {
            ok: false,
            error: Some(activation_failure_message(&error)),
        }),
    }
}

publishing_command!(ui_create_element(app, state, train_id: String, kind: String, name: String) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
|services: Arc<AppServices>, train_id: String, kind: String, name: String| {
    let train_id = parse_entity_id("train_id", &train_id).map_err(to_app_failure)?;
    services.create_element(train_id, &kind, &name)
});

publishing_command!(ui_delete_element(app, state, id: String) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
|services: Arc<AppServices>, id: String| {
    services.delete_element(parse_entity_id("id", &id).map_err(to_app_failure)?)
});

publishing_command!(ui_create_lever(app, state, element_id: String, min_endpoint: String, max_endpoint: String, value_endpoint: String, notch_count_endpoint: Option<String>, notch_index_endpoint: Option<String>, lever_type: Option<String>, inverted: bool) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
|services: Arc<AppServices>, element_id: String, min_endpoint: String, max_endpoint: String, value_endpoint: String, notch_count_endpoint: Option<String>, notch_index_endpoint: Option<String>, lever_type: Option<String>, inverted: bool| {
    let element_id = parse_entity_id("element_id", &element_id).map_err(to_app_failure)?;
    services.create_lever(trenino_runtime::app::CreateLeverParams {
        element_id,
        min_endpoint,
        max_endpoint,
        value_endpoint,
        notch_count_endpoint,
        notch_index_endpoint,
        lever_type,
        inverted,
    })
});

publishing_command!(ui_update_lever(app, state, id: String, min_endpoint: Option<String>, max_endpoint: Option<String>, value_endpoint: Option<String>, notch_count_endpoint: NullableArg<String>, notch_index_endpoint: NullableArg<String>, lever_type: NullableArg<String>, inverted: Option<bool>) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
|services: Arc<AppServices>, id: String, min_endpoint: Option<String>, max_endpoint: Option<String>, value_endpoint: Option<String>, notch_count_endpoint: NullableArg<String>, notch_index_endpoint: NullableArg<String>, lever_type: NullableArg<String>, inverted: Option<bool>| {
    let notch_count_endpoint = notch_count_endpoint.0;
    let notch_index_endpoint = notch_index_endpoint.0;
    let lever_type = lever_type.0;
    let id = parse_entity_id("id", &id).map_err(to_app_failure)?;
    services.update_lever(trenino_runtime::app::UpdateLeverParams {
        lever_config_id: id,
        min_endpoint,
        max_endpoint,
        value_endpoint,
        notch_count_endpoint,
        notch_index_endpoint,
        lever_type,
        inverted,
    })
});

publishing_command!(ui_create_notch(app, state, lever_config_id: String, notch: NotchInput) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
|services: Arc<AppServices>, lever_config_id: String, notch: NotchInput| {
    let lever_config_id = parse_entity_id("lever_config_id", &lever_config_id).map_err(to_app_failure)?;
    services.create_notch_entry(lever_config_id, notch_draft(notch).map_err(to_app_failure)?)
});

publishing_command!(ui_update_notch(app, state, id: String, index: Option<i64>, kind: Option<String>, value: NullableArg<f64>, min_value: NullableArg<f64>, max_value: NullableArg<f64>, input_min: NullableArg<f64>, input_max: NullableArg<f64>, sim_input_min: NullableArg<f64>, sim_input_max: NullableArg<f64>) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
|services: Arc<AppServices>, id: String, index: Option<i64>, kind: Option<String>, value: NullableArg<f64>, min_value: NullableArg<f64>, max_value: NullableArg<f64>, input_min: NullableArg<f64>, input_max: NullableArg<f64>, sim_input_min: NullableArg<f64>, sim_input_max: NullableArg<f64>| {
    let value = value.0;
    let min_value = min_value.0;
    let max_value = max_value.0;
    let input_min = input_min.0;
    let input_max = input_max.0;
    let sim_input_min = sim_input_min.0;
    let sim_input_max = sim_input_max.0;
    let id = parse_entity_id("id", &id).map_err(to_app_failure)?;
    let kind = match kind.as_deref() {
        Some("gate") => Some(trenino_runtime::storage::trains::NotchKind::Gate),
        Some("linear") => Some(trenino_runtime::storage::trains::NotchKind::Linear),
        Some(_) => return Err(to_app_failure(validation_failure("kind", "Notch kind must be \"gate\" or \"linear\"."))),
        None => None,
    };
    services.update_notch_entry(id, trenino_runtime::storage::trains::NotchPatch {
        index, kind, value, min_value, max_value, input_min, input_max, sim_input_min, sim_input_max,
    })
});

publishing_command!(ui_delete_notch(app, state, id: String) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
|services: Arc<AppServices>, id: String| {
    services.delete_notch_entry(parse_entity_id("id", &id).map_err(to_app_failure)?)
});

publishing_command!(ui_save_notches(app, state, lever_config_id: String, notches: Vec<NotchInput>) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
|services: Arc<AppServices>, lever_config_id: String, notches: Vec<NotchInput>| {
    let lever_config_id = parse_entity_id("lever_config_id", &lever_config_id).map_err(to_app_failure)?;
    let notches = notches
        .into_iter()
        .map(notch_draft)
        .collect::<Result<Vec<_>, _>>()
        .map_err(to_app_failure)?;
    services.save_notches(lever_config_id, notches)
});

publishing_command!(ui_auto_distribute_notches(app, state, lever_config_id: String) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
|services: Arc<AppServices>, lever_config_id: String| {
    services.auto_distribute_notches(parse_entity_id("lever_config_id", &lever_config_id).map_err(to_app_failure)?)
});

command!(ui_validate_notches(state, lever_config_id: String) -> UiSnapshot<trenino_core::ui::NotchRangesValidationView> =
|services: Arc<AppServices>, lever_config_id: String| {
    services.validate_notch_ranges(parse_entity_id("lever_config_id", &lever_config_id).map_err(to_app_failure)?)
});

// ---- Sequences ----------------------------------------------------------------

publishing_command!(ui_create_sequence(app, state, train_id: String, name: String) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
|services: Arc<AppServices>, train_id: String, name: String| {
    services.create_sequence_entry(parse_entity_id("train_id", &train_id).map_err(to_app_failure)?, &name)
});

publishing_command!(ui_update_sequence(app, state, id: String, name: Option<String>) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
|services: Arc<AppServices>, id: String, name: Option<String>| {
    services.update_sequence_entry(parse_entity_id("id", &id).map_err(to_app_failure)?, name)
});

publishing_command!(ui_delete_sequence(app, state, id: String) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
|services: Arc<AppServices>, id: String| {
    services.delete_sequence_entry(parse_entity_id("id", &id).map_err(to_app_failure)?)
});

publishing_command!(ui_set_sequence_commands(app, state, sequence_id: String, commands: Vec<SequenceCommandInput>) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
|services: Arc<AppServices>, sequence_id: String, commands: Vec<SequenceCommandInput>| {
    let sequence_id = parse_entity_id("sequence_id", &sequence_id).map_err(to_app_failure)?;
    services.set_sequence_commands_entry(sequence_id, command_input(commands))
});

publishing_command!(ui_add_sequence_command(app, state, sequence_id: String, command: SequenceCommandInput) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
|services: Arc<AppServices>, sequence_id: String, command: SequenceCommandInput| {
    let sequence_id = parse_entity_id("sequence_id", &sequence_id).map_err(to_app_failure)?;
    services.add_sequence_command_entry(sequence_id, command_draft(command))
});

publishing_command!(ui_delete_sequence_command(app, state, command_id: String) -> UiSnapshot<trenino_core::ui::TrainDetailView>, Topic::Trains,
|services: Arc<AppServices>, command_id: String| {
    services.delete_sequence_command_entry(parse_entity_id("command_id", &command_id).map_err(to_app_failure)?)
});

/// Runs a stored sequence through the accepted connection's owned session host.
/// Completion is acknowledged only after every command succeeds; replacement,
/// cancellation and shutdown stop the owned run before later commands execute.
#[tauri::command(rename_all = "snake_case")]
async fn ui_test_sequence(
    state: State<'_, RustAppState>,
    sequence_id: String,
) -> Result<bool, UiFailure> {
    let sequence_id = parse_entity_id("sequence_id", &sequence_id)?;
    let services = state.services()?;
    let sessions = state
        .controls
        .lock()
        .map_err(|_| UiFailure::from(unavailable("The control runtime is unavailable.")))?
        .as_ref()
        .filter(|runtime| runtime.is_running())
        .map(|runtime| runtime.sessions.clone())
        .ok_or_else(|| UiFailure::from(unavailable("The control runtime is not running.")))?;
    let commands = tauri::async_runtime::spawn_blocking(move || {
        services.database_op(|db| {
            if db
                .get_sequence(sequence_id)
                .map_err(|_| AppError::internal("sequence read failed"))?
                .is_none()
            {
                return Err(AppError {
                    code: trenino_core::ErrorCode::NotFound,
                    message: "The requested sequence was not found.".into(),
                    field_errors: Default::default(),
                    retryable: false,
                });
            }
            db.sequence_commands(sequence_id)
                .map_err(|_| AppError::internal("sequence commands failed"))?
                .into_iter()
                .map(|command| {
                    Ok(trenino_core::train::buttons::SequenceCommand {
                        endpoint: command.endpoint,
                        value: command.value,
                        position: command
                            .position
                            .try_into()
                            .map_err(|_| AppError::internal("invalid sequence position"))?,
                        delay_ms: command
                            .delay_ms
                            .try_into()
                            .map_err(|_| AppError::internal("invalid sequence delay"))?,
                    })
                })
                .collect::<Result<Vec<_>, AppError>>()
        })
    })
    .await
    .map_err(|_| UiFailure::from(AppError::internal("sequence task failed")))?
    .map_err(UiFailure::from)?;
    sessions
        .run_manual_sequence(commands)
        .await
        .map_err(sequence_session_failure)
}
fn sequence_session_failure(
    error: trenino_runtime::composition::sessions::SessionError,
) -> UiFailure {
    use trenino_runtime::composition::sessions::SessionError;
    let (code, retryable) = match &error {
        SessionError::InvalidInput(_) => ("validation", false),
        SessionError::Busy => ("conflict", true),
        SessionError::NotFound => ("not_found", false),
        SessionError::Cancelled => ("cancelled", true),
        SessionError::Deadline => ("unavailable", true),
        SessionError::Offline
        | SessionError::Closed
        | SessionError::CleanupFailed(_)
        | SessionError::Simulator(_) => ("unavailable", true),
    };
    UiFailure {
        code: code.into(),
        message: error.to_string(),
        field_errors: Default::default(),
        retryable,
    }
}

// ---- Scripts ------------------------------------------------------------------

publishing_command!(ui_create_script(app, state, train_id: String, name: String, code: String, triggers: Vec<String>) -> UiSnapshot<trenino_core::ui::ScriptsView>, Topic::Scripts,
|services: Arc<AppServices>, train_id: String, name: String, code: String, triggers: Vec<String>| {
    services.create_script_entry(parse_entity_id("train_id", &train_id).map_err(to_app_failure)?, &name, &code, triggers)
});

publishing_command!(ui_update_script(app, state, id: String, name: Option<String>, code: Option<String>, triggers: Option<Vec<String>>, enabled: Option<bool>) -> UiSnapshot<trenino_core::ui::ScriptsView>, Topic::Scripts,
|services: Arc<AppServices>, id: String, name: Option<String>, code: Option<String>, triggers: Option<Vec<String>>, enabled: Option<bool>| {
    let id = parse_entity_id("id", &id).map_err(to_app_failure)?;
    services.update_script_entry(id, trenino_runtime::storage::scripts::ScriptPatch { name, code, triggers, enabled })
});

publishing_command!(ui_delete_script(app, state, id: String) -> UiSnapshot<trenino_core::ui::ScriptsView>, Topic::Scripts,
|services: Arc<AppServices>, id: String| {
    services.delete_script_entry(parse_entity_id("id", &id).map_err(to_app_failure)?)
});

publishing_command!(ui_reload_scripts(app, state) -> UiSnapshot<trenino_core::ui::ScriptsView>, Topic::Scripts,
    |services: Arc<AppServices>| services.reload_scripts());

// ---- Bindings ----------------------------------------------------------------

publishing_command!(ui_bind_lever(app, state, lever_config_id: String, input_id: String, replace: bool) -> UiSnapshot<trenino_core::ui::BindingsView>, Topic::Bindings,
|services: Arc<AppServices>, lever_config_id: String, input_id: String, replace: bool| {
    services.bind_lever(
        parse_entity_id("lever_config_id", &lever_config_id).map_err(to_app_failure)?,
        parse_entity_id("input_id", &input_id).map_err(to_app_failure)?,
        replace,
    )
});

publishing_command!(ui_unbind_lever(app, state, lever_config_id: String) -> UiSnapshot<trenino_core::ui::BindingsView>, Topic::Bindings,
|services: Arc<AppServices>, lever_config_id: String| {
    services.unbind_lever(parse_entity_id("lever_config_id", &lever_config_id).map_err(to_app_failure)?)
});

publishing_command!(ui_set_lever_binding_enabled(app, state, lever_config_id: String, enabled: bool) -> UiSnapshot<trenino_core::ui::BindingsView>, Topic::Bindings,
|services: Arc<AppServices>, lever_config_id: String, enabled: bool| {
    services.set_lever_binding_enabled_entry(parse_entity_id("lever_config_id", &lever_config_id).map_err(to_app_failure)?, enabled)
});

fn parse_button_mode(
    value: &str,
) -> Result<trenino_runtime::storage::bindings::ButtonMode, UiFailure> {
    use trenino_runtime::storage::bindings::ButtonMode;
    match value {
        "simple" => Ok(ButtonMode::Simple),
        "momentary" => Ok(ButtonMode::Momentary),
        "sequence" => Ok(ButtonMode::Sequence),
        "keystroke" => Ok(ButtonMode::Keystroke),
        _ => Err(validation_failure(
            "mode",
            "Button mode must be simple, momentary, sequence or keystroke.",
        )),
    }
}

fn parse_hardware_type(
    value: &str,
) -> Result<trenino_runtime::storage::bindings::ButtonHardwareType, UiFailure> {
    use trenino_runtime::storage::bindings::ButtonHardwareType;
    match value {
        "momentary" => Ok(ButtonHardwareType::Momentary),
        "latching" => Ok(ButtonHardwareType::Latching),
        _ => Err(validation_failure(
            "hardware_type",
            "Hardware type must be momentary or latching.",
        )),
    }
}

fn parse_binding_operator(
    value: &str,
) -> Result<trenino_runtime::storage::bindings::OutputBindingOperator, UiFailure> {
    use trenino_runtime::storage::bindings::OutputBindingOperator;
    match value {
        "gt" => Ok(OutputBindingOperator::Gt),
        "gte" => Ok(OutputBindingOperator::Gte),
        "lt" => Ok(OutputBindingOperator::Lt),
        "lte" => Ok(OutputBindingOperator::Lte),
        "between" => Ok(OutputBindingOperator::Between),
        "eq_true" => Ok(OutputBindingOperator::EqTrue),
        "eq_false" => Ok(OutputBindingOperator::EqFalse),
        _ => Err(validation_failure(
            "operator",
            "Enter a supported comparison operator.",
        )),
    }
}

fn to_app_failure(failure: UiFailure) -> AppError {
    let code = match failure.code.as_str() {
        "validation" => trenino_core::ErrorCode::Validation,
        "conflict" => trenino_core::ErrorCode::Conflict,
        "not_found" => trenino_core::ErrorCode::NotFound,
        "cancelled" => trenino_core::ErrorCode::Cancelled,
        "unavailable" => trenino_core::ErrorCode::Unavailable,
        _ => trenino_core::ErrorCode::Internal,
    };
    AppError {
        code,
        message: failure.message,
        field_errors: failure.field_errors,
        retryable: failure.retryable,
    }
}

publishing_command!(ui_put_button_binding(app, state, element_id: String, input_id: String, endpoint: NullableArg<String>, on_value: Option<f64>, off_value: Option<f64>, enabled: Option<bool>, mode: Option<String>, hardware_type: Option<String>, repeat_interval_ms: Option<i64>, keystroke: NullableArg<String>, on_sequence_id: NullableArg<String>, off_sequence_id: NullableArg<String>, replace: bool) -> UiSnapshot<trenino_core::ui::BindingsView>, Topic::Bindings,
|services: Arc<AppServices>, element_id: String, input_id: String, endpoint: NullableArg<String>, on_value: Option<f64>, off_value: Option<f64>, enabled: Option<bool>, mode: Option<String>, hardware_type: Option<String>, repeat_interval_ms: Option<i64>, keystroke: NullableArg<String>, on_sequence_id: NullableArg<String>, off_sequence_id: NullableArg<String>, replace: bool| {
    let endpoint = endpoint.0;
    let keystroke = keystroke.0;
    let on_sequence_id = on_sequence_id.0;
    let off_sequence_id = off_sequence_id.0;
    let element_id = parse_entity_id("element_id", &element_id).map_err(to_app_failure)?;
    let input_id = parse_entity_id("input_id", &input_id).map_err(to_app_failure)?;
    let mode = mode.map(|value| parse_button_mode(&value)).transpose().map_err(to_app_failure)?;
    let hardware_type = hardware_type.map(|value| parse_hardware_type(&value)).transpose().map_err(to_app_failure)?;
    let on_sequence_id = on_sequence_id.map(|value| value.map(|value| parse_entity_id("on_sequence_id", &value)).transpose()).transpose().map_err(to_app_failure)?;
    let off_sequence_id = off_sequence_id.map(|value| value.map(|value| parse_entity_id("off_sequence_id", &value)).transpose()).transpose().map_err(to_app_failure)?;
    services.put_button_binding_patch(element_id, input_id, trenino_runtime::storage::bindings::ButtonBindingPatch {
        input_id: Some(input_id),
        endpoint, on_value, off_value, enabled, mode, hardware_type, repeat_interval_ms, keystroke, on_sequence_id, off_sequence_id,
    }, replace)
});

publishing_command!(ui_delete_button_binding(app, state, element_id: String) -> UiSnapshot<trenino_core::ui::BindingsView>, Topic::Bindings,
|services: Arc<AppServices>, element_id: String| {
    services.delete_button_binding_entry(parse_entity_id("element_id", &element_id).map_err(to_app_failure)?)
});

fn parse_output_type(
    value: &str,
) -> Result<trenino_runtime::storage::bindings::OutputType, UiFailure> {
    use trenino_runtime::storage::bindings::OutputType;
    match value {
        "led" => Ok(OutputType::Led),
        _ => Err(validation_failure(
            "output_type",
            "Output type must be a supported output kind.",
        )),
    }
}

publishing_command!(ui_create_output_binding(app, state, train_id: String, name: String, output_type: String, output_id: String, endpoint: String, operator: String, value_a: Option<f64>, value_b: Option<f64>, enabled: Option<bool>) -> UiSnapshot<trenino_core::ui::BindingsView>, Topic::Bindings,
|services: Arc<AppServices>, train_id: String, name: String, output_type: String, output_id: String, endpoint: String, operator: String, value_a: Option<f64>, value_b: Option<f64>, enabled: Option<bool>| {
    let train_id = parse_entity_id("train_id", &train_id).map_err(to_app_failure)?;
    let output_id = parse_entity_id("output_id", &output_id).map_err(to_app_failure)?;
    let output_type = parse_output_type(&output_type).map_err(to_app_failure)?;
    let operator = parse_binding_operator(&operator).map_err(to_app_failure)?;
    services.create_output_binding_entry(train_id, trenino_runtime::storage::bindings::OutputBindingDraft {
        name, output_type: Some(output_type), output_id, endpoint, operator, value_a, value_b, enabled,
    })
});

publishing_command!(ui_update_output_binding(app, state, id: String, name: Option<String>, output_type: Option<String>, output_id: Option<String>, endpoint: Option<String>, operator: Option<String>, value_a: NullableArg<f64>, value_b: NullableArg<f64>, enabled: Option<bool>) -> UiSnapshot<trenino_core::ui::BindingsView>, Topic::Bindings,
|services: Arc<AppServices>, id: String, name: Option<String>, output_type: Option<String>, output_id: Option<String>, endpoint: Option<String>, operator: Option<String>, value_a: NullableArg<f64>, value_b: NullableArg<f64>, enabled: Option<bool>| {
    let value_a = value_a.0;
    let value_b = value_b.0;
    let id = parse_entity_id("id", &id).map_err(to_app_failure)?;
    let output_type = output_type.map(|value| parse_output_type(&value)).transpose().map_err(to_app_failure)?;
    let operator = operator.map(|value| parse_binding_operator(&value)).transpose().map_err(to_app_failure)?;
    let output_id = output_id.map(|value| parse_entity_id("output_id", &value)).transpose().map_err(to_app_failure)?;
    services.update_output_binding_entry(id, trenino_runtime::storage::bindings::OutputBindingPatch {
        name, output_type, output_id, endpoint, operator, value_a, value_b, enabled,
    })
});

publishing_command!(ui_delete_output_binding(app, state, id: String) -> UiSnapshot<trenino_core::ui::BindingsView>, Topic::Bindings,
|services: Arc<AppServices>, id: String| {
    services.delete_output_binding_entry(parse_entity_id("id", &id).map_err(to_app_failure)?)
});

publishing_command!(ui_create_display_binding(app, state, train_id: String, i2c_module_id: String, name: Option<String>, endpoint: String, format_string: Option<String>, enabled: Option<bool>) -> UiSnapshot<trenino_core::ui::BindingsView>, Topic::Bindings,
|services: Arc<AppServices>, train_id: String, i2c_module_id: String, name: Option<String>, endpoint: String, format_string: Option<String>, enabled: Option<bool>| {
    let train_id = parse_entity_id("train_id", &train_id).map_err(to_app_failure)?;
    let i2c_module_id = parse_entity_id("i2c_module_id", &i2c_module_id).map_err(to_app_failure)?;
    services.create_display_binding_entry(train_id, trenino_runtime::storage::bindings::DisplayBindingDraft {
        i2c_module_id, name, endpoint, format_string, enabled,
    })
});

publishing_command!(ui_update_display_binding(app, state, id: String, i2c_module_id: Option<String>, name: NullableArg<String>, endpoint: Option<String>, format_string: Option<String>, enabled: Option<bool>) -> UiSnapshot<trenino_core::ui::BindingsView>, Topic::Bindings,
|services: Arc<AppServices>, id: String, i2c_module_id: Option<String>, name: NullableArg<String>, endpoint: Option<String>, format_string: Option<String>, enabled: Option<bool>| {
    let name = name.0;
    let id = parse_entity_id("id", &id).map_err(to_app_failure)?;
    let i2c_module_id = i2c_module_id.map(|value| parse_entity_id("i2c_module_id", &value)).transpose().map_err(to_app_failure)?;
    services.update_display_binding_entry(id, trenino_runtime::storage::bindings::DisplayBindingPatch {
        i2c_module_id, name, endpoint, format_string, enabled,
    })
});

publishing_command!(ui_delete_display_binding(app, state, id: String) -> UiSnapshot<trenino_core::ui::BindingsView>, Topic::Bindings,
|services: Arc<AppServices>, id: String| {
    services.delete_display_binding_entry(parse_entity_id("id", &id).map_err(to_app_failure)?)
});

// ---- Virtual joystick ----------------------------------------------------------

command!(ui_get_vjoy(state) -> UiSnapshot<trenino_core::ui::VjoyView> =
    |services: Arc<AppServices>| services.get_vjoy_snapshot());

#[tauri::command(rename_all = "snake_case")]
async fn ui_vjoy_enable(
    app: AppHandle,
    state: State<'_, RustAppState>,
) -> Result<UiSnapshot<trenino_core::ui::VjoyView>, UiFailure> {
    let _publication = state.publication.lock().await;
    state.vjoy_manager()?.enable().map_err(vjoy_failure)?;
    let services = state.services()?;
    let snapshot =
        tauri::async_runtime::spawn_blocking(move || services.confirm_vjoy_enabled(true))
            .await
            .map_err(|_| UiFailure::from(AppError::internal("vjoy task failed")))?
            .map_err(UiFailure::from)?;
    publish_change(&app, Topic::Vjoy, &snapshot);
    Ok(snapshot)
}

#[tauri::command(rename_all = "snake_case")]
async fn ui_vjoy_disable(
    app: AppHandle,
    state: State<'_, RustAppState>,
) -> Result<UiSnapshot<trenino_core::ui::VjoyView>, UiFailure> {
    let _publication = state.publication.lock().await;
    state.vjoy_manager()?.disable().map_err(vjoy_failure)?;
    let services = state.services()?;
    let snapshot =
        tauri::async_runtime::spawn_blocking(move || services.confirm_vjoy_enabled(false))
            .await
            .map_err(|_| UiFailure::from(AppError::internal("vjoy task failed")))?
            .map_err(UiFailure::from)?;
    publish_change(&app, Topic::Vjoy, &snapshot);
    Ok(snapshot)
}

publishing_command!(ui_set_vjoy_selection(app, state, devices: Vec<u8>) -> UiSnapshot<trenino_core::ui::VjoyView>, Topic::Vjoy,
    |services: Arc<AppServices>, devices: Vec<u8>| services.set_vjoy_selection(devices));

publishing_command!(ui_put_vjoy_mapping(app, state, input_id: String, device_index: u8, target: String, inverted: bool, replace: bool) -> UiSnapshot<trenino_core::ui::VjoyView>, Topic::Vjoy,
|services: Arc<AppServices>, input_id: String, device_index: u8, target: String, inverted: bool, replace: bool| {
    let input_id = parse_entity_id("input_id", &input_id).map_err(to_app_failure)?;
    let target = parse_vjoy_target(&target).map_err(to_app_failure)?;
    services.put_vjoy_mapping_entry(input_id, trenino_runtime::vjoy::store::MappingDraft { device_index, target, inverted }, replace)
});

fn parse_vjoy_target(value: &str) -> Result<trenino_runtime::vjoy::store::Target, UiFailure> {
    use trenino_runtime::vjoy::store::{Target, VjoyAxis};
    if let Some(axis) = value.strip_prefix("axis/") {
        return VjoyAxis::parse(axis).map(Target::Axis).ok_or_else(|| {
            validation_failure(
                "target",
                "Axis must be one of x, y, z, rx, ry, rz, slider_1, slider_2.",
            )
        });
    }
    if let Some(button) = value.strip_prefix("button/") {
        let button = button
            .trim()
            .parse::<u8>()
            .ok()
            .filter(|button| *button <= trenino_runtime::vjoy::store::MAX_BUTTON)
            .ok_or_else(|| validation_failure("target", "Button index is out of range."))?;
        return Ok(Target::Button(button));
    }
    Err(validation_failure(
        "target",
        "Target must be axis/<name> or button/<index>.",
    ))
}

publishing_command!(ui_delete_vjoy_mapping(app, state, id: String) -> UiSnapshot<trenino_core::ui::VjoyView>, Topic::Vjoy,
|services: Arc<AppServices>, id: String| {
    services.delete_vjoy_mapping_entry(parse_entity_id("id", &id).map_err(to_app_failure)?)
});

/// Payload contract for `ui_vjoy_status` (`VjoyStatusView` in `client.ts`).
/// The manager's public lifecycle status maps onto the five recovery states
/// the virtual joystick page understands, exhaustively:
/// - `Active` -> `"on"` (enabled and healthy)
/// - `Enabling` -> `"on"` (requested; the acquire transition is in progress)
/// - `Off` | `Disabling` -> `"off"` (nothing acquired, or release in progress)
/// - `Unsupported` -> `"off"` (this platform cannot host vJoy; no adapter
///   call ever happens, so there is nothing to recover)
/// - `NeedsSetup` -> `"needs_setup"` (saved enabled but a selected device is
///   absent from the driver)
/// - `NeedsCleanup` -> `"needs_cleanup"` (saved off but a Trenino-owned
///   device remains)
/// - `Degraded` | `Error` -> `"error"` (the last reason string rides along)
#[derive(Serialize)]
struct VjoyStatusView {
    state: &'static str,
    reason: Option<String>,
}

/// Payload contract for `ui_vjoy_remove_leftover` / `ui_vjoy_repair`
/// (`VjoyActionResult` in `client.ts`): recovery failures (invalid state,
/// foreign device refusal, UAC cancel, busy driver) are reported in-band
/// with the manager's reason instead of rejecting the IPC promise.
#[derive(Serialize)]
struct VjoyActionView {
    ok: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

fn vjoy_status_view(
    manager: &trenino_runtime::vjoy::VjoyManager<PlatformVjoyAdapter>,
) -> VjoyStatusView {
    use trenino_runtime::vjoy::VjoyStatus;
    let (status, reason) = manager.status_details();
    VjoyStatusView {
        state: match status {
            VjoyStatus::Active | VjoyStatus::Enabling => "on",
            VjoyStatus::Off | VjoyStatus::Disabling | VjoyStatus::Unsupported => "off",
            VjoyStatus::NeedsSetup => "needs_setup",
            VjoyStatus::NeedsCleanup => "needs_cleanup",
            VjoyStatus::Degraded | VjoyStatus::Error => "error",
        },
        reason: reason.map(|error| error.to_string()),
    }
}

#[tauri::command(rename_all = "snake_case")]
async fn ui_vjoy_status(state: State<'_, RustAppState>) -> Result<VjoyStatusView, UiFailure> {
    let manager = state.vjoy_manager()?;
    Ok(vjoy_status_view(manager.as_ref()))
}

/// Runs one recovery action on the manager and republishes the persisted vJoy
/// view so subscribed windows refresh alongside the page's status poll.
async fn vjoy_recovery_action<R: tauri::Runtime>(
    app: AppHandle<R>,
    state: State<'_, RustAppState>,
    action: impl FnOnce(
        &trenino_runtime::vjoy::VjoyManager<PlatformVjoyAdapter>,
    ) -> Result<(), trenino_runtime::vjoy::VjoyError>,
) -> Result<VjoyActionView, UiFailure> {
    let manager = state.vjoy_manager()?;
    if let Err(error) = action(manager.as_ref()) {
        return Ok(VjoyActionView {
            ok: false,
            error: Some(error.to_string()),
        });
    }
    let _publication = state.publication.lock().await;
    let services = state.services()?;
    let snapshot = tauri::async_runtime::spawn_blocking(move || services.get_vjoy_snapshot())
        .await
        .map_err(|_| UiFailure::from(AppError::internal("vjoy task failed")))?
        .map_err(UiFailure::from)?;
    publish_change(&app, Topic::Vjoy, &snapshot);
    Ok(VjoyActionView {
        ok: true,
        error: None,
    })
}

#[tauri::command(rename_all = "snake_case")]
async fn ui_vjoy_remove_leftover<R: tauri::Runtime>(
    app: AppHandle<R>,
    state: State<'_, RustAppState>,
) -> Result<VjoyActionView, UiFailure> {
    vjoy_recovery_action(app, state, |manager| manager.remove_leftover()).await
}

#[tauri::command(rename_all = "snake_case")]
async fn ui_vjoy_repair<R: tauri::Runtime>(
    app: AppHandle<R>,
    state: State<'_, RustAppState>,
) -> Result<VjoyActionView, UiFailure> {
    vjoy_recovery_action(app, state, |manager| manager.repair()).await
}

// ---- Firmware ------------------------------------------------------------------

/// Checks the firmware catalog upstream and refreshes the persisted catalog
/// (`Firmware.Live mount` / `UpdateChecker`), then records the check.
#[tauri::command(rename_all = "snake_case")]
async fn ui_check_firmware_updates<R: tauri::Runtime>(
    app: AppHandle<R>,
    state: State<'_, RustAppState>,
) -> Result<UiSnapshot<trenino_core::ui::FirmwareView>, UiFailure> {
    runtime_firmware::owner(&state)?
        .check()
        .await
        .map_err(runtime_firmware::failure)?;
    let _publication = state.publication.lock().await;
    let services = state.services()?;
    let snapshot = tauri::async_runtime::spawn_blocking(move || services.get_firmware_snapshot())
        .await
        .map_err(|_| UiFailure::from(AppError::internal("firmware task failed")))?
        .map_err(UiFailure::from)?;
    publish_change(&app, Topic::Firmware, &snapshot);
    Ok(snapshot)
}

/// Downloads the firmware asset for one release/environment into the local
/// cache (`Firmware.Downloader.download`).
#[tauri::command(rename_all = "snake_case")]
async fn ui_download_firmware(
    app: AppHandle,
    state: State<'_, RustAppState>,
    release_id: String,
    environment: String,
) -> Result<UiSnapshot<trenino_core::ui::FirmwareView>, UiFailure> {
    let _publication = state.publication.lock().await;
    let release_id = parse_entity_id("release_id", &release_id)?;
    let db = state.services()?.database();
    let catalog = firmware_catalog(&db)?;
    let selection = catalog
        .select(release_id, &environment)
        .map_err(catalog_failure)?;
    let app_dir = app.path().app_local_data_dir().map_err(|_| {
        UiFailure::from(unavailable("The firmware cache directory is unavailable."))
    })?;
    let cache_dir =
        trenino_runtime::firmware::FirmwareDownloader::cache_directory(true, &app_dir, &app_dir);
    let downloader = trenino_runtime::firmware::FirmwareDownloader::new(
        trenino_runtime::firmware::FirmwareHttpClient::new(std::time::Duration::from_secs(120))
            .map_err(|_| UiFailure::from(AppError::internal("firmware HTTP client unavailable")))?,
        cache_dir,
        4 * 1024 * 1024,
        2,
    );
    downloader
        .download(&selection)
        .await
        .map_err(download_failure)?;
    let services = state.services()?;
    let snapshot = tauri::async_runtime::spawn_blocking(move || services.get_firmware_snapshot())
        .await
        .map_err(|_| UiFailure::from(AppError::internal("firmware task failed")))?
        .map_err(UiFailure::from)?;
    publish_change(&app, Topic::Firmware, &snapshot);
    Ok(snapshot)
}

/// Starts an avrdude upload for one downloaded firmware file
/// (`FirmwareLive.handle_event("upload", ...)`).
#[tauri::command(rename_all = "snake_case")]
async fn ui_start_firmware_upload(
    app: AppHandle,
    state: State<'_, RustAppState>,
    firmware_file_id: String,
    port: String,
    environment: String,
    generation: i64,
) -> Result<String, UiFailure> {
    let firmware_file_id = parse_entity_id("firmware_file_id", &firmware_file_id)?;
    let db = state.services()?.database();
    let catalog = firmware_catalog(&db)?;
    let file = tauri::async_runtime::spawn_blocking({
        let db = db.clone();
        move || db.get_firmware_file(firmware_file_id)
    })
    .await
    .map_err(|_| UiFailure::from(AppError::internal("firmware task failed")))?
    .map_err(|_| UiFailure::from(unavailable("The firmware catalog is unavailable.")))?
    .ok_or_else(|| validation_failure("firmware_file_id", "Select a downloaded firmware file."))?;
    let selection = catalog
        .select(file.release_id, &environment)
        .map_err(catalog_failure)?;
    let app_dir = app.path().app_local_data_dir().map_err(|_| {
        UiFailure::from(unavailable("The firmware cache directory is unavailable."))
    })?;
    let downloader = trenino_runtime::firmware::FirmwareDownloader::new(
        trenino_runtime::firmware::FirmwareHttpClient::new(std::time::Duration::from_secs(30))
            .map_err(|_| UiFailure::from(AppError::internal("firmware HTTP client unavailable")))?,
        trenino_runtime::firmware::FirmwareDownloader::cache_directory(true, &app_dir, &app_dir),
        4 * 1024 * 1024,
        2,
    );
    let hex_path = downloader
        .cache_path(&selection)
        .map_err(download_failure)?;
    let manager = state.upload_manager()?;
    let upload_id = manager
        .start_upload(trenino_runtime::firmware::UploadRequest {
            port,
            environment,
            firmware_file_id,
            hex_path,
            upload_config: selection.upload_config,
            generation: generation.max(0) as u64,
        })
        .map_err(upload_failure)?;
    Ok(upload_id)
}

#[tauri::command(rename_all = "snake_case")]
async fn ui_cancel_firmware_upload(
    state: State<'_, RustAppState>,
    upload_id: String,
) -> Result<bool, UiFailure> {
    let manager = state.upload_manager()?;
    tauri::async_runtime::spawn_blocking(move || manager.cancel_upload(&upload_id).map(|_| true))
        .await
        .map_err(|_| UiFailure::from(AppError::internal("firmware task failed")))?
        .map_err(|error| match error {
            trenino_runtime::firmware::UploadCancelError::NotFound => UiFailure {code:"not_found".into(),message:"No upload with that identifier is running.".into(),field_errors:Default::default(),retryable:false},
            trenino_runtime::firmware::UploadCancelError::Timeout => UiFailure::from(unavailable("Upload cancellation is still waiting for the serial owner. Retry cancellation.")),
            trenino_runtime::firmware::UploadCancelError::CleanupIncomplete => UiFailure::from(unavailable("Upload stopped, but serial ownership cleanup is incomplete. Retry cleanup before using the device.")),
        })
}

command!(ui_firmware_history(state) -> UiSnapshot<trenino_core::ui::FirmwareView> =
    |services: Arc<AppServices>| services.get_firmware_snapshot());

command!(ui_get_bindings(state) -> UiSnapshot<trenino_core::ui::BindingsView> =
    |services: Arc<AppServices>| services.get_bindings_snapshot());

command!(ui_get_scripts(state) -> UiSnapshot<trenino_core::ui::ScriptsView> =
    |services: Arc<AppServices>| services.get_scripts_snapshot());

command!(ui_get_firmware(state) -> UiSnapshot<trenino_core::ui::FirmwareView> =
    |services: Arc<AppServices>| services.get_firmware_snapshot());

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn simulator_probe_errors_carry_distinct_actionable_messages() {
        use trenino_runtime::simulator::client::SimulatorError;

        let rejected = simulator_probe_error(
            "http://192.168.1.31:31270",
            &SimulatorError::HttpStatus {
                status: 403,
                body: serde_json::json!({}),
            },
        );
        assert_eq!(rejected.code, trenino_core::ErrorCode::Validation);
        assert!(!rejected.retryable);
        assert!(rejected.message.contains("rejected the API key"));

        let unreachable = simulator_probe_error(
            "http://192.168.1.31:31270",
            &SimulatorError::Transport("connection timed out".into()),
        );
        assert_eq!(unreachable.code, trenino_core::ErrorCode::Unavailable);
        assert!(unreachable.retryable);
        assert!(unreachable.message.contains("192.168.1.31:31270"));
        assert!(unreachable.message.contains("Firewall"));

        let server_error = simulator_probe_error(
            "http://localhost:31270",
            &SimulatorError::HttpStatus {
                status: 500,
                body: serde_json::json!({}),
            },
        );
        assert_eq!(server_error.code, trenino_core::ErrorCode::Unavailable);
        assert!(server_error.message.contains("HTTP 500"));
    }
    #[test]
    fn observer_registration_is_window_scoped_and_idempotent() {
        let state = RustAppState::empty();
        state
            .register("main", Topic::Settings, "observer-1")
            .unwrap();
        state
            .register("main", Topic::Settings, "observer-1")
            .unwrap();
        state
            .register("secondary", Topic::Settings, "observer-1")
            .unwrap();
        assert_eq!(state.windows_for(Topic::Settings).len(), 2);

        state
            .unregister("main", Topic::Settings, "observer-1")
            .unwrap();
        assert_eq!(state.windows_for(Topic::Settings), ["secondary"]);
        state
            .unregister("main", Topic::Settings, "observer-1")
            .unwrap();
        assert_eq!(state.windows_for(Topic::Settings), ["secondary"]);
    }

    #[test]
    fn observer_id_cannot_be_rebound_to_another_topic_and_window_close_cleans_up() {
        let state = RustAppState::empty();
        state.register("main", Topic::Trains, "observer-1").unwrap();
        assert!(state
            .register("main", Topic::Settings, "observer-1")
            .is_err());
        state.unregister_window("main");
        assert!(state.windows_for(Topic::Trains).is_empty());
    }

    #[test]
    fn invalid_observer_ids_are_rejected() {
        assert!(validate_subscription_id("").is_err());
        assert!(validate_subscription_id("bad\nobserver").is_err());
        assert!(validate_subscription_id(&"x".repeat(129)).is_err());
    }

    #[test]
    fn trial_database_override_must_be_absolute_and_never_falls_back() {
        let directory = tempfile::tempdir().unwrap();
        let default = directory.path().join("app/local/rust-trial/trenino.db");
        assert!(
            selected_trial_database_path(Some(PathBuf::from("relative.db")), default.clone())
                .is_err()
        );
        let override_path = directory.path().join("isolated/trial.db");
        assert_eq!(
            selected_trial_database_path(Some(override_path.clone()), default.clone()).unwrap(),
            override_path
        );
        assert_eq!(
            selected_trial_database_path(None, default.clone()).unwrap(),
            default
        );
    }

    #[test]
    fn startup_schema_refusal_is_actionable_and_reaches_the_dialog_presenter() {
        let mut shown = None;
        dispatch_startup_failure(
            &trenino_runtime::storage::StorageError::LegacyUpgradeRequired,
            |message| shown = Some(message.to_owned()),
        );
        let shown = shown.expect("startup refusal should be presented");
        assert!(shown.contains("backup"));
        assert!(shown.contains("maintenance upgrade"));
        assert!(!shown.contains("legacy.db"));
    }

    #[test]
    fn bootstrap_schema_refusal_explains_that_existing_data_was_preserved() {
        let mut shown = None;
        dispatch_startup_failure(
            &trenino_runtime::storage::StorageError::BootstrapUpgradeRequired,
            |message| shown = Some(message.to_owned()),
        );
        let shown = shown.expect("startup refusal should be presented");
        assert!(shown.contains("preserved"));
        assert!(shown.contains("backup"));
    }

    #[test]
    fn startup_failure_state_can_follow_normal_exit_without_installed_services() {
        let state = RustAppState::empty();
        state.shutdown().unwrap();
    }

    #[test]
    fn application_snapshot_adapter_matches_frontend_wire_contract() {
        let directory = tempfile::tempdir().unwrap();
        let state = RustAppState::empty();
        state
            .install(AppServices::open_full(directory.path().join("ui.db"), None).unwrap())
            .unwrap();
        let services = state.services().unwrap();

        let settings = services.snapshot_json(Topic::Settings).unwrap();
        assert_eq!(settings["epoch"], "1");
        assert_eq!(settings["topic"], "settings");
        assert_eq!(settings["revision"], "0");
        assert_eq!(settings["value"]["error_reporting"], "unset");
        assert_eq!(
            settings["value"]["simulator"]["url"],
            "http://localhost:31270"
        );

        let configurations = services.snapshot_json(Topic::Hardware).unwrap();
        assert_eq!(configurations["topic"], "hardware");
        assert!(configurations["value"].as_array().unwrap().is_empty());
        let trains = services.snapshot_json(Topic::Trains).unwrap();
        assert_eq!(trains["topic"], "trains");
        assert!(trains["value"].as_array().unwrap().is_empty());

        let firmware = services.snapshot_json(Topic::Firmware).unwrap();
        assert_eq!(firmware["topic"], "firmware");
        assert!(firmware["value"]["releases"].as_array().unwrap().is_empty());
        assert!(firmware["value"]["upload_history"]
            .as_array()
            .unwrap()
            .is_empty());
    }

    struct ShutdownSerial {
        events: Arc<Mutex<Vec<String>>>,
        fail: AtomicBool,
    }
    impl trenino_runtime::composition::hardware::EffectTransport for ShutdownSerial {
        fn connected_ports(&self) -> Vec<trenino_runtime::hardware::service::ConnectedPort> {
            vec![trenino_runtime::hardware::service::ConnectedPort {
                port: "panel".into(),
                firmware_version: None,
                generation: 1,
                config_id: None,
                device_id: None,
            }]
        }
        fn send_message(
            &self,
            _: &str,
            _: u64,
            message: trenino_core::hardware::protocol::Message,
            _: Duration,
        ) -> Result<(), String> {
            self.events.lock().unwrap().push(format!("{message:?}"));
            if self.fail.swap(false, Ordering::SeqCst) {
                Err("uncertain serial acknowledgement".into())
            } else {
                Ok(())
            }
        }
    }
    struct ShutdownHandle {
        events: Arc<Mutex<Vec<String>>>,
        remaining_failures: usize,
    }
    impl HardwareShutdown for ShutdownHandle {
        fn close_admission(&self) {}
        fn cancel_sessions(&self) {}
        fn close(&mut self) -> Result<(), String> {
            self.events.lock().unwrap().push("close".into());
            if self.remaining_failures > 0 {
                self.remaining_failures -= 1;
                Err("close not yet acknowledged".into())
            } else {
                Ok(())
            }
        }
    }
    fn shutdown_hardware_fixture(
        fail_close: bool,
    ) -> (
        tempfile::TempDir,
        Arc<HardwareRuntime<ShutdownHandle>>,
        Arc<ShutdownSerial>,
    ) {
        let directory = tempfile::tempdir().unwrap();
        let database = Arc::new(
            trenino_runtime::storage::Database::open_full(directory.path().join("hardware.db"))
                .unwrap(),
        );
        let events = Arc::new(Mutex::new(Vec::new()));
        let serial = Arc::new(ShutdownSerial {
            events: events.clone(),
            fail: AtomicBool::new(false),
        });
        let effects = Arc::new(LiveHardwareEffects::new(
            serial.clone(),
            database,
            Arc::new(Mutex::new(Default::default())),
        ));
        let runtime = Arc::new(HardwareRuntime {
            handle: Mutex::new(Some(ShutdownHandle {
                events,
                remaining_failures: if fail_close { 2 } else { 0 },
            })),
            effects,
        });
        (directory, runtime, serial)
    }
    #[test]
    fn hardware_shutdown_drains_manual_high_and_display_before_close_and_retries_failure() {
        use trenino_runtime::train::output_controller::{HardwareDispatch, OutputLevel};
        let (_directory, hardware, serial) = shutdown_hardware_fixture(false);
        hardware
            .effects
            .set_output("panel", 4, OutputLevel::High)
            .unwrap();
        hardware
            .effects
            .write_segments("panel", 0x70, vec![7; 8])
            .unwrap();
        serial.fail.store(true, Ordering::SeqCst);
        let shutdown = ShutdownCoordinator::default();
        shutdown.register(hardware.clone()).unwrap();
        assert!(shutdown.shutdown(|| Ok(())).is_err());
        assert!(!serial
            .events
            .lock()
            .unwrap()
            .iter()
            .any(|event| event == "close"));
        assert!(hardware.handle.lock().unwrap().is_some());
        shutdown.shutdown(|| Ok(())).unwrap();
        let events = serial.events.lock().unwrap();
        assert_eq!(
            events
                .iter()
                .filter(|e| *e == "SetOutput { pin: 4, high: false }")
                .count(),
            2
        );
        assert!(events
            .iter()
            .any(|e| e == "WriteSegments { address: 112, data: [0, 0, 0, 0, 0, 0, 0, 0] }"));
        assert_eq!(events.last().unwrap(), "close");
        assert!(hardware.handle.lock().unwrap().is_none());
    }
    #[test]
    fn hardware_failed_close_retains_original_handle_for_retry() {
        let (_directory, hardware, serial) = shutdown_hardware_fixture(true);
        assert!(hardware.close_ports_and_network().is_err());
        assert!(
            hardware.handle.lock().unwrap().is_some(),
            "failed handle must remain owned"
        );
        assert!(hardware.close_ports_and_network().is_err());
        assert!(
            hardware.handle.lock().unwrap().is_some(),
            "second failed close must remain owned"
        );
        hardware.close_ports_and_network().unwrap();
        assert!(hardware.handle.lock().unwrap().is_none());
        assert_eq!(
            *serial.events.lock().unwrap(),
            vec!["close", "close", "close"]
        );
    }

    struct FlakyShutdownParticipant(AtomicBool);
    impl ShutdownParticipant for FlakyShutdownParticipant {
        fn stop_admission(&self) -> Result<(), String> {
            Ok(())
        }
        fn cancel_and_join_producers(&self) -> Result<(), String> {
            Ok(())
        }
        fn neutralize_and_release_outputs(&self) -> Result<(), String> {
            if !self.0.swap(true, Ordering::AcqRel) {
                Err("adapter could not neutralize output".into())
            } else {
                Ok(())
            }
        }
        fn close_ports_and_network(&self) -> Result<(), String> {
            Ok(())
        }
    }

    #[test]
    fn failed_update_quiescence_keeps_database_open_and_retry_closes_it_last() {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("update.db");
        let state = RustAppState::empty();
        state
            .install(AppServices::open_full(&path, None).unwrap())
            .unwrap();
        state
            .register_shutdown_participant(Arc::new(FlakyShutdownParticipant(AtomicBool::new(
                false,
            ))))
            .unwrap();

        assert!(state.shutdown().is_err());
        assert!(
            state.services().is_err(),
            "shutdown keeps public admission fenced"
        );
        assert!(state
            .services
            .lock()
            .unwrap()
            .as_ref()
            .unwrap()
            .get_settings()
            .is_ok());
        state.shutdown().unwrap();
        assert!(state.services().is_err());
        AppServices::open_full(&path, None).unwrap();
    }
}

#[tauri::command]
async fn ui_run_script(state: State<'_, RustAppState>, id: String) -> Result<bool, UiFailure> {
    state.services()?;
    let id = id
        .parse::<i64>()
        .map_err(|_| UiFailure::from(unavailable("Invalid script ID.")))?;
    let runtime = state
        .controls
        .lock()
        .map_err(|_| UiFailure::from(unavailable("Controls unavailable.")))?
        .clone()
        .ok_or_else(|| UiFailure::from(unavailable("Script runner is not running.")))?;
    runtime
        .scripts
        .run_script(id)
        .await
        .map_err(|e| UiFailure::from(unavailable(&format!("Script execution unavailable: {e:?}"))))
}
#[tauri::command]
async fn ui_get_script_log(
    state: State<'_, RustAppState>,
    id: String,
) -> Result<Vec<String>, UiFailure> {
    state.services()?;
    let id = id
        .parse::<i64>()
        .map_err(|_| UiFailure::from(unavailable("Invalid script ID.")))?;
    let runtime = state
        .controls
        .lock()
        .map_err(|_| UiFailure::from(unavailable("Controls unavailable.")))?
        .clone()
        .ok_or_else(|| UiFailure::from(unavailable("Script runner is not running.")))?;
    runtime
        .scripts
        .get_script_log(id)
        .await
        .ok_or_else(|| UiFailure::from(unavailable("The script is not active.")))
}

struct LiveDetection {
    hardware: std::sync::Weak<HardwareRuntime>,
    db: Arc<trenino_runtime::storage::Database>,
    app: AppHandle,
}
impl trenino_runtime::mcp::ports::DetectionPort for LiveDetection {
    fn detect_input(
        &self,
        request: &trenino_runtime::mcp::ports::DetectionRequest,
    ) -> trenino_runtime::mcp::ports::DetectionOutcome {
        use trenino_runtime::{
            hardware::sessions::{
                DetectionOutcome as HardwareOutcome, InputDetectionSession, InputKind,
            },
            mcp::ports::{DetectedInput, DetectionKind, DetectionOutcome, InputType},
        };
        let Some(hardware) = self.hardware.upgrade() else {
            return DetectionOutcome::Timeout;
        };
        let timeout = Duration::from_millis(request.timeout_ms.clamp(1, 120_000) as u64);
        let id = trenino_core::SessionId(history_operation_id().0);
        let filter = match request.kind {
            DetectionKind::Button => InputKind::Button,
            DetectionKind::Analog => InputKind::Analog,
            DetectionKind::Any => InputKind::Any,
        };
        let session = hardware.with_handle(|h| {
            h.start_detection(id, InputDetectionSession::new(filter, timeout))
                .map_err(|e| UiFailure::from(unavailable(&format!("{e:?}"))))
        });
        let Ok(session) = session else {
            return DetectionOutcome::Timeout;
        };
        let _ = self.app.emit(
            "ui://hardware/detection",
            serde_json::json!({"session_id":id.0.to_string(),"prompt":request.prompt}),
        );
        let result = loop {
            if let Some(outcome) = session
                .lock()
                .expect("detection session")
                .expire_if_due(Instant::now())
            {
                break outcome;
            }
            std::thread::sleep(Duration::from_millis(10));
        };
        let _ = hardware.with_handle(|h| Ok(h.sessions().cancel_detection(id)));
        let _ = self.app.emit(
            "ui://hardware/detection",
            serde_json::json!({"session_id":id.0.to_string(),"prompt":null}),
        );
        if let HardwareOutcome::Detected {
            identity,
            pin,
            value,
        } = result
        {
            if let (Ok(Some(input)), Ok(Some(device))) = (
                self.db.get_input(identity.input_id),
                self.db.get_device(identity.device_id),
            ) {
                return DetectionOutcome::Detected(DetectedInput {
                    input_id: identity.input_id.0,
                    pin: pin as i64,
                    input_type: if input.kind == Some(trenino_runtime::storage::InputKind::Button) {
                        InputType::Button
                    } else {
                        InputType::Analog
                    },
                    name: input.name.unwrap_or_default(),
                    device_id: identity.device_id.0,
                    device_name: device.name.unwrap_or_default(),
                    value: value as i64,
                });
            }
        }
        DetectionOutcome::Timeout
    }
}

#[derive(Clone, Serialize)]
struct ConnectedDeviceView {
    port: String,
    generation: u64,
    config_id: Option<u32>,
    device_id: Option<String>,
    status: &'static str,
}
#[tauri::command]
async fn ui_get_connected_devices(
    state: State<'_, RustAppState>,
) -> Result<Vec<ConnectedDeviceView>, UiFailure> {
    state.services()?;
    state.hardware_runtime()?.with_handle(|h| {
        Ok(h.connected_ports()
            .into_iter()
            .map(|p| ConnectedDeviceView {
                port: p.port,
                generation: p.generation,
                config_id: p.config_id.map(|v| v.get()),
                device_id: p.device_id.map(|v| v.0.to_string()),
                status: "connected",
            })
            .collect())
    })
}
#[derive(Serialize)]
struct SimulatorRuntimeView {
    status: String,
    last_error: Option<String>,
    active_train_id: Option<String>,
    detected_identifier: Option<String>,
}
#[tauri::command]
async fn ui_get_simulator_status(
    state: State<'_, RustAppState>,
) -> Result<SimulatorRuntimeView, UiFailure> {
    state.services()?;
    let runtime = state
        .controls
        .lock()
        .map_err(|_| UiFailure::from(unavailable("Controls unavailable.")))?
        .clone()
        .ok_or_else(|| UiFailure::from(unavailable("Simulator runtime is unavailable.")))?;
    let status = runtime.simulator.status.borrow().clone();
    let train = runtime.train.snapshot();
    Ok(SimulatorRuntimeView {
        status: match status.status {
            trenino_runtime::simulator::connection::SimulatorStatus::NeedsConfig => {
                "needs_config".into()
            }
            other => format!("{other:?}").to_lowercase(),
        },
        last_error: status.last_error.map(|e| format!("{e:?}")),
        active_train_id: train.active_train_id.map(|v| v.0.to_string()),
        detected_identifier: train.detected_identifier,
    })
}
#[tauri::command]
async fn ui_retry_simulator(state: State<'_, RustAppState>) -> Result<bool, UiFailure> {
    state.services()?;
    let runtime = state
        .controls
        .lock()
        .map_err(|_| UiFailure::from(unavailable("Controls unavailable.")))?
        .clone()
        .ok_or_else(|| UiFailure::from(unavailable("Simulator runtime is unavailable.")))?;
    runtime
        .connection
        .retry_connection()
        .await
        .map_err(|e| UiFailure::from(unavailable(&format!("Connection retry failed: {e:?}"))))?;
    Ok(true)
}

#[cfg(test)]
mod packaged_tooling_tests {
    use super::*;
    #[test]
    fn installed_upload_tooling_uses_sidecar_directory_and_bundled_configuration() {
        let directory = tempfile::tempdir().unwrap();
        let executable = directory.path().join("MacOS");
        let resources = directory.path().join("Resources");
        std::fs::create_dir_all(&executable).unwrap();
        std::fs::create_dir_all(resources.join("binaries")).unwrap();
        let binary = executable.join(if cfg!(windows) {
            "avrdude.exe"
        } else {
            "avrdude"
        });
        std::fs::write(&binary, "fixture").unwrap();
        let configuration = resources.join("binaries/avrdude.conf");
        std::fs::write(&configuration, "fixture").unwrap();
        let resolved = avrdude_tooling_at(None, Some(executable.clone()), Some(resources.clone()));
        assert_eq!(resolved.avrdude_path, binary);
        assert_eq!(resolved.avrdude_conf, Some(configuration));
        let rejected = avrdude_tooling_at(
            Some(PathBuf::from("relative-tool")),
            Some(executable),
            Some(resources),
        );
        assert_eq!(rejected.avrdude_path, PathBuf::from("relative-tool"));
    }
}

fn installed_keystroke_probe(
    executable_directory: Option<PathBuf>,
) -> trenino_runtime::executable::ExecutableProbe {
    let mut probe = trenino_runtime::executable::ExecutableProbe::keystroke();
    probe.app_resource_dir = executable_directory;
    probe
}

#[cfg(test)]
mod packaged_keyboard_tests {
    use super::*;
    #[test]
    fn installed_keyboard_uses_the_executable_sibling_instead_of_resource_storage() {
        let directory = tempfile::tempdir().unwrap();
        let executable = directory.path().join("MacOS");
        let resources = directory.path().join("Resources");
        std::fs::create_dir_all(&executable).unwrap();
        std::fs::create_dir_all(&resources).unwrap();
        let binary = executable.join(if cfg!(windows) {
            "keystroke.exe"
        } else {
            "keystroke"
        });
        std::fs::write(&binary, "fixture").unwrap();
        let probe = installed_keystroke_probe(Some(executable));
        assert_eq!(probe.resolve().unwrap(), binary);
        assert!(!resources.join("keystroke").exists());
    }
}

#[cfg(test)]
mod mutation_wire_tests {
    use super::*;
    #[test]
    fn configuration_create_returns_detail_but_publishes_the_canonical_list() {
        let directory = tempfile::tempdir().unwrap();
        let services =
            Arc::new(AppServices::open_full(directory.path().join("wire.sqlite"), None).unwrap());
        let created = mutation_publication(services.clone(), Topic::Hardware, |services| {
            services.create_configuration_detail("Wire panel", None)
        })
        .unwrap();
        assert_eq!(created.result.value.name.as_deref(), Some("Wire panel"));
        assert!(created
            .result
            .value
            .config_id
            .is_some_and(|id| id.get() > 0));
        let canonical = created.canonical.unwrap();
        let list: Vec<trenino_core::ui::ConfigurationSummaryView> =
            serde_json::from_value(canonical.value).unwrap();
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].device_id, created.result.value.id);
        let input = mutation_publication(services, Topic::Hardware, |services| {
            services.create_input(trenino_runtime::app::CreateInputParams {
                device_id: created.result.value.id,
                pin: 2,
                kind: "button".into(),
                sensitivity: None,
                debounce: Some(5),
                name: None,
                matrix_id: None,
            })
        })
        .unwrap();
        assert_eq!(input.result.value.inputs.len(), 1);
        assert!(
            input.canonical.unwrap().value.is_array(),
            "child commands must not publish detail objects to list subscribers"
        );
    }
}

#[cfg(test)]
mod preview_invoke_tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn actual_tauri_dispatch_accepts_the_frontends_snake_case_preview_payloads() {
        let directory = tempfile::tempdir().unwrap();
        let state = RustAppState::empty();
        state
            .install(
                AppServices::open_full(directory.path().join("preview-invoke.sqlite"), None)
                    .unwrap(),
            )
            .unwrap();
        let app = tauri::test::mock_builder()
            .manage(state)
            .invoke_handler(tauri::generate_handler![
                runtime_preview::ui_calibration_ceiling,
                runtime_preview::ui_preview_input,
                runtime_preview::ui_preview_notch_mapping,
                runtime_preview::ui_preview_display,
                runtime_preview::ui_preview_output_condition,
            ])
            .build(tauri::test::mock_context(tauri::test::noop_assets()))
            .unwrap();
        let webview = tauri::WebviewWindowBuilder::new(&app, "main", Default::default())
            .build()
            .unwrap();
        let invoke = |cmd: &str, body: serde_json::Value| {
            tauri::test::get_ipc_response(
                &webview,
                tauri::webview::InvokeRequest {
                    cmd: cmd.into(),
                    callback: tauri::ipc::CallbackFn(0),
                    error: tauri::ipc::CallbackFn(1),
                    url: if cfg!(windows) {
                        "http://tauri.localhost"
                    } else {
                        "tauri://localhost"
                    }
                    .parse()
                    .unwrap(),
                    body: tauri::ipc::InvokeBody::Json(body),
                    headers: Default::default(),
                    invoke_key: tauri::test::INVOKE_KEY.into(),
                },
            )
            .map(|body| body.deserialize::<serde_json::Value>().unwrap())
        };
        for (command, body) in [
            ("ui_calibration_ceiling", json!({"input_id":"1"})),
            ("ui_preview_input", json!({"input_id":"1","raw":42})),
            (
                "ui_preview_notch_mapping",
                json!({"input_id":"1","notches":[{"sim_input_min":null,"sim_input_max":null}],"captured":[],"auto_distribute":true}),
            ),
            (
                "ui_preview_display",
                json!({"module_id":"1","format_string":"{value}","sample_value":3.0}),
            ),
        ] {
            let error = invoke(command, body).unwrap_err();
            assert_eq!(
                error["code"], "not_found",
                "{command} must deserialize its arguments before domain lookup: {error}"
            );
        }
        let condition = invoke(
            "ui_preview_output_condition",
            json!({"operator":"gt","value_a":2.0,"value_b":null}),
        )
        .unwrap();
        assert_eq!(
            condition["valid"], true,
            "the optional snake_case threshold must reach Rust validation"
        );
    }
}

#[cfg(test)]
mod recovery_invoke_tests {
    use super::*;
    use serde_json::json;

    #[cfg(not(windows))]
    struct NoopResourceConsumers;
    #[cfg(not(windows))]
    impl trenino_runtime::resource::ResourceConsumers for NoopResourceConsumers {
        fn suspend_actuation(&self, _: &str) -> Result<(), String> {
            Ok(())
        }
        fn cancel_calibration(&self, _: &str) -> Result<(), String> {
            Ok(())
        }
        fn source_lost(&self, _: &str, _: u64) -> Result<(), String> {
            Ok(())
        }
        fn resume_after_fresh_sample(&self, _: &str) -> Result<(), String> {
            Ok(())
        }
    }

    #[cfg(not(windows))]
    fn install_unsupported_vjoy(
        state: &RustAppState,
        database: &std::sync::Arc<trenino_runtime::storage::Database>,
    ) {
        let manager = Arc::new(trenino_runtime::vjoy::VjoyManager::new(
            (**database).clone(),
            Arc::new(trenino_runtime::resource::ResourceArbiter::new(Arc::new(
                NoopResourceConsumers,
            ))),
            UnsupportedVjoyAdapter,
        ));
        *state.vjoy.lock().unwrap() = Some(Arc::new(VjoyRuntime {
            manager,
            stop: std::sync::mpsc::channel().0,
            host: Mutex::new(None),
        }));
    }

    type MockWindow = tauri::WebviewWindow<tauri::test::MockRuntime>;

    fn recovery_webview(state: RustAppState) -> MockWindow {
        let app = tauri::test::mock_builder()
            .manage(state)
            .invoke_handler(tauri::generate_handler![
                ui_activate_train,
                runtime_sessions::ui_suggest_lever,
                runtime_sessions::ui_suggest_button,
                ui_vjoy_status,
                ui_vjoy_remove_leftover,
                ui_vjoy_repair,
            ])
            .build(tauri::test::mock_context(tauri::test::noop_assets()))
            .unwrap();
        tauri::WebviewWindowBuilder::new(&app, "main", Default::default())
            .build()
            .unwrap()
    }

    fn send(
        webview: &MockWindow,
        cmd: &str,
        body: serde_json::Value,
    ) -> Result<serde_json::Value, serde_json::Value> {
        tauri::test::get_ipc_response(
            webview,
            tauri::webview::InvokeRequest {
                cmd: cmd.into(),
                callback: tauri::ipc::CallbackFn(0),
                error: tauri::ipc::CallbackFn(1),
                url: if cfg!(windows) {
                    "http://tauri.localhost"
                } else {
                    "tauri://localhost"
                }
                .parse()
                .unwrap(),
                body: tauri::ipc::InvokeBody::Json(body),
                headers: Default::default(),
                invoke_key: tauri::test::INVOKE_KEY.into(),
            },
        )
        .map(|body| body.deserialize::<serde_json::Value>().unwrap())
    }

    fn installed_state(directory: &std::path::Path, db_name: &str) -> RustAppState {
        let state = RustAppState::empty();
        state
            .install(AppServices::open_full(directory.join(db_name), None).unwrap())
            .unwrap();
        state
    }

    #[test]
    fn recovery_commands_accept_the_frontend_camel_case_payloads() {
        let directory = tempfile::tempdir().unwrap();
        let webview = recovery_webview(installed_state(directory.path(), "recovery-invoke.sqlite"));

        // The frontend sends a camelCase `trainId`; the command must accept it
        // and surface the missing runtime as an unavailable failure.
        let error = send(&webview, "ui_activate_train", json!({"trainId":"5"})).unwrap_err();
        assert_eq!(error["code"], "unavailable");
        // snake_case keys never reach the handler: argument parsing rejects them.
        let error = send(&webview, "ui_activate_train", json!({"train_id":"5"})).unwrap_err();
        assert!(
            error.get("code").is_none(),
            "snake_case train id must be rejected: {error}"
        );

        // Suggestions never reject the promise: without a simulator connection
        // they answer with an in-band null match plus the not-connected reason.
        let lever = send(
            &webview,
            "ui_suggest_lever",
            json!({"elementName":"Throttle"}),
        )
        .unwrap();
        assert!(lever["match"].is_null());
        assert!(
            lever["error"].as_str().unwrap().contains("not connected"),
            "{lever}"
        );
        let button = send(&webview, "ui_suggest_button", json!({"elementName":"Horn"})).unwrap();
        assert!(button["match"].is_null());
        assert!(
            button["error"].as_str().unwrap().contains("not connected"),
            "{button}"
        );
        let error = send(
            &webview,
            "ui_suggest_lever",
            json!({"element_name":"Throttle"}),
        )
        .unwrap_err();
        assert!(
            error.get("code").is_none(),
            "snake_case element name must be rejected: {error}"
        );

        // Without an installed manager the status command reports unavailability.
        let error = send(&webview, "ui_vjoy_status", json!({})).unwrap_err();
        assert_eq!(error["code"], "unavailable");
    }

    #[cfg(not(windows))]
    #[test]
    fn unsupported_vjoy_manager_reports_off_and_in_band_recovery_failures() {
        let directory = tempfile::tempdir().unwrap();
        let state = RustAppState::empty();
        let services =
            AppServices::open_full(directory.path().join("vjoy-recovery.sqlite"), None).unwrap();
        let database = services.database();
        state.install(services).unwrap();
        install_unsupported_vjoy(&state, &database);
        let webview = recovery_webview(state);

        // The unsupported-platform manager maps to `off` without a reason.
        let status = send(&webview, "ui_vjoy_status", json!({})).unwrap();
        assert_eq!(status["state"], "off");
        assert!(status["reason"].is_null());
        // Recovery commands are in-band failures carrying the manager's reason.
        let leftover = send(&webview, "ui_vjoy_remove_leftover", json!({})).unwrap();
        assert_eq!(leftover["ok"], false);
        assert!(
            leftover["error"]
                .as_str()
                .unwrap()
                .contains("needs_cleanup"),
            "{leftover}"
        );
        let repair = send(&webview, "ui_vjoy_repair", json!({})).unwrap();
        assert_eq!(repair["ok"], false);
        assert!(
            repair["error"]
                .as_str()
                .unwrap()
                .contains("repair requires error"),
            "{repair}"
        );
    }
}

#[cfg(test)]
mod resume_fence_tests {
    use super::*;
    #[test]
    fn output_admission_stays_fenced_until_all_consumers_acknowledge_resume() {
        let suspended = Mutex::new(std::collections::HashSet::from(["PORT".to_owned()]));
        assert!(resume_suspended_port(&suspended, "PORT", || {
            assert!(suspended.lock().unwrap().contains("PORT"));
            Err("fresh sample is unavailable".into())
        })
        .is_err());
        assert!(suspended.lock().unwrap().contains("PORT"));
        resume_suspended_port(&suspended, "PORT", || {
            assert!(suspended.lock().unwrap().contains("PORT"));
            Ok(())
        })
        .unwrap();
        assert!(!suspended.lock().unwrap().contains("PORT"));
    }
}

#[cfg(test)]
mod telemetry_consent_tests {
    use super::*;

    #[test]
    fn consent_command_updates_reporting_only_after_a_successful_save() {
        let directory = tempfile::tempdir().unwrap();
        let state = RustAppState::empty();
        state
            .install(AppServices::open_full(directory.path().join("consent.sqlite"), None).unwrap())
            .unwrap();
        let app = tauri::test::mock_builder()
            .manage(state)
            .invoke_handler(tauri::generate_handler![ui_set_consent])
            .build(tauri::test::mock_context(tauri::test::noop_assets()))
            .unwrap();
        let webview = tauri::WebviewWindowBuilder::new(&app, "main", Default::default())
            .build()
            .unwrap();
        let invoke = |value: &str| {
            tauri::test::get_ipc_response(
                &webview,
                tauri::webview::InvokeRequest {
                    cmd: "ui_set_consent".into(),
                    callback: tauri::ipc::CallbackFn(0),
                    error: tauri::ipc::CallbackFn(1),
                    url: if cfg!(windows) {
                        "http://tauri.localhost"
                    } else {
                        "tauri://localhost"
                    }
                    .parse()
                    .unwrap(),
                    body: tauri::ipc::InvokeBody::Json(serde_json::json!({"value": value})),
                    headers: Default::default(),
                    invoke_key: tauri::test::INVOKE_KEY.into(),
                },
            )
        };
        let state = app.state::<RustAppState>();
        assert!(!state.telemetry_gate.allow());
        assert!(invoke("enabled").is_ok());
        assert!(state.telemetry_gate.allow());
        assert!(invoke("invalid").is_err());
        assert!(state.telemetry_gate.allow());
        assert!(invoke("disabled").is_ok());
        assert!(!state.telemetry_gate.allow());
        assert!(matches!(
            state
                .services()
                .unwrap()
                .get_settings()
                .unwrap()
                .value
                .error_reporting,
            trenino_core::ui::ConsentState::Disabled
        ));
        // A failed persistence operation must never reopen the reporting gate.
        state.services.lock().unwrap().take();
        assert!(invoke("enabled").is_err());
        assert!(!state.telemetry_gate.allow());
    }
}
