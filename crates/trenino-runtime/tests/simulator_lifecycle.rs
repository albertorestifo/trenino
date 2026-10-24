use serde_json::json;
use std::{
    io::{Read, Write},
    net::TcpListener,
    sync::mpsc,
    thread,
    time::Duration,
};
use trenino_core::simulator::{Endpoint, SimValue};
use trenino_runtime::simulator::client::{SimulatorClient, SimulatorError, TimeoutProfile};
use trenino_runtime::simulator::subscriptions::SubscriptionRegistry;
use trenino_runtime::simulator::writer::{GenerationWriter, SimulatorWrite, WriteAck, WriterError};

fn fake_server(
    status: u16,
    body: &'static str,
    gate: Option<mpsc::Receiver<()>>,
) -> (String, mpsc::Receiver<String>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let address = listener.local_addr().unwrap();
    let (observed_tx, observed_rx) = mpsc::channel();
    thread::spawn(move || {
        if let Ok((mut stream, _)) = listener.accept() {
            let mut request = [0_u8; 8192];
            let size = stream.read(&mut request).unwrap_or(0);
            let request = String::from_utf8_lossy(&request[..size]).to_string();
            let _ = observed_tx.send(request);
            if let Some(gate) = gate {
                let _ = gate.recv_timeout(Duration::from_secs(2));
            }
            let reason = if status == 200 { "OK" } else { "Forbidden" };
            let response = format!("HTTP/1.1 {status} {reason}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}", body.len());
            let _ = stream.write_all(response.as_bytes());
        }
    });
    (format!("http://{address}"), observed_rx)
}

#[tokio::test]
async fn simulator_client_escapes_path_authenticates_and_preserves_response_envelope() {
    let (url, observed) = fake_server(
        200,
        r#"{"Result":"Success","Values":{"Speed":4.567}}"#,
        None,
    );
    let client = SimulatorClient::new(&url, "secret").unwrap();
    let result = client.get("Current/Brake(Lever).InputValue").await.unwrap();
    assert_eq!(result["Result"], "Success");
    let request = observed
        .recv_timeout(Duration::from_secs(2))
        .unwrap()
        .to_ascii_lowercase();
    assert!(request.starts_with("get /get/current/brake%28lever%29.inputvalue "));
    assert!(request.contains("dtgcommkey: secret"));
    let (url, _) = fake_server(403, r#"{"error":"key"}"#, None);
    assert_eq!(
        SimulatorClient::new(&url, "x").unwrap().info().await,
        Err(SimulatorError::InvalidKey)
    );
}

#[tokio::test]
async fn simulator_client_preserves_fast_profile_and_rounds_number_strings() {
    let (url, _) = fake_server(200, r#"{"Values":{"Value":"1.235"}}"#, None);
    let normal = SimulatorClient::new(&url, "key").unwrap();
    let fast = normal.with_fast_timeouts().unwrap();
    assert_eq!(normal.profile(), TimeoutProfile::Normal);
    assert_eq!(fast.profile(), TimeoutProfile::Fast);
    assert_eq!(fast.get_float("Speed").await.unwrap(), 1.24);
}

#[test]
fn subscription_registry_deduplicates_per_lease_and_unsubscribes_only_after_last_owner() {
    let mut registry = SubscriptionRegistry::new(999);
    let first = registry
        .acquire("lever", 3, vec!["A".into(), "A".into()])
        .unwrap();
    let second = registry.acquire("button", 3, vec!["A".into()]).unwrap();
    assert_eq!(first.endpoints["A"], second.endpoints["A"]);
    assert!(registry.release(first).unwrap().is_empty());
    assert_eq!(registry.release(second).unwrap(), vec![1000]);
    assert_eq!(registry.lease_count(), 0);
}

#[tokio::test]
async fn writer_generation_switch_waits_for_old_request_then_fences_queued_old_writes() {
    let (gate_tx, gate_rx) = mpsc::channel();
    let (url, observed) = fake_server(200, r#"{"Result":"Success"}"#, Some(gate_rx));
    let client = SimulatorClient::new(&url, "key").unwrap();
    let writer = GenerationWriter::new(client, 1, 2).unwrap();
    let writer_for_task = writer.clone();
    let task = tokio::spawn(async move {
        writer_for_task
            .write(SimulatorWrite {
                generation: 1,
                command_id: 10,
                endpoint: Endpoint::new("A.InputValue").unwrap(),
                value: SimValue::Number(0.5),
            })
            .await
    });
    tokio::task::spawn_blocking(move || observed.recv_timeout(Duration::from_secs(2)).unwrap())
        .await
        .unwrap();
    let queued_writer = writer.clone();
    let queued = tokio::spawn(async move {
        queued_writer
            .write(SimulatorWrite {
                generation: 1,
                command_id: 11,
                endpoint: Endpoint::new("B.InputValue").unwrap(),
                value: SimValue::Number(1.0),
            })
            .await
    });
    tokio::task::yield_now().await;
    let switch = tokio::spawn({
        let writer = writer.clone();
        async move { writer.advance_generation(2).await }
    });
    tokio::time::sleep(Duration::from_millis(20)).await;
    assert!(!switch.is_finished());
    gate_tx.send(()).unwrap();
    assert_eq!(
        task.await.unwrap().unwrap(),
        WriteAck::Stale { command_id: 10 }
    );
    assert_eq!(
        queued.await.unwrap().unwrap(),
        WriteAck::Stale { command_id: 11 }
    );
    switch.await.unwrap().unwrap();
    assert_eq!(writer.generation(), 2);
    assert!(matches!(
        writer.advance_generation(1).await,
        Err(WriterError::GenerationWentBackwards)
    ));
}

#[tokio::test]
async fn writer_queue_wait_is_bounded_separately_from_http_request_deadline() {
    let (gate_tx, gate_rx) = mpsc::channel();
    let (url, observed) = fake_server(200, r#"{"Result":"Success"}"#, Some(gate_rx));
    let client = SimulatorClient::new(&url, "key").unwrap();
    let writer =
        GenerationWriter::new_with_queue_wait(client, 1, 1, Duration::from_millis(10)).unwrap();
    let inflight_writer = writer.clone();
    let inflight = tokio::spawn(async move {
        inflight_writer
            .write(SimulatorWrite {
                generation: 1,
                command_id: 1,
                endpoint: Endpoint::new("A").unwrap(),
                value: SimValue::Number(1.0),
            })
            .await
    });
    tokio::task::spawn_blocking(move || observed.recv_timeout(Duration::from_secs(2)).unwrap())
        .await
        .unwrap();
    let queued_writer = writer.clone();
    let queued = tokio::spawn(async move {
        queued_writer
            .write(SimulatorWrite {
                generation: 1,
                command_id: 2,
                endpoint: Endpoint::new("B").unwrap(),
                value: SimValue::Number(2.0),
            })
            .await
    });
    tokio::task::yield_now().await;
    let saturated = writer
        .write(SimulatorWrite {
            generation: 1,
            command_id: 3,
            endpoint: Endpoint::new("C").unwrap(),
            value: SimValue::Number(3.0),
        })
        .await;
    assert!(matches!(saturated, Err(WriterError::QueueTimeout)));
    gate_tx.send(()).unwrap();
    let _ = inflight.await.unwrap();
    let _ = queued.await.unwrap();
}

#[tokio::test]
async fn cancelling_write_waiter_does_not_let_old_request_cross_generation_barrier() {
    let (gate_tx, gate_rx) = mpsc::channel();
    let (url, observed) = fake_server(200, r#"{"Result":"Success"}"#, Some(gate_rx));
    let client = SimulatorClient::new(&url, "key").unwrap();
    let writer = GenerationWriter::new(client, 1, 2).unwrap();
    let pending_writer = writer.clone();
    let pending = tokio::spawn(async move {
        pending_writer
            .write(SimulatorWrite {
                generation: 1,
                command_id: 40,
                endpoint: Endpoint::new("Old.Input").unwrap(),
                value: SimValue::Number(1.0),
            })
            .await
    });
    tokio::task::spawn_blocking(move || observed.recv_timeout(Duration::from_secs(2)).unwrap())
        .await
        .unwrap();
    pending.abort();
    let switching_writer = writer.clone();
    let switching = tokio::spawn(async move { switching_writer.advance_generation(2).await });
    tokio::time::sleep(Duration::from_millis(20)).await;
    assert!(!switching.is_finished());
    gate_tx.send(()).unwrap();
    switching.await.unwrap().unwrap();
    assert_eq!(writer.generation(), 2);
}

#[tokio::test]
async fn writer_shutdown_waits_for_owned_worker_and_joins_it() {
    let (gate_tx, gate_rx) = mpsc::channel();
    let (url, observed) = fake_server(200, r#"{"Result":"Success"}"#, Some(gate_rx));
    let writer = GenerationWriter::new(SimulatorClient::new(&url, "key").unwrap(), 1, 2).unwrap();
    let active_writer = writer.clone();
    let active = tokio::spawn(async move {
        active_writer
            .write(SimulatorWrite {
                generation: 1,
                command_id: 41,
                endpoint: Endpoint::new("A.Input").unwrap(),
                value: SimValue::Number(1.0),
            })
            .await
    });
    tokio::task::spawn_blocking(move || observed.recv_timeout(Duration::from_secs(2)).unwrap())
        .await
        .unwrap();
    let shutdown_writer = writer.clone();
    let shutdown = tokio::spawn(async move { shutdown_writer.shutdown().await });
    tokio::time::sleep(Duration::from_millis(20)).await;
    assert!(!shutdown.is_finished());
    gate_tx.send(()).unwrap();
    active.await.unwrap().unwrap();
    shutdown.await.unwrap().unwrap();
    assert!(matches!(
        writer
            .write(SimulatorWrite {
                generation: 1,
                command_id: 42,
                endpoint: Endpoint::new("B.Input").unwrap(),
                value: SimValue::Number(2.0),
            })
            .await,
        Err(WriterError::Closed)
    ));
}
use trenino_runtime::simulator::connection::{ConnectionState, HealthDecision, SimulatorStatus};

#[test]
fn connection_lifecycle_uses_thirty_second_health_and_two_second_transient_retry_before_error() {
    let mut state = ConnectionState::default();
    assert_eq!(state.status, SimulatorStatus::NeedsConfig);
    state.connected(json!({"commands":["info"]}));
    assert_eq!(
        state.after_health_check(Ok(())),
        HealthDecision::CheckAfter(Duration::from_secs(30))
    );
    assert_eq!(
        state.after_health_check(Err(
            trenino_runtime::simulator::connection::ConnectionError::Timeout
        )),
        HealthDecision::CheckAfter(Duration::from_secs(2))
    );
    assert_eq!(state.status, SimulatorStatus::Connected);
    assert_eq!(
        state.after_health_check(Err(
            trenino_runtime::simulator::connection::ConnectionError::Timeout
        )),
        HealthDecision::CheckAfter(Duration::from_secs(2))
    );
    assert_eq!(
        state.after_health_check(Err(
            trenino_runtime::simulator::connection::ConnectionError::Timeout
        )),
        HealthDecision::RetryAfter(Duration::from_secs(30))
    );
    assert_eq!(state.status, SimulatorStatus::Error);
}
fn fake_server_many(count: usize, body: &'static str) -> (String, mpsc::Receiver<String>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let address = listener.local_addr().unwrap();
    let (observed_tx, observed_rx) = mpsc::channel();
    thread::spawn(move || {
        for _ in 0..count {
            if let Ok((mut stream, _)) = listener.accept() {
                let mut request = [0_u8; 8192];
                let size = stream.read(&mut request).unwrap_or(0);
                let _ = observed_tx.send(String::from_utf8_lossy(&request[..size]).to_string());
                let response = format!("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}", body.len());
                let _ = stream.write_all(response.as_bytes());
            }
        }
    });
    (format!("http://{address}"), observed_rx)
}

#[tokio::test]
async fn subscription_service_creates_once_for_shared_endpoint_and_unsubscribes_after_last_lease() {
    use trenino_runtime::simulator::subscriptions::SubscriptionService;
    let (url, observed) = fake_server_many(2, r#"{"Result":"Success"}"#);
    let client = std::sync::Arc::new(SimulatorClient::new(&url, "key").unwrap());
    let service = SubscriptionService::new(client, 999);
    let first = service
        .acquire("lever", 5, vec!["A.B".into()])
        .await
        .unwrap();
    let second = service
        .acquire("display", 5, vec!["A.B".into()])
        .await
        .unwrap();
    assert_eq!(first.endpoints["A.B"], second.endpoints["A.B"]);
    let created = observed
        .recv_timeout(Duration::from_secs(2))
        .unwrap()
        .to_ascii_lowercase();
    assert!(created.starts_with("post /subscription/a.b?subscription=1000 "));
    assert!(service.release(first).await.unwrap().is_empty());
    let removed = service.release(second).await.unwrap();
    assert_eq!(removed, vec![1000]);
    let cleanup = observed
        .recv_timeout(Duration::from_secs(2))
        .unwrap()
        .to_ascii_lowercase();
    assert!(cleanup.starts_with("delete /subscription?subscription=1000 "));
}
use trenino_runtime::keyboard::{key_actions, Key, KeyAction, KeystrokeAction};

#[test]
fn keyboard_parser_preserves_aliases_and_modifier_press_reverse_release_order() {
    let down = key_actions(KeystrokeAction::Down, "CONTROL+shift+F1");
    assert_eq!(
        down,
        vec![
            KeyAction::Press(Key::Control),
            KeyAction::Press(Key::Shift),
            KeyAction::Press(Key::Function(1))
        ]
    );
    let up = key_actions(KeystrokeAction::Up, "CTRL+ALT+S");
    assert_eq!(
        up,
        vec![
            KeyAction::Release(Key::Unicode('s')),
            KeyAction::Release(Key::Alt),
            KeyAction::Release(Key::Control)
        ]
    );
    let tap = key_actions(KeystrokeAction::Tap, "WIN+ARROWLEFT");
    assert_eq!(
        tap,
        vec![
            KeyAction::Press(Key::Meta),
            KeyAction::Click(Key::LeftArrow),
            KeyAction::Release(Key::Meta)
        ]
    );
}
