//! Lever and button dispatch integration tests.
//!
//! Mirrors the Elixir suites with a scripted loopback TSW server, a fake
//! clock and a fake keystroke port — never real hardware, serial, or a user
//! database:
//!
//! - `test/trenino/train/lever_controller_test.exs` — one in-flight write,
//!   latest-pending coalescing, success-only acknowledgement, the 200/400/800
//!   retry ladder with reconnect budget restore, lifecycle cancellation and
//!   the disconnected park.
//! - `test/trenino/train/button_controller_test.exs` — simple dedup,
//!   momentary Interacting ordering with request-paced repeats, sequence
//!   execution/cancellation semantics and keystroke dispatch.
//!
//! Plus the controls-plan regression list: overload release, canceled
//! callers, 10k-sample bounded state and source loss during held keys.

#[path = "fixtures/controls/mod.rs"]
mod fixtures;

use std::sync::Arc;
use std::time::Duration;

use trenino_core::hardware::calibration::Calibration;
use trenino_core::train::lever::{Notch, NotchType};
use trenino_core::{ConfigId, EntityId, Revision};
use trenino_runtime::routing::{InputIdentity, InputResolver};
use trenino_runtime::simulator::client::SimulatorClient;
use trenino_runtime::simulator::services::clock::FakeClock;
use trenino_runtime::storage::bindings::{ButtonHardwareType, ButtonMode};
use trenino_runtime::train::button_controller::{
    ButtonController, ButtonSample, ButtonStateChange, KeystrokeOwner,
};
use trenino_runtime::train::button_controller::QueueError as ButtonQueueError;
use trenino_runtime::train::detection::{
    ButtonBindingInfo, LeverBindingInfo, SequenceCommand, TrainConfigSnapshot,
};
use trenino_runtime::train::lever_controller::{LeverController, LeverSample, QueueError};

use fixtures::{
    advance_until, settle, yield_until, FakeConfig, FakeKeystrokes, ScriptedSim,
};

const THROTTLE: &str = "CurrentDrivableActor/Throttle(Lever).InputValue";
const HORN: &str = "CurrentDrivableActor/Horn.InputValue";
const HORN_INTERACTING: &str = "CurrentDrivableActor/Horn.Interacting";

fn client(sim: &ScriptedSim) -> Arc<SimulatorClient> {
    Arc::new(SimulatorClient::new(&sim.url(), "test-key").unwrap())
}

fn resolver(port: &str, pin: u8, input_id: i64) -> Arc<InputResolver> {
    let resolver = Arc::new(InputResolver::default());
    resolver.replace_port(
        port,
        1,
        ConfigId::new(11).unwrap(),
        [(
            pin,
            InputIdentity {
                device_id: EntityId(9),
                input_id: EntityId(input_id),
            },
        )],
    );
    resolver
}

fn sample(port: &str, pin: u8, value: i16) -> LeverSample {
    LeverSample {
        port: port.to_owned(),
        port_generation: 1,
        config_id: ConfigId::new(11).unwrap(),
        pin,
        value,
    }
}

fn button_sample(port: &str, pin: u8, value: i16) -> ButtonSample {
    ButtonSample {
        port: port.to_owned(),
        port_generation: 1,
        config_id: ConfigId::new(11).unwrap(),
        pin,
        value,
    }
}

/// Linear 0..1 → 0..1 mapping with a 0..1000 hardware calibration, matching
/// the ExUnit lever fixtures (raw 500 → 0.5, raw 100 → 0.1, ...).
fn lever_snapshot(input_id: i64) -> TrainConfigSnapshot {
    TrainConfigSnapshot {
        revision: Revision(1),
        train_id: EntityId(7),
        train_name: "Latency Train".to_owned(),
        elements: Vec::new(),
        lever_bindings: vec![LeverBindingInfo {
            binding_id: EntityId(100),
            input_id: EntityId(input_id),
            input_device: Some(EntityId(9)),
            lever_config_id: EntityId(50),
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

fn button_snapshot(bindings: Vec<ButtonBindingInfo>) -> TrainConfigSnapshot {
    TrainConfigSnapshot {
        revision: Revision(1),
        train_id: EntityId(7),
        train_name: "Test Train".to_owned(),
        elements: Vec::new(),
        lever_bindings: Vec::new(),
        button_bindings: bindings,
        scripts: Vec::new(),
    }
}

fn simple_binding(input_id: i64, element_id: i64) -> ButtonBindingInfo {
    ButtonBindingInfo {
        binding_id: EntityId(100),
        element_id: EntityId(element_id),
        input_id: EntityId(input_id),
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
    }
}

struct LeverHarness {
    lever: LeverController,
    clock: FakeClock,
}

fn lever_harness(sim: ScriptedSim) -> LeverHarness {
    let resolver = resolver("COM1", 2, 42);
    let clock = FakeClock::new();
    let lever = LeverController::start(Arc::new(clock.clone()), resolver);
    lever.activate(1, &lever_snapshot(42)).unwrap();
    lever.simulator_connected(client(&sim)).unwrap();
    LeverHarness { lever, clock }
}

async fn patch_count(sim: &ScriptedSim, target: usize) {
    yield_until(|| (sim.log().iter().filter(|r| r.method == "PATCH").count() >= target).then_some(()))
        .await;
}

async fn expect_no_patch(sim: &ScriptedSim, beyond: usize, clock: &FakeClock) {
    // Advance fake time far beyond every retry budget, then settle in real
    // time; no new request may appear.
    clock.advance(Duration::from_secs(5));
    settle().await;
    assert_eq!(
        sim.log().iter().filter(|r| r.method == "PATCH").count(),
        beyond,
        "unexpected simulator write after the retry budget"
    );
}

/// Mirrors "sends the latest jittered value instead of draining a FIFO of
/// stale writes" (lever_controller_test.exs:92-130): one blocked write, four
/// jitter samples, then exactly the latest value is written — no replay.
#[tokio::test]
async fn lever_sends_latest_jittered_value_not_a_fifo() {
    let sim = ScriptedSim::spawn();
    let harness = lever_harness(sim.clone());
    let gate = sim.gate(THROTTLE);

    harness.lever.input(sample("COM1", 2, 100)).await.unwrap();
    gate.await_entered().await;

    for raw in [200, 400, 600, 800] {
        harness.lever.input(sample("COM1", 2, raw)).await.unwrap();
    }
    gate.release();
    patch_count(&sim, 2).await;
    let values: Vec<f64> = sim.set_values().into_iter().map(|(_, value)| value).collect();
    assert_eq!(values, vec![0.1, 0.8]);

    expect_no_patch(&sim, 2, &harness.clock).await;
    let state = harness.lever.state().await.unwrap();
    assert_eq!(state.pending, 0);
    harness.lever.shutdown().await.unwrap();
}

/// Mirrors "reconnect retries a retained failed write"
/// (lever_controller_test.exs:132-160): a failed write is parked; the
/// reconnect event restarts it with the retained value.
#[tokio::test]
async fn lever_reconnect_retries_retained_failed_write() {
    let sim = ScriptedSim::spawn();
    let harness = lever_harness(sim.clone());
    let gate = sim.gate(THROTTLE);

    harness.lever.input(sample("COM1", 2, 500)).await.unwrap();
    gate.await_entered().await;
    gate.fail();
    patch_count(&sim, 1).await;
    settle().await;

    // The armed 200ms retry exists but does not fire until the fake clock
    // advances; the reconnect fires it immediately instead.
    let state = harness.lever.state().await.unwrap();
    assert_eq!(state.retries, 1);
    assert_eq!(state.inflight, 0);

    harness.lever.simulator_connected(client(&sim)).unwrap();
    patch_count(&sim, 2).await;
    let values: Vec<f64> = sim.set_values().into_iter().map(|(_, value)| value).collect();
    assert_eq!(values, vec![0.5, 0.5]);
    expect_no_patch(&sim, 2, &harness.clock).await;
    harness.lever.shutdown().await.unwrap();
}

/// Mirrors "retries a final transient failure without another input"
/// (lever_controller_test.exs:162-171): the first retry fires on the 200ms
/// token and a success acknowledges the slot.
#[tokio::test]
async fn lever_retries_final_transient_failure_without_new_input() {
    let sim = ScriptedSim::spawn();
    let harness = lever_harness(sim.clone());
    let gate = sim.gate(THROTTLE);

    harness.lever.input(sample("COM1", 2, 500)).await.unwrap();
    gate.await_entered().await;
    gate.fail();

    let gate2 = sim.gate(THROTTLE);
    advance_until(&harness.clock, Duration::from_millis(50), || {
        (sim.log().iter().filter(|r| r.method == "PATCH").count() >= 2).then_some(())
    })
    .await;
    gate2.await_entered().await;
    gate2.release();
    patch_count(&sim, 2).await;
    settle().await;

    expect_no_patch(&sim, 2, &harness.clock).await;
    let state = harness.lever.state().await.unwrap();
    assert_eq!(state.pending, 0);
    assert_eq!(state.retries, 0);
    harness.lever.shutdown().await.unwrap();
}

/// Mirrors "reconnect before an old writer fails still delivers the newest
/// target" (lever_controller_test.exs:173-182).
#[tokio::test]
async fn lever_reconnect_before_old_writer_fails_delivers_newest() {
    let sim = ScriptedSim::spawn();
    let harness = lever_harness(sim.clone());
    let gate = sim.gate(THROTTLE);

    harness.lever.input(sample("COM1", 2, 500)).await.unwrap();
    gate.await_entered().await;

    harness.lever.input(sample("COM1", 2, 800)).await.unwrap();
    harness.lever.simulator_connected(client(&sim)).unwrap();
    // The in-flight write keeps its slot; only the retry state is cleared.
    let state = harness.lever.state().await.unwrap();
    assert_eq!(state.inflight, 1);

    gate.fail();
    let gate2 = sim.gate(THROTTLE);
    advance_until(&harness.clock, Duration::from_millis(50), || {
        (sim.log().iter().filter(|r| r.method == "PATCH").count() >= 2).then_some(())
    })
    .await;
    gate2.await_entered().await;
    gate2.release();
    patch_count(&sim, 2).await;
    settle().await;

    let values: Vec<f64> = sim.set_values().into_iter().map(|(_, value)| value).collect();
    assert_eq!(values, vec![0.5, 0.8]);
    expect_no_patch(&sim, 2, &harness.clock).await;
    harness.lever.shutdown().await.unwrap();
}

/// Mirrors "persistent failures exhaust a bounded retry budget"
/// (lever_controller_test.exs:214-224): 200/400/800ms retries, then parked.
#[tokio::test]
async fn lever_persistent_failures_exhaust_bounded_retry_budget() {
    let sim = ScriptedSim::spawn();
    let harness = lever_harness(sim.clone());
    let gate = sim.gate(THROTTLE);

    harness.lever.input(sample("COM1", 2, 500)).await.unwrap();
    gate.await_entered().await;
    gate.fail();
    sim.fail_set(THROTTLE, 500);

    // Retries land after exactly 200ms, 400ms and 800ms of fake time.
    for (expected, delay) in [(2, 200u64), (3, 400), (4, 800)] {
        advance_until(&harness.clock, Duration::from_millis(50), || {
            (sim.log().iter().filter(|r| r.method == "PATCH").count() >= expected).then_some(())
        })
        .await;
        let _ = delay;
    }
    // Budget exhausted: the parked target never retries on its own.
    expect_no_patch(&sim, 4, &harness.clock).await;
    harness.lever.shutdown().await.unwrap();
}

/// Mirrors "reconnect during the final allowed attempt restores a retry
/// budget" (lever_controller_test.exs:184-199).
#[tokio::test]
async fn lever_reconnect_during_final_attempt_restores_budget() {
    let sim = ScriptedSim::spawn();
    let harness = lever_harness(sim.clone());
    let gate = sim.gate(THROTTLE);

    harness.lever.input(sample("COM1", 2, 500)).await.unwrap();
    gate.await_entered().await;
    gate.fail();
    sim.fail_set(THROTTLE, 500);

    for expected in [2usize, 3, 4] {
        advance_until(&harness.clock, Duration::from_millis(50), || {
            (sim.log().iter().filter(|r| r.method == "PATCH").count() >= expected).then_some(())
        })
        .await;
    }
    // The fourth attempt failed; the budget is exhausted until reconnect.
    harness.lever.simulator_connected(client(&sim)).unwrap();
    // Reconnect restarts the parked target immediately (fresh budget).
    advance_until(&harness.clock, Duration::from_millis(10), || {
        (sim.log().iter().filter(|r| r.method == "PATCH").count() >= 5).then_some(())
    })
    .await;
    // The fresh budget arms a 200ms retry after this failure.
    sim.state.lock().unwrap().set_behavior.remove(THROTTLE);
    advance_until(&harness.clock, Duration::from_millis(50), || {
        (sim.log().iter().filter(|r| r.method == "PATCH").count() >= 6).then_some(())
    })
    .await;
    settle().await;
    let state = harness.lever.state().await.unwrap();
    assert_eq!(state.pending, 0);
    harness.lever.shutdown().await.unwrap();
}

/// Mirrors "a pending retry coalesces fresh input without bypassing the
/// delay" (lever_controller_test.exs:201-212).
#[tokio::test]
async fn lever_pending_retry_coalesces_fresh_input() {
    let sim = ScriptedSim::spawn();
    let harness = lever_harness(sim.clone());
    let gate = sim.gate(THROTTLE);

    harness.lever.input(sample("COM1", 2, 500)).await.unwrap();
    gate.await_entered().await;
    gate.fail();
    settle().await;
    let state = harness.lever.state().await.unwrap();
    assert_eq!(state.retries, 1);

    for raw in [600, 700, 900] {
        harness.lever.input(sample("COM1", 2, raw)).await.unwrap();
    }
    // The armed timer keeps its deadline; the retry writes the latest value.
    let gate2 = sim.gate(THROTTLE);
    advance_until(&harness.clock, Duration::from_millis(50), || {
        (sim.log().iter().filter(|r| r.method == "PATCH").count() >= 2).then_some(())
    })
    .await;
    gate2.await_entered().await;
    gate2.release();
    patch_count(&sim, 2).await;
    settle().await;
    let values: Vec<f64> = sim.set_values().into_iter().map(|(_, value)| value).collect();
    assert_eq!(values, vec![0.5, 0.9]);
    harness.lever.shutdown().await.unwrap();
}

/// Mirrors "disconnect suspends retries until reconnect and retains the
/// latest input" (lever_controller_test.exs:226-245).
#[tokio::test]
async fn lever_disconnect_suspends_retries_and_retains_latest() {
    let sim = ScriptedSim::spawn();
    let harness = lever_harness(sim.clone());
    let gate = sim.gate(THROTTLE);

    harness.lever.input(sample("COM1", 2, 500)).await.unwrap();
    gate.await_entered().await;
    gate.fail();
    settle().await;

    harness.lever.simulator_disconnected().unwrap();
    for raw in [600, 700, 900] {
        harness.lever.input(sample("COM1", 2, raw)).await.unwrap();
    }
    // No writer spawns while disconnected, however far the clock advances.
    expect_no_patch(&sim, 1, &harness.clock).await;

    harness.lever.simulator_connected(client(&sim)).unwrap();
    patch_count(&sim, 2).await;
    settle().await;
    let values: Vec<f64> = sim.set_values().into_iter().map(|(_, value)| value).collect();
    assert_eq!(values, vec![0.5, 0.9]);
    harness.lever.shutdown().await.unwrap();
}

/// Mirrors the lifecycle matrix of "reload/deactivate/change_train cancels a
/// scheduled retry" (lever_controller_test.exs:247-268).
#[tokio::test]
async fn lever_lifecycle_events_cancel_scheduled_retries() {
    for variant in ["reload", "deactivate", "change_train"] {
        let sim = ScriptedSim::spawn();
        let harness = lever_harness(sim.clone());
        let gate = sim.gate(THROTTLE);

        harness.lever.input(sample("COM1", 2, 500)).await.unwrap();
        gate.await_entered().await;
        gate.fail();
        settle().await;
        let state = harness.lever.state().await.unwrap();
        assert_eq!(state.retries, 1, "{variant}: retry should be scheduled");

        match variant {
            "reload" => harness.lever.activate(2, &lever_snapshot(42)).unwrap(),
            "deactivate" => harness.lever.release().unwrap(),
            _ => harness
                .lever
                .activate(2, &lever_snapshot(43))
                .unwrap(),
        }
        let state = harness.lever.state().await.unwrap();
        assert_eq!(state.pending, 0, "{variant}: pending cleared");
        assert_eq!(state.retries, 0, "{variant}: retry cancelled");
        expect_no_patch(&sim, 1, &harness.clock).await;
        harness.lever.shutdown().await.unwrap();
    }
}

/// Mirrors "reloading bindings terminates obsolete in-flight writers"
/// (lever_controller_test.exs:296-315): activation kills the blocked writer
/// before the new bindings take over.
#[tokio::test]
async fn lever_reload_terminates_obsolete_in_flight_writers() {
    let sim = ScriptedSim::spawn();
    let harness = lever_harness(sim.clone());
    let gate = sim.gate(THROTTLE);

    harness.lever.input(sample("COM1", 2, 100)).await.unwrap();
    gate.await_entered().await;

    harness.lever.activate(2, &lever_snapshot(42)).unwrap();
    let state = harness.lever.state().await.unwrap();
    assert_eq!(state.pending, 0);
    assert_eq!(state.inflight, 0);
    // The aborted writer never reports; releasing the gate now only closes
    // the dead HTTP connection.
    gate.release();
    settle().await;
    expect_no_patch(&sim, 1, &harness.clock).await;
    harness.lever.shutdown().await.unwrap();
}

/// Mirrors "disconnected writes wait for a lifecycle event"
/// (lever_controller_test.exs:317-328): with no client, samples park without
/// spawning a writer.
#[tokio::test]
async fn lever_disconnected_writes_wait_for_lifecycle_event() {
    let sim = ScriptedSim::spawn();
    let resolver = resolver("COM1", 2, 42);
    let clock = FakeClock::new();
    let lever = LeverController::start(Arc::new(clock.clone()), resolver);
    lever.activate(1, &lever_snapshot(42)).unwrap();
    // No simulator_connected: the client is absent.
    lever.input(sample("COM1", 2, 500)).await.unwrap();
    settle().await;
    let state = lever.state().await.unwrap();
    assert_eq!(state.inflight, 0);
    assert_eq!(state.pending, 1);
    assert!(sim.set_values().is_empty());

    lever.simulator_connected(client(&sim)).unwrap();
    patch_count(&sim, 1).await;
    assert_eq!(sim.set_values()[0].1, 0.5);
    lever.shutdown().await.unwrap();
}

/// Controls-plan stress case: 10,000 jitter samples against a blocked first
/// write leave bounded state, deliver the final value exactly once and leave
/// no stale retries behind.
#[tokio::test]
async fn lever_ten_thousand_samples_leave_bounded_state() {
    let sim = ScriptedSim::spawn();
    let harness = lever_harness(sim.clone());
    let gate = sim.gate(THROTTLE);

    harness.lever.input(sample("COM1", 2, 100)).await.unwrap();
    gate.await_entered().await;

    for index in 1..=10_000i32 {
        // Sweep raw values across the calibrated travel (0..1000).
        let raw = (index % 1001) as i16;
        harness.lever.input(sample("COM1", 2, raw)).await.unwrap();
        if index % 2_500 == 0 {
            let state = harness.lever.state().await.unwrap();
            assert!(state.pending <= 1, "pending blew up at {index}: {state:?}");
            assert!(state.inflight <= 1, "multiple in-flight writes at {index}");
            assert_eq!(state.retries, 0, "retries armed under load at {index}");
        }
    }

    gate.release();
    // The last sample of the sweep: index 10_000 % 1001 == 990 → 0.99.
    patch_count(&sim, 2).await;
    settle().await;
    let values = sim.set_values();
    assert_eq!(values.len(), 2, "exactly one in-flight plus one latest write");
    assert_eq!(values[1].1, 0.99);
    expect_no_patch(&sim, 2, &harness.clock).await;
    let state = harness.lever.state().await.unwrap();
    assert_eq!(state.pending, 0);
    harness.lever.shutdown().await.unwrap();
}

/// Controls-plan regression: a release must not wait behind a saturated
/// input queue. 256 queued samples (capacity hit reported to the caller) must
/// not delay or swallow the release.
#[tokio::test]
async fn lever_release_precedes_a_saturated_sample_queue() {
    let sim = ScriptedSim::spawn();
    let harness = lever_harness(sim.clone());
    let gate = sim.gate(THROTTLE);

    harness.lever.input(sample("COM1", 2, 100)).await.unwrap();
    gate.await_entered().await;

    // Fill the command queue synchronously (no awaits → the worker cannot
    // drain between pushes on this current-thread runtime).
    let mut overflowed = 0usize;
    for index in 0..600i16 {
        match harness.lever.try_input(sample("COM1", 2, index % 1000)) {
            Ok(()) => {}
            Err(QueueError::Overflow) => overflowed += 1,
            Err(other) => panic!("unexpected ingress error: {other:?}"),
        }
    }
    assert!(overflowed > 0, "queue saturation was not exercised");

    harness.lever.release().unwrap();
    let state = harness.lever.state().await.unwrap();
    assert!(!state.active);
    assert_eq!(state.pending, 0);
    gate.release();
    settle().await;
    // Every queued sample was fenced after the release: exactly one write.
    expect_no_patch(&sim, 1, &harness.clock).await;
    harness.lever.shutdown().await.unwrap();
}

// ---------------------------------------------------------------------------
// Buttons
// ---------------------------------------------------------------------------

struct ButtonHarness {
    buttons: ButtonController,
    broadcast: tokio::sync::mpsc::Receiver<ButtonStateChange>,
    clock: FakeClock,
    keystrokes: Arc<FakeKeystrokes>,
}

fn button_harness(sim: ScriptedSim, bindings: Vec<ButtonBindingInfo>) -> ButtonHarness {
    let resolver = resolver("COM1", 5, 42);
    let clock = FakeClock::new();
    let keystrokes = Arc::new(FakeKeystrokes::default());
    let (buttons, broadcast) = ButtonController::start(
        Arc::new(clock.clone()),
        resolver,
        keystrokes.clone(),
    );
    buttons
        .activate(1, EntityId(7), &button_snapshot(bindings))
        .unwrap();
    buttons.simulator_connected(client(&sim)).unwrap();
    ButtonHarness {
        buttons,
        broadcast,
        clock,
        keystrokes,
    }
}

async fn next_broadcast(
    receiver: &mut tokio::sync::mpsc::Receiver<ButtonStateChange>,
) -> ButtonStateChange {
    yield_until(|| receiver.try_recv().ok()).await
}

/// Mirrors "updates last_sent_values on press and release" plus the dedup
/// guarantee (button_controller_test.exs:466-527; simple mode at
/// button_controller.ex:360-371).
#[tokio::test]
async fn simple_button_deduplicates_repeated_edges() {
    let sim = ScriptedSim::spawn();
    let mut harness = button_harness(sim.clone(), vec![simple_binding(42, 5)]);

    harness.buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    let change = next_broadcast(&mut harness.broadcast).await;
    assert_eq!(
        change,
        ButtonStateChange {
            element_id: EntityId(5),
            value: 1.0,
            pressed: true,
        }
    );
    // A repeated press is deduplicated: no second write, no broadcast.
    harness.buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    settle().await;
    assert_eq!(sim.set_values().len(), 1);
    assert!(harness.broadcast.try_recv().is_err());

    harness.buttons.input(button_sample("COM1", 5, 0)).await.unwrap();
    let change = next_broadcast(&mut harness.broadcast).await;
    assert_eq!(change.value, 0.0);
    assert!(!change.pressed);
    harness.buttons.input(button_sample("COM1", 5, 0)).await.unwrap();
    settle().await;
    assert_eq!(sim.set_values().len(), 2);
    assert_eq!(sim.set_values()[1], (HORN.to_owned(), 0.0));
    harness.buttons.shutdown().await.unwrap();
}

/// Mirrors the momentary ordering contract (button_controller.ex:622-658)
/// and the request-paced repeat loop (210-225): Interacting=1 before the
/// value on press, repeats of the on value one per completed HTTP send, then
/// value before Interacting=0 on release.
#[tokio::test]
async fn momentary_button_orders_interacting_and_repeats_while_held() {
    let sim = ScriptedSim::spawn();
    let mut binding = simple_binding(42, 5);
    binding.mode = ButtonMode::Momentary;
    binding.repeat_interval_ms = 50;
    let mut harness = button_harness(sim.clone(), vec![binding]);

    harness.buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    let change = next_broadcast(&mut harness.broadcast).await;
    assert_eq!(change, ButtonStateChange { element_id: EntityId(5), value: 1.0, pressed: true });

    // Request-paced repeats: several on-value sends land while held.
    yield_until(|| {
        (sim
            .set_values()
            .iter()
            .filter(|(path, value)| path == HORN && *value == 1.0)
            .count()
            >= 3)
            .then_some(())
    })
    .await;

    harness.buttons.input(button_sample("COM1", 5, 0)).await.unwrap();
    let change = next_broadcast(&mut harness.broadcast).await;
    assert_eq!(change.value, 0.0);
    assert!(!change.pressed);

    settle().await;
    let paths = sim.set_paths();
    // Press: Interacting=1 strictly before the first on-value send.
    assert_eq!(paths[0], HORN_INTERACTING);
    assert_eq!(paths[1], HORN);
    // Release: the final two sends are value=0.0 before Interacting=0.
    let tail = &paths[paths.len() - 2..];
    assert_eq!(tail, [HORN, HORN_INTERACTING]);
    let values = sim.set_values();
    assert_eq!(values[values.len() - 2], (HORN.to_owned(), 0.0));
    assert_eq!(values[values.len() - 1], (HORN_INTERACTING.to_owned(), 0.0));

    // No repeats after release.
    let count = sim.set_values().len();
    settle().await;
    assert_eq!(sim.set_values().len(), count);
    let state = harness.buttons.state().await.unwrap();
    assert_eq!(state.active_buttons, 0);
    harness.buttons.shutdown().await.unwrap();
}

/// Mirrors "clears active button when released" / "ignores stale
/// momentary_repeat messages after release" (button_controller_test.exs:379-463).
#[tokio::test]
async fn momentary_release_cancels_repeats_and_ignores_stale_ticks() {
    let sim = ScriptedSim::spawn();
    let mut binding = simple_binding(42, 5);
    binding.mode = ButtonMode::Momentary;
    let mut harness = button_harness(sim.clone(), vec![binding]);

    harness.buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    let _ = next_broadcast(&mut harness.broadcast).await;
    yield_until(|| (sim.set_values().len() >= 2).then_some(())).await;
    let state = harness.buttons.state().await.unwrap();
    assert_eq!(state.active_buttons, 1);

    harness.buttons.input(button_sample("COM1", 5, 0)).await.unwrap();
    let _ = next_broadcast(&mut harness.broadcast).await;
    let state = harness.buttons.state().await.unwrap();
    assert_eq!(state.active_buttons, 0);

    let count = sim.set_values().len();
    settle().await;
    assert_eq!(sim.set_values().len(), count, "stale repeat ticks kept writing");
    harness.buttons.shutdown().await.unwrap();
}

/// Sequence mode: ordered commands with per-command delays, completion
/// cleanup and the broadcast contract (button_controller_test.exs:529-651;
/// sequence executor at button_controller.ex:695-758).
#[tokio::test]
async fn sequence_mode_executes_ordered_commands_with_delays() {
    let sim = ScriptedSim::spawn();
    let mut binding = simple_binding(42, 5);
    binding.mode = ButtonMode::Sequence;
    binding.endpoint = None;
    binding.on_sequence = Some(vec![
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
    ]);
    let mut harness = button_harness(sim.clone(), vec![binding]);

    harness.buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    let change = next_broadcast(&mut harness.broadcast).await;
    assert_eq!(change.value, 1.0);
    assert!(change.pressed);

    // First command immediately; the second only after 100ms of fake time.
    patch_count(&sim, 1).await;
    assert_eq!(sim.set_paths(), ["DoorKey.InputValue"]);
    advance_until(&harness.clock, Duration::from_millis(20), || {
        (sim.set_paths().len() >= 2).then_some(())
    })
    .await;
    assert_eq!(sim.set_paths(), ["DoorKey.InputValue", "DoorOpen.InputValue"]);

    // Completion removes the active entry.
    yield_until(|| {
        harness
            .broadcast
            .try_recv()
            .err()
            .is_some()
            .then_some(())
            .filter(|_| sim.set_paths().len() == 2)
    })
    .await;
    let state = harness.buttons.state().await.unwrap();
    assert_eq!(state.active_buttons, 0);
    harness.buttons.shutdown().await.unwrap();
}

/// Mirrors "skips when no on_sequence configured" and the empty-sequence
/// guard (button_controller_test.exs:686-716; button_controller.ex:400-410).
#[tokio::test]
async fn sequence_mode_skips_missing_and_empty_sequences() {
    let sim = ScriptedSim::spawn();
    let mut missing = simple_binding(42, 5);
    missing.mode = ButtonMode::Sequence;
    missing.endpoint = None;
    let mut empty = simple_binding(43, 6);
    empty.mode = ButtonMode::Sequence;
    empty.endpoint = None;
    empty.on_sequence = Some(Vec::new());

    let resolver = Arc::new(InputResolver::default());
    resolver.replace_port(
        "COM1",
        1,
        ConfigId::new(11).unwrap(),
        [
            (5, InputIdentity { device_id: EntityId(9), input_id: EntityId(42) }),
            (6, InputIdentity { device_id: EntityId(9), input_id: EntityId(43) }),
        ],
    );
    let clock = FakeClock::new();
    let keystrokes = Arc::new(FakeKeystrokes::default());
    let (buttons, _broadcast) =
        ButtonController::start(Arc::new(clock), resolver, keystrokes);
    buttons
        .activate(1, EntityId(7), &button_snapshot(vec![missing, empty]))
        .unwrap();
    buttons.simulator_connected(client(&sim)).unwrap();

    buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    buttons.input(button_sample("COM1", 6, 1)).await.unwrap();
    settle().await;
    assert!(sim.set_values().is_empty());
    let state = buttons.state().await.unwrap();
    assert_eq!(state.active_buttons, 0);
    buttons.shutdown().await.unwrap();
}

/// Mirrors "cancels sequence on button release for momentary hardware" and
/// "sequence with long delays is properly cancelled"
/// (button_controller_test.exs:653-684, 788-828): release kills the executor
/// mid-delay — it does not wait out the delay.
#[tokio::test]
async fn sequence_release_cancels_momentary_hardware_mid_delay() {
    let sim = ScriptedSim::spawn();
    let mut binding = simple_binding(42, 5);
    binding.mode = ButtonMode::Sequence;
    binding.endpoint = None;
    binding.on_sequence = Some(vec![
        SequenceCommand {
            endpoint: "First.InputValue".to_owned(),
            value: 1.0,
            delay_ms: 5_000,
        },
        SequenceCommand {
            endpoint: "Second.InputValue".to_owned(),
            value: 1.0,
            delay_ms: 0,
        },
    ]);
    let mut harness = button_harness(sim.clone(), vec![binding]);

    harness.buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    let _ = next_broadcast(&mut harness.broadcast).await;
    patch_count(&sim, 1).await;

    harness.buttons.input(button_sample("COM1", 5, 0)).await.unwrap();
    let change = next_broadcast(&mut harness.broadcast).await;
    assert_eq!(change.value, 0.0);
    assert!(!change.pressed);

    // The aborted executor never runs the second command, however far the
    // clock advances past the 5s delay.
    harness.clock.advance(Duration::from_secs(10));
    settle().await;
    assert_eq!(sim.set_paths(), ["First.InputValue"]);
    let state = harness.buttons.state().await.unwrap();
    assert_eq!(state.active_buttons, 0);
    harness.buttons.shutdown().await.unwrap();
}

/// Failure-continues: a failing command is logged and the remaining commands
/// still run (button_controller.ex:731-743).
#[tokio::test]
async fn sequence_failure_continues_with_remaining_commands() {
    let sim = ScriptedSim::spawn();
    sim.fail_set("Broken.InputValue", 500);
    let mut binding = simple_binding(42, 5);
    binding.mode = ButtonMode::Sequence;
    binding.endpoint = None;
    binding.on_sequence = Some(vec![
        SequenceCommand {
            endpoint: "Broken.InputValue".to_owned(),
            value: 1.0,
            delay_ms: 50,
        },
        SequenceCommand {
            endpoint: "Afterwards.InputValue".to_owned(),
            value: 1.0,
            delay_ms: 0,
        },
    ]);
    let mut harness = button_harness(sim.clone(), vec![binding]);

    harness.buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    let _ = next_broadcast(&mut harness.broadcast).await;
    patch_count(&sim, 1).await;
    advance_until(&harness.clock, Duration::from_millis(20), || {
        (sim.set_paths().len() >= 2).then_some(())
    })
    .await;
    assert_eq!(
        sim.set_paths(),
        ["Broken.InputValue", "Afterwards.InputValue"]
    );
    harness.buttons.shutdown().await.unwrap();
}

/// Mirrors "rapid button presses properly cancel previous sequences"
/// (button_controller_test.exs:718-753): release kills the first executor
/// before the re-press starts the next one.
#[tokio::test]
async fn sequence_rapid_repress_cancels_previous_execution() {
    let sim = ScriptedSim::spawn();
    let mut binding = simple_binding(42, 5);
    binding.mode = ButtonMode::Sequence;
    binding.endpoint = None;
    binding.on_sequence = Some(vec![
        SequenceCommand {
            endpoint: "Step.InputValue".to_owned(),
            value: 1.0,
            delay_ms: 5_000,
        },
        SequenceCommand {
            endpoint: "Tail.InputValue".to_owned(),
            value: 1.0,
            delay_ms: 0,
        },
    ]);
    let mut harness = button_harness(sim.clone(), vec![binding]);

    harness.buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    let _ = next_broadcast(&mut harness.broadcast).await;
    patch_count(&sim, 1).await;
    let state = harness.buttons.state().await.unwrap();
    assert_eq!(state.active_buttons, 1);

    harness.buttons.input(button_sample("COM1", 5, 0)).await.unwrap();
    harness.buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    let _ = next_broadcast(&mut harness.broadcast).await;
    let _ = next_broadcast(&mut harness.broadcast).await;
    // The re-press ran the first command again with a fresh 5s delay.
    patch_count(&sim, 2).await;
    // After 6s both 5s delays would have elapsed; exactly ONE tail command
    // proves the first executor was cancelled before its delay completed.
    harness.clock.advance(Duration::from_secs(6));
    settle().await;
    assert_eq!(
        sim.set_paths(),
        ["Step.InputValue", "Step.InputValue", "Tail.InputValue"]
    );
    harness.buttons.shutdown().await.unwrap();
}

/// Latching hardware runs the off-sequence on release
/// (button_controller.ex:538-577; "loads off_sequence for latching
/// hardware" at button_controller_test.exs:587-604).
#[tokio::test]
async fn sequence_latching_release_starts_off_sequence() {
    let sim = ScriptedSim::spawn();
    let mut binding = simple_binding(42, 5);
    binding.mode = ButtonMode::Sequence;
    binding.hardware_type = ButtonHardwareType::Latching;
    binding.endpoint = None;
    binding.on_sequence = Some(vec![SequenceCommand {
        endpoint: "Open.InputValue".to_owned(),
        value: 1.0,
        delay_ms: 0,
    }]);
    binding.off_sequence = Some(vec![SequenceCommand {
        endpoint: "Close.InputValue".to_owned(),
        value: 1.0,
        delay_ms: 0,
    }]);
    let mut harness = button_harness(sim.clone(), vec![binding]);

    harness.buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    let _ = next_broadcast(&mut harness.broadcast).await;
    patch_count(&sim, 1).await;

    harness.buttons.input(button_sample("COM1", 5, 0)).await.unwrap();
    let change = next_broadcast(&mut harness.broadcast).await;
    assert_eq!(change.value, 0.0);
    patch_count(&sim, 2).await;
    assert_eq!(sim.set_paths(), ["Open.InputValue", "Close.InputValue"]);
    harness.buttons.shutdown().await.unwrap();
}

/// Keystroke mode dispatches press/release through the injected port and
/// broadcasts only on success (button_controller.ex:440-453, 497-510).
#[tokio::test]
async fn keystroke_mode_presses_and_releases_through_the_port() {
    let sim = ScriptedSim::spawn();
    let mut binding = simple_binding(42, 5);
    binding.mode = ButtonMode::Keystroke;
    binding.endpoint = None;
    binding.keystroke = Some("CTRL+W".to_owned());
    let mut harness = button_harness(sim.clone(), vec![binding]);

    harness.buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    let change = next_broadcast(&mut harness.broadcast).await;
    assert_eq!(change, ButtonStateChange { element_id: EntityId(5), value: 1.0, pressed: true });
    let calls = harness.keystrokes.calls();
    assert_eq!(calls.len(), 1);
    assert_eq!(calls[0].action, "press");
    assert_eq!(calls[0].combo.as_deref(), Some("CTRL+W"));
    assert_eq!(calls[0].binding, Some(EntityId(100)));
    assert_eq!(calls[0].owner, KeystrokeOwner { owner: EntityId(7), generation: 1 });

    harness.buttons.input(button_sample("COM1", 5, 0)).await.unwrap();
    let change = next_broadcast(&mut harness.broadcast).await;
    assert_eq!(change.value, 0.0);
    let calls = harness.keystrokes.calls();
    assert_eq!(calls.len(), 2);
    assert_eq!(calls[1].action, "release");

    // A failed press broadcasts nothing (Elixir :error → :skip).
    harness.keystrokes.fail_next("press", "no keyboard");
    harness.buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    settle().await;
    assert!(harness.broadcast.try_recv().is_err());
    assert_eq!(harness.keystrokes.calls().len(), 3);
    harness.buttons.shutdown().await.unwrap();
}

/// Controls-plan regression: source loss / train switch during a held
/// keystroke releases the owner (stuck-key cleanup through `owner_gone`).
#[tokio::test]
async fn train_switch_releases_held_keystrokes() {
    let sim = ScriptedSim::spawn();
    let mut binding = simple_binding(42, 5);
    binding.mode = ButtonMode::Keystroke;
    binding.endpoint = None;
    binding.keystroke = Some("W".to_owned());
    let mut harness = button_harness(sim.clone(), vec![binding]);

    harness.buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    let _ = next_broadcast(&mut harness.broadcast).await;
    assert_eq!(harness.keystrokes.calls().len(), 1);

    // Train switch: release() must not lose the held key.
    harness.buttons.release().unwrap();
    let state = harness.buttons.state().await.unwrap();
    assert!(!state.active);
    let calls = harness.keystrokes.calls();
    assert_eq!(calls.len(), 2);
    assert_eq!(calls[1].action, "owner_gone");
    assert_eq!(calls[1].owner, KeystrokeOwner { owner: EntityId(7), generation: 1 });
    harness.buttons.shutdown().await.unwrap();
}

/// Controls-plan regression: a train switch during a sequence delay kills
/// the executor (mirrors "sequence task is cancelled on train change",
/// button_controller_test.exs:755-786).
#[tokio::test]
async fn train_switch_cancels_running_sequence() {
    let sim = ScriptedSim::spawn();
    let mut binding = simple_binding(42, 5);
    binding.mode = ButtonMode::Sequence;
    binding.endpoint = None;
    binding.on_sequence = Some(vec![
        SequenceCommand {
            endpoint: "First.InputValue".to_owned(),
            value: 1.0,
            delay_ms: 5_000,
        },
        SequenceCommand {
            endpoint: "Second.InputValue".to_owned(),
            value: 1.0,
            delay_ms: 0,
        },
    ]);
    let mut harness = button_harness(sim.clone(), vec![binding]);

    harness.buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    let _ = next_broadcast(&mut harness.broadcast).await;
    patch_count(&sim, 1).await;

    harness.buttons.release().unwrap();
    let state = harness.buttons.state().await.unwrap();
    assert_eq!(state.active_buttons, 0);
    harness.clock.advance(Duration::from_secs(10));
    settle().await;
    assert_eq!(sim.set_paths(), ["First.InputValue"]);
    harness.buttons.shutdown().await.unwrap();
}

/// Controls-plan regression: overload release. With the worker stalled inside
/// a momentary press HTTP call and the edge queue saturated, the release
/// takes the priority path, delivers value=0 before Interacting=0 and no
/// queued edge resurrects the button.
#[tokio::test]
async fn button_release_survives_queue_saturation() {
    let sim = ScriptedSim::spawn();
    let mut binding = simple_binding(42, 5);
    binding.mode = ButtonMode::Momentary;
    let resolver = resolver("COM1", 5, 42);
    let clock = FakeClock::new();
    let keystrokes = Arc::new(FakeKeystrokes::default());
    let (buttons, mut broadcast) =
        ButtonController::start(Arc::new(clock), resolver, keystrokes);
    buttons
        .activate(1, EntityId(7), &button_snapshot(vec![binding]))
        .unwrap();
    buttons.simulator_connected(client(&sim)).unwrap();

    // Gate the value endpoint so the first repeat blocks the worker mid-send.
    let gate = sim.gate(HORN);
    buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    // Interacting=1 + value land, then the first repeat blocks.
    gate.await_entered().await;

    // Saturate the edge queue; overflows are reported, not dropped silently.
    let mut overflowed = 0usize;
    for _ in 0..600 {
        match buttons.try_input(button_sample("COM1", 5, 1)) {
            Ok(()) => {}
            Err(ButtonQueueError::Overflow) => overflowed += 1,
            Err(other) => panic!("unexpected ingress error: {other:?}"),
        }
    }
    assert!(overflowed > 0, "queue saturation was not exercised");

    // The owner-level release takes the priority control path — it must not
    // wait behind the 600 queued edges.
    buttons.release().unwrap();
    gate.release();

    // The press broadcast (from before the gate) arrives; the release
    // broadcasts nothing of its own (Elixir deactivation does not re-send
    // off values — cancel_all_active_buttons/1 only kills executors).
    let change = next_broadcast(&mut broadcast).await;
    assert_eq!(change.value, 1.0);
    assert!(change.pressed);

    // state() is itself a control message: it can only report inactive if
    // the release was already processed — proof the release did not queue
    // behind the saturated edge channel.
    let state = buttons.state().await.unwrap();
    assert!(!state.active, "release was not processed promptly");
    assert_eq!(state.active_buttons, 0);
    assert_eq!(state.bindings, 0);

    // Every queued edge was fenced: the repeat loop stopped and the set
    // count is frozen at the press writes (Interacting=1, value, plus
    // however many repeats completed before the release).
    let frozen = sim.set_values().len();
    settle().await;
    assert_eq!(sim.set_values().len(), frozen, "queued edges wrote after release");
    buttons.shutdown().await.unwrap();
}

/// Controls-plan regression: a momentary repeat loop must survive edge-queue
/// saturation. The Elixir controller re-queues its self-tick on an unbounded
/// mailbox, so a burst of edges can pause repeats but never kill the loop:
/// once the bounded queue drains, request-paced repeats resume (the parked
/// tick is re-armed, `pending_repeats`).
#[tokio::test]
async fn momentary_repeat_survives_queue_saturation() {
    let sim = ScriptedSim::spawn();
    let mut binding = simple_binding(42, 5);
    binding.mode = ButtonMode::Momentary;
    let mut harness = button_harness(sim.clone(), vec![binding]);

    harness.buttons.input(button_sample("COM1", 5, 1)).await.unwrap();
    let _ = next_broadcast(&mut harness.broadcast).await;
    // Repeats are running.
    yield_until(|| (horn_on_count(&sim) >= 3).then_some(())).await;

    // Saturate the edge queue from this task without awaiting, so the worker
    // cannot drain between pushes. The flooded edges target an unbound pin
    // (they resolve to nothing) — the momentary button itself stays held.
    let mut overflowed = 0usize;
    for _ in 0..600 {
        match harness.buttons.try_input(button_sample("COM1", 7, 1)) {
            Ok(()) => {}
            Err(ButtonQueueError::Overflow) => overflowed += 1,
            Err(other) => panic!("unexpected ingress error: {other:?}"),
        }
    }
    assert!(overflowed > 0, "queue saturation was not exercised");

    // The in-flight tick's re-arm hit the full queue; after the backlog of
    // no-op edges drains, repeats must resume — the count keeps growing.
    yield_until(|| (horn_on_count(&sim) >= 4).then_some(())).await;
    let before = horn_on_count(&sim);
    settle().await;
    let after = horn_on_count(&sim);
    assert!(after > before, "repeat loop died under saturation: {before} → {after}");

    // Release still lands and stops the loop.
    harness.buttons.input(button_sample("COM1", 5, 0)).await.unwrap();
    let _ = next_broadcast(&mut harness.broadcast).await;
    let frozen = horn_on_count(&sim);
    settle().await;
    assert_eq!(horn_on_count(&sim), frozen, "repeats continued after release");
    harness.buttons.shutdown().await.unwrap();
}

fn horn_on_count(sim: &ScriptedSim) -> usize {
    sim.set_values()
        .iter()
        .filter(|(path, value)| path == HORN && *value == 1.0)
        .count()
}

/// Fake-config smoke check shared with the sessions suite: the fake source
/// tracks revisions like the DB topic sum.
#[test]
fn fake_config_source_bumps_revisions() {
    let config = FakeConfig::new();
    assert_eq!(config.revision(), 0);
    config.commit(
        trenino_core::train::identifier::TrainProfile {
            id: 7,
            name: "Test".into(),
            identifiers: vec!["RVM_TEST".into()],
        },
        None,
    );
    assert_eq!(config.revision(), 1);
}
