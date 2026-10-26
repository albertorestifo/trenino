//! Train activation coordinator.
//!
//! Owns the wave-1 detection monitor ([`TrainDetection`] wraps
//! `TrainDetectionMonitor`'s exact 5s/30s/200ms semantics), snapshots the
//! active train's full routing-relevant configuration once per activation at
//! the committed DB revision ([`TrainConfigSource::snapshot`]), and drives the
//! shared [`RoutingService`]: activation commits a desired TSW routing and
//! reconciles, so release-before-activate ordering and degraded states come
//! from the routing service, not from the controllers.
//!
//! Mirrors `Trenino.Train.Detection` + the controllers' activation halves:
//! a unique identifier match activates, `not_found` deactivates, an ambiguous
//! match deactivates (never picks the longest prefix), and manual [`sync`]
//! after CRUD re-detects with a cleared identifier and reloads the committed
//! configuration (detection.ex:137-147).
//!
//! ## Integration contract (for the AppServices track)
//!
//! - Construct with `TrainService::start(clock, source, routing, resolver,
//!   keystrokes)`; `resolver` must be the same `InputResolver` instance held
//!   by the routing service, `source` typically `DbTrainConfigSource`.
//! - Forward simulator connection changes through
//!   [`simulator_connected`] / [`simulator_disconnected`].
//! - Call [`sync`] after any train/binding/sequence/script CRUD commit.
//! - Read [`TrainServiceHandle::snapshot`] for UI state; consume the returned
//!   [`TrainEvent`] receiver for `train:detection`-equivalent events plus
//!   `button_state_changed` broadcasts.

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use trenino_core::{EntityId, Revision};

use crate::routing::reconcile::{
    DegradedReason, DesiredRouting, DestinationId, DestinationPlan, InputRoute, RouteTarget,
    RoutingError, RoutingService,
};
use crate::routing::{InputIdentity, InputResolver};
use crate::simulator::client::SimulatorClient;
use crate::simulator::services::clock::Clock;
use crate::simulator::services::train_detection::{MonitorError, TrainDetectionEvent};
use crate::storage::bindings::ButtonMode;

use super::button_controller::{ButtonController, ButtonKeystrokes, ButtonStateChange, QueueError};
use super::detection::{TrainConfigError, TrainConfigSnapshot, TrainConfigSource, TrainDetection};
use super::lever_controller::LeverController;
use crate::routing::reconcile::{ActivationContext, RoutingDestination};

/// UI-facing state of the train service (plan: `TrainSnapshot` carries
/// generation, active id, detected identifier, ambiguity candidates and the
/// committed binding revision).
#[derive(Clone, Debug, PartialEq)]
pub struct TrainSnapshot {
    pub generation: u64,
    pub active_train_id: Option<EntityId>,
    pub detected_identifier: Option<String>,
    pub ambiguous_candidates: Vec<EntityId>,
    /// Committed desired routing revision, if any.
    pub desired_revision: Option<Revision>,
    /// Fully acknowledged active routing revision.
    pub active_revision: Option<Revision>,
}

/// Events on the `"train:detection"` topic plus routing degradation and the
/// `"train:button_values"` broadcasts.
#[derive(Clone, Debug, PartialEq)]
pub enum TrainEvent {
    TrainDetected {
        identifier: String,
        train_id: Option<EntityId>,
    },
    TrainChanged(Option<EntityId>),
    MultipleTrainsMatch {
        identifier: String,
        trains: Vec<EntityId>,
    },
    DetectionError(String),
    RoutingDegraded(DegradedReason),
    ButtonStateChanged(ButtonStateChange),
}

/// Successful manual activation ("Set Active"): the generation committed by
/// this activation and the resulting desired routing revision.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ManualActivation {
    pub train_id: EntityId,
    pub generation: u64,
    pub desired_revision: Option<Revision>,
}

/// Manual activation failures: the service is shutting down, or the train
/// configuration could not be read (unknown train, storage error).
#[derive(Clone, Debug, PartialEq)]
pub enum ManualActivationError {
    Closed,
    Train(TrainConfigError),
}

impl std::fmt::Display for ManualActivationError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Closed => write!(f, "train service is shutting down"),
            Self::Train(error) => write!(f, "{error}"),
        }
    }
}

impl std::error::Error for ManualActivationError {}

impl From<QueueError> for ManualActivationError {
    fn from(error: QueueError) -> Self {
        match error {
            QueueError::Closed => Self::Closed,
            _ => Self::Train(TrainConfigError::Storage(format!("{error:?}"))),
        }
    }
}

impl From<TrainConfigError> for ManualActivationError {
    fn from(error: TrainConfigError) -> Self {
        Self::Train(error)
    }
}

struct ServiceState {
    generation: u64,
    last_revision: Option<Revision>,
    last_db_revision: u64,
    active_train_id: Option<EntityId>,
    detected_identifier: Option<String>,
    ambiguous: Vec<EntityId>,
    /// Set when the simulator connection drops (disconnect/grace entry),
    /// cleared by the next successful detection. A standalone TrainChanged
    /// (grace expiry, disconnect) maps to Elixir `deactivate_train/1`, which
    /// clears the identifier; an identifier-driven TrainChanged keeps it.
    connection_lost: bool,
}

impl ServiceState {
    /// The routing service requires strictly increasing revisions; the DB
    /// topic sum is the base, and a bump past the last commit covers events
    /// (like deactivation) that do not touch the database.
    fn next_revision(&mut self, db_revision: u64) -> Revision {
        let candidate = Revision(db_revision.max(self.last_revision.map_or(0, |last| last.0 + 1)));
        self.last_revision = Some(candidate);
        candidate
    }
}

/// Pending activation handed to the TSW destination driver. Set at commit
/// time (with the desired routing), consumed by `activate` after the release
/// barrier, fenced by the service generation.
struct PendingActivation {
    generation: u64,
    train_id: EntityId,
    snapshot: TrainConfigSnapshot,
}

/// The TSW routing destination: releases cancel the lever/button controllers
/// (activation barrier, obsolete writers die first), activations load the
/// frozen snapshot into them.
///
/// The routing service *carries* a destination whose plan is unchanged
/// across revisions — two trains can legitimately route identical inputs to
/// identical endpoints while their controller configuration (bindings,
/// sequences, dedup state) still differs. The pump therefore applies the
/// pending activation directly whenever reconciliation did not (applied
/// generation fence), but only after a successful reconcile: a failed release
/// barrier must never be followed by activation.
struct TswDestination {
    lever: LeverController,
    buttons: ButtonController,
    pending: Mutex<Option<PendingActivation>>,
    applied: Mutex<u64>,
}

impl TswDestination {
    fn set_pending(&self, activation: Option<PendingActivation>) {
        *self.pending.lock().expect("tsw destination poisoned") = activation;
    }

    fn applied_generation(&self) -> u64 {
        *self.applied.lock().expect("tsw destination poisoned")
    }

    /// Release barrier: stop the controllers and forget the applied
    /// generation, but KEEP the pending activation. `commit_and_reconcile`
    /// arms the pending snapshot *before* `reconcile()` runs, and the routing
    /// service's release-then-activate ordering calls this `release` first —
    /// wiping the pending here would make every plan-changing re-activation
    /// (manual sync after CRUD, train switch) fail with "no pending
    /// activation snapshot". Deactivation disarms pending explicitly through
    /// `set_pending(None)` instead.
    fn release_controllers(&self) -> Result<(), String> {
        self.lever.release_acknowledged()?;
        self.buttons.release_acknowledged()?;
        *self.applied.lock().expect("tsw destination poisoned") = 0;
        Ok(())
    }

    fn activate_controllers(&self) -> Result<(), String> {
        let pending = self
            .pending
            .lock()
            .expect("tsw destination poisoned")
            .take()
            .ok_or_else(|| "no pending activation snapshot".to_owned())?;
        self.lever
            .activate(pending.generation, &pending.snapshot)
            .map_err(|_| "lever controller closed".to_owned())?;
        self.buttons
            .activate(pending.generation, pending.train_id, &pending.snapshot)
            .map_err(|_| "button controller closed".to_owned())?;
        *self.applied.lock().expect("tsw destination poisoned") = pending.generation;
        Ok(())
    }
}

impl RoutingDestination for TswDestination {
    fn release(&self) -> Result<(), String> {
        self.release_controllers()
    }

    fn activate(
        &self,
        _context: &ActivationContext,
        _plan: &DestinationPlan,
    ) -> Result<(), String> {
        self.activate_controllers()
    }
}

/// Handle to the train service: detection, activation and the lever/button
/// controllers. Dropping without `shutdown` stops the workers when all clones
/// are gone.
#[derive(Clone)]
pub struct TrainServiceHandle {
    detection: Arc<TrainDetectionShared>,
    lever: LeverController,
    buttons: ButtonController,
    source: Arc<dyn TrainConfigSource>,
    routing: Arc<RoutingService>,
    destination: Arc<TswDestination>,
    state: Arc<Mutex<ServiceState>>,
    events: tokio::sync::mpsc::Sender<TrainEvent>,
    lifecycle: Arc<ServiceLifecycle>,
}

const SHUTDOWN_TIMEOUT: Duration = Duration::from_secs(1);

struct ServiceLifecycle {
    stopping: AtomicBool,
    shutdown: tokio::sync::Mutex<ServiceShutdownState>,
}

struct ServiceShutdownState {
    detection_pump: Option<tokio::task::JoinHandle<()>>,
    button_forwarding: Option<tokio::task::JoinHandle<()>>,
    routing_release: Option<tokio::task::JoinHandle<Result<(), RoutingError>>>,
    routing_released: bool,
    finished: bool,
}

/// Shared detection commands (the monitor handle is behind an `Arc` so callers
/// can clone it out of the lock and never hold the guard across an await).
struct TrainDetectionShared {
    monitor: Mutex<Option<Arc<super::detection::TrainDetection>>>,
}

impl TrainServiceHandle {
    /// Start the coordinator. `resolver` must be the same instance the
    /// routing service was built with; the service registers itself as the
    /// TSW destination driver.
    pub fn start(
        clock: Arc<dyn Clock>,
        source: Arc<dyn TrainConfigSource>,
        routing: Arc<RoutingService>,
        resolver: Arc<InputResolver>,
        keystrokes: Arc<dyn ButtonKeystrokes>,
    ) -> (Self, tokio::sync::mpsc::Receiver<TrainEvent>) {
        let (detection, detection_events) = TrainDetection::start(clock.clone(), source.clone());
        let lever = LeverController::start(clock.clone(), resolver.clone());
        let (buttons, button_broadcast) = ButtonController::start(clock, resolver, keystrokes);
        let destination = Arc::new(TswDestination {
            lever: lever.clone(),
            buttons: buttons.clone(),
            pending: Mutex::new(None),
            applied: Mutex::new(0),
        });
        routing.register_destination(DestinationId::Tsw, destination.clone());

        let (events, events_rx) = tokio::sync::mpsc::channel(256);
        let state = Arc::new(Mutex::new(ServiceState {
            generation: 0,
            last_revision: None,
            last_db_revision: 0,
            active_train_id: None,
            detected_identifier: None,
            ambiguous: Vec::new(),
            connection_lost: false,
        }));
        let detection_pump = tokio::spawn(pump(
            source.clone(),
            routing.clone(),
            destination.clone(),
            state.clone(),
            events.clone(),
            detection_events,
        ));
        // Merge the button broadcasts into the event stream (PubSub drop).
        let button_forwarding = {
            let events = events.clone();
            tokio::spawn(async move {
                let mut button_broadcast = button_broadcast;
                while let Some(change) = button_broadcast.recv().await {
                    let _ = events.try_send(TrainEvent::ButtonStateChanged(change));
                }
            })
        };

        (
            Self {
                detection: Arc::new(TrainDetectionShared {
                    monitor: Mutex::new(Some(Arc::new(detection))),
                }),
                lever,
                buttons,
                source,
                routing,
                destination,
                state,
                events,
                lifecycle: Arc::new(ServiceLifecycle {
                    stopping: AtomicBool::new(false),
                    shutdown: tokio::sync::Mutex::new(ServiceShutdownState {
                        detection_pump: Some(detection_pump),
                        button_forwarding: Some(button_forwarding),
                        routing_release: None,
                        routing_released: false,
                        finished: false,
                    }),
                }),
            },
            events_rx,
        )
    }

    pub fn lever(&self) -> &LeverController {
        &self.lever
    }

    /// Manual activation ("Set Active"): records the desired revision and
    /// triggers the same reconcile the detector uses — the generation fences
    /// in the routing service and TSW destination are never bypassed.
    /// Fails when the train does not exist.
    pub async fn activate_train(
        &self,
        train_id: EntityId,
    ) -> Result<ManualActivation, ManualActivationError> {
        self.ensure_open()?;
        let snapshot = snapshot_train(&self.source, train_id).await?;
        commit_and_reconcile(
            &self.routing,
            &self.destination,
            &self.state,
            &self.events,
            train_id,
            snapshot,
        )
        .await;
        let (generation, desired_revision) = {
            let state = self.state.lock().expect("train service poisoned");
            (state.generation, self.routing.desired_revision())
        };
        Ok(ManualActivation {
            train_id,
            generation,
            desired_revision,
        })
    }
    pub fn buttons(&self) -> &ButtonController {
        &self.buttons
    }

    fn ensure_open(&self) -> Result<(), QueueError> {
        if self.lifecycle.stopping.load(Ordering::Acquire) {
            Err(QueueError::Closed)
        } else {
            Ok(())
        }
    }

    /// Forward a simulator connection: the detection monitor (grace handling)
    /// and both controllers see it.
    pub async fn simulator_connected(
        &self,
        client: Arc<SimulatorClient>,
    ) -> Result<(), QueueError> {
        self.ensure_open()?;
        self.state
            .lock()
            .expect("train service poisoned")
            .connection_lost = false;
        // Clone the handle out of the lock so the guard is dropped before
        // awaiting (clippy::await_holding_lock); ordering is unchanged.
        let detection = self
            .detection
            .monitor
            .lock()
            .expect("detection poisoned")
            .clone();
        if let Some(detection) = detection.as_ref() {
            detection
                .connected(client.clone())
                .await
                .map_err(|_| QueueError::Closed)?;
        }
        self.lever
            .simulator_connected(client.clone())
            .map_err(|_| QueueError::Closed)?;
        self.buttons.simulator_connected(client)
    }

    pub async fn simulator_disconnected(&self) -> Result<(), QueueError> {
        self.ensure_open()?;
        self.state
            .lock()
            .expect("train service poisoned")
            .connection_lost = true;
        // Same lock-scoping as `simulator_connected`: clone before awaiting.
        let detection = self
            .detection
            .monitor
            .lock()
            .expect("detection poisoned")
            .clone();
        if let Some(detection) = detection.as_ref() {
            detection
                .disconnected()
                .await
                .map_err(|_| QueueError::Closed)?;
        }
        self.lever
            .simulator_disconnected()
            .map_err(|_| QueueError::Closed)?;
        self.buttons.simulator_disconnected()
    }

    /// Manual sync after CRUD: forces full re-detection (cleared identifier)
    /// and reloads the committed configuration when it changed.
    pub async fn sync(&self) -> Result<(), QueueError> {
        self.ensure_open()?;
        // Clone before awaiting (clippy::await_holding_lock).
        let detection = self
            .detection
            .monitor
            .lock()
            .expect("detection poisoned")
            .clone();
        match detection.as_ref() {
            Some(detection) => detection.sync().await.map_err(|_| QueueError::Closed),
            None => Err(QueueError::Closed),
        }
    }

    pub fn snapshot(&self) -> TrainSnapshot {
        let state = self.state.lock().expect("train service poisoned");
        let routing = self.routing.snapshot();
        TrainSnapshot {
            generation: state.generation,
            active_train_id: state.active_train_id,
            detected_identifier: state.detected_identifier.clone(),
            ambiguous_candidates: state.ambiguous.clone(),
            desired_revision: routing.desired_revision,
            active_revision: routing.active_revision,
        }
    }

    /// Shutdown order (plan §Shutdown): stop detection admission, release the
    /// controllers (held keystrokes and in-flight writers die while the
    /// adapters are alive), then shut the workers down.
    pub async fn shutdown(&self) -> Result<(), QueueError> {
        self.lifecycle.stopping.store(true, Ordering::Release);
        self.lever.begin_shutdown();
        self.buttons.begin_shutdown();
        // The mutex serializes shutdown across clones and preserves every
        // unfinished join handle if a bounded attempt times out.
        let mut progress = self.lifecycle.shutdown.lock().await;
        if progress.finished {
            return Ok(());
        }
        if let Some(task) = progress.detection_pump.as_ref() {
            task.abort();
        }
        if let Some(task) = progress.button_forwarding.as_ref() {
            task.abort();
        }
        let detection = self
            .detection
            .monitor
            .lock()
            .expect("detection poisoned")
            .clone();
        let stop_detection = async {
            if let Some(detection) = detection {
                detection.shutdown().await.map_err(|error| match error {
                    MonitorError::Timeout => QueueError::Timeout,
                    MonitorError::Closed => QueueError::Closed,
                })
            } else {
                Ok(())
            }
        };
        // Stop the producers before committing a no-TSW routing revision.
        // Controller admission is already closed, but their release command
        // remains available until the routing release barrier acknowledges.
        let ServiceShutdownState {
            detection_pump,
            button_forwarding,
            ..
        } = &mut *progress;
        let (pump, forwarding, detection) = tokio::join!(
            join_cancelled(detection_pump),
            join_cancelled(button_forwarding),
            stop_detection,
        );
        let mut first_error = None;
        for result in [pump, forwarding, detection] {
            if let Err(error) = result {
                first_error.get_or_insert(error);
            }
        }
        if let Some(error) = first_error {
            return Err(error);
        }

        release_tsw_route(&mut progress, &self.routing, &self.destination, &self.state).await?;
        // The destination release callback has acknowledged cancellation of
        // writers/sequences and keys. Now join the controller workers.
        let (lever, buttons) = tokio::join!(self.lever.shutdown(), self.buttons.shutdown());
        if let Err(error) = lever.map_err(|error| match error {
            super::lever_controller::QueueError::Timeout => QueueError::Timeout,
            _ => QueueError::Closed,
        }) {
            first_error.get_or_insert(error);
        }
        if let Err(error) = buttons {
            first_error.get_or_insert(error);
        }
        if let Some(error) = first_error {
            return Err(error);
        }
        let mut state = self.state.lock().expect("train service poisoned");
        state.generation += 1;
        state.active_train_id = None;
        state.detected_identifier = None;
        state.ambiguous.clear();
        state.last_revision = self.routing.desired_revision();
        progress.finished = true;
        Ok(())
    }
}

async fn release_tsw_route(
    progress: &mut ServiceShutdownState,
    routing: &Arc<RoutingService>,
    destination: &Arc<TswDestination>,
    service_state: &Arc<Mutex<ServiceState>>,
) -> Result<(), QueueError> {
    if progress.routing_released {
        return Ok(());
    }
    if progress.routing_release.is_none() {
        destination.set_pending(None);
        let last_service_revision = service_state
            .lock()
            .expect("train service poisoned")
            .last_revision
            .map_or(0, |revision| revision.0);
        let revision = Revision(
            routing
                .desired_revision()
                .map_or(0, |revision| revision.0)
                .max(last_service_revision)
                + 1,
        );
        let routing = routing.clone();
        progress.routing_release = Some(tokio::task::spawn_blocking(move || {
            routing.deactivate_destination(DestinationId::Tsw, revision)
        }));
    }
    let handle = progress
        .routing_release
        .as_mut()
        .expect("route task inserted");
    let result = tokio::time::timeout(SHUTDOWN_TIMEOUT, handle)
        .await
        .map_err(|_| QueueError::Timeout)?
        .map_err(|_| QueueError::Closed)?;
    progress.routing_release = None;
    match result {
        Ok(()) => {
            progress.routing_released = true;
            Ok(())
        }
        Err(RoutingError::ReleaseFailed { error, .. }) if error.contains("timed out") => {
            // A previous attempt may finish just after its caller timed out.
            // This attempt still reports timeout; the next retries the
            // retained routing intent and physical release.
            Err(QueueError::Timeout)
        }
        Err(_) => Err(QueueError::Closed),
    }
}

async fn join_cancelled(task: &mut Option<tokio::task::JoinHandle<()>>) -> Result<(), QueueError> {
    let Some(handle) = task.as_mut() else {
        return Ok(());
    };
    let joined = tokio::time::timeout(SHUTDOWN_TIMEOUT, handle)
        .await
        .map_err(|_| QueueError::Timeout)?;
    if let Err(error) = joined {
        if !error.is_cancelled() {
            return Err(QueueError::Closed);
        }
    }
    *task = None;
    Ok(())
}

/// Detection pump: forwards the monitor's detection events and drives the
/// routing revisions for train activation/deactivation.
async fn pump(
    source: Arc<dyn TrainConfigSource>,
    routing: Arc<RoutingService>,
    destination: Arc<TswDestination>,
    state: Arc<Mutex<ServiceState>>,
    events: tokio::sync::mpsc::Sender<TrainEvent>,
    mut detection_events: tokio::sync::mpsc::Receiver<TrainDetectionEvent>,
) {
    while let Some(event) = detection_events.recv().await {
        match event {
            TrainDetectionEvent::TrainDetected { identifier, train } => {
                state
                    .lock()
                    .expect("train service poisoned")
                    .connection_lost = false;
                let train_id = train.as_ref().map(|profile| EntityId(profile.id));
                {
                    let mut state = state.lock().expect("train service poisoned");
                    state.detected_identifier = Some(identifier.clone());
                    if train_id.is_some() {
                        state.ambiguous.clear();
                    }
                }
                let _ = events
                    .send(TrainEvent::TrainDetected {
                        identifier,
                        train_id,
                    })
                    .await;
                // Manual sync after CRUD: the identifier was cleared, the same
                // train re-matched, and the committed configuration moved —
                // reload the controllers at the new revision (TrainChanged
                // fires only when the train itself changed).
                let same_active = state
                    .lock()
                    .expect("train service poisoned")
                    .active_train_id
                    == train_id;
                if same_active {
                    if let Some(id) = train_id {
                        reactivate_if_moved(&source, &routing, &destination, &state, &events, id)
                            .await;
                    }
                }
            }
            TrainDetectionEvent::TrainChanged(train) => {
                let train_id = train.as_ref().map(|profile| EntityId(profile.id));
                let _ = events.send(TrainEvent::TrainChanged(train_id)).await;
                match train {
                    Some(profile) => {
                        activate(
                            &source,
                            &routing,
                            &destination,
                            &state,
                            &events,
                            EntityId(profile.id),
                        )
                        .await;
                    }
                    None => {
                        // Identifier-driven deactivations (not_found,
                        // ambiguity) keep the fresh identifier; standalone
                        // deactivations (disconnect, grace expiry) clear it.
                        let connection_lost = state
                            .lock()
                            .expect("train service poisoned")
                            .connection_lost;
                        deactivate(&routing, &destination, &state, &events, connection_lost).await;
                    }
                }
            }
            TrainDetectionEvent::MultipleTrainsMatch { identifier, trains } => {
                {
                    let mut state = state.lock().expect("train service poisoned");
                    state.ambiguous = trains.iter().map(|train| EntityId(train.id)).collect();
                }
                let _ = events
                    .send(TrainEvent::MultipleTrainsMatch {
                        identifier,
                        trains: trains.iter().map(|train| EntityId(train.id)).collect(),
                    })
                    .await;
            }
            TrainDetectionEvent::DetectionError(error) => {
                let _ = events
                    .send(TrainEvent::DetectionError(error.to_string()))
                    .await;
            }
        }
    }
}

/// Build the declarative TSW routing plan from the snapshot: lever value
/// endpoints plus button endpoints (simple/momentary; sequences and
/// keystrokes are dynamic targets driven by the controllers themselves).
fn tsw_plan(snapshot: &TrainConfigSnapshot) -> DestinationPlan {
    let mut routes = Vec::new();
    for binding in &snapshot.lever_bindings {
        if let Some(device_id) = binding.input_device {
            routes.push(InputRoute {
                input: InputIdentity {
                    device_id,
                    input_id: binding.input_id,
                },
                target: RouteTarget::TswEndpoint(binding.value_endpoint.clone()),
            });
        }
    }
    for binding in &snapshot.button_bindings {
        let dynamic = matches!(binding.mode, ButtonMode::Sequence | ButtonMode::Keystroke);
        if let (Some(device_id), Some(endpoint)) = (binding.input_device, binding.endpoint.clone())
        {
            if !dynamic {
                routes.push(InputRoute {
                    input: InputIdentity {
                        device_id,
                        input_id: binding.input_id,
                    },
                    target: RouteTarget::TswEndpoint(endpoint),
                });
            }
        }
    }
    DestinationPlan {
        destination: DestinationId::Tsw,
        routes,
    }
}

async fn snapshot_train(
    source: &Arc<dyn TrainConfigSource>,
    train_id: EntityId,
) -> Result<TrainConfigSnapshot, TrainConfigError> {
    let source = source.clone();
    tokio::task::spawn_blocking(move || source.snapshot(train_id))
        .await
        .map_err(|join| TrainConfigError::Storage(join.to_string()))?
}

/// Activate a newly detected train: snapshot once at the committed revision,
/// commit the desired routing, then reconcile. The release barrier stops the
/// old controllers before the new snapshot loads.
async fn activate(
    source: &Arc<dyn TrainConfigSource>,
    routing: &Arc<RoutingService>,
    destination: &Arc<TswDestination>,
    state: &Arc<Mutex<ServiceState>>,
    events: &tokio::sync::mpsc::Sender<TrainEvent>,
    train_id: EntityId,
) {
    let snapshot = match snapshot_train(source, train_id).await {
        Ok(snapshot) => snapshot,
        Err(error) => {
            let _ = events
                .send(TrainEvent::DetectionError(error.to_string()))
                .await;
            return;
        }
    };
    commit_and_reconcile(routing, destination, state, events, train_id, snapshot).await;
}

/// Manual-sync reload for the still-active train: only when the committed
/// configuration actually moved (Elixir pairs `Detection.sync()` with the
/// controllers' `reload_bindings` after CRUD).
async fn reactivate_if_moved(
    source: &Arc<dyn TrainConfigSource>,
    routing: &Arc<RoutingService>,
    destination: &Arc<TswDestination>,
    state: &Arc<Mutex<ServiceState>>,
    events: &tokio::sync::mpsc::Sender<TrainEvent>,
    train_id: EntityId,
) {
    let snapshot = match snapshot_train(source, train_id).await {
        Ok(snapshot) => snapshot,
        Err(error) => {
            let _ = events
                .send(TrainEvent::DetectionError(error.to_string()))
                .await;
            return;
        }
    };
    let moved = snapshot.revision.0
        > state
            .lock()
            .expect("train service poisoned")
            .last_db_revision;
    if moved {
        commit_and_reconcile(routing, destination, state, events, train_id, snapshot).await;
    }
}

async fn commit_and_reconcile(
    routing: &Arc<RoutingService>,
    destination: &Arc<TswDestination>,
    state: &Arc<Mutex<ServiceState>>,
    events: &tokio::sync::mpsc::Sender<TrainEvent>,
    train_id: EntityId,
    snapshot: TrainConfigSnapshot,
) {
    let (revision, generation) = {
        let mut state = state.lock().expect("train service poisoned");
        state.generation += 1;
        let revision = state.next_revision(snapshot.revision.0);
        state.last_db_revision = snapshot.revision.0;
        (revision, state.generation)
    };
    destination.set_pending(Some(PendingActivation {
        generation,
        train_id,
        snapshot: snapshot.clone(),
    }));
    let plan = tsw_plan(&snapshot);
    let desired = DesiredRouting::new(revision, Some(train_id), vec![plan]);
    match routing.activate_train_revision(desired) {
        Ok(()) => {
            match reconcile_routing(routing).await {
                Ok(()) => {
                    // The release barrier passed. If reconciliation carried
                    // TSW (identical routes), apply the controller activation
                    // directly; the destination never double-applies a
                    // generation.
                    if destination.applied_generation() != generation {
                        if let Err(error) = destination.activate_controllers() {
                            let _ = events
                                .send(TrainEvent::RoutingDegraded(
                                    DegradedReason::ActivationFailed {
                                        destination: DestinationId::Tsw,
                                        error,
                                    },
                                ))
                                .await;
                        }
                    }
                    state
                        .lock()
                        .expect("train service poisoned")
                        .active_train_id = Some(train_id);
                }
                Err(error) => {
                    // Saved-but-not-active: the desired revision stays
                    // committed, controllers stay on the old activation, and
                    // the degraded reason is visible in the routing snapshot.
                    if !matches!(
                        error,
                        RoutingError::Superseded | RoutingError::ReconcileInProgress
                    ) {
                        let _ = events
                            .send(TrainEvent::RoutingDegraded(
                                match routing.degraded_reasons().first() {
                                    Some(reason) => reason.clone(),
                                    None => DegradedReason::ActivationFailed {
                                        destination: DestinationId::Tsw,
                                        error: format!("{error:?}"),
                                    },
                                },
                            ))
                            .await;
                    }
                    state
                        .lock()
                        .expect("train service poisoned")
                        .active_train_id = Some(train_id);
                }
            }
        }
        Err(RoutingError::StaleRevision { .. }) | Err(_) => {
            // A newer commit beat us; leave the desired revision alone.
        }
    }
}

async fn deactivate(
    routing: &Arc<RoutingService>,
    destination: &Arc<TswDestination>,
    state: &Arc<Mutex<ServiceState>>,
    events: &tokio::sync::mpsc::Sender<TrainEvent>,
    clear_identifier: bool,
) {
    let revision = {
        let mut state = state.lock().expect("train service poisoned");
        state.generation += 1;
        state.active_train_id = None;
        if clear_identifier {
            state.detected_identifier = None;
            state.ambiguous.clear();
        }
        let last_db_revision = state.last_db_revision;
        state.next_revision(last_db_revision)
    };
    destination.set_pending(None);
    match routing.deactivate_train(revision) {
        Ok(()) => {
            if let Err(error) = reconcile_routing(routing).await {
                if !matches!(error, RoutingError::StaleRevision { .. }) {
                    if let Some(reason) = routing.degraded_reasons().first() {
                        let _ = events
                            .send(TrainEvent::RoutingDegraded(reason.clone()))
                            .await;
                    }
                }
            }
        }
        Err(RoutingError::StaleRevision { .. }) => {}
        Err(_) => {}
    }
}

/// Routing destination callbacks include synchronous worker acknowledgements.
/// Run them off the Tokio worker so a current-thread runtime can keep driving
/// the controller tasks while the callback waits.
async fn reconcile_routing(routing: &Arc<RoutingService>) -> Result<(), RoutingError> {
    let routing = routing.clone();
    tokio::task::spawn_blocking(move || routing.reconcile())
        .await
        .map_err(|error| RoutingError::InvalidDesired(format!("routing task failed: {error}")))?
}
