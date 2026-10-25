//! Button dispatch controller.
//!
//! Port of `Trenino.Train.ButtonController`
//! (lib/trenino/train/button_controller.ex) with all four binding modes:
//!
//! - **simple** — on/off sends deduplicated through `last_sent` per element
//!   (button_controller.ex:360-371, 465-476);
//! - **momentary** — press sends `Interacting=1` *before* the value, release
//!   sends the value *before* `Interacting=0` (622-658), then request-paced
//!   repeats of the on value while held: one repeat per completed HTTP send,
//!   no interval pacing (210-225 — the persisted `repeat_interval_ms` is
//!   deliberately ignored, a documented baseline quirk);
//! - **sequence** — ordered commands each followed by their delay, executed
//!   in a spawned task; a failing command is logged and the sequence
//!   continues (718-757); momentary hardware cancels the on-sequence on
//!   release while latching hardware starts the off-sequence (512-577);
//! - **keystroke** — press/release through the injected keystroke port.
//!
//! Structural differences from the Elixir process model: input identity comes
//! from the shared [`InputResolver`]; the mailbox is split into a bounded
//! command queue (256; edges are never silently dropped — ingress sees
//! [`QueueError::Overflow`]) and a priority control queue, so release and
//! activation never wait behind input load; sequence cancellation aborts the
//! executor task immediately (Elixir kills the spawned process) and stale
//! completions are fenced by activation generation.

use std::collections::HashMap;
use std::sync::{Arc, RwLock};
use std::time::Duration;

use serde_json::Value;
use tokio::sync::{mpsc, oneshot};
use tokio::task::JoinHandle;
use trenino_core::{ConfigId, EntityId};

use crate::routing::InputResolver;
use crate::simulator::client::SimulatorClient;
use crate::simulator::services::clock::Clock;
use crate::storage::bindings::{ButtonHardwareType, ButtonMode};

use super::detection::{SequenceCommand, TrainConfigSnapshot};

/// Bounded command queue for button edges (plan default: 256).
const COMMAND_CAPACITY: usize = 256;
/// `button_state_changed` broadcast fan-out (PubSub-style drop when full).
const BROADCAST_CAPACITY: usize = 64;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum QueueError {
    Overflow,
    Closed,
}

/// `{:button_state_changed, element_id, %{value, pressed}}` on the
/// `"train:button_values"` topic (button_controller.ex:684-690).
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct ButtonStateChange {
    pub element_id: EntityId,
    pub value: f64,
    pub pressed: bool,
}

/// Owner identity for held keystrokes. Field-for-field compatible with the
/// merged `crate::keyboard::HoldOwner` (KeyboardOwnership track): the
/// production bridge passes `owner = train_id` and the activation generation,
/// so a stale generation's late events never own live keys.
#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash)]
pub struct KeystrokeOwner {
    pub owner: EntityId,
    pub generation: u64,
}

/// Narrow keystroke port the button controller depends on. Method shape
/// matches the merged `KeyboardOwnership` API (`press(owner, binding, combo)`
/// / `release(owner, binding)` / `owner_gone(owner)`); the wave-integration
/// bridge wraps `KeyboardOwnership<A>` behind this trait. Tests install an
/// in-memory fake.
pub trait ButtonKeystrokes: Send + Sync + 'static {
    fn press(&self, owner: KeystrokeOwner, binding: EntityId, combo: &str) -> Result<(), String>;
    fn release(&self, owner: KeystrokeOwner, binding: EntityId) -> Result<(), String>;
    /// Release every key held by `owner` (stuck-key cleanup on train switch).
    fn owner_gone(&self, owner: KeystrokeOwner);
}

/// One hardware button sample: the Elixir
/// `{:input_value_updated, port, pin, raw_value}` message plus the connection
/// identity the shared resolver needs.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ButtonSample {
    pub port: String,
    pub port_generation: u64,
    pub config_id: ConfigId,
    pub pin: u8,
    pub value: i16,
}

/// Controller-visible state for diagnostics.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct ButtonStateSnapshot {
    pub active: bool,
    pub generation: u64,
    pub bindings: usize,
    pub last_sent: usize,
    pub active_buttons: usize,
}

#[derive(Clone, Debug)]
struct BindingRuntime {
    binding_id: EntityId,
    element_id: EntityId,
    endpoint: Option<String>,
    on_value: f64,
    off_value: f64,
    mode: ButtonMode,
    hardware_type: ButtonHardwareType,
    keystroke: Option<String>,
    on_sequence: Option<Vec<SequenceCommand>>,
    off_sequence: Option<Vec<SequenceCommand>>,
}

#[derive(Debug)]
struct ActiveButton {
    #[allow(dead_code)]
    binding_id: EntityId,
    endpoint: Option<String>,
    #[allow(dead_code)]
    on_value: f64,
    sequence: Option<JoinHandle<()>>,
}

enum Control {
    Activate {
        generation: u64,
        train_id: EntityId,
        bindings: HashMap<EntityId, BindingRuntime>,
    },
    Release,
    SimulatorConnected(Arc<SimulatorClient>),
    SimulatorDisconnected,
    SequenceDone {
        generation: u64,
        element_id: EntityId,
    },
    State(oneshot::Sender<ButtonStateSnapshot>),
    Shutdown(oneshot::Sender<()>),
}

enum Command {
    Input(ButtonSample),
    /// Self-addressed repeat tick; a missing entry means the button was
    /// released (button_controller.ex:210-225).
    MomentaryRepeat(EntityId),
}

/// Shared view of the current simulator client for spawned sequence tasks
/// (they read the live connection per command, like the Elixir executor
/// calling `get_simulator_client/0` before each command).
type ClientSlot = Arc<RwLock<Option<Arc<SimulatorClient>>>>;

#[derive(Clone)]
pub struct ButtonController {
    commands: mpsc::Sender<Command>,
    control: mpsc::UnboundedSender<Control>,
}

impl ButtonController {
    pub fn start(
        clock: Arc<dyn Clock>,
        resolver: Arc<InputResolver>,
        keystrokes: Arc<dyn ButtonKeystrokes>,
    ) -> (Self, mpsc::Receiver<ButtonStateChange>) {
        let (commands, command_rx) = mpsc::channel(COMMAND_CAPACITY);
        let (control, control_rx) = mpsc::unbounded_channel();
        let (broadcast, broadcast_rx) = mpsc::channel(BROADCAST_CAPACITY);
        tokio::spawn(run(
            clock,
            resolver,
            keystrokes,
            broadcast,
            commands.clone(),
            command_rx,
            control.clone(),
            control_rx,
        ));
        (Self { commands, control }, broadcast_rx)
    }

    /// Load bindings for a new activation, cancelling every active button,
    /// sequence task and held keystroke of the previous activation first
    /// (`cancel_all_active_buttons/1`, button_controller.ex:596-605).
    pub fn activate(
        &self,
        generation: u64,
        train_id: EntityId,
        snapshot: &TrainConfigSnapshot,
    ) -> Result<(), QueueError> {
        let bindings = snapshot
            .button_bindings
            .iter()
            .map(|binding| {
                (
                    binding.input_id,
                    BindingRuntime {
                        binding_id: binding.binding_id,
                        element_id: binding.element_id,
                        endpoint: binding.endpoint.clone(),
                        on_value: binding.on_value,
                        off_value: binding.off_value,
                        mode: binding.mode,
                        hardware_type: binding.hardware_type,
                        keystroke: binding.keystroke.clone(),
                        on_sequence: binding.on_sequence.clone(),
                        off_sequence: binding.off_sequence.clone(),
                    },
                )
            })
            .collect();
        self.control
            .send(Control::Activate {
                generation,
                train_id,
                bindings,
            })
            .map_err(|_| QueueError::Closed)
    }

    pub fn release(&self) -> Result<(), QueueError> {
        self.control.send(Control::Release).map_err(|_| QueueError::Closed)
    }

    pub fn simulator_connected(&self, client: Arc<SimulatorClient>) -> Result<(), QueueError> {
        self.control
            .send(Control::SimulatorConnected(client))
            .map_err(|_| QueueError::Closed)
    }

    pub fn simulator_disconnected(&self) -> Result<(), QueueError> {
        self.control
            .send(Control::SimulatorDisconnected)
            .map_err(|_| QueueError::Closed)
    }

    /// Queue a button edge, waiting while the bounded queue is full.
    pub async fn input(&self, sample: ButtonSample) -> Result<(), QueueError> {
        self.commands
            .send(Command::Input(sample))
            .await
            .map_err(|_| QueueError::Closed)
    }

    /// Non-blocking ingress: an edge is never silently dropped — the caller
    /// observes [`QueueError::Overflow`] and must shed or reset the source.
    pub fn try_input(&self, sample: ButtonSample) -> Result<(), QueueError> {
        self.commands
            .try_send(Command::Input(sample))
            .map_err(|error| match error {
                mpsc::error::TrySendError::Full(_) => QueueError::Overflow,
                mpsc::error::TrySendError::Closed(_) => QueueError::Closed,
            })
    }

    pub async fn state(&self) -> Result<ButtonStateSnapshot, QueueError> {
        let (reply, reply_rx) = oneshot::channel();
        self.control
            .send(Control::State(reply))
            .map_err(|_| QueueError::Closed)?;
        reply_rx.await.map_err(|_| QueueError::Closed)
    }

    pub async fn shutdown(self) -> Result<(), QueueError> {
        let (reply, reply_rx) = oneshot::channel();
        self.control
            .send(Control::Shutdown(reply))
            .map_err(|_| QueueError::Closed)?;
        reply_rx.await.map_err(|_| QueueError::Closed)
    }
}

struct WorkerState {
    generation: u64,
    train_id: Option<EntityId>,
    active: bool,
    bindings: HashMap<EntityId, BindingRuntime>,
    last_sent: HashMap<EntityId, f64>,
    active_buttons: HashMap<EntityId, ActiveButton>,
    client: Option<Arc<SimulatorClient>>,
    client_slot: ClientSlot,
    keystrokes: Arc<dyn ButtonKeystrokes>,
    clock: Arc<dyn Clock>,
    control_tx: mpsc::UnboundedSender<Control>,
    self_tx: mpsc::Sender<Command>,
    /// Momentary repeat ticks that could not be queued because the bounded
    /// edge queue was full; re-armed as the queue drains so saturation can
    /// never permanently kill a held button's repeat loop (the Elixir
    /// mailbox is unbounded and always delivers the self-tick).
    pending_repeats: std::collections::HashSet<EntityId>,
    broadcast: mpsc::Sender<ButtonStateChange>,
}

impl WorkerState {
    fn keystroke_owner(&self) -> KeystrokeOwner {
        KeystrokeOwner {
            owner: self.train_id.unwrap_or(EntityId(0)),
            generation: self.generation,
        }
    }

    /// `cancel_all_active_buttons/1`: kill sequence tasks and forget entries.
    /// Held keystrokes of the old activation are force-released through
    /// `owner_gone` so a train switch cannot leak a held OS key.
    fn cancel_all(&mut self) {
        if self.train_id.is_some() {
            self.keystrokes.owner_gone(self.keystroke_owner());
        }
        for button in self.active_buttons.values() {
            if let Some(sequence) = button.sequence.as_ref() {
                sequence.abort();
            }
        }
        self.pending_repeats.clear();
        self.active_buttons.clear();
    }

    /// Queue the next repeat tick, remembering the button when the bounded
    /// queue is momentarily full.
    fn arm_repeat(&mut self, element_id: EntityId) {
        if self
            .self_tx
            .try_send(Command::MomentaryRepeat(element_id))
            .is_err()
        {
            self.pending_repeats.insert(element_id);
        }
    }

    /// Re-arm overflowed repeat ticks after each processed command so the
    /// loop resumes as soon as the queue has room; entries for buttons that
    /// were released while parked are dropped.
    fn drain_pending_repeats(&mut self) {
        let ids: Vec<EntityId> = self.pending_repeats.iter().copied().collect();
        for id in ids {
            if !self.active_buttons.contains_key(&id) {
                self.pending_repeats.remove(&id);
            } else if self.self_tx.try_send(Command::MomentaryRepeat(id)).is_ok() {
                self.pending_repeats.remove(&id);
            }
        }
    }

    fn clear_routing(&mut self) {
        self.cancel_all();
        self.bindings.clear();
        self.last_sent.clear();
    }

    fn broadcast(&self, element_id: EntityId, value: f64, pressed: bool) {
        // PubSub-style: a full mailbox drops instead of stalling dispatch.
        let _ = self.broadcast.try_send(ButtonStateChange {
            element_id,
            value,
            pressed,
        });
    }

    async fn send_value(&self, endpoint: &str, value: f64) {
        if let Some(client) = &self.client {
            let _ = client.set(endpoint, &Value::from(value)).await;
        }
    }

    /// `send_to_simulator_with_interacting/3` (button_controller.ex:622-644):
    /// press order is Interacting=1 then value; release order is value then
    /// Interacting=0. Both sends are best-effort, like the Elixir client calls.
    async fn send_with_interacting(&self, endpoint: &str, value: f64, interacting: bool) {
        let Some(client) = self.client.clone() else {
            return;
        };
        let interacting_endpoint = derive_interacting_endpoint(endpoint);
        if interacting {
            let _ = client.set(&interacting_endpoint, &Value::from(1.0)).await;
            let _ = client.set(endpoint, &Value::from(value)).await;
        } else {
            let _ = client.set(endpoint, &Value::from(value)).await;
            let _ = client.set(&interacting_endpoint, &Value::from(0.0)).await;
        }
    }

    fn spawn_sequence(&self, element_id: EntityId, commands: Vec<SequenceCommand>) -> JoinHandle<()> {
        let generation = self.generation;
        let client_slot = self.client_slot.clone();
        let clock = self.clock.clone();
        let control = self.control_tx.clone();
        tokio::spawn(async move {
            for command in commands {
                // Owner-liveness is structural: cancellation aborts this task
                // (Elixir kills the process); a completion that already left
                // is fenced by its generation tag.
                let client = client_slot.read().expect("client slot poisoned").clone();
                if let Some(client) = client {
                    // A failed command is logged and the sequence continues
                    // (execute_sequence_loop/4 ignores the send result).
                    let _ = client
                        .set(&command.endpoint, &Value::from(command.value))
                        .await;
                }
                if command.delay_ms > 0 {
                    clock.sleep(Duration::from_millis(command.delay_ms)).await;
                }
            }
            let _ = control.send(Control::SequenceDone {
                generation,
                element_id,
            });
        })
    }
}

/// `derive_interacting_endpoint/1` (button_controller.ex:646-658): replace a
/// trailing `.InputValue` with `.Interacting`, otherwise replace the final
/// dot-separated segment; an endpoint without any dot is returned unchanged.
fn derive_interacting_endpoint(endpoint: &str) -> String {
    if let Some(prefix) = endpoint.strip_suffix(".InputValue") {
        return format!("{prefix}.Interacting");
    }
    if let Some((prefix, _)) = endpoint.rsplit_once('.') {
        return format!("{prefix}.Interacting");
    }
    endpoint.to_owned()
}

async fn run(
    clock: Arc<dyn Clock>,
    resolver: Arc<InputResolver>,
    keystrokes: Arc<dyn ButtonKeystrokes>,
    broadcast: mpsc::Sender<ButtonStateChange>,
    self_tx: mpsc::Sender<Command>,
    mut commands: mpsc::Receiver<Command>,
    control_tx: mpsc::UnboundedSender<Control>,
    mut control: mpsc::UnboundedReceiver<Control>,
) {
    let client_slot: ClientSlot = Arc::new(RwLock::new(None));
    let mut state = WorkerState {
        generation: 0,
        train_id: None,
        active: false,
        bindings: HashMap::new(),
        last_sent: HashMap::new(),
        active_buttons: HashMap::new(),
        client: None,
        client_slot: client_slot.clone(),
        keystrokes,
        clock,
        control_tx,
        self_tx,
        pending_repeats: std::collections::HashSet::new(),
        broadcast,
    };

    loop {
        tokio::select! {
            biased;
            control = control.recv() => {
                let Some(control) = control else { break };
                match control {
                    Control::Activate { generation, train_id, bindings } => {
                        state.clear_routing();
                        state.generation = generation;
                        state.train_id = Some(train_id);
                        state.bindings = bindings;
                        state.active = true;
                    }
                    Control::Release => {
                        // {:train_changed, nil}: cancel everything, clear lookups.
                        state.clear_routing();
                        state.active = false;
                        state.train_id = None;
                    }
                    Control::SimulatorConnected(client) => {
                        state.client = Some(client.clone());
                        *client_slot.write().expect("client slot poisoned") = Some(client);
                    }
                    Control::SimulatorDisconnected => {
                        state.client = None;
                        *client_slot.write().expect("client slot poisoned") = None;
                    }
                    Control::SequenceDone { generation, element_id } => {
                        // Stale completions after a re-activation are dropped.
                        if generation == state.generation {
                            state.active_buttons.remove(&element_id);
                        }
                    }
                    Control::State(reply) => {
                        let snapshot = ButtonStateSnapshot {
                            active: state.active,
                            generation: state.generation,
                            bindings: state.bindings.len(),
                            last_sent: state.last_sent.len(),
                            active_buttons: state.active_buttons.len(),
                        };
                        let _ = reply.send(snapshot);
                    }
                    Control::Shutdown(reply) => {
                        state.clear_routing();
                        let _ = reply.send(());
                        break;
                    }
                }
            }
            command = commands.recv() => {
                let Some(command) = command else { break };
                match command {
                    Command::Input(sample) => {
                        apply_input(&mut state, &resolver, sample).await;
                    }
                    Command::MomentaryRepeat(element_id) => {
                        // Active entry drives request-paced repeats; a released
                        // button's stale tick is a no-op (210-225).
                        if let Some(button) = state.active_buttons.get(&element_id) {
                            let endpoint = button.endpoint.clone();
                            let on_value = button.on_value;
                            if let Some(endpoint) = endpoint {
                                state.send_value(&endpoint, on_value).await;
                            }
                            // Immediately queue the next send (no delay);
                            // a full queue parks the tick for re-arming.
                            state.arm_repeat(element_id);
                        }
                    }
                }
                state.drain_pending_repeats();
            }
        }
    }
}

async fn apply_input(state: &mut WorkerState, resolver: &Arc<InputResolver>, sample: ButtonSample) {
    if !state.active {
        return;
    }
    let Some(identity) = resolver.resolve(
        &sample.port,
        sample.port_generation,
        sample.config_id,
        sample.pin,
    ) else {
        return;
    };
    let Some(binding) = state.bindings.get(&identity.input_id).cloned() else {
        return;
    };
    match sample.value {
        1 => press(state, &binding).await,
        0 => release(state, &binding).await,
        _ => {}
    }
}

async fn press(state: &mut WorkerState, binding: &BindingRuntime) {
    match binding.mode {
        ButtonMode::Simple => {
            // Dedup through last_sent; the broadcast still fires on a
            // best-effort send, exactly like the Elixir handler.
            if state.last_sent.get(&binding.element_id) != Some(&binding.on_value) {
                if let Some(endpoint) = &binding.endpoint {
                    state.send_value(endpoint, binding.on_value).await;
                }
                state.broadcast(binding.element_id, binding.on_value, true);
                state.last_sent.insert(binding.element_id, binding.on_value);
            }
        }
        ButtonMode::Momentary => {
            let endpoint = binding.endpoint.clone().unwrap_or_default();
            state
                .send_with_interacting(&endpoint, binding.on_value, true)
                .await;
            state.broadcast(binding.element_id, binding.on_value, true);
            // Start the request-paced repeat loop (no interval); a full
            // queue parks the first tick for re-arming.
            state.arm_repeat(binding.element_id);
            state.active_buttons.insert(
                binding.element_id,
                ActiveButton {
                    binding_id: binding.binding_id,
                    endpoint: binding.endpoint.clone(),
                    on_value: binding.on_value,
                    sequence: None,
                },
            );
            state.last_sent.insert(binding.element_id, binding.on_value);
        }
        ButtonMode::Sequence => {
            // No sequence or an empty sequence: skip (400-410).
            let empty = binding
                .on_sequence
                .as_ref()
                .is_none_or(|commands| commands.is_empty());
            if empty {
                return;
            }
            state.broadcast(binding.element_id, binding.on_value, true);
            // A re-press replaces any surviving entry (and its task).
            if let Some(previous) = state.active_buttons.remove(&binding.element_id) {
                if let Some(sequence) = previous.sequence.as_ref() {
                    sequence.abort();
                }
            }
            let task = state.spawn_sequence(
                binding.element_id,
                binding.on_sequence.clone().unwrap_or_default(),
            );
            state.active_buttons.insert(
                binding.element_id,
                ActiveButton {
                    binding_id: binding.binding_id,
                    endpoint: binding.endpoint.clone(),
                    on_value: binding.on_value,
                    sequence: Some(task),
                },
            );
            state.last_sent.insert(binding.element_id, binding.on_value);
        }
        ButtonMode::Keystroke => {
            let Some(combo) = binding.keystroke.as_deref() else {
                return;
            };
            if state
                .keystrokes
                .press(state.keystroke_owner(), binding.binding_id, combo)
                .is_ok()
            {
                state.broadcast(binding.element_id, 1.0, true);
                state.last_sent.insert(binding.element_id, 1.0);
            }
        }
    }
}

async fn release(state: &mut WorkerState, binding: &BindingRuntime) {
    match binding.mode {
        ButtonMode::Simple => {
            if state.last_sent.get(&binding.element_id) != Some(&binding.off_value) {
                if let Some(endpoint) = &binding.endpoint {
                    state.send_value(endpoint, binding.off_value).await;
                }
                state.broadcast(binding.element_id, binding.off_value, false);
                state.last_sent.insert(binding.element_id, binding.off_value);
            }
        }
        ButtonMode::Momentary => {
            // Cancel the repeat loop first, then value + Interacting=0.
            state.active_buttons.remove(&binding.element_id);
            let endpoint = binding.endpoint.clone().unwrap_or_default();
            state
                .send_with_interacting(&endpoint, binding.off_value, false)
                .await;
            state.broadcast(binding.element_id, binding.off_value, false);
            state.last_sent.insert(binding.element_id, binding.off_value);
        }
        ButtonMode::Sequence => {
            // Momentary hardware: the on-sequence dies on release (579-594).
            if let Some(previous) = state.active_buttons.remove(&binding.element_id) {
                if let Some(sequence) = previous.sequence.as_ref() {
                    sequence.abort();
                }
            }
            let starts_off_sequence = binding.hardware_type == ButtonHardwareType::Latching
                && binding
                    .off_sequence
                    .as_ref()
                    .is_some_and(|commands| !commands.is_empty());
            if starts_off_sequence {
                let task = state.spawn_sequence(
                    binding.element_id,
                    binding.off_sequence.clone().unwrap_or_default(),
                );
                state.active_buttons.insert(
                    binding.element_id,
                    ActiveButton {
                        binding_id: binding.binding_id,
                        endpoint: binding.endpoint.clone(),
                        on_value: binding.on_value,
                        sequence: Some(task),
                    },
                );
            }
            state.broadcast(binding.element_id, binding.off_value, false);
            state.last_sent.insert(binding.element_id, binding.off_value);
        }
        ButtonMode::Keystroke => {
            // Ownership bookkeeping remembers the pressed keys; a missing
            // combo mirrors the Elixir key_up(nil) failure path (skip).
            if binding.keystroke.is_none() {
                return;
            }
            if state
                .keystrokes
                .release(state.keystroke_owner(), binding.binding_id)
                .is_ok()
            {
                state.broadcast(binding.element_id, 0.0, false);
                state.last_sent.insert(binding.element_id, 0.0);
            }
        }
    }
}
