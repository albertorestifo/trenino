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

#[tokio::test]
async fn simulator_client_uses_elixir_ties_rejects_overflow_and_never_saturates_integers() {
    let (url, _) = scripted_server(vec![
        (200, r#"{"Values":{"V":2.675}}"#, None),
        (200, r#"{"Values":{"V":1e307}}"#, None),
        (200, r#"{"Values":{"V":1e20}}"#, None),
        (200, r#"{"Values":{"V":9223372036854775807}}"#, None),
        (200, r#"{"Values":{"V":9223372036854775808}}"#, None),
    ]);
    let client = SimulatorClient::new(&url, "key").unwrap();
    assert_eq!(client.get_float("A").await.unwrap(), 2.67);
    assert_eq!(client.get_float("A").await.unwrap(), 1e307);
    assert_eq!(
        client.get_int("A").await.unwrap_err(),
        SimulatorError::InvalidValue
    );
    assert_eq!(client.get_int("A").await.unwrap(), i64::MAX);
    assert_eq!(
        client.get_int("A").await.unwrap_err(),
        SimulatorError::InvalidValue
    );
}

#[tokio::test]
async fn simulator_string_reads_preserve_integer_float_and_exponent_lexemes() {
    let (url, _) = scripted_server(vec![
        (200, r#"{"Values":{"V":12}}"#, None),
        (200, r#"{"Values":{"V":12.0}}"#, None),
        (200, r#"{"Values":{"V":1.0e20}}"#, None),
        (200, r#"{"Values":{"V":1.0e-8}}"#, None),
    ]);
    let client = SimulatorClient::with_profile(&url, "key", TimeoutProfile::Fast).unwrap();
    assert_eq!(client.get_string("V").await.unwrap(), "12");
    assert_eq!(client.get_string("V").await.unwrap(), "12.0");
    assert_eq!(client.get_string("V").await.unwrap(), "1.0e20");
    assert_eq!(client.get_string("V").await.unwrap(), "1.0e-8");
}

#[tokio::test]
async fn simulator_client_classifies_non_json_statuses_before_decoding_the_body() {
    let (url, _) = fake_server(403, "invalid key", None);
    assert_eq!(
        SimulatorClient::new(&url, "key").unwrap().info().await,
        Err(SimulatorError::InvalidKey)
    );
    let (url, _) = fake_server(403, "", None);
    assert_eq!(
        SimulatorClient::new(&url, "key").unwrap().info().await,
        Err(SimulatorError::InvalidKey)
    );
    let (url, _) = fake_server(503, "temporarily unavailable", None);
    assert_eq!(
        SimulatorClient::with_profile(&url, "key", TimeoutProfile::Fast)
            .unwrap()
            .info()
            .await,
        Err(SimulatorError::HttpStatus {
            status: 503,
            body: serde_json::Value::String("temporarily unavailable".into())
        })
    );
    let (url, _) = fake_server(500, "", None);
    assert_eq!(
        SimulatorClient::with_profile(&url, "key", TimeoutProfile::Fast)
            .unwrap()
            .info()
            .await,
        Err(SimulatorError::HttpStatus {
            status: 500,
            body: serde_json::Value::String(String::new())
        })
    );
}

#[tokio::test]
async fn normal_safe_reads_retry_transient_statuses_but_fast_reads_do_not() {
    let (url, observed) = scripted_server(vec![
        (503, "busy", None),
        (200, r#"{"Result":"Success"}"#, None),
    ]);
    assert_eq!(
        SimulatorClient::new(&url, "key")
            .unwrap()
            .info()
            .await
            .unwrap()["Result"],
        "Success"
    );
    assert_eq!(
        observed.recv_timeout(Duration::from_secs(1)).unwrap().1,
        503
    );
    assert_eq!(
        observed.recv_timeout(Duration::from_secs(1)).unwrap().1,
        200
    );

    let (url, observed) = scripted_server(vec![(503, "busy", None)]);
    let client = SimulatorClient::with_profile(&url, "key", TimeoutProfile::Fast).unwrap();
    assert!(matches!(
        client.info().await,
        Err(SimulatorError::HttpStatus { status: 503, .. })
    ));
    assert_eq!(
        observed.recv_timeout(Duration::from_secs(1)).unwrap().1,
        503
    );
    assert!(observed.recv_timeout(Duration::from_millis(50)).is_err());
}

#[tokio::test]
async fn normal_safe_reads_stop_after_two_transient_status_retries() {
    let (url, observed) = scripted_server(vec![
        (503, "unavailable", None),
        (503, "still unavailable", None),
        (503, "exhausted", None),
    ]);
    let client = SimulatorClient::new(&url, "key").unwrap();
    assert_eq!(
        client.info().await,
        Err(SimulatorError::HttpStatus {
            status: 503,
            body: serde_json::Value::String("exhausted".into()),
        })
    );
    for _ in 0..3 {
        observed.recv_timeout(Duration::from_secs(2)).unwrap();
    }
}

#[tokio::test]
async fn simulator_paths_reject_dot_segments_and_redirects_do_not_forward_the_api_key() {
    let client = SimulatorClient::new("http://127.0.0.1:1", "dummy-key").unwrap();
    assert_eq!(
        client.get("A/../../info").await,
        Err(SimulatorError::InvalidPath)
    );
    assert_eq!(
        client.list(Some("A/../B")).await,
        Err(SimulatorError::InvalidPath)
    );
    assert_eq!(
        client.set("A/../B", &serde_json::json!(1)).await,
        Err(SimulatorError::InvalidPath)
    );
    assert_eq!(
        client.subscribe("A/./B", 1).await,
        Err(SimulatorError::InvalidPath)
    );

    let (destination_url, destination_seen) = fake_server(200, r#"{"Result":"Success"}"#, None);
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let source_url = format!("http://{}", listener.local_addr().unwrap());
    thread::spawn(move || {
        if let Ok((mut stream, _)) = listener.accept() {
            let mut request = [0; 8192];
            let _ = stream.read(&mut request);
            let body = "redirect";
            let response = format!(
                "HTTP/1.1 302 Found\r\nLocation: {destination_url}/steal\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                body.len()
            );
            let _ = stream.write_all(response.as_bytes());
        }
    });
    let result = SimulatorClient::new(&source_url, "dummy-key")
        .unwrap()
        .info()
        .await;
    assert!(matches!(
        result,
        Err(SimulatorError::HttpStatus { status: 302, .. })
    ));
    assert!(destination_seen
        .recv_timeout(Duration::from_millis(50))
        .is_err());
}

#[tokio::test]
async fn simulator_path_encoding_preserves_valid_delimiters_and_unicode() {
    let (url, observed) = scripted_server(vec![(200, r#"{"Result":"Success"}"#, None)]);
    let client = SimulatorClient::with_profile(&url, "key", TimeoutProfile::Fast).unwrap();
    client.get("Current/Trenño?x#y.InputValue").await.unwrap();
    let request = observed.recv_timeout(Duration::from_secs(1)).unwrap().0;
    assert!(request.starts_with("GET /get/Current/Tren%C3%B1o%3Fx%23y.InputValue "));
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
    let (url, observed) = scripted_server(vec![
        (200, r#"{"Result":"Success"}"#, Some(gate_rx)),
        (200, r#"{"Result":"Success"}"#, None),
    ]);
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
    assert_eq!(
        writer.generation(),
        2,
        "old generation must fence at request time"
    );
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
async fn writer_admission_deadline_covers_contention_for_the_admission_lock() {
    let (gate_tx, gate_rx) = mpsc::channel();
    let (url, observed) = scripted_server(vec![
        (200, r#"{"Result":"Success"}"#, Some(gate_rx)),
        (200, r#"{"Result":"Success"}"#, None),
    ]);
    let writer = GenerationWriter::new_with_queue_wait(
        SimulatorClient::new(&url, "key").unwrap(),
        1,
        1,
        Duration::from_millis(40),
    )
    .unwrap();
    let active_writer = writer.clone();
    let active = tokio::spawn(async move {
        active_writer
            .write(SimulatorWrite {
                generation: 1,
                command_id: 80,
                endpoint: Endpoint::new("Active").unwrap(),
                value: SimValue::Number(1.0),
            })
            .await
    });
    tokio::task::spawn_blocking(move || observed.recv_timeout(Duration::from_secs(2)).unwrap())
        .await
        .unwrap();
    let start = tokio::time::Instant::now();
    let mut waiters = Vec::new();
    for command_id in 81..86 {
        let writer = writer.clone();
        waiters.push(tokio::spawn(async move {
            writer
                .write(SimulatorWrite {
                    generation: 1,
                    command_id,
                    endpoint: Endpoint::new("Queued").unwrap(),
                    value: SimValue::Number(command_id as f64),
                })
                .await
        }));
    }
    tokio::time::sleep(Duration::from_millis(60)).await;
    gate_tx.send(()).unwrap();
    let mut timed_out = 0;
    let mut admitted = 0;
    for waiter in waiters {
        let result = waiter.await.unwrap();
        match result {
            Err(WriterError::QueueTimeout) => timed_out += 1,
            Ok(WriteAck::Applied { .. }) => admitted += 1,
            other => panic!("unexpected admission result: {other:?}"),
        }
    }
    assert!(start.elapsed() < Duration::from_millis(120));
    assert_eq!(timed_out, 4);
    assert_eq!(admitted, 1);
    let _ = active.await.unwrap();
    writer.shutdown().await.unwrap();
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

#[test]
fn invalid_key_is_a_permanent_health_failure() {
    let mut state = ConnectionState::default();
    state.connected(json!({"ok": true}));
    assert_eq!(
        state.after_health_check(Err(
            trenino_runtime::simulator::connection::ConnectionError::InvalidKey
        )),
        HealthDecision::RetryAfter(Duration::from_secs(30))
    );
    assert_eq!(state.status, SimulatorStatus::Error);
    assert_eq!(
        state.last_error,
        Some(trenino_runtime::simulator::connection::ConnectionError::InvalidKey)
    );
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

fn scripted_server(
    responses: Vec<(u16, &'static str, Option<mpsc::Receiver<()>>)>,
) -> (String, mpsc::Receiver<(String, u16)>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let address = listener.local_addr().unwrap();
    let (observed_tx, observed_rx) = mpsc::channel();
    thread::spawn(move || {
        for (status, body, gate) in responses {
            if let Ok((mut stream, _)) = listener.accept() {
                let mut request = [0_u8; 8192];
                let size = stream.read(&mut request).unwrap_or(0);
                let request_text = String::from_utf8_lossy(&request[..size]).to_string();
                let _ = observed_tx.send((request_text, status));
                if let Some(gate) = gate {
                    let _ = gate.recv_timeout(Duration::from_secs(2));
                }
                let reason = match status {
                    200 => "OK",
                    302 => "Found",
                    403 => "Forbidden",
                    500 => "Internal Server Error",
                    503 => "Service Unavailable",
                    _ => "Error",
                };
                let response = format!(
                    "HTTP/1.1 {status} {reason}\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                    body.len()
                );
                let _ = stream.write_all(response.as_bytes());
            }
        }
    });
    (format!("http://{address}"), observed_rx)
}

async fn recv_from_thread<T: Send + 'static>(
    receiver: std::sync::Arc<std::sync::Mutex<mpsc::Receiver<T>>>,
) -> T {
    tokio::task::spawn_blocking(move || {
        receiver
            .lock()
            .unwrap()
            .recv_timeout(Duration::from_secs(2))
            .unwrap()
    })
    .await
    .unwrap()
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

#[tokio::test]
async fn cancelled_subscription_acquire_rolls_back_and_removes_orphan_lease() {
    use trenino_runtime::simulator::subscriptions::SubscriptionService;
    let (gate_tx, gate_rx) = mpsc::channel();
    let (url, observed) = scripted_server(vec![
        (200, r#"{"Result":"Success"}"#, Some(gate_rx)),
        (200, r#"{"Result":"Success"}"#, None),
    ]);
    let service = std::sync::Arc::new(SubscriptionService::new(
        std::sync::Arc::new(SimulatorClient::new(&url, "key").unwrap()),
        999,
    ));
    let observed = std::sync::Arc::new(std::sync::Mutex::new(observed));
    let pending_service = service.clone();
    let pending = tokio::spawn(async move {
        pending_service
            .acquire("abandoned", 1, vec!["A".into()])
            .await
    });
    let request = recv_from_thread(observed.clone()).await;
    assert!(request
        .0
        .to_ascii_lowercase()
        .starts_with("post /subscription/a?"));
    pending.abort();
    gate_tx.send(()).unwrap();
    let cleanup = recv_from_thread(observed.clone()).await;
    assert!(cleanup
        .0
        .to_ascii_lowercase()
        .starts_with("delete /subscription?"));
    assert_eq!(service.lease_count().await, 0);
    service.shutdown().await.unwrap();
}

#[tokio::test]
async fn cancelled_multi_id_cleanup_retains_each_id_until_success() {
    use trenino_runtime::simulator::subscriptions::SubscriptionService;
    let (first_gate_tx, first_gate_rx) = mpsc::channel();
    let (second_gate_tx, second_gate_rx) = mpsc::channel();
    let (url, observed) = scripted_server(vec![
        (200, r#"{"Result":"Success"}"#, None),
        (200, r#"{"Result":"Success"}"#, None),
        (200, r#"{"Result":"Success"}"#, Some(first_gate_rx)),
        (200, r#"{"Result":"Success"}"#, Some(second_gate_rx)),
    ]);
    let service = std::sync::Arc::new(SubscriptionService::new(
        std::sync::Arc::new(SimulatorClient::new(&url, "key").unwrap()),
        999,
    ));
    let observed = std::sync::Arc::new(std::sync::Mutex::new(observed));
    let lease = service
        .acquire("owner", 2, vec!["A".into(), "B".into()])
        .await
        .unwrap();
    let release_service = service.clone();
    let release = tokio::spawn(async move { release_service.release(lease).await });
    let _ = recv_from_thread(observed.clone()).await;
    let _ = recv_from_thread(observed.clone()).await;
    let first_delete = recv_from_thread(observed.clone()).await;
    assert!(first_delete
        .0
        .to_ascii_lowercase()
        .contains("subscription=1000"));
    release.abort();
    first_gate_tx.send(()).unwrap();
    let second_delete = recv_from_thread(observed.clone()).await;
    assert!(second_delete
        .0
        .to_ascii_lowercase()
        .contains("subscription=1001"));
    second_gate_tx.send(()).unwrap();
    assert_eq!(service.pending_cleanup_count().await, 0);
    assert_eq!(service.lease_count().await, 0);
    service.shutdown().await.unwrap();
}

#[tokio::test]
async fn partial_subscribe_failure_cleans_created_and_ambiguous_ids() {
    use trenino_runtime::simulator::subscriptions::SubscriptionService;
    let (url, observed) = scripted_server(vec![
        (200, r#"{"Result":"Success"}"#, None),
        (500, "failed", None),
        (200, r#"{"Result":"Success"}"#, None),
        (200, r#"{"Result":"Success"}"#, None),
    ]);
    let service = SubscriptionService::new(
        std::sync::Arc::new(SimulatorClient::new(&url, "key").unwrap()),
        999,
    );
    assert!(service
        .acquire("owner", 3, vec!["A".into(), "B".into()])
        .await
        .is_err());
    assert_eq!(service.lease_count().await, 0);
    assert_eq!(service.pending_cleanup_count().await, 0);
    let requests: Vec<_> = (0..4)
        .map(|_| {
            observed
                .recv_timeout(Duration::from_secs(2))
                .unwrap()
                .0
                .to_ascii_lowercase()
        })
        .collect();
    assert!(requests[2].starts_with("delete /subscription?"));
    assert!(requests[3].starts_with("delete /subscription?"));
    service.shutdown().await.unwrap();
}

#[tokio::test]
async fn failed_unsubscribe_is_explicitly_retryable_without_new_consumers() {
    use trenino_runtime::simulator::subscriptions::SubscriptionService;
    let (url, observed) = scripted_server(vec![
        (200, r#"{"Result":"Success"}"#, None),
        (503, "try later", None),
        (200, r#"{"Result":"Success"}"#, None),
    ]);
    let service = SubscriptionService::new(
        std::sync::Arc::new(SimulatorClient::new(&url, "key").unwrap()),
        999,
    );
    let lease = service.acquire("owner", 4, vec!["A".into()]).await.unwrap();
    assert!(service.release(lease).await.is_err());
    assert_eq!(service.pending_cleanup_count().await, 1);
    service.retry_cleanup().await.unwrap();
    assert_eq!(service.pending_cleanup_count().await, 0);
    let _ = observed.recv_timeout(Duration::from_secs(1)).unwrap();
    let _ = observed.recv_timeout(Duration::from_secs(1)).unwrap();
    let _ = observed.recv_timeout(Duration::from_secs(1)).unwrap();
    service.shutdown().await.unwrap();
}

#[tokio::test]
async fn saturated_subscription_shutdown_returns_without_waiting_for_an_unrequested_exit() {
    use trenino_runtime::simulator::subscriptions::{
        SubscriptionService, SubscriptionServiceError,
    };
    let (gate_tx, gate_rx) = mpsc::channel();
    let (url, observed) = fake_server(200, r#"{"Result":"Success"}"#, Some(gate_rx));
    let service = std::sync::Arc::new(SubscriptionService::new(
        std::sync::Arc::new(
            SimulatorClient::with_profile(&url, "key", TimeoutProfile::Fast).unwrap(),
        ),
        999,
    ));
    let observed = std::sync::Arc::new(std::sync::Mutex::new(observed));
    let acquiring_service = service.clone();
    let acquiring = tokio::spawn(async move {
        acquiring_service
            .acquire("owner", 1, vec!["A".into()])
            .await
    });
    assert!(recv_from_thread(observed)
        .await
        .to_ascii_lowercase()
        .starts_with("post /subscription/a?"));

    let mut counts = Vec::new();
    for _ in 0..65 {
        let service = service.clone();
        counts.push(tokio::spawn(async move { service.lease_count().await }));
    }
    tokio::time::sleep(Duration::from_millis(50)).await;
    assert!(counts.iter().all(|count| !count.is_finished()));

    let first_shutdown = tokio::time::timeout(Duration::from_secs(1), service.shutdown()).await;
    gate_tx.send(()).unwrap();
    assert!(
        matches!(
            first_shutdown,
            Ok(Err(SubscriptionServiceError::QueueTimeout))
        ),
        "first saturated shutdown must return a retryable admission error: {first_shutdown:?}"
    );
    assert!(acquiring.await.unwrap().is_ok());
    for count in counts {
        let _ = count.await.unwrap();
    }
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
