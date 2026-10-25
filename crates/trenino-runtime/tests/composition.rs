//! Production composition using disposable SQLite, loopback TSW and fake hardware.
use std::{
    io::{BufRead, BufReader, Write},
    net::TcpListener,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    },
    time::{Duration, Instant},
};
use trenino_core::{ConfigId, OperationId};
use trenino_runtime::{
    composition::{io::IoBridge, keyboard::NativeKeyboard, ControlRuntime},
    executable::ExecutableProbe,
    lifecycle::ShutdownParticipant,
    resource::{ResourceArbiter, ResourceConsumers},
    routing::InputResolver,
    settings::Settings,
    storage::{
        bindings::{OutputBindingDraft, OutputBindingOperator},
        scripts::{ScriptDraft, ScriptPatch},
        trains::TrainDraft,
        Database, DeviceDraft, OutputDraft,
    },
    train::output_controller::{HardwareDispatch, OutputLevel},
};
#[derive(Default)]
struct Hardware(Mutex<Vec<(i32, bool)>>);
impl HardwareDispatch for Hardware {
    fn resolve_port(&self, _: i64) -> Option<String> {
        Some("panel".into())
    }
    fn set_output(&self, _: &str, pin: i32, level: OutputLevel) -> Result<(), String> {
        self.0
            .lock()
            .unwrap()
            .push((pin, level == OutputLevel::High));
        Ok(())
    }
    fn set_module_brightness(&self, _: &str, _: i32, _: i32) -> Result<(), String> {
        Ok(())
    }
    fn write_segments(&self, _: &str, _: i32, _: Vec<u8>) -> Result<(), String> {
        Ok(())
    }
}
struct Consumers;
impl ResourceConsumers for Consumers {
    fn suspend_actuation(&self, _: &str) -> Result<(), String> {
        Ok(())
    }
    fn cancel_calibration(&self, _: &str) -> Result<(), String> {
        Ok(())
    }
    fn source_lost(&self, _: &str, _: u64) -> Result<(), String> {
        Ok(())
    }
    fn resume_after_fresh_sample(&self, _: &str) -> Result<(), String> {
        Ok(())
    }
}
fn wait(mut condition: impl FnMut() -> bool) {
    let deadline = Instant::now() + Duration::from_secs(8);
    while !condition() {
        assert!(Instant::now() < deadline, "condition timed out");
        std::thread::sleep(Duration::from_millis(10));
    }
}
#[test]
fn train_activation_script_effect_committed_reload_disconnect_and_shutdown() {
    let server = TcpListener::bind("127.0.0.1:0").unwrap();
    server.set_nonblocking(true).unwrap();
    let url = format!("http://{}", server.local_addr().unwrap());
    let stopped = Arc::new(AtomicBool::new(false));
    let stop = stopped.clone();
    let requests = Arc::new(Mutex::new(vec![]));
    let seen = requests.clone();
    let server_host = std::thread::spawn(move || {
        while !stop.load(Ordering::Acquire) {
            match server.accept() {
                Ok((mut socket, _)) => {
                    socket.set_nonblocking(false).unwrap();
                    socket
                        .set_read_timeout(Some(Duration::from_secs(2)))
                        .unwrap();
                    let mut reader = BufReader::new(socket.try_clone().unwrap());
                    let mut line = String::new();
                    reader.read_line(&mut line).unwrap();
                    seen.lock().unwrap().push(line.clone());
                    loop {
                        let mut header = String::new();
                        reader.read_line(&mut header).unwrap();
                        if header == "\r\n" || header.is_empty() {
                            break;
                        }
                    }
                    let body = if line.contains("/info") {
                        r#"{"commands":["info"]}"#
                    } else if line.contains("ObjectClass") {
                        r#"{"Values":{"Value":"BP_Test_C"}}"#
                    } else if line.contains("Drivable") {
                        r#"{"Values":{"Value":0}}"#
                    } else {
                        r#"{"Values":{"Value":1},"Entries":[{"NodeValid":true,"Values":{"Value":1}}]}"#
                    };
                    let _=write!(socket,"HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",body.len(),body);
                }
                Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                    std::thread::sleep(Duration::from_millis(2))
                }
                Err(e) => panic!("{e}"),
            }
        }
    });
    let dir = tempfile::tempdir().unwrap();
    let db = Arc::new(Database::open_full(dir.path().join("live.db")).unwrap());
    db.allocate_epoch().unwrap();
    let settings = Settings::new((*db).clone());
    settings.set_api_key("test").unwrap();
    settings.set_simulator_url(&url).unwrap();
    let train = db
        .create_train(
            OperationId(1),
            TrainDraft {
                name: "Test".into(),
                description: None,
                identifiers: vec!["BP_Test".into()],
            },
        )
        .unwrap()
        .record;
    let device = db
        .create_device(
            OperationId(2),
            DeviceDraft {
                name: "Panel".into(),
                description: None,
                config_id: Some(ConfigId::new(10).unwrap()),
            },
        )
        .unwrap()
        .record;
    let output = db
        .create_output(
            OperationId(3),
            device.id,
            OutputDraft { pin: 4, name: None },
        )
        .unwrap()
        .record;
    db.create_output_binding(
        OperationId(4),
        train.id,
        OutputBindingDraft {
            name: "Indicator".into(),
            output_type: None,
            output_id: output.id,
            endpoint: "Speed".into(),
            operator: OutputBindingOperator::Gt,
            value_a: Some(0.0),
            value_b: None,
            enabled: None,
        },
    )
    .unwrap();
    let script = db
        .create_script(
            OperationId(5),
            train.id,
            ScriptDraft {
                name: "Signal".into(),
                enabled: true,
                code: format!(
                    "function on_change(e) output.set({}, true); print('old') end",
                    output.id.0
                ),
                triggers: vec![],
            },
        )
        .unwrap()
        .record;
    let input = db
        .create_input(
            OperationId(7),
            device.id,
            trenino_runtime::storage::InputDraft {
                pin: 2,
                kind: trenino_runtime::storage::InputKind::Button,
                sensitivity: None,
                debounce: Some(20),
                name: None,
                matrix_id: None,
            },
        )
        .unwrap()
        .record;
    let button = db
        .create_train_element(
            OperationId(8),
            train.id,
            trenino_runtime::storage::trains::ElementDraft {
                name: "Horn".into(),
                kind: trenino_runtime::storage::trains::ElementKind::Button,
            },
        )
        .unwrap()
        .record;
    db.create_button_binding(
        OperationId(9),
        button.id,
        input.id,
        trenino_runtime::storage::bindings::ButtonBindingDraft {
            endpoint: Some("Horn.InputValue".into()),
            ..Default::default()
        },
    )
    .unwrap();
    let resolver = Arc::new(InputResolver::default());
    resolver.replace_port(
        "panel",
        1,
        ConfigId::new(10).unwrap(),
        [(
            2,
            trenino_runtime::routing::InputIdentity {
                device_id: device.id,
                input_id: input.id,
            },
        )],
    );
    let hardware = Arc::new(Hardware::default());
    let runtime = ControlRuntime::start(
        db.clone(),
        Arc::new(settings),
        resolver,
        Arc::new(ResourceArbiter::new(Arc::new(Consumers))),
        hardware.clone(),
        Arc::new(NativeKeyboard::new(&ExecutableProbe::keystroke())),
    )
    .unwrap();
    wait(|| runtime.train.snapshot().active_train_id == Some(train.id));
    wait(|| hardware.0.lock().unwrap().contains(&(4, true)));
    runtime
        .train
        .buttons()
        .try_input(trenino_runtime::train::button_controller::ButtonSample {
            port: "panel".into(),
            port_generation: 1,
            config_id: ConfigId::new(10).unwrap(),
            pin: 2,
            value: 1,
        })
        .unwrap();
    wait(|| {
        requests
            .lock()
            .unwrap()
            .iter()
            .any(|r| r.starts_with("PATCH /set/Horn.InputValue"))
    });
    let rt = tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .unwrap();
    rt.block_on(async {
        assert!(runtime.scripts.run_script(script.id.0).await.unwrap());
        let log = runtime.scripts.get_script_log(script.id.0).await.unwrap();
        assert!(log.iter().any(|l| l.contains("old")), "{log:?}");
    });
    db.update_script(
        OperationId(6),
        script.id,
        ScriptPatch {
            code: Some(format!(
                "function on_change(e) output.set({}, false); print('new') end",
                output.id.0
            )),
            ..Default::default()
        },
    )
    .unwrap();
    // Revision polling observes commits from every caller, including MCP storage ports.
    wait(|| {
        rt.block_on(async {
            assert!(runtime.scripts.run_script(script.id.0).await.unwrap());
            runtime
                .scripts
                .get_script_log(script.id.0)
                .await
                .unwrap()
                .iter()
                .any(|l| l.contains("new"))
        })
    });
    rt.block_on(runtime.connection.disconnect()).unwrap();
    wait(|| !trenino_runtime::mcp::ports::SimulatorPort::is_connected(&*runtime.simulator));
    wait(|| hardware.0.lock().unwrap().last() == Some(&(4, false)));
    let high_count = hardware
        .0
        .lock()
        .unwrap()
        .iter()
        .filter(|v| **v == (4, true))
        .count();
    rt.block_on(runtime.connection.retry_connection()).unwrap();
    wait(|| {
        hardware
            .0
            .lock()
            .unwrap()
            .iter()
            .filter(|v| **v == (4, true))
            .count()
            > high_count
    });
    runtime.cancel_and_join_producers().unwrap();
    runtime.cancel_and_join_producers().unwrap();
    let count = requests.lock().unwrap().len();
    std::thread::sleep(Duration::from_millis(300));
    assert_eq!(requests.lock().unwrap().len(), count);
    stopped.store(true, Ordering::Release);
    server_host.join().unwrap();
}
#[tokio::test(flavor = "current_thread")]
async fn sync_bridge_works_inside_current_thread_and_cancels_queued_work_on_shutdown() {
    let io = IoBridge::start();
    assert_eq!(
        io.call(async {
            tokio::time::sleep(Duration::from_millis(10)).await;
            Ok(42)
        })
        .unwrap(),
        42
    );
    let clone = io.clone();
    let started = Arc::new(AtomicBool::new(false));
    let flag = started.clone();
    let waiting = std::thread::spawn(move || {
        clone.call(async move {
            flag.store(true, Ordering::Release);
            std::future::pending::<()>().await;
            Ok(())
        })
    });
    wait(|| started.load(Ordering::Acquire));
    let start = Instant::now();
    io.shutdown();
    assert!(waiting.join().unwrap().is_err());
    assert!(start.elapsed() < Duration::from_secs(1));
    assert!(io.call(async { Ok(()) }).is_err());
}

#[test]
fn live_ports_reject_retained_client_in_error_connecting_and_disconnected_states() {
    use trenino_runtime::{
        composition::io::LiveSimulator,
        mcp::ports::SimulatorPort,
        simulator::{
            client::SimulatorClient, connection::SimulatorStatus, connection_owner::StatusSnapshot,
        },
        train::output_controller::SimulatorConnectionView,
    };
    let snapshot = StatusSnapshot {
        status: SimulatorStatus::Connected,
        last_error: None,
        info: None,
        health_failures: 0,
        client: Some(Arc::new(
            SimulatorClient::new("http://127.0.0.1:1", "test").unwrap(),
        )),
    };
    let (status, receiver) = tokio::sync::watch::channel(snapshot);
    let io = IoBridge::start();
    let live = LiveSimulator {
        io: io.clone(),
        status: receiver,
    };
    assert!(live.is_connected());
    for state in [
        SimulatorStatus::Error,
        SimulatorStatus::Connecting,
        SimulatorStatus::Disconnected,
        SimulatorStatus::NeedsConfig,
    ] {
        status.send_modify(|v| v.status = state);
        assert!(!live.is_connected());
        assert!(live.connected_client().is_none());
        assert_eq!(
            live.set_value("Horn", &serde_json::json!(1)).unwrap_err(),
            "simulator disconnected"
        );
    }
    io.shutdown();
}
