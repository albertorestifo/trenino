//! I2C display control from simulator subscriptions: a port of
//! `Trenino.Train.DisplayController` (lib/trenino/train/display_controller.ex).
//!
//! Mirrors the output controller (one subscription per unique endpoint from
//! the 3000+ range, 200ms polling, two-decimal rounding) but writes encoded
//! segment data instead of output levels. Display-specific semantics:
//!
//! - brightness is sent before the first segment write of a binding
//!   (`last_text == nil`) and after invalidation, never on repeat sends;
//! - only successful sends are cached (`last_text`), so a failed write or a
//!   missing device port replays the same text on the next poll;
//! - simulator reconnection (with an active train) blanks, unsubscribes and
//!   reloads bindings, recovering profiles loaded while disconnected;
//! - device hotplug (`devices_updated`) only invalidates `last_text`;
//! - configuration replay reloads persisted address/encoding/minimum without
//!   blanking the old addresses;
//! - cleanup blanks every tracked display and unsubscribes even when the
//!   simulator is already disconnected.

use std::collections::BTreeMap;
use std::sync::Arc;
use std::time::{Duration, Instant};

use tokio::sync::{mpsc, oneshot, Mutex};
use tokio::task::JoinHandle;

use trenino_core::hardware::ht16k33::encode_string;
use trenino_core::train::display::{clamp_to_min, format_display};
use trenino_core::train::identifier::TrainProfile;
use trenino_core::train::output::subscription_reading;

use crate::simulator::services::clock::Clock;
use crate::train::output_controller::HardwareDispatch;
use crate::train::output_controller::{SimulatorConnectionView, SimulatorSubscriptions};

/// `@poll_interval_ms`.
pub const POLL_INTERVAL: Duration = Duration::from_millis(200);
/// `@subscription_id_base`; displays use 3000+ (outputs 1000-1999, scripts
/// 2000-2999).
pub const SUBSCRIPTION_ID_BASE: i64 = 3000;

const COMMAND_QUEUE: usize = 256;

/// One enabled `train_display_bindings` row with its I2C module preloaded
/// (`Train.list_enabled_display_bindings/1` + `i2c_module: :device`), chip
#[derive(Clone, Debug, PartialEq)]
pub struct DisplayBindingConfig {
    pub id: i64,
    pub endpoint: String,
    pub format_string: String,
    pub device_config_id: i64,
    pub i2c_address: i32,
    pub brightness: i32,
    pub num_digits: usize,
    pub seven_segment: bool,
    pub has_dot: bool,
    pub align_right: bool,
    pub min_value: Option<f64>,
}

/// Storage seam for the enabled display bindings of a train.
pub trait DisplayBindingSource: Send + Sync + 'static {
    fn enabled_display_bindings(&self, train_id: i64) -> Vec<DisplayBindingConfig>;
}

/// Controller mailbox (`handle_cast`/`handle_info` entries).
pub enum DisplayControllerCommand {
    TrainChanged(Option<TrainProfile>),
    ReloadBindings,
    /// `{:simulator_status_changed, %ConnectionState{status: :connected}}`.
    SimulatorConnected,
    /// `{:devices_updated, devices}`.
    DevicesUpdated,
    /// `{:configuration_applied, port, device, config_id}`.
    ConfigurationApplied,
    Shutdown(oneshot::Sender<()>),
}

struct BindingInfo {
    binding: DisplayBindingConfig,
    subscription_id: i64,
    last_text: Option<String>,
}

struct State {
    active_train: Option<TrainProfile>,
    bindings: BTreeMap<i64, BindingInfo>,
    subscriptions: BTreeMap<String, i64>,
    poll_deadline: Option<Instant>,
}

/// Handle to the display controller task.
#[derive(Clone)]
pub struct DisplayController {
    sender: mpsc::Sender<DisplayControllerCommand>,
    worker: Arc<Mutex<Option<JoinHandle<()>>>>,
}

impl DisplayController {
    pub fn start(
        source: Arc<dyn DisplayBindingSource>,
        connection: Arc<dyn SimulatorConnectionView>,
        sink: Arc<dyn HardwareDispatch>,
        clock: Arc<dyn Clock>,
    ) -> Self {
        let (sender, receiver) = mpsc::channel(COMMAND_QUEUE);
        let worker = tokio::task::spawn_blocking(move || {
            let host = tokio::runtime::Builder::new_current_thread()
                .enable_all()
                .build()
                .expect("controller runtime");
            host.block_on(run(
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
        });
        Self {
            sender,
            worker: Arc::new(Mutex::new(Some(worker))),
        }
    }

    pub async fn train_changed(&self, train: Option<TrainProfile>) {
        let _ = self
            .sender
            .send(DisplayControllerCommand::TrainChanged(train))
            .await;
    }

    pub async fn reload_bindings(&self) {
        let _ = self
            .sender
            .send(DisplayControllerCommand::ReloadBindings)
            .await;
    }

    pub async fn simulator_connected(&self) {
        let _ = self
            .sender
            .send(DisplayControllerCommand::SimulatorConnected)
            .await;
    }

    pub fn invalidate_hardware(&self) -> Result<(), String> {
        self.sender
            .try_send(DisplayControllerCommand::DevicesUpdated)
            .map_err(|e| e.to_string())
    }
    pub async fn devices_updated(&self) {
        let _ = self
            .sender
            .send(DisplayControllerCommand::DevicesUpdated)
            .await;
    }

    pub async fn configuration_applied(&self) {
        let _ = self
            .sender
            .send(DisplayControllerCommand::ConfigurationApplied)
            .await;
    }

    /// Cleanup (blank displays, release subscriptions) then stop the task.
    pub async fn shutdown(&self) {
        let (reply, done) = oneshot::channel();
        if self
            .sender
            .send(DisplayControllerCommand::Shutdown(reply))
            .await
            .is_ok()
        {
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
    mut receiver: mpsc::Receiver<DisplayControllerCommand>,
    source: Arc<dyn DisplayBindingSource>,
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
                    poll_and_update(&mut state, &*connection, &*sink);
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
            DisplayControllerCommand::TrainChanged(None) => {
                cleanup(&mut state, &*connection, &*sink, true);
                state.active_train = None;
                state.bindings.clear();
                state.subscriptions.clear();
            }
            DisplayControllerCommand::TrainChanged(Some(train)) => {
                cleanup(&mut state, &*connection, &*sink, true);
                load_bindings_for_train(&mut state, &*source, &*connection, &*clock, train);
            }
            DisplayControllerCommand::ReloadBindings => match state.active_train.clone() {
                None => {}
                Some(train) => {
                    cleanup(&mut state, &*connection, &*sink, true);
                    load_bindings_for_train(&mut state, &*source, &*connection, &*clock, train);
                }
            },
            DisplayControllerCommand::SimulatorConnected => {
                if let Some(train) = state.active_train.clone() {
                    cleanup(&mut state, &*connection, &*sink, true);
                    load_bindings_for_train(&mut state, &*source, &*connection, &*clock, train);
                }
            }
            DisplayControllerCommand::DevicesUpdated => {
                invalidate_displays(&mut state);
            }
            DisplayControllerCommand::ConfigurationApplied => {
                // Configuration deployment may change or remove modules; do
                // not blank old addresses, reload persisted settings instead.
                if let Some(train) = state.active_train.clone() {
                    cleanup(&mut state, &*connection, &*sink, false);
                    load_bindings_for_train(&mut state, &*source, &*connection, &*clock, train);
                }
            }
            DisplayControllerCommand::Shutdown(reply) => {
                cleanup(&mut state, &*connection, &*sink, true);
                let _ = reply.send(());
                break;
            }
        }
    }
}

fn load_bindings_for_train(
    state: &mut State,
    source: &dyn DisplayBindingSource,
    connection: &dyn SimulatorConnectionView,
    clock: &dyn Clock,
    train: TrainProfile,
) {
    let bindings = source.enabled_display_bindings(train.id);
    state.active_train = Some(train);
    if bindings.is_empty() {
        state.bindings.clear();
        state.subscriptions.clear();
        return;
    }
    let Some(client) = connection.connected_client() else {
        // "Simulator not connected, skipping subscriptions"
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

/// `setup_subscriptions/2` with the 3000+ ID base; see the output
/// controller's notes on lexicographic endpoint ordering and consumed IDs on
/// failed subscribes.
fn setup_subscriptions(
    client: &dyn SimulatorSubscriptions,
    bindings: Vec<DisplayBindingConfig>,
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
                    last_text: None,
                },
            );
        }
    }
    (binding_map, subscription_map)
}

/// `poll_and_update/1` + `process_subscription/4`.
fn poll_and_update(
    state: &mut State,
    connection: &dyn SimulatorConnectionView,
    sink: &dyn HardwareDispatch,
) {
    let Some(client) = connection.connected_client() else {
        return;
    };
    let mut by_subscription: BTreeMap<i64, Vec<i64>> = BTreeMap::new();
    for (id, info) in &state.bindings {
        by_subscription
            .entry(info.subscription_id)
            .or_default()
            .push(*id);
    }
    for (subscription_id, binding_ids) in by_subscription {
        let Ok(body) = client.get_subscription(subscription_id) else {
            continue;
        };
        let Some(value) = subscription_reading(&body) else {
            continue;
        };
        update_displays(state, sink, &binding_ids, &value);
    }
}

/// `update_displays/3`: clamp against the module minimum, format, and send
/// unless the exact text was already delivered.
fn update_displays(
    state: &mut State,
    sink: &dyn HardwareDispatch,
    binding_ids: &[i64],
    value: &trenino_core::train::output::SimValue,
) {
    for id in binding_ids {
        let Some(info) = state.bindings.get(id) else {
            continue;
        };
        let clamped = clamp_to_min(value.clone(), info.binding.min_value);
        let text = format_display(&info.binding.format_string, &clamped);
        if info.last_text.as_deref() == Some(text.as_str()) {
            continue;
        }
        let initialize = info.last_text.is_none();
        if send_to_display(sink, &info.binding, &text, initialize).is_ok() {
            let info = state.bindings.get_mut(id).expect("checked above");
            info.last_text = Some(text);
        }
    }
}

/// `cleanup/2`: cancel the timer, blank every tracked display (unless a
/// configuration replay asked not to), then unsubscribe — skipped when the
/// simulator is already disconnected.
fn cleanup(
    state: &mut State,
    connection: &dyn SimulatorConnectionView,
    sink: &dyn HardwareDispatch,
    blank: bool,
) {
    state.poll_deadline = None;
    if blank {
        for info in state.bindings.values() {
            blank_display(sink, &info.binding);
        }
    }
    if let Some(client) = connection.connected_client() {
        for subscription_id in state.subscriptions.values() {
            let _ = client.unsubscribe(*subscription_id);
        }
    }
}

/// `send_to_display/3`: no connected port fails without any write; otherwise
/// brightness first when initializing, then the encoded segments.
fn send_to_display(
    sink: &dyn HardwareDispatch,
    binding: &DisplayBindingConfig,
    text: &str,
    initialize: bool,
) -> Result<(), String> {
    let Some(port) = sink.resolve_port(binding.device_config_id) else {
        return Err("disconnected".to_owned());
    };
    let bytes = encode(binding, text);
    if initialize {
        sink.set_module_brightness(&port, binding.i2c_address, binding.brightness)?;
    }
    sink.write_segments(&port, binding.i2c_address, bytes)
}

/// `blank_display/1`: empty text encoding, no brightness message.
fn blank_display(sink: &dyn HardwareDispatch, binding: &DisplayBindingConfig) {
    if let Some(port) = sink.resolve_port(binding.device_config_id) {
        let bytes = encode(binding, "");
        let _ = sink.write_segments(&port, binding.i2c_address, bytes);
    }
}

fn encode(binding: &DisplayBindingConfig, text: &str) -> Vec<u8> {
    encode_string(
        text,
        binding.num_digits,
        binding.seven_segment,
        binding.has_dot,
        binding.align_right,
    )
}

/// `invalidate_displays/1`: forget delivered text so the next poll replays
/// brightness and segments after device hotplug.
fn invalidate_displays(state: &mut State) {
    for info in state.bindings.values_mut() {
        info.last_text = None;
    }
}
