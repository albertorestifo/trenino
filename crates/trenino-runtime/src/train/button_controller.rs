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

use std::collections::{HashMap, HashSet};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc as std_mpsc;
use std::sync::{Arc, RwLock};
use std::time::Duration;

use serde_json::Value;
use tokio::sync::{mpsc, oneshot, watch, Mutex};
use trenino_core::train::buttons::SequenceCommand as CoreSequenceCommand;
use trenino_core::{ConfigId, EntityId};

use crate::routing::InputResolver;
use crate::simulator::client::SimulatorClient;
use crate::simulator::services::clock::Clock;
use crate::storage::bindings::{ButtonHardwareType, ButtonMode};

use super::detection::{SequenceCommand, TrainConfigSnapshot};
use super::sequence::{
    SequenceEvent, SequenceExecutor, SequenceRun, SequenceSendOutcome, SequenceSimulator,
};

/// Bounded command queue for button edges (plan default: 256).
const COMMAND_CAPACITY: usize = 256;
/// `button_state_changed` broadcast fan-out (PubSub-style drop when full).
const BROADCAST_CAPACITY: usize = 64;
const PORT_ACK_TIMEOUT: Duration = Duration::from_secs(1);
const SHUTDOWN_TIMEOUT: Duration = Duration::from_secs(1);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum QueueError {
    Overflow,
    Closed,
    Timeout,
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
    /// Live executor run, if the mode started one (the Elixir tracked pid).
    sequence: Option<SequenceRun>,
}

enum Control {
    Activate {
        generation: u64,
        train_id: EntityId,
        bindings: HashMap<EntityId, BindingRuntime>,
    },
    Release,
    ReleaseAcknowledged(std_mpsc::SyncSender<Result<(), String>>),
    SimulatorConnected(Arc<SimulatorClient>),
    SimulatorDisconnected,
    SuspendPort {
        port: String,
        lost_generation: Option<u64>,
        reply: std_mpsc::SyncSender<Result<(), String>>,
    },
    ResumePort {
        port: String,
        reply: std_mpsc::SyncSender<Result<(), String>>,
    },
    State(oneshot::Sender<ButtonStateSnapshot>),
    Shutdown,
}

enum Command {
    Input(ButtonSample),
    Observe(ButtonSample),
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
    lifecycle: Arc<ControllerLifecycle>,
}

struct ControllerLifecycle {
    closing: AtomicBool,
    shutdown_sent: AtomicBool,
    worker: Mutex<Option<tokio::task::JoinHandle<()>>>,
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
        let worker = tokio::spawn(run(
            RunContext {
                clock,
                resolver,
                keystrokes,
                broadcast,
                self_tx: commands.clone(),
            },
            command_rx,
            control_rx,
        ));
        let lifecycle = Arc::new(ControllerLifecycle {
            closing: AtomicBool::new(false),
            shutdown_sent: AtomicBool::new(false),
            worker: Mutex::new(Some(worker)),
        });
        (
            Self {
                commands,
                control,
                lifecycle,
            },
            broadcast_rx,
        )
    }

    fn ensure_open(&self) -> Result<(), QueueError> {
        if self.lifecycle.closing.load(Ordering::Acquire) {
            Err(QueueError::Closed)
        } else {
            Ok(())
        }
    }

    pub(crate) fn begin_shutdown(&self) {
        self.lifecycle.closing.store(true, Ordering::Release);
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
        self.ensure_open()?;
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
        self.ensure_open()?;
        self.control
            .send(Control::Release)
            .map_err(|_| QueueError::Closed)
    }

    /// Bounded synchronous routing release barrier. It is callable after
    /// admission closes and must run on an OS thread outside the worker.
    pub(crate) fn release_acknowledged(&self) -> Result<(), String> {
        let (reply, done) = std_mpsc::sync_channel(1);
        self.control
            .send(Control::ReleaseAcknowledged(reply))
            .map_err(|_| "button worker closed".to_string())?;
        done.recv_timeout(PORT_ACK_TIMEOUT)
            .map_err(|_| "button release acknowledgement timed out".to_string())?
    }

    pub fn simulator_connected(&self, client: Arc<SimulatorClient>) -> Result<(), QueueError> {
        self.ensure_open()?;
        self.control
            .send(Control::SimulatorConnected(client))
            .map_err(|_| QueueError::Closed)
    }

    pub fn simulator_disconnected(&self) -> Result<(), QueueError> {
        self.ensure_open()?;
        self.control
            .send(Control::SimulatorDisconnected)
            .map_err(|_| QueueError::Closed)
    }

    /// Synchronous acknowledged fence for hardware lease transfer. Call
    /// from an OS thread outside the controller's Tokio worker.
    pub fn suspend_port(&self, port: &str) -> Result<(), String> {
        self.port_command(port, None, false)
    }

    pub fn source_lost(&self, port: &str, generation: u64) -> Result<(), String> {
        self.port_command(port, Some(generation), false)
    }

    /// Clear a port fence after the hardware owner verifies a fresh sample.
    pub fn resume_port(&self, port: &str) -> Result<(), String> {
        self.port_command(port, None, true)
    }

    fn port_command(
        &self,
        port: &str,
        generation: Option<u64>,
        resume: bool,
    ) -> Result<(), String> {
        self.ensure_open()
            .map_err(|_| "button worker closing".to_string())?;
        let (reply, done) = std_mpsc::sync_channel(1);
        let command = if resume {
            Control::ResumePort {
                port: port.into(),
                reply,
            }
        } else {
            Control::SuspendPort {
                port: port.into(),
                lost_generation: generation,
                reply,
            }
        };
        self.control
            .send(command)
            .map_err(|_| "button worker closed".to_string())?;
        done.recv_timeout(PORT_ACK_TIMEOUT)
            .map_err(|_| "button port acknowledgement timed out".to_string())?
    }

    /// Queue a button edge, waiting while the bounded queue is full.
    pub async fn input(&self, sample: ButtonSample) -> Result<(), QueueError> {
        self.ensure_open()?;
        self.commands
            .send(Command::Input(sample))
            .await
            .map_err(|_| QueueError::Closed)
    }

    /// Non-blocking ingress: an edge is never silently dropped — the caller
    /// observes [`QueueError::Overflow`] and must shed or reset the source.
    pub fn try_input(&self, sample: ButtonSample) -> Result<(), QueueError> {
        self.ensure_open()?;
        self.commands
            .try_send(Command::Input(sample))
            .map_err(|error| match error {
                mpsc::error::TrySendError::Full(_) => QueueError::Overflow,
                mpsc::error::TrySendError::Closed(_) => QueueError::Closed,
            })
    }

    /// Preserve a leased/suspended physical level without running its edge later.
    pub fn try_observe(&self, sample: ButtonSample) -> Result<(), QueueError> {
        self.ensure_open()?;
        self.commands
            .try_send(Command::Observe(sample))
            .map_err(|error| match error {
                mpsc::error::TrySendError::Full(_) => QueueError::Overflow,
                mpsc::error::TrySendError::Closed(_) => QueueError::Closed,
            })
    }

    pub async fn state(&self) -> Result<ButtonStateSnapshot, QueueError> {
        self.ensure_open()?;
        let (reply, reply_rx) = oneshot::channel();
        self.control
            .send(Control::State(reply))
            .map_err(|_| QueueError::Closed)?;
        reply_rx.await.map_err(|_| QueueError::Closed)
    }

    pub async fn shutdown(&self) -> Result<(), QueueError> {
        self.begin_shutdown();
        // Holding this gate serializes clone callers. A timeout keeps the
        // join handle and the already admitted shutdown command for retry.
        let mut slot = self.lifecycle.worker.lock().await;
        let Some(worker) = slot.as_mut() else {
            return Ok(());
        };
        if !self.lifecycle.shutdown_sent.swap(true, Ordering::AcqRel) {
            self.control
                .send(Control::Shutdown)
                .map_err(|_| QueueError::Closed)?;
        }
        tokio::time::timeout(SHUTDOWN_TIMEOUT, worker)
            .await
            .map_err(|_| QueueError::Timeout)?
            .map_err(|_| QueueError::Closed)?;
        *slot = None;
        Ok(())
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
    keystrokes: Arc<dyn ButtonKeystrokes>,
    /// Sequence runs go through the shared [`SequenceExecutor`] — the single
    /// tested executor (parity audit P1-12): the former inlined duplicate of
    /// `execute_sequence_commands/3` was deleted in its favor.
    executor: SequenceExecutor,
    /// Owner-liveness half for spawned runs (the executor's `Process.monitor`
    /// stand-in): dropped with the controller, cancelling every live run.
    owner: watch::Sender<()>,
    /// Completion sink of live runs; drained by the select loop.
    sequence_events: mpsc::UnboundedSender<SequenceEvent>,
    /// Run id → activation generation, fencing stale completions after a
    /// re-activation (`handle_info({:sequence_complete, …})` ignores them).
    sequence_runs: HashMap<u64, u64>,
    retired_runs: Vec<SequenceRun>,
    held_keys: HashMap<EntityId, String>,
    element_ports: HashMap<EntityId, String>,
    port_generations: HashMap<String, u64>,
    suspended_ports: HashSet<String>,
    observed_inputs: HashMap<EntityId, (String, u64, i16)>,
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
        for (_, button) in self.active_buttons.drain() {
            if let Some(sequence) = button.sequence {
                sequence.abort();
                self.retired_runs.push(sequence);
            }
        }
        if self.train_id.is_some() {
            self.keystrokes.owner_gone(self.keystroke_owner());
        }
        self.retired_runs.retain(|run| !run.is_finished());
        self.sequence_runs.clear();
        self.held_keys.clear();
        self.element_ports.clear();
        self.pending_repeats.clear();
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
            let still_active = self.active_buttons.contains_key(&id);
            let queued =
                still_active && self.self_tx.try_send(Command::MomentaryRepeat(id)).is_ok();
            if !still_active || queued {
                self.pending_repeats.remove(&id);
            }
        }
    }

    fn clear_routing(&mut self) {
        self.cancel_all();
        self.bindings.clear();
        self.observed_inputs.clear();
        self.last_sent.clear();
    }

    async fn release_for_routing(&mut self) -> Result<(), String> {
        for (_, button) in self.active_buttons.drain() {
            if let Some(sequence) = button.sequence {
                sequence.abort();
                self.retired_runs.push(sequence);
            }
        }
        self.sequence_runs.clear();
        self.element_ports.clear();
        self.pending_repeats.clear();
        self.bindings.clear();
        self.observed_inputs.clear();
        self.last_sent.clear();
        self.active = false;

        let owner = self.keystroke_owner();
        let mut failure = None;
        for id in self.held_keys.keys().copied().collect::<Vec<_>>() {
            match self.keystrokes.release(owner, id) {
                Ok(()) => {
                    self.held_keys.remove(&id);
                }
                Err(error) => {
                    failure.get_or_insert(error);
                }
            }
        }
        if failure.is_none() {
            if self.train_id.is_some() {
                self.keystrokes.owner_gone(owner);
            }
            self.train_id = None;
        }
        let settled = tokio::time::timeout(Duration::from_millis(500), async {
            while self.retired_runs.iter().any(|run| !run.is_finished()) {
                tokio::time::sleep(Duration::from_millis(1)).await;
            }
        })
        .await
        .is_ok();
        if !settled {
            failure.get_or_insert("button sequence cancellation timed out".into());
        }
        failure.map_or(Ok(()), Err)
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
    /// Start one run through the shared [`SequenceExecutor`] and remember
    /// its generation for stale-completion fencing. The Elixir controller
    /// spawns a monitored process per sequence press
    /// (`spawn_sequence_runner/2`); the executor owns the loop, the delays
    /// and the `{:sequence_complete, element_id}` report.
    fn start_sequence(
        &mut self,
        element_id: EntityId,
        commands: Vec<SequenceCommand>,
    ) -> SequenceRun {
        let run = self.executor.start(
            element_id.0,
            core_sequence_commands(commands),
            self.owner.subscribe(),
            self.sequence_events.clone(),
        );
        self.sequence_runs.insert(run.run, self.generation);
        run
    }

    /// Abort a tracked run and forget its fence entry (re-press, release,
    /// train switch — every `Process.exit(task, :kill)` site).
    fn cancel_sequence_run(&mut self, run: SequenceRun) {
        self.sequence_runs.remove(&run.run);
        run.abort();
        self.retired_runs.retain(|retired| !retired.is_finished());
        self.retired_runs.push(run);
    }
}

/// `SequenceSimulator` adapter over the live client slot: each command
/// reads the CURRENT client (like the Elixir executor calling
/// `get_simulator_client/0` before each send) and performs the HTTP set; a
/// missing client is the "Simulator not connected for sequence" skip.
struct ClientSlotSequence {
    slot: ClientSlot,
}

impl SequenceSimulator for ClientSlotSequence {
    fn set_async<'a>(
        &'a self,
        endpoint: &'a str,
        value: f64,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = SequenceSendOutcome> + Send + 'a>> {
        let client = self.slot.read().expect("client slot poisoned").clone();
        let endpoint = endpoint.to_owned();
        Box::pin(async move {
            let Some(client) = client else {
                return SequenceSendOutcome::Disconnected;
            };
            match client.set(&endpoint, &Value::from(value)).await {
                Ok(_) => SequenceSendOutcome::Sent,
                Err(error) => SequenceSendOutcome::Failed(error.to_string()),
            }
        })
    }
}

/// The controller loads sequences already ordered by position
/// (`preload_order: [asc: :position]`); index → position keeps that order
/// for `ordered_sequence`'s stable sort.
fn core_sequence_commands(commands: Vec<SequenceCommand>) -> Vec<CoreSequenceCommand> {
    commands
        .into_iter()
        .enumerate()
        .map(|(position, command)| CoreSequenceCommand {
            endpoint: command.endpoint,
            value: command.value,
            delay_ms: command.delay_ms,
            position: position as u32,
        })
        .collect()
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

/// Bundled worker inputs for [`run`] (keeps the argument list within limits).
struct RunContext {
    clock: Arc<dyn Clock>,
    resolver: Arc<InputResolver>,
    keystrokes: Arc<dyn ButtonKeystrokes>,
    broadcast: mpsc::Sender<ButtonStateChange>,
    self_tx: mpsc::Sender<Command>,
}

async fn run(
    ctx: RunContext,
    mut commands: mpsc::Receiver<Command>,
    mut control: mpsc::UnboundedReceiver<Control>,
) {
    let RunContext {
        clock,
        resolver,
        keystrokes,
        broadcast,
        self_tx,
    } = ctx;
    let client_slot: ClientSlot = Arc::new(RwLock::new(None));
    // The single shared sequence executor (P1-12): every mode goes through
    // `train::sequence`, the tested port of `execute_sequence_commands/3`.
    let executor = SequenceExecutor::new(
        Arc::new(ClientSlotSequence {
            slot: client_slot.clone(),
        }),
        clock,
    );
    // Owner-liveness monitor: dropping the sender (controller end) cancels
    // every live run through the executor's watch arms.
    let (owner, _) = watch::channel(());
    let (sequence_events, mut sequence_event_rx) = mpsc::unbounded_channel();
    let mut state = WorkerState {
        generation: 0,
        train_id: None,
        active: false,
        bindings: HashMap::new(),
        last_sent: HashMap::new(),
        active_buttons: HashMap::new(),
        client: None,
        keystrokes,
        executor,
        owner,
        sequence_events,
        sequence_runs: HashMap::new(),
        retired_runs: Vec::new(),
        held_keys: HashMap::new(),
        element_ports: HashMap::new(),
        port_generations: HashMap::new(),
        suspended_ports: HashSet::new(),
        observed_inputs: HashMap::new(),
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
                    Control::ReleaseAcknowledged(reply) => {
                        let _ = reply.send(state.release_for_routing().await);
                    }
                    Control::SimulatorConnected(client) => {
                        state.client = Some(client.clone());
                        *client_slot.write().expect("client slot poisoned") = Some(client);
                    }
                    Control::SimulatorDisconnected => {
                        state.client = None;
                        *client_slot.write().expect("client slot poisoned") = None;
                    }
                    Control::SuspendPort { port, lost_generation, reply } => {
                        let newer = lost_generation.is_some_and(|generation|
                            state.port_generations.get(&port).is_some_and(|current| *current > generation));
                        if newer { let _ = reply.send(Ok(())); continue; }
                        state.suspended_ports.insert(port.clone());
                        let _ = reply.send(neutralize_port(&mut state, &port).await);
                    }
                    Control::ResumePort { port, reply } => {
                        state.suspended_ports.remove(&port);
                        let _ = reply.send(Ok(()));
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
                    Control::Shutdown => {
                        state.clear_routing();
                        while state.retired_runs.iter().any(|run| !run.is_finished()) {
                            tokio::time::sleep(Duration::from_millis(1)).await;
                        }
                        break;
                    }
                }
            }
            // `{:sequence_complete, element_id}` reports; stale runs after
            // a re-activation are dropped (run→generation fence).
            sequence_event = sequence_event_rx.recv() => {
                let Some(SequenceEvent::Complete { element_id, run }) = sequence_event else { break };
                if state.sequence_runs.remove(&run) == Some(state.generation) {
                    state.active_buttons.remove(&EntityId(element_id));
                }
            }
            command = commands.recv() => {
                let Some(command) = command else { break };
                match command {
                    Command::Input(sample) => {
                        apply_input(&mut state, &resolver, sample, false).await;
                    }
                    Command::Observe(sample) => {
                        apply_input(&mut state, &resolver, sample, true).await;
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

async fn neutralize_port(state: &mut WorkerState, port: &str) -> Result<(), String> {
    let affected: Vec<_> = state
        .element_ports
        .iter()
        .filter(|(_, source)| source.as_str() == port)
        .map(|(id, _)| *id)
        .collect();
    let mut aborted = Vec::new();
    for id in affected {
        state.element_ports.remove(&id);
        state.last_sent.remove(&id);
        state.pending_repeats.remove(&id);
        if let Some(button) = state.active_buttons.remove(&id) {
            if let Some(run) = button.sequence {
                state.sequence_runs.remove(&run.run);
                run.abort();
                aborted.push(run);
            }
        }
    }
    let key_ids: Vec<_> = state
        .held_keys
        .iter()
        .filter(|(_, source)| source.as_str() == port)
        .map(|(id, _)| *id)
        .collect();
    let mut error = None;
    for id in key_ids {
        match state.keystrokes.release(state.keystroke_owner(), id) {
            Ok(()) => {
                state.held_keys.remove(&id);
            }
            Err(reason) => {
                error.get_or_insert(reason);
            }
        }
    }
    let settled = tokio::time::timeout(Duration::from_millis(500), async {
        while aborted.iter().any(|run| !run.is_finished()) {
            tokio::time::sleep(Duration::from_millis(1)).await;
        }
    })
    .await
    .is_ok();
    state.retired_runs.extend(aborted);
    if !settled {
        error.get_or_insert("button sequence cancellation timed out".into());
    }
    error.map_or(Ok(()), Err)
}

async fn apply_input(
    state: &mut WorkerState,
    resolver: &Arc<InputResolver>,
    sample: ButtonSample,
    observe_only: bool,
) {
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
    if observe_only || state.suspended_ports.contains(&sample.port) {
        state
            .port_generations
            .insert(sample.port.clone(), sample.port_generation);
        if state.bindings.contains_key(&identity.input_id) {
            state.observed_inputs.insert(
                identity.input_id,
                (sample.port.clone(), sample.port_generation, sample.value),
            );
        }
        if let Err(error) = neutralize_port(state, &sample.port).await {
            eprintln!("button cached-source cleanup failed: {error}");
        }
        return;
    }
    if state
        .observed_inputs
        .get(&identity.input_id)
        .is_some_and(|(port, generation, value)| {
            port == &sample.port && *generation == sample.port_generation && *value == sample.value
        })
    {
        return;
    }
    state.observed_inputs.remove(&identity.input_id);
    let Some(binding) = state.bindings.get(&identity.input_id).cloned() else {
        return;
    };
    state
        .port_generations
        .insert(sample.port.clone(), sample.port_generation);
    state
        .element_ports
        .insert(binding.element_id, sample.port.clone());
    match sample.value {
        1 => press(state, &binding, &sample.port).await,
        0 => release(state, &binding).await,
        _ => {}
    }
}

async fn press(state: &mut WorkerState, binding: &BindingRuntime, port: &str) {
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
                if let Some(sequence) = previous.sequence {
                    state.cancel_sequence_run(sequence);
                }
            }
            let task = state.start_sequence(
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
                state.held_keys.insert(binding.binding_id, port.into());
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
                state
                    .last_sent
                    .insert(binding.element_id, binding.off_value);
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
            state
                .last_sent
                .insert(binding.element_id, binding.off_value);
        }
        ButtonMode::Sequence => {
            // Momentary hardware: the on-sequence dies on release (579-594).
            if let Some(previous) = state.active_buttons.remove(&binding.element_id) {
                if let Some(sequence) = previous.sequence {
                    state.cancel_sequence_run(sequence);
                }
            }
            let starts_off_sequence = binding.hardware_type == ButtonHardwareType::Latching
                && binding
                    .off_sequence
                    .as_ref()
                    .is_some_and(|commands| !commands.is_empty());
            if starts_off_sequence {
                let task = state.start_sequence(
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
            state
                .last_sent
                .insert(binding.element_id, binding.off_value);
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
                state.held_keys.remove(&binding.binding_id);
            }
        }
    }
}
