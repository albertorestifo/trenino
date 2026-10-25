//! Routing reconciliation across TSW and vJoy destinations with fake drivers.
//!
//! Mirrors Elixir-oracle behaviors:
//! - test/trenino/train/button_controller_test.exs "clears bindings when train is
//!   deactivated" and LeverController/ButtonController `{:train_changed, ...}`
//!   handling: old destinations are released before replacements activate.
//! - test/trenino/train/lever_controller_test.exs "reloading bindings terminates
//!   obsolete in-flight writers": generation fencing discards stale in-flight work.
//! - test/trenino/simulator/connection_test.exs retry/recovery cases: a failed
//!   transition leaves saved-but-inactive state and a later retry converges.
//! - docs/superpowers/plans/2026-10-24-rust-platform.md: "commit precedes a
//!   release barrier; if old-output release fails, the input remains
//!   suspended/degraded, new routing stays inactive".
use std::collections::VecDeque;
use std::sync::mpsc::{channel, Receiver, Sender};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use trenino_core::{EntityId, Revision};
use trenino_runtime::resource::{LeaseKind, ResourceArbiter, ResourceConsumers};
use trenino_runtime::routing::reconcile::{
    ActivationContext, DegradedReason, DesiredRouting, DestinationId, DestinationPlan,
    DestinationStatus, InputRoute, RouteTarget, RoutingDestination, RoutingError, RoutingService,
};
use trenino_runtime::routing::{InputIdentity, InputResolver};

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, PartialEq)]
enum DestCall {
    Release,
    Activate(Revision, DestinationPlan),
}

struct Gate {
    entered: Sender<()>,
    proceed: Receiver<()>,
}

struct FakeDestination {
    calls: Mutex<Vec<DestCall>>,
    driving: Mutex<Option<DestinationPlan>>,
    fail_releases: Mutex<VecDeque<String>>,
    fail_activations: Mutex<VecDeque<String>>,
    release_gate: Mutex<Option<Gate>>,
    activate_gate: Mutex<Option<Gate>>,
    seen_resolver: Mutex<Option<usize>>,
    seen_arbiter: Mutex<Option<usize>>,
}

impl FakeDestination {
    fn new() -> Self {
        Self {
            calls: Mutex::new(Vec::new()),
            driving: Mutex::new(None),
            fail_releases: Mutex::new(VecDeque::new()),
            fail_activations: Mutex::new(VecDeque::new()),
            release_gate: Mutex::new(None),
            activate_gate: Mutex::new(None),
            seen_resolver: Mutex::new(None),
            seen_arbiter: Mutex::new(None),
        }
    }

    fn calls(&self) -> Vec<DestCall> {
        self.calls.lock().unwrap().clone()
    }

    fn driving(&self) -> Option<DestinationPlan> {
        self.driving.lock().unwrap().clone()
    }

    fn fail_next_release(&self, error: &str) {
        self.fail_releases
            .lock()
            .unwrap()
            .push_back(error.to_owned());
    }

    /// Arm the next `release` call to signal entry and block until released.
    fn gate_next_release(&self) -> (Receiver<()>, Sender<()>) {
        let (entered_tx, entered_rx) = channel();
        let (proceed_tx, proceed_rx) = channel();
        *self.release_gate.lock().unwrap() = Some(Gate {
            entered: entered_tx,
            proceed: proceed_rx,
        });
        (entered_rx, proceed_tx)
    }

    /// Arm the next `activate` call to signal entry and block until released.
    fn gate_next_activate(&self) -> (Receiver<()>, Sender<()>) {
        let (entered_tx, entered_rx) = channel();
        let (proceed_tx, proceed_rx) = channel();
        *self.activate_gate.lock().unwrap() = Some(Gate {
            entered: entered_tx,
            proceed: proceed_rx,
        });
        (entered_rx, proceed_tx)
    }
}

impl RoutingDestination for FakeDestination {
    fn release(&self) -> Result<(), String> {
        let gate = self.release_gate.lock().unwrap().take();
        if let Some(gate) = gate {
            let _ = gate.entered.send(());
            let _ = gate.proceed.recv();
        }
        self.calls.lock().unwrap().push(DestCall::Release);
        if let Some(error) = self.fail_releases.lock().unwrap().pop_front() {
            return Err(error);
        }
        *self.driving.lock().unwrap() = None;
        Ok(())
    }

    fn activate(&self, context: &ActivationContext, plan: &DestinationPlan) -> Result<(), String> {
        *self.seen_resolver.lock().unwrap() = Some(Arc::as_ptr(&context.resolver) as usize);
        *self.seen_arbiter.lock().unwrap() = Some(Arc::as_ptr(&context.arbiter) as usize);
        let gate = self.activate_gate.lock().unwrap().take();
        if let Some(gate) = gate {
            let _ = gate.entered.send(());
            let _ = gate.proceed.recv();
        }
        self.calls
            .lock()
            .unwrap()
            .push(DestCall::Activate(context.revision, plan.clone()));
        if let Some(error) = self.fail_activations.lock().unwrap().pop_front() {
            return Err(error);
        }
        *self.driving.lock().unwrap() = Some(plan.clone());
        Ok(())
    }
}

struct NoopConsumers;
impl ResourceConsumers for NoopConsumers {
    fn suspend_actuation(&self, _port: &str) -> Result<(), String> {
        Ok(())
    }
    fn cancel_calibration(&self, _port: &str) -> Result<(), String> {
        Ok(())
    }
    fn source_lost(&self, _port: &str, _generation: u64) -> Result<(), String> {
        Ok(())
    }
    fn resume_after_fresh_sample(&self, _port: &str) -> Result<(), String> {
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

struct Harness {
    service: Arc<RoutingService>,
    resolver: Arc<InputResolver>,
    arbiter: Arc<ResourceArbiter>,
    tsw: Arc<FakeDestination>,
    vjoy: Arc<FakeDestination>,
}

fn harness() -> Harness {
    let resolver = Arc::new(InputResolver::default());
    let arbiter = Arc::new(ResourceArbiter::new(Arc::new(NoopConsumers)));
    let service = Arc::new(RoutingService::new(resolver.clone(), arbiter.clone()));
    let tsw = Arc::new(FakeDestination::new());
    let vjoy = Arc::new(FakeDestination::new());
    service.register_destination(DestinationId::Tsw, tsw.clone());
    service.register_destination(DestinationId::VJoy, vjoy.clone());
    Harness {
        service,
        resolver,
        arbiter,
        tsw,
        vjoy,
    }
}

fn input(device: i64, input: i64) -> InputIdentity {
    InputIdentity {
        device_id: EntityId(device),
        input_id: EntityId(input),
    }
}

fn tsw_plan(endpoint: &str) -> DestinationPlan {
    DestinationPlan {
        destination: DestinationId::Tsw,
        routes: vec![InputRoute {
            input: input(1, 1),
            target: RouteTarget::TswEndpoint(endpoint.to_owned()),
        }],
    }
}

fn vjoy_plan(button: u8) -> DestinationPlan {
    DestinationPlan {
        destination: DestinationId::VJoy,
        routes: vec![InputRoute {
            input: input(1, 2),
            target: RouteTarget::VJoyButton { device: 1, button },
        }],
    }
}

fn desired(revision: u64, plans: Vec<DestinationPlan>) -> DesiredRouting {
    DesiredRouting::new(Revision(revision), Some(EntityId(7)), plans)
}

fn destination_status(
    snapshot: &trenino_runtime::routing::reconcile::RoutingSnapshot,
    id: &DestinationId,
) -> DestinationStatus {
    snapshot
        .destinations
        .iter()
        .find(|entry| &entry.destination == id)
        .map(|entry| entry.status)
        .unwrap_or_else(|| panic!("destination {id:?} missing from snapshot"))
}

fn wait_for(mut condition: impl FnMut() -> bool) {
    let deadline = Instant::now() + Duration::from_secs(5);
    while !condition() {
        assert!(Instant::now() < deadline, "timed out waiting for condition");
        thread::sleep(Duration::from_millis(1));
    }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

/// Mirrors ButtonController/LeverController `{:train_changed, ...}` clearing:
/// old destinations are released before replacements activate, and an unchanged
/// destination is carried without churn.
#[test]
fn normal_swap_releases_old_destinations_before_activating_replacements() {
    let h = harness();

    h.service
        .activate_train_revision(desired(1, vec![tsw_plan("a"), vjoy_plan(1)]))
        .unwrap();
    h.service.reconcile().unwrap();
    assert_eq!(h.service.active_revision(), Some(Revision(1)));
    assert_eq!(
        h.tsw.calls(),
        vec![DestCall::Activate(Revision(1), tsw_plan("a"))]
    );
    assert_eq!(
        h.vjoy.calls(),
        vec![DestCall::Activate(Revision(1), vjoy_plan(1))]
    );
    let snapshot = h.service.snapshot();
    assert_eq!(snapshot.train_id, Some(EntityId(7)));
    assert!(snapshot.degraded.is_empty());

    // Swap TSW routing; the unchanged vJoy plan must be carried, not re-driven.
    h.service
        .activate_train_revision(desired(2, vec![tsw_plan("b"), vjoy_plan(1)]))
        .unwrap();
    h.service.reconcile().unwrap();
    assert_eq!(h.service.active_revision(), Some(Revision(2)));
    assert_eq!(
        h.tsw.calls(),
        vec![
            DestCall::Activate(Revision(1), tsw_plan("a")),
            DestCall::Release,
            DestCall::Activate(Revision(2), tsw_plan("b")),
        ],
        "release must precede the replacement activation"
    );
    assert_eq!(
        h.vjoy.calls(),
        vec![DestCall::Activate(Revision(1), vjoy_plan(1))],
        "unchanged destination must not be churned"
    );
    assert_eq!(h.tsw.driving(), Some(tsw_plan("b")));
    assert_eq!(h.vjoy.driving(), Some(vjoy_plan(1)));

    // Deactivation releases every engaged destination.
    h.service.deactivate_train(Revision(3)).unwrap();
    h.service.reconcile().unwrap();
    assert_eq!(h.service.active_revision(), Some(Revision(3)));
    assert_eq!(h.tsw.driving(), None);
    assert_eq!(h.vjoy.driving(), None);
    assert_eq!(h.tsw.calls().last(), Some(&DestCall::Release));
    assert_eq!(h.vjoy.calls().last(), Some(&DestCall::Release));
}

/// Mirrors the platform contract "saved-but-not-active" and the connection
/// retry tests: a failed release keeps the desired revision saved but inactive,
/// never starts competing destinations, and a later retry converges.
#[test]
fn failed_release_leaves_revision_saved_but_inactive_and_retry_converges() {
    let h = harness();
    h.service
        .activate_train_revision(desired(1, vec![tsw_plan("a"), vjoy_plan(1)]))
        .unwrap();
    h.service.reconcile().unwrap();

    h.tsw.fail_next_release("tsw driver stuck");
    h.service
        .activate_train_revision(desired(2, vec![tsw_plan("b"), vjoy_plan(2)]))
        .unwrap();
    let result = h.service.reconcile();
    assert_eq!(
        result,
        Err(RoutingError::ReleaseFailed {
            destination: DestinationId::Tsw,
            error: "tsw driver stuck".to_owned()
        })
    );

    // Desired saved, but nothing new active; no replacement was started while
    // the old TSW routing refused to release (release barrier).
    let snapshot = h.service.snapshot();
    assert_eq!(snapshot.desired_revision, Some(Revision(2)));
    assert_eq!(snapshot.active_revision, None);
    assert_eq!(
        snapshot.degraded,
        vec![DegradedReason::ReleaseFailed {
            destination: DestinationId::Tsw,
            error: "tsw driver stuck".to_owned()
        }]
    );
    assert_eq!(
        destination_status(&snapshot, &DestinationId::Tsw),
        DestinationStatus::Stale
    );
    assert_eq!(
        destination_status(&snapshot, &DestinationId::VJoy),
        DestinationStatus::Pending
    );
    assert_eq!(
        h.tsw
            .calls()
            .iter()
            .filter(|call| matches!(call, DestCall::Activate(_, _)))
            .count(),
        1,
        "replacement TSW routing must not activate behind a failed release"
    );
    assert!(
        !h.vjoy
            .calls()
            .iter()
            .any(|call| matches!(call, DestCall::Activate(rev, _) if *rev == Revision(2))),
        "no destination activates when the release barrier fails"
    );
    assert_eq!(
        h.tsw.driving(),
        Some(tsw_plan("a")),
        "old TSW routing is still engaged"
    );

    // Retry with a healthy driver converges on the saved revision.
    h.service.reconcile().unwrap();
    assert_eq!(h.service.active_revision(), Some(Revision(2)));
    assert_eq!(h.tsw.driving(), Some(tsw_plan("b")));
    assert_eq!(h.vjoy.driving(), Some(vjoy_plan(2)));
    assert!(h.service.degraded_reasons().is_empty());
}

/// Mirrors "reloading bindings terminates obsolete in-flight writers": a
/// reconciliation whose revision is superseded mid-flight must lose — it never
/// acknowledges the older revision, and the follow-up reconcile converges on
/// the newer one.
#[test]
fn racing_revisions_older_reconciliation_loses() {
    let h = harness();
    h.service
        .activate_train_revision(desired(1, vec![tsw_plan("a")]))
        .unwrap();

    let (entered, proceed) = h.tsw.gate_next_activate();
    let service = h.service.clone();
    let racing = thread::spawn(move || service.reconcile());
    entered.recv().unwrap();

    // A newer revision is committed while the older reconciliation is in flight.
    h.service
        .activate_train_revision(desired(2, vec![tsw_plan("b"), vjoy_plan(2)]))
        .unwrap();
    proceed.send(()).unwrap();

    assert_eq!(racing.join().unwrap(), Err(RoutingError::Superseded));
    let snapshot = h.service.snapshot();
    assert_eq!(snapshot.desired_revision, Some(Revision(2)));
    assert_eq!(
        snapshot.active_revision, None,
        "the superseded reconciliation must not claim its revision is active"
    );
    assert_ne!(
        destination_status(&snapshot, &DestinationId::Tsw),
        DestinationStatus::Active
    );

    // The stale TSW activation is released before the newer revision drives.
    h.service.reconcile().unwrap();
    assert_eq!(h.service.active_revision(), Some(Revision(2)));
    assert_eq!(
        h.tsw.calls(),
        vec![
            DestCall::Activate(Revision(1), tsw_plan("a")),
            DestCall::Release,
            DestCall::Activate(Revision(2), tsw_plan("b")),
        ]
    );
    assert_eq!(
        h.vjoy.calls(),
        vec![DestCall::Activate(Revision(2), vjoy_plan(2))]
    );
    assert_eq!(h.tsw.driving(), Some(tsw_plan("b")));
}

/// The generation fence stops a superseded reconciliation between destinations:
/// once a newer revision lands, no further destination is activated by the
/// stale pass.
#[test]
fn generation_fence_stops_remaining_activations() {
    let h = harness();
    h.service
        .activate_train_revision(desired(1, vec![tsw_plan("a"), vjoy_plan(1)]))
        .unwrap();

    let (entered, proceed) = h.tsw.gate_next_activate();
    let service = h.service.clone();
    let racing = thread::spawn(move || service.reconcile());
    entered.recv().unwrap();

    h.service
        .activate_train_revision(desired(2, vec![tsw_plan("b"), vjoy_plan(2)]))
        .unwrap();
    proceed.send(()).unwrap();

    assert_eq!(racing.join().unwrap(), Err(RoutingError::Superseded));
    assert_eq!(
        h.vjoy.calls(),
        Vec::<DestCall>::new(),
        "the fenced reconciliation must not activate further destinations"
    );

    h.service.reconcile().unwrap();
    assert_eq!(h.service.active_revision(), Some(Revision(2)));
    assert_eq!(
        h.tsw.calls(),
        vec![
            DestCall::Activate(Revision(1), tsw_plan("a")),
            DestCall::Release,
            DestCall::Activate(Revision(2), tsw_plan("b")),
        ]
    );
    assert_eq!(
        h.vjoy.calls(),
        vec![DestCall::Activate(Revision(2), vjoy_plan(2))]
    );
}

/// Mirrors connection `disconnect` semantics and the lifecycle shutdown phases:
/// shutdown releases engaged destinations, retains the desired revision, and
/// closes admission.
#[test]
fn shutdown_releases_active_destinations_and_blocks_new_admission() {
    let h = harness();
    h.service
        .activate_train_revision(desired(1, vec![tsw_plan("a"), vjoy_plan(1)]))
        .unwrap();
    h.service.reconcile().unwrap();

    h.service.shutdown().unwrap();
    assert_eq!(h.tsw.driving(), None);
    assert_eq!(h.vjoy.driving(), None);
    assert_eq!(h.tsw.calls().last(), Some(&DestCall::Release));
    assert_eq!(h.vjoy.calls().last(), Some(&DestCall::Release));

    let snapshot = h.service.snapshot();
    assert!(snapshot.shut_down);
    assert_eq!(
        snapshot.desired_revision,
        Some(Revision(1)),
        "shutdown never rolls back the saved revision"
    );
    assert_eq!(snapshot.active_revision, None);
    assert!(snapshot.degraded.is_empty());

    assert_eq!(h.service.reconcile(), Err(RoutingError::Shutdown));
    assert_eq!(
        h.service
            .activate_train_revision(desired(2, vec![tsw_plan("b")])),
        Err(RoutingError::Shutdown)
    );
}

/// The fence also discards a superseded release barrier: its effects are not
/// committed, the recorded active routing is retained, and the next reconcile
/// (releases are idempotent) converges on the newest revision.
#[test]
fn generation_fence_discards_superseded_release_barrier() {
    let h = harness();
    h.service
        .activate_train_revision(desired(1, vec![tsw_plan("a")]))
        .unwrap();
    h.service.reconcile().unwrap();
    h.service
        .activate_train_revision(desired(2, vec![tsw_plan("b")]))
        .unwrap();

    let (entered, proceed) = h.tsw.gate_next_release();
    let service = h.service.clone();
    let racing = thread::spawn(move || service.reconcile());
    entered.recv().unwrap();

    // An even newer revision lands while the release barrier is in flight.
    h.service
        .activate_train_revision(desired(3, vec![tsw_plan("c")]))
        .unwrap();
    proceed.send(()).unwrap();

    assert_eq!(racing.join().unwrap(), Err(RoutingError::Superseded));
    let snapshot = h.service.snapshot();
    assert_eq!(snapshot.desired_revision, Some(Revision(3)));
    assert_eq!(snapshot.active_revision, None);
    assert_eq!(
        destination_status(&snapshot, &DestinationId::Tsw),
        DestinationStatus::Stale
    );

    h.service.reconcile().unwrap();
    assert_eq!(h.service.active_revision(), Some(Revision(3)));
    assert_eq!(
        h.tsw.calls(),
        vec![
            DestCall::Activate(Revision(1), tsw_plan("a")),
            DestCall::Release,
            DestCall::Release,
            DestCall::Activate(Revision(3), tsw_plan("c")),
        ],
        "the discarded barrier is retried before the newest plan activates"
    );
    assert_eq!(h.tsw.driving(), Some(tsw_plan("c")));
}

/// Shutdown fences an in-flight reconciliation: it returns `Cancelled`, skips
/// remaining activations, and shutdown releases whatever it left engaged.
#[test]
fn shutdown_cancels_in_flight_reconciliation() {
    let h = harness();
    h.service
        .activate_train_revision(desired(1, vec![tsw_plan("a"), vjoy_plan(1)]))
        .unwrap();

    let (entered, proceed) = h.tsw.gate_next_activate();
    let service = h.service.clone();
    let racing = thread::spawn(move || service.reconcile());
    entered.recv().unwrap();

    let service = h.service.clone();
    let shutting = thread::spawn(move || service.shutdown());
    // Shutdown sets the flag and fences the in-flight pass before waiting for it.
    wait_for(|| h.service.snapshot().shut_down);
    proceed.send(()).unwrap();

    assert_eq!(racing.join().unwrap(), Err(RoutingError::Cancelled));
    shutting.join().unwrap().unwrap();

    assert_eq!(
        h.vjoy.calls(),
        Vec::<DestCall>::new(),
        "the cancelled reconciliation must not activate further destinations"
    );
    assert_eq!(
        h.tsw.calls(),
        vec![
            DestCall::Activate(Revision(1), tsw_plan("a")),
            DestCall::Release
        ],
        "shutdown releases the stale activation left by the fenced pass"
    );
    let snapshot = h.service.snapshot();
    assert!(snapshot.shut_down);
    assert_eq!(snapshot.desired_revision, Some(Revision(1)));
    assert_eq!(snapshot.active_revision, None);
    assert!(snapshot.degraded.is_empty());
    assert_eq!(h.service.reconcile(), Err(RoutingError::Shutdown));
}

/// Shared resource arbiter integration: while a calibration/firmware lease
/// suspends ordinary actuation, releases still run but activations are
/// deferred; after the lease, reconciliation converges.
#[test]
fn reconciliation_defers_activation_while_arbiter_suspended() {
    let h = harness();
    h.service
        .activate_train_revision(desired(1, vec![tsw_plan("a")]))
        .unwrap();

    let lease = h
        .arbiter
        .acquire(LeaseKind::Calibration {
            port: "COM9".into(),
            generation: 3,
        })
        .unwrap();
    assert_eq!(
        h.service.reconcile(),
        Err(RoutingError::ArbitrationSuspended)
    );
    assert_eq!(
        h.tsw.calls(),
        Vec::<DestCall>::new(),
        "no activation while actuation is suspended"
    );
    assert_eq!(
        h.service.degraded_reasons(),
        vec![DegradedReason::ArbitrationSuspended]
    );
    assert_eq!(h.service.active_revision(), None);

    h.arbiter.release(lease).unwrap();
    h.service.reconcile().unwrap();
    assert_eq!(h.service.active_revision(), Some(Revision(1)));
    assert_eq!(h.tsw.driving(), Some(tsw_plan("a")));

    // Releases still run during suspension; only the replacement is deferred.
    h.service
        .activate_train_revision(desired(2, vec![tsw_plan("b")]))
        .unwrap();
    let lease = h
        .arbiter
        .acquire(LeaseKind::Calibration {
            port: "COM9".into(),
            generation: 4,
        })
        .unwrap();
    assert_eq!(
        h.service.reconcile(),
        Err(RoutingError::ArbitrationSuspended)
    );
    assert_eq!(
        h.tsw.driving(),
        None,
        "old routing was released during suspension"
    );
    assert_eq!(h.service.active_revision(), None);

    h.arbiter.release(lease).unwrap();
    h.service.reconcile().unwrap();
    assert_eq!(h.service.active_revision(), Some(Revision(2)));
    assert_eq!(h.tsw.driving(), Some(tsw_plan("b")));
}

/// A saved revision is committed intent: older or repeated revisions are
/// rejected and never roll back the newest one.
#[test]
fn stale_revisions_are_rejected_and_never_roll_back_newer_intent() {
    let h = harness();
    h.service
        .activate_train_revision(desired(5, vec![tsw_plan("e")]))
        .unwrap();
    assert_eq!(
        h.service
            .activate_train_revision(desired(3, vec![tsw_plan("c")])),
        Err(RoutingError::StaleRevision {
            current: Revision(5),
            attempted: Revision(3)
        })
    );
    assert_eq!(
        h.service
            .activate_train_revision(desired(5, vec![tsw_plan("other")])),
        Err(RoutingError::StaleRevision {
            current: Revision(5),
            attempted: Revision(5)
        })
    );
    assert_eq!(h.service.desired_revision(), Some(Revision(5)));

    h.service.reconcile().unwrap();
    assert_eq!(h.tsw.driving(), Some(tsw_plan("e")));
    assert_eq!(h.service.active_revision(), Some(Revision(5)));
}

/// A desired destination without a registered driver is degraded, never
/// silently active; registering the driver lets the retry converge.
#[test]
fn desired_destination_without_driver_is_degraded_until_registered() {
    let resolver = Arc::new(InputResolver::default());
    let arbiter = Arc::new(ResourceArbiter::new(Arc::new(NoopConsumers)));
    let service = RoutingService::new(resolver, arbiter);
    let tsw = Arc::new(FakeDestination::new());
    service.register_destination(DestinationId::Tsw, tsw.clone());

    service
        .activate_train_revision(desired(1, vec![tsw_plan("a"), vjoy_plan(1)]))
        .unwrap();
    assert_eq!(
        service.reconcile(),
        Err(RoutingError::DestinationUnavailable {
            destination: DestinationId::VJoy
        })
    );
    let snapshot = service.snapshot();
    assert_eq!(snapshot.active_revision, None);
    assert_eq!(
        destination_status(&snapshot, &DestinationId::Tsw),
        DestinationStatus::Active
    );
    assert_eq!(
        destination_status(&snapshot, &DestinationId::VJoy),
        DestinationStatus::Degraded
    );
    assert_eq!(
        snapshot.degraded,
        vec![DegradedReason::DestinationUnavailable {
            destination: DestinationId::VJoy
        }]
    );

    let vjoy = Arc::new(FakeDestination::new());
    service.register_destination(DestinationId::VJoy, vjoy.clone());
    service.reconcile().unwrap();
    assert_eq!(service.active_revision(), Some(Revision(1)));
    assert_eq!(vjoy.driving(), Some(vjoy_plan(1)));
    assert_eq!(
        tsw.calls(),
        vec![DestCall::Activate(Revision(1), tsw_plan("a"))],
        "the converged TSW destination is carried without churn"
    );
}

/// A concurrent reconcile is rejected instead of racing destination callbacks.
#[test]
fn concurrent_reconciliation_is_rejected() {
    let h = harness();
    h.service
        .activate_train_revision(desired(1, vec![tsw_plan("a")]))
        .unwrap();

    let (entered, proceed) = h.tsw.gate_next_activate();
    let service = h.service.clone();
    let first = thread::spawn(move || service.reconcile());
    entered.recv().unwrap();

    assert_eq!(
        h.service.reconcile(),
        Err(RoutingError::ReconcileInProgress)
    );
    proceed.send(()).unwrap();
    first.join().unwrap().unwrap();
    assert_eq!(h.service.active_revision(), Some(Revision(1)));
}

/// Destinations receive the shared resolver and arbiter at activation time —
/// no parallel identity maps.
#[test]
fn activation_context_shares_the_single_resolver_and_arbiter() {
    let h = harness();
    h.service
        .activate_train_revision(desired(1, vec![tsw_plan("a")]))
        .unwrap();
    h.service.reconcile().unwrap();

    assert_eq!(
        *h.tsw.seen_resolver.lock().unwrap(),
        Some(Arc::as_ptr(&h.resolver) as usize)
    );
    assert_eq!(
        *h.tsw.seen_arbiter.lock().unwrap(),
        Some(Arc::as_ptr(&h.arbiter) as usize)
    );
}

#[test]
fn scoped_tsw_deactivation_preserves_vjoy_plan_and_driver() {
    let h = harness();
    h.service
        .activate_train_revision(desired(1, vec![tsw_plan("a"), vjoy_plan(1)]))
        .unwrap();
    h.service.reconcile().unwrap();
    h.service
        .deactivate_destination(DestinationId::Tsw, Revision(2))
        .unwrap();
    let snapshot = h.service.snapshot();
    assert_eq!(snapshot.desired_revision, Some(Revision(2)));
    assert!(snapshot
        .destinations
        .iter()
        .all(|destination| destination.destination != DestinationId::Tsw));
    assert_eq!(
        destination_status(&snapshot, &DestinationId::VJoy),
        DestinationStatus::Active
    );
    assert_eq!(h.tsw.calls().last(), Some(&DestCall::Release));
    assert_eq!(
        h.vjoy.calls(),
        vec![DestCall::Activate(Revision(1), vjoy_plan(1))]
    );
    assert_eq!(h.vjoy.driving(), Some(vjoy_plan(1)));
}
