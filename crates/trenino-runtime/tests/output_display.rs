//! Integration tests for the train output/display controllers and the
//! sequence executor (`trenino_runtime::train`).
//!
//! Every test drives fakes and a `FakeClock` only, mirroring the ExUnit
//! suites:
//!
//! - `test/trenino/train/output_controller_test.exs` — predicate matrix,
//!   type-mismatch rules and binding state semantics
//!   (lib/trenino/train/output_controller.ex).
//! - `test/trenino/train/display_controller_test.exs` — failed-write caching,
//!   brightness-before-segments, replay after hotplug/reconnect, module
//!   removal, minimum clamping, timer replacement
//!   (lib/trenino/train/display_controller.ex).
//! - `test/trenino/train/display_formatter_test.exs` — token/precision rules
//!   (also covered by the core unit tests).
//! - `test/trenino/train/button_controller_test.exs` sequence execution
//!   (lib/trenino/train/button_controller.ex `execute_sequence_commands/3`).

use std::collections::{HashMap, HashSet};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use serde_json::{json, Value};
use tokio::sync::{mpsc, watch};

use trenino_core::train::buttons::SequenceCommand;
use trenino_core::train::identifier::TrainProfile;
use trenino_core::train::output::OutputOperator;

use trenino_runtime::simulator::services::clock::FakeClock;
use trenino_runtime::train::display_controller::{
    DisplayBindingConfig, DisplayBindingSource, DisplayController,
};
use trenino_runtime::train::output_controller::{
    HardwareDispatch, OutputBindingConfig, OutputBindingSource, OutputController, OutputLevel,
    SimulatorConnectionView, SimulatorSubscriptions,
};
use trenino_runtime::train::sequence::{
    SequenceEvent, SequenceExecutor, SequenceSendOutcome, SequenceSimulator,
};

// ---------------------------------------------------------------------------
// Fake-clock drivers (same pattern as tests/simulator_detection.rs)
// ---------------------------------------------------------------------------

const DRIVE_LIMIT: usize = 30_000;

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

/// Let any just-triggered work run out without advancing fake time.
async fn settle() {
    for _ in 0..16 {
        tokio::task::yield_now().await;
    }
    tokio::time::sleep(Duration::from_millis(10)).await;
}

// ---------------------------------------------------------------------------
// Fake simulator subscriptions + connection state
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, PartialEq)]
enum SimCall {
    Subscribe { endpoint: String, id: i64 },
    GetSubscription { id: i64 },
    Unsubscribe { id: i64 },
}

#[derive(Default)]
struct FakeSimulator {
    inner: Mutex<FakeSimInner>,
}

#[derive(Default)]
struct FakeSimInner {
    trace: Vec<SimCall>,
    readings: HashMap<i64, Result<Value, String>>,
    failed_endpoints: HashSet<String>,
}

impl FakeSimulator {
    fn trace(&self) -> Vec<SimCall> {
        self.inner.lock().unwrap().trace.clone()
    }

    fn set_reading(&self, id: i64, body: Value) {
        self.inner.lock().unwrap().readings.insert(id, Ok(body));
    }

    fn set_reading_error(&self, id: i64) {
        self.inner
            .lock()
            .unwrap()
            .readings
            .insert(id, Err("http 500".to_owned()));
    }

    fn fail_subscribe(&self, endpoint: &str) {
        self.inner
            .lock()
            .unwrap()
            .failed_endpoints
            .insert(endpoint.to_owned());
    }

    fn reading_of(&self, value: Value) -> Value {
        json!({"Entries": [{"NodeValid": true, "Values": {"Speed": value}}]})
    }
}

impl SimulatorSubscriptions for FakeSimulator {
    fn subscribe(&self, endpoint: &str, id: i64) -> Result<(), String> {
        let mut inner = self.inner.lock().unwrap();
        inner.trace.push(SimCall::Subscribe {
            endpoint: endpoint.to_owned(),
            id,
        });
        if inner.failed_endpoints.contains(endpoint) {
            return Err("refused".to_owned());
        }
        Ok(())
    }

    fn get_subscription(&self, id: i64) -> Result<Value, String> {
        let mut inner = self.inner.lock().unwrap();
        inner.trace.push(SimCall::GetSubscription { id });
        inner
            .readings
            .get(&id)
            .cloned()
            .unwrap_or_else(|| Err("unknown subscription".to_owned()))
    }

    fn unsubscribe(&self, id: i64) -> Result<(), String> {
        self.inner
            .lock()
            .unwrap()
            .trace
            .push(SimCall::Unsubscribe { id });
        Ok(())
    }
}

struct FakeConnection {
    simulator: Arc<FakeSimulator>,
    connected: AtomicBool,
}

impl SimulatorConnectionView for FakeConnection {
    fn connected_client(&self) -> Option<Arc<dyn SimulatorSubscriptions>> {
        if self.connected.load(Ordering::SeqCst) {
            Some(self.simulator.clone())
        } else {
            None
        }
    }
}

// ---------------------------------------------------------------------------
// Fake hardware dispatch
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, PartialEq)]
enum HardwareCall {
    SetOutput {
        port: String,
        pin: i32,
        level: OutputLevel,
    },
    SetBrightness {
        port: String,
        address: i32,
        brightness: i32,
    },
    Segments {
        port: String,
        address: i32,
        data: Vec<u8>,
    },
}

struct FakeHardware {
    connected_config_ids: Mutex<HashSet<i64>>,
    trace: Mutex<Vec<HardwareCall>>,
    fail_outputs: AtomicBool,
    fail_brightness: AtomicBool,
    fail_segments: AtomicBool,
}

impl FakeHardware {
    fn new(config_ids: &[i64]) -> Self {
        Self {
            connected_config_ids: Mutex::new(config_ids.iter().copied().collect()),
            trace: Mutex::new(Vec::new()),
            fail_outputs: AtomicBool::new(false),
            fail_brightness: AtomicBool::new(false),
            fail_segments: AtomicBool::new(false),
        }
    }

    fn trace(&self) -> Vec<HardwareCall> {
        self.trace.lock().unwrap().clone()
    }

    fn disconnect(&self, config_id: i64) {
        self.connected_config_ids.lock().unwrap().remove(&config_id);
    }

    fn reconnect(&self, config_id: i64) {
        self.connected_config_ids.lock().unwrap().insert(config_id);
    }
}

impl HardwareDispatch for FakeHardware {
    fn resolve_port(&self, device_config_id: i64) -> Option<String> {
        self.connected_config_ids
            .lock()
            .unwrap()
            .contains(&device_config_id)
            .then(|| format!("port-{device_config_id}"))
    }

    fn set_output(&self, port: &str, pin: i32, level: OutputLevel) -> Result<(), String> {
        self.trace.lock().unwrap().push(HardwareCall::SetOutput {
            port: port.to_owned(),
            pin,
            level,
        });
        if self.fail_outputs.load(Ordering::SeqCst) {
            return Err("write failed".to_owned());
        }
        Ok(())
    }

    fn set_module_brightness(
        &self,
        port: &str,
        i2c_address: i32,
        brightness: i32,
    ) -> Result<(), String> {
        self.trace
            .lock()
            .unwrap()
            .push(HardwareCall::SetBrightness {
                port: port.to_owned(),
                address: i2c_address,
                brightness,
            });
        if self.fail_brightness.load(Ordering::SeqCst) {
            return Err("write failed".to_owned());
        }
        Ok(())
    }

    fn write_segments(&self, port: &str, i2c_address: i32, data: Vec<u8>) -> Result<(), String> {
        self.trace.lock().unwrap().push(HardwareCall::Segments {
            port: port.to_owned(),
            address: i2c_address,
            data,
        });
        if self.fail_segments.load(Ordering::SeqCst) {
            return Err("write failed".to_owned());
        }
        Ok(())
    }
}

// ---------------------------------------------------------------------------
// Fake binding sources
// ---------------------------------------------------------------------------

#[derive(Default)]
struct FakeOutputSource {
    bindings: Mutex<Vec<(i64, OutputBindingConfig)>>,
}

impl FakeOutputSource {
    fn set(&self, train_id: i64, bindings: Vec<OutputBindingConfig>) {
        let mut stored = self.bindings.lock().unwrap();
        stored.retain(|(train, _)| *train != train_id);
        stored.extend(bindings.into_iter().map(|binding| (train_id, binding)));
    }
}

impl OutputBindingSource for FakeOutputSource {
    fn enabled_output_bindings(&self, train_id: i64) -> Vec<OutputBindingConfig> {
        self.bindings
            .lock()
            .unwrap()
            .iter()
            .filter(|(train, _)| *train == train_id)
            .map(|(_, binding)| binding.clone())
            .collect()
    }
}

#[derive(Default)]
struct FakeDisplaySource {
    bindings: Mutex<Vec<(i64, DisplayBindingConfig)>>,
}

impl FakeDisplaySource {
    fn set(&self, train_id: i64, bindings: Vec<DisplayBindingConfig>) {
        let mut stored = self.bindings.lock().unwrap();
        stored.retain(|(train, _)| *train != train_id);
        stored.extend(bindings.into_iter().map(|binding| (train_id, binding)));
    }
}

impl DisplayBindingSource for FakeDisplaySource {
    fn enabled_display_bindings(&self, train_id: i64) -> Vec<DisplayBindingConfig> {
        self.bindings
            .lock()
            .unwrap()
            .iter()
            .filter(|(train, _)| *train == train_id)
            .map(|(_, binding)| binding.clone())
            .collect()
    }
}

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

fn train(id: i64) -> TrainProfile {
    TrainProfile {
        id,
        name: format!("Train {id}"),
        identifiers: vec![format!("train_{id}")],
    }
}

fn output_binding(id: i64, endpoint: &str, operator: OutputOperator) -> OutputBindingConfig {
    OutputBindingConfig {
        id,
        endpoint: endpoint.to_owned(),
        operator,
        value_a: None,
        value_b: None,
        device_config_id: 123,
        pin: (12 + id) as i32,
    }
}

fn numeric_binding(
    id: i64,
    endpoint: &str,
    operator: OutputOperator,
    value_a: f64,
) -> OutputBindingConfig {
    let mut binding = output_binding(id, endpoint, operator);
    binding.value_a = Some(value_a);
    binding
}

fn display_binding(id: i64, endpoint: &str, format: &str) -> DisplayBindingConfig {
    DisplayBindingConfig {
        id,
        endpoint: endpoint.to_owned(),
        format_string: format.to_owned(),
        device_config_id: 123,
        i2c_address: 0x70,
        brightness: 7,
        num_digits: 4,
        seven_segment: false,
        has_dot: false,
        align_right: true,
        min_value: Some(0.0),
    }
}

struct OutputHarness {
    simulator: Arc<FakeSimulator>,
    connection: Arc<FakeConnection>,
    hardware: Arc<FakeHardware>,
    source: Arc<FakeOutputSource>,
    clock: FakeClock,
    controller: OutputController,
}

impl OutputHarness {
    fn start() -> Self {
        let simulator = Arc::new(FakeSimulator::default());
        let connection = Arc::new(FakeConnection {
            simulator: simulator.clone(),
            connected: AtomicBool::new(true),
        });
        let hardware = Arc::new(FakeHardware::new(&[123]));
        let source = Arc::new(FakeOutputSource::default());
        let clock = FakeClock::new();
        let controller = OutputController::start(
            source.clone(),
            connection.clone(),
            hardware.clone(),
            Arc::new(clock.clone()),
        );
        Self {
            simulator,
            connection,
            hardware,
            source,
            clock,
            controller,
        }
    }

    async fn activate(&self, train_id: i64) {
        self.controller.train_changed(Some(train(train_id))).await;
        yield_until(|| {
            let trace = self.simulator.trace();
            trace
                .iter()
                .any(|c| matches!(c, SimCall::Subscribe { .. }))
                .then_some(())
        })
        .await;
    }

    fn reads(&self) -> usize {
        self.simulator
            .trace()
            .iter()
            .filter(|c| matches!(c, SimCall::GetSubscription { .. }))
            .count()
    }

    /// Drive the clock until `expected` subscription reads have happened.
    async fn poll_until_reads(&self, expected: usize) {
        advance_until(&self.clock, Duration::from_millis(200), || {
            (self.reads() >= expected).then_some(())
        })
        .await;
    }
}

struct DisplayHarness {
    simulator: Arc<FakeSimulator>,
    connection: Arc<FakeConnection>,
    hardware: Arc<FakeHardware>,
    source: Arc<FakeDisplaySource>,
    clock: FakeClock,
    controller: DisplayController,
}

impl DisplayHarness {
    fn start() -> Self {
        let simulator = Arc::new(FakeSimulator::default());
        let connection = Arc::new(FakeConnection {
            simulator: simulator.clone(),
            connected: AtomicBool::new(true),
        });
        let hardware = Arc::new(FakeHardware::new(&[123]));
        let source = Arc::new(FakeDisplaySource::default());
        let clock = FakeClock::new();
        let controller = DisplayController::start(
            source.clone(),
            connection.clone(),
            hardware.clone(),
            Arc::new(clock.clone()),
        );
        Self {
            simulator,
            connection,
            hardware,
            source,
            clock,
            controller,
        }
    }

    async fn activate(&self, train_id: i64) {
        self.controller.train_changed(Some(train(train_id))).await;
        yield_until(|| {
            let trace = self.simulator.trace();
            trace
                .iter()
                .any(|c| matches!(c, SimCall::Subscribe { .. }))
                .then_some(())
        })
        .await;
    }

    /// Drive one poll: advance 200ms and wait for the get_subscription call.
    async fn poll(&self) {
        let before = self
            .simulator
            .trace()
            .iter()
            .filter(|c| matches!(c, SimCall::GetSubscription { .. }))
            .count();
        advance_until(&self.clock, Duration::from_millis(200), || {
            let count = self
                .simulator
                .trace()
                .iter()
                .filter(|c| matches!(c, SimCall::GetSubscription { .. }))
                .count();
            (count > before).then_some(())
        })
        .await;
    }
}

fn segments(port: &str, address: i32, data: Vec<u8>) -> HardwareCall {
    HardwareCall::Segments {
        port: port.to_owned(),
        address,
        data,
    }
}

fn brightness(port: &str, address: i32, level: i32) -> HardwareCall {
    HardwareCall::SetBrightness {
        port: port.to_owned(),
        address,
        brightness: level,
    }
}

// ===========================================================================
// Sequence executor (button_controller.ex execute_sequence_commands/3)
// ===========================================================================

struct RecordingSequenceSimulator {
    sends: Mutex<Vec<(String, f64)>>,
    outcome: Mutex<SequenceSendOutcome>,
}

impl SequenceSimulator for RecordingSequenceSimulator {
    fn set(&self, endpoint: &str, value: f64) -> SequenceSendOutcome {
        self.sends
            .lock()
            .unwrap()
            .push((endpoint.to_owned(), value));
        self.outcome.lock().unwrap().clone()
    }
}

fn sequence_harness() -> (Arc<RecordingSequenceSimulator>, FakeClock, SequenceExecutor) {
    let simulator = Arc::new(RecordingSequenceSimulator {
        sends: Mutex::new(Vec::new()),
        outcome: Mutex::new(SequenceSendOutcome::Sent),
    });
    let clock = FakeClock::new();
    let executor = SequenceExecutor::new(simulator.clone(), Arc::new(clock.clone()));
    (simulator, clock, executor)
}

struct PendingSequenceSimulator {
    entered: AtomicBool,
}
impl SequenceSimulator for PendingSequenceSimulator {
    fn set_async<'a>(
        &'a self,
        _endpoint: &'a str,
        _value: f64,
    ) -> std::pin::Pin<Box<dyn std::future::Future<Output = SequenceSendOutcome> + Send + 'a>> {
        self.entered.store(true, Ordering::SeqCst);
        Box::pin(std::future::pending())
    }
}

#[tokio::test]
async fn owner_death_interrupts_an_in_flight_sequence_write() {
    let simulator = Arc::new(PendingSequenceSimulator {
        entered: AtomicBool::new(false),
    });
    let executor = SequenceExecutor::new(simulator.clone(), Arc::new(FakeClock::new()));
    let (owner, observed) = watch::channel(());
    let (events, mut received) = mpsc::unbounded_channel();
    let run = executor.start(
        7,
        vec![SequenceCommand {
            endpoint: "Brake".into(),
            value: 1.0,
            delay_ms: 0,
            position: 0,
        }],
        observed,
        events,
    );
    yield_until(|| simulator.entered.load(Ordering::SeqCst).then_some(())).await;
    drop(owner);
    yield_until(|| run.is_finished().then_some(())).await;
    assert!(received.try_recv().is_err());
}

#[tokio::test]
async fn sequence_sends_commands_in_position_order_and_reports_completion() {
    let (simulator, clock, executor) = sequence_harness();
    let (owner_tx, owner_rx) = watch::channel(());
    let (events_tx, mut events_rx) = mpsc::unbounded_channel();

    // Scrambled positions mirror the unordered load then position ordering.
    let commands = vec![
        SequenceCommand {
            endpoint: "DoorOpen.InputValue".into(),
            value: 1.0,
            delay_ms: 0,
            position: 1,
        },
        SequenceCommand {
            endpoint: "DoorKey.InputValue".into(),
            value: 1.0,
            delay_ms: 100,
            position: 0,
        },
    ];
    let run = executor.start(7, commands, owner_rx, events_tx);

    // First command is sent immediately; the second waits for the delay.
    yield_until(|| {
        let sends = simulator.sends.lock().unwrap();
        (sends.len() == 1).then_some(())
    })
    .await;
    assert_eq!(
        *simulator.sends.lock().unwrap(),
        vec![("DoorKey.InputValue".to_owned(), 1.0)]
    );

    advance_until(&clock, Duration::from_millis(100), || {
        let sends = simulator.sends.lock().unwrap();
        (sends.len() == 2).then_some(())
    })
    .await;

    let complete = yield_until(|| events_rx.try_recv().ok()).await;
    assert_eq!(
        complete,
        SequenceEvent::Complete {
            element_id: 7,
            run: run.run
        }
    );
    drop(owner_tx);
}

#[tokio::test]
async fn sequence_failure_continues_and_never_replays() {
    let (simulator, clock, executor) = sequence_harness();
    *simulator.outcome.lock().unwrap() = SequenceSendOutcome::Failed("500".into());
    let (_owner_tx, owner_rx) = watch::channel(());
    let (events_tx, mut events_rx) = mpsc::unbounded_channel();

    let commands = vec![
        SequenceCommand {
            endpoint: "First.InputValue".into(),
            value: 1.0,
            delay_ms: 50,
            position: 0,
        },
        SequenceCommand {
            endpoint: "Second.InputValue".into(),
            value: 2.0,
            delay_ms: 0,
            position: 1,
        },
    ];
    let _run = executor.start(3, commands, owner_rx, events_tx);

    let complete = advance_until(&clock, Duration::from_millis(50), || {
        events_rx.try_recv().ok()
    })
    .await;
    assert!(matches!(complete, SequenceEvent::Complete { .. }));
    // Each command was attempted exactly once: no auto-replay after failure.
    assert_eq!(
        *simulator.sends.lock().unwrap(),
        vec![
            ("First.InputValue".to_owned(), 1.0),
            ("Second.InputValue".to_owned(), 2.0)
        ]
    );
}

#[tokio::test]
async fn sequence_continues_when_simulator_is_disconnected() {
    let (simulator, clock, executor) = sequence_harness();
    *simulator.outcome.lock().unwrap() = SequenceSendOutcome::Disconnected;
    let (_owner_tx, owner_rx) = watch::channel(());
    let (events_tx, mut events_rx) = mpsc::unbounded_channel();

    let commands = vec![
        SequenceCommand {
            endpoint: "A.InputValue".into(),
            value: 1.0,
            delay_ms: 10,
            position: 0,
        },
        SequenceCommand {
            endpoint: "B.InputValue".into(),
            value: 1.0,
            delay_ms: 0,
            position: 1,
        },
    ];
    let _run = executor.start(9, commands, owner_rx, events_tx);
    let complete = advance_until(&clock, Duration::from_millis(10), || {
        events_rx.try_recv().ok()
    })
    .await;
    assert!(matches!(complete, SequenceEvent::Complete { .. }));
    assert_eq!(simulator.sends.lock().unwrap().len(), 2);
}

#[tokio::test]
async fn cancelled_sequence_never_sends_later_commands_or_completes() {
    // "sequence with long delays is properly cancelled"
    let (simulator, clock, executor) = sequence_harness();
    let (_owner_tx, owner_rx) = watch::channel(());
    let (events_tx, mut events_rx) = mpsc::unbounded_channel();

    let commands = vec![
        SequenceCommand {
            endpoint: "First.InputValue".into(),
            value: 1.0,
            delay_ms: 5000,
            position: 0,
        },
        SequenceCommand {
            endpoint: "Second.InputValue".into(),
            value: 1.0,
            delay_ms: 0,
            position: 1,
        },
    ];
    let run = executor.start(11, commands, owner_rx, events_tx);

    yield_until(|| {
        let sends = simulator.sends.lock().unwrap();
        (sends.len() == 1).then_some(())
    })
    .await;

    // Release the button mid-delay: the run dies immediately.
    run.abort();
    clock.advance(Duration::from_millis(10_000));
    settle().await;

    assert_eq!(
        *simulator.sends.lock().unwrap(),
        vec![("First.InputValue".to_owned(), 1.0)]
    );
    assert!(events_rx.try_recv().is_err());
}

#[tokio::test]
async fn owner_death_cancels_a_running_sequence() {
    // execute_sequence_loop/4 monitors the controller and exits on :DOWN.
    let (simulator, clock, executor) = sequence_harness();
    let (owner_tx, owner_rx) = watch::channel(());
    let (events_tx, mut events_rx) = mpsc::unbounded_channel();

    let commands = vec![
        SequenceCommand {
            endpoint: "A.InputValue".into(),
            value: 1.0,
            delay_ms: 250,
            position: 0,
        },
        SequenceCommand {
            endpoint: "B.InputValue".into(),
            value: 1.0,
            delay_ms: 0,
            position: 1,
        },
    ];
    let _run = executor.start(5, commands, owner_rx, events_tx);

    yield_until(|| {
        let sends = simulator.sends.lock().unwrap();
        (sends.len() == 1).then_some(())
    })
    .await;

    // Controller dies (train switch teardown) while the delay is pending.
    drop(owner_tx);
    clock.advance(Duration::from_millis(1000));
    settle().await;

    assert_eq!(simulator.sends.lock().unwrap().len(), 1);
    assert!(events_rx.try_recv().is_err());
}

#[tokio::test]
async fn replacement_runs_are_distinguishable_and_stale_runs_never_complete() {
    // "ignores stale sequence_complete messages": a cancelled run's completion
    // must never arrive and a replacement run reports a fresh run id.
    let (simulator, clock, executor) = sequence_harness();
    let (owner_tx, _owner_rx) = watch::channel(());
    let (events_tx, mut events_rx) = mpsc::unbounded_channel();

    let commands = || {
        vec![
            SequenceCommand {
                endpoint: "First.InputValue".into(),
                value: 1.0,
                delay_ms: 1000,
                position: 0,
            },
            SequenceCommand {
                endpoint: "Second.InputValue".into(),
                value: 1.0,
                delay_ms: 0,
                position: 1,
            },
        ]
    };

    let stale = executor.start(7, commands(), owner_tx.subscribe(), events_tx.clone());
    yield_until(|| {
        let sends = simulator.sends.lock().unwrap();
        (sends.len() == 1).then_some(())
    })
    .await;
    stale.abort();

    let fresh = executor.start(7, commands(), owner_tx.subscribe(), events_tx);
    assert!(fresh.run > stale.run);

    let complete = advance_until(&clock, Duration::from_millis(1000), || {
        events_rx.try_recv().ok()
    })
    .await;
    assert_eq!(
        complete,
        SequenceEvent::Complete {
            element_id: 7,
            run: fresh.run
        }
    );
    assert!(events_rx.try_recv().is_err());
    // One aborted attempt + one full run: 1 + 2 sends.
    assert_eq!(simulator.sends.lock().unwrap().len(), 3);
}

#[tokio::test]
async fn empty_sequence_completes_without_sending() {
    let (simulator, _clock, executor) = sequence_harness();
    let (_owner_tx, owner_rx) = watch::channel(());
    let (events_tx, mut events_rx) = mpsc::unbounded_channel();

    let run = executor.start(1, Vec::new(), owner_rx, events_tx);
    let complete = yield_until(|| events_rx.try_recv().ok()).await;
    assert_eq!(
        complete,
        SequenceEvent::Complete {
            element_id: 1,
            run: run.run
        }
    );
    assert!(simulator.sends.lock().unwrap().is_empty());
}

// ===========================================================================
// OutputController (output_controller.ex)
// ===========================================================================

#[tokio::test]
async fn outputs_subscribe_once_per_unique_endpoint_in_lexicographic_id_order() {
    let harness = OutputHarness::start();
    harness.source.set(
        1,
        vec![
            numeric_binding(1, "Speed", OutputOperator::Gt, 50.0),
            numeric_binding(2, "Speed", OutputOperator::Lte, 40.0),
            numeric_binding(3, "Brake", OutputOperator::EqTrue, 0.0),
        ],
    );
    harness.activate(1).await;

    // Elixir assigns 1000+index over Enum.group_by endpoints; small maps
    // iterate in key (lexicographic) order, so Brake precedes Speed.
    assert_eq!(
        harness.simulator.trace(),
        vec![
            SimCall::Subscribe {
                endpoint: "Brake".into(),
                id: 1000
            },
            SimCall::Subscribe {
                endpoint: "Speed".into(),
                id: 1001
            }
        ]
    );
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn outputs_write_only_on_state_change_and_share_one_reading_per_endpoint() {
    let harness = OutputHarness::start();
    harness.source.set(
        1,
        vec![
            numeric_binding(1, "Speed", OutputOperator::Gt, 50.0),
            numeric_binding(2, "Speed", OutputOperator::Lte, 40.0),
        ],
    );
    harness.activate(1).await;

    // 30.0: gt-50 stays LOW (initial false), lte-40 turns HIGH.
    harness
        .simulator
        .set_reading(1000, harness.simulator.reading_of(json!(30.0)));
    advance_until(&harness.clock, Duration::from_millis(200), || {
        harness
            .hardware
            .trace()
            .iter()
            .any(|c| {
                matches!(
                    c,
                    HardwareCall::SetOutput {
                        pin: 14,
                        level: OutputLevel::High,
                        ..
                    }
                )
            })
            .then_some(())
    })
    .await;
    assert_eq!(
        harness.hardware.trace(),
        vec![HardwareCall::SetOutput {
            port: "port-123".into(),
            pin: 14,
            level: OutputLevel::High
        }]
    );

    // Same value on the next poll: nothing more is written (dedup).
    let before = harness.hardware.trace().len();
    advance_until(&harness.clock, Duration::from_millis(200), || {
        harness
            .simulator
            .trace()
            .iter()
            .filter(|c| matches!(c, SimCall::GetSubscription { id: 1000 }))
            .nth(1)
            .map(|_| ())
    })
    .await;
    assert_eq!(harness.hardware.trace().len(), before);

    // 60.0 flips both: binding ids ascend within the subscription.
    harness
        .simulator
        .set_reading(1000, harness.simulator.reading_of(json!(60.0)));
    advance_until(&harness.clock, Duration::from_millis(200), || {
        (harness.hardware.trace().len() >= 3).then_some(())
    })
    .await;
    assert_eq!(
        harness.hardware.trace()[1..],
        vec![
            HardwareCall::SetOutput {
                port: "port-123".into(),
                pin: 13,
                level: OutputLevel::High
            },
            HardwareCall::SetOutput {
                port: "port-123".into(),
                pin: 14,
                level: OutputLevel::Low
            }
        ]
    );
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn output_readings_are_rounded_to_two_decimals_before_evaluation() {
    let harness = OutputHarness::start();
    harness.source.set(
        1,
        vec![numeric_binding(1, "Speed", OutputOperator::Gt, 50.0)],
    );
    harness.activate(1).await;

    harness
        .simulator
        .set_reading(1000, harness.simulator.reading_of(json!(50.004)));
    advance_until(&harness.clock, Duration::from_millis(200), || {
        harness
            .simulator
            .trace()
            .iter()
            .find(|c| matches!(c, SimCall::GetSubscription { .. }))
            .map(|_| ())
    })
    .await;
    // 50.004 rounds to 50.0, which does not exceed the threshold.
    assert!(harness.hardware.trace().is_empty());

    harness
        .simulator
        .set_reading(1000, harness.simulator.reading_of(json!(50.006)));
    advance_until(&harness.clock, Duration::from_millis(200), || {
        (!harness.hardware.trace().is_empty()).then_some(())
    })
    .await;
    // 50.006 rounds to 50.01, which does.
    assert_eq!(
        harness.hardware.trace(),
        vec![HardwareCall::SetOutput {
            port: "port-123".into(),
            pin: 13,
            level: OutputLevel::High
        }]
    );
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn invalid_or_failed_readings_leave_output_state_untouched() {
    let harness = OutputHarness::start();
    harness.source.set(
        1,
        vec![numeric_binding(1, "Speed", OutputOperator::Gt, 50.0)],
    );
    harness.activate(1).await;

    // Drive HIGH first.
    harness
        .simulator
        .set_reading(1000, harness.simulator.reading_of(json!(60.0)));
    advance_until(&harness.clock, Duration::from_millis(200), || {
        (!harness.hardware.trace().is_empty()).then_some(())
    })
    .await;
    assert_eq!(harness.hardware.trace().len(), 1);

    // NodeValid:false — no reevaluation (two polls' worth).
    harness.simulator.set_reading(
        1000,
        json!({"Entries": [{"NodeValid": false, "Values": {"Speed": 10.0}}]}),
    );
    harness.poll_until_reads(3).await;
    assert_eq!(harness.hardware.trace().len(), 1);

    // Empty Values map — untouched.
    harness.simulator.set_reading(
        1000,
        json!({"Entries": [{"NodeValid": true, "Values": {}}]}),
    );
    harness.poll_until_reads(4).await;
    assert_eq!(harness.hardware.trace().len(), 1);

    // Fetch error — untouched.
    harness.simulator.set_reading_error(1000);
    harness.poll_until_reads(5).await;
    assert_eq!(harness.hardware.trace().len(), 1);

    // A null value IS a reading: the predicate is false and the output drops.
    harness
        .simulator
        .set_reading(1000, harness.simulator.reading_of(Value::Null));
    advance_until(&harness.clock, Duration::from_millis(200), || {
        (harness.hardware.trace().len() > 1).then_some(())
    })
    .await;
    assert_eq!(
        harness.hardware.trace()[1],
        HardwareCall::SetOutput {
            port: "port-123".into(),
            pin: 13,
            level: OutputLevel::Low
        }
    );
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn output_boolean_bindings_only_respond_to_boolean_readings() {
    let harness = OutputHarness::start();
    harness
        .source
        .set(1, vec![output_binding(1, "Door", OutputOperator::EqTrue)]);
    harness.activate(1).await;

    // A numeric reading against eq_true evaluates false: the initial LOW
    // state is not even confirmed by a write.
    harness
        .simulator
        .set_reading(1000, harness.simulator.reading_of(json!(1)));
    advance_until(&harness.clock, Duration::from_millis(200), || {
        harness
            .simulator
            .trace()
            .iter()
            .find(|c| matches!(c, SimCall::GetSubscription { .. }))
            .map(|_| ())
    })
    .await;
    assert!(harness.hardware.trace().is_empty());

    harness
        .simulator
        .set_reading(1000, harness.simulator.reading_of(json!(true)));
    advance_until(&harness.clock, Duration::from_millis(200), || {
        (!harness.hardware.trace().is_empty()).then_some(())
    })
    .await;
    assert_eq!(
        harness.hardware.trace(),
        vec![HardwareCall::SetOutput {
            port: "port-123".into(),
            pin: 13,
            level: OutputLevel::High
        }]
    );
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn failed_subscribe_consumes_its_id_and_tracks_no_binding() {
    let harness = OutputHarness::start();
    harness.simulator.fail_subscribe("Brake");
    harness.source.set(
        1,
        vec![
            numeric_binding(1, "Speed", OutputOperator::Gt, 50.0),
            numeric_binding(2, "Brake", OutputOperator::Gt, 5.0),
        ],
    );
    harness.activate(1).await;

    assert_eq!(
        harness.simulator.trace(),
        vec![
            SimCall::Subscribe {
                endpoint: "Brake".into(),
                id: 1000
            },
            SimCall::Subscribe {
                endpoint: "Speed".into(),
                id: 1001
            }
        ]
    );

    // The failed endpoint's binding never evaluates (no LOW on cleanup) and
    // cleanup only unsubscribes the live subscription.
    harness.controller.train_changed(None).await;
    yield_until(|| {
        harness
            .simulator
            .trace()
            .iter()
            .find(|c| matches!(c, SimCall::Unsubscribe { id: 1001 }))
            .map(|_| ())
    })
    .await;
    assert!(!harness
        .simulator
        .trace()
        .iter()
        .any(|c| matches!(c, SimCall::Unsubscribe { id: 1000 })));
}

#[tokio::test]
async fn train_switch_drives_outputs_low_even_when_simulator_disconnected() {
    let harness = OutputHarness::start();
    harness.source.set(
        1,
        vec![
            numeric_binding(1, "Speed", OutputOperator::Gt, 50.0),
            numeric_binding(2, "Brake", OutputOperator::EqTrue, 0.0),
        ],
    );
    harness.source.set(2, vec![]);
    harness.activate(1).await;

    // Sorted endpoints: Brake=1000, Speed=1001; the speed reading lives on 1001.
    harness.simulator.set_reading(
        1001,
        json!({"Entries": [{"NodeValid": true, "Values": {"Speed": 60.0}}]}),
    );
    advance_until(&harness.clock, Duration::from_millis(200), || {
        (!harness.hardware.trace().is_empty()).then_some(())
    })
    .await;
    assert_eq!(harness.hardware.trace().len(), 1);

    // Simulator drops, then the train is deactivated: unsubscribe is skipped
    // but every tracked output still goes LOW (cleanup order: unsubscribe,
    // then LOW writes in binding-id order).
    harness.connection.connected.store(false, Ordering::SeqCst);
    harness.controller.train_changed(None).await;
    yield_until(|| (harness.hardware.trace().len() == 3).then_some(())).await;

    assert_eq!(
        harness.hardware.trace()[1..],
        vec![
            HardwareCall::SetOutput {
                port: "port-123".into(),
                pin: 13,
                level: OutputLevel::Low
            },
            HardwareCall::SetOutput {
                port: "port-123".into(),
                pin: 14,
                level: OutputLevel::Low
            }
        ]
    );
    assert!(!harness
        .simulator
        .trace()
        .iter()
        .any(|c| matches!(c, SimCall::Unsubscribe { .. })));

    // A stale poll must not happen: the timer is gone, advancing stays quiet.
    let reads = harness.simulator.trace().len();
    harness.clock.advance(Duration::from_millis(10_000));
    settle().await;
    assert_eq!(harness.simulator.trace().len(), reads);
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn reload_replaces_bindings_and_the_output_controller_ignores_reconnects() {
    let harness = OutputHarness::start();
    harness.source.set(
        1,
        vec![numeric_binding(1, "Speed", OutputOperator::Gt, 50.0)],
    );
    harness.controller.train_changed(None).await;
    settle().await;

    // reload without an active train is a no-op.
    harness.controller.reload_bindings().await;
    settle().await;
    assert!(harness.simulator.trace().is_empty());

    // Load while disconnected: nothing is subscribed.
    harness.connection.connected.store(false, Ordering::SeqCst);
    harness.controller.train_changed(Some(train(1))).await;
    settle().await;
    assert!(harness.simulator.trace().is_empty());

    // Unlike DisplayController, reconnecting the simulator does NOT reload:
    // the output controller has no simulator-status handler.
    harness.connection.connected.store(true, Ordering::SeqCst);
    harness.clock.advance(Duration::from_millis(5000));
    settle().await;
    assert!(harness.simulator.trace().is_empty());
    assert!(harness.hardware.trace().is_empty());

    // An explicit reload picks the bindings up and replaces the subscription.
    harness.controller.reload_bindings().await;
    yield_until(|| {
        harness
            .simulator
            .trace()
            .iter()
            .find(|c| matches!(c, SimCall::Subscribe { id: 1000, .. }))
            .map(|_| ())
    })
    .await;
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn reload_while_active_rebuilds_subscriptions_and_resets_state() {
    let harness = OutputHarness::start();
    harness.source.set(
        1,
        vec![numeric_binding(1, "Speed", OutputOperator::Gt, 50.0)],
    );
    harness.activate(1).await;

    harness
        .simulator
        .set_reading(1000, harness.simulator.reading_of(json!(60.0)));
    advance_until(&harness.clock, Duration::from_millis(200), || {
        (!harness.hardware.trace().is_empty()).then_some(())
    })
    .await;
    assert_eq!(harness.hardware.trace().len(), 1);

    // Reload: unsubscribe + LOW, then re-subscribe. The new binding starts
    // with current_state false, so the unchanged HIGH value writes again.
    harness.controller.reload_bindings().await;
    yield_until(|| {
        harness
            .simulator
            .trace()
            .iter()
            .filter(|c| matches!(c, SimCall::Subscribe { .. }))
            .nth(1)
            .map(|_| ())
    })
    .await;
    assert!(harness
        .simulator
        .trace()
        .iter()
        .any(|c| matches!(c, SimCall::Unsubscribe { id: 1000 })));
    assert_eq!(
        harness.hardware.trace()[1],
        HardwareCall::SetOutput {
            port: "port-123".into(),
            pin: 13,
            level: OutputLevel::Low
        }
    );

    advance_until(&harness.clock, Duration::from_millis(200), || {
        (harness.hardware.trace().len() >= 3).then_some(())
    })
    .await;
    assert_eq!(
        harness.hardware.trace()[2],
        HardwareCall::SetOutput {
            port: "port-123".into(),
            pin: 13,
            level: OutputLevel::High
        }
    );
    harness.controller.shutdown().await;
}

// ===========================================================================
// DisplayController (display_controller.ex)
// ===========================================================================

#[tokio::test]
async fn display_bindings_sharing_an_endpoint_update_from_one_reading() {
    let harness = DisplayHarness::start();
    let mut second = display_binding(2, "Speed", "{value:.0f}");
    second.i2c_address = 0x72;
    harness
        .source
        .set(1, vec![display_binding(1, "Speed", "{value:.1f}"), second]);
    harness.activate(1).await;
    // A single subscription serves both bindings.
    assert_eq!(
        harness.simulator.trace(),
        vec![SimCall::Subscribe {
            endpoint: "Speed".into(),
            id: 3000
        }]
    );

    harness
        .simulator
        .set_reading(3000, harness.simulator.reading_of(json!(42.56)));
    harness.poll().await;
    // Rounded to 42.56 → "42.6" and "43", both initialized with brightness
    // (binding-id order).
    let trace = harness.hardware.trace();
    assert_eq!(trace.len(), 4);
    assert_eq!(trace[0], brightness("port-123", 0x70, 7));
    assert_eq!(
        trace[1],
        segments(
            "port-123",
            0x70,
            trenino_core::hardware::ht16k33::encode_string("42.6", 4, false, false, true)
        )
    );
    assert_eq!(trace[2], brightness("port-123", 0x72, 7));
    assert_eq!(
        trace[3],
        segments(
            "port-123",
            0x72,
            trenino_core::hardware::ht16k33::encode_string("43", 4, false, false, true)
        )
    );
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn display_initializes_brightness_before_segments_and_dedups_repeats() {
    let harness = DisplayHarness::start();
    harness
        .source
        .set(1, vec![display_binding(1, "Speed", "{value:.1f}")]);
    harness.activate(1).await;

    harness
        .simulator
        .set_reading(3000, harness.simulator.reading_of(json!(42.5)));
    advance_until(&harness.clock, Duration::from_millis(200), || {
        (harness.hardware.trace().len() == 2).then_some(())
    })
    .await;

    // SetModuleBrightness precedes WriteSegments (14-segment, 4 digits,
    // right-aligned: "42.5" fills the display, encoded by the core encoder).
    let expected = trenino_core::hardware::ht16k33::encode_string("42.5", 4, false, false, true);
    assert_eq!(
        harness.hardware.trace(),
        vec![
            brightness("port-123", 0x70, 7),
            segments("port-123", 0x70, expected),
        ]
    );

    // Same text on the next poll: nothing more is sent.
    let before = harness.hardware.trace().len();
    harness.poll().await;
    assert_eq!(harness.hardware.trace().len(), before);
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn display_failed_writes_are_not_cached_and_retry_the_unchanged_value() {
    // "does not cache a failed write and retries the unchanged value"
    let harness = DisplayHarness::start();
    harness
        .source
        .set(1, vec![display_binding(1, "Speed", "{value:.1f}")]);
    harness.activate(1).await;
    harness
        .simulator
        .set_reading(3000, harness.simulator.reading_of(json!(42.5)));

    harness.hardware.fail_segments.store(true, Ordering::SeqCst);
    harness.poll().await;
    assert_eq!(harness.hardware.trace().len(), 2);

    harness
        .hardware
        .fail_segments
        .store(false, Ordering::SeqCst);
    harness.poll().await;
    // Retried with brightness again (last_text was never cached).
    let successes = harness
        .hardware
        .trace()
        .iter()
        .filter(|c| matches!(c, HardwareCall::Segments { .. }))
        .count();
    assert_eq!(successes, 2);

    harness.poll().await;
    let successes_after = harness
        .hardware
        .trace()
        .iter()
        .filter(|c| matches!(c, HardwareCall::Segments { .. }))
        .count();
    assert_eq!(successes_after, 2);
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn display_failed_brightness_blocks_segments_and_caching() {
    // "failed brightness delivery does not mark the display delivered"
    let harness = DisplayHarness::start();
    harness
        .source
        .set(1, vec![display_binding(1, "Speed", "{value:.1f}")]);
    harness.activate(1).await;
    harness
        .simulator
        .set_reading(3000, harness.simulator.reading_of(json!(42.5)));
    harness
        .hardware
        .fail_brightness
        .store(true, Ordering::SeqCst);

    harness.poll().await;
    assert_eq!(
        harness.hardware.trace(),
        vec![brightness("port-123", 0x70, 7)],
        "brightness failure must stop the segments write"
    );

    harness
        .hardware
        .fail_brightness
        .store(false, Ordering::SeqCst);
    harness.poll().await;
    let segments_sent = harness
        .hardware
        .trace()
        .iter()
        .filter(|c| matches!(c, HardwareCall::Segments { .. }))
        .count();
    assert_eq!(segments_sent, 1);
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn display_without_a_connected_port_never_caches() {
    // "does not cache values without a connected port"
    let harness = DisplayHarness::start();
    harness
        .source
        .set(1, vec![display_binding(1, "Speed", "{value:.1f}")]);
    harness.activate(1).await;
    harness
        .simulator
        .set_reading(3000, harness.simulator.reading_of(json!(42.5)));
    harness.hardware.disconnect(123);

    harness.poll().await;
    assert!(harness.hardware.trace().is_empty());

    harness.hardware.reconnect(123);
    harness.poll().await;
    assert_eq!(harness.hardware.trace().len(), 2);
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn devices_updated_replays_stable_text_with_brightness_once() {
    // "replays stable text and brightness after hardware reconnect"
    let harness = DisplayHarness::start();
    harness
        .source
        .set(1, vec![display_binding(1, "Speed", "{value:.1f}")]);
    harness.activate(1).await;
    harness
        .simulator
        .set_reading(3000, harness.simulator.reading_of(json!(42.5)));
    harness.poll().await;
    assert_eq!(harness.hardware.trace().len(), 2);

    harness.controller.devices_updated().await;
    settle().await;
    harness.poll().await;
    // Invalidation resends brightness + segments for the same text.
    assert_eq!(harness.hardware.trace().len(), 4);
    assert_eq!(harness.hardware.trace()[2], brightness("port-123", 0x70, 7));

    harness.poll().await;
    assert_eq!(harness.hardware.trace().len(), 4);
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn simulator_reconnect_subscribes_a_profile_loaded_while_disconnected() {
    // "subscribes to a profile loaded while the simulator was disconnected"
    let harness = DisplayHarness::start();
    harness
        .source
        .set(1, vec![display_binding(1, "Speed", "{value}")]);
    harness.connection.connected.store(false, Ordering::SeqCst);
    harness.controller.train_changed(Some(train(1))).await;
    settle().await;
    assert!(harness.simulator.trace().is_empty());

    harness.connection.connected.store(true, Ordering::SeqCst);
    harness.controller.simulator_connected().await;
    yield_until(|| {
        harness
            .simulator
            .trace()
            .iter()
            .find(|c| matches!(c, SimCall::Subscribe { id: 3000, .. }))
            .map(|_| ())
    })
    .await;
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn configuration_replay_reloads_address_brightness_encoding_and_minimum() {
    // "configuration replay reloads persisted address, encoding, brightness
    // and minimum" — value 42.5 clamped to the persisted 50.0 minimum, encoded
    // on an 8-digit seven-segment module at 0x71.
    let harness = DisplayHarness::start();
    harness
        .source
        .set(1, vec![display_binding(1, "Speed", "{value:.1f}")]);
    harness.activate(1).await;
    harness
        .simulator
        .set_reading(3000, harness.simulator.reading_of(json!(42.5)));
    harness.poll().await;
    assert_eq!(harness.hardware.trace().len(), 2);

    let mut updated = display_binding(1, "Speed", "{value:.1f}");
    updated.i2c_address = 0x71;
    updated.brightness = 12;
    updated.num_digits = 8;
    updated.seven_segment = true;
    updated.has_dot = true;
    updated.align_right = false;
    updated.min_value = Some(50.0);
    harness.source.set(1, vec![updated]);

    harness.controller.configuration_applied().await;
    yield_until(|| {
        harness
            .simulator
            .trace()
            .iter()
            .filter(|c| matches!(c, SimCall::Subscribe { .. }))
            .nth(1)
            .map(|_| ())
    })
    .await;
    // Cleanup during replay unsubscribes but does NOT blank the old address.
    assert!(!harness
        .hardware
        .trace()
        .iter()
        .any(|c| matches!(c, HardwareCall::Segments { address: 0x70, data, .. } if data.iter().all(|b| *b == 0))));

    harness.poll().await;
    // Elixir golden: WriteSegments{0x71, <<0x6D, 0xBF, 0x3F, 0, 0, 0, 0, 0>>}
    // for "50.0" on 8 digits, seven-segment, dot, left-aligned.
    assert_eq!(
        harness.hardware.trace()[2..],
        vec![
            brightness("port-123", 0x71, 12),
            segments(
                "port-123",
                0x71,
                vec![0x6D, 0xBF, 0x3F, 0x00, 0x00, 0x00, 0x00, 0x00]
            ),
        ]
    );
    assert!(!harness.hardware.trace()[2..]
        .iter()
        .any(|c| matches!(c, HardwareCall::SetBrightness { address: 0x70, .. })));
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn configuration_replay_drops_removed_modules_and_stops_the_poll_timer() {
    // "configuration replay drops removed modules and stops their poll timer"
    let harness = DisplayHarness::start();
    harness
        .source
        .set(1, vec![display_binding(1, "Speed", "{value:.1f}")]);
    harness.activate(1).await;
    harness
        .simulator
        .set_reading(3000, harness.simulator.reading_of(json!(42.5)));
    harness.poll().await;
    assert_eq!(harness.hardware.trace().len(), 2);

    harness.source.set(1, vec![]);
    harness.controller.configuration_applied().await;
    yield_until(|| {
        harness
            .simulator
            .trace()
            .iter()
            .find(|c| matches!(c, SimCall::Unsubscribe { id: 3000 }))
            .map(|_| ())
    })
    .await;

    // No blanking write for the removed module, no further polls.
    assert_eq!(harness.hardware.trace().len(), 2);
    let reads = harness
        .simulator
        .trace()
        .iter()
        .filter(|c| matches!(c, SimCall::GetSubscription { .. }))
        .count();
    harness.clock.advance(Duration::from_millis(10_000));
    settle().await;
    let reads_after = harness
        .simulator
        .trace()
        .iter()
        .filter(|c| matches!(c, SimCall::GetSubscription { .. }))
        .count();
    assert_eq!(reads_after, reads);
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn nil_minimum_renders_negative_values() {
    // "a persisted nil minimum renders negative simulator values"
    let harness = DisplayHarness::start();
    let mut binding = display_binding(1, "Speed", "{value}");
    binding.min_value = None;
    harness.source.set(1, vec![binding]);
    harness.activate(1).await;
    harness
        .simulator
        .set_reading(3000, harness.simulator.reading_of(json!(-12.5)));
    harness.poll().await;

    let expected = trenino_core::hardware::ht16k33::encode_string("-12.5", 4, false, false, true);
    assert_eq!(
        harness.hardware.trace()[1],
        segments("port-123", 0x70, expected)
    );
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn train_switch_blanks_displays_without_brightness_and_unsubscribes() {
    let harness = DisplayHarness::start();
    harness
        .source
        .set(1, vec![display_binding(1, "Speed", "{value:.1f}")]);
    harness.activate(1).await;
    harness
        .simulator
        .set_reading(3000, harness.simulator.reading_of(json!(42.5)));
    harness.poll().await;
    assert_eq!(harness.hardware.trace().len(), 2);

    harness.controller.train_changed(None).await;
    yield_until(|| (harness.hardware.trace().len() == 3).then_some(())).await;

    // Blank = empty-text encoding, no brightness message.
    let blank = trenino_core::hardware::ht16k33::encode_string("", 4, false, false, true);
    assert_eq!(
        harness.hardware.trace()[2],
        segments("port-123", 0x70, blank)
    );
    assert_eq!(
        harness
            .hardware
            .trace()
            .iter()
            .filter(|c| matches!(c, HardwareCall::SetBrightness { .. }))
            .count(),
        1
    );
    assert!(harness
        .simulator
        .trace()
        .iter()
        .any(|c| matches!(c, SimCall::Unsubscribe { id: 3000 })));
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn display_blank_cleanup_still_runs_when_simulator_is_disconnected() {
    let harness = DisplayHarness::start();
    harness
        .source
        .set(1, vec![display_binding(1, "Speed", "{value:.1f}")]);
    harness.activate(1).await;
    harness
        .simulator
        .set_reading(3000, harness.simulator.reading_of(json!(42.5)));
    harness.poll().await;

    harness.connection.connected.store(false, Ordering::SeqCst);
    harness.controller.train_changed(None).await;
    yield_until(|| (harness.hardware.trace().len() == 3).then_some(())).await;
    // Unsubscribe was skipped (no client) but the blank went out anyway.
    assert!(!harness
        .simulator
        .trace()
        .iter()
        .any(|c| matches!(c, SimCall::Unsubscribe { .. })));
    harness.controller.shutdown().await;
}

#[tokio::test]
async fn a_queued_poll_cannot_leave_a_second_polling_timer_alive() {
    // "a queued poll cannot leave a second polling timer alive": after a
    // reload, each 200ms advance triggers exactly one get_subscription.
    let harness = DisplayHarness::start();
    harness
        .source
        .set(1, vec![display_binding(1, "Speed", "{value:.1f}")]);
    harness.activate(1).await;
    harness.controller.reload_bindings().await;
    yield_until(|| {
        harness
            .simulator
            .trace()
            .iter()
            .filter(|c| matches!(c, SimCall::Subscribe { .. }))
            .nth(1)
            .map(|_| ())
    })
    .await;

    harness
        .simulator
        .set_reading(3000, harness.simulator.reading_of(json!(1.0)));
    for expected_reads in 1..=3 {
        advance_until(&harness.clock, Duration::from_millis(200), || {
            let reads = harness
                .simulator
                .trace()
                .iter()
                .filter(|c| matches!(c, SimCall::GetSubscription { .. }))
                .count();
            (reads >= expected_reads).then_some(reads)
        })
        .await;
        settle().await;
        let reads = harness
            .simulator
            .trace()
            .iter()
            .filter(|c| matches!(c, SimCall::GetSubscription { .. }))
            .count();
        assert_eq!(reads, expected_reads, "exactly one poll per 200ms");
    }
    harness.controller.shutdown().await;
}
