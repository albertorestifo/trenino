//! Simulator endpoint inspection through the application's accepted connection.
//! The LiveSimulator port owns the bounded IO bridge and rejects disconnected reads.
use super::RustAppState;
use serde::Serialize;
use serde_json::Value;
use tauri::State;
use trenino_core::ui::UiFailure;
use trenino_runtime::mcp::ports::SimulatorPort;

fn unavailable(message: impl Into<String>) -> UiFailure {
    UiFailure {
        code: "unavailable".into(),
        message: message.into(),
        field_errors: Default::default(),
        retryable: true,
    }
}

fn invalid_path() -> UiFailure {
    UiFailure {
        code: "validation".into(),
        message: "Select a valid simulator endpoint path.".into(),
        field_errors: Default::default(),
        retryable: false,
    }
}

fn simulator(
    state: State<'_, RustAppState>,
) -> Result<std::sync::Arc<trenino_runtime::composition::io::LiveSimulator>, UiFailure> {
    state.services()?;
    state
        .controls
        .lock()
        .map_err(|_| unavailable("Simulator runtime is unavailable."))?
        .as_ref()
        .map(|runtime| runtime.simulator.clone())
        .ok_or_else(|| unavailable("Simulator runtime is unavailable."))
}

fn check_path(path: &str) -> Result<(), UiFailure> {
    if path.is_empty() || path.len() > 1024 || path.chars().any(char::is_control) {
        Err(invalid_path())
    } else {
        Ok(())
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize)]
pub(super) struct SimulatorEndpointView {
    name: String,
    path: String,
    kind: &'static str,
    writable: bool,
}

fn parse_listing(response: &Value, parent: Option<&str>) -> Vec<SimulatorEndpointView> {
    let mut entries = Vec::new();
    if let Some(nodes) = response.get("Nodes").and_then(Value::as_array) {
        for node in nodes {
            let name = node
                .as_str()
                .or_else(|| node.get("NodeName").and_then(Value::as_str))
                .or_else(|| node.get("Name").and_then(Value::as_str));
            if let Some(name) = name.filter(|name| !name.is_empty()) {
                entries.push(SimulatorEndpointView {
                    name: name.into(),
                    path: parent
                        .map_or_else(|| name.to_owned(), |prefix| format!("{prefix}/{name}")),
                    kind: "node",
                    writable: false,
                });
            }
        }
    }
    if let Some(endpoints) = response.get("Endpoints").and_then(Value::as_array) {
        for endpoint in endpoints {
            let name = endpoint
                .as_str()
                .or_else(|| endpoint.get("Name").and_then(Value::as_str));
            if let Some(name) = name.filter(|name| !name.is_empty()) {
                entries.push(SimulatorEndpointView {
                    name: name.into(),
                    path: parent
                        .map_or_else(|| name.to_owned(), |prefix| format!("{prefix}.{name}")),
                    kind: "endpoint",
                    writable: endpoint
                        .get("Writable")
                        .and_then(Value::as_bool)
                        .unwrap_or(false),
                });
            }
        }
    }
    entries.sort_by(|a, b| a.name.cmp(&b.name));
    entries
}

#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_list_simulator_endpoints(
    state: State<'_, RustAppState>,
    path: Option<String>,
) -> Result<Vec<SimulatorEndpointView>, UiFailure> {
    if let Some(path) = path.as_deref() {
        check_path(path)?;
    }
    let simulator = simulator(state)?;
    tauri::async_runtime::spawn_blocking(move || {
        let response = simulator
            .list_endpoints(path.as_deref())
            .map_err(unavailable)?;
        Ok(parse_listing(&response, path.as_deref()))
    })
    .await
    .map_err(|_| unavailable("Simulator endpoint request failed."))?
}

#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_get_simulator_value(
    state: State<'_, RustAppState>,
    path: String,
) -> Result<Value, UiFailure> {
    check_path(&path)?;
    let simulator = simulator(state)?;
    tauri::async_runtime::spawn_blocking(move || simulator.get_value(&path).map_err(unavailable))
        .await
        .map_err(|_| unavailable("Simulator value request failed."))?
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn listing_matches_legacy_slash_nodes_and_dot_endpoints() {
        let response = serde_json::json!({
            "Nodes": [{"NodeName":"Throttle(Lever)"}, "Cab"],
            "Endpoints": [{"Name":"InputValue","Writable":true}, {"Name":"Speed","Writable":false}]
        });
        let result = parse_listing(&response, Some("CurrentDrivableActor"));
        assert_eq!(result.len(), 4);
        assert!(result
            .iter()
            .any(|entry| entry.path == "CurrentDrivableActor/Throttle(Lever)"
                && entry.kind == "node"));
        assert!(result
            .iter()
            .any(|entry| entry.path == "CurrentDrivableActor.InputValue"
                && entry.kind == "endpoint"
                && entry.writable));
    }
}
