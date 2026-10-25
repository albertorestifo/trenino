//! Sequence execution: the `execute_sequence_commands/3` half of
//! `Trenino.Train.ButtonController` (lib/trenino/train/button_controller.ex).
//!
//! The Elixir controller spawns one process per sequence run that monitors the
//! controller, sends each ordered command (`SimulatorClient.set/3`), waits
//! `delay_ms` after it, continues past per-command failures, never replays a
//! partly executed sequence, and reports `{:sequence_complete, element_id}` at
//! the end. Killing the process (`Process.exit(task, :kill)` on release, train
//! change or reload) cancels the run at any await point, and the controller
//! ignores completions for elements no longer active.
//!
//! This module keeps only the executor; edge deduplication and momentary
//! repeats stay with the button controller.

use std::sync::Arc;
use std::time::Duration;
use std::{future::Future, pin::Pin};

use tokio::sync::{mpsc, watch};
use tokio::task::JoinHandle;

use trenino_core::train::buttons::{ordered_sequence, SequenceCommand};

use crate::simulator::services::clock::Clock;

/// Outcome of one command send, mirroring `send_to_simulator/2` and the
/// "Simulator not connected for sequence" branch of
/// `execute_sequence_loop/4`: every outcome continues the sequence.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SequenceSendOutcome {
    Sent,
    /// Connected, but `SimulatorClient.set/3` failed (logged and skipped).
    Failed(String),
    /// No connected simulator client (logged and skipped).
    Disconnected,
}

/// Seam over `SimulatorConnection.get_status/0` + `SimulatorClient.set/3`.
pub trait SequenceSimulator: Send + Sync + 'static {
    /// Existing synchronous test and simple adapter surface.
    fn set(&self, _endpoint: &str, _value: f64) -> SequenceSendOutcome {
        SequenceSendOutcome::Disconnected
    }

    /// Live HTTP implementations override this to await the request. The
    /// default retains the synchronous seam for existing callers and fakes.
    fn set_async<'a>(
        &'a self,
        endpoint: &'a str,
        value: f64,
    ) -> Pin<Box<dyn Future<Output = SequenceSendOutcome> + Send + 'a>> {
        Box::pin(async move { self.set(endpoint, value) })
    }
}

/// Messages a finished run reports to its owner. `Complete` mirrors
/// `{:sequence_complete, element_id}`; receivers must ignore it when the
/// element/run is no longer active (stale completions), exactly like
/// `ButtonController.handle_info({:sequence_complete, element_id}, state)`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SequenceEvent {
    Complete { element_id: i64, run: u64 },
}

/// Spawns and tracks sequence runs (the Elixir `spawn` + tracked pid pair).
pub struct SequenceExecutor {
    simulator: Arc<dyn SequenceSimulator>,
    clock: Arc<dyn Clock>,
    next_run: std::sync::atomic::AtomicU64,
}

/// One live execution. `abort()` is `Process.exit(task, :kill)`; dropping the
/// handle does not stop the run, just like the unmonitored pid in state.
#[derive(Debug)]
pub struct SequenceRun {
    pub run: u64,
    pub element_id: i64,
    task: JoinHandle<()>,
}

impl SequenceRun {
    pub fn abort(&self) {
        self.task.abort();
    }

    pub fn is_finished(&self) -> bool {
        self.task.is_finished()
    }
}

impl SequenceExecutor {
    pub fn new(simulator: Arc<dyn SequenceSimulator>, clock: Arc<dyn Clock>) -> Self {
        Self {
            simulator,
            clock,
            next_run: std::sync::atomic::AtomicU64::new(0),
        }
    }

    /// Start one run. `owner` is the liveness monitor: dropping every
    /// `watch::Sender` halves (the controller dying) cancels the run the same
    /// way `Process.monitor/1` delivers `:DOWN` in
    /// `execute_sequence_loop/4`. Commands are ordered by position like the
    /// `preload_order: [asc: :position]` preload.
    pub fn start(
        &self,
        element_id: i64,
        commands: Vec<SequenceCommand>,
        owner: watch::Receiver<()>,
        events: mpsc::UnboundedSender<SequenceEvent>,
    ) -> SequenceRun {
        let run = self
            .next_run
            .fetch_add(1, std::sync::atomic::Ordering::SeqCst);
        let simulator = Arc::clone(&self.simulator);
        let clock = Arc::clone(&self.clock);
        let ordered = ordered_sequence(&commands);
        let task = tokio::spawn(async move {
            execute(ordered, simulator, clock, owner, events, element_id, run).await;
        });
        SequenceRun {
            run,
            element_id,
            task,
        }
    }
}

async fn execute(
    commands: Vec<SequenceCommand>,
    simulator: Arc<dyn SequenceSimulator>,
    clock: Arc<dyn Clock>,
    mut owner: watch::Receiver<()>,
    events: mpsc::UnboundedSender<SequenceEvent>,
    element_id: i64,
    run: u64,
) {
    for command in commands {
        // Controller-death check before each send (`receive ... after 0`):
        // non-blocking; a live owner never resolves the monitor. `has_changed`
        // only fails when every sender half is gone (the owner never sends),
        // which is the controller-death signal.
        if owner.has_changed().is_err() {
            return;
        }
        let send = simulator.set_async(&command.endpoint, command.value);
        tokio::pin!(send);
        loop {
            tokio::select! {
                _outcome = &mut send => break,
                changed = owner.changed() => {
                    if changed.is_err() { return; }
                }
            }
        }

        if command.delay_ms > 0 {
            let delay = clock.sleep(Duration::from_millis(command.delay_ms));
            tokio::select! {
                () = delay => {}
                // Controller death during the wait (`receive {:DOWN, ...}`
                // after delay_ms); a value change never happens because the
                // owner only keeps the channel alive, it never sends.
                changed = owner.changed() => {
                    if changed.is_err() {
                        return;
                    }
                }
            }
        }
    }
    // `send(controller_pid, {:sequence_complete, element_id})`: a dead owner
    // simply drops the message.
    let _ = events.send(SequenceEvent::Complete { element_id, run });
}
