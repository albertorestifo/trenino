//! Integration tests for `SimulatorConnectionOwner`
//! (`trenino_runtime::simulator::connection_owner`).
//!
//! The owner ports the `Trenino.Simulator.Connection` GenServer
//! (lib/trenino/simulator/connection.ex); its ExUnit suite
//! test/trenino/simulator/connection_test.exs is the oracle for the
//! health-check tolerance, and the GenServer source pins the remaining
//! cadences and casts. Every test drives the accepted `SimulatorClient`
//! against a loopback fake TSW HTTP server and a `FakeClock` — the same
//! harness style as `tests/simulator_detection.rs` — so the 1s initial
//! delay, 30s health poll, 2s fast recheck and 30s retry cadence are
//! exercised without real waits.
//!
//! Oracle mapping:
//!
//! - "single transient failure does not change status to error"
//!   (connection_test.exs:54-65) →
//!   `single_transient_health_failure_stays_connected_with_the_two_second_fast_retry`
//! - "3 consecutive failures trigger error broadcast" (:67-82) →
//!   `three_consecutive_health_failures_broadcast_error_and_reconnect_after_thirty_seconds`
//! - "invalid_key error is permanent and triggers immediate error" (:84-99) →
//!   `invalid_key_is_a_permanent_health_failure` and
//!   `invalid_key_on_the_connect_attempt_errors_and_retries`
//! - "recovery after failures resets counter" (:101-124) →
//!   `health_recovery_resets_the_failure_counter`
//! - setup's initial-connect wait (:31-42) and the source-pinned casts,
//!   timers and async-task handling (connection.ex:98-243) → the remaining
//!   lifecycle tests.

use std::collections::VecDeque;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

use tokio::sync::{broadcast, mpsc};

use trenino_runtime::simulator::connection::{ConnectionError, SimulatorStatus};
use trenino_runtime::simulator::connection_owner::{
    ConnectionConfig, ConnectionSignal, SimulatorConnectionOwner, StatusChanged,
};
use trenino_runtime::simulator::services::clock::FakeClock;

const DRIVE_LIMIT: usize = 30_000;

// ---------------------------------------------------------------------------
// Fake loopback TSW HTTP server (scripted responses, thread-per-connection)
// ---------------------------------------------------------------------------

/// A scripted response. `Held` blocks its connection thread until the test
/// releases it, which pins the mid-flight reconfigure race deterministically.
enum Scripted {
    Ready(u16, String),
    Held(std::sync::mpsc::Receiver<()>, u16, String),
}

struct FakeTsw {
    base_url: String,
    requests: Arc<Mutex<Vec<String>>>,
    script: Arc<Mutex<VecDeque<Scripted>>>,
}

impl FakeTsw {
    /// Every request is answered with `{"commands":["info"]}` (the oracle
    /// setup's default Req stub) unless a scripted response is queued.
    fn spawn() -> Self {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let address = listener.local_addr().unwrap();
        let requests = Arc::new(Mutex::new(Vec::new()));
        let script = Arc::new(Mutex::new(VecDeque::new()));
        let (logged, queued) = (requests.clone(), script.clone());
        thread::spawn(move || {
            for stream in listener.incoming().flatten() {
                let (logged, queued) = (logged.clone(), queued.clone());
                thread::spawn(move || serve(stream, logged, queued));
            }
        });
        Self {
            base_url: format!("http://{address}"),
            requests,
            script,
        }
    }

    fn url(&self) -> String {
        self.base_url.clone()
    }

    /// Queue the next response for any request (script entries are consumed
    /// in order, like the oracle's `expect(Req, :request, n, …)`).
    fn push(&self, status: u16, body: &str) {
        self.script
            .lock()
            .unwrap()
            .push_back(Scripted::Ready(status, body.to_owned()));
    }

    /// Queue a response whose connection blocks until the returned sender
    /// fires; the response then goes out as `(status, body)`.
    fn push_held(&self, status: u16, body: &str) -> std::sync::mpsc::Sender<()> {
        let (release, receiver) = std::sync::mpsc::channel();
        self.script
            .lock()
            .unwrap()
            .push_back(Scripted::Held(receiver, status, body.to_owned()));
        release
    }

    fn request_count(&self) -> usize {
        self.requests.lock().unwrap().len()
    }

    fn logged_requests(&self) -> Vec<String> {
        self.requests.lock().unwrap().clone()
    }
}

fn serve(
    stream: TcpStream,
    logged: Arc<Mutex<Vec<String>>>,
    queued: Arc<Mutex<VecDeque<Scripted>>>,
) {
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
    let (status, body) = match queued.lock().unwrap().pop_front() {
        Some(Scripted::Ready(status, body)) => (status, body),
        Some(Scripted::Held(release, status, body)) => {
            // Block the connection thread (not the owner) until released.
            let _ = release.recv();
            (status, body)
        }
        None => (200, r#"{"commands":["info"]}"#.to_owned()),
    };
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

/// A URL that refuses connections without retries worth waiting for
/// (mirrors tests/simulator_detection.rs:974-978).
fn dead_url() -> String {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let url = format!("http://{}", listener.local_addr().unwrap());
    drop(listener);
    url
}

// ---------------------------------------------------------------------------
// Fake settings (`Trenino.Settings` surface consumed by connection.ex)
// ---------------------------------------------------------------------------

struct FakeConfig {
    url: Mutex<String>,
    api_key: Mutex<Option<String>>,
}

impl FakeConfig {
    fn new(url: String) -> Arc<Self> {
        Arc::new(Self {
            url: Mutex::new(url),
            api_key: Mutex::new(Some("test-api-key".to_owned())),
        })
    }

    fn set_url(&self, url: String) {
        *self.url.lock().unwrap() = url;
    }

    fn set_api_key(&self, key: Option<String>) {
        *self.api_key.lock().unwrap() = key;
    }
}

impl ConnectionConfig for FakeConfig {
    fn simulator_url(&self) -> String {
        self.url.lock().unwrap().clone()
    }
    fn api_key(&self) -> Option<String> {
        self.api_key.lock().unwrap().clone()
    }
}

// ---------------------------------------------------------------------------
// Harness + fake-clock drivers (tests/simulator_detection.rs:217-267 style)
// ---------------------------------------------------------------------------

struct Harness {
    owner: SimulatorConnectionOwner,
    events: broadcast::Receiver<StatusChanged>,
    signals: mpsc::Receiver<ConnectionSignal>,
    clock: FakeClock,
    server: FakeTsw,
    config: Arc<FakeConfig>,
}

impl Harness {
    fn start() -> Self {
        let server = FakeTsw::spawn();
        let config = FakeConfig::new(server.url());
        Self::with(config, server)
    }

    fn with(config: Arc<FakeConfig>, server: FakeTsw) -> Self {
        let clock = FakeClock::new();
        let (signal_sender, signals) = mpsc::channel(64);
        let owner =
            SimulatorConnectionOwner::start(Arc::new(clock.clone()), config.clone(), signal_sender);
        let events = owner.subscribe();
        Self {
            owner,
            events,
            signals,
            clock,
            server,
            config,
        }
    }

    /// The oracle setup state (connection_test.exs:36-42): wait for the
    /// initial 1s-delayed attempt to connect, then drain startup broadcasts.
    async fn connected(&mut self) {
        self.clock.advance(Duration::from_secs(1));
        let connecting = next_status(&mut self.events).await;
        assert_eq!(connecting.0.status, SimulatorStatus::Connecting);
        assert!(connecting.0.client.is_some());
        assert!(connecting.0.last_error.is_none());
        let connected = next_status(&mut self.events).await;
        assert_eq!(connected.0.status, SimulatorStatus::Connected);
        assert_eq!(
            connected.0.info,
            Some(serde_json::json!({"commands": ["info"]}))
        );
        drain_status(&mut self.events);
        settle().await;
    }
}

/// 1ms real sleeps between probes so the current-thread runtime parks and its
/// IO/timer drivers can run loopback HTTP round trips (fake time is exact).
async fn yield_until<T>(mut probe: impl FnMut() -> Option<T>) -> T {
    for _ in 0..DRIVE_LIMIT {
        if let Some(value) = probe() {
            return value;
        }
        tokio::time::sleep(Duration::from_millis(1)).await;
    }
    panic!("condition never observed while yielding");
}

/// Wait for the next broadcast without moving the fake clock (attempt
/// results and command effects arrive on real IO time).
async fn next_status(events: &mut broadcast::Receiver<StatusChanged>) -> StatusChanged {
    yield_until(|| events.try_recv().ok()).await
}

/// drain_status_messages/0 (connection_test.exs:45-51).
fn drain_status(events: &mut broadcast::Receiver<StatusChanged>) {
    while events.try_recv().is_ok() {}
}

/// Real-time settle so in-flight work finishes before an absence proof.
async fn settle() {
    tokio::time::sleep(Duration::from_millis(20)).await;
}

/// Prove no further status broadcast arrives (and thus no timer fired).
async fn assert_no_status(events: &mut broadcast::Receiver<StatusChanged>) {
    drain_status(events);
    settle().await;
    assert!(matches!(
        events.try_recv(),
        Err(broadcast::error::TryRecvError::Empty)
    ));
}

fn take_signals(signals: &mut mpsc::Receiver<ConnectionSignal>) -> Vec<ConnectionSignal> {
    let mut collected = Vec::new();
    while let Ok(signal) = signals.try_recv() {
        collected.push(signal);
    }
    collected
}

fn assert_disconnected_signal(signal: &ConnectionSignal) {
    assert!(matches!(signal, ConnectionSignal::Disconnected));
}

// ===========================================================================
// Initial connection (connection.ex:98-105, 134-138, 179-205, 236-243)
// ===========================================================================

/// init/1 schedules the first attempt after the 1s initial delay; the async
/// probe broadcasts Connecting immediately and Connected with the /info body
/// when the task replies (Task.Supervisor.async_nolink + {ref, result}).
#[tokio::test]
async fn initial_connect_after_one_second_broadcasts_connecting_then_connected() {
    let mut harness = Harness::start();

    // 999ms: nothing yet — no attempt, no request, no broadcast.
    harness.clock.advance(Duration::from_millis(999));
    assert_no_status(&mut harness.events).await;
    assert_eq!(harness.server.request_count(), 0);
    assert_eq!(
        harness.owner.status().await.unwrap().status,
        SimulatorStatus::NeedsConfig
    );

    // 1ms more: the initial delay elapses and the attempt runs.
    harness.clock.advance(Duration::from_millis(1));
    let connecting = next_status(&mut harness.events).await;
    assert_eq!(connecting.0.status, SimulatorStatus::Connecting);
    let connected = next_status(&mut harness.events).await;
    assert_eq!(connected.0.status, SimulatorStatus::Connected);
    assert_eq!(connected.0.health_failures, 0);
    assert!(connected.0.client.is_some());

    // The snapshot client is the live one (get_status carries the client).
    let snapshot = harness.owner.status().await.unwrap();
    assert_eq!(snapshot.status, SimulatorStatus::Connected);
    assert!(snapshot.client.is_some());
    assert_eq!(harness.server.request_count(), 1);
    assert_eq!(
        harness.server.logged_requests(),
        vec!["GET /info".to_owned()]
    );

    // detection.ex:174-199 — the detection feed sees the broadcast pair.
    let signals = take_signals(&mut harness.signals);
    assert_eq!(signals.len(), 2);
    assert_disconnected_signal(&signals[0]); // Connecting broadcast
    assert!(matches!(signals[1], ConnectionSignal::Connected(_)));

    harness.owner.shutdown().await.unwrap();
}

// ===========================================================================
// Health check tolerance (connection_test.exs:53-125)
// ===========================================================================

/// Oracle: "single transient failure does not change status to error"
/// (connection_test.exs:54-65) plus the 2s fast recheck cadence the oracle
/// drives manually (connection.ex:150-154): a transport-level failure keeps
/// the Connected status, records health_failures and stays silent.
#[tokio::test]
async fn single_transient_health_failure_stays_connected_with_the_two_second_fast_retry() {
    let mut harness = Harness::start();
    harness.connected().await;

    // First failing health poll 30s after the connect (500 on the fast
    // profile is a single attempt — no internal retries).
    harness.server.push(500, r#"{"error":"boom"}"#);
    harness.clock.advance(Duration::from_secs(30));
    settle().await;

    let status = harness.owner.status().await.unwrap();
    assert_eq!(status.status, SimulatorStatus::Connected);
    assert_eq!(status.health_failures, 1);
    assert_eq!(status.last_error, Some(ConnectionError::ConnectionFailed));
    // Transient failure: no broadcast (connection.ex:150-154).
    assert_no_status(&mut harness.events).await;

    // The recheck fires after 2s — not 30s: a second scripted failure at
    // exactly +2s bumps the counter again.
    harness.server.push(500, r#"{"error":"boom"}"#);
    harness.clock.advance(Duration::from_millis(1_999));
    assert_eq!(harness.owner.status().await.unwrap().health_failures, 1);
    harness.clock.advance(Duration::from_millis(1));
    settle().await;

    let status = harness.owner.status().await.unwrap();
    assert_eq!(status.status, SimulatorStatus::Connected);
    assert_eq!(status.health_failures, 2);
    assert_no_status(&mut harness.events).await;

    harness.owner.shutdown().await.unwrap();
}

/// Oracle: "3 consecutive failures trigger error broadcast"
/// (connection_test.exs:67-82) — the third consecutive failure flips to
/// Error, broadcasts, resets the counter (mark_error) and enters the 30s
/// reconnect cadence (connection.ex:156-160, 296-298).
#[tokio::test]
async fn three_consecutive_health_failures_broadcast_error_and_reconnect_after_thirty_seconds() {
    let mut harness = Harness::start();
    harness.connected().await;

    for _ in 0..3 {
        harness.server.push(500, r#"{"error":"boom"}"#);
    }
    harness.clock.advance(Duration::from_secs(30)); // failure 1/3
    settle().await;
    harness.clock.advance(Duration::from_secs(2)); // failure 2/3 (fast retry)
    settle().await;
    harness.clock.advance(Duration::from_secs(2)); // failure 3/3 → error
    let error = next_status(&mut harness.events).await;

    assert_eq!(error.0.status, SimulatorStatus::Error);
    assert_eq!(error.0.last_error, Some(ConnectionError::ConnectionFailed));
    assert_eq!(error.0.health_failures, 0); // mark_error resets (connection_state.ex:87-95)
    assert_eq!(
        harness.owner.status().await.unwrap().status,
        SimulatorStatus::Error
    );
    let signals = take_signals(&mut harness.signals);
    assert_disconnected_signal(signals.last().unwrap());

    // Reconnect cadence: quiet until exactly +30s from the error, then a new
    // attempt succeeds (script exhausted → default 200).
    let requests_at_error = harness.server.request_count();
    harness.clock.advance(Duration::from_millis(29_999));
    assert_eq!(harness.server.request_count(), requests_at_error);
    assert_no_status(&mut harness.events).await;

    harness.clock.advance(Duration::from_millis(1));
    let connecting = next_status(&mut harness.events).await;
    assert_eq!(connecting.0.status, SimulatorStatus::Connecting);
    let connected = next_status(&mut harness.events).await;
    assert_eq!(connected.0.status, SimulatorStatus::Connected);
    assert_eq!(harness.server.request_count(), requests_at_error + 1);

    harness.owner.shutdown().await.unwrap();
}

/// Oracle: "invalid_key error is permanent and triggers immediate error"
/// (connection_test.exs:84-99) — a 403 on the health check bypasses the
/// transient budget, broadcasts Error immediately with last_error
/// :invalid_key.
#[tokio::test]
async fn invalid_key_is_a_permanent_health_failure() {
    let mut harness = Harness::start();
    harness.connected().await;

    harness
        .server
        .push(403, r#"{"errorCode":"dtg.comm.InvalidKey"}"#);
    harness.clock.advance(Duration::from_secs(30));
    let error = next_status(&mut harness.events).await;

    assert_eq!(error.0.status, SimulatorStatus::Error);
    assert_eq!(error.0.last_error, Some(ConnectionError::InvalidKey));
    let status = harness.owner.status().await.unwrap();
    assert_eq!(status.status, SimulatorStatus::Error);
    assert_eq!(status.last_error, Some(ConnectionError::InvalidKey));
    assert_eq!(status.health_failures, 0);
    let signals = take_signals(&mut harness.signals);
    assert_disconnected_signal(signals.last().unwrap());

    harness.owner.shutdown().await.unwrap();
}

/// Oracle: "recovery after failures resets counter" (connection_test.exs:101-
/// 124) — a successful recheck after a transient failure clears the counter
/// and stays silent.
#[tokio::test]
async fn health_recovery_resets_the_failure_counter() {
    let mut harness = Harness::start();
    harness.connected().await;

    harness.server.push(500, r#"{"error":"boom"}"#);
    harness.clock.advance(Duration::from_secs(30));
    settle().await;
    assert_eq!(harness.owner.status().await.unwrap().health_failures, 1);

    // Fast recheck at +2s succeeds (script exhausted → default 200).
    harness.clock.advance(Duration::from_secs(2));
    settle().await;

    let status = harness.owner.status().await.unwrap();
    assert_eq!(status.status, SimulatorStatus::Connected);
    assert_eq!(status.health_failures, 0);
    assert_eq!(status.last_error, None);
    assert_no_status(&mut harness.events).await;

    harness.owner.shutdown().await.unwrap();
}

// ===========================================================================
// Connect-path failures and the retry cadence (connection.ex:206-217, 296-298)
// ===========================================================================

/// handle_connection_result/2's {:error, reason} branch: a dead endpoint
/// lands in Error with :connection_failed and reconnects every 30s.
#[tokio::test]
async fn connection_failure_errors_and_reconnects_on_the_thirty_second_cadence() {
    let mut harness = Harness::start();
    harness.config.set_url(dead_url());

    harness.clock.advance(Duration::from_secs(1));
    let connecting = next_status(&mut harness.events).await;
    assert_eq!(connecting.0.status, SimulatorStatus::Connecting);
    let error = next_status(&mut harness.events).await;
    assert_eq!(error.0.status, SimulatorStatus::Error);
    assert_eq!(error.0.last_error, Some(ConnectionError::ConnectionFailed));

    // 29.999s after the failure: quiet; 1ms more: the retry attempt fires.
    harness.clock.advance(Duration::from_millis(29_999));
    assert_no_status(&mut harness.events).await;
    harness.clock.advance(Duration::from_millis(1));
    let connecting = next_status(&mut harness.events).await;
    assert_eq!(connecting.0.status, SimulatorStatus::Connecting);
    let error = next_status(&mut harness.events).await;
    assert_eq!(error.0.status, SimulatorStatus::Error);
    assert_eq!(error.0.last_error, Some(ConnectionError::ConnectionFailed));

    harness.owner.shutdown().await.unwrap();
}

/// handle_connection_result/2's invalid-key branch (connection.ex:207-211):
/// a 403 on the initial attempt is a permanent Error that still retries on
/// the shared 30s cadence.
#[tokio::test]
async fn invalid_key_on_the_connect_attempt_errors_and_retries() {
    let mut harness = Harness::start();
    harness
        .server
        .push(403, r#"{"errorCode":"dtg.comm.InvalidKey"}"#);

    harness.clock.advance(Duration::from_secs(1));
    let connecting = next_status(&mut harness.events).await;
    assert_eq!(connecting.0.status, SimulatorStatus::Connecting);
    let error = next_status(&mut harness.events).await;
    assert_eq!(error.0.status, SimulatorStatus::Error);
    assert_eq!(error.0.last_error, Some(ConnectionError::InvalidKey));
    assert_eq!(harness.server.request_count(), 1);

    // Exactly one retry request at +30s; the default 200 response then
    // connects (the key/config never changed, mirroring the oracle's
    // schedule_retry-after-invalid-key behavior).
    harness.clock.advance(Duration::from_millis(29_999));
    assert_eq!(harness.server.request_count(), 1);
    harness.clock.advance(Duration::from_millis(1));
    let connecting = next_status(&mut harness.events).await;
    assert_eq!(connecting.0.status, SimulatorStatus::Connecting);
    let connected = next_status(&mut harness.events).await;
    assert_eq!(connected.0.status, SimulatorStatus::Connected);
    assert_eq!(connected.0.last_error, None);
    assert_eq!(harness.server.request_count(), 2);

    harness.owner.shutdown().await.unwrap();
}

// ===========================================================================
// needs_config, retry_connection, reconfigure, disconnect
// (connection.ex:53-94, 112-131, 219-227)
// ===========================================================================

/// attempt_connection/1 (connection.ex:219-227): without an API key the owner
/// parks in NeedsConfig, schedules nothing and stays silent until settings
/// change; reconfigure then reconnects after 500ms.
#[tokio::test]
async fn missing_api_key_parks_in_needs_config_without_polling() {
    let mut harness = Harness::start();
    harness.config.set_api_key(None);

    harness.clock.advance(Duration::from_secs(1));
    let needs_config = next_status(&mut harness.events).await;
    assert_eq!(needs_config.0.status, SimulatorStatus::NeedsConfig);
    assert!(needs_config.0.client.is_none());
    assert_eq!(harness.server.request_count(), 0);

    // No retry is scheduled: silence for a full minute.
    harness.clock.advance(Duration::from_secs(60));
    assert_no_status(&mut harness.events).await;
    assert_eq!(harness.server.request_count(), 0);
    assert_eq!(
        harness.owner.status().await.unwrap().status,
        SimulatorStatus::NeedsConfig
    );

    // Settings arrive → reconfigure → 500ms delayed reconnect.
    harness.config.set_api_key(Some("late-key".to_owned()));
    harness.owner.reconfigure().await.unwrap();
    assert_eq!(
        harness.owner.status().await.unwrap().status,
        SimulatorStatus::Disconnected
    );
    assert_no_status(&mut harness.events).await; // reconfigure never broadcasts
    harness.clock.advance(Duration::from_millis(500));
    let connecting = next_status(&mut harness.events).await;
    assert_eq!(connecting.0.status, SimulatorStatus::Connecting);
    let connected = next_status(&mut harness.events).await;
    assert_eq!(connected.0.status, SimulatorStatus::Connected);
    assert_eq!(harness.server.request_count(), 1);

    harness.owner.shutdown().await.unwrap();
}

/// retry_connection/0 (connection.ex:53-65) is the :connect cast: it attempts
/// immediately, without waiting for any timer.
#[tokio::test]
async fn retry_connection_attempts_immediately_from_error() {
    let mut harness = Harness::start();
    let live_url = harness.server.url();
    harness.config.set_url(dead_url());

    harness.clock.advance(Duration::from_secs(1));
    next_status(&mut harness.events).await; // Connecting
    let error = next_status(&mut harness.events).await;
    assert_eq!(error.0.status, SimulatorStatus::Error);
    drain_status(&mut harness.events);

    // No clock advance at all: the manual retry runs on real IO time.
    harness.config.set_url(live_url);
    harness.owner.retry_connection().await.unwrap();
    let connecting = next_status(&mut harness.events).await;
    assert_eq!(connecting.0.status, SimulatorStatus::Connecting);
    let connected = next_status(&mut harness.events).await;
    assert_eq!(connected.0.status, SimulatorStatus::Connected);
    assert_eq!(harness.server.request_count(), 1);
    harness.owner.shutdown().await.unwrap();
}

/// handle_cast(:reconfigure) (connection.ex:118-124): disconnect silently,
/// then reconnect with the fresh URL/key after 500ms; the old endpoint is
/// never polled again.
#[tokio::test]
async fn reconfigure_mid_connection_reconnects_with_new_settings() {
    let mut harness = Harness::start();
    harness.connected().await;
    let requests_before = harness.server.request_count();

    let replacement = FakeTsw::spawn();
    harness.config.set_url(replacement.url());
    harness
        .config
        .set_api_key(Some("replacement-key".to_owned()));

    harness.owner.reconfigure().await.unwrap();
    let status = harness.owner.status().await.unwrap();
    assert_eq!(status.status, SimulatorStatus::Disconnected);
    assert!(status.client.is_none());
    assert!(status.info.is_none());
    assert_no_status(&mut harness.events).await; // reconfigure does not broadcast

    // 499ms: still silent; 1ms more: the reconnect attempt fires.
    harness.clock.advance(Duration::from_millis(499));
    assert_eq!(replacement.request_count(), 0);
    assert_no_status(&mut harness.events).await;
    harness.clock.advance(Duration::from_millis(1));
    let connecting = next_status(&mut harness.events).await;
    assert_eq!(connecting.0.status, SimulatorStatus::Connecting);
    let connected = next_status(&mut harness.events).await;
    assert_eq!(connected.0.status, SimulatorStatus::Connected);

    assert_eq!(replacement.request_count(), 1);
    assert_eq!(replacement.logged_requests(), vec!["GET /info".to_owned()]);
    // The old endpoint is frozen: no further polls after the reconfigure.
    settle().await;
    assert_eq!(harness.server.request_count(), requests_before);

    harness.owner.shutdown().await.unwrap();
}

/// Reconfigure must fence the old HTTP attempt before activating fresh settings.
#[tokio::test]
async fn reconfigure_mid_attempt_fences_the_old_result() {
    let mut harness = Harness::start();
    let release = harness.server.push_held(200, r#"{"commands":["info"]}"#);
    harness.clock.advance(Duration::from_secs(1));
    assert_eq!(
        next_status(&mut harness.events).await.0.status,
        SimulatorStatus::Connecting
    );
    yield_until(|| (harness.server.request_count() == 1).then_some(())).await;
    let replacement = FakeTsw::spawn();
    harness.config.set_url(replacement.url());
    harness.owner.reconfigure().await.unwrap();
    assert_eq!(
        harness.owner.status().await.unwrap().status,
        SimulatorStatus::Disconnected
    );
    let _ = release.send(());
    settle().await;
    assert!(harness.events.try_recv().is_err());
    harness.clock.advance(Duration::from_millis(500));
    assert_eq!(
        next_status(&mut harness.events).await.0.status,
        SimulatorStatus::Connecting
    );
    assert_eq!(
        next_status(&mut harness.events).await.0.status,
        SimulatorStatus::Connected
    );
    assert_eq!(replacement.request_count(), 1);
    harness.owner.shutdown().await.unwrap();
}

/// handle_cast(:disconnect) (connection.ex:126-131): broadcast Disconnected,
/// drop the client, and stop probing — the health chain keeps rescheduling
/// without issuing requests (connection.ex:165-169).
#[tokio::test]
async fn disconnect_broadcasts_stops_polling_and_freezes_requests() {
    let mut harness = Harness::start();
    harness.connected().await;
    let requests_before = harness.server.request_count();

    harness.owner.disconnect().await.unwrap();
    let disconnected = next_status(&mut harness.events).await;
    assert_eq!(disconnected.0.status, SimulatorStatus::Disconnected);
    assert!(disconnected.0.client.is_none());
    assert!(disconnected.0.info.is_none());
    assert_eq!(disconnected.0.health_failures, 0);
    assert_eq!(
        harness.owner.status().await.unwrap().status,
        SimulatorStatus::Disconnected
    );
    let signals = take_signals(&mut harness.signals);
    assert_disconnected_signal(signals.last().unwrap());

    // A full minute of fake time: no broadcast, no /info poll.
    harness.clock.advance(Duration::from_secs(60));
    assert_no_status(&mut harness.events).await;
    assert_eq!(harness.server.request_count(), requests_before);
    assert_eq!(
        harness.owner.status().await.unwrap().status,
        SimulatorStatus::Disconnected
    );

    harness.owner.shutdown().await.unwrap();
}

// ===========================================================================
// Subscriptions and the detection feed (connection.ex:43-51, 300-306;
// detection.ex:174-199)
// ===========================================================================

/// subscribe/0 is PubSub: every subscriber observes the same broadcast
/// stream, and the signal feed maps it to the connected/disconnected pair
/// Detection reacts to. The snapshot client stays live.
#[tokio::test]
async fn subscriptions_and_signals_mirror_the_pubsub_stream() {
    let mut harness = Harness::start();
    let mut second = harness.owner.subscribe();

    // connect → disconnect → retry_connection → connect.
    harness.clock.advance(Duration::from_secs(1));
    for expected in [SimulatorStatus::Connecting, SimulatorStatus::Connected] {
        let event = next_status(&mut harness.events).await;
        assert_eq!(event.0.status, expected);
        let mirrored = next_status(&mut second).await;
        assert_eq!(mirrored.0.status, expected);
    }
    drain_status(&mut harness.events);
    drain_status(&mut second);

    harness.owner.disconnect().await.unwrap();
    let event = next_status(&mut harness.events).await;
    assert_eq!(event.0.status, SimulatorStatus::Disconnected);
    let mirrored = next_status(&mut second).await;
    assert_eq!(mirrored.0.status, SimulatorStatus::Disconnected);

    harness.owner.retry_connection().await.unwrap();
    let event = next_status(&mut harness.events).await;
    assert_eq!(event.0.status, SimulatorStatus::Connecting);
    let event = next_status(&mut harness.events).await;
    assert_eq!(event.0.status, SimulatorStatus::Connected);

    // The signal feed: Connecting→Disconnected, Connected, Disconnect cast,
    // Connecting→Disconnected, Connected (detection.ex:174-199 reacts to
    // every broadcast, connected only on :connected).
    let signals = take_signals(&mut harness.signals);
    assert_eq!(signals.len(), 5);
    assert_disconnected_signal(&signals[0]);
    assert!(matches!(signals[1], ConnectionSignal::Connected(_)));
    assert_disconnected_signal(&signals[2]);
    assert_disconnected_signal(&signals[3]);
    assert!(matches!(signals[4], ConnectionSignal::Connected(_)));

    // The snapshot client is the live client: a direct /info succeeds.
    let snapshot = harness.owner.status().await.unwrap();
    let info = snapshot
        .client
        .expect("connected snapshot carries the client")
        .info()
        .await
        .unwrap();
    assert_eq!(info, serde_json::json!({"commands": ["info"]}));

    harness.owner.shutdown().await.unwrap();
}

#[tokio::test]
async fn disconnect_fences_an_inflight_connect_result() {
    let mut harness = Harness::start();
    settle().await;
    let release = harness.server.push_held(200, r#"{"commands":["info"]}"#);
    harness.clock.advance(Duration::from_secs(1));
    assert_eq!(
        next_status(&mut harness.events).await.0.status,
        SimulatorStatus::Connecting
    );
    yield_until(|| (harness.server.request_count() == 1).then_some(())).await;
    harness.owner.disconnect().await.unwrap();
    assert_eq!(
        next_status(&mut harness.events).await.0.status,
        SimulatorStatus::Disconnected
    );
    let _ = release.send(());
    settle().await;
    assert_eq!(
        harness.owner.status().await.unwrap().status,
        SimulatorStatus::Disconnected
    );
    assert!(
        harness.events.try_recv().is_err(),
        "stale connect result must not reactivate controllers"
    );
    harness.owner.shutdown().await.unwrap();
}

#[tokio::test]
async fn shutdown_is_idempotent_and_cancels_pending_connect() {
    let mut harness = Harness::start();
    settle().await;
    let release = harness.server.push_held(200, r#"{"commands":["info"]}"#);
    harness.clock.advance(Duration::from_secs(1));
    assert_eq!(
        next_status(&mut harness.events).await.0.status,
        SimulatorStatus::Connecting
    );
    harness.owner.shutdown().await.unwrap();
    assert!(harness.owner.shutdown().await.is_ok());
    let _ = release.send(());
}

#[tokio::test]
async fn latest_state_recovers_even_when_compatibility_signals_are_full() {
    let mut harness = Harness::start();
    let latest = harness.owner.latest();
    harness.connected().await;
    // The current-state channel is independent of telemetry consumption.
    assert_eq!(latest.borrow().status, SimulatorStatus::Connected);
    for _ in 0..70 {
        harness.owner.disconnect().await.unwrap();
        assert_eq!(
            harness.owner.status().await.unwrap().status,
            SimulatorStatus::Disconnected
        );
    }
    assert_eq!(latest.borrow().status, SimulatorStatus::Disconnected);
    assert!(latest.borrow().client.is_none());
    harness.owner.shutdown().await.unwrap();
}

#[test]
fn client_debug_redacts_credentials_and_urls() {
    let client = trenino_runtime::simulator::client::SimulatorClient::new(
        "http://username:password@localhost:31270/?secret=private",
        "api-secret",
    )
    .unwrap();
    let diagnostic = format!("{client:?}");
    for secret in ["username", "password", "private", "api-secret"] {
        assert!(!diagnostic.contains(secret));
    }
}

#[tokio::test]
async fn disconnect_preempts_an_inflight_health_request() {
    let mut harness = Harness::start();
    harness.connected().await;
    let release = harness.server.push_held(200, r#"{"commands":["info"]}"#);
    harness.clock.advance(Duration::from_secs(30));
    yield_until(|| (harness.server.request_count() == 2).then_some(())).await;
    let disconnected = tokio::time::timeout(Duration::from_millis(300), async {
        harness.owner.disconnect().await.unwrap();
        harness.owner.status().await.unwrap()
    })
    .await;
    let _ = release.send(());
    assert_eq!(
        disconnected
            .expect("disconnect must cancel health IO, not wait for its HTTP deadline")
            .status,
        SimulatorStatus::Disconnected
    );
    harness.owner.shutdown().await.unwrap();
}
