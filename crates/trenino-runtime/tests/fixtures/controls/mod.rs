//! Shared fakes for the train runtime integration tests: a scripted loopback
//! TSW HTTP server, fake-clock drivers, an in-memory keystroke port and a
//! fake train configuration source. No real OS input, serial or network
//! beyond loopback; no user database.

#![allow(dead_code)]

use std::collections::{HashMap, VecDeque};
use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::{mpsc as std_mpsc, Arc, Mutex};
use std::thread;
use std::time::Duration;

use trenino_core::train::identifier::TrainProfile;
use trenino_core::EntityId;
use trenino_runtime::simulator::services::clock::FakeClock;
use trenino_runtime::train::button_controller::{ButtonKeystrokes, KeystrokeOwner};
use trenino_runtime::train::detection::{TrainConfigError, TrainConfigSnapshot, TrainConfigSource};

pub const DRIVE_LIMIT: usize = 30_000;

// ---------------------------------------------------------------------------
// Fake clock drivers (same pattern as tests/simulator_detection.rs)
// ---------------------------------------------------------------------------

/// Park 1ms between probes so the current-thread runtime can advance its IO
/// drivers; the fake clock keeps logical timing exact.
pub async fn yield_until<T>(mut probe: impl FnMut() -> Option<T>) -> T {
    for _ in 0..DRIVE_LIMIT {
        if let Some(value) = probe() {
            return value;
        }
        tokio::time::sleep(Duration::from_millis(1)).await;
    }
    panic!("condition never observed while yielding");
}

pub async fn advance_until<T>(
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

/// Real-time settle: let a just-observed effect finish its trailing IO and
/// let the worker re-arm timers from the un-advanced fake clock.
pub async fn settle() {
    tokio::time::sleep(Duration::from_millis(10)).await;
}

// ---------------------------------------------------------------------------
// Scripted fake TSW server
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, PartialEq)]
pub struct RequestLog {
    pub method: String,
    /// Percent-decoded request path (no query).
    pub path: String,
    /// The parsed `Value=` query of a PATCH /set.
    pub set_value: Option<f64>,
}

#[derive(Default)]
pub struct SimState {
    /// ObjectClass served at `CurrentFormation/{i}.ObjectClass`.
    pub object_class: Option<String>,
    /// DrivableIndex result; None fails with 500 (fallback-to-0 path).
    pub drivable_index: Option<i64>,
    pub object_class_fails: bool,
    /// Per-endpoint set behavior; missing entry means Ok.
    pub set_behavior: HashMap<String, SetBehavior>,
    /// Gates: endpoint → (entered notification, proceed channel).
    pub gates: HashMap<String, (std_mpsc::Sender<()>, Arc<Mutex<Option<std_mpsc::Receiver<bool>>>>)>,
}

#[derive(Clone)]
pub enum SetBehavior {
    Ok,
    /// Immediate HTTP failure with the given status.
    Fail(u16),
    /// Block until released: true → Ok, channel dropped → 500.
    Gate(GateHandle),
}

#[derive(Clone)]
pub struct GateHandle {
    pub entered: Arc<Mutex<Option<std_mpsc::Receiver<()>>>>,
    pub proceed: Arc<std_mpsc::Sender<bool>>,
}

impl GateHandle {
    /// Wait until the fake server thread is blocked inside the gated request.
    /// Polls cooperatively so the current-thread runtime keeps driving IO.
    pub async fn await_entered(&self) {
        let entered = self.entered.lock().unwrap().take();
        let Some(entered) = entered else {
            panic!("gate already consumed or never armed");
        };
        for _ in 0..DRIVE_LIMIT {
            if entered.try_recv().is_ok() {
                return;
            }
            tokio::time::sleep(Duration::from_millis(1)).await;
        }
        panic!("gated request never entered");
    }

    /// Release with success.
    pub fn release(&self) {
        let _ = self.proceed.send(true);
    }

    /// Release with an HTTP 500 (simulates a failed/dropped write).
    pub fn fail(&self) {
        let _ = self.proceed.send(false);
    }
}

#[derive(Clone, Default)]
pub struct ScriptedSim {
    pub state: Arc<Mutex<SimState>>,
    pub requests: Arc<Mutex<Vec<RequestLog>>>,
    pub base_url: Arc<Mutex<Option<String>>>,
}

impl ScriptedSim {
    pub fn spawn() -> Self {
        let state = Arc::new(Mutex::new(SimState::default()));
        let requests: Arc<Mutex<Vec<RequestLog>>> = Arc::new(Mutex::new(Vec::new()));
        let base_url = Arc::new(Mutex::new(None));
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        *base_url.lock().unwrap() = Some(format!("http://{}", listener.local_addr().unwrap()));
        {
            let state = state.clone();
            let requests = requests.clone();
            thread::spawn(move || {
                for stream in listener.incoming().flatten() {
                    let state = state.clone();
                    let requests = requests.clone();
                    thread::spawn(move || handle_connection(stream, state, requests));
                }
            });
        }
        Self {
            state,
            requests,
            base_url,
        }
    }

    pub fn url(&self) -> String {
        self.base_url.lock().unwrap().clone().unwrap()
    }

    pub fn log(&self) -> Vec<RequestLog> {
        self.requests.lock().unwrap().clone()
    }

    pub fn set_paths(&self) -> Vec<String> {
        self.requests
            .lock()
            .unwrap()
            .iter()
            .filter(|request| request.method == "PATCH")
            .map(|request| request.path.clone())
            .collect()
    }

    pub fn set_values(&self) -> Vec<(String, f64)> {
        self.requests
            .lock()
            .unwrap()
            .iter()
            .filter_map(|request| {
                (request.method == "PATCH")
                    .then(|| request.set_value.map(|value| (request.path.clone(), value)))
                    .flatten()
            })
            .collect()
    }

    /// Arm an endpoint to block the next set; `release`/`fail` unblock it.
    pub fn gate(&self, endpoint: &str) -> GateHandle {
        let (entered_tx, entered_rx) = std_mpsc::channel();
        let (proceed_tx, proceed_rx) = std_mpsc::channel();
        let handle = GateHandle {
            entered: Arc::new(Mutex::new(Some(entered_rx))),
            proceed: Arc::new(proceed_tx),
        };
        self.state
            .lock()
            .unwrap()
            .set_behavior
            .insert(endpoint.to_owned(), SetBehavior::Gate(handle.clone()));
        self.state
            .lock()
            .unwrap()
            .gates
            .insert(endpoint.to_owned(), (entered_tx, Arc::new(Mutex::new(Some(proceed_rx)))));
        handle
    }

    /// Arm an endpoint to fail with the given HTTP status.
    pub fn fail_set(&self, endpoint: &str, status: u16) {
        self.state
            .lock()
            .unwrap()
            .set_behavior
            .insert(endpoint.to_owned(), SetBehavior::Fail(status));
    }
}

fn percent_decode(raw: &str) -> String {
    let bytes = raw.as_bytes();
    let mut out = String::new();
    let mut index = 0;
    while index < bytes.len() {
        if bytes[index] == b'%' && index + 2 < bytes.len() {
            let hex = &raw[index + 1..index + 3];
            if let Ok(value) = u8::from_str_radix(hex, 16) {
                out.push(value as char);
                index += 3;
                continue;
            }
        }
        out.push(bytes[index] as char);
        index += 1;
    }
    out
}

fn handle_connection(
    stream: TcpStream,
    state: Arc<Mutex<SimState>>,
    requests: Arc<Mutex<Vec<RequestLog>>>,
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
    let target = parts.next().unwrap_or_default().to_owned();
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

    let (path, query) = target.split_once('?').unwrap_or((target.as_str(), ""));
    let path = percent_decode(path);
    let set_value = if method == "PATCH" {
        query
            .split('&')
            .find_map(|pair| pair.split_once('='))
            .and_then(|(name, value)| (name == "Value").then(|| value.parse::<f64>().ok()).flatten())
    } else {
        None
    };
    // Log the endpoint form (operation prefix stripped) for readable
    // assertions; `respond` still sees the full path.
    let logged = path
        .trim_start_matches("/set/")
        .trim_start_matches("/get/")
        .to_owned();
    requests.lock().unwrap().push(RequestLog {
        method: method.clone(),
        path: logged,
        set_value,
    });

    let (status, response_body) = respond(&method, &path, set_value, &state);
    let reason = if status == 200 { "OK" } else { "Internal Server Error" };
    let response = format!(
        "HTTP/1.1 {status} {reason}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{response_body}",
        response_body.len()
    );
    let _ = writer.write_all(response.as_bytes());
    let _ = writer.flush();
}

fn respond(
    method: &str,
    path: &str,
    _set_value: Option<f64>,
    state: &Arc<Mutex<SimState>>,
) -> (u16, String) {
    if method == "GET" && path == "/get/CurrentFormation.DrivableIndex" {
        let drivable_index = state.lock().unwrap().drivable_index;
        return match drivable_index {
            Some(index) => (
                200,
                format!(r#"{{"Result":"Success","Values":{{"ReturnValue":{index}}}}}"#),
            ),
            None => (500, r#"{"error":"no drivable index"}"#.to_owned()),
        };
    }
    if method == "GET" && path.starts_with("/get/CurrentFormation/") && path.ends_with(".ObjectClass") {
        let state = state.lock().unwrap();
        if state.object_class_fails {
            return (500, r#"{"error":"gone"}"#.to_owned());
        }
        return match &state.object_class {
            Some(object_class) => (
                200,
                format!(r#"{{"Result":"Success","Values":{{"ReturnValue":"{object_class}"}}}}"#),
            ),
            None => (500, r#"{"error":"no formation"}"#.to_owned()),
        };
    }
    if method == "PATCH" && path.starts_with("/set/") {
        let endpoint = path.trim_start_matches("/set/").to_owned();
        let behavior = state
            .lock()
            .unwrap()
            .set_behavior
            .get(&endpoint)
            .cloned();
        return match behavior {
            None | Some(SetBehavior::Ok) => (200, r#"{"Result":"Success"}"#.to_owned()),
            Some(SetBehavior::Fail(status)) => (status, r#"{"error":"set failed"}"#.to_owned()),
            Some(SetBehavior::Gate(_)) => {
                // Signal entry, then block until released.
                let entered_gate = {
                    let state = state.lock().unwrap();
                    state.gates.get(&endpoint).map(|gate| gate.clone())
                };
                if let Some((entered_tx, _)) = entered_gate {
                    let _ = entered_tx.send(());
                }
                let proceed_rx = {
                    let mut state = state.lock().unwrap();
                    // Gates are one-shot: later requests on the same endpoint
                    // fall through to the default Ok behavior.
                    state.set_behavior.remove(&endpoint);
                    state
                        .gates
                        .get(&endpoint)
                        .and_then(|(_, rx)| rx.lock().unwrap().take())
                };
                let Some(proceed_rx) = proceed_rx else {
                    return (500, r#"{"error":"gate consumed"}"#.to_owned());
                };
                match proceed_rx.recv() {
                    Ok(true) => (200, r#"{"Result":"Success"}"#.to_owned()),
                    _ => (500, r#"{"error":"gate released as failure"}"#.to_owned()),
                }
            }
        };
    }
    (404, r#"{"error":"not found"}"#.to_owned())
}

// ---------------------------------------------------------------------------
// Fake keystroke port
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct KeystrokeCall {
    pub action: &'static str,
    pub owner: KeystrokeOwner,
    pub binding: Option<EntityId>,
    pub combo: Option<String>,
}

#[derive(Default)]
pub struct FakeKeystrokes {
    pub calls: Mutex<Vec<KeystrokeCall>>,
    pub failures: Mutex<VecDeque<(&'static str, String)>>,
}

impl FakeKeystrokes {
    pub fn fail_next(&self, action: &'static str, error: &str) {
        self.failures.lock().unwrap().push_back((action, error.to_owned()));
    }

    pub fn calls(&self) -> Vec<KeystrokeCall> {
        self.calls.lock().unwrap().clone()
    }

    fn fail(&self, action: &'static str) -> Result<(), String> {
        let mut failures = self.failures.lock().unwrap();
        if let Some(index) = failures.iter().position(|(queued, _)| *queued == action) {
            return Err(failures.remove(index).expect("failure slot exists").1);
        }
        Ok(())
    }
}

impl ButtonKeystrokes for FakeKeystrokes {
    fn press(&self, owner: KeystrokeOwner, binding: EntityId, combo: &str) -> Result<(), String> {
        self.calls.lock().unwrap().push(KeystrokeCall {
            action: "press",
            owner,
            binding: Some(binding),
            combo: Some(combo.to_owned()),
        });
        self.fail("press")
    }

    fn release(&self, owner: KeystrokeOwner, binding: EntityId) -> Result<(), String> {
        self.calls.lock().unwrap().push(KeystrokeCall {
            action: "release",
            owner,
            binding: Some(binding),
            combo: None,
        });
        self.fail("release")
    }

    fn owner_gone(&self, owner: KeystrokeOwner) {
        self.calls.lock().unwrap().push(KeystrokeCall {
            action: "owner_gone",
            owner,
            binding: None,
            combo: None,
        });
    }
}

// ---------------------------------------------------------------------------
// Fake train configuration source
// ---------------------------------------------------------------------------

#[derive(Default)]
pub struct FakeConfigSource {
    pub profiles: Vec<TrainProfile>,
    pub snapshots: HashMap<EntityId, TrainConfigSnapshot>,
    /// Simulated committed DB revision (topic sum), bumped per fake CRUD.
    pub revision: u64,
}

pub struct FakeConfig(Arc<Mutex<FakeConfigSource>>);

impl FakeConfig {
    pub fn new() -> Self {
        Self(Arc::new(Mutex::new(FakeConfigSource::default())))
    }

    pub fn source(&self) -> Arc<dyn TrainConfigSource> {
        Arc::new(FakeConfig(self.0.clone()))
    }

    /// Commit a train profile + snapshot (the fake CRUD); bumps the revision.
    pub fn commit(&self, profile: TrainProfile, snapshot: Option<TrainConfigSnapshot>) {
        let mut inner = self.0.lock().unwrap();
        inner.revision += 1;
        inner.profiles.retain(|existing| existing.id != profile.id);
        if let Some(snapshot) = snapshot {
            inner.snapshots.insert(EntityId(profile.id), snapshot);
        }
        inner.profiles.push(profile);
    }

    pub fn revision(&self) -> u64 {
        self.0.lock().unwrap().revision
    }
}

impl Default for FakeConfig {
    fn default() -> Self {
        Self::new()
    }
}

impl TrainConfigSource for FakeConfig {
    fn profiles(&self) -> Vec<TrainProfile> {
        self.0.lock().unwrap().profiles.clone()
    }

    fn snapshot(&self, train_id: EntityId) -> Result<TrainConfigSnapshot, TrainConfigError> {
        let inner = self.0.lock().unwrap();
        let mut snapshot = inner
            .snapshots
            .get(&train_id)
            .cloned()
            .ok_or(TrainConfigError::NotFound(train_id))?;
        snapshot.revision = trenino_core::Revision(inner.revision);
        Ok(snapshot)
    }
}
