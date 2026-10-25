//! Hardware output control from simulator subscriptions: a port of
//! `Trenino.Train.OutputController` (lib/trenino/train/output_controller.ex).
//!
//! When a train becomes active the controller loads its enabled output
//! bindings, creates one subscription per unique endpoint from the ID range
//! 1000-1999, and polls every 200ms. Readings are rounded to two decimals,
//! evaluated against each binding's predicate, and hardware outputs are
//! written only when the evaluated state changes (dedup by `current_state`).
//! Invalid subscriptions (`NodeValid: false`, empty `Values`, fetch errors)
//! leave state untouched. Cleanup — train switch, reload, shutdown — drives
//! every tracked output LOW and unsubscribes even when the simulator is
//! already disconnected. Unlike the display controller, this controller does
//! not react to simulator reconnections: bindings loaded while the simulator
//! was disconnected stay idle until the train changes or bindings reload.

use std::collections::BTreeMap;
use std::sync::Arc;
use std::time::{Duration, Instant};

use tokio::sync::{mpsc, oneshot, Mutex};
use tokio::task::JoinHandle;

use trenino_core::train::identifier::TrainProfile;
use trenino_core::train::output::{
    evaluate_output, subscription_reading, OutputBinding as PredicateBinding, OutputOperator,
    SimValue,
};

use crate::simulator::services::clock::Clock;

/// `@poll_interval_ms`.
pub const POLL_INTERVAL: Duration = Duration::from_millis(200);
/// `@subscription_id_base`; 1000-1999 (2000-2999 are reserved for scripts).
pub const SUBSCRIPTION_ID_BASE: i64 = 1000;

const COMMAND_QUEUE: usize = 256;

/// `Hardware.set_output/3` level (`SetOutput` value).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum OutputLevel {
    Low,
    High,
}

/// Hardware dispatch seam: `ConfigurationManager.config_id_to_port/1` over the
/// currently connected devices plus the serial `SetOutput` message. The
/// AppServices/hardware integration wires this against the live serial
/// connection (resource-lease gated there, not here).
pub trait HardwareDispatch: Send + Sync + 'static {
    fn resolve_port(&self, device_config_id: i64) -> Option<String>;
    fn set_output(&self, port: &str, pin: i32, level: OutputLevel) -> Result<(), String>;
    /// `SerialConnection.send_message(port, %SetModuleBrightness{})`.
    fn set_module_brightness(
        &self,
        port: &str,
        i2c_address: i32,
        brightness: i32,
    ) -> Result<(), String>;
    /// `Hardware.write_segments/3`.
    fn write_segments(
        &self,
        port: &str,
        i2c_address: i32,
        data: Vec<u8>,
    ) -> Result<(), String>;
}

/// `SimulatorClient` subscription operations used by both controllers.
pub trait SimulatorSubscriptions: Send + Sync + 'static {
    /// `subscribe/3`; `Ok` mirrors `{:ok, _}`.
    fn subscribe(&self, endpoint: &str, subscription_id: i64) -> Result<(), String>;
    /// `get_subscription/2`; `Ok` carries the decoded response body
    /// (`%{"Entries" => [...]}` envelope).
    fn get_subscription(&self, subscription_id: i64) -> Result<serde_json::Value, String>;
    fn unsubscribe(&self, subscription_id: i64) -> Result<(), String>;
}

/// `SimulatorConnection.get_status/0`: `Some(client)` only while the
/// connection status is `:connected` with a live client.
pub trait SimulatorConnectionView: Send + Sync + 'static {
    fn connected_client(&self) -> Option<Arc<dyn SimulatorSubscriptions>>;
}

/// One enabled `train_output_bindings` row with its hardware output preloaded
/// (`Train.list_enabled_output_bindings/1` + `output: :device`).
#[derive(Clone, Debug, PartialEq)]
pub struct OutputBindingConfig {
    pub id: i64,
    pub endpoint: String,
    pub operator: OutputOperator,
    pub value_a: Option<f64>,
    pub value_b: Option<f64>,
    pub device_config_id: i64,
    pub pin: i32,
}

/// Storage seam for the enabled output bindings of a train.
pub trait OutputBindingSource: Send + Sync + 'static {
    fn enabled_output_bindings(&self, train_id: i64) -> Vec<OutputBindingConfig>;
}

/// Controller mailbox (`handle_cast`/`handle_info` entries).
pub enum OutputControllerCommand {
    /// `{:train_changed, train | nil}`.
    TrainChanged(Option<TrainProfile>),
    /// `:reload_bindings`.
    ReloadBindings,
    Shutdown(oneshot::Sender<()>),
}

struct BindingInfo {
    binding: OutputBindingConfig,
    subscription_id: i64,
    current_state: bool,
}

struct State {
    active_train: Option<TrainProfile>,
    bindings: BTreeMap<i64, BindingInfo>,
    subscriptions: BTreeMap<String, i64>,
    poll_deadline: Option<Instant>,
}

/// Handle to the output controller task.
#[derive(Clone)]
pub struct OutputController {
    sender: mpsc::Sender<OutputControllerCommand>,
    worker: Arc<Mutex<Option<JoinHandle<()>>>>,
}

impl OutputController {
    pub fn start(
        source: Arc<dyn OutputBindingSource>,
        connection: Arc<dyn SimulatorConnectionView>,
        sink: Arc<dyn HardwareDispatch>,
        clock: Arc<dyn Clock>,
    ) -> Self {
        let (sender, receiver) = mpsc::channel(COMMAND_QUEUE);
        let worker = tokio::spawn(run(
            receiver,
            source,
            connection,
            sink,
            clock,
            State {
                active_train: None,
                bindings: BTreeMap::new(),
                subscriptions: BTreeMap::new(),
                poll_deadline: None,
            },
        ));
        Self {
            sender,
            worker: Arc::new(Mutex::new(Some(worker))),
        }
    }

    pub async fn train_changed(&self, train: Option<TrainProfile>) {
        let _ = self.sender.send(OutputControllerCommand::TrainChanged(train)).await;
    }

    pub async fn reload_bindings(&self) {
        let _ = self.sender.send(OutputControllerCommand::ReloadBindings).await;
    }

    /// Cleanup (outputs LOW, subscriptions released) then stop the task.
    pub async fn shutdown(&self) {
        let (reply, done) = oneshot::channel();
        if self.sender.send(OutputControllerCommand::Shutdown(reply)).await.is_ok() {
            let _ = done.await;
        }
        let mut worker = self.worker.lock().await;
        if let Some(handle) = worker.as_mut() {
            let _ = handle.await;
            worker.take();
        }
    }
}

async fn run(
    mut receiver: mpsc::Receiver<OutputControllerCommand>,
    source: Arc<dyn OutputBindingSource>,
    connection: Arc<dyn SimulatorConnectionView>,
    sink: Arc<dyn HardwareDispatch>,
    clock: Arc<dyn Clock>,
    mut state: State,
) {
    loop {
        let command = if let Some(deadline) = state.poll_deadline {
            let remaining = deadline.saturating_duration_since(clock.now());
            let sleep = clock.sleep(remaining);
            tokio::select! {
                command = receiver.recv() => command,
                () = sleep => {
                    poll_and_update_outputs(&mut state, &*connection, &*sink);
                    if !state.bindings.is_empty() {
                        state.poll_deadline = Some(clock.now() + POLL_INTERVAL);
                    } else {
                        state.poll_deadline = None;
                    }
                    continue;
                }
            }
        } else {
            receiver.recv().await
        };
        let Some(command) = command else { break };
        match command {
            OutputControllerCommand::TrainChanged(None) => {
                // "Train deactivated, cleaning up"
                cleanup(&mut state, &*connection, &*sink);
                state.active_train = None;
                state.bindings.clear();
                state.subscriptions.clear();
            }
            OutputControllerCommand::TrainChanged(Some(train)) => {
                cleanup(&mut state, &*connection, &*sink);
                load_bindings_for_train(&mut state, &*source, &*connection, &*clock, train);
            }
            OutputControllerCommand::ReloadBindings => match state.active_train.clone() {
                None => {}
                Some(train) => {
                    cleanup(&mut state, &*connection, &*sink);
                    load_bindings_for_train(&mut state, &*source, &*connection, &*clock, train);
                }
            },
            OutputControllerCommand::Shutdown(reply) => {
                cleanup(&mut state, &*connection, &*sink);
                let _ = reply.send(());
                break;
            }
        }
    }
}

fn load_bindings_for_train(
    state: &mut State,
    source: &dyn OutputBindingSource,
    connection: &dyn SimulatorConnectionView,
    clock: &dyn Clock,
    train: TrainProfile,
) {
    let bindings = source.enabled_output_bindings(train.id);
    state.active_train = Some(train);
    if bindings.is_empty() {
        state.bindings.clear();
        state.subscriptions.clear();
        return;
    }
    let Some(client) = connection.connected_client() else {
        // "Simulator not connected, cannot set up subscriptions"
        state.bindings.clear();
        state.subscriptions.clear();
        return;
    };
    let (binding_map, subscription_map) = setup_subscriptions(&*client, bindings);
    state.bindings = binding_map;
    state.subscriptions = subscription_map;
    if !state.bindings.is_empty() {
        state.poll_deadline = Some(clock.now() + POLL_INTERVAL);
    }
}

/// `setup_subscriptions/2`: one subscription per unique endpoint, IDs
/// 1000+index. Elixir's `Enum.group_by/2` iterates a small (<= 32 entry) map
/// in key term order, so IDs follow lexicographic endpoint order; beyond 32
/// endpoints Elixir's order is hash-based while this stays lexicographic.
/// A failed subscribe consumes its ID but tracks no bindings.
fn setup_subscriptions(
    client: &dyn SimulatorSubscriptions,
    bindings: Vec<OutputBindingConfig>,
) -> (BTreeMap<i64, BindingInfo>, BTreeMap<String, i64>) {
    let mut endpoints: Vec<&str> = bindings.iter().map(|b| b.endpoint.as_str()).collect();
    endpoints.sort_unstable();
    endpoints.dedup();

    let mut binding_map = BTreeMap::new();
    let mut subscription_map = BTreeMap::new();
    for (index, endpoint) in endpoints.into_iter().enumerate() {
        let subscription_id = SUBSCRIPTION_ID_BASE + index as i64;
        if client.subscribe(endpoint, subscription_id).is_err() {
            continue;
        }
        subscription_map.insert(endpoint.to_owned(), subscription_id);
        for binding in bindings.iter().filter(|b| b.endpoint == endpoint) {
            binding_map.insert(
                binding.id,
                BindingInfo {
                    binding: binding.clone(),
                    subscription_id,
                    current_state: false,
                },
            );
        }
    }
    (binding_map, subscription_map)
}

/// `cleanup_subscriptions/2`: cancel the timer, unsubscribe every live
/// subscription (skipped when the simulator is disconnected), then drive
/// every tracked output LOW regardless of connection state.
fn cleanup(state: &mut State, connection: &dyn SimulatorConnectionView, sink: &dyn HardwareDispatch) {
    state.poll_deadline = None;
    if let Some(client) = connection.connected_client() {
        for subscription_id in state.subscriptions.values() {
            let _ = client.unsubscribe(*subscription_id);
        }
    }
    for info in state.bindings.values() {
        set_output_state(&*sink, &info.binding, false);
    }
}

/// `set_output_state/2`: resolve the device port and fire the SetOutput
/// message. A missing port (device not connected) skips the write silently;
/// the Elixir controller ignores the send result, so the tracked state moves
/// even when the write fails.
fn set_output_state(sink: &dyn HardwareDispatch, binding: &OutputBindingConfig, level: bool) {
    if let Some(port) = sink.resolve_port(binding.device_config_id) {
        let level = if level { OutputLevel::High } else { OutputLevel::Low };
        let _ = sink.set_output(&port, binding.pin, level);
    }
}

/// `poll_and_update_outputs/1` + `process_subscription/4`: group bindings by
/// subscription ID, fetch each reading, and write only on state changes.
fn poll_and_update_outputs(
    state: &mut State,
    connection: &dyn SimulatorConnectionView,
    sink: &dyn HardwareDispatch,
) {
    let Some(client) = connection.connected_client() else {
        return;
    };
    let mut by_subscription: BTreeMap<i64, Vec<i64>> = BTreeMap::new();
    for (id, info) in &state.bindings {
        by_subscription.entry(info.subscription_id).or_default().push(*id);
    }
    for (subscription_id, binding_ids) in by_subscription {
        let Ok(body) = client.get_subscription(subscription_id) else {
            // "Failed to get subscription": leave state untouched.
            continue;
        };
        let Some(value) = subscription_reading(&body) else {
            continue;
        };
        update_bindings_with_value(state, sink, &binding_ids, &value);
    }
}

fn update_bindings_with_value(
    state: &mut State,
    sink: &dyn HardwareDispatch,
    binding_ids: &[i64],
    value: &SimValue,
) {
    for id in binding_ids {
        let Some(info) = state.bindings.get(id) else { continue };
        let predicate = PredicateBinding {
            operator: info.binding.operator,
            value_a: info.binding.value_a,
            value_b: info.binding.value_b,
        };
        let new_state = evaluate_output(&predicate, value);
        if new_state != info.current_state {
            set_output_state(sink, &info.binding, new_state);
            let info = state.bindings.get_mut(id).expect("checked above");
            info.current_state = new_state;
        }
    }
}
