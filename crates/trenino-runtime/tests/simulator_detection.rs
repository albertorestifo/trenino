//! Integration tests for the simulator detection/exploration/calibration
//! services (`trenino_runtime::simulator::services`).
//!
//! Every test drives the accepted `SimulatorClient` against a loopback fake
//! TSW HTTP server and a `FakeClock`, mirroring the ExUnit suites:
//!
//! - endpoint exploration: `Trenino.Simulator.ControlDetector`
//!   (lib/trenino/simulator/control_detector.ex; the module has no dedicated
//!   ExUnit file, so its doctests are the oracle) and the fake-server request
//!   shapes of `test/trenino/simulator/client_test.exs`.
//! - control detection session:
//!   `test/trenino/simulator/control_detection_session_test.exs`.
//! - lever analysis: `test/trenino/simulator/lever_analyzer_test.exs`
//!   (fast options use `settling_time_ms: 0` like the ExUnit `@fast_opts`).
//! - train detection: `test/trenino/train/detection_test.exs`
//!   (5s poll / 30s grace with 200ms probes).
//! - lever calibration: `test/trenino/train/calibration/lever_session_test.exs`.
//! - notch mapping wizard:
//!   `test/trenino/train/calibration/notch_mapping_session_test.exs`.

use std::collections::HashMap;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use serde_json::{json, Value};
use tokio::sync::mpsc;
use trenino_core::calibration::analysis::{LeverType, ZoneType};
use trenino_core::hardware::calibration::Calibration;
use trenino_core::train::identifier::TrainProfile;
use trenino_runtime::resource::{LeaseKind, ResourceArbiter, ResourceConsumers, ResourceError};
use trenino_runtime::simulator::client::{SimulatorClient, SimulatorError, TimeoutProfile};
use trenino_runtime::simulator::services::calibration as lever_calib;
use trenino_runtime::simulator::services::calibration::{
    CalibrationEvent, CalibrationStep, CalibrationStore, MappingEvent, MappingStep,
    NotchDefinition, NotchKind, NotchMappingConfig,
};
use trenino_runtime::simulator::services::clock::{Clock, FakeClock};
use trenino_runtime::simulator::services::control_detection::{
    self as control_detection, DetectionEvent, DetectionFailure, DetectionOutcome,
};
use trenino_runtime::simulator::services::explorer;
use trenino_runtime::simulator::services::lever_analysis::{
    self as lever_analysis, AnalysisFailure, AnalysisOptions, QuickCheck, QuickCheckError,
};
use trenino_runtime::simulator::services::session::SessionHandle;
use trenino_runtime::simulator::services::train_detection::{
    self as train_detection, TrainDetectionEvent,
};

// ---------------------------------------------------------------------------
// Fake loopback TSW HTTP server
// ---------------------------------------------------------------------------

struct FakeRequest {
    method: String,
    /// Raw request target (path plus query) exactly as sent by the client.
    path: String,
}

impl FakeRequest {
    fn query(&self, key: &str) -> Option<String> {
        let (_, query) = self.path.split_once('?')?;
        query.split('&').find_map(|pair| {
            let (name, value) = pair.split_once('=')?;
            (name == key).then(|| value.to_owned())
        })
    }

    /// The `Value=` query of a PATCH /set, mirroring the Elixir tests'
    /// `round(value * 1000)` atomics trick that hides float drift.
    fn set_value(&self) -> f64 {
        self.query("Value")
            .and_then(|value| value.parse::<f64>().ok())
            .map(|value| (value * 1000.0).round() / 1000.0)
            .unwrap_or(0.0)
    }
}

struct FakeSim {
    base_url: String,
    requests: Arc<Mutex<Vec<String>>>,
}

impl FakeSim {
    /// One OS thread per connection; every request is answered and the
    /// connection closed, which keeps reqwest from reusing pooled sockets.
    fn spawn<F>(handler: F) -> Self
    where
        F: Fn(FakeRequest) -> (u16, String) + Send + Sync + 'static,
    {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let address = listener.local_addr().unwrap();
        let handler = Arc::new(handler);
        let requests = Arc::new(Mutex::new(Vec::new()));
        let logged = requests.clone();
        thread::spawn(move || {
            for stream in listener.incoming().flatten() {
                let handler = handler.clone();
                let logged = logged.clone();
                thread::spawn(move || handle_connection(stream, handler, logged));
            }
        });
        Self {
            base_url: format!("http://{address}"),
            requests,
        }
    }

    fn url(&self) -> &str {
        &self.base_url
    }

    fn request_count(&self) -> usize {
        self.requests.lock().unwrap().len()
    }
}

fn handle_connection<F>(stream: TcpStream, handler: Arc<F>, logged: Arc<Mutex<Vec<String>>>)
where
    F: Fn(FakeRequest) -> (u16, String),
{
    let mut writer = match stream.try_clone() {
        Ok(writer) => writer,
        Err(_) => return,
    };
    let mut reader = BufReader::new(stream);
    let mut request_line = String::new();
    if reader.read_line(&mut request_line).unwrap_or(0) == 0 {
        return;
    }
    let mut parts = request_line.split_whitespace();
    let method = parts.next().unwrap_or_default().to_owned();
    let path = parts.next().unwrap_or_default().to_owned();
    let mut content_length = 0_usize;
    loop {
        let mut header = String::new();
        if reader.read_line(&mut header).unwrap_or(0) == 0 {
            return;
        }
        let header = header.trim_end();
        if header.is_empty() {
            break;
        }
        if let Some((name, value)) = header.split_once(':') {
            if name.trim().eq_ignore_ascii_case("content-length") {
                content_length = value.trim().parse().unwrap_or(0);
            }
        }
    }
    let mut body = vec![0_u8; content_length];
    if !body.is_empty() && reader.read_exact(&mut body).is_err() {
        return;
    }
    logged.lock().unwrap().push(format!("{method} {path}"));
    let (status, body) = handler(FakeRequest { method, path });
    let reason = match status {
        200 => "OK",
        403 => "Forbidden",
        404 => "Not Found",
        _ => "Internal Server Error",
    };
    let response = format!(
        "HTTP/1.1 {status} {reason}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
        body.len()
    );
    let _ = writer.write_all(response.as_bytes());
    let _ = writer.flush();
}

fn ok(body: Value) -> (u16, String) {
    (200, body.to_string())
}

fn not_found() -> (u16, String) {
    (404, r#"{"error":"not found"}"#.to_owned())
}

// ---------------------------------------------------------------------------
// Fake resource arbiter consumers (mirrors tests/resource_arbiter.rs)
// ---------------------------------------------------------------------------

struct FakeConsumers;

impl ResourceConsumers for FakeConsumers {
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

fn arbiter() -> Arc<ResourceArbiter> {
    Arc::new(ResourceArbiter::new(Arc::new(FakeConsumers)))
}

fn lease() -> LeaseKind {
    LeaseKind::Calibration {
        port: "COM_TEST".to_owned(),
        generation: 1,
    }
}

// ---------------------------------------------------------------------------
// Fake-clock drivers
// ---------------------------------------------------------------------------

const DRIVE_LIMIT: usize = 30_000;

/// A 1ms real sleep between probes instead of `yield_now`: parking the
/// probing task gives the current-thread runtime real park cycles to run its
/// IO/timer drivers, which a pure yield (or zero-sleep spin) would starve —
/// loopback HTTP round trips need several IO turns each. The fake clock is
/// unaffected, so logical timing stays exact.
async fn yield_until<T>(mut probe: impl FnMut() -> Option<T>) -> T {
    for _ in 0..DRIVE_LIMIT {
        if let Some(value) = probe() {
            return value;
        }
        tokio::time::sleep(Duration::from_millis(1)).await;
    }
    panic!("condition never observed while yielding");
}

async fn advance_until<T>(
    clock: &FakeClock,
    step: Duration,
    mut probe: impl FnMut() -> Option<T>,
) -> T {
    for _ in 0..DRIVE_LIMIT {
        if let Some(value) = probe() {
            return value;
        }
        clock.advance(step);
        tokio::time::sleep(Duration::from_millis(1)).await;
    }
    panic!("condition never observed while driving the fake clock");
}

async fn next_event<E>(clock: &FakeClock, step: Duration, receiver: &mut mpsc::Receiver<E>) -> E {
    advance_until(clock, step, || receiver.try_recv().ok()).await
}

/// Yield a few times so a spawned task could have run, then prove it did not.
/// Real-time settle so a just-observed poll finishes its trailing HTTP
/// round trips and the worker re-arms its timer from the un-advanced fake
/// time. Without it, the next `advance` can land mid-poll and push the
/// re-armed deadline one step out, wedging the next per-poll wait.
async fn settle() {
    tokio::time::sleep(Duration::from_millis(10)).await;
}

async fn assert_quiet(mut probe: impl FnMut()) {
    for _ in 0..16 {
        tokio::task::yield_now().await;
    }
    probe();
}

// ===========================================================================
// Endpoint exploration (Trenino.Simulator.ControlDetector)
// ===========================================================================

fn explorer_sim() -> FakeSim {
    FakeSim::spawn(
        |request| match (request.method.as_str(), request.path.as_str()) {
            ("GET", "/list/CurrentDrivableActor") => ok(json!({
                "Result": "Success",
                "Nodes": ["Throttle(Lever)", "Horn", "Plain"]
            })),
            ("GET", "/list/CurrentDrivableActor/Throttle%28Lever%29") => ok(json!({
                "Result": "Success",
                "Nodes": ["InputValue", "Function.GetNotchCount"]
            })),
            ("GET", "/list/CurrentDrivableActor/Horn") => ok(json!({
                "Result": "Success",
                "Nodes": ["InputValue", "Property.bDefaultToPressed"]
            })),
            ("GET", "/list/CurrentDrivableActor/Plain") => ok(json!({
                "Result": "Success",
                "Nodes": ["InputValue"]
            })),
            _ => not_found(),
        },
    )
}

/// Mirrors `ControlDetector.list_controls/1`, `detect_lever/2` and
/// `detect_button/2` (control_detector.ex:144-226): controls come from the
/// `Nodes` list under `CurrentDrivableActor`, levers expose a
/// `Function.GetNotchCount` endpoint and buttons a `Property.bDefaultToPressed`.
#[tokio::test]
async fn exploration_lists_and_classifies_levers_and_buttons() {
    let sim = explorer_sim();
    let client = SimulatorClient::new(sim.url(), "key").unwrap();

    let controls = explorer::list_controls(&client).await.unwrap();
    assert_eq!(
        controls,
        vec![
            "Throttle(Lever)".to_owned(),
            "Horn".to_owned(),
            "Plain".to_owned()
        ]
    );

    let levers = explorer::detect_levers(&client).await.unwrap();
    assert_eq!(levers.len(), 1);
    assert_eq!(levers[0].name, "Throttle(Lever)");
    assert_eq!(
        levers[0].min_endpoint,
        "CurrentDrivableActor/Throttle(Lever).Function.GetMinimumInputValue"
    );
    assert_eq!(
        levers[0].max_endpoint,
        "CurrentDrivableActor/Throttle(Lever).Function.GetMaximumInputValue"
    );
    assert_eq!(
        levers[0].value_endpoint,
        "CurrentDrivableActor/Throttle(Lever).InputValue"
    );
    assert_eq!(
        levers[0].notch_count_endpoint,
        "CurrentDrivableActor/Throttle(Lever).Function.GetNotchCount"
    );
    assert_eq!(
        levers[0].notch_index_endpoint,
        "CurrentDrivableActor/Throttle(Lever).Function.GetCurrentNotchIndex"
    );

    let buttons = explorer::detect_buttons(&client).await.unwrap();
    assert_eq!(buttons.len(), 1);
    assert_eq!(buttons[0].name, "Horn");
    assert_eq!(buttons[0].endpoint, "CurrentDrivableActor/Horn.InputValue");
}

/// Mirrors the `suggest_lever/1` / `suggest_button/1` doctests
/// (control_detector.ex:48-130) and the `calculate_confidence/2` ladder
/// (control_detector.ex:247-281): contained element 0.85, exact 1.0 and the
/// strictly-above-0.3 gate.
#[tokio::test]
async fn suggestions_use_the_confidence_ladder_and_gate_low_confidence() {
    let sim = explorer_sim();
    let client = SimulatorClient::new(sim.url(), "key").unwrap();

    let lever = explorer::suggest_lever(&client, "Throttle").await.unwrap();
    assert_eq!(lever.lever.name, "Throttle(Lever)");
    assert!((lever.confidence - 0.85).abs() < 1e-12);

    let button = explorer::suggest_button(&client, "Horn").await.unwrap();
    assert_eq!(button.button.name, "Horn");
    assert!((button.confidence - 1.0).abs() < 1e-12);

    // No shared characters with the only lever -> jaro 0.0 -> below the gate.
    assert_eq!(
        explorer::suggest_lever(&client, "Qqqqzz")
            .await
            .unwrap_err(),
        explorer::SuggestError::NoMatch
    );
}

/// The fuzzy-matching primitives against `String.jaro_distance/2` golden
/// values and `ControlDetector.split_into_words/1` (control_detector.ex:284-297).
#[test]
fn exploration_fuzzy_primitives_match_elixir() {
    // Golden values verified against String.jaro_distance/2.
    assert!((explorer::jaro_distance("dwayne", "duane") - 0.8222222222222223).abs() < 1e-12);
    assert!((explorer::jaro_distance("hardware", "wizardry") - 0.6666666666666666).abs() < 1e-12);
    assert!(
        (explorer::jaro_distance("throttle", "throttlelever") - 0.8717948717948718).abs() < 1e-12
    );
    assert_eq!(explorer::jaro_distance("", ""), 1.0);
    assert_eq!(explorer::jaro_distance("a", ""), 0.0);

    assert_eq!(
        explorer::split_into_words("ThrottleLever_x (y)"),
        vec![
            "throttle".to_owned(),
            "lever".to_owned(),
            "x".to_owned(),
            "y".to_owned()
        ]
    );

    assert_eq!(explorer::confidence("horn", "Horn"), 1.0);
    assert_eq!(explorer::confidence("throttle", "Throttle(Lever)"), 0.85);
    assert_eq!(explorer::confidence("throttle lever", "Throttle"), 0.75);
    // Word matches blend the (capped) base score with the jaro distance.
    let blended = explorer::confidence("brake lever", "Brake(Lever)");
    assert!(blended > 0.45 && blended < 0.95, "blended = {blended}");
}

/// Mirrors the list-failure branch of `list_controls/1`
/// (control_detector.ex:152-154): the client error surfaces to the caller.
#[tokio::test]
async fn exploration_surfaces_client_failures() {
    let sim = FakeSim::spawn(|_| (404, r#"{"error":"missing"}"#.to_owned()));
    let client = SimulatorClient::new(sim.url(), "key").unwrap();
    match explorer::list_controls(&client).await {
        Err(explorer::ExploreError::Simulator(SimulatorError::HttpStatus { status, .. })) => {
            assert_eq!(status, 404)
        }
        other => panic!("expected http status error, got {other:?}"),
    }
}

// ===========================================================================
// Control detection session (Trenino.Simulator.ControlDetectionSession)
// ===========================================================================

#[derive(Default)]
struct ControlSimState {
    horn: f64,
    light: f64,
    fail_root_list: bool,
    fail_subscription_gets: u32,
    subscription_gets: u64,
    unsubscribes: u64,
}

fn control_detection_sim(state: &Arc<Mutex<ControlSimState>>) -> FakeSim {
    let state = state.clone();
    FakeSim::spawn(move |request| {
        let mut state = state.lock().unwrap();
        // Route on the bare path: subscription reads carry a Subscription query.
        let route = request.path.split('?').next().unwrap_or("");
        match (request.method.as_str(), route) {
            ("GET", "/list/CurrentDrivableActor") => {
                if state.fail_root_list {
                    return (500, "Internal Server Error".to_owned());
                }
                ok(json!({
                    "Result": "Success",
                    "Nodes": [
                        {"NodeName": "Horn"},
                        {"NodeName": "Light"}
                    ],
                    "Endpoints": []
                }))
            }
            ("GET", path)
                if path == "/list/CurrentDrivableActor/Horn"
                    || path == "/list/CurrentDrivableActor/Light" =>
            {
                ok(json!({
                    "Result": "Success",
                    "Nodes": [],
                    "Endpoints": [{"Name": "InputValue", "Writable": true}]
                }))
            }
            ("POST", path) if path.starts_with("/subscription/") => {
                ok(json!({"Result": "Success"}))
            }
            ("DELETE", "/subscription") => {
                state.unsubscribes += 1;
                ok(json!({"Result": "Success"}))
            }
            ("GET", "/subscription") => {
                state.subscription_gets += 1;
                // The first read is the baseline snapshot: only later polls
                // fail (the Elixir poll-error clause), setup stays healthy.
                if state.fail_subscription_gets > 0 && state.subscription_gets > 1 {
                    state.fail_subscription_gets -= 1;
                    return (500, "boom".to_owned());
                }
                ok(json!({
                    "Result": "Success",
                    "Entries": [
                        {"Path": "CurrentDrivableActor/Horn.InputValue",
                         "Values": {"InputValue": state.horn}},
                        {"Path": "CurrentDrivableActor/Light.InputValue",
                         "Values": {"InputValue": state.light}}
                    ]
                }))
            }
            _ => not_found(),
        }
    })
}

async fn start_detection(
    sim: &FakeSim,
    arbiter: &Arc<ResourceArbiter>,
    clock: &FakeClock,
) -> SessionHandle<DetectionEvent> {
    let client = Arc::new(SimulatorClient::new(sim.url(), "key").unwrap());
    control_detection::start_control_detection(client, arbiter, lease(), Arc::new(clock.clone()))
        .unwrap()
}

async fn subscription_gets(state: &Arc<Mutex<ControlSimState>>) -> u64 {
    yield_until(|| Some(state.lock().unwrap().subscription_gets)).await
}

/// Waits for the setup phase (subscribe-all + baseline snapshot) to finish.
async fn baseline_taken(state: &Arc<Mutex<ControlSimState>>) {
    yield_until(|| {
        let gets = state.lock().unwrap().subscription_gets;
        (gets >= 1).then_some(gets)
    })
    .await;
}

/// Mirrors "discovers InputValue endpoints from list response" and "detects
/// single control change" (control_detection_session_test.exs:10-94, 122-214):
/// recursive discovery of writable InputValue endpoints, subscribe-all to id
/// 99, baseline snapshot, first change above 0.01 reported with the control
/// name, then the session stops and unsubscribes.
#[tokio::test]
async fn control_detection_reports_first_change_and_unsubscribes() {
    let state = Arc::new(Mutex::new(ControlSimState::default()));
    let sim = control_detection_sim(&state);
    let clock = FakeClock::new();
    let arbiter = arbiter();
    let mut session = start_detection(&sim, &arbiter, &clock).await;

    // Baseline snapshot is the first subscription read.
    baseline_taken(&state).await;

    // User moves the horn: every later poll reports 1.0.
    state.lock().unwrap().horn = 1.0;

    let event = next_event(&clock, Duration::from_millis(50), session.events()).await;
    match event {
        DetectionEvent::Completed(DetectionOutcome::Detected { changes, ambiguous }) => {
            assert!(!ambiguous);
            assert_eq!(changes.len(), 1);
            assert_eq!(changes[0].endpoint, "CurrentDrivableActor/Horn.InputValue");
            assert_eq!(changes[0].control_name, "Horn");
            assert_eq!(changes[0].previous_value, 0.0);
            assert_eq!(changes[0].current_value, 1.0);
        }
        other => panic!("expected detection, got {other:?}"),
    }

    // The GenServer stopped itself; terminate/2 unsubscribed and released.
    session.cancel().await.unwrap();
    assert!(state.lock().unwrap().unsubscribes >= 1);
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
}

/// Mirrors "detects multiple simultaneous changes"
/// (control_detection_session_test.exs:215-318): several simultaneous changes
/// are reported together as one ambiguous candidate set.
#[tokio::test]
async fn control_detection_reports_simultaneous_changes_as_ambiguous() {
    let state = Arc::new(Mutex::new(ControlSimState::default()));
    let sim = control_detection_sim(&state);
    let clock = FakeClock::new();
    let arbiter = arbiter();
    let mut session = start_detection(&sim, &arbiter, &clock).await;
    baseline_taken(&state).await;

    {
        let mut state = state.lock().unwrap();
        state.horn = 1.0;
        state.light = 0.5;
    }

    let event = next_event(&clock, Duration::from_millis(50), session.events()).await;
    match event {
        DetectionEvent::Completed(DetectionOutcome::Detected { changes, ambiguous }) => {
            assert!(ambiguous);
            assert_eq!(changes.len(), 2);
            assert_eq!(changes[0].control_name, "Horn");
            assert_eq!(changes[1].control_name, "Light");
            assert_eq!(changes[1].current_value, 0.5);
        }
        other => panic!("expected ambiguous detection, got {other:?}"),
    }
    session.cancel().await.unwrap();
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
}

/// Mirrors "ignores changes below threshold (< 0.01)" and the nested-path
/// `extract_control_name` test (control_detection_session_test.exs:320-392,
/// 467-538): a 0.005 delta never fires and nested paths collapse to the last
/// path segment.
#[tokio::test]
async fn control_detection_ignores_changes_below_threshold() {
    let state = Arc::new(Mutex::new(ControlSimState::default()));
    let sim = control_detection_sim(&state);
    let clock = FakeClock::new();
    let arbiter = arbiter();
    let mut session = start_detection(&sim, &arbiter, &clock).await;
    baseline_taken(&state).await;

    state.lock().unwrap().horn = 0.005;

    // Two full 150ms poll cycles without a detection.
    clock.advance(Duration::from_millis(350));
    assert_quiet(|| assert!(session.events().try_recv().is_err())).await;

    // control_name mirrors extract_control_name/1.
    assert_eq!(
        control_detection::control_name("CurrentDrivableActor/Horn.InputValue"),
        "Horn"
    );
    assert_eq!(
        control_detection::control_name("CurrentDrivableActor/Throttle(Lever).InputValue"),
        "Throttle(Lever)"
    );
    assert_eq!(
        control_detection::control_name("CurrentDrivableActor/Group/Horn.InputValue"),
        "Horn"
    );

    session.cancel().await.unwrap();
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
}

/// Mirrors `@poll_interval_ms 150` / `@timeout_ms 30_000`
/// (control_detection_session.ex:28-31): polls at exact 150ms boundaries and
/// the 30s timeout fires instead of the poll scheduled for the same instant,
/// after exactly 199 polls.
#[tokio::test]
async fn control_detection_times_out_after_thirty_seconds() {
    let state = Arc::new(Mutex::new(ControlSimState::default()));
    let sim = control_detection_sim(&state);
    let clock = FakeClock::new();
    let arbiter = arbiter();
    let mut session = start_detection(&sim, &arbiter, &clock).await;
    baseline_taken(&state).await;
    yield_until(|| {
        clock
            .pending_deadlines()
            .contains(&(clock.now() + Duration::from_millis(150)))
            .then_some(())
    })
    .await;

    // 149ms: no poll yet; +1ms: the first poll runs.
    clock.advance(Duration::from_millis(149));
    assert_quiet(|| assert_eq!(state.lock().unwrap().subscription_gets, 1)).await;
    clock.advance(Duration::from_millis(1));
    yield_until(|| {
        let gets = state.lock().unwrap().subscription_gets;
        (gets == 2).then_some(gets)
    })
    .await;
    yield_until(|| {
        clock
            .pending_deadlines()
            .contains(&(clock.now() + Duration::from_millis(150)))
            .then_some(())
    })
    .await;

    // Remaining polls up to t=29_850.
    for expected in 3..=200_u64 {
        clock.advance(Duration::from_millis(150));
        yield_until(|| {
            let gets = state.lock().unwrap().subscription_gets;
            (gets == expected).then_some(gets)
        })
        .await;
        yield_until(|| {
            clock
                .pending_deadlines()
                .contains(&(clock.now() + Duration::from_millis(150)))
                .then_some(())
        })
        .await;
    }

    // t=30_000: the timeout message wins over the poll scheduled for the
    // same instant.
    clock.advance(Duration::from_millis(150));
    let event = next_event(&clock, Duration::from_millis(50), session.events()).await;
    assert_eq!(event, DetectionEvent::Completed(DetectionOutcome::TimedOut));
    assert_eq!(subscription_gets(&state).await, 200);

    session.cancel().await.unwrap();
    assert!(state.lock().unwrap().unsubscribes >= 1);
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
}

/// Mirrors the poll-error clause of `handle_info(:poll, ...)`
/// (control_detection_session.exs:131-136): failing polls are logged and
/// polling continues until a real change arrives.
#[tokio::test]
async fn control_detection_keeps_polling_through_errors() {
    let state = Arc::new(Mutex::new(ControlSimState {
        fail_subscription_gets: 2,
        ..ControlSimState::default()
    }));
    let sim = control_detection_sim(&state);
    let clock = FakeClock::new();
    let arbiter = arbiter();
    // Fast profile: the failing 500s are not retried, like Req in the tests.
    let client =
        Arc::new(SimulatorClient::with_profile(sim.url(), "key", TimeoutProfile::Fast).unwrap());
    let mut session = control_detection::start_control_detection(
        client,
        &arbiter,
        lease(),
        Arc::new(clock.clone()),
    )
    .unwrap();
    baseline_taken(&state).await;

    state.lock().unwrap().horn = 1.0;

    let event = next_event(&clock, Duration::from_millis(50), session.events()).await;
    match event {
        DetectionEvent::Completed(DetectionOutcome::Detected { changes, ambiguous }) => {
            assert!(!ambiguous);
            assert_eq!(changes[0].control_name, "Horn");
        }
        other => panic!("expected detection after transient errors, got {other:?}"),
    }
    // Baseline + 2 failing polls + the detecting poll.
    assert_eq!(subscription_gets(&state).await, 4);
    session.cancel().await.unwrap();
}

/// Mirrors "sends detection_error when list fails"
/// (control_detection_session_test.exs:96-118): a failing root list surfaces
/// as a `ListFailed` result (the Elixir `{:list_failed, reason}` error), with
/// the terminate cleanup still running.
#[tokio::test]
async fn control_detection_fails_when_discovery_fails() {
    let state = Arc::new(Mutex::new(ControlSimState {
        fail_root_list: true,
        ..ControlSimState::default()
    }));
    let sim = control_detection_sim(&state);
    let clock = FakeClock::new();
    let arbiter = arbiter();
    let client =
        Arc::new(SimulatorClient::with_profile(sim.url(), "key", TimeoutProfile::Fast).unwrap());
    let mut session = control_detection::start_control_detection(
        client,
        &arbiter,
        lease(),
        Arc::new(clock.clone()),
    )
    .unwrap();

    let event = next_event(&clock, Duration::from_millis(50), session.events()).await;
    match event {
        DetectionEvent::Failed(DetectionFailure::ListFailed(SimulatorError::HttpStatus {
            status,
            ..
        })) => assert_eq!(status, 500),
        other => panic!("expected list failure, got {other:?}"),
    }
    session.cancel().await.unwrap();
    assert!(state.lock().unwrap().unsubscribes >= 1);
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
}

/// Sessions own a resource-arbiter lease (the Rust replacement for the
/// SessionSupervisor single-session guarantee): a busy resource fails the
/// start call, and cancellation/drop release the lease without a UI listener.
#[tokio::test]
async fn control_detection_releases_its_lease_on_cancel_and_drop() {
    let state = Arc::new(Mutex::new(ControlSimState::default()));
    let sim = control_detection_sim(&state);
    let clock = FakeClock::new();
    let arbiter = arbiter();

    // Busy resource: the start fails synchronously with Busy.
    let held = arbiter.acquire(lease()).unwrap();
    let client = Arc::new(SimulatorClient::new(sim.url(), "key").unwrap());
    assert!(matches!(
        control_detection::start_control_detection(
            client,
            &arbiter,
            lease(),
            Arc::new(clock.clone())
        ),
        Err(ResourceError::Busy)
    ));
    arbiter.release(held).unwrap();

    // Explicit cancel releases the lease and unsubscribes.
    {
        let mut session = start_detection(&sim, &arbiter, &clock).await;
        baseline_taken(&state).await;
        session.cancel().await.unwrap();
        assert!(state.lock().unwrap().unsubscribes >= 1);
        yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
    }

    // Dropping the handle stops the session without a listener.
    {
        let state = Arc::new(Mutex::new(ControlSimState::default()));
        let sim = control_detection_sim(&state);
        let clock = FakeClock::new();
        let arb = Arc::new(ResourceArbiter::new(Arc::new(FakeConsumers)));
        let session = start_detection(&sim, &arb, &clock).await;
        baseline_taken(&state).await;
        let unsubscribes = state.lock().unwrap().unsubscribes;
        drop(session);
        yield_until(|| {
            let state = state.lock().unwrap();
            (!arb.is_suspended() && state.unsubscribes > unsubscribes).then_some(())
        })
        .await;
    }
}

// ===========================================================================
// Lever analysis (Trenino.Simulator.LeverAnalyzer)
// ===========================================================================

/// Mirrors `stub_sweep_responses/2` (lever_analyzer_test.exs:198-291): PATCH
/// records the last set value; GETs answer by endpoint suffix.
fn lever_analysis_sim(
    min_input: f64,
    max_input: f64,
    behavior: impl Fn(f64) -> (f64, f64, i64) + Send + Sync + 'static,
) -> FakeSim {
    let last_set = Arc::new(Mutex::new(0.0_f64));
    let last = last_set.clone();
    FakeSim::spawn(move |request| {
        if request.method == "PATCH" {
            *last.lock().unwrap() = request.set_value();
            return ok(json!({"Result": "Success"}));
        }
        let set = *last.lock().unwrap();
        let (actual, output, notch) = behavior(set);
        let path = request.path.as_str();
        if path.contains("GetMinimumInputValue") {
            ok(json!({"Result": "Success", "Values": {"ReturnValue": min_input}}))
        } else if path.contains("GetMaximumInputValue") {
            ok(json!({"Result": "Success", "Values": {"ReturnValue": max_input}}))
        } else if path.contains("GetCurrentOutputValue") {
            ok(json!({"Result": "Success", "Values": {"ReturnValue": output}}))
        } else if path.contains("GetCurrentNotchIndex") {
            ok(json!({"Result": "Success", "Values": {"ReturnValue": notch}}))
        } else if path.contains(".InputValue") {
            ok(json!({"Result": "Success", "Values": {"InputValue": actual}}))
        } else {
            not_found()
        }
    })
}

/// Runs `analyze` on a spawned task while driving the fake clock past the
/// push-attempt delays (the session variant drives the clock itself).
async fn analyze_driven(
    client: &SimulatorClient,
    clock: &FakeClock,
    control_path: &str,
    options: &AnalysisOptions,
) -> Result<trenino_core::calibration::analysis::AnalysisResult, AnalysisFailure> {
    let client = client.clone();
    let task_clock: Arc<dyn Clock> = Arc::new(clock.clone());
    let control_path = control_path.to_owned();
    let options = options.clone();
    let handle = tokio::spawn(async move {
        lever_analysis::analyze(&client, &task_clock, &control_path, &options).await
    });
    advance_until(clock, Duration::from_millis(30), || {
        handle.is_finished().then_some(())
    })
    .await;
    handle.await.expect("analysis task panicked")
}

fn fast_options() -> AnalysisOptions {
    AnalysisOptions {
        settling_time: Duration::ZERO,
        ..AnalysisOptions::default()
    }
}

/// Mirrors "sweeps lever and collects samples for discrete lever"
/// (lever_analyzer_test.exs:23-44): three snap zones with integer outputs
/// classify as discrete with all-gate suggested notches. Runs through the
/// session wrapper so the analysis also proves its lease is released.
#[tokio::test]
async fn lever_analysis_classifies_discrete_lever_and_releases_lease() {
    let sim = lever_analysis_sim(0.0, 1.0, |input| {
        if input < 0.33 {
            (0.0, -1.0, 0)
        } else if input < 0.66 {
            (0.5, 0.0, 1)
        } else {
            (1.0, 1.0, 2)
        }
    });
    let clock = FakeClock::new();
    let arbiter = arbiter();
    let client = Arc::new(SimulatorClient::new(sim.url(), "key").unwrap());
    let mut session = lever_analysis::start_lever_analysis(
        client,
        &arbiter,
        lease(),
        Arc::new(clock.clone()),
        "CurrentDrivableActor/Reverser".to_owned(),
        fast_options(),
    )
    .unwrap();

    // The five 30ms push attempts are the only sleeps (settling time is 0).
    let event = next_event(&clock, Duration::from_millis(30), session.events()).await;
    let result = match event {
        lever_analysis::AnalysisEvent::Completed(result) => result,
        other => panic!("expected completed analysis, got {other:?}"),
    };
    assert_eq!(result.lever_type, LeverType::Discrete);
    assert!(result.all_outputs_integers);
    assert_eq!(result.unique_output_count, 3);
    assert!(!result.suggested_notches.is_empty());
    assert!(result
        .suggested_notches
        .iter()
        .all(|notch| notch.kind == ZoneType::Gate));

    session.cancel().await.unwrap();
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
}

/// Mirrors "sweeps lever and collects samples for continuous lever"
/// (lever_analyzer_test.exs:46-61).
#[tokio::test]
async fn lever_analysis_classifies_continuous_lever() {
    let sim = lever_analysis_sim(0.0, 1.0, |input| (input, input, 0));
    let client = SimulatorClient::new(sim.url(), "key").unwrap();
    let clock = FakeClock::new();
    let result = analyze_driven(
        &client,
        &clock,
        "CurrentDrivableActor/Throttle",
        &fast_options(),
    )
    .await
    .unwrap();
    assert_eq!(result.lever_type, LeverType::Continuous);
    assert!(!result.all_outputs_integers);
    assert!(result.unique_output_count >= 20);
    assert_eq!(result.suggested_notches.len(), 1);
    assert_eq!(result.suggested_notches[0].kind, ZoneType::Linear);
}

/// Mirrors "sweeps full -1 to 1 input range for irregular lever"
/// (lever_analyzer_test.exs:93-134): eight snap zones across a -1..1 range.
#[tokio::test]
async fn lever_analysis_sweeps_full_negative_to_positive_range() {
    let sim = lever_analysis_sim(-1.0, 1.0, |input| {
        if input < -0.75 {
            (-1.0, -4.0, 0)
        } else if input < -0.50 {
            (-0.75, -3.0, 1)
        } else if input < -0.25 {
            (-0.50, -2.0, 2)
        } else if input < 0.0 {
            (-0.25, -1.0, 3)
        } else if input < 0.25 {
            (0.0, 0.0, 4)
        } else if input < 0.50 {
            (0.25, 1.0, 5)
        } else if input < 0.75 {
            (0.50, 2.0, 6)
        } else {
            (1.0, 3.0, 7)
        }
    });
    let client = SimulatorClient::new(sim.url(), "key").unwrap();
    let clock = FakeClock::new();
    let result = analyze_driven(
        &client,
        &clock,
        "CurrentDrivableActor/ThrottleAndBrake",
        &fast_options(),
    )
    .await
    .unwrap();
    assert_eq!(result.lever_type, LeverType::Discrete);
    assert_eq!(result.zones.len(), 8);
    let set_inputs: Vec<f64> = result.samples.iter().map(|s| s.set_input).collect();
    assert!(set_inputs.iter().fold(f64::INFINITY, |a, b| a.min(*b)) <= -1.0);
    assert!(set_inputs.iter().fold(f64::NEG_INFINITY, |a, b| a.max(*b)) >= 1.0);
}

/// Mirrors "returns error when insufficient samples are collected"
/// (lever_analyzer_test.exs:136-145): a dead endpoint yields no samples.
#[tokio::test]
async fn lever_analysis_reports_insufficient_samples() {
    // Bind, then close: the client gets connection refused without retries.
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let url = format!("http://{}", listener.local_addr().unwrap());
    drop(listener);
    let client = SimulatorClient::with_profile(&url, "key", TimeoutProfile::Fast).unwrap();
    let clock = FakeClock::new();
    assert_eq!(
        analyze_driven(
            &client,
            &clock,
            "CurrentDrivableActor/TestLever",
            &fast_options()
        )
        .await
        .unwrap_err(),
        AnalysisFailure::InsufficientSamples
    );
}

/// Mirrors the quick_check tests (lever_analyzer_test.exs:148-195), including
/// the `expect(Req, :request, 10, ...)` shape: all five strategic positions
/// are sampled even when reads fail, and failures collapse to
/// `{:error, :sample_failed}`.
#[tokio::test]
async fn lever_quick_check_classifies_and_surfaces_sample_failures() {
    // Integer outputs at every point -> discrete.
    let sim = FakeSim::spawn(|request| {
        if request.method == "PATCH" {
            return ok(json!({"Result": "Success"}));
        }
        ok(json!({"Result": "Success", "Values": {"ReturnValue": 1.0}}))
    });
    let client = SimulatorClient::new(sim.url(), "key").unwrap();
    let clock: Arc<dyn Clock> = Arc::new(FakeClock::new());
    assert_eq!(
        lever_analysis::quick_check(
            &client,
            &clock,
            "CurrentDrivableActor/Reverser",
            Duration::ZERO
        )
        .await
        .unwrap(),
        QuickCheck::Discrete
    );
    assert_eq!(sim.request_count(), 10);

    // Fractional outputs -> continuous.
    let counter = Arc::new(Mutex::new(0_u32));
    let counted = counter.clone();
    let sim = FakeSim::spawn(move |request| {
        if request.method == "PATCH" {
            return ok(json!({"Result": "Success"}));
        }
        let mut count = counted.lock().unwrap();
        *count += 1;
        let value = f64::from(*count) * 0.25;
        ok(json!({"Result": "Success", "Values": {"ReturnValue": value}}))
    });
    let client = SimulatorClient::new(sim.url(), "key").unwrap();
    assert_eq!(
        lever_analysis::quick_check(
            &client,
            &clock,
            "CurrentDrivableActor/Throttle",
            Duration::ZERO
        )
        .await
        .unwrap(),
        QuickCheck::Continuous
    );

    // Every read fails: all five points are still attempted, then the
    // generic sample_failed error surfaces (the underlying reason is lost,
    // exactly like the Elixir wrapper).
    let sim = FakeSim::spawn(|request| {
        if request.method == "PATCH" {
            return ok(json!({"Result": "Success"}));
        }
        (404, r#"{"error":"missing"}"#.to_owned())
    });
    let client = SimulatorClient::new(sim.url(), "key").unwrap();
    assert_eq!(
        lever_analysis::quick_check(
            &client,
            &clock,
            "CurrentDrivableActor/Reverser",
            Duration::ZERO
        )
        .await
        .unwrap_err(),
        QuickCheckError::SampleFailed
    );
    assert_eq!(sim.request_count(), 10);
}

// ===========================================================================
// Train detection (Trenino.Train.Detection)
// ===========================================================================

#[derive(Default)]
struct TrainSimState {
    object_class: String,
    fail_object_class: bool,
    drivable_gets: u64,
}

fn train_detection_sim(state: &Arc<Mutex<TrainSimState>>) -> FakeSim {
    let state = state.clone();
    FakeSim::spawn(move |request| {
        if request.method != "GET" {
            return not_found();
        }
        let mut state = state.lock().unwrap();
        let path = request.path.as_str();
        if path.starts_with("/get/CurrentFormation/") && path.ends_with(".ObjectClass") {
            if state.fail_object_class {
                return (404, r#"{"error":"gone"}"#.to_owned());
            }
            return ok(json!({
                "Result": "Success",
                "Values": {"ReturnValue": state.object_class}
            }));
        }
        if path == "/get/CurrentFormation.DrivableIndex" {
            state.drivable_gets += 1;
            return ok(json!({"Result": "Success", "Values": {"ReturnValue": 0}}));
        }
        not_found()
    })
}

fn profiles(list: &[(&str, &str, &[&str])]) -> Vec<TrainProfile> {
    list.iter()
        .map(|(id, name, identifiers)| TrainProfile {
            id: id.parse().unwrap(),
            name: (*name).to_owned(),
            identifiers: identifiers.iter().map(|s| (*s).to_owned()).collect(),
        })
        .collect()
}

struct FakeProfiles(Vec<TrainProfile>);
impl train_detection::ProfileSource for FakeProfiles {
    fn profiles(&self) -> Vec<TrainProfile> {
        self.0.clone()
    }
}

async fn drivable_gets(state: &Arc<Mutex<TrainSimState>>) -> u64 {
    yield_until(|| Some(state.lock().unwrap().drivable_gets)).await
}

/// Mirrors "clears state and broadcasts train_changed nil on disconnect" and
/// the no-active-train grace test (detection_test.exs:53-71, 315-330):
/// disconnecting with no active train deactivates immediately (no grace).
#[tokio::test]
async fn train_detection_disconnect_without_train_deactivates_immediately() {
    let state = Arc::new(Mutex::new(TrainSimState {
        object_class: "RVM_PBO_Class142_DMSL_C".to_owned(),
        ..TrainSimState::default()
    }));
    // The monitor never connects, so no fake server is needed; only the
    // shared profile source answers the disconnect.
    let clock = FakeClock::new();
    let (monitor, mut events) = train_detection::TrainDetectionMonitor::start(
        Arc::new(clock.clone()),
        Arc::new(FakeProfiles(profiles(&[(
            "7",
            "Class 142",
            &["RVM_PBO_Class142"],
        )]))),
    );

    monitor.disconnected().await.unwrap();
    let event = next_event(&clock, Duration::from_millis(50), &mut events).await;
    assert_eq!(event, TrainDetectionEvent::TrainChanged(None));

    // No grace polls follow: polling stays disabled.
    assert_eq!(drivable_gets(&state).await, 0);
    let (first, second) = tokio::join!(monitor.shutdown(), monitor.shutdown());
    first.unwrap();
    second.unwrap();
    monitor.shutdown().await.unwrap();
    assert!(monitor.sync().await.is_err());
}

/// Mirrors "enables polling on connect" plus the matching flow of
/// `handle_identifier_detected/2` (detection.ex:248-303): detection events,
/// change events, the `_C` suffix strip and the unchanged-identifier silence.
#[tokio::test]
async fn train_detection_reports_train_and_change_events() {
    let state = Arc::new(Mutex::new(TrainSimState {
        object_class: "RVM_PBO_Class142_DMSL_C".to_owned(),
        ..TrainSimState::default()
    }));
    let sim = train_detection_sim(&state);
    let clock = FakeClock::new();
    let (monitor, mut events) = train_detection::TrainDetectionMonitor::start(
        Arc::new(clock.clone()),
        Arc::new(FakeProfiles(profiles(&[
            ("7", "Class 142", &["RVM_PBO_Class142"]),
            ("9", "DB BR 430", &["RVM_FSN_DB_BR430"]),
        ]))),
    );

    let client = Arc::new(SimulatorClient::new(sim.url(), "key").unwrap());
    monitor.connected(client).await.unwrap();

    // Immediate detection: identifier normalized (_C stripped), train matched.
    let detected = next_event(&clock, Duration::from_millis(50), &mut events).await;
    match detected {
        TrainDetectionEvent::TrainDetected { identifier, train } => {
            assert_eq!(identifier, "RVM_PBO_Class142_DMSL");
            assert_eq!(train.as_ref().unwrap().id, 7);
        }
        other => panic!("expected detection, got {other:?}"),
    }
    let changed = next_event(&clock, Duration::from_millis(50), &mut events).await;
    match changed {
        TrainDetectionEvent::TrainChanged(train) => assert_eq!(train.unwrap().id, 7),
        other => panic!("expected train change, got {other:?}"),
    }
    assert_eq!(drivable_gets(&state).await, 1);

    // Same identifier on the next poll: no events at all.
    clock.advance(Duration::from_secs(5));
    yield_until(|| {
        let gets = state.lock().unwrap().drivable_gets;
        (gets == 2).then_some(gets)
    })
    .await;
    settle().await;
    assert_quiet(|| assert!(events.try_recv().is_err())).await;

    // A different formation changes the detected train.
    state.lock().unwrap().object_class = "RVM_FSN_DB_BR430_ETW4_C".to_owned();
    clock.advance(Duration::from_secs(5));
    let detected = next_event(&clock, Duration::from_millis(50), &mut events).await;
    match detected {
        TrainDetectionEvent::TrainDetected { identifier, train } => {
            assert_eq!(identifier, "RVM_FSN_DB_BR430_ETW4");
            assert_eq!(train.unwrap().id, 9);
        }
        other => panic!("expected second detection, got {other:?}"),
    }
    let changed = next_event(&clock, Duration::from_millis(50), &mut events).await;
    match changed {
        TrainDetectionEvent::TrainChanged(train) => assert_eq!(train.unwrap().id, 9),
        other => panic!("expected train change to 9, got {other:?}"),
    }

    monitor.shutdown().await.unwrap();
}

/// Mirrors `@poll_interval_ms 5_000` (detection.ex:29): the poll fires at
/// exact five-second boundaries only.
#[tokio::test]
async fn train_detection_polls_every_five_seconds() {
    let state = Arc::new(Mutex::new(TrainSimState {
        object_class: "RVM_PBO_Class142_DMSL_C".to_owned(),
        ..TrainSimState::default()
    }));
    let sim = train_detection_sim(&state);
    let clock = FakeClock::new();
    let (monitor, mut events) = train_detection::TrainDetectionMonitor::start(
        Arc::new(clock.clone()),
        Arc::new(FakeProfiles(profiles(&[(
            "7",
            "Class 142",
            &["RVM_PBO_Class142"],
        )]))),
    );
    let client = Arc::new(SimulatorClient::new(sim.url(), "key").unwrap());
    monitor.connected(client).await.unwrap();
    // Initial loopback IO must settle without advancing logical time. The
    // general next_event driver advances 50ms per probe, which made the
    // following 4900ms advance cross the 5s boundary on a loaded host.
    for _ in 0..2 {
        let _ = yield_until(|| events.try_recv().ok()).await;
    }
    let poll_at = clock.now() + train_detection::POLL_INTERVAL;
    yield_until(|| clock.pending_deadlines().contains(&poll_at).then_some(())).await;
    assert_eq!(drivable_gets(&state).await, 1);

    clock.advance(Duration::from_millis(4_900));
    assert_quiet(|| assert_eq!(state.lock().unwrap().drivable_gets, 1)).await;
    clock.advance(Duration::from_millis(100));
    yield_until(|| {
        let gets = state.lock().unwrap().drivable_gets;
        (gets == 2).then_some(gets)
    })
    .await;
    settle().await;

    monitor.shutdown().await.unwrap();
}

/// Mirrors `handle_identifier_detected/2` ambiguous branch
/// (detection.ex:283-301): several matching stored profiles report
/// `MultipleTrainsMatch` and deactivate instead of picking one.
#[tokio::test]
async fn train_detection_reports_ambiguity() {
    let state = Arc::new(Mutex::new(TrainSimState {
        object_class: "RVM_DUP_Class66_Rivers_C".to_owned(),
        ..TrainSimState::default()
    }));
    let sim = train_detection_sim(&state);
    let clock = FakeClock::new();
    let (monitor, mut events) = train_detection::TrainDetectionMonitor::start(
        Arc::new(clock.clone()),
        Arc::new(FakeProfiles(profiles(&[
            ("1", "Class 66 A", &["RVM_DUP"]),
            ("2", "Class 66 B", &["RVM_DUP"]),
        ]))),
    );
    let client = Arc::new(SimulatorClient::new(sim.url(), "key").unwrap());
    monitor.connected(client).await.unwrap();

    let detected = next_event(&clock, Duration::from_millis(50), &mut events).await;
    match detected {
        TrainDetectionEvent::TrainDetected { identifier, train } => {
            assert_eq!(identifier, "RVM_DUP_Class66_Rivers");
            assert!(train.is_none());
        }
        other => panic!("expected detection, got {other:?}"),
    }
    let ambiguous = next_event(&clock, Duration::from_millis(50), &mut events).await;
    match ambiguous {
        TrainDetectionEvent::MultipleTrainsMatch { identifier, trains } => {
            assert_eq!(identifier, "RVM_DUP_Class66_Rivers");
            assert_eq!(trains.iter().map(|t| t.id).collect::<Vec<_>>(), vec![1, 2]);
        }
        other => panic!("expected ambiguity, got {other:?}"),
    }
    // No active train existed, so no TrainChanged follows.
    assert_quiet(|| assert!(events.try_recv().is_err())).await;
    monitor.shutdown().await.unwrap();
}

/// Mirrors the grace-period suite (detection_test.exs:169-246): disconnect
/// with an active train enters grace instead of deactivating, successful
/// 200ms probes keep the profile alive and refresh the contact time, and
/// expiry after an exact 30s without contact deactivates the train.
#[tokio::test]
async fn train_detection_grace_probes_then_expires_after_thirty_seconds() {
    let state = Arc::new(Mutex::new(TrainSimState {
        object_class: "RVM_PBO_Class142_DMSL_C".to_owned(),
        ..TrainSimState::default()
    }));
    let sim = train_detection_sim(&state);
    let clock = FakeClock::new();
    let (monitor, mut events) = train_detection::TrainDetectionMonitor::start(
        Arc::new(clock.clone()),
        Arc::new(FakeProfiles(profiles(&[(
            "7",
            "Class 142",
            &["RVM_PBO_Class142"],
        )]))),
    );
    let client = Arc::new(SimulatorClient::new(sim.url(), "key").unwrap());
    monitor.connected(client).await.unwrap();
    for _ in 0..2 {
        let _ = next_event(&clock, Duration::from_millis(50), &mut events).await;
    }
    assert_eq!(drivable_gets(&state).await, 1);

    // Disconnect: grace starts instead of deactivation.
    monitor.disconnected().await.unwrap();
    assert_quiet(|| {
        assert!(
            events.try_recv().is_err(),
            "no train_changed while in grace"
        )
    })
    .await;

    // Five successful 200ms grace probes keep the train alive.
    let mut polls = 1_u64;
    for _ in 0..5 {
        clock.advance(Duration::from_millis(200));
        polls += 1;
        yield_until(|| {
            let gets = state.lock().unwrap().drivable_gets;
            (gets == polls).then_some(gets)
        })
        .await;
        settle().await;
    }
    assert_quiet(|| {
        assert!(
            events.try_recv().is_err(),
            "successful probes keep the profile"
        )
    })
    .await;
    let successful_polls = polls;

    // The simulator goes away: probes fail until 30s pass without contact.
    state.lock().unwrap().fail_object_class = true;
    let mut advanced = Duration::ZERO;
    let expiry = loop {
        clock.advance(Duration::from_millis(200));
        advanced += Duration::from_millis(200);
        polls += 1;
        yield_until(|| {
            let gets = state.lock().unwrap().drivable_gets;
            (gets == polls).then_some(gets)
        })
        .await;
        settle().await;
        match events.try_recv() {
            Ok(TrainDetectionEvent::TrainChanged(None)) => break advanced,
            Ok(other) => panic!("unexpected event during grace: {other:?}"),
            Err(_) => {}
        }
        assert!(advanced < Duration::from_secs(35), "grace never expired");
    };
    // 30s from the last successful probe, in exact 200ms steps.
    assert_eq!(expiry, Duration::from_secs(30));
    assert_eq!(polls - successful_polls, 150);

    monitor.shutdown().await.unwrap();
}

/// Mirrors "connection recovery during grace exits grace cleanly"
/// (detection_test.exs:248-280): the grace client stops, normal polling
/// resumes and the same train stays detected without spurious events.
#[tokio::test]
async fn train_detection_reconnect_exits_grace_without_losing_the_train() {
    let state = Arc::new(Mutex::new(TrainSimState {
        object_class: "RVM_PBO_Class142_DMSL_C".to_owned(),
        ..TrainSimState::default()
    }));
    let sim = train_detection_sim(&state);
    let clock = FakeClock::new();
    let (monitor, mut events) = train_detection::TrainDetectionMonitor::start(
        Arc::new(clock.clone()),
        Arc::new(FakeProfiles(profiles(&[(
            "7",
            "Class 142",
            &["RVM_PBO_Class142"],
        )]))),
    );
    let client = Arc::new(SimulatorClient::new(sim.url(), "key").unwrap());
    monitor.connected(client.clone()).await.unwrap();
    for _ in 0..2 {
        let _ = next_event(&clock, Duration::from_millis(50), &mut events).await;
    }
    assert_eq!(drivable_gets(&state).await, 1);

    monitor.disconnected().await.unwrap();
    // Let the worker process the disconnect and arm the first grace timer
    // before any fake time passes, keeping the 200ms grid exact.
    settle().await;
    // Three grace polls, each on its exact 200ms boundary.
    let mut polls = 1_u64;
    for _ in 0..3 {
        clock.advance(Duration::from_millis(200));
        polls += 1;
        yield_until(|| {
            let gets = state.lock().unwrap().drivable_gets;
            (gets == polls).then_some(gets)
        })
        .await;
        settle().await;
    }

    // Reconnect: grace is exited and the same train stays detected, so the
    // immediate poll is silent (same identifier).
    monitor.connected(client).await.unwrap();
    yield_until(|| {
        let gets = state.lock().unwrap().drivable_gets;
        (gets == polls + 1).then_some(gets)
    })
    .await;
    assert_quiet(|| assert!(events.try_recv().is_err())).await;

    monitor.shutdown().await.unwrap();
}

// ===========================================================================
// Lever calibration session (Trenino.Train.Calibration.LeverSession)
// ===========================================================================

#[derive(Default)]
struct CalibrationSimState {
    min_value: f64,
    max_value: f64,
    notch_count: i64,
    set_milli: f64,
    gate: bool,
    fail_min: bool,
}

fn lever_calibration_sim(state: &Arc<Mutex<CalibrationSimState>>) -> FakeSim {
    let state = state.clone();
    FakeSim::spawn(move |request| {
        let mut state = state.lock().unwrap();
        let set = state.set_milli / 1000.0;
        match (
            request.method.as_str(),
            request.path.split('?').next().unwrap_or(""),
        ) {
            ("PATCH", "/set/Throttle.Value") => {
                state.set_milli = request.set_value() * 1000.0;
                ok(json!({"Result": "Success"}))
            }
            ("GET", "/get/Throttle.Min") => {
                if state.fail_min {
                    return (404, r#"{"error":"gone"}"#.to_owned());
                }
                ok(json!({"Result": "Success", "Values": {"ReturnValue": state.min_value}}))
            }
            ("GET", "/get/Throttle.Max") => {
                ok(json!({"Result": "Success", "Values": {"ReturnValue": state.max_value}}))
            }
            ("GET", "/get/Throttle.NotchCount") => {
                ok(json!({"Result": "Success", "Values": {"ReturnValue": state.notch_count}}))
            }
            ("GET", "/get/Throttle.Value") => {
                if state.gate {
                    let snapped = if set < 0.25 {
                        0.0
                    } else if set < 0.75 {
                        0.5
                    } else {
                        1.0
                    };
                    ok(json!({"Result": "Success", "Values": {"InputValue": snapped}}))
                } else {
                    ok(json!({"Result": "Success", "Values": {"InputValue": set}}))
                }
            }
            ("GET", "/get/Throttle.NotchIndex") => {
                let index = if state.gate {
                    if set < 0.25 {
                        0
                    } else if set < 0.75 {
                        1
                    } else {
                        2
                    }
                } else if set < 0.5 {
                    0
                } else {
                    1
                };
                ok(json!({"Result": "Success", "Values": {"ReturnValue": index}}))
            }
            _ => not_found(),
        }
    })
}

#[derive(Default)]
struct FakeStore {
    saves: Mutex<Vec<(i64, Vec<lever_calib::NotchDraft>)>>,
    range_saves: Mutex<Vec<(i64, Vec<lever_calib::NotchRangeUpdate>, bool)>>,
    checkpoints: Mutex<HashMap<i64, lever_calib::MappingCheckpoint>>,
}

impl CalibrationStore for FakeStore {
    fn save_lever_calibration(
        &self,
        lever_config_id: i64,
        notches: &[lever_calib::NotchDraft],
    ) -> Result<(), lever_calib::CalibrationStoreError> {
        self.saves
            .lock()
            .unwrap()
            .push((lever_config_id, notches.to_vec()));
        Ok(())
    }

    fn save_notch_input_ranges(
        &self,
        lever_config_id: i64,
        updates: &[lever_calib::NotchRangeUpdate],
        inverted: bool,
    ) -> Result<(), lever_calib::CalibrationStoreError> {
        self.range_saves
            .lock()
            .unwrap()
            .push((lever_config_id, updates.to_vec(), inverted));
        Ok(())
    }

    fn save_mapping_checkpoint(
        &self,
        lever_config_id: i64,
        checkpoint: &lever_calib::MappingCheckpoint,
    ) -> Result<(), lever_calib::CalibrationStoreError> {
        self.checkpoints
            .lock()
            .unwrap()
            .insert(lever_config_id, checkpoint.clone());
        Ok(())
    }

    fn load_mapping_checkpoint(
        &self,
        lever_config_id: i64,
    ) -> Result<Option<lever_calib::MappingCheckpoint>, lever_calib::CalibrationStoreError> {
        Ok(self
            .checkpoints
            .lock()
            .unwrap()
            .get(&lever_config_id)
            .cloned())
    }
}

fn lever_endpoints() -> lever_calib::LeverEndpointSet {
    lever_calib::LeverEndpointSet {
        lever_config_id: 42,
        min_endpoint: "Throttle.Min".to_owned(),
        max_endpoint: "Throttle.Max".to_owned(),
        value_endpoint: "Throttle.Value".to_owned(),
        notch_count_endpoint: "Throttle.NotchCount".to_owned(),
        notch_index_endpoint: "Throttle.NotchIndex".to_owned(),
    }
}

/// Runs a full lever calibration against `sim`, driving the fake clock past
/// the 5ms step delays, and returns every broadcast plus the arbiter.
async fn run_lever_calibration(
    sim: &FakeSim,
    store: Arc<FakeStore>,
) -> (Vec<CalibrationEvent>, Arc<ResourceArbiter>) {
    let clock = FakeClock::new();
    let arbiter = arbiter();
    let client = Arc::new(SimulatorClient::new(sim.url(), "key").unwrap());
    let mut session = lever_calib::start_lever_calibration(
        client,
        &arbiter,
        lease(),
        Arc::new(clock.clone()),
        lever_endpoints(),
        store,
    )
    .unwrap();
    let mut events = Vec::new();
    advance_until(&clock, Duration::from_millis(5), || {
        while let Ok(event) = session.events().try_recv() {
            let done = matches!(event, CalibrationEvent::Result(_));
            events.push(event);
            if done {
                return Some(());
            }
        }
        None
    })
    .await;
    session.cancel().await.unwrap();
    (events, arbiter)
}

fn result_of(events: &[CalibrationEvent]) -> lever_calib::CompletedCalibration {
    match events.last() {
        Some(CalibrationEvent::Result(Ok(completed))) => completed.clone(),
        other => panic!("expected successful calibration result, got {other:?}"),
    }
}

/// Mirrors "creates a single linear notch spanning full range"
/// (lever_session_test.exs:51-99): notch_count == 1 skips the sweep and saves
/// a linear notch covering min..max.
#[tokio::test]
async fn lever_calibration_creates_single_linear_notch() {
    let state = Arc::new(Mutex::new(CalibrationSimState {
        min_value: 0.0,
        max_value: 1.0,
        notch_count: 1,
        ..CalibrationSimState::default()
    }));
    let sim = lever_calibration_sim(&state);
    let store = Arc::new(FakeStore::default());
    let (events, arbiter) = run_lever_calibration(&sim, store.clone()).await;

    let completed = result_of(&events);
    assert_eq!(completed.lever_config_id, 42);
    assert_eq!(
        completed.notches,
        vec![lever_calib::NotchDraft {
            index: 0,
            kind: NotchKind::Linear,
            value: None,
            min_value: Some(0.0),
            max_value: Some(1.0),
            description: "Notch 0".to_owned(),
        }]
    );
    assert_eq!(store.saves.lock().unwrap().len(), 1);
    // The single-notch path broadcasts :saving before the result, like
    // initialize_single_notch/3 setting step: :saving.
    match events.first() {
        Some(CalibrationEvent::Progress(progress)) => {
            assert_eq!(progress.step, CalibrationStep::Saving);
            assert_eq!(progress.lever_config_id, 42);
            assert_eq!(progress.progress, 1.0);
        }
        other => panic!("expected saving progress first, got {other:?}"),
    }
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
}

/// Mirrors "detects gate notches with correct values"
/// (lever_session_test.exs:101-188): snapped reads classify every notch as a
/// gate holding the snapped value.
#[tokio::test]
async fn lever_calibration_detects_gate_notches() {
    let state = Arc::new(Mutex::new(CalibrationSimState {
        min_value: 0.0,
        max_value: 1.0,
        notch_count: 3,
        gate: true,
        ..CalibrationSimState::default()
    }));
    let sim = lever_calibration_sim(&state);
    let store = Arc::new(FakeStore::default());
    let (events, arbiter) = run_lever_calibration(&sim, store.clone()).await;

    let completed = result_of(&events);
    let notches = completed.notches;
    assert_eq!(notches.len(), 3);
    let expected = [(0_i64, 0.0_f64), (1, 0.5), (2, 1.0)];
    for (notch, (index, value)) in notches.iter().zip(expected) {
        assert_eq!(notch.index, index, "notch {index}");
        assert_eq!(notch.kind, NotchKind::Gate);
        assert_eq!(notch.value, Some(value));
        assert_eq!(notch.min_value, None);
        assert_eq!(notch.max_value, None);
        assert_eq!(notch.description, format!("Notch {index}"));
    }
    assert_eq!(store.saves.lock().unwrap().len(), 1);
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
}

/// Mirrors "broadcasts progress during calibration"
/// (lever_session_test.exs:264-317). The fixture lever echoes every set
/// value, but unlike the Mimic-based ExUnit case ("detects linear notches
/// when values are accepted as-is", lever_session_test.exs:190-262, which
/// stubs `Client.get_float` and skips its rounding), the accepted client
/// rounds reads to two decimals (client.ex:198 / get_float). A 0.025 step
/// therefore reads back +/-0.005, above the 0.001 gate tolerance, so every
/// notch records gate evidence with the last two-decimal read as its value —
/// exactly what the Elixir production stack computes for the same lever.
#[tokio::test]
async fn lever_calibration_broadcasts_progress_and_gates_rounded_read_back() {
    let state = Arc::new(Mutex::new(CalibrationSimState {
        min_value: 0.0,
        max_value: 1.0,
        notch_count: 2,
        gate: false,
        ..CalibrationSimState::default()
    }));
    let sim = lever_calibration_sim(&state);
    let store = Arc::new(FakeStore::default());
    let (events, arbiter) = run_lever_calibration(&sim, store.clone()).await;

    let completed = result_of(&events);
    // Notch 0 ends at the 0.5 boundary; its last read was round2(0.475) = 0.47.
    // Notch 1's last read was round2(0.975) = 0.97.
    assert_eq!(
        completed.notches,
        vec![
            lever_calib::NotchDraft {
                index: 0,
                kind: NotchKind::Gate,
                value: Some(0.47),
                min_value: None,
                max_value: None,
                description: "Notch 0".to_owned(),
            },
            lever_calib::NotchDraft {
                index: 1,
                kind: NotchKind::Gate,
                value: Some(0.97),
                min_value: None,
                max_value: None,
                description: "Notch 1".to_owned(),
            },
        ]
    );

    // Progress: first a calibrating broadcast at 0.0, then monotonically
    // increasing sweep progress up to the final result.
    let progress: Vec<lever_calib::CalibrationProgress> = events
        .iter()
        .filter_map(|event| match event {
            CalibrationEvent::Progress(progress) => Some(progress.clone()),
            _ => None,
        })
        .collect();
    assert!(progress.len() >= 2);
    assert_eq!(progress[0].step, CalibrationStep::Calibrating);
    assert_eq!(progress[0].progress, 0.0);
    assert_eq!(progress[0].lever_config_id, 42);
    for pair in progress.windows(2) {
        assert!(pair[1].progress >= pair[0].progress, "progress regressed");
    }
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
}

/// Mirrors "handles API errors gracefully"
/// (lever_session_test.exs:319-335): an init failure broadcasts only the
/// error result and nothing is persisted.
#[tokio::test]
async fn lever_calibration_surfaces_client_errors() {
    let state = Arc::new(Mutex::new(CalibrationSimState {
        fail_min: true,
        ..CalibrationSimState::default()
    }));
    let sim = lever_calibration_sim(&state);
    let store = Arc::new(FakeStore::default());
    let (events, arbiter) = run_lever_calibration(&sim, store.clone()).await;
    assert_eq!(events.len(), 1);
    match events.last() {
        Some(CalibrationEvent::Result(Err(lever_calib::CalibrationFailure::Simulator(_)))) => {}
        other => panic!("expected simulator failure, got {other:?}"),
    }
    assert!(store.saves.lock().unwrap().is_empty());
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
}

// ===========================================================================
// Notch mapping wizard (Trenino.Train.Calibration.NotchMappingSession)
// ===========================================================================

fn mapping_config(notches: Vec<NotchDefinition>) -> NotchMappingConfig {
    NotchMappingConfig {
        lever_config_id: 42,
        pin: 5,
        calibration: Calibration {
            min_value: 100,
            max_value: 900,
            max_hardware_value: 1023,
            inverted: false,
            rollover: false,
        },
        notches,
    }
}

fn wizard_notches(sim_inputs: &[(Option<f64>, Option<f64>)]) -> Vec<NotchDefinition> {
    sim_inputs
        .iter()
        .enumerate()
        .map(|(index, (min, max))| NotchDefinition {
            id: 100 + index as i64,
            index: index as i64,
            kind: if index % 2 == 0 {
                NotchKind::Gate
            } else {
                NotchKind::Linear
            },
            description: format!("Notch {index}"),
            sim_input_min: *min,
            sim_input_max: *max,
        })
        .collect()
}

async fn mapping_state_event(
    receiver: &mut mpsc::Receiver<MappingEvent>,
) -> lever_calib::MappingPublicState {
    match yield_until(|| receiver.try_recv().ok()).await {
        MappingEvent::SessionStarted(state) => state,
        MappingEvent::StepChanged(state) => state,
        MappingEvent::SampleUpdated(state) => state,
        MappingEvent::CaptureStarted(state) => state,
        MappingEvent::CaptureStopped(state) => state,
        other => panic!("expected state event, got {other:?}"),
    }
}

/// Waits for the SampleUpdated broadcast carrying the final sample of a
/// batch, discarding the earlier ones still queued.
async fn drain_samples(
    receiver: &mut mpsc::Receiver<MappingEvent>,
    expected: usize,
) -> lever_calib::MappingPublicState {
    yield_until(|| match receiver.try_recv() {
        Ok(MappingEvent::SampleUpdated(state)) if state.sample_count == expected => Some(state),
        _ => None,
    })
    .await
}

async fn capture_notch(
    monitor: &lever_calib::NotchMappingMonitor,
    events: &mut mpsc::Receiver<MappingEvent>,
    samples: &[i32],
) -> lever_calib::MappingPublicState {
    monitor.start_capturing().await.unwrap();
    let _ = mapping_state_event(events).await; // CaptureStarted
    for value in samples {
        monitor.input_sample(5, *value).await;
    }
    drain_samples(events, samples.len()).await;
    monitor.capture_range().await.unwrap();
    mapping_state_event(events).await // StepChanged
}

/// Mirrors the capture walkthrough (notch_mapping_session_test.exs:229-256,
/// 258-290, 499-546): samples calibrate against the input calibration,
/// min/max tracking, single-point captures for gates, navigation guards,
/// re-editing a captured notch and the normalized 0.0-1.0 save.
#[tokio::test]
async fn notch_mapping_walks_captures_preview_and_saves() {
    let store = Arc::new(FakeStore::default());
    let arbiter = arbiter();
    // The Elixir fixture creates notches without sim_input ranges, so
    // inversion detection has no valid pair and stays off.
    let config = mapping_config(wizard_notches(&[(None, None), (None, None), (None, None)]));
    let (monitor, mut events) =
        lever_calib::start_notch_mapping(&arbiter, lease(), config, store.clone()).unwrap();
    assert!(arbiter.is_suspended(), "wizard holds its lease");

    let started = mapping_state_event(&mut events).await;
    assert_eq!(started.current_step, MappingStep::Ready);
    assert_eq!(started.notch_count, 3);
    assert_eq!(started.total_travel, 800);
    assert!(started.captured_ranges.iter().all(|range| range.is_none()));

    monitor.start_mapping().await.unwrap();
    let state = mapping_state_event(&mut events).await;
    assert_eq!(state.current_step, MappingStep::Notch(0));

    // "cannot capture range without any samples".
    assert_eq!(
        monitor.capture_range().await.unwrap_err(),
        lever_calib::MappingError::NoSamples
    );

    // Raw 200..300 calibrate to 100..200 (min_value 100), ten samples make
    // the capture stable ("tracks sample count", @min_sample_count 10).
    monitor.start_capturing().await.unwrap();
    let _ = mapping_state_event(&mut events).await; // CaptureStarted
    for value in [200, 220, 250, 280, 300, 250, 220, 280, 240, 260] {
        monitor.input_sample(5, value).await;
    }
    let samples = drain_samples(&mut events, 10).await;
    assert!(samples.is_stable);
    assert!(samples.can_capture);
    assert_eq!(samples.current_min, Some(100));
    assert_eq!(samples.current_max, Some(200));
    assert_eq!(samples.current_value, Some(160));
    monitor.capture_range().await.unwrap();
    let state = mapping_state_event(&mut events).await;
    assert_eq!(state.current_step, MappingStep::Notch(1));
    assert_eq!(
        state.captured_ranges[0],
        Some(lever_calib::SampleRange { min: 100, max: 200 })
    );
    // Checkpoint committed on capture.
    assert_eq!(
        store.checkpoints.lock().unwrap().get(&42),
        Some(&lever_calib::MappingCheckpoint {
            lever_config_id: 42,
            captured_ranges: vec![
                Some(lever_calib::SampleRange { min: 100, max: 200 }),
                None,
                None,
            ],
            next_notch_index: 1,
        })
    );

    // Preview is guarded until every notch has a range.
    assert_eq!(
        monitor.go_to_preview().await.unwrap_err(),
        lever_calib::MappingError::IncompleteRanges
    );

    // Single-point capture for gate notches (min == max).
    let state = capture_notch(&monitor, &mut events, &[500, 500, 500]).await;
    assert_eq!(
        state.captured_ranges[1],
        Some(lever_calib::SampleRange { min: 400, max: 400 })
    );

    // Back to edit an earlier notch ("can go back to edit previous notch");
    // committed ranges survive the navigation.
    monitor.go_to_notch(0).await.unwrap();
    let state = mapping_state_event(&mut events).await;
    assert_eq!(state.current_step, MappingStep::Notch(0));
    assert!(
        state.captured_ranges[0].is_some(),
        "committed ranges survive"
    );

    // Re-capture notch 0, then walk forward through the remaining notches:
    // the wizard always advances one notch per capture, ending at preview.
    let state = capture_notch(&monitor, &mut events, &[200, 300, 400, 500]).await;
    assert_eq!(state.current_step, MappingStep::Notch(1));
    let state = capture_notch(&monitor, &mut events, &[400, 500, 550, 600]).await;
    assert_eq!(state.current_step, MappingStep::Notch(2));
    let state = capture_notch(&monitor, &mut events, &[700, 750, 800, 850]).await;
    assert_eq!(state.current_step, MappingStep::Preview);
    assert!(state.captured_ranges.iter().all(|range| range.is_some()));

    let completed = monitor.save_mapping().await.unwrap();
    assert!(!completed.inverted);
    // Calibrated 100-400 / 300-500 / 600-750 out of 800 total travel.
    let expected = [
        (100_i64, 0.125_f64, 0.5_f64),
        (101, 0.375, 0.625),
        (102, 0.75, 0.9375),
    ];
    assert_eq!(completed.updates.len(), expected.len());
    for (update, (notch_id, min, max)) in completed.updates.iter().zip(expected) {
        assert_eq!(update.notch_id, notch_id);
        assert!((update.input_min - min).abs() < 1e-12);
        assert!((update.input_max - max).abs() < 1e-12);
    }
    {
        let saves = store.range_saves.lock().unwrap();
        assert_eq!(saves.len(), 1);
        assert_eq!(saves[0].0, 42);
        assert!(!saves[0].2);
    }

    // The save publishes step_changed (saving, complete) and then the
    // mapping_result broadcast; drain the intermediate step events.
    let published = yield_until(|| match events.try_recv() {
        Ok(MappingEvent::MappingResult(result)) => Some(result),
        _ => None,
    })
    .await;
    assert_eq!(published, Ok(completed));

    monitor.cancel().await.unwrap();
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
}

/// Mirrors the invalid-step/notch-index guards
/// (notch_mapping_session_test.exs:158-169, 324-340, 406-416, 447-466).
#[tokio::test]
async fn notch_mapping_rejects_invalid_transitions_and_foreign_pins() {
    let store = Arc::new(FakeStore::default());
    let arbiter = arbiter();
    let config = mapping_config(wizard_notches(&[(None, None), (None, None)]));
    let (monitor, mut events) =
        lever_calib::start_notch_mapping(&arbiter, lease(), config, store.clone()).unwrap();
    let _ = mapping_state_event(&mut events).await; // SessionStarted

    // Everything is guarded while :ready.
    assert_eq!(
        monitor.capture_range().await.unwrap_err(),
        lever_calib::MappingError::InvalidStep
    );
    assert_eq!(
        monitor.reset_samples().await.unwrap_err(),
        lever_calib::MappingError::InvalidStep
    );
    assert_eq!(
        monitor.start_capturing().await.unwrap_err(),
        lever_calib::MappingError::InvalidStep
    );
    assert_eq!(
        monitor.save_mapping().await.unwrap_err(),
        lever_calib::MappingError::InvalidStep
    );

    monitor.start_mapping().await.unwrap();
    let _ = mapping_state_event(&mut events).await;
    assert_eq!(
        monitor.start_mapping().await.unwrap_err(),
        lever_calib::MappingError::InvalidStep
    );
    assert_eq!(
        monitor.go_to_notch(2).await.unwrap_err(),
        lever_calib::MappingError::InvalidNotchIndex
    );

    // Samples from other pins are ignored entirely.
    monitor.start_capturing().await.unwrap();
    let _ = mapping_state_event(&mut events).await; // CaptureStarted
    monitor.input_sample(6, 500).await;
    assert_quiet(|| assert!(events.try_recv().is_err())).await;
    assert_eq!(
        monitor.capture_range().await.unwrap_err(),
        lever_calib::MappingError::NoSamples
    );

    monitor.cancel().await.unwrap();
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
}

/// Mirrors `detect_inversion/3` and `calibrated_to_normalized/4`
/// (notch_mapping_session.ex:544-614): when the notch at the lowest hardware
/// position has the highest sim input the ranges are saved swapped.
#[tokio::test]
async fn notch_mapping_auto_detects_inversion() {
    let store = Arc::new(FakeStore::default());
    let arbiter = arbiter();
    // Notch 0 sits high in sim range, notch 1 low: inverted layout (M9-A).
    let config = mapping_config(wizard_notches(&[
        (Some(0.8), Some(1.0)),
        (Some(0.0), Some(0.2)),
    ]));
    let (monitor, mut events) =
        lever_calib::start_notch_mapping(&arbiter, lease(), config, store.clone()).unwrap();
    let _ = mapping_state_event(&mut events).await;

    monitor.start_mapping().await.unwrap();
    let _ = mapping_state_event(&mut events).await;

    // Notch 0 captured at hardware 100..200, notch 1 at 600..750.
    let _ = capture_notch(&monitor, &mut events, &[200, 250, 300]).await;
    let _ = capture_notch(&monitor, &mut events, &[700, 750, 800, 850]).await;

    let completed = monitor.save_mapping().await.unwrap();
    assert!(completed.inverted);
    // 0.125/0.25 and 0.75/0.9375 normalized, then swapped by inversion.
    let expected = [
        (100_i64, 1.0 - 0.25, 1.0 - 0.125),
        (101, 1.0 - 0.9375, 1.0 - 0.75),
    ];
    for (update, (notch_id, min, max)) in completed.updates.iter().zip(expected) {
        assert_eq!(update.notch_id, notch_id);
        assert!((update.input_min - min).abs() < 1e-12);
        assert!((update.input_max - max).abs() < 1e-12);
    }
    assert!(store.range_saves.lock().unwrap()[0].2);

    monitor.cancel().await.unwrap();
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
}

/// Checkpoint resume (the controls plan's checkpoint-based wizard
/// persistence): a cancelled wizard restarts where its committed captures
/// left off, and committed checkpoints survive the cancellation.
#[tokio::test]
async fn notch_mapping_checkpoints_persist_and_resume_after_cancel() {
    let store = Arc::new(FakeStore::default());
    let arbiter = arbiter();
    let config = mapping_config(wizard_notches(&[(None, None), (None, None), (None, None)]));

    // First wizard run: capture one notch, then cancel.
    let (monitor, mut events) =
        lever_calib::start_notch_mapping(&arbiter, lease(), config.clone(), store.clone()).unwrap();
    let _ = mapping_state_event(&mut events).await;
    monitor.start_mapping().await.unwrap();
    let _ = mapping_state_event(&mut events).await;
    let _ = capture_notch(&monitor, &mut events, &[200, 250, 300]).await;
    monitor.cancel().await.unwrap();
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
    assert!(store.checkpoints.lock().unwrap().contains_key(&42));

    // Second run resumes the committed capture and finishes the wizard.
    let (monitor, mut events) =
        lever_calib::start_notch_mapping(&arbiter, lease(), config, store.clone()).unwrap();
    let started = mapping_state_event(&mut events).await;
    assert_eq!(
        started.captured_ranges[0],
        Some(lever_calib::SampleRange { min: 100, max: 200 })
    );

    monitor.start_mapping().await.unwrap();
    let state = mapping_state_event(&mut events).await;
    // Resumes at the first uncaptured notch instead of notch 0.
    assert_eq!(state.current_step, MappingStep::Notch(1));

    let _ = capture_notch(&monitor, &mut events, &[400, 500, 600]).await;
    let state = capture_notch(&monitor, &mut events, &[700, 800, 900]).await;
    assert_eq!(state.current_step, MappingStep::Preview);

    let completed = monitor.save_mapping().await.unwrap();
    assert_eq!(completed.updates.len(), 3);
    monitor.cancel().await.unwrap();
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
}

/// Mirrors "cancel stops the session" (notch_mapping_session_test.exs:641-654)
/// plus the drop path: the lease is released even without an explicit cancel.
#[tokio::test]
async fn notch_mapping_releases_lease_on_cancel_and_drop() {
    let store = Arc::new(FakeStore::default());
    let arbiter = arbiter();
    let config = mapping_config(wizard_notches(&[(None, None)]));

    let (monitor, mut events) =
        lever_calib::start_notch_mapping(&arbiter, lease(), config.clone(), store.clone()).unwrap();
    let _ = mapping_state_event(&mut events).await;
    monitor.cancel().await.unwrap();
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;

    let (monitor, events) =
        lever_calib::start_notch_mapping(&arbiter, lease(), config, store.clone()).unwrap();
    let _ = events;
    drop(monitor);
    yield_until(|| (!arbiter.is_suspended()).then_some(())).await;
}
