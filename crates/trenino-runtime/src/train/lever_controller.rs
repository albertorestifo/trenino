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

use std::collections::HashMap;
use std::sync::Arc;
use std::time::{Duration, Instant};

use serde_json::Value;
use tokio::sync::{mpsc, oneshot};
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
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum QueueError {
    Overflow,
    Closed,
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
    SimulatorConnected(Arc<SimulatorClient>),
    SimulatorDisconnected,
    State(oneshot::Sender<LeverStateSnapshot>),
    Shutdown(oneshot::Sender<()>),
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
    commands: mpsc::Sender<LeverSample>,
    control: mpsc::UnboundedSender<Control>,
}

impl LeverController {
    pub fn start(clock: Arc<dyn Clock>, resolver: Arc<InputResolver>) -> Self {
        let (commands, command_rx) = mpsc::channel(COMMAND_CAPACITY);
        let (control, control_rx) = mpsc::unbounded_channel();
        let (writes, writes_rx) = mpsc::channel(WRITE_CAPACITY);
        tokio::spawn(run(clock, resolver, command_rx, control_rx, writes_rx, writes));
        Self { commands, control }
    }

    /// Load bindings for a new activation. Cancels every in-flight writer and
    /// scheduled retry of the previous activation first (the activation
    /// barrier; Elixir `load_bindings_for_train/2` → `cancel_pending/1`).
    pub fn activate(
        &self,
        generation: u64,
        snapshot: &TrainConfigSnapshot,
    ) -> Result<(), QueueError> {
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
            .send(Control::Activate { generation, bindings })
            .map_err(|_| QueueError::Closed)
    }

    /// Stop driving any lever (train deactivated or switched).
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

    /// Queue an input sample, waiting while the bounded queue is full.
    pub async fn input(&self, sample: LeverSample) -> Result<(), QueueError> {
        self.commands.send(sample).await.map_err(|_| QueueError::Closed)
    }

    /// Non-blocking ingress: reports [`QueueError::Overflow`] instead of
    /// silently dropping the sample.
    pub fn try_input(&self, sample: LeverSample) -> Result<(), QueueError> {
        self.commands.try_send(sample).map_err(|error| match error {
            mpsc::error::TrySendError::Full(_) => QueueError::Overflow,
            mpsc::error::TrySendError::Closed(_) => QueueError::Closed,
        })
    }

    pub async fn state(&self) -> Result<LeverStateSnapshot, QueueError> {
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
    active: bool,
    bindings: HashMap<EntityId, BindingRuntime>,
    pending: HashMap<EntityId, PendingWrite>,
    retries: HashMap<EntityId, RetryState>,
    client: Option<Arc<SimulatorClient>>,
    write_seq: u64,
    retry_token: u64,
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
            }
        }
        self.pending.clear();
        self.retries.clear();
    }

    fn clear_retry(&mut self, id: EntityId) {
        self.retries.remove(&id);
    }

    fn start_write(&mut self, id: EntityId, endpoint: String, value: f64, writes: &mpsc::Sender<WriteDone>) {
        self.write_seq += 1;
        let seq = self.write_seq;
        let inflight = self.client.clone().map(|client| {
            let generation = self.generation;
            let writer =
                tokio::spawn(send_value(client, endpoint.clone(), value, generation, id, seq, writes.clone()));
            let abort = writer.abort_handle();
            // A writer killed without reporting (abort, panic) must still
            // release the lever: the Elixir `:DOWN` handler folds it into
            // `finish_write(:error)`.
            let watcher_tx = writes.clone();
            tokio::spawn(async move {
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
            InFlight { seq, abort }
        });
        self.pending.insert(id, PendingWrite { value, endpoint, inflight });
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
    mut commands: mpsc::Receiver<LeverSample>,
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
                        state.active = true;
                    }
                    Control::Release => {
                        state.cancel_pending();
                        state.bindings.clear();
                        state.active = false;
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
                    Control::Shutdown(reply) => {
                        state.cancel_pending();
                        let _ = reply.send(());
                        break;
                    }
                }
            }
            command = commands.recv() => {
                let Some(sample) = command else { break };
                apply_input(&mut state, &resolver, sample, &writes_tx, &clock);
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

fn apply_input(
    state: &mut WorkerState,
    resolver: &Arc<InputResolver>,
    sample: LeverSample,
    writes: &mpsc::Sender<WriteDone>,
    clock: &Arc<dyn Clock>,
) {
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
    let Some(binding) = state.bindings.get(&identity.input_id) else {
        return;
    };
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
