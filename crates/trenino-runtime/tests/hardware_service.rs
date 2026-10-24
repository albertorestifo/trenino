use std::collections::VecDeque;
use std::io;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

use trenino_core::hardware::calibration::Calibration;
use trenino_core::hardware::protocol::{decode_message, encode_message, FrameDecoder, Message};
use trenino_core::{ConfigId, EntityId};
use trenino_runtime::hardware::configuration::{ConfigurationApply, ConfigurationRepository};
use trenino_runtime::hardware::discovery::DiscoveryTiming;
use trenino_runtime::hardware::service::{
    HardwareConsumers, HardwareRepository, HardwareService, PersistedHardwareConfiguration,
    PersistedInputMapping,
};
use trenino_runtime::hardware::sessions::CalibrationSession;
use trenino_runtime::hardware::sessions::{CalibrationRepository, InputKind};
use trenino_runtime::hardware::transport::{SerialIo, SerialTransport};
use trenino_runtime::resource::ResourceConsumers;
use trenino_runtime::routing::{InputEvent, InputIdentity};

#[derive(Clone)]
struct FakeTransport {
    connected: Arc<AtomicBool>,
}
struct FakePort(VecDeque<Vec<u8>>);

impl SerialTransport for FakeTransport {
    fn enumerate(&self) -> io::Result<Vec<String>> {
        Ok(if self.connected.load(Ordering::SeqCst) {
            vec!["SERVICE-PORT".into()]
        } else {
            vec![]
        })
    }
    fn open(&self, _port: &str, _baud: u32, _timeout: Duration) -> io::Result<Box<dyn SerialIo>> {
        Ok(Box::new(FakePort(VecDeque::new())))
    }
}
impl SerialIo for FakePort {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        let Some(bytes) = self.0.pop_front() else {
            return Err(io::ErrorKind::TimedOut.into());
        };
        buffer[..bytes.len()].copy_from_slice(&bytes);
        Ok(bytes.len())
    }
    fn write_all(&mut self, bytes: &[u8]) -> io::Result<()> {
        let payload = FrameDecoder::default().push(bytes).remove(0).unwrap();
        match decode_message(&payload).unwrap() {
            Message::IdentityRequest { request_id } => {
                let frame =
                    |message| FrameDecoder::encode_frame(&encode_message(&message).unwrap());
                let mut output = frame(Message::IdentityResponse {
                    request_id,
                    major: 1,
                    minor: 0,
                    patch: 0,
                    config_id: 1,
                });
                output.extend(frame(Message::InputValue { pin: 2, value: 0 }));
                output.extend(frame(Message::InputValue { pin: 2, value: 1 }));
                self.0.push_back(output);
            }
            Message::ConfigureButton { config_id, .. } => {
                self.0.push_back(FrameDecoder::encode_frame(
                    &encode_message(&Message::ConfigurationStored { config_id }).unwrap(),
                ));
            }
            Message::Heartbeat => {
                self.0.push_back(FrameDecoder::encode_frame(
                    &encode_message(&Message::InputValue { pin: 2, value: 99 }).unwrap(),
                ));
            }
            _ => {}
        }
        Ok(())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

struct FakeRepository {
    confirmations: AtomicUsize,
}
impl ConfigurationRepository for FakeRepository {
    fn confirm_configuration(
        &mut self,
        _device_id: EntityId,
        _config_id: ConfigId,
    ) -> Result<(), String> {
        self.confirmations.fetch_add(1, Ordering::SeqCst);
        Ok(())
    }
}
impl CalibrationRepository for FakeRepository {
    fn persist_calibration(
        &mut self,
        _input_id: EntityId,
        _calibration: Calibration,
    ) -> Result<(), String> {
        Ok(())
    }
}
impl HardwareRepository for FakeRepository {
    fn load_configuration(
        &mut self,
        _port: &str,
        _identity: &Message,
    ) -> Result<Option<PersistedHardwareConfiguration>, String> {
        Ok(Some(PersistedHardwareConfiguration {
            device_id: EntityId(4),
            config_id: ConfigId::new(1).unwrap(),
            mappings: vec![PersistedInputMapping {
                pin: 2,
                identity: InputIdentity {
                    device_id: EntityId(4),
                    input_id: EntityId(8),
                },
                kind: InputKind::Button,
            }],
        }))
    }
}

#[derive(Default)]
struct FakeConsumers {
    fail_loss: AtomicBool,
    inputs: Mutex<Vec<InputEvent>>,
    config_applied: Mutex<Vec<(String, u64, ConfigId)>>,
    source_lost: Mutex<Vec<(String, u64)>>,
    detections: Mutex<
        Vec<(
            trenino_core::SessionId,
            trenino_runtime::hardware::sessions::DetectionOutcome,
        )>,
    >,
    operations: Mutex<Vec<&'static str>>,
    fresh: Mutex<bool>,
    changed: std::sync::Condvar,
}
impl ResourceConsumers for FakeConsumers {
    fn suspend_actuation(&self, _port: &str) -> Result<(), String> {
        self.operations.lock().unwrap().push("suspend");
        Ok(())
    }
    fn cancel_calibration(&self, _port: &str) -> Result<(), String> {
        self.operations.lock().unwrap().push("cancel-calibration");
        Ok(())
    }
    fn source_lost(&self, port: &str, generation: u64) -> Result<(), String> {
        self.source_lost
            .lock()
            .unwrap()
            .push((port.into(), generation));
        self.operations.lock().unwrap().push("source-lost");
        if self.fail_loss.load(Ordering::SeqCst) {
            return Err("injected neutralization failure".into());
        }
        *self.fresh.lock().unwrap() = false;
        Ok(())
    }
    fn resume_after_fresh_sample(&self, _port: &str) -> Result<(), String> {
        self.operations.lock().unwrap().push("wait-fresh");
        let deadline = std::time::Instant::now() + Duration::from_secs(3);
        while !*self.fresh.lock().unwrap() {
            assert!(
                std::time::Instant::now() < deadline,
                "consumer did not receive a fresh sample"
            );
            std::thread::sleep(Duration::from_millis(2));
        }
        self.operations.lock().unwrap().push("resume");
        Ok(())
    }
}
impl HardwareConsumers for FakeConsumers {
    fn dispatch_input(&self, _identity: InputIdentity, event: InputEvent) -> Result<(), String> {
        self.inputs.lock().unwrap().push(event);
        *self.fresh.lock().unwrap() = true;
        self.changed.notify_all();
        Ok(())
    }
    fn protocol_error(&self, _port: &str, _generation: u64, _reason: &str) {}
    fn configuration_applied(&self, port: &str, generation: u64, config_id: ConfigId) {
        self.config_applied
            .lock()
            .unwrap()
            .push((port.into(), generation, config_id));
        self.changed.notify_all();
    }
    fn detection_outcome(
        &self,
        id: trenino_core::SessionId,
        outcome: trenino_runtime::hardware::sessions::DetectionOutcome,
    ) {
        self.detections.lock().unwrap().push((id, outcome));
        self.changed.notify_all();
    }
    fn calibration_error(
        &self,
        _id: trenino_core::SessionId,
        _error: trenino_runtime::hardware::sessions::SessionError,
    ) {
    }
}

#[test]
fn service_owns_discovery_routing_configuration_ack_and_disconnect_revocation() {
    let connected = Arc::new(AtomicBool::new(true));
    let consumers = Arc::new(FakeConsumers::default());
    let repo = FakeRepository {
        confirmations: AtomicUsize::new(0),
    };
    let service = Arc::new(
        HardwareService::new(
            Arc::new(FakeTransport {
                connected: connected.clone(),
            }),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
            repo,
            consumers.clone(),
        )
        .with_policy(
            Duration::from_secs(60),
            Duration::from_secs(1),
            Duration::from_secs(1),
        ),
    );
    let mut handle = service.start().unwrap();
    handle.scan_now().unwrap();
    let generation = {
        let deadline = std::time::Instant::now() + Duration::from_secs(2);
        loop {
            let values = consumers.inputs.lock().unwrap();
            if let Some(event) = values.last() {
                break event.port_generation;
            }
            drop(values);
            assert!(
                std::time::Instant::now() < deadline,
                "service failed to dispatch discovered input"
            );
            std::thread::sleep(Duration::from_millis(2));
        }
    };
    let config_id = ConfigId::new(1).unwrap();
    assert_eq!(
        handle
            .resolver()
            .resolve("SERVICE-PORT", generation, config_id, 2,),
        Some(InputIdentity {
            device_id: EntityId(4),
            input_id: EntityId(8)
        })
    );

    let operation = handle
        .begin_configuration(ConfigurationApply {
            port_name: "SERVICE-PORT".into(),
            generation,
            device_id: EntityId(4),
            config_id,
            messages: vec![Message::ConfigureButton {
                config_id: config_id.get(),
                total_parts: 1,
                part_number: 0,
                pin: 2,
                debounce: 5,
            }],
            mappings: vec![(
                2,
                InputIdentity {
                    device_id: EntityId(4),
                    input_id: EntityId(8),
                },
            )],
            timeout: Duration::from_secs(1),
        })
        .unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    loop {
        if let Some(result) = handle.take_configuration_result(operation) {
            result.unwrap();
            break;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "configuration operation did not finish"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    assert_eq!(consumers.config_applied.lock().unwrap().len(), 1);

    let calibration = handle
        .start_calibration(CalibrationSession::new(
            trenino_core::SessionId(92),
            EntityId(8),
            "SERVICE-PORT".into(),
            generation,
            2,
            1023,
        ))
        .unwrap();
    let arbiter = handle.resource_arbiter();
    assert!(arbiter.is_suspended());

    connected.store(false, Ordering::SeqCst);
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    while handle
        .resolver()
        .resolve("SERVICE-PORT", generation, config_id, 2)
        .is_some()
    {
        assert!(
            std::time::Instant::now() < deadline,
            "disconnect did not revoke routes"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    assert!(handle
        .input_cache()
        .snapshot("SERVICE-PORT", generation)
        .is_empty());
    assert!(consumers
        .source_lost
        .lock()
        .unwrap()
        .contains(&("SERVICE-PORT".into(), generation)));
    assert_eq!(
        calibration.lock().unwrap().step(),
        trenino_runtime::hardware::sessions::CalibrationStep::SourceLost
    );
    assert!(arbiter.is_suspended());
    connected.store(true, Ordering::SeqCst);
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let replacement_generation = loop {
        let inputs = consumers.inputs.lock().unwrap();
        if inputs.len() >= 4 {
            break inputs.last().unwrap().port_generation;
        }
        drop(inputs);
        assert!(
            std::time::Instant::now() < deadline,
            "replacement port was not discovered"
        );
        std::thread::sleep(Duration::from_millis(2));
    };
    assert!(replacement_generation > generation);
    assert_eq!(
        handle
            .resolver()
            .resolve("SERVICE-PORT", generation, config_id, 2),
        None
    );
    assert_eq!(
        handle
            .resolver()
            .resolve("SERVICE-PORT", replacement_generation, config_id, 2),
        Some(InputIdentity {
            device_id: EntityId(4),
            input_id: EntityId(8)
        })
    );
    assert!(handle
        .input_cache()
        .snapshot("SERVICE-PORT", generation)
        .is_empty());
    assert!(!arbiter.is_suspended());
    handle.shutdown().unwrap();
}

#[test]
fn service_cancels_calibration_before_firmware_handoff_and_waits_for_fresh_reconnect_input() {
    let connected = Arc::new(AtomicBool::new(true));
    let consumers = Arc::new(FakeConsumers::default());
    let service = Arc::new(
        HardwareService::new(
            Arc::new(FakeTransport { connected }),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
            FakeRepository {
                confirmations: AtomicUsize::new(0),
            },
            consumers.clone(),
        )
        .with_policy(
            Duration::from_secs(60),
            Duration::from_secs(1),
            Duration::from_secs(1),
        ),
    );
    let mut handle = service.start().unwrap();
    handle.scan_now().unwrap();
    let generation = loop {
        if let Some(event) = consumers.inputs.lock().unwrap().last() {
            break event.port_generation;
        }
        std::thread::sleep(Duration::from_millis(2));
    };
    let session = handle
        .start_calibration(CalibrationSession::new(
            trenino_core::SessionId(90),
            EntityId(8),
            "SERVICE-PORT".into(),
            generation,
            2,
            1023,
        ))
        .unwrap();
    let arbiter = handle.resource_arbiter();
    assert!(arbiter.is_suspended());
    let firmware = handle
        .acquire_firmware_lease("SERVICE-PORT", generation)
        .unwrap();
    assert_eq!(
        session.lock().unwrap().step(),
        trenino_runtime::hardware::sessions::CalibrationStep::Cancelled
    );
    assert_eq!(
        *consumers.operations.lock().unwrap(),
        vec!["suspend", "cancel-calibration", "source-lost"]
    );
    let operation = handle
        .begin_firmware_handoff(firmware, "SERVICE-PORT", generation)
        .unwrap();
    let handoff = loop {
        if let Some(result) = handle.handoff_result(operation) {
            break result.unwrap();
        }
        std::thread::sleep(Duration::from_millis(2));
    };
    let release = handle.release_firmware_handoff(firmware, handoff).unwrap();
    loop {
        if let Some(result) = handle.handoff_release_result(release) {
            result.unwrap();
            break;
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    // Lease release blocks inside the shared arbiter until the newly discovered
    // generation dispatches its first current sample.
    handle.release_firmware_lease(firmware).unwrap();
    assert!(!arbiter.is_suspended());
    assert!(consumers
        .operations
        .lock()
        .unwrap()
        .ends_with(&["wait-fresh", "resume"]));
    handle.shutdown().unwrap();
}

#[test]
fn service_publishes_autonomous_detection_timeout_from_owned_session() {
    let consumers = Arc::new(FakeConsumers::default());
    let service = Arc::new(HardwareService::new(
        Arc::new(FakeTransport {
            connected: Arc::new(AtomicBool::new(false)),
        }),
        DiscoveryTiming {
            settle: Duration::ZERO,
            read_timeout: Duration::from_millis(2),
            attempts: 1,
        },
        FakeRepository {
            confirmations: AtomicUsize::new(0),
        },
        consumers.clone(),
    ));
    let mut handle = service.start().unwrap();
    handle
        .start_detection(
            trenino_core::SessionId(91),
            trenino_runtime::hardware::sessions::InputDetectionSession::new(
                InputKind::Button,
                Duration::from_millis(20),
            ),
        )
        .unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(1);
    loop {
        if consumers.detections.lock().unwrap().contains(&(
            trenino_core::SessionId(91),
            trenino_runtime::hardware::sessions::DetectionOutcome::TimedOut,
        )) {
            break;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "owned detection timeout was not published"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    handle.shutdown().unwrap();
}

#[test]
fn configuration_commit_updates_dispatcher_configuration_before_later_input() {
    let consumers = Arc::new(FakeConsumers::default());
    let service = Arc::new(HardwareService::new(
        Arc::new(FakeTransport { connected: Arc::new(AtomicBool::new(true)) }),
        DiscoveryTiming { settle: Duration::ZERO, read_timeout: Duration::from_millis(2), attempts: 1 },
        FakeRepository { confirmations: AtomicUsize::new(0) },
        consumers.clone(),
    ));
    let mut handle = service.start().unwrap();
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let generation = loop {
        if let Some(event) = consumers.inputs.lock().unwrap().last() { break event.port_generation; }
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    };
    let config_id = ConfigId::new(2).unwrap();
    let operation = handle.begin_configuration(ConfigurationApply {
        port_name: "SERVICE-PORT".into(), generation, device_id: EntityId(4), config_id,
        messages: vec![Message::ConfigureButton { config_id: 2, total_parts: 1, part_number: 0, pin: 2, debounce: 5 }],
        mappings: vec![(2, InputIdentity { device_id: EntityId(4), input_id: EntityId(8) })],
        timeout: Duration::from_secs(1),
    }).unwrap();
    loop {
        if let Some(result) = handle.take_configuration_result(operation) { result.unwrap(); break; }
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    }
    let before = consumers.inputs.lock().unwrap().len();
    handle.send_message("SERVICE-PORT", generation, Message::Heartbeat, Duration::from_secs(1)).unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(1);
    loop {
        let inputs = consumers.inputs.lock().unwrap();
        if inputs.len() > before {
            assert_eq!(inputs.last().unwrap().config_id, config_id);
            break;
        }
        drop(inputs);
        assert!(std::time::Instant::now() < deadline, "post-configuration input was not routed");
        std::thread::sleep(Duration::from_millis(2));
    }
    handle.shutdown().unwrap();
}

#[test]
fn neutralization_error_is_retained_and_shutdown_reports_it() {
    let consumers = Arc::new(FakeConsumers::default());
    let service = Arc::new(HardwareService::new(
        Arc::new(FakeTransport { connected: Arc::new(AtomicBool::new(true)) }),
        DiscoveryTiming { settle: Duration::ZERO, read_timeout: Duration::from_millis(2), attempts: 1 },
        FakeRepository { confirmations: AtomicUsize::new(0) },
        consumers.clone(),
    ));
    let mut handle = service.start().unwrap();
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    while consumers.inputs.lock().unwrap().is_empty() {
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    }
    consumers.fail_loss.store(true, Ordering::SeqCst);
    handle.scan_now().unwrap();
    let result = handle.shutdown();
    assert!(result.is_err(), "unresolved neutralization must make shutdown fail");
}

#[test]
fn shutdown_closes_shared_session_and_lease_admission() {
    let consumers = Arc::new(FakeConsumers::default());
    let service = Arc::new(HardwareService::new(
        Arc::new(FakeTransport { connected: Arc::new(AtomicBool::new(false)) }),
        DiscoveryTiming { settle: Duration::ZERO, read_timeout: Duration::from_millis(2), attempts: 1 },
        FakeRepository { confirmations: AtomicUsize::new(0) }, consumers,
    ));
    let mut handle = service.start().unwrap();
    let sessions = handle.sessions();
    let arbiter = handle.resource_arbiter();
    handle.shutdown().unwrap();
    assert!(matches!(handle.start_detection(
        trenino_core::SessionId(300),
        trenino_runtime::hardware::sessions::InputDetectionSession::new(InputKind::Button, Duration::from_millis(5)),
    ), Err(trenino_runtime::hardware::sessions::SessionError::AdmissionClosed)));
    assert!(matches!(sessions.insert_calibration(CalibrationSession::new(
        trenino_core::SessionId(301), EntityId(8), "SERVICE-PORT".into(), 1, 2, 1023,
    )), Err(trenino_runtime::hardware::sessions::SessionError::AdmissionClosed)));
    assert!(matches!(arbiter.acquire(trenino_runtime::resource::LeaseKind::Firmware {
        port: "SERVICE-PORT".into(), generation: 1,
    }), Err(trenino_runtime::resource::ResourceError::Busy)));
}
