//! Desktop IPC for owned guided simulator sessions.
use super::RustAppState;
use serde::{Deserialize, Serialize};
use tauri::State;
use trenino_core::ui::UiFailure;
use trenino_runtime::{
    composition::sessions::{SessionError, SessionSnapshot, SimulatorSessionHost},
    simulator::{
        connection::SimulatorStatus,
        services::{
            calibration::LeverEndpointSet,
            explorer::{self, LeverControl},
            suggest::{self, ButtonSuggestionView, LeverSuggestionView, SuggestService},
        },
    },
};

fn failure(error: SessionError) -> UiFailure {
    let (code, retryable) = match &error {
        SessionError::Offline
        | SessionError::Closed
        | SessionError::Deadline
        | SessionError::CleanupFailed(_)
        | SessionError::Simulator(_) => ("unavailable", true),
        SessionError::Busy => ("conflict", true),
        SessionError::InvalidInput(_) | SessionError::NotFound => ("validation", false),
        SessionError::Cancelled => ("conflict", false),
    };
    UiFailure {
        code: code.into(),
        message: error.to_string(),
        field_errors: Default::default(),
        retryable,
    }
}
fn sessions(state: State<'_, RustAppState>) -> Result<SimulatorSessionHost, UiFailure> {
    state.services()?;
    state
        .controls
        .lock()
        .map_err(|_| failure(SessionError::Closed))?
        .as_ref()
        .map(|runtime| runtime.sessions.clone())
        .ok_or_else(|| failure(SessionError::Closed))
}
fn id(raw: &str) -> Result<u64, UiFailure> {
    raw.parse::<u64>()
        .ok()
        .filter(|id| *id > 0)
        .ok_or_else(|| failure(SessionError::InvalidInput("invalid session ID".into())))
}
fn control_path(raw: &str) -> Result<String, UiFailure> {
    let path = raw.strip_suffix(".InputValue").unwrap_or(raw);
    if path.is_empty() || path.len() > 1000 || path.chars().any(char::is_control) {
        Err(failure(SessionError::InvalidInput(
            "invalid control path".into(),
        )))
    } else {
        Ok(path.to_owned())
    }
}
#[derive(Serialize)]
pub(super) struct SessionStartView {
    session_id: String,
}
#[derive(Deserialize)]
pub(super) struct CalibrationEndpointInput {
    min_endpoint: String,
    max_endpoint: String,
    value_endpoint: String,
    notch_count_endpoint: String,
    notch_index_endpoint: String,
}
fn started(id: u64) -> SessionStartView {
    SessionStartView {
        session_id: id.to_string(),
    }
}

#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_resolve_lever_endpoints(
    state: State<'_, RustAppState>,
    control_path: String,
) -> Result<LeverControl, UiFailure> {
    let path = self::control_path(&control_path)?;
    state.services()?;
    let status = state
        .controls
        .lock()
        .map_err(|_| failure(SessionError::Closed))?
        .as_ref()
        .map(|runtime| runtime.simulator.status.clone())
        .ok_or_else(|| failure(SessionError::Closed))?;
    let client = {
        let snapshot = status.borrow();
        if snapshot.status == SimulatorStatus::Connected {
            snapshot.client.clone()
        } else {
            None
        }
    }
    .ok_or_else(|| failure(SessionError::Offline))?;
    tokio::time::timeout(
        std::time::Duration::from_secs(12),
        explorer::resolve_lever_endpoints(&client, &path),
    )
    .await
    .map_err(|_| failure(SessionError::Deadline))?
    .map_err(|e| failure(SessionError::Simulator(format!("{e:?}"))))?
    .ok_or_else(|| {
        failure(SessionError::InvalidInput(
            "selected control is not a lever".into(),
        ))
    })
}

/// Payload contract for `ui_suggest_lever` / `ui_suggest_button`
/// (`LeverSuggestionResult` / `ButtonSuggestionResult` in `client.ts`). The
/// binding wizards treat a null match as "no suggestion" and stay silent, so
/// every failure mode — including a missing simulator connection — is
/// reported in-band instead of rejecting the IPC promise.
#[derive(Serialize)]
pub(super) struct SuggestionResultView<T> {
    #[serde(rename = "match")]
    matched: Option<T>,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

impl<T> SuggestionResultView<T> {
    fn matched(view: T) -> Self {
        Self {
            matched: Some(view),
            error: None,
        }
    }
    fn empty() -> Self {
        Self {
            matched: None,
            error: None,
        }
    }
    fn failure(error: impl std::fmt::Display) -> Self {
        Self {
            matched: None,
            error: Some(error.to_string()),
        }
    }
}

/// Lever match as consumed by the frontend: nested `endpoints` object with
/// camelCase field names.
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct LeverMatchView {
    control_path: String,
    endpoints: LeverEndpointsView,
    confidence: f64,
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct LeverEndpointsView {
    value: String,
    min: String,
    max: String,
    notch_count: String,
    notch_index: String,
}

impl From<LeverSuggestionView> for LeverMatchView {
    fn from(view: LeverSuggestionView) -> Self {
        Self {
            control_path: view.control_path,
            endpoints: LeverEndpointsView {
                value: view.value_endpoint,
                min: view.min_endpoint,
                max: view.max_endpoint,
                notch_count: view.notch_count_endpoint,
                notch_index: view.notch_index_endpoint,
            },
            confidence: view.confidence,
        }
    }
}

/// Button match as consumed by the frontend (camelCase field names).
#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct ButtonMatchView {
    control_path: String,
    endpoint: String,
    confidence: f64,
}

impl From<ButtonSuggestionView> for ButtonMatchView {
    fn from(view: ButtonSuggestionView) -> Self {
        Self {
            control_path: view.control_path,
            endpoint: view.endpoint,
            confidence: view.confidence,
        }
    }
}

fn suggest_service(
    state: &State<'_, RustAppState>,
) -> Result<SuggestService, suggest::SuggestServiceError> {
    state
        .controls
        .lock()
        .ok()
        .and_then(|runtime| {
            runtime
                .as_ref()
                .map(|runtime| runtime.simulator.status.clone())
        })
        .map(SuggestService::new)
        .ok_or(suggest::SuggestServiceError::NotConnected)
}

/// Name-based lever suggestion. The frontend invokes with a camelCase
/// `elementName` key, so this command keeps the Tauri default casing instead
/// of the `rename_all = "snake_case"` used above.
#[tauri::command]
pub(super) async fn ui_suggest_lever(
    state: State<'_, RustAppState>,
    element_name: String,
) -> Result<SuggestionResultView<LeverMatchView>, UiFailure> {
    Ok(match suggest_service(&state) {
        Err(error) => SuggestionResultView::failure(error),
        Ok(service) => match service.suggest_lever(&element_name).await {
            Ok(Some(view)) => SuggestionResultView::matched(LeverMatchView::from(view)),
            Ok(None) => SuggestionResultView::empty(),
            Err(error) => SuggestionResultView::failure(error),
        },
    })
}

/// Name-based button suggestion; same camelCase `elementName` invocation.
#[tauri::command]
pub(super) async fn ui_suggest_button(
    state: State<'_, RustAppState>,
    element_name: String,
) -> Result<SuggestionResultView<ButtonMatchView>, UiFailure> {
    Ok(match suggest_service(&state) {
        Err(error) => SuggestionResultView::failure(error),
        Ok(service) => match service.suggest_button(&element_name).await {
            Ok(Some(view)) => SuggestionResultView::matched(ButtonMatchView::from(view)),
            Ok(None) => SuggestionResultView::empty(),
            Err(error) => SuggestionResultView::failure(error),
        },
    })
}

#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_start_control_detection(
    state: State<'_, RustAppState>,
) -> Result<SessionStartView, UiFailure> {
    Ok(started(
        sessions(state)?
            .start_control_detection()
            .await
            .map_err(failure)?,
    ))
}
#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_control_detection_status(
    state: State<'_, RustAppState>,
    session_id: String,
) -> Result<SessionSnapshot, UiFailure> {
    sessions(state)?
        .status(id(&session_id)?)
        .await
        .map_err(failure)
}
#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_cancel_control_detection(
    state: State<'_, RustAppState>,
    session_id: String,
) -> Result<bool, UiFailure> {
    sessions(state)?
        .cancel(id(&session_id)?)
        .await
        .map_err(failure)
}

#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_start_lever_analysis(
    state: State<'_, RustAppState>,
    control_path: String,
    restore_position: Option<f64>,
) -> Result<SessionStartView, UiFailure> {
    Ok(started(
        sessions(state)?
            .start_lever_analysis(self::control_path(&control_path)?, restore_position)
            .await
            .map_err(failure)?,
    ))
}
#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_lever_analysis_status(
    state: State<'_, RustAppState>,
    session_id: String,
) -> Result<SessionSnapshot, UiFailure> {
    sessions(state)?
        .status(id(&session_id)?)
        .await
        .map_err(failure)
}
#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_cancel_lever_analysis(
    state: State<'_, RustAppState>,
    session_id: String,
) -> Result<bool, UiFailure> {
    sessions(state)?
        .cancel(id(&session_id)?)
        .await
        .map_err(failure)
}

#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_start_lever_calibration(
    state: State<'_, RustAppState>,
    control_path: String,
    lever_config_id: Option<i64>,
    endpoints: Option<CalibrationEndpointInput>,
) -> Result<SessionStartView, UiFailure> {
    let path = self::control_path(&control_path)?;
    let endpoints = match endpoints {
        Some(e) => LeverEndpointSet {
            lever_config_id: lever_config_id.unwrap_or(0),
            min_endpoint: e.min_endpoint,
            max_endpoint: e.max_endpoint,
            value_endpoint: e.value_endpoint,
            notch_count_endpoint: e.notch_count_endpoint,
            notch_index_endpoint: e.notch_index_endpoint,
        },
        None => LeverEndpointSet {
            lever_config_id: lever_config_id.unwrap_or(0),
            min_endpoint: format!("{path}.Function.GetMinimumInputValue"),
            max_endpoint: format!("{path}.Function.GetMaximumInputValue"),
            value_endpoint: format!("{path}.InputValue"),
            notch_count_endpoint: format!("{path}.Function.GetNotchCount"),
            notch_index_endpoint: format!("{path}.Function.GetCurrentNotchIndex"),
        },
    };
    Ok(started(
        sessions(state)?
            .start_lever_calibration(endpoints)
            .await
            .map_err(failure)?,
    ))
}
#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_lever_calibration_status(
    state: State<'_, RustAppState>,
    session_id: String,
) -> Result<SessionSnapshot, UiFailure> {
    sessions(state)?
        .status(id(&session_id)?)
        .await
        .map_err(failure)
}
#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_cancel_lever_calibration(
    state: State<'_, RustAppState>,
    session_id: String,
) -> Result<bool, UiFailure> {
    sessions(state)?
        .cancel(id(&session_id)?)
        .await
        .map_err(failure)
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn normalizes_detected_input_path() {
        assert_eq!(
            control_path("CurrentDrivableActor/Throttle.InputValue").unwrap(),
            "CurrentDrivableActor/Throttle"
        );
    }
}
