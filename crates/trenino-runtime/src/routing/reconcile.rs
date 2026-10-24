//! Revisioned desired routing with explicit, generation-fenced reconciliation
//! across TSW and vJoy destinations.
//!
//! Ported behavior (Elixir oracle):
//! - A train switch releases the old train's bindings before the new train drives
//!   outputs (`LeverController`/`ButtonController` clear bindings on
//!   `{:train_changed, ...}`: lib/trenino/train/lever_controller.ex,
//!   lib/trenino/train/button_controller.ex; test/trenino/train/button_controller_test.exs
//!   "clears bindings when train is deactivated").
//! - Reloading configuration terminates obsolete in-flight writers
//!   (test/trenino/train/lever_controller_test.exs "reloading bindings terminates
//!   obsolete in-flight writers"); the generation fence here gives the same
//!   guarantee to whole-destination reconciliation.
//! - A failed release leaves the committed intent saved but inactive
//!   ("saved-but-not-active", docs/superpowers/plans/2026-10-24-rust-platform.md):
//!   the desired revision is never rolled back, replacements are never started
//!   while an old destination refuses to release, and bounded `reconcile` retries
//!   converge using fresh generations.
//!
//! Destinations share the one [`InputResolver`] identity map and the process-wide
//! [`ResourceArbiter`]; they must not maintain parallel identity maps.

use std::collections::{BTreeMap, BTreeSet};
use std::sync::{Arc, Condvar, Mutex, MutexGuard};

use trenino_core::{EntityId, Revision};

use super::{InputIdentity, InputResolver};
use crate::resource::ResourceArbiter;

const LOCK: &str = "routing service poisoned";

/// A routable output destination.
#[derive(Clone, Debug, Eq, Hash, Ord, PartialEq, PartialOrd)]
pub enum DestinationId {
    /// Train Sim World simulator API.
    Tsw,
    /// Virtual joystick manager (owns all selected vJoy devices).
    VJoy,
}

/// Where one routed input lands on its destination.
#[derive(Clone, Debug, Eq, Ord, PartialEq, PartialOrd)]
pub enum RouteTarget {
    /// TSW API endpoint path (lever value endpoint, button endpoint, ...).
    TswEndpoint(String),
    /// A vJoy device button.
    VJoyButton { device: u16, button: u8 },
    /// A vJoy device axis.
    VJoyAxis { device: u16, axis: u8 },
}

/// One input binding routed to a destination target.
#[derive(Clone, Debug, Eq, Ord, PartialEq, PartialOrd)]
pub struct InputRoute {
    pub input: InputIdentity,
    pub target: RouteTarget,
}

/// All routes driven by one destination under one revision.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct DestinationPlan {
    pub destination: DestinationId,
    pub routes: Vec<InputRoute>,
}

/// Complete, atomically replaceable desired routing for one committed revision.
///
/// The revision is the committed-DB intent revision; it must strictly increase
/// across edits so a newer commit can never be rolled back by an older one.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct DesiredRouting {
    pub revision: Revision,
    pub train_id: Option<EntityId>,
    pub plans: Vec<DestinationPlan>,
}

impl DesiredRouting {
    pub fn new(
        revision: Revision,
        train_id: Option<EntityId>,
        plans: Vec<DestinationPlan>,
    ) -> Self {
        Self {
            revision,
            train_id,
            plans,
        }
    }

    /// Intent to drive nothing (train deactivated).
    pub fn deactivated(revision: Revision) -> Self {
        Self::new(revision, None, Vec::new())
    }
}

/// Handles shared with destinations at activation time: the sole input resolver
/// and the shared resource arbiter, so no destination builds a parallel map.
pub struct ActivationContext {
    pub revision: Revision,
    pub train_id: Option<EntityId>,
    pub resolver: Arc<InputResolver>,
    pub arbiter: Arc<ResourceArbiter>,
}

/// A live TSW/vJoy destination driver.
///
/// Callbacks run outside the service state lock and must be bounded: `shutdown`
/// waits for an in-flight reconciliation to leave its callbacks. `release` must
/// be idempotent and safe when nothing is driving; `activate` must replace
/// whatever the destination currently drives.
pub trait RoutingDestination: Send + Sync + 'static {
    /// Stop driving any routing on this destination.
    fn release(&self) -> Result<(), String>;
    /// Drive the given plan, replacing any current routing.
    fn activate(&self, context: &ActivationContext, plan: &DestinationPlan) -> Result<(), String>;
}

/// Why desired routing is not (fully) active.
#[derive(Clone, Debug, Eq, PartialEq)]
pub enum DegradedReason {
    /// An old destination refused to release; replacements stay inactive.
    ReleaseFailed { destination: DestinationId, error: String },
    /// A destination failed to activate after the release barrier passed.
    ActivationFailed { destination: DestinationId, error: String },
    /// Activation is gated by an active calibration/firmware lease.
    ArbitrationSuspended,
    /// Desired routing names a destination with no registered driver.
    DestinationUnavailable { destination: DestinationId },
    /// Shutdown could not release an engaged destination.
    ShutdownReleaseFailed { destination: DestinationId, error: String },
}

impl DegradedReason {
    fn destination(&self) -> Option<&DestinationId> {
        match self {
            Self::ReleaseFailed { destination, .. }
            | Self::ActivationFailed { destination, .. }
            | Self::DestinationUnavailable { destination }
            | Self::ShutdownReleaseFailed { destination, .. } => Some(destination),
            Self::ArbitrationSuspended => None,
        }
    }
}

/// Per-destination desired-vs-active status.
#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DestinationStatus {
    /// Driving the desired routes.
    Active,
    /// Desired but reconciliation has not engaged it yet.
    Pending,
    /// Engaged with outdated or no-longer-desired routes; release pending/failed.
    Stale,
    /// Reconciliation failed for this destination (see degraded reasons).
    Degraded,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct DestinationSnapshot {
    pub destination: DestinationId,
    pub status: DestinationStatus,
    pub active_revision: Option<Revision>,
}

/// Desired-vs-active view for controllers and UI reporting.
#[derive(Clone, Debug, Eq, PartialEq)]
pub struct RoutingSnapshot {
    pub desired_revision: Option<Revision>,
    /// `Some(rev)` only when every desired destination is acknowledged at `rev`
    /// and no stale destination remains engaged; never claims a requested
    /// revision is active before it is fully acknowledged.
    pub active_revision: Option<Revision>,
    pub train_id: Option<EntityId>,
    pub destinations: Vec<DestinationSnapshot>,
    pub degraded: Vec<DegradedReason>,
    pub reconciling: bool,
    pub shut_down: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum RoutingError {
    /// A revision that would rewind or rewrite committed intent.
    StaleRevision { current: Revision, attempted: Revision },
    /// Malformed desired routing (e.g. a destination listed twice).
    InvalidDesired(String),
    /// Another reconciliation is in flight; retry after it finishes.
    ReconcileInProgress,
    /// The in-flight reconciliation lost the generation fence to a newer
    /// committed revision and was discarded without effect.
    Superseded,
    /// Shutdown fenced the in-flight reconciliation before it could commit.
    Cancelled,
    /// Admission is closed; the service is shut down.
    Shutdown,
    /// The release barrier failed; the desired revision is saved but inactive.
    ReleaseFailed { destination: DestinationId, error: String },
    /// A destination failed to activate; the desired revision stays degraded.
    ActivationFailed { destination: DestinationId, error: String },
    /// Desired routing names a destination with no registered driver.
    DestinationUnavailable { destination: DestinationId },
    /// Activation is gated by an active calibration/firmware lease.
    ArbitrationSuspended,
}

#[derive(Clone, Debug, Eq, PartialEq)]
struct ActiveDestination {
    revision: Revision,
    plan: DestinationPlan,
}

#[derive(Default)]
struct State {
    desired: Option<DesiredRouting>,
    active: BTreeMap<DestinationId, ActiveDestination>,
    /// Destinations whose `activate` callback ran but whose commit was fenced;
    /// they may be driving unacknowledged routes and must be released first.
    dirty: BTreeSet<DestinationId>,
    generation: u64,
    degraded: Vec<DegradedReason>,
    reconciling: bool,
    shut_down: bool,
}

/// Revisioned routing service shared by all wave-2 controllers.
///
/// Desired edits are atomic (one lock, complete replacement). Reconciliation is
/// explicit: it releases old destinations before activating replacements, never
/// starts replacements when the release barrier fails, and is fenced by a
/// generation counter so a stale reconciliation cannot act on newer intent.
pub struct RoutingService {
    state: Mutex<State>,
    idle: Condvar,
    drivers: Mutex<BTreeMap<DestinationId, Arc<dyn RoutingDestination>>>,
    resolver: Arc<InputResolver>,
    arbiter: Arc<ResourceArbiter>,
}

impl RoutingService {
    pub fn new(resolver: Arc<InputResolver>, arbiter: Arc<ResourceArbiter>) -> Self {
        Self {
            state: Mutex::new(State::default()),
            idle: Condvar::new(),
            drivers: Mutex::new(BTreeMap::new()),
            resolver,
            arbiter,
        }
    }

    /// Register (or replace) a destination driver. Registered destinations that
    /// end up driving unacknowledged routes are released before replacements.
    pub fn register_destination(
        &self,
        destination: DestinationId,
        driver: Arc<dyn RoutingDestination>,
    ) {
        self.drivers
            .lock()
            .expect(LOCK)
            .insert(destination, driver);
    }

    /// Atomically commit a new desired routing revision. This only records
    /// intent; call [`RoutingService::reconcile`] to drive it. The revision must
    /// strictly increase so a newer commit is never rolled back.
    pub fn activate_train_revision(&self, mut desired: DesiredRouting) -> Result<(), RoutingError> {
        for plan in &mut desired.plans {
            plan.routes.sort();
        }
        desired.plans.sort_by(|a, b| a.destination.cmp(&b.destination));
        for pair in desired.plans.windows(2) {
            if pair[0].destination == pair[1].destination {
                return Err(RoutingError::InvalidDesired(format!(
                    "destination {:?} listed more than once",
                    pair[0].destination
                )));
            }
        }
        let mut state = self.state.lock().expect(LOCK);
        if state.shut_down {
            return Err(RoutingError::Shutdown);
        }
        if let Some(current) = &state.desired {
            if desired.revision <= current.revision {
                return Err(RoutingError::StaleRevision {
                    current: current.revision,
                    attempted: desired.revision,
                });
            }
        }
        state.generation = state.generation.wrapping_add(1);
        state.degraded = Vec::new();
        state.desired = Some(desired);
        Ok(())
    }

    /// Commit intent to drive nothing (train deactivated) at a new revision.
    pub fn deactivate_train(&self, revision: Revision) -> Result<(), RoutingError> {
        self.activate_train_revision(DesiredRouting::deactivated(revision))
    }

    /// Drive active routing toward the committed desired revision.
    ///
    /// Releases every destination whose engaged routes differ from the desired
    /// plan (including destinations left dirty by a fenced reconciliation)
    /// before activating any replacement. A failed release aborts before any
    /// activation, leaving the desired revision saved but inactive; a later
    /// `reconcile` retries. While the resource arbiter is suspended, releases
    /// still run but activations are deferred.
    pub fn reconcile(&self) -> Result<(), RoutingError> {
        let (generation, desired, context, releases, activations, carried, unavailable) = {
            let mut state = self.state.lock().expect(LOCK);
            if state.shut_down {
                return Err(RoutingError::Shutdown);
            }
            if state.reconciling {
                return Err(RoutingError::ReconcileInProgress);
            }
            state.reconciling = true;

            let desired = state.desired.clone();
            let desired_plans: BTreeMap<DestinationId, DestinationPlan> = desired
                .as_ref()
                .map(|desired| {
                    desired
                        .plans
                        .iter()
                        .map(|plan| (plan.destination.clone(), plan.clone()))
                        .collect()
                })
                .unwrap_or_default();
            let drivers = self.drivers.lock().expect(LOCK).clone();

            let mut releases = Vec::new();
            let mut activations = Vec::new();
            let mut carried = Vec::new();
            let mut unavailable = Vec::new();
            for (id, plan) in &desired_plans {
                match drivers.get(id) {
                    None => unavailable.push(id.clone()),
                    Some(driver) => {
                        let unchanged = state
                            .active
                            .get(id)
                            .is_some_and(|active| active.plan == *plan);
                        if unchanged {
                            carried.push(id.clone());
                        } else {
                            if state.active.contains_key(id) || state.dirty.contains(id) {
                                releases.push((id.clone(), driver.clone()));
                            }
                            activations.push((id.clone(), plan.clone(), driver.clone()));
                        }
                    }
                }
            }
            for (id, driver) in &drivers {
                if desired_plans.contains_key(id) {
                    continue;
                }
                if state.active.contains_key(id) || state.dirty.contains(id) {
                    releases.push((id.clone(), driver.clone()));
                }
            }

            let context = ActivationContext {
                revision: desired.as_ref().map_or(Revision(0), |d| d.revision),
                train_id: desired.as_ref().and_then(|d| d.train_id),
                resolver: self.resolver.clone(),
                arbiter: self.arbiter.clone(),
            };
            (
                state.generation,
                desired,
                context,
                releases,
                activations,
                carried,
                unavailable,
            )
        };

        // Phase 1: release barrier. No replacement may start while any old
        // destination refuses to release.
        let mut released = Vec::new();
        let mut release_failures = Vec::new();
        for (id, driver) in &releases {
            match driver.release() {
                Ok(()) => released.push(id.clone()),
                Err(error) => release_failures.push((id.clone(), error)),
            }
        }
        {
            let mut state = self.state.lock().expect(LOCK);
            if state.generation != generation {
                return self.finish_superseded(state);
            }
            for id in &released {
                state.active.remove(id);
                state.dirty.remove(id);
            }
            if !release_failures.is_empty() {
                state.degraded = release_failures
                    .iter()
                    .map(|(id, error)| DegradedReason::ReleaseFailed {
                        destination: id.clone(),
                        error: error.clone(),
                    })
                    .collect();
                let (destination, error) = release_failures
                    .into_iter()
                    .next()
                    .expect("release failure list is non-empty");
                return self.finish_with(state, Err(RoutingError::ReleaseFailed { destination, error }));
            }
        }

        // Phase 2 gate: while calibration/firmware leases suspend ordinary
        // actuation, releases stand but no destination is (re)started.
        if self.arbiter.is_suspended() {
            let mut state = self.state.lock().expect(LOCK);
            if state.generation != generation {
                return self.finish_superseded(state);
            }
            state.degraded = vec![DegradedReason::ArbitrationSuspended];
            return self.finish_with(state, Err(RoutingError::ArbitrationSuspended));
        }

        // Phase 3: activate replacements. Each destination is fenced again so a
        // newer commit or shutdown stops further activations; destinations whose
        // activation began are tracked dirty until the fenced commit.
        let mut activated = Vec::new();
        let mut activation_failures = Vec::new();
        for (id, plan, driver) in activations {
            {
                let mut state = self.state.lock().expect(LOCK);
                if state.generation != generation || state.shut_down {
                    break;
                }
                state.dirty.insert(id.clone());
            }
            match driver.activate(&context, &plan) {
                Ok(()) => activated.push((id, plan)),
                Err(error) => activation_failures.push((id, error)),
            }
        }

        let mut state = self.state.lock().expect(LOCK);
        if state.generation != generation {
            // Fenced: leave activated destinations dirty; a newer reconciliation
            // will release them. Never acknowledge this revision.
            return self.finish_superseded(state);
        }
        if let Some(desired) = &desired {
            for id in &carried {
                if let Some(active) = state.active.get_mut(id) {
                    active.revision = desired.revision;
                }
                state.dirty.remove(id);
            }
            for (id, plan) in &activated {
                state.active.insert(
                    id.clone(),
                    ActiveDestination {
                        revision: desired.revision,
                        plan: plan.clone(),
                    },
                );
                state.dirty.remove(id);
            }
        }
        let mut degraded: Vec<DegradedReason> = unavailable
            .iter()
            .map(|id| DegradedReason::DestinationUnavailable {
                destination: id.clone(),
            })
            .collect();
        degraded.extend(
            activation_failures
                .iter()
                .map(|(id, error)| DegradedReason::ActivationFailed {
                    destination: id.clone(),
                    error: error.clone(),
                }),
        );
        state.degraded = degraded;
        let result = if let Some(destination) = unavailable.into_iter().next() {
            Err(RoutingError::DestinationUnavailable { destination })
        } else if let Some((destination, error)) = activation_failures.into_iter().next() {
            Err(RoutingError::ActivationFailed { destination, error })
        } else {
            Ok(())
        };
        self.finish_with(state, result)
    }

    /// Current desired-vs-active view, including degraded reasons.
    pub fn snapshot(&self) -> RoutingSnapshot {
        let state = self.state.lock().expect(LOCK);
        let desired = state.desired.clone();
        let desired_revision = desired.as_ref().map(|d| d.revision);
        let desired_plans: BTreeMap<DestinationId, DestinationPlan> = desired
            .as_ref()
            .map(|d| {
                d.plans
                    .iter()
                    .map(|plan| (plan.destination.clone(), plan.clone()))
                    .collect()
            })
            .unwrap_or_default();
        let degraded_for = |id: &DestinationId| {
            state
                .degraded
                .iter()
                .any(|reason| reason.destination() == Some(id))
        };

        let mut ids: BTreeSet<DestinationId> = desired_plans.keys().cloned().collect();
        ids.extend(state.active.keys().cloned());
        ids.extend(state.dirty.iter().cloned());

        let mut converged = desired.is_some() && state.degraded.is_empty();
        let mut destinations = Vec::new();
        for id in ids {
            let (status, active_revision) = match (desired_plans.get(&id), state.active.get(&id)) {
                (Some(plan), Some(active)) => {
                    if active.plan == *plan {
                        if degraded_for(&id) {
                            (DestinationStatus::Degraded, Some(active.revision))
                        } else {
                            (DestinationStatus::Active, Some(active.revision))
                        }
                    } else {
                        (DestinationStatus::Stale, Some(active.revision))
                    }
                }
                (Some(_), None) => {
                    if degraded_for(&id) {
                        (DestinationStatus::Degraded, None)
                    } else {
                        (DestinationStatus::Pending, None)
                    }
                }
                (None, Some(active)) => (DestinationStatus::Stale, Some(active.revision)),
                (None, None) => (DestinationStatus::Stale, None),
            };
            if !(status == DestinationStatus::Active && active_revision == desired_revision) {
                converged = false;
            }
            destinations.push(DestinationSnapshot {
                destination: id,
                status,
                active_revision,
            });
        }

        RoutingSnapshot {
            desired_revision,
            active_revision: if converged { desired_revision } else { None },
            train_id: desired.and_then(|d| d.train_id),
            destinations,
            degraded: state.degraded.clone(),
            reconciling: state.reconciling,
            shut_down: state.shut_down,
        }
    }

    pub fn desired_revision(&self) -> Option<Revision> {
        self.state
            .lock()
            .expect(LOCK)
            .desired
            .as_ref()
            .map(|d| d.revision)
    }

    pub fn active_revision(&self) -> Option<Revision> {
        self.snapshot().active_revision
    }

    pub fn degraded_reasons(&self) -> Vec<DegradedReason> {
        self.state.lock().expect(LOCK).degraded.clone()
    }

    /// Close admission, fence any in-flight reconciliation, wait for it to
    /// finish, then release every engaged destination. The desired revision is
    /// retained, never rolled back. Safe to retry after a failed release.
    ///
    /// Must not be called from a destination callback (shutdown waits for
    /// in-flight callbacks to complete).
    pub fn shutdown(&self) -> Result<(), RoutingError> {
        let release_targets = {
            let mut state = self.state.lock().expect(LOCK);
            state.shut_down = true;
            state.generation = state.generation.wrapping_add(1);
            while state.reconciling {
                state = self.idle.wait(state).expect(LOCK);
            }
            let drivers = self.drivers.lock().expect(LOCK);
            let ids: BTreeSet<DestinationId> = state
                .active
                .keys()
                .chain(state.dirty.iter())
                .cloned()
                .collect();
            ids.iter()
                .filter_map(|id| drivers.get(id).map(|driver| (id.clone(), driver.clone())))
                .collect::<Vec<_>>()
        };

        let mut released = Vec::new();
        let mut failures = Vec::new();
        for (id, driver) in release_targets {
            match driver.release() {
                Ok(()) => released.push(id),
                Err(error) => failures.push((id, error)),
            }
        }

        let mut state = self.state.lock().expect(LOCK);
        for id in &released {
            state.active.remove(id);
            state.dirty.remove(id);
        }
        if failures.is_empty() {
            state.degraded = Vec::new();
            Ok(())
        } else {
            state.degraded = failures
                .iter()
                .map(|(id, error)| DegradedReason::ShutdownReleaseFailed {
                    destination: id.clone(),
                    error: error.clone(),
                })
                .collect();
            let (destination, error) = failures
                .into_iter()
                .next()
                .expect("shutdown failure list is non-empty");
            Err(RoutingError::ReleaseFailed { destination, error })
        }
    }

    fn finish_with(
        &self,
        mut state: MutexGuard<'_, State>,
        result: Result<(), RoutingError>,
    ) -> Result<(), RoutingError> {
        state.reconciling = false;
        drop(state);
        self.idle.notify_all();
        result
    }

    fn finish_superseded(&self, state: MutexGuard<'_, State>) -> Result<(), RoutingError> {
        let error = if state.shut_down {
            RoutingError::Cancelled
        } else {
            RoutingError::Superseded
        };
        self.finish_with(state, Err(error))
    }
}
