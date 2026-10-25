//! Lever dispatch controller.
//!
//! Port of `Trenino.Train.LeverController` (lib/trenino/train/lever_controller.ex):
//! one in-flight write plus one latest pending value per lever, success-only
//! acknowledgement, bounded 200/400/800ms retries with per-lever tokens, and
//! suspended retries while the simulator is disconnected. Smooth-lever jitter
//! replaces the pending value instead of queueing a FIFO of stale writes
//! (lever_controller.ex:321-378); only successful writes are acknowledged, a
//! failure retains the latest target and retries it (371-391); a reconnect
//! restarts parked writers with a fresh retry budget (185-199).
//!
//! Differences forced by the runtime model are structural only: input identity
//! is resolved through the shared [`InputResolver`] instead of a per-controller
//! `(port, pin)` map, and the Elixir process mailbox is split into a bounded
//! command queue (256 samples, latest-value semantics) plus a priority control
//! queue so activation/release/cancel never wait behind input load.

use std::collections::{HashMap, HashSet};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc as std_mpsc;
use std::sync::Arc;
use std::time::{Duration, Instant};

use serde_json::Value;
use tokio::sync::{mpsc, oneshot, Mutex};
use trenino_core::hardware::calibration::{normalize, total_travel, Calibration};
use trenino_core::rounding::round_elixir;
use trenino_core::train::lever::{map_input, LeverConfig};
use trenino_core::{ConfigId, EntityId};

use crate::routing::InputResolver;
use crate::simulator::client::SimulatorClient;
use crate::simulator::services::clock::Clock;

use super::detection::TrainConfigSnapshot;

/// `@retry_delays [200, 400, 800]` (lever_controller.ex:46).
pub const RETRY_DELAYS: [Duration; 3] = [
    Duration::from_millis(200),
    Duration::from_millis(400),
    Duration::from_millis(800),
];

/// Bounded command queue for input samples (plan default: 256).
const COMMAND_CAPACITY: usize = 256;
/// Completion queue for in-flight writes (one per lever, bounded).
const WRITE_CAPACITY: usize = 64;
const PORT_ACK_TIMEOUT: Duration = Duration::from_secs(1);
const SHUTDOWN_TIMEOUT: Duration = Duration::from_secs(1);
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum QueueError {
    Overflow,
    Closed,
    Timeout,
}

/// Controller-visible state for diagnostics and bounded-state assertions.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct LeverStateSnapshot {
    pub active: bool,
    pub generation: u64,
    pub pending: usize,
    pub inflight: usize,
    pub retries: usize,
}

/// One hardware input sample for the lever controller: the Elixir
/// `{:input_value_updated, port, pin, raw_value}` message plus the connection
/// identity the shared resolver needs.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct LeverSample {
    pub port: String,
    pub port_generation: u64,
    pub config_id: ConfigId,
    pub pin: u8,
    pub value: i16,
}

struct BindingRuntime {
    lever_config_id: EntityId,
    value_endpoint: String,
    mapper: LeverConfig,
    calibration: Option<Calibration>,
}

struct PendingWrite {
    value: f64,
    endpoint: String,
    inflight: Option<InFlight>,
}

struct InFlight {
    seq: u64,
    abort: tokio::task::AbortHandle,
    watcher_abort: tokio::task::AbortHandle,
}

#[derive(Default)]
struct RetryState {
    attempts: u32,
    /// Armed timer (token + deadline); `None` while disarmed or exhausted.
    armed: Option<(u64, Instant)>,
}

enum Control {
    Activate {
        generation: u64,
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
    State(oneshot::Sender<LeverStateSnapshot>),
    Shutdown,
}

#[derive(Debug)]
struct WriteDone {
    generation: u64,
    lever_config_id: EntityId,
    seq: u64,
    written: f64,
    ok: bool,
}

/// Handle to the lever controller worker. Cloning shares the queues; dropping
/// the last clone stops the worker.
#[derive(Clone)]
pub struct LeverController {
    commands: mpsc::Sender<IncomingSample>,
    control: mpsc::UnboundedSender<Control>,
    lifecycle: Arc<ControllerLifecycle>,
}

struct IncomingSample {
    sample: LeverSample,
    observe_only: bool,
}

struct ControllerLifecycle {
    closing: AtomicBool,
    shutdown_sent: AtomicBool,
    worker: Mutex<Option<tokio::task::JoinHandle<()>>>,
}

impl LeverController {
    pub fn start(clock: Arc<dyn Clock>, resolver: Arc<InputResolver>) -> Self {
        let (commands, command_rx) = mpsc::channel(COMMAND_CAPACITY);
        let (control, control_rx) = mpsc::unbounded_channel();
        let (writes, writes_rx) = mpsc::channel(WRITE_CAPACITY);
        let worker = tokio::spawn(run(
            clock, resolver, command_rx, control_rx, writes_rx, writes,
        ));
        let lifecycle = Arc::new(ControllerLifecycle {
            closing: AtomicBool::new(false),
            shutdown_sent: AtomicBool::new(false),
            worker: Mutex::new(Some(worker)),
        });
        Self {
            commands,
            control,
            lifecycle,
        }
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

    /// Load bindings for a new activation. Cancels every in-flight writer and
    /// scheduled retry of the previous activation first (the activation
    /// barrier; Elixir `load_bindings_for_train/2` → `cancel_pending/1`).
    pub fn activate(
        &self,
        generation: u64,
        snapshot: &TrainConfigSnapshot,
    ) -> Result<(), QueueError> {
        self.ensure_open()?;
        let mut bindings = HashMap::new();
        for binding in &snapshot.lever_bindings {
            bindings.insert(
                binding.input_id,
                BindingRuntime {
                    lever_config_id: binding.lever_config_id,
                    value_endpoint: binding.value_endpoint.clone(),
                    mapper: LeverConfig {
                        inverted: binding.inverted,
                        notches: binding.notches.clone(),
                    },
                    calibration: binding.calibration,
                },
            );
        }
        self.control
            .send(Control::Activate {
                generation,
                bindings,
            })
            .map_err(|_| QueueError::Closed)
    }

    /// Stop driving any lever (train deactivated or switched).
    pub fn release(&self) -> Result<(), QueueError> {
        self.ensure_open()?;
        self.control
            .send(Control::Release)
            .map_err(|_| QueueError::Closed)
    }

    /// Bounded synchronous release barrier used by the routing destination.
    /// It remains available after admission closes so shutdown can release
    /// the route before joining the worker. Call from a non-Tokio thread.
    pub(crate) fn release_acknowledged(&self) -> Result<(), String> {
        let (reply, done) = std_mpsc::sync_channel(1);
        self.control
            .send(Control::ReleaseAcknowledged(reply))
            .map_err(|_| "lever worker closed".to_string())?;
        done.recv_timeout(PORT_ACK_TIMEOUT)
            .map_err(|_| "lever release acknowledgement timed out".to_string())?
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

    /// A synchronous, acknowledged port fence for hardware lease transfer.
    /// Call only from outside the controller's Tokio worker thread.
    pub fn suspend_port(&self, port: &str) -> Result<(), String> {
        self.port_command(port, None, false)
    }

    /// Fence a lost source generation; a later generation is left untouched.
    pub fn source_lost(&self, port: &str, generation: u64) -> Result<(), String> {
        self.port_command(port, Some(generation), false)
    }

    /// Release the fence after the hardware owner has verified a fresh sample.
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
            .map_err(|_| "lever worker closing".to_string())?;
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
            .map_err(|_| "lever worker closed".to_string())?;
        done.recv_timeout(PORT_ACK_TIMEOUT)
            .map_err(|_| "lever port acknowledgement timed out".to_string())?
    }

    /// Queue an input sample, waiting while the bounded queue is full.
    pub async fn input(&self, sample: LeverSample) -> Result<(), QueueError> {
        self.ensure_open()?;
        self.commands
            .send(IncomingSample {
                sample,
                observe_only: false,
            })
            .await
            .map_err(|_| QueueError::Closed)
    }

    /// Non-blocking ingress: reports [`QueueError::Overflow`] instead of
    /// silently dropping the sample.
    pub fn try_input(&self, sample: LeverSample) -> Result<(), QueueError> {
        self.ensure_open()?;
        self.try_sample(sample, false)
    }

    /// Cache a leased/suspended sample as a baseline, never as deferred actuation.
    pub fn try_observe(&self, sample: LeverSample) -> Result<(), QueueError> {
        self.try_sample(sample, true)
    }

    fn try_sample(&self, sample: LeverSample, observe_only: bool) -> Result<(), QueueError> {
        self.ensure_open()?;
        self.commands
            .try_send(IncomingSample {
                sample,
                observe_only,
            })
            .map_err(|error| match error {
                mpsc::error::TrySendError::Full(_) => QueueError::Overflow,
                mpsc::error::TrySendError::Closed(_) => QueueError::Closed,
            })
    }

    pub async fn state(&self) -> Result<LeverStateSnapshot, QueueError> {
        self.ensure_open()?;
        let (reply, reply_rx) = oneshot::channel();
        self.control
            .send(Control::State(reply))
            .map_err(|_| QueueError::Closed)?;
        reply_rx.await.map_err(|_| QueueError::Closed)
    }

    pub async fn shutdown(&self) -> Result<(), QueueError> {
        self.begin_shutdown();
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
    active: bool,
    bindings: HashMap<EntityId, BindingRuntime>,
    pending: HashMap<EntityId, PendingWrite>,
    retries: HashMap<EntityId, RetryState>,
    client: Option<Arc<SimulatorClient>>,
    write_seq: u64,
    retry_token: u64,
    lever_ports: HashMap<EntityId, String>,
    port_generations: HashMap<String, u64>,
    suspended_ports: HashSet<String>,
    observed_inputs: HashMap<EntityId, (String, u64, i16)>,
    retired_tasks: Vec<tokio::task::AbortHandle>,
}

impl WorkerState {
    fn next_retry_deadline(&self) -> Option<Instant> {
        self.retries
            .values()
            .filter_map(|retry| retry.armed.map(|(_, deadline)| deadline))
            .min()
    }

    /// `cancel_pending/1` (lever_controller.ex:412-419): kill in-flight
    /// writers, drop pending values and retry state.
    fn cancel_pending(&mut self) {
        for pending in self.pending.values_mut() {
            if let Some(inflight) = pending.inflight.take() {
                inflight.abort.abort();
                inflight.watcher_abort.abort();
                self.retired_tasks.push(inflight.abort);
                self.retired_tasks.push(inflight.watcher_abort);
            }
        }
        self.retired_tasks.retain(|task| !task.is_finished());
        self.pending.clear();
        self.retries.clear();
    }

    fn clear_retry(&mut self, id: EntityId) {
        self.retries.remove(&id);
    }

    fn start_write(
        &mut self,
        id: EntityId,
        endpoint: String,
        value: f64,
        writes: &mpsc::Sender<WriteDone>,
    ) {
        self.write_seq += 1;
        let seq = self.write_seq;
        let inflight = self.client.clone().map(|client| {
            let generation = self.generation;
            let writer = tokio::spawn(send_value(
                client,
                endpoint.clone(),
                value,
                generation,
                id,
                seq,
                writes.clone(),
            ));
            let abort = writer.abort_handle();
            // A writer killed without reporting (abort, panic) must still
            // release the lever: the Elixir `:DOWN` handler folds it into
            // `finish_write(:error)`.
            let watcher_tx = writes.clone();
            let watcher = tokio::spawn(async move {
                if writer.await.is_err() {
                    let _ = watcher_tx
                        .send(WriteDone {
                            generation,
                            lever_config_id: id,
                            seq,
                            written: f64::NAN,
                            ok: false,
                        })
                        .await;
                }
            });
            InFlight {
                seq,
                abort,
                watcher_abort: watcher.abort_handle(),
            }
        });
        self.pending.insert(
            id,
            PendingWrite {
                value,
                endpoint,
                inflight,
            },
        );
    }

    fn schedule_retry(&mut self, id: EntityId, clock: &Arc<dyn Clock>) {
        let attempts = self.retries.get(&id).map_or(0, |retry| retry.attempts);
        let Some(delay) = RETRY_DELAYS.get(attempts as usize) else {
            // Budget exhausted: the latest target stays parked until a new
            // input, a reconnect, or a lifecycle event (lever_controller.ex:380-391).
            return;
        };
        if self.client.is_none() {
            // Disconnected: wait for reconnect instead of spawning writers.
            return;
        }
        self.retry_token += 1;
        let token = self.retry_token;
        let deadline = clock.now() + *delay;
        let retry = self.retries.entry(id).or_default();
        retry.attempts = attempts + 1;
        retry.armed = Some((token, deadline));
    }

    /// Fire every armed retry whose deadline passed, mirroring
    /// `handle_info({:retry_write, id, token}, ...)`: only a lever whose
    /// pending write is parked (no in-flight task) restarts.
    fn fire_due_retries(&mut self, now: Instant, writes: &mpsc::Sender<WriteDone>) {
        let due: Vec<EntityId> = self
            .retries
            .iter()
            .filter(|(_, retry)| retry.armed.is_some_and(|(_, deadline)| deadline <= now))
            .map(|(id, _)| *id)
            .collect();
        for id in due {
            // The Elixir retry handler disarms the timer but keeps the
            // attempts counter, so the 200/400/800 ladder advances.
            if let Some(retry) = self.retries.get_mut(&id) {
                retry.armed = None;
            }
            let Some(pending) = self.pending.get(&id) else {
                continue;
            };
            if pending.inflight.is_some() {
                continue;
            }
            let value = pending.value;
            let endpoint = pending.endpoint.clone();
            self.start_write(id, endpoint, value, writes);
        }
    }
}

async fn send_value(
    client: Arc<SimulatorClient>,
    endpoint: String,
    value: f64,
    generation: u64,
    lever_config_id: EntityId,
    seq: u64,
    writes: mpsc::Sender<WriteDone>,
) {
    let ok = client.set(&endpoint, &Value::from(value)).await.is_ok();
    let _ = writes
        .send(WriteDone {
            generation,
            lever_config_id,
            seq,
            written: value,
            ok,
        })
        .await;
}

async fn run(
    clock: Arc<dyn Clock>,
    resolver: Arc<InputResolver>,
    mut commands: mpsc::Receiver<IncomingSample>,
    mut control: mpsc::UnboundedReceiver<Control>,
    mut writes: mpsc::Receiver<WriteDone>,
    writes_tx: mpsc::Sender<WriteDone>,
) {
    let mut state = WorkerState {
        generation: 0,
        active: false,
        bindings: HashMap::new(),
        pending: HashMap::new(),
        retries: HashMap::new(),
        client: None,
        write_seq: 0,
        retry_token: 0,
        lever_ports: HashMap::new(),
        port_generations: HashMap::new(),
        suspended_ports: HashSet::new(),
        observed_inputs: HashMap::new(),
        retired_tasks: Vec::new(),
    };

    loop {
        let retry_deadline = state.next_retry_deadline();
        let retry_sleep = retry_deadline.map(|deadline| {
            let delay = deadline.saturating_duration_since(clock.now());
            clock.sleep(delay)
        });
        tokio::select! {
            biased;
            control = control.recv() => {
                let Some(control) = control else { break };
                match control {
                    Control::Activate { generation, bindings } => {
                        // Activation barrier: obsolete writers die first.
                        state.cancel_pending();
                        state.generation = generation;
                        state.bindings = bindings;
                        state.lever_ports.clear();
                        state.observed_inputs.clear();
                        state.active = true;
                    }
                    Control::Release => {
                        state.cancel_pending();
                        state.bindings.clear();
                        state.lever_ports.clear();
                        state.observed_inputs.clear();
                        state.active = false;
                    }
                    Control::ReleaseAcknowledged(reply) => {
                        state.cancel_pending();
                        state.bindings.clear();
                        state.lever_ports.clear();
                        state.observed_inputs.clear();
                        state.active = false;
                        let settled = tokio::time::timeout(Duration::from_millis(500), async {
                            while state.retired_tasks.iter().any(|task| !task.is_finished()) {
                                tokio::time::sleep(Duration::from_millis(1)).await;
                            }
                        }).await.is_ok();
                        let _ = reply.send(if settled { Ok(()) } else { Err("lever writer cancellation timed out".into()) });
                    }
                    Control::SimulatorConnected(client) => {
                        state.client = Some(client);
                        // Restart parked writers with a fresh retry budget
                        // (lever_controller.ex:185-199).
                        let ids: Vec<EntityId> = state.pending.keys().copied().collect();
                        for id in ids {
                            state.clear_retry(id);
                            if state.pending.get(&id).is_some_and(|p| p.inflight.is_none()) {
                                let value = state.pending[&id].value;
                                let endpoint = state.pending[&id].endpoint.clone();
                                state.start_write(id, endpoint, value, &writes_tx);
                            }
                        }
                    }
                    Control::SimulatorDisconnected => {
                        state.client = None;
                        // cancel_retry_timers/1: timers die, attempts survive.
                        for retry in state.retries.values_mut() {
                            retry.armed = None;
                        }
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
                        let snapshot = LeverStateSnapshot {
                            active: state.active,
                            generation: state.generation,
                            pending: state.pending.len(),
                            inflight: state.pending.values().filter(|p| p.inflight.is_some()).count(),
                            retries: state.retries.len(),
                        };
                        let _ = reply.send(snapshot);
                    }
                    Control::Shutdown => {
                        state.cancel_pending();
                        while state.retired_tasks.iter().any(|task| !task.is_finished()) {
                            tokio::time::sleep(Duration::from_millis(1)).await;
                        }
                        break;
                    }
                }
            }
            command = commands.recv() => {
                let Some(sample) = command else { break };
                apply_input(&mut state, &resolver, sample, &writes_tx, &clock).await;
            }
            done = writes.recv() => {
                let Some(done) = done else { continue };
                finish_write(&mut state, done, &writes_tx, &clock);
            }
            _ = async {
                match retry_sleep {
                    Some(sleep) => sleep.await,
                    None => std::future::pending::<()>().await,
                }
            }, if retry_deadline.is_some() => {
                state.fire_due_retries(clock.now(), &writes_tx);
            }
        }
    }
}

async fn neutralize_port(state: &mut WorkerState, port: &str) -> Result<(), String> {
    let ids: Vec<_> = state
        .lever_ports
        .iter()
        .filter(|(_, source)| source.as_str() == port)
        .map(|(id, _)| *id)
        .collect();
    let mut aborted = Vec::new();
    for id in ids {
        state.lever_ports.remove(&id);
        state.retries.remove(&id);
        if let Some(pending) = state.pending.remove(&id) {
            if let Some(inflight) = pending.inflight {
                inflight.abort.abort();
                inflight.watcher_abort.abort();
                aborted.push(inflight.abort);
                aborted.push(inflight.watcher_abort);
            }
        }
    }
    let settled = tokio::time::timeout(Duration::from_millis(500), async {
        while aborted.iter().any(|task| !task.is_finished()) {
            tokio::time::sleep(Duration::from_millis(1)).await;
        }
    })
    .await
    .is_ok();
    // Keep a timed-out cancellation visible to later
    // shutdown; never acknowledge a stopped worker while
    // one of its children can still run.
    state.retired_tasks.retain(|task| !task.is_finished());
    state.retired_tasks.extend(aborted);
    if settled {
        Ok(())
    } else {
        Err("lever writer cancellation timed out".into())
    }
}

async fn apply_input(
    state: &mut WorkerState,
    resolver: &Arc<InputResolver>,
    incoming: IncomingSample,
    writes: &mpsc::Sender<WriteDone>,
    clock: &Arc<dyn Clock>,
) {
    let sample = incoming.sample;
    // `resolve_simulator_value/4` with no active train: skip.
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
    if incoming.observe_only || state.suspended_ports.contains(&sample.port) {
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
            eprintln!("lever cached-source cleanup failed: {error}");
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
    let Some(binding) = state.bindings.get(&identity.input_id) else {
        return;
    };
    state
        .port_generations
        .insert(sample.port.clone(), sample.port_generation);
    state
        .lever_ports
        .insert(binding.lever_config_id, sample.port.clone());
    // normalize_value/2 (lever_controller.ex:432-445).
    let Some(calibration) = binding.calibration else {
        // {:error, :no_calibration} → :skip
        return;
    };
    let total = total_travel(&calibration);
    if total <= 0 {
        return;
    }
    let normalized = normalize(i32::from(sample.value), &calibration) as f64 / total as f64;
    let Some(normalized) = round_elixir(normalized, 2) else {
        return;
    };
    let Ok(sim_value) = map_input(&binding.mapper, normalized) else {
        return;
    };
    let _ = clock;
    enqueue_value(
        state,
        binding.lever_config_id,
        binding.value_endpoint.clone(),
        sim_value,
        writes,
    );
}

/// `enqueue_value/3` (lever_controller.ex:323-334): while a write is in flight
/// or a retry timer is armed, a newer sample only replaces the pending value.
fn enqueue_value(
    state: &mut WorkerState,
    id: EntityId,
    endpoint: String,
    value: f64,
    writes: &mpsc::Sender<WriteDone>,
) {
    let parked = state
        .pending
        .get(&id)
        .is_some_and(|pending| pending.inflight.is_some())
        || state
            .retries
            .get(&id)
            .is_some_and(|retry| retry.armed.is_some());
    if parked {
        if let Some(pending) = state.pending.get_mut(&id) {
            pending.value = value;
        }
    } else {
        // enqueue_value/3's third clause: start_write(clear_retry(state, id)).
        state.clear_retry(id);
        state.start_write(id, endpoint, value, writes);
    }
}

fn finish_write(
    state: &mut WorkerState,
    done: WriteDone,
    writes: &mpsc::Sender<WriteDone>,
    clock: &Arc<dyn Clock>,
) {
    // A completion from an obsolete activation must not touch live state
    // (review focus: stale request after a train switch).
    if done.generation != state.generation {
        return;
    }
    let Some(pending) = state.pending.get(&done.lever_config_id) else {
        return;
    };
    if pending.inflight.as_ref().map(|inflight| inflight.seq) != Some(done.seq) {
        return;
    }
    if done.ok {
        // Success-only acknowledgement; `latest == written` clears the slot,
        // otherwise the newest target is written immediately (finish_write/3).
        let latest = pending.value;
        let endpoint = pending.endpoint.clone();
        state.clear_retry(done.lever_config_id);
        if latest == done.written {
            state.pending.remove(&done.lever_config_id);
        } else {
            state.start_write(done.lever_config_id, endpoint, latest, writes);
        }
    } else {
        if let Some(pending) = state.pending.get_mut(&done.lever_config_id) {
            pending.inflight = None;
        }
        state.schedule_retry(done.lever_config_id, clock);
    }
}
