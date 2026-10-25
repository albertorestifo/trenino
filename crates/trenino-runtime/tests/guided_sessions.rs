use serde_json::json;
use std::{
    io::{BufRead, BufReader, Read, Write},
    net::{TcpListener, TcpStream},
    sync::{
        atomic::{AtomicBool, AtomicUsize, Ordering},
        Arc, Mutex,
    },
    thread,
    time::Duration,
};
use tokio::sync::watch;
use trenino_core::train::buttons::SequenceCommand;
use trenino_runtime::{
    composition::sessions::{SessionState, SimulatorSessionHost},
    simulator::{
        client::SimulatorClient,
        connection::SimulatorStatus,
        connection_owner::StatusSnapshot,
        services::{
            calibration::LeverEndpointSet,
            clock::{FakeClock, SystemClock},
            explorer,
        },
    },
};

struct FakeSim {
    url: String,
    requests: Arc<Mutex<Vec<String>>>,
    value: Arc<Mutex<f64>>,
    fail_unsubscribe: Arc<AtomicBool>,
    fail_set: Arc<AtomicBool>,
    hold_unsubscribe: Arc<AtomicBool>,
    hold_set: Arc<AtomicBool>,
    failed_unsubscribe_responses: Arc<AtomicUsize>,
}
impl FakeSim {
    fn start() -> Self {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let url = format!("http://{}", listener.local_addr().unwrap());
        let requests = Arc::new(Mutex::new(Vec::new()));
        let value = Arc::new(Mutex::new(0.0));
        let fail_unsubscribe = Arc::new(AtomicBool::new(false));
        let fail_set = Arc::new(AtomicBool::new(false));
        let hold_unsubscribe = Arc::new(AtomicBool::new(false));
        let hold_set = Arc::new(AtomicBool::new(false));
        let failed_unsubscribe_responses = Arc::new(AtomicUsize::new(0));
        let recorded = requests.clone();
        let current = value.clone();
        let fail = fail_unsubscribe.clone();
        let fail_write = fail_set.clone();
        let hold = hold_unsubscribe.clone();
        let hold_write = hold_set.clone();
        let failed_deletes = failed_unsubscribe_responses.clone();
        thread::spawn(move || {
            for stream in listener.incoming().flatten() {
                let recorded = recorded.clone();
                let current = current.clone();
                let fail = fail.clone();
                let fail_write = fail_write.clone();
                let hold = hold.clone();
                let hold_write = hold_write.clone();
                let failed_deletes = failed_deletes.clone();
                thread::spawn(move || {
                    serve(
                        stream,
                        recorded,
                        current,
                        fail,
                        fail_write,
                        hold,
                        hold_write,
                        failed_deletes,
                    )
                });
            }
        });
        Self {
            url,
            requests,
            value,
            fail_unsubscribe,
            fail_set,
            hold_unsubscribe,
            hold_set,
            failed_unsubscribe_responses,
        }
    }
    fn client(&self) -> Arc<SimulatorClient> {
        Arc::new(SimulatorClient::new(&self.url, "key").unwrap())
    }
}
// Independent failure/hold gates keep loopback races deterministic.
#[allow(clippy::too_many_arguments)]
fn serve(
    stream: TcpStream,
    requests: Arc<Mutex<Vec<String>>>,
    value: Arc<Mutex<f64>>,
    fail_unsubscribe: Arc<AtomicBool>,
    fail_set: Arc<AtomicBool>,
    hold_unsubscribe: Arc<AtomicBool>,
    hold_set: Arc<AtomicBool>,
    failed_unsubscribe_responses: Arc<AtomicUsize>,
) {
    let mut reader = BufReader::new(stream.try_clone().unwrap());
    let mut line = String::new();
    if reader.read_line(&mut line).is_err() {
        return;
    }
    let mut parts = line.split_whitespace();
    let method = parts.next().unwrap_or("").to_owned();
    let path = parts.next().unwrap_or("").to_owned();
    let mut length = 0usize;
    loop {
        line.clear();
        if reader.read_line(&mut line).ok().unwrap_or(0) == 0 || line == "\r\n" {
            break;
        }
        if let Some(n) = line.to_ascii_lowercase().strip_prefix("content-length:") {
            length = n.trim().parse().unwrap_or(0);
        }
    }
    let mut body = vec![0; length];
    let _ = reader.read_exact(&mut body);
    let clean = path.split('?').next().unwrap_or(&path);
    let response = match (method.as_str(), clean) {
        ("GET", "/list/CurrentDrivableActor") => {
            json!({"Result":"Success","Nodes":[{"NodeName":"Throttle"},{"NodeName":"Brake"}]})
        }
        ("GET", "/list/CurrentDrivableActor/Throttle") => {
            json!({"Result":"Success","Endpoints":[{"Name":"InputValue","Writable":true},{"Name":"Function.GetNotchCount","Writable":false}]})
        }
        ("GET", "/list/CurrentDrivableActor/Brake") => {
            json!({"Result":"Success","Endpoints":[{"Name":"InputValue","Writable":true}]})
        }
        ("GET", "/subscription") => {
            let v = *value.lock().unwrap();
            json!({"Result":"Success","Entries":[{"Path":"CurrentDrivableActor/Throttle.InputValue","Values":{"InputValue":v}},{"Path":"CurrentDrivableActor/Brake.InputValue","Values":{"InputValue":v}}]})
        }
        ("GET", "/get/Throttle.Function.GetMinimumInputValue") => {
            json!({"Result":"Success","Values":{"ReturnValue":0.0}})
        }
        ("GET", "/get/Throttle.Function.GetMaximumInputValue") => {
            json!({"Result":"Success","Values":{"ReturnValue":0.2}})
        }
        ("GET", "/get/Throttle.Function.GetNotchCount") => {
            json!({"Result":"Success","Values":{"ReturnValue":1}})
        }
        ("GET", "/get/Throttle.InputValue") => {
            json!({"Result":"Success","Values":{"InputValue":*value.lock().unwrap()}})
        }
        ("GET", "/get/Throttle.Function.GetCurrentOutputValue") => {
            json!({"Result":"Success","Values":{"ReturnValue":*value.lock().unwrap()}})
        }
        ("GET", "/get/Throttle.Function.GetCurrentNotchIndex") => {
            json!({"Result":"Success","Values":{"ReturnValue":0}})
        }
        ("PATCH", "/set/Throttle.InputValue") => {
            let v = path
                .split("Value=")
                .nth(1)
                .and_then(|v| v.parse::<f64>().ok())
                .unwrap_or(0.0);
            *value.lock().unwrap() = v;
            json!({"Result":"Success"})
        }
        _ => json!({"Result":"Success"}),
    };
    requests.lock().unwrap().push(format!("{method} {path}"));
    if method == "DELETE" && clean == "/subscription" {
        while hold_unsubscribe.load(Ordering::SeqCst) {
            thread::sleep(Duration::from_millis(1));
        }
    }
    if method == "PATCH" && clean.starts_with("/set/") {
        while hold_set.load(Ordering::SeqCst) {
            thread::sleep(Duration::from_millis(1));
        }
    }
    let status = if (method == "DELETE"
        && clean == "/subscription"
        && fail_unsubscribe.load(Ordering::SeqCst))
        || (method == "PATCH" && clean.starts_with("/set/") && fail_set.load(Ordering::SeqCst))
    {
        500
    } else {
        200
    };
    if method == "DELETE" && clean == "/subscription" && status == 500 {
        failed_unsubscribe_responses.fetch_add(1, Ordering::SeqCst);
    }
    let bytes = serde_json::to_vec(&response).unwrap();
    let mut stream = stream;
    let _=write!(stream,"HTTP/1.1 {status} OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n",bytes.len());
    let _ = stream.write_all(&bytes);
}
fn accepted(client: Option<Arc<SimulatorClient>>) -> StatusSnapshot {
    StatusSnapshot {
        status: if client.is_some() {
            SimulatorStatus::Connected
        } else {
            SimulatorStatus::Disconnected
        },
        last_error: None,
        info: None,
        health_failures: 0,
        client,
    }
}

#[tokio::test]
async fn control_detection_works_without_hardware_and_retains_ambiguous_result() {
    let sim = FakeSim::start();
    let (_tx, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(SystemClock));
    let id = host.start_control_detection().await.unwrap();
    tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            if sim
                .requests
                .lock()
                .unwrap()
                .iter()
                .any(|p| p.starts_with("GET /subscription"))
            {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    *sim.value.lock().unwrap() = 0.5;
    let result = tokio::time::timeout(Duration::from_secs(3), async {
        loop {
            let s = host.status(id).await.unwrap();
            if s.state == SessionState::Detected {
                break s;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    assert!(result.ambiguous);
    assert_eq!(result.changes.len(), 2);
    assert_eq!(host.status(id).await.unwrap().state, SessionState::Detected);
    assert!(sim
        .requests
        .lock()
        .unwrap()
        .iter()
        .any(|p| p.starts_with("DELETE /subscription")));
    host.shutdown().await.unwrap();
}

#[tokio::test]
async fn detection_timeout_is_terminal_and_unsubscribes() {
    let sim = FakeSim::start();
    let clock = FakeClock::new();
    let (_tx, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(clock.clone()));
    let id = host.start_control_detection().await.unwrap();
    tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            if !clock.pending_deadlines().is_empty() {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    assert!(host.status(id).await.unwrap().remaining_ms.unwrap() > 0);
    clock.advance(Duration::from_secs(30));
    tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            if host.status(id).await.unwrap().state == SessionState::TimedOut {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    assert!(sim
        .requests
        .lock()
        .unwrap()
        .iter()
        .any(|p| p.starts_with("DELETE /subscription")));
    host.shutdown().await.unwrap();
}

#[tokio::test]
async fn failed_unsubscribe_is_not_acknowledged_and_cancel_can_retry() {
    let sim = FakeSim::start();
    let (_tx, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(SystemClock));
    let id = host.start_control_detection().await.unwrap();
    tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            if sim
                .requests
                .lock()
                .unwrap()
                .iter()
                .any(|p| p.starts_with("GET /subscription"))
            {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    sim.fail_unsubscribe.store(true, Ordering::SeqCst);
    assert!(host.cancel(id).await.is_err());
    let pending = host.status(id).await.unwrap();
    assert_eq!(pending.state, SessionState::Failed);
    assert_eq!(
        serde_json::to_value(&pending).unwrap()["cleanup_pending"],
        true,
        "a failed cleanup retains the active session slot"
    );
    assert!(host.start_control_detection().await.is_err());
    sim.fail_unsubscribe.store(false, Ordering::SeqCst);
    assert!(host.cancel(id).await.unwrap());
    let cleaned = host.status(id).await.unwrap();
    assert_eq!(cleaned.state, SessionState::Cancelled);
    assert_eq!(
        serde_json::to_value(&cleaned).unwrap()["cleanup_pending"],
        false
    );
    host.shutdown().await.unwrap();
}

#[tokio::test]
async fn failed_unsubscribe_retries_after_ui_caller_leaves() {
    let sim = FakeSim::start();
    let (_owner, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(SystemClock));
    let id = host.start_control_detection().await.unwrap();
    tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            if sim
                .requests
                .lock()
                .unwrap()
                .iter()
                .any(|p| p.starts_with("GET /subscription"))
            {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    sim.fail_unsubscribe.store(true, Ordering::SeqCst);
    assert!(host.cancel(id).await.is_err());
    let failed = host.status(id).await.unwrap();
    assert_eq!(failed.state, SessionState::Failed);
    assert!(failed.cleanup_pending);

    // Route unmount drops its session ID; no further UI cancel request arrives.
    tokio::time::sleep(Duration::from_millis(1200)).await;
    assert!(
        sim.failed_unsubscribe_responses.load(Ordering::SeqCst) <= 3,
        "retry must be timed, not a hot loop"
    );
    sim.fail_unsubscribe.store(false, Ordering::SeqCst);
    tokio::time::timeout(Duration::from_secs(3), async {
        loop {
            let snapshot = host.status(id).await.unwrap();
            if !snapshot.cleanup_pending {
                assert_eq!(snapshot.state, SessionState::Cancelled);
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .expect("host must release the failed cleanup owner without another caller");
    let next = host.start_control_detection().await.unwrap();
    host.cancel(next).await.unwrap();
    host.shutdown().await.unwrap();
}

#[tokio::test]
async fn healthy_detection_is_not_cancelled_by_cleanup_retry_timer() {
    let sim = FakeSim::start();
    let (_owner, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(SystemClock));
    let id = host.start_control_detection().await.unwrap();
    tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            if sim
                .requests
                .lock()
                .unwrap()
                .iter()
                .any(|p| p.starts_with("GET /subscription"))
            {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    let cleanup_before = sim
        .requests
        .lock()
        .unwrap()
        .iter()
        .filter(|p| p.starts_with("DELETE /subscription"))
        .count();
    tokio::time::sleep(Duration::from_millis(1200)).await;
    let current = host.status(id).await.unwrap();
    assert_eq!(current.state, SessionState::Listening);
    assert!(!current.cleanup_pending);
    assert_eq!(
        sim.requests
            .lock()
            .unwrap()
            .iter()
            .filter(|p| p.starts_with("DELETE /subscription"))
            .count(),
        cleanup_before
    );
    host.cancel(id).await.unwrap();
    host.shutdown().await.unwrap();
}

#[tokio::test]
async fn completed_detection_retains_cleanup_owner_until_unsubscribe_retry() {
    let sim = FakeSim::start();
    let clock = FakeClock::new();
    let (_tx, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(clock.clone()));
    let id = host.start_control_detection().await.unwrap();
    tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            if !clock.pending_deadlines().is_empty() {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    sim.fail_unsubscribe.store(true, Ordering::SeqCst);
    clock.advance(Duration::from_secs(30));
    let pending = tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            let snapshot = host.status(id).await.unwrap();
            if snapshot.state == SessionState::Failed {
                break snapshot;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    assert!(pending.cleanup_pending);
    assert_eq!(
        serde_json::to_value(&pending).unwrap()["cleanup_pending"],
        true
    );
    sim.fail_unsubscribe.store(false, Ordering::SeqCst);
    assert!(host.cancel(id).await.unwrap());
    assert!(!host.status(id).await.unwrap().cleanup_pending);
    host.shutdown().await.unwrap();
}

#[tokio::test]
async fn analysis_reports_progress_and_draft_result() {
    let sim = FakeSim::start();
    let (_tx, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(SystemClock));
    let id = host
        .start_lever_analysis("Throttle".into(), None)
        .await
        .unwrap();
    let result = tokio::time::timeout(Duration::from_secs(5), async {
        loop {
            let s = host.status(id).await.unwrap();
            if s.state == SessionState::Complete {
                break s;
            }
            if s.state == SessionState::Failed {
                panic!("analysis failed: {:?}", s.message);
            }
            tokio::time::sleep(Duration::from_millis(20)).await;
        }
    })
    .await
    .unwrap();
    assert!(result.analysis_progress.is_some());
    assert!(result.analysis.unwrap().samples.len() >= 10);
    host.shutdown().await.unwrap();
}

#[tokio::test]
async fn calibration_returns_draft_notches_without_a_store() {
    let sim = FakeSim::start();
    let (_tx, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(SystemClock));
    let id = host
        .start_lever_calibration(LeverEndpointSet {
            lever_config_id: 0,
            min_endpoint: "Throttle.Function.GetMinimumInputValue".into(),
            max_endpoint: "Throttle.Function.GetMaximumInputValue".into(),
            value_endpoint: "Throttle.InputValue".into(),
            notch_count_endpoint: "Throttle.Function.GetNotchCount".into(),
            notch_index_endpoint: "Throttle.Function.GetCurrentNotchIndex".into(),
        })
        .await
        .unwrap();
    let result = tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            let s = host.status(id).await.unwrap();
            if s.state == SessionState::Complete {
                break s;
            }
            if s.state == SessionState::Failed {
                panic!("calibration failed: {:?}", s.message);
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    assert_eq!(result.calibration.unwrap().notches.len(), 1);
    assert!(result.progress.is_some());
    host.shutdown().await.unwrap();
}

#[tokio::test]
async fn shutdown_cancels_pending_sweep_and_prevents_late_writes() {
    let sim = FakeSim::start();
    let (_tx, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(SystemClock));
    let id = host
        .start_lever_analysis("Throttle".into(), None)
        .await
        .unwrap();
    host.shutdown().await.unwrap();
    let before = sim
        .requests
        .lock()
        .unwrap()
        .iter()
        .filter(|p| p.starts_with("PATCH /set/"))
        .count();
    tokio::time::sleep(Duration::from_millis(250)).await;
    assert_eq!(
        sim.requests
            .lock()
            .unwrap()
            .iter()
            .filter(|p| p.starts_with("PATCH /set/"))
            .count(),
        before
    );
    assert!(host.start_control_detection().await.is_err());
    assert!(host.status(id).await.is_err());
}

fn sequence(endpoint: &str, value: f64, delay_ms: u64, position: u32) -> SequenceCommand {
    SequenceCommand {
        endpoint: endpoint.into(),
        value,
        delay_ms,
        position,
    }
}

#[tokio::test]
async fn manual_sequence_acknowledges_only_successful_ordered_writes() {
    let sim = FakeSim::start();
    let (_tx, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(SystemClock));
    assert!(host
        .run_manual_sequence(vec![
            sequence("Throttle.InputValue", 0.2, 0, 2),
            sequence("Throttle.InputValue", 0.1, 0, 1)
        ])
        .await
        .unwrap());
    let writes = sim
        .requests
        .lock()
        .unwrap()
        .iter()
        .filter(|p| p.starts_with("PATCH /set/"))
        .cloned()
        .collect::<Vec<_>>();
    assert_eq!(writes.len(), 2);
    assert!(writes[0].contains("Value=0.1"));
    assert!(writes[1].contains("Value=0.2"));
    sim.fail_set.store(true, Ordering::SeqCst);
    assert!(host
        .run_manual_sequence(vec![
            sequence("Throttle.InputValue", 0.3, 0, 1),
            sequence("Throttle.InputValue", 0.4, 0, 2)
        ])
        .await
        .is_err());
    let writes = sim
        .requests
        .lock()
        .unwrap()
        .iter()
        .filter(|p| p.starts_with("PATCH /set/"))
        .count();
    assert_eq!(writes, 3, "second command must not follow a failed send");
    let failed = host.status(2).await.unwrap();
    assert_eq!(failed.state, SessionState::Failed);
    assert_eq!(
        serde_json::to_value(&failed).unwrap()["cleanup_pending"],
        false,
        "a terminal command failure no longer owns cleanup"
    );
    host.shutdown().await.unwrap();
}

#[tokio::test]
async fn manual_sequence_delay_is_cancelled_on_connection_replacement() {
    let sim = FakeSim::start();
    let (tx, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(SystemClock));
    let running = tokio::spawn({
        let host = host.clone();
        async move {
            host.run_manual_sequence(vec![
                sequence("Throttle.InputValue", 0.1, 5_000, 1),
                sequence("Throttle.InputValue", 0.2, 0, 2),
            ])
            .await
        }
    });
    tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            if sim
                .requests
                .lock()
                .unwrap()
                .iter()
                .any(|p| p.starts_with("PATCH /set/"))
            {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    tx.send(accepted(None)).unwrap();
    assert!(tokio::time::timeout(Duration::from_secs(2), running)
        .await
        .unwrap()
        .unwrap()
        .is_err());
    assert_eq!(
        sim.requests
            .lock()
            .unwrap()
            .iter()
            .filter(|p| p.starts_with("PATCH /set/"))
            .count(),
        1
    );
    host.shutdown().await.unwrap();
}

#[tokio::test]
async fn persisted_sixty_second_sequence_delay_remains_valid() {
    let sim = FakeSim::start();
    let clock = FakeClock::new();
    let (_tx, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(clock.clone()));
    let running = tokio::spawn({
        let host = host.clone();
        async move {
            host.run_manual_sequence(vec![
                sequence("Throttle.InputValue", 0.1, 60_000, 1),
                sequence("Throttle.InputValue", 0.2, 0, 2),
            ])
            .await
        }
    });
    tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            if !clock.pending_deadlines().is_empty() {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    clock.advance(Duration::from_secs(60));
    assert!(tokio::time::timeout(Duration::from_secs(2), running)
        .await
        .unwrap()
        .unwrap()
        .unwrap());
    assert_eq!(
        sim.requests
            .lock()
            .unwrap()
            .iter()
            .filter(|p| p.starts_with("PATCH /set/"))
            .count(),
        2
    );
    host.shutdown().await.unwrap();
}

#[tokio::test]
async fn selected_lever_resolves_all_five_simulator_endpoints() {
    let sim = FakeSim::start();
    let resolved =
        explorer::resolve_lever_endpoints(&sim.client(), "CurrentDrivableActor/Throttle")
            .await
            .unwrap()
            .unwrap();
    assert_eq!(
        resolved.value_endpoint,
        "CurrentDrivableActor/Throttle.InputValue"
    );
    assert_eq!(
        resolved.notch_count_endpoint,
        "CurrentDrivableActor/Throttle.Function.GetNotchCount"
    );
    assert_eq!(
        resolved.notch_index_endpoint,
        "CurrentDrivableActor/Throttle.Function.GetCurrentNotchIndex"
    );
    assert!(
        explorer::resolve_lever_endpoints(&sim.client(), "CurrentDrivableActor/Brake")
            .await
            .unwrap()
            .is_none()
    );
}

#[tokio::test]
async fn replacement_cancels_inflight_sweep_and_old_results_cannot_complete() {
    let sim = FakeSim::start();
    let (tx, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(SystemClock));
    let id = host
        .start_lever_analysis("Throttle".into(), None)
        .await
        .unwrap();
    tx.send(accepted(None)).unwrap();
    tokio::time::timeout(Duration::from_secs(3), async {
        loop {
            let s = host.status(id).await.unwrap();
            if s.state == SessionState::Cancelled {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    assert!(host.start_control_detection().await.is_err());
    host.shutdown().await.unwrap();
}

#[tokio::test]
async fn owner_watch_drop_cancels_worker_and_keeps_status_shutdown_responsive() {
    let sim = FakeSim::start();
    let (owner, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(SystemClock));
    let id = host.start_control_detection().await.unwrap();
    tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            if sim
                .requests
                .lock()
                .unwrap()
                .iter()
                .any(|p| p.starts_with("GET /subscription"))
            {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    drop(owner);
    let ended = tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            let snapshot = host.status(id).await.unwrap();
            if snapshot.state == SessionState::Cancelled {
                break snapshot;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .expect("owner death must not starve status commands");
    assert_eq!(ended.state, SessionState::Cancelled);
    assert!(sim
        .requests
        .lock()
        .unwrap()
        .iter()
        .any(|p| p.starts_with("DELETE /subscription")));
    tokio::time::timeout(Duration::from_secs(2), host.shutdown())
        .await
        .expect("owner death must not starve shutdown")
        .unwrap();
}

#[tokio::test]
async fn abandoned_queued_start_never_creates_hidden_session() {
    let sim = FakeSim::start();
    let (_owner, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(SystemClock));
    let id = host.start_control_detection().await.unwrap();
    tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            if sim
                .requests
                .lock()
                .unwrap()
                .iter()
                .any(|p| p.starts_with("GET /subscription"))
            {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    let old_deletes = sim
        .requests
        .lock()
        .unwrap()
        .iter()
        .filter(|p| p.starts_with("DELETE /subscription"))
        .count();
    sim.hold_unsubscribe.store(true, Ordering::SeqCst);
    let cancelling = tokio::spawn({
        let host = host.clone();
        async move { host.cancel(id).await }
    });
    tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            if sim
                .requests
                .lock()
                .unwrap()
                .iter()
                .filter(|p| p.starts_with("DELETE /subscription"))
                .count()
                > old_deletes
            {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    let mut abandoned = Box::pin(host.start_control_detection());
    tokio::select! {biased;
        _=&mut abandoned=>panic!("cancel cleanup should still block admission"),
        _=tokio::time::sleep(Duration::from_millis(10))=>{}
    }
    drop(abandoned);
    sim.hold_unsubscribe.store(false, Ordering::SeqCst);
    assert!(tokio::time::timeout(Duration::from_secs(2), cancelling)
        .await
        .unwrap()
        .unwrap()
        .unwrap());
    let next = host
        .start_control_detection()
        .await
        .expect("abandoned request must not occupy the only session slot");
    host.cancel(next).await.unwrap();
    host.shutdown().await.unwrap();
}

#[tokio::test]
async fn abandoned_manual_sequence_cancels_before_later_commands() {
    let sim = FakeSim::start();
    let clock = FakeClock::new();
    let (_owner, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(clock.clone()));
    let running = tokio::spawn({
        let host = host.clone();
        async move {
            host.run_manual_sequence(vec![
                sequence("Throttle.InputValue", 0.1, 60_000, 1),
                sequence("Throttle.InputValue", 0.2, 0, 2),
            ])
            .await
        }
    });
    tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            if !clock.pending_deadlines().is_empty() {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    running.abort();
    let _ = running.await;
    let id = tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            match host.start_control_detection().await {
                Ok(id) => break id,
                Err(trenino_runtime::composition::sessions::SessionError::Busy) => {
                    tokio::time::sleep(Duration::from_millis(10)).await
                }
                Err(error) => panic!("unexpected session error: {error:?}"),
            }
        }
    })
    .await
    .expect("abandoned sequence must release slot");
    clock.advance(Duration::from_secs(60));
    tokio::time::sleep(Duration::from_millis(50)).await;
    assert_eq!(
        sim.requests
            .lock()
            .unwrap()
            .iter()
            .filter(|p| p.starts_with("PATCH /set/"))
            .count(),
        1
    );
    host.cancel(id).await.unwrap();
    host.shutdown().await.unwrap();
}

#[tokio::test]
async fn abandoned_manual_sequence_fences_zero_delay_next_patch() {
    let sim = FakeSim::start();
    let (_owner, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(SystemClock));
    sim.hold_set.store(true, Ordering::SeqCst);
    let running = tokio::spawn({
        let host = host.clone();
        async move {
            host.run_manual_sequence(vec![
                sequence("Throttle.InputValue", 0.1, 0, 1),
                sequence("Throttle.InputValue", 0.2, 0, 2),
            ])
            .await
        }
    });
    tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            if sim
                .requests
                .lock()
                .unwrap()
                .iter()
                .filter(|p| p.starts_with("PATCH /set/"))
                .count()
                == 1
            {
                break;
            }
            tokio::time::sleep(Duration::from_millis(1)).await;
        }
    })
    .await
    .unwrap();
    // The old 50ms poll has just had time to run; release the held response
    // immediately after caller death, before its next poll.
    tokio::time::sleep(Duration::from_millis(55)).await;
    running.abort();
    let _ = running.await;
    sim.hold_set.store(false, Ordering::SeqCst);
    tokio::time::sleep(Duration::from_millis(80)).await;
    assert_eq!(
        sim.requests
            .lock()
            .unwrap()
            .iter()
            .filter(|p| p.starts_with("PATCH /set/"))
            .count(),
        1
    );
    host.shutdown().await.unwrap();
}

#[tokio::test]
async fn last_host_handle_keeps_retrying_failed_detection_unsubscribe() {
    let sim = FakeSim::start();
    let (_owner, status) = watch::channel(accepted(Some(sim.client())));
    let host = SimulatorSessionHost::start(status, Arc::new(SystemClock));
    let _id = host.start_control_detection().await.unwrap();
    tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            if sim
                .requests
                .lock()
                .unwrap()
                .iter()
                .any(|p| p.starts_with("GET /subscription"))
            {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    let deletes_before = sim
        .requests
        .lock()
        .unwrap()
        .iter()
        .filter(|p| p.starts_with("DELETE /subscription"))
        .count();
    sim.fail_unsubscribe.store(true, Ordering::SeqCst);
    drop(host);
    tokio::time::timeout(Duration::from_secs(2), async {
        loop {
            if sim.failed_unsubscribe_responses.load(Ordering::SeqCst) > 0 {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .unwrap();
    sim.fail_unsubscribe.store(false, Ordering::SeqCst);
    tokio::time::timeout(Duration::from_secs(3), async {
        loop {
            if sim
                .requests
                .lock()
                .unwrap()
                .iter()
                .filter(|p| p.starts_with("DELETE /subscription"))
                .count()
                >= deletes_before + 2
            {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
    })
    .await
    .expect("cleanup owner must retry after last handle drops");
    tokio::time::sleep(Duration::from_millis(1200)).await;
    assert_eq!(
        sim.requests
            .lock()
            .unwrap()
            .iter()
            .filter(|p| p.starts_with("DELETE /subscription"))
            .count(),
        deletes_before + 2,
        "successful retry should end background cleanup attempts"
    );
}
