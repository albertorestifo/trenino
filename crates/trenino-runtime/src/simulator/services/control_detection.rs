//! Control detection session.
//!
//! Port of `Trenino.Simulator.ControlDetectionSession`
//! (lib/trenino/simulator/control_detection_session.ex): discovers writable
//! `InputValue` endpoints under `CurrentDrivableActor`, subscribes them all to
//! subscription id 99, snapshots a baseline and polls every 150ms for the first
//! change above 0.01, reporting every changed endpoint together (several
//! simultaneous changes are reported as one ambiguous candidate set). The
//! session auto-terminates on detection, after the 30s timeout, on error, on
//! cancellation and when the listener disappears — always unsubscribing and
//! releasing its resource-arbiter lease.

use crate::resource::{LeaseKind, ResourceArbiter, ResourceError};
use crate::simulator::client::{SimulatorClient, SimulatorError};
use serde_json::Value;
use std::collections::HashMap;
use std::sync::Arc;
use std::time::Duration;

use super::clock::Clock;
use super::explorer::ROOT_PATH;
use super::session::{spawn_leased_session, SessionHandle};

pub const POLL_INTERVAL: Duration = Duration::from_millis(150);
pub const DETECTION_THRESHOLD: f64 = 0.01;
pub const TIMEOUT: Duration = Duration::from_secs(30);
pub const SUBSCRIPTION_ID: i64 = 99;

#[derive(Clone, Debug, PartialEq)]
pub struct DetectedChange {
    pub endpoint: String,
    pub control_name: String,
    pub previous_value: f64,
    pub current_value: f64,
}

#[derive(Clone, Debug, PartialEq)]
pub enum DetectionOutcome {
    /// Every endpoint that changed since the baseline, in subscription order.
    /// `ambiguous` is true when more than one control moved at once.
    Detected {
        changes: Vec<DetectedChange>,
        ambiguous: bool,
    },
    TimedOut,
}

#[derive(Clone, Debug, PartialEq)]
pub enum DetectionFailure {
    /// Root listing failed (mirrors `{:list_failed, reason}`).
    ListFailed(SimulatorError),
    /// No endpoint could be subscribed (mirrors `:no_subscriptions_created`).
    NoSubscriptionsCreated,
    /// Baseline snapshot failed (mirrors `{:snapshot_failed, reason}`).
    SnapshotFailed(SimulatorError),
}

#[derive(Clone, Debug, PartialEq)]
pub enum DetectionEvent {
    Completed(DetectionOutcome),
    Failed(DetectionFailure),
}

/// Start a detection session holding `lease` for its whole lifetime. The lease
/// is acquired synchronously, so a busy resource fails the start immediately.
pub fn start_control_detection(
    client: Arc<SimulatorClient>,
    arbiter: &Arc<ResourceArbiter>,
    lease: LeaseKind,
    clock: Arc<dyn Clock>,
) -> Result<SessionHandle<DetectionEvent>, ResourceError> {
    let cleanup_client = client.clone();
    spawn_leased_session(
        arbiter,
        lease,
        |_| run_detection(client, clock),
        move || {
            // terminate/2 always unsubscribes the shared subscription id.
            let client = cleanup_client.clone();
            async move {
                let _ = client.unsubscribe(SUBSCRIPTION_ID).await;
            }
        },
    )
}

async fn run_detection(
    client: Arc<SimulatorClient>,
    clock: Arc<dyn Clock>,
) -> Option<DetectionEvent> {
    match detect(client, clock).await {
        Ok(outcome) => Some(DetectionEvent::Completed(outcome)),
        Err(failure) => Some(DetectionEvent::Failed(failure)),
    }
}

async fn detect(
    client: Arc<SimulatorClient>,
    clock: Arc<dyn Clock>,
) -> Result<DetectionOutcome, DetectionFailure> {
    let endpoints = discover_input_endpoints(&client)
        .await
        .map_err(DetectionFailure::ListFailed)?;
    create_subscriptions(&client, &endpoints).await?;
    let baseline = take_baseline_snapshot(&client)
        .await
        .map_err(DetectionFailure::SnapshotFailed)?;
    let deadline = clock.now() + TIMEOUT;
    loop {
        clock.sleep(POLL_INTERVAL).await;
        // The timeout message wins over the poll scheduled for the same
        // instant, mirroring the earlier-scheduled timer firing first.
        if clock.now() >= deadline {
            return Ok(DetectionOutcome::TimedOut);
        }
        let Ok(response) = client.get_subscription(SUBSCRIPTION_ID).await else {
            // Poll errors are logged and polling continues.
            continue;
        };
        let Some(entries) = response.get("Entries").and_then(Value::as_array) else {
            continue;
        };
        let changes = detect_changes(entries, &baseline);
        if changes.is_empty() {
            continue;
        }
        let ambiguous = changes.len() > 1;
        return Ok(DetectionOutcome::Detected { changes, ambiguous });
    }
}

async fn discover_input_endpoints(client: &SimulatorClient) -> Result<Vec<String>, SimulatorError> {
    // Iterative pre-order DFS equivalent to the Elixir recursion: a node's own
    // writable InputValue endpoint precedes its children's, and a failed
    // child listing contributes nothing.
    let response = client.list(Some(ROOT_PATH)).await?;
    let mut pending: Vec<String> = child_paths(&response, ROOT_PATH);
    pending.reverse();
    let mut endpoints = Vec::new();
    while let Some(node_path) = pending.pop() {
        let Ok(child) = client.list(Some(&node_path)).await else {
            continue;
        };
        if has_writable_input_value(&child) {
            endpoints.push(format!("{node_path}.InputValue"));
        }
        let mut children = child_paths(&child, &node_path);
        children.reverse();
        pending.extend(children);
    }
    Ok(endpoints)
}

fn child_paths(response: &Value, parent_path: &str) -> Vec<String> {
    response
        .get("Nodes")
        .and_then(Value::as_array)
        .map(|nodes| {
            nodes
                .iter()
                .map(|node| format!("{parent_path}/{}", node_name(node)))
                .collect()
        })
        .unwrap_or_default()
}

fn has_writable_input_value(response: &Value) -> bool {
    response
        .get("Endpoints")
        .and_then(Value::as_array)
        .map(|endpoints| {
            endpoints.iter().any(|endpoint| {
                endpoint.get("Name").and_then(Value::as_str) == Some("InputValue")
                    && matches!(endpoint.get("Writable"), Some(writable)
                        if *writable != Value::Bool(false) && !writable.is_null())
            })
        })
        .unwrap_or(false)
}

fn node_name(node: &Value) -> String {
    match node {
        Value::String(name) => name.clone(),
        Value::Object(map) => map
            .get("NodeName")
            .filter(|value| value.is_string())
            .or_else(|| map.get("Name"))
            .and_then(Value::as_str)
            .unwrap_or_default()
            .to_owned(),
        _ => String::new(),
    }
}

async fn create_subscriptions(
    client: &SimulatorClient,
    endpoints: &[String],
) -> Result<(), DetectionFailure> {
    // Clear any existing subscription with this id first.
    let _ = client.unsubscribe(SUBSCRIPTION_ID).await;
    let mut any_ok = false;
    for endpoint in endpoints {
        match client.subscribe(endpoint, SUBSCRIPTION_ID).await {
            Ok(_) => any_ok = true,
            Err(_) => continue,
        }
    }
    if any_ok {
        Ok(())
    } else {
        Err(DetectionFailure::NoSubscriptionsCreated)
    }
}

async fn take_baseline_snapshot(
    client: &SimulatorClient,
) -> Result<HashMap<String, f64>, SimulatorError> {
    let response = client.get_subscription(SUBSCRIPTION_ID).await?;
    let mut baseline = HashMap::new();
    if let Some(entries) = response.get("Entries").and_then(Value::as_array) {
        for entry in entries {
            if let Some((path, Some(value))) = entry_path_and_value(entry) {
                baseline.insert(path, value);
            }
        }
    }
    Ok(baseline)
}

fn entry_path_and_value(entry: &Value) -> Option<(String, Option<f64>)> {
    let path = entry.get("Path")?.as_str()?.to_owned();
    let values = entry.get("Values")?.as_object()?;
    Some((path, values.values().next().and_then(number)))
}

fn number(value: &Value) -> Option<f64> {
    match value {
        Value::Number(number) => number.as_f64(),
        _ => None,
    }
}

fn detect_changes(entries: &[Value], baseline: &HashMap<String, f64>) -> Vec<DetectedChange> {
    entries
        .iter()
        .filter_map(|entry| {
            let (path, current) = entry_path_and_value(entry)?;
            let current = current?;
            let previous = baseline.get(&path).copied()?;
            if (current - previous).abs() > DETECTION_THRESHOLD {
                Some(DetectedChange {
                    endpoint: path.clone(),
                    control_name: control_name(&path),
                    previous_value: previous,
                    current_value: current,
                })
            } else {
                None
            }
        })
        .collect()
}

/// "CurrentDrivableActor/Horn.InputValue" -> "Horn" and
/// "CurrentDrivableActor/Throttle(Lever).InputValue" -> "Throttle(Lever)",
/// mirroring `ControlDetectionSession.extract_control_name/1`.
pub fn control_name(path: &str) -> String {
    path.replace(&format!("{ROOT_PATH}/"), "")
        .replace(".InputValue", "")
        .split('/')
        .next_back()
        .unwrap_or_default()
        .to_owned()
}
