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
