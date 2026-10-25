//! Train activation coordinator integration tests.
//!
//! Mirrors `test/trenino/train/detection_test.exs` through the service layer
//! (grace period, ambiguity, manual sync) and the controls-plan regression
//! list (activation races, train-switch cleanup, canceled callers). The
//! detection polling semantics themselves (5s poll, 30s grace / 200ms probes,
//! drivable-index fallback) are ported in `simulator/services/train_detection.rs`
//! and covered by `tests/simulator_detection.rs`; here they are asserted
//! end-to-end through the activation coordinator, the routing service and the
//! lever/button controllers.
//!
//! All simulator traffic hits a scripted loopback server; the clock is fake;
//! no user database is touched (the configuration source is in-memory).

#[path = "fixtures/controls/mod.rs"]
mod fixtures;

use std::sync::Arc;
use std::time::Duration;

use trenino_core::hardware::calibration::Calibration;
use trenino_core::train::identifier::TrainProfile;
use trenino_core::train::lever::{Notch, NotchType};
use trenino_core::{ConfigId, EntityId};
use trenino_runtime::resource::{ResourceArbiter, ResourceConsumers};
use trenino_runtime::routing::reconcile::RoutingService;
use trenino_runtime::routing::{InputIdentity, InputResolver};
use trenino_runtime::simulator::client::SimulatorClient;
use trenino_runtime::simulator::services::clock::FakeClock;
use trenino_runtime::storage::bindings::{ButtonHardwareType, ButtonMode};
use trenino_runtime::train::detection::{
    ButtonBindingInfo, LeverBindingInfo, SequenceCommand, TrainConfigSnapshot,
};
use trenino_runtime::train::lever_controller::LeverSample;
use trenino_runtime::train::button_controller::ButtonSample;
use trenino_runtime::train::service::{TrainEvent, TrainServiceHandle};

use fixtures::{advance_until, settle, yield_until, FakeConfig, FakeKeystrokes, ScriptedSim};

const THROTTLE: &str = "CurrentDrivableActor/Throttle(Lever).InputValue";
const HORN: &str = "CurrentDrivableActor/Horn.InputValue";

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

fn profile(id: i64, name: &str, identifiers: &[&str]) -> TrainProfile {
    TrainProfile {
        id,
        name: name.to_owned(),
        identifiers: identifiers.iter().map(|item| (*item).to_owned()).collect(),
    }
}

fn snapshot(train_id: i64) -> TrainConfigSnapshot {
    TrainConfigSnapshot {
        revision: trenino_core::Revision(0),
        train_id: EntityId(train_id),
        train_name: format!("Train {train_id}"),
        elements: Vec::new(),
        lever_bindings: vec![LeverBindingInfo {
            binding_id: EntityId(100 + train_id),
            input_id: EntityId(42),
            input_device: Some(EntityId(9)),
            lever_config_id: EntityId(50 + train_id),
            value_endpoint: THROTTLE.to_owned(),
            inverted: false,
            notches: vec![Notch {
                kind: NotchType::Linear,
                input_min: Some(0.0),
                input_max: Some(1.0),
                sim_input_min: Some(0.0),
                sim_input_max: Some(1.0),
            }],
            calibration: Some(Calibration {
                min_value: 0,
                max_value: 1000,
                max_hardware_value: 1023,
                inverted: false,
                rollover: false,
            }),
        }],
        button_bindings: Vec::new(),
        scripts: Vec::new(),
    }
}

struct Harness {
    service: TrainServiceHandle,
    events: tokio::sync::mpsc::Receiver<TrainEvent>,
    sim: ScriptedSim,
    clock: FakeClock,
    config: FakeConfig,
    routing: Arc<RoutingService>,
    keystrokes: Arc<FakeKeystrokes>,
}

fn harness(sim: ScriptedSim) -> Harness {
    let clock = FakeClock::new();
    let config = FakeConfig::new();
    let resolver = Arc::new(InputResolver::default());
    resolver.replace_port(
        "COM1",
        1,
        ConfigId::new(11).unwrap(),
        [(
            2,
            InputIdentity {
                device_id: EntityId(9),
                input_id: EntityId(42),
            },
        ),(
            5,
            InputIdentity {
                device_id: EntityId(9),
                input_id: EntityId(43),
            },
        )],
    );
    let arbiter = Arc::new(ResourceArbiter::new(Arc::new(NoopConsumers)));
    let routing = Arc::new(RoutingService::new(resolver.clone(), arbiter));
    let keystrokes = Arc::new(FakeKeystrokes::default());
    let (service, events) = TrainServiceHandle::start(
        Arc::new(clock.clone()),
        config.source(),
        routing.clone(),
        resolver,
        keystrokes.clone(),
    );
    Harness {
        service,
        events,
        sim,
        clock,
        config,
        routing,
        keystrokes,
    }
}

/// Step fake time in 200ms grace-probe increments, yielding between steps so
/// the monitor worker completes each probe's HTTP round trips before the next
/// deadline passes (mirrors how simulator_detection.rs drives grace tests).
async fn advance_grace(clock: &FakeClock, total: Duration) {
    let mut remaining = total;
    while remaining > Duration::ZERO {
        let step = remaining.min(Duration::from_millis(200));
        clock.advance(step);
        tokio::time::sleep(Duration::from_millis(2)).await;
        remaining -= step;
    }
}

fn client(sim: &ScriptedSim) -> Arc<SimulatorClient> {
    Arc::new(SimulatorClient::new(&sim.url(), "test-key").unwrap())
}

fn connect(harness: &Harness) {
    harness.sim.state.lock().unwrap().drivable_index = Some(0);
}

async fn next_event(harness: &mut Harness) -> TrainEvent {
    yield_until(|| harness.events.try_recv().ok()).await
}

async fn expect_event(harness: &mut Harness, expected: &TrainEvent) {
    let event = next_event(harness).await;
    assert_eq!(&event, expected, "unexpected service event");
}

async fn expect_no_event(harness: &mut Harness) {
    settle().await;
    assert!(
        harness.events.try_recv().is_err(),
        "unexpected trailing service event"
    );
}

fn lever_input(harness: &Harness, value: i16) {
    harness
        .service
        .lever()
        .try_input(LeverSample {
            port: "COM1".to_owned(),
            port_generation: 1,
            config_id: ConfigId::new(11).unwrap(),
            pin: 2,
            value,
        })
        .unwrap();
}

fn button_input(harness: &Harness, value: i16) {
    harness
        .service
        .buttons()
        .try_input(ButtonSample {
            port: "COM1".to_owned(),
            port_generation: 1,
            config_id: ConfigId::new(11).unwrap(),
            pin: 5,
            value,
        })
        .unwrap();
}

/// Mirrors "enables polling on connect" plus the matching flow
/// (detection_test.exs:73-88; detection.ex:248-303): connect → identifier
/// derived and normalized (`_C` stripped) → unique match → activation with a
/// committed routing revision, and the lever write path live.
#[tokio::test]
async fn activation_commits_routing_and_loads_controllers() {
    let sim = ScriptedSim::spawn();
    sim.state.lock().unwrap().object_class = Some("RVM_PBO_Class142_DMSL_C".to_owned());
    let mut harness = harness(sim.clone());
    harness.config.commit(
        profile(7, "Class 142", &["RVM_PBO_Class142"]),
        Some(snapshot(7)),
    );
    connect(&harness);
    harness.service.simulator_connected(client(&sim)).await.unwrap();

    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_PBO_Class142_DMSL".to_owned(),
            train_id: Some(EntityId(7)),
        },
    )
    .await;
    expect_event(&mut harness, &TrainEvent::TrainChanged(Some(EntityId(7)))).await;

    yield_until(|| {
        let snapshot = harness.service.snapshot();
        (snapshot.active_train_id == Some(EntityId(7)) && snapshot.active_revision.is_some())
            .then_some(snapshot)
    })
    .await;
    let snapshot = harness.service.snapshot();
    assert_eq!(snapshot.detected_identifier.as_deref(), Some("RVM_PBO_Class142_DMSL"));
    assert!(snapshot.ambiguous_candidates.is_empty());
    // RoutingService convergence: desired == active, no degraded reasons.
    assert_eq!(snapshot.desired_revision, snapshot.active_revision);
    assert!(harness.routing.degraded_reasons().is_empty());

    // The lever controller is live: an input sample reaches the simulator.
    lever_input(&harness, 500);
    yield_until(|| (sim.set_values().len() >= 1).then_some(())).await;
    assert_eq!(sim.set_values()[0], (THROTTLE.to_owned(), 0.5));

    harness.service.shutdown().await.unwrap();
}

/// Mirrors the drivable-index fallback ("falls back to index 0 when
/// DrivableIndex request fails", identifier_test.exs:127-149) through the
/// coordinator: the ObjectClass at index 0 identifies the train.
#[tokio::test]
async fn activation_falls_back_to_formation_index_zero() {
    let sim = ScriptedSim::spawn();
    sim.state.lock().unwrap().object_class = Some("RVM_Train_Class_C".to_owned());
    // DrivableIndex stays unset → the fake answers 500 → fallback to index 0.
    let mut harness = harness(sim.clone());
    harness.config.commit(
        profile(7, "Class", &["RVM_Train_Class"]),
        Some(snapshot(7)),
    );
    harness.service.simulator_connected(client(&sim)).await.unwrap();

    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_Train_Class".to_owned(),
            train_id: Some(EntityId(7)),
        },
    )
    .await;
    expect_event(&mut harness, &TrainEvent::TrainChanged(Some(EntityId(7)))).await;
    harness.service.shutdown().await.unwrap();
}

/// Mirrors the ambiguity contract (train_identifier_matching_test.exs:41-49;
/// detection.ex:283-302): overlapping identifiers across two profiles match
/// ambiguously, so the active train is deactivated instead of choosing the
/// longest prefix.
#[tokio::test]
async fn ambiguous_detection_deactivates_routing() {
    let sim = ScriptedSim::spawn();
    sim.state.lock().unwrap().object_class = Some("RVM_DB_BR423_C".to_owned());
    let mut harness = harness(sim.clone());
    harness.config.commit(profile(7, "BR 423", &["RVM_DB_BR423"]), Some(snapshot(7)));
    harness.config.commit(
        profile(8, "BR 423 Red", &["RVM_DB_BR423_RED"]),
        Some(snapshot(8)),
    );
    connect(&harness);
    harness.service.simulator_connected(client(&sim)).await.unwrap();
    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_DB_BR423".to_owned(),
            train_id: Some(EntityId(7)),
        },
    )
    .await;
    expect_event(&mut harness, &TrainEvent::TrainChanged(Some(EntityId(7)))).await;
    yield_until(|| harness.service.snapshot().active_revision.is_some().then_some(())).await;

    // The formation changes to a variant matching BOTH profiles: ambiguity
    // deactivates instead of choosing the longest prefix.
    sim.state.lock().unwrap().object_class = Some("RVM_DB_BR423_RED_VARIANT_C".to_owned());
    harness.clock.advance(Duration::from_secs(5));

    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_DB_BR423_RED_VARIANT".to_owned(),
            train_id: None,
        },
    )
    .await;
    expect_event(
        &mut harness,
        &TrainEvent::MultipleTrainsMatch {
            identifier: "RVM_DB_BR423_RED_VARIANT".to_owned(),
            trains: vec![EntityId(7), EntityId(8)],
        },
    )
    .await;
    expect_event(&mut harness, &TrainEvent::TrainChanged(None)).await;

    yield_until(|| {
        (harness.service.snapshot().active_train_id.is_none()).then_some(())
    })
    .await;
    let snapshot = harness.service.snapshot();
    assert_eq!(snapshot.ambiguous_candidates, vec![EntityId(7), EntityId(8)]);
    // Identifier-driven deactivation keeps the fresh identifier (Elixir
    // semantics: current_identifier is set, active_train is nil).
    assert_eq!(
        snapshot.detected_identifier.as_deref(),
        Some("RVM_DB_BR423_RED_VARIANT")
    );
    // The routing service released the old train's desired routes.
    assert_eq!(harness.routing.snapshot().train_id, None);

    // Controllers are released: an input sample writes nothing.
    lever_input(&harness, 500);
    settle().await;
    assert!(sim.set_values().is_empty());
    harness.service.shutdown().await.unwrap();
}

/// Mirrors "clears state and broadcasts train_changed nil on disconnect" /
/// "no grace period when no active train" (detection_test.exs:54-71,
/// 315-330): disconnect without an active train deactivates immediately.
#[tokio::test]
async fn disconnect_without_active_train_deactivates_immediately() {
    let sim = ScriptedSim::spawn();
    sim.state.lock().unwrap().object_class = Some("RVM_Unknown_Thing_C".to_owned());
    let mut harness = harness(sim.clone());
    connect(&harness);
    harness.service.simulator_connected(client(&sim)).await.unwrap();

    // Unknown identifier: no active train.
    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_Unknown_Thing".to_owned(),
            train_id: None,
        },
    )
    .await;

    harness.service.simulator_disconnected().await.unwrap();
    // `deactivate_train/1` broadcasts `{:train_changed, nil}` unconditionally
    // (detection_test.exs:54-71, 315-330) and clears the identifier.
    expect_event(&mut harness, &TrainEvent::TrainChanged(None)).await;
    expect_no_event(&mut harness).await;
    assert_eq!(harness.service.snapshot().detected_identifier, None);
    harness.service.shutdown().await.unwrap();
}

/// Mirrors the grace-period suite (detection_test.exs:134-330): disconnect
/// keeps the active train, 200ms probes extend the 30s grace, and expiry
/// deactivates through the routing service.
#[tokio::test]
async fn grace_period_keeps_train_then_expires() {
    let sim = ScriptedSim::spawn();
    sim.state.lock().unwrap().object_class = Some("RVM_PBO_Class142_DMSL_C".to_owned());
    let mut harness = harness(sim.clone());
    harness.config.commit(
        profile(7, "Class 142", &["RVM_PBO_Class142"]),
        Some(snapshot(7)),
    );
    connect(&harness);
    harness.service.simulator_connected(client(&sim)).await.unwrap();
    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_PBO_Class142_DMSL".to_owned(),
            train_id: Some(EntityId(7)),
        },
    )
    .await;
    expect_event(&mut harness, &TrainEvent::TrainChanged(Some(EntityId(7)))).await;
    // Wait for the activation commit before disconnecting.
    yield_until(|| harness.service.snapshot().active_revision.is_some().then_some(())).await;
    let active_revision = harness.service.snapshot().desired_revision;

    harness.service.simulator_disconnected().await.unwrap();

    // Successful probes for 20s of fake time: the train stays active and no
    // further events fire.
    advance_grace(&harness.clock, Duration::from_secs(20)).await;
    settle().await;
    assert_eq!(harness.service.snapshot().active_train_id, Some(EntityId(7)));
    assert_eq!(harness.service.snapshot().desired_revision, active_revision);
    assert!(harness.events.try_recv().is_err());

    // Probes start failing; 30s after the last successful contact the grace
    // expires and the train deactivates.
    sim.state.lock().unwrap().object_class_fails = true;
    advance_grace(&harness.clock, Duration::from_secs(15)).await;
    settle().await;
    assert_eq!(harness.service.snapshot().active_train_id, Some(EntityId(7)));
    advance_grace(&harness.clock, Duration::from_secs(16)).await;
    expect_event(&mut harness, &TrainEvent::TrainChanged(None)).await;
    let snapshot = harness.service.snapshot();
    assert_eq!(snapshot.active_train_id, None);
    assert_eq!(snapshot.detected_identifier, None);
    // Deactivation committed a fresh desired revision with no train.
    assert!(snapshot.desired_revision > active_revision);
    let routing = harness.routing.snapshot();
    assert_eq!(routing.train_id, None);

    lever_input(&harness, 500);
    settle().await;
    assert!(sim.set_values().is_empty());
    harness.service.shutdown().await.unwrap();
}

/// Mirrors "connection recovery during grace exits grace cleanly"
/// (detection_test.exs:248-280): the train profile survives the outage and
/// polling resumes without duplicate poll loops.
#[tokio::test]
async fn grace_recovery_preserves_profile_and_resumes_polling() {
    let sim = ScriptedSim::spawn();
    sim.state.lock().unwrap().object_class = Some("RVM_PBO_Class142_DMSL_C".to_owned());
    let mut harness = harness(sim.clone());
    harness.config.commit(
        profile(7, "Class 142", &["RVM_PBO_Class142"]),
        Some(snapshot(7)),
    );
    connect(&harness);
    harness.service.simulator_connected(client(&sim)).await.unwrap();
    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_PBO_Class142_DMSL".to_owned(),
            train_id: Some(EntityId(7)),
        },
    )
    .await;
    expect_event(&mut harness, &TrainEvent::TrainChanged(Some(EntityId(7)))).await;
    yield_until(|| harness.service.snapshot().active_revision.is_some().then_some(())).await;
    let baseline_revision = harness.service.snapshot().desired_revision;

    harness.service.simulator_disconnected().await.unwrap();
    advance_grace(&harness.clock, Duration::from_secs(2)).await;
    harness.service.simulator_connected(client(&sim)).await.unwrap();

    // The same identifier re-detects: no change events, no re-activation.
    expect_no_event(&mut harness).await;
    assert_eq!(harness.service.snapshot().active_train_id, Some(EntityId(7)));
    assert_eq!(
        harness.service.snapshot().desired_revision,
        baseline_revision,
        "grace recovery must not re-commit routing"
    );

    // Polling resumed with exactly one 5s loop: advancing 10s yields two
    // polls (each still matching the same identifier → silent).
    let formation_gets = sim
        .log()
        .iter()
        .filter(|request| request.method == "GET")
        .count();
    harness.clock.advance(Duration::from_secs(10));
    settle().await;
    harness.clock.advance(Duration::from_secs(5));
    settle().await;
    let after = sim
        .log()
        .iter()
        .filter(|request| request.method == "GET")
        .count();
    assert!(after > formation_gets, "polling did not resume after recovery");
    assert!(harness.events.try_recv().is_err(), "duplicate poll loops");
    harness.service.shutdown().await.unwrap();
}

/// Controls-plan regression — activation race / train switch cleanup
/// (review focus 1): a blocked write of the old train is aborted when the
/// switch happens, its late completion never lands, and the new train's
/// controller takes over.
#[tokio::test]
async fn train_switch_aborts_obsolete_writers_before_activation() {
    let sim = ScriptedSim::spawn();
    sim.state.lock().unwrap().object_class = Some("RVM_PBO_Class142_DMSL_C".to_owned());
    let mut harness = harness(sim.clone());
    harness.config.commit(
        profile(7, "Class 142", &["RVM_PBO_Class142"]),
        Some(snapshot(7)),
    );
    harness.config.commit(
        profile(8, "DB BR 430", &["RVM_FSN_DB_BR430"]),
        Some(snapshot(8)),
    );
    connect(&harness);
    harness.service.simulator_connected(client(&sim)).await.unwrap();
    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_PBO_Class142_DMSL".to_owned(),
            train_id: Some(EntityId(7)),
        },
    )
    .await;
    expect_event(&mut harness, &TrainEvent::TrainChanged(Some(EntityId(7)))).await;
    yield_until(|| harness.service.snapshot().active_revision.is_some().then_some(())).await;

    // Start a blocked write for train A.
    let gate = sim.gate(THROTTLE);
    lever_input(&harness, 500);
    gate.await_entered().await;

    // Switch trains: the next poll detects train B.
    sim.state.lock().unwrap().object_class = Some("RVM_FSN_DB_BR430_C".to_owned());
    harness.clock.advance(Duration::from_secs(5));
    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_FSN_DB_BR430".to_owned(),
            train_id: Some(EntityId(8)),
        },
    )
    .await;
    expect_event(&mut harness, &TrainEvent::TrainChanged(Some(EntityId(8)))).await;
    yield_until(|| {
        (harness.service.snapshot().active_train_id == Some(EntityId(8))).then_some(())
    })
    .await;

    // The obsolete writer was aborted: releasing the gate only fails the
    // dead request; no completion touches the new train's state.
    gate.fail();
    settle().await;
    let state = harness.service.lever().state().await.unwrap();
    assert_eq!(state.pending, 0);
    assert_eq!(state.inflight, 0);

    // The new train drives the simulator.
    lever_input(&harness, 900);
    yield_until(|| (sim.set_values().len() >= 2).then_some(())).await;
    assert_eq!(sim.set_values()[1], (THROTTLE.to_owned(), 0.9));
    harness.service.shutdown().await.unwrap();
}

/// Mirrors the manual-sync flow (detection.ex:137-147; "manual sync after
/// CRUD"): editing the committed configuration and syncing reloads the
/// controllers at the new revision without a train change event.
#[tokio::test]
async fn manual_sync_after_crud_reloads_committed_configuration() {
    let sim = ScriptedSim::spawn();
    sim.state.lock().unwrap().object_class = Some("RVM_PBO_Class142_DMSL_C".to_owned());
    let mut harness = harness(sim.clone());
    harness.config.commit(
        profile(7, "Class 142", &["RVM_PBO_Class142"]),
        Some(snapshot(7)),
    );
    connect(&harness);
    harness.service.simulator_connected(client(&sim)).await.unwrap();
    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_PBO_Class142_DMSL".to_owned(),
            train_id: Some(EntityId(7)),
        },
    )
    .await;
    expect_event(&mut harness, &TrainEvent::TrainChanged(Some(EntityId(7)))).await;
    yield_until(|| harness.service.snapshot().active_revision.is_some().then_some(())).await;

    // A button input before the CRUD writes nothing.
    button_input(&harness, 1);
    settle().await;
    assert!(sim.set_values().is_empty());

    // CRUD: add an enabled button binding (bumps the committed revision).
    let mut updated = snapshot(7);
    updated.button_bindings.push(ButtonBindingInfo {
        binding_id: EntityId(200),
        element_id: EntityId(5),
        input_id: EntityId(43),
        input_device: Some(EntityId(9)),
        endpoint: Some(HORN.to_owned()),
        on_value: 1.0,
        off_value: 0.0,
        mode: ButtonMode::Simple,
        hardware_type: ButtonHardwareType::Momentary,
        repeat_interval_ms: 100,
        keystroke: None,
        on_sequence: None,
        off_sequence: None,
    });
    harness
        .config
        .commit(profile(7, "Class 142", &["RVM_PBO_Class142"]), Some(updated));

    let revision_before_sync = harness.service.snapshot().desired_revision.unwrap();
    harness.service.sync().await.unwrap();
    // Re-detection with the cleared identifier re-broadcasts TrainDetected;
    // the train did not change, so no TrainChanged fires.
    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_PBO_Class142_DMSL".to_owned(),
            train_id: Some(EntityId(7)),
        },
    )
    .await;

    // The new committed revision landed in the routing service and the
    // controllers reloaded from the fresh snapshot.
    yield_until(|| {
        let snapshot = harness.service.snapshot();
        (snapshot.desired_revision > Some(revision_before_sync)
            && snapshot.active_revision == snapshot.desired_revision
            && snapshot.active_revision.is_some())
        .then_some(())
    })
    .await;
    assert!(
        harness.service.snapshot().desired_revision > Some(revision_before_sync),
        "the committed CRUD revision never activated"
    );
    let revision_after_sync = harness.service.snapshot().desired_revision;
    button_input(&harness, 1);
    yield_until(|| (sim.set_values().len() >= 1).then_some(())).await;
    assert_eq!(sim.set_values()[0], (HORN.to_owned(), 1.0));
    // The press's own `button_state_changed` broadcast is merged into the
    // event stream; sync itself must not emit anything else (no TrainChanged).
    settle().await;
    while let Ok(event) = harness.events.try_recv() {
        assert!(
            matches!(event, TrainEvent::ButtonStateChanged(_)),
            "sync must not emit {event:?}"
        );
    }

    // Syncing again without CRUD is a no-op: no reload, revision stable.
    harness.service.sync().await.unwrap();
    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_PBO_Class142_DMSL".to_owned(),
            train_id: Some(EntityId(7)),
        },
    )
    .await;
    settle().await;
    assert_eq!(
        harness.service.snapshot().desired_revision,
        revision_after_sync
    );
    harness.service.shutdown().await.unwrap();
}

/// Controls-plan regression — canceled callers: shutdown with an in-flight
/// write and a held keystroke releases the owner and stops all workers.
#[tokio::test]
async fn shutdown_releases_held_state_and_stops_writers() {
    let sim = ScriptedSim::spawn();
    sim.state.lock().unwrap().object_class = Some("RVM_PBO_Class142_DMSL_C".to_owned());
    let mut harness = harness(sim.clone());
    let mut snap = snapshot(7);
    snap.button_bindings.push(ButtonBindingInfo {
        binding_id: EntityId(200),
        element_id: EntityId(5),
        input_id: EntityId(43),
        input_device: Some(EntityId(9)),
        endpoint: None,
        on_value: 1.0,
        off_value: 0.0,
        mode: ButtonMode::Keystroke,
        hardware_type: ButtonHardwareType::Momentary,
        repeat_interval_ms: 100,
        keystroke: Some("W".to_owned()),
        on_sequence: None,
        off_sequence: None,
    });
    harness.config.commit(
        profile(7, "Class 142", &["RVM_PBO_Class142"]),
        Some(snap),
    );
    connect(&harness);
    harness.service.simulator_connected(client(&sim)).await.unwrap();
    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_PBO_Class142_DMSL".to_owned(),
            train_id: Some(EntityId(7)),
        },
    )
    .await;
    expect_event(&mut harness, &TrainEvent::TrainChanged(Some(EntityId(7)))).await;
    yield_until(|| harness.service.snapshot().active_revision.is_some().then_some(())).await;

    // Hold a key and block a lever write.
    button_input(&harness, 1);
    let gate = sim.gate(THROTTLE);
    lever_input(&harness, 500);
    gate.await_entered().await;

    harness.service.shutdown().await.unwrap();
    gate.fail();
    settle().await;
    let calls = harness.keystrokes.calls();
    assert!(
        calls.iter().any(|call| call.action == "owner_gone"),
        "shutdown must release held keystrokes"
    );
    let state_calls = sim.set_values();
    assert_eq!(state_calls.len(), 1, "the aborted write never completed");
}

/// Mirrors "matches detected identifier to stored train configuration"
/// (detection_test.exs:115-132) plus sequence wiring through the service:
/// an activated train's button sequence drives the simulator in order.
#[tokio::test]
async fn activated_train_runs_sequences_through_the_service() {
    let sim = ScriptedSim::spawn();
    sim.state.lock().unwrap().object_class = Some("RVM_PBO_Class142_DMSL_C".to_owned());
    let mut harness = harness(sim.clone());
    let mut snap = snapshot(7);
    snap.button_bindings.push(ButtonBindingInfo {
        binding_id: EntityId(200),
        element_id: EntityId(5),
        input_id: EntityId(43),
        input_device: Some(EntityId(9)),
        endpoint: None,
        on_value: 1.0,
        off_value: 0.0,
        mode: ButtonMode::Sequence,
        hardware_type: ButtonHardwareType::Momentary,
        repeat_interval_ms: 100,
        keystroke: None,
        on_sequence: Some(vec![
            SequenceCommand {
                endpoint: "DoorKey.InputValue".to_owned(),
                value: 1.0,
                delay_ms: 100,
            },
            SequenceCommand {
                endpoint: "DoorOpen.InputValue".to_owned(),
                value: 1.0,
                delay_ms: 0,
            },
        ]),
        off_sequence: None,
    });
    harness.config.commit(
        profile(7, "Class 142", &["RVM_PBO_Class142"]),
        Some(snap),
    );
    connect(&harness);
    harness.service.simulator_connected(client(&sim)).await.unwrap();
    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_PBO_Class142_DMSL".to_owned(),
            train_id: Some(EntityId(7)),
        },
    )
    .await;
    expect_event(&mut harness, &TrainEvent::TrainChanged(Some(EntityId(7)))).await;
    yield_until(|| harness.service.snapshot().active_revision.is_some().then_some(())).await;

    button_input(&harness, 1);
    // The press broadcast arrives through the service event stream.
    let broadcast = next_event(&mut harness).await;
    match broadcast {
        TrainEvent::ButtonStateChanged(change) => {
            assert_eq!(change.element_id, EntityId(5));
            assert!(change.pressed);
        }
        other => panic!("expected button broadcast, got {other:?}"),
    }
    yield_until(|| (sim.set_paths().len() >= 1).then_some(())).await;
    advance_until(&harness.clock, Duration::from_millis(20), || {
        (sim.set_paths().len() >= 2).then_some(())
    })
    .await;
    assert_eq!(sim.set_paths(), ["DoorKey.InputValue", "DoorOpen.InputValue"]);
    harness.service.shutdown().await.unwrap();
}

/// Deactivated then re-detected trains re-activate cleanly at a new revision
/// (grace expiry recovery into a fresh activation).
#[tokio::test]
async fn reactivation_after_deactivation_commits_fresh_revision() {
    let sim = ScriptedSim::spawn();
    sim.state.lock().unwrap().object_class = Some("RVM_PBO_Class142_DMSL_C".to_owned());
    let mut harness = harness(sim.clone());
    harness.config.commit(
        profile(7, "Class 142", &["RVM_PBO_Class142"]),
        Some(snapshot(7)),
    );
    connect(&harness);
    harness.service.simulator_connected(client(&sim)).await.unwrap();
    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_PBO_Class142_DMSL".to_owned(),
            train_id: Some(EntityId(7)),
        },
    )
    .await;
    expect_event(&mut harness, &TrainEvent::TrainChanged(Some(EntityId(7)))).await;
    yield_until(|| harness.service.snapshot().active_revision.is_some().then_some(())).await;
    let first_revision = harness.service.snapshot().desired_revision.unwrap();

    // Lose the train (unknown identifier), then re-detect it.
    sim.state.lock().unwrap().object_class = Some("RVM_Elsewhere_C".to_owned());
    harness.clock.advance(Duration::from_secs(5));
    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_Elsewhere".to_owned(),
            train_id: None,
        },
    )
    .await;
    expect_event(&mut harness, &TrainEvent::TrainChanged(None)).await;

    sim.state.lock().unwrap().object_class = Some("RVM_PBO_Class142_DMSL_C".to_owned());
    harness.clock.advance(Duration::from_secs(5));
    expect_event(
        &mut harness,
        &TrainEvent::TrainDetected {
            identifier: "RVM_PBO_Class142_DMSL".to_owned(),
            train_id: Some(EntityId(7)),
        },
    )
    .await;
    expect_event(&mut harness, &TrainEvent::TrainChanged(Some(EntityId(7)))).await;
    yield_until(|| {
        (harness.service.snapshot().active_train_id == Some(EntityId(7))).then_some(())
    })
    .await;
    let second_revision = harness.service.snapshot().desired_revision.unwrap();
    assert!(second_revision > first_revision);

    lever_input(&harness, 900);
    yield_until(|| (sim.set_values().len() >= 1).then_some(())).await;
    assert_eq!(sim.set_values()[0], (THROTTLE.to_owned(), 0.9));
    harness.service.shutdown().await.unwrap();
}
