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

type ObserverMap = HashMap<String, Topic>;

pub(crate) struct RustAppState {
    services: Mutex<Option<Arc<AppServices>>>,
    observers: Mutex<HashMap<String, ObserverMap>>,
    publication: tokio::sync::Mutex<()>,
    shutdown_lock: Mutex<()>,
    shutdown: ShutdownCoordinator,
    stopping: AtomicBool,
    startup_failure_pending: AtomicBool,
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
            let owned = slot.take();
            drop(slot);
            drop(owned);
            drop(services);
            Ok(())
        });
        if result.is_err() {
            self.stopping.store(false, Ordering::Release);
        }
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
async fn ui_set_consent(
    app: AppHandle,
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

fn publish_change<T: Serialize>(app: &AppHandle, topic: Topic, snapshot: &UiSnapshot<T>) {
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
            if app
                .state::<RustAppState>()
                .install(services)
                .is_err()
            {
                show_startup_failure(
                    app.handle(),
                    "The Rust trial could not initialize its application services. Restart the application and try again.",
                );
                return Ok(());
            }

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

#[cfg(test)]
mod tests {
    use super::*;

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

        let unavailable = services.snapshot_json(Topic::Firmware).unwrap_err();
        let failure = UiFailure::from(unavailable);
        assert_eq!(failure.code, "unavailable");
        assert!(failure.field_errors.is_empty());
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
        assert!(state.services().unwrap().get_settings().is_ok());
        state.shutdown().unwrap();
        assert!(state.services().is_err());
        AppServices::open_full(&path, None).unwrap();
    }
}
