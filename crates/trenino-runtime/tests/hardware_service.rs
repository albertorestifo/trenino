use std::collections::VecDeque;
use std::io;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::mpsc;
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
    heartbeat_value: Arc<std::sync::atomic::AtomicI32>,
}
impl FakeTransport {
    fn new(connected: Arc<AtomicBool>) -> Self {
        Self {
            connected,
            heartbeat_value: Arc::new(std::sync::atomic::AtomicI32::new(99)),
        }
    }
    fn with_heartbeat_value(
        connected: Arc<AtomicBool>,
        heartbeat_value: Arc<std::sync::atomic::AtomicI32>,
    ) -> Self {
        Self {
            connected,
            heartbeat_value,
        }
    }
}
struct FakePort {
    reads: VecDeque<Vec<u8>>,
    heartbeat_value: Arc<std::sync::atomic::AtomicI32>,
}

impl SerialTransport for FakeTransport {
    fn enumerate(&self) -> io::Result<Vec<String>> {
        Ok(if self.connected.load(Ordering::SeqCst) {
            vec!["SERVICE-PORT".into()]
        } else {
            vec![]
        })
    }
    fn open(&self, _port: &str, _baud: u32, _timeout: Duration) -> io::Result<Box<dyn SerialIo>> {
        Ok(Box::new(FakePort {
            reads: VecDeque::new(),
            heartbeat_value: self.heartbeat_value.clone(),
        }))
    }
}
impl SerialIo for FakePort {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        let Some(bytes) = self.reads.pop_front() else {
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
                self.reads.push_back(output);
            }
            Message::ConfigureButton { config_id, .. }
            | Message::ConfigureAnalog { config_id, .. }
            | Message::ConfigureMatrix { config_id, .. } => {
                self.reads.push_back(FrameDecoder::encode_frame(
                    &encode_message(&Message::ConfigurationStored { config_id }).unwrap(),
                ));
            }
            Message::Heartbeat => {
                self.reads.push_back(FrameDecoder::encode_frame(
                    &encode_message(&Message::InputValue {
                        pin: 2,
                        value: self.heartbeat_value.load(Ordering::SeqCst) as i16,
                    })
                    .unwrap(),
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

#[derive(Default)]
struct ScriptedRepositoryState {
    lookups: Mutex<VecDeque<Option<PersistedHardwareConfiguration>>>,
    lookups_seen: Mutex<Vec<String>>,
    confirmed: Mutex<Vec<(EntityId, ConfigId)>>,
    deletions: Mutex<Vec<EntityId>>,
    delete_entered: AtomicBool,
    delete_release: Mutex<Option<mpsc::Receiver<()>>>,
}
impl ScriptedRepositoryState {
    fn configured() -> Option<PersistedHardwareConfiguration> {
        Some(PersistedHardwareConfiguration {
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
        })
    }
}
struct ScriptedRepository {
    state: Arc<ScriptedRepositoryState>,
}
impl Default for ScriptedRepository {
    fn default() -> Self {
        Self {
            state: Arc::new(ScriptedRepositoryState::default()),
        }
    }
}
impl ScriptedRepository {
    fn new(state: Arc<ScriptedRepositoryState>) -> Self {
        Self { state }
    }
}
impl ConfigurationRepository for ScriptedRepository {
    fn confirm_configuration(
        &mut self,
        device_id: EntityId,
        config_id: ConfigId,
    ) -> Result<(), String> {
        self.state
            .confirmed
            .lock()
            .unwrap()
            .push((device_id, config_id));
        Ok(())
    }
}
impl CalibrationRepository for ScriptedRepository {
    fn persist_calibration(
        &mut self,
        _input_id: EntityId,
        _calibration: Calibration,
    ) -> Result<(), String> {
        Ok(())
    }
}
impl HardwareRepository for ScriptedRepository {
    fn load_configuration(
        &mut self,
        port: &str,
        _identity: &Message,
    ) -> Result<Option<PersistedHardwareConfiguration>, String> {
        self.state
            .lookups_seen
            .lock()
            .unwrap()
            .push(port.to_owned());
        Ok(match self.state.lookups.lock().unwrap().pop_front() {
            Some(scripted) => scripted,
            None => ScriptedRepositoryState::configured(),
        })
    }

    fn delete_device_unchecked(&mut self, device_id: EntityId) -> Result<(), String> {
        self.state.delete_entered.store(true, Ordering::SeqCst);
        if let Some(wait) = self.state.delete_release.lock().unwrap().as_mut() {
            let _ = wait.recv();
        }
        self.state.deletions.lock().unwrap().push(device_id);
        Ok(())
    }
}

#[derive(Default)]
struct FakeConsumers {
    fail_loss: AtomicBool,
    inputs: Mutex<Vec<InputEvent>>,
    protocol_errors: Mutex<Vec<(String, u64, String)>>,
    calibration_errors: Mutex<
        Vec<(
            trenino_core::SessionId,
            trenino_runtime::hardware::sessions::SessionError,
        )>,
    >,
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
    fn protocol_error(&self, port: &str, generation: u64, reason: &str) {
        self.protocol_errors
            .lock()
            .unwrap()
            .push((port.into(), generation, reason.into()));
    }
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
        id: trenino_core::SessionId,
        error: trenino_runtime::hardware::sessions::SessionError,
    ) {
        self.calibration_errors.lock().unwrap().push((id, error));
    }
}

#[test]
fn service_owns_discovery_routing_configuration_ack_and_disconnect_revocation() {
    let connected = Arc::new(AtomicBool::new(true));
    let consumers = Arc::new(FakeConsumers::default());
    let repo = ScriptedRepository::default();
    let service = Arc::new(
        HardwareService::new(
            Arc::new(FakeTransport::new(connected.clone())),
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
            Arc::new(FakeTransport::new(connected)),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
            ScriptedRepository::default(),
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
        Arc::new(FakeTransport::new(Arc::new(AtomicBool::new(false)))),
        DiscoveryTiming {
            settle: Duration::ZERO,
            read_timeout: Duration::from_millis(2),
            attempts: 1,
        },
        ScriptedRepository::default(),
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
        Arc::new(FakeTransport::new(Arc::new(AtomicBool::new(true)))),
        DiscoveryTiming {
            settle: Duration::ZERO,
            read_timeout: Duration::from_millis(2),
            attempts: 1,
        },
        ScriptedRepository::default(),
        consumers.clone(),
    ));
    let mut handle = service.start().unwrap();
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let generation = loop {
        if let Some(event) = consumers.inputs.lock().unwrap().last() {
            break event.port_generation;
        }
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    };
    let config_id = ConfigId::new(2).unwrap();
    let operation = handle
        .begin_configuration(ConfigurationApply {
            port_name: "SERVICE-PORT".into(),
            generation,
            device_id: EntityId(4),
            config_id,
            messages: vec![Message::ConfigureButton {
                config_id: 2,
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
    loop {
        if let Some(result) = handle.take_configuration_result(operation) {
            result.unwrap();
            break;
        }
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    }
    let before = consumers.inputs.lock().unwrap().len();
    handle
        .send_message(
            "SERVICE-PORT",
            generation,
            Message::Heartbeat,
            Duration::from_secs(1),
        )
        .unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(1);
    loop {
        let inputs = consumers.inputs.lock().unwrap();
        if inputs.len() > before {
            assert_eq!(inputs.last().unwrap().config_id, config_id);
            break;
        }
        drop(inputs);
        assert!(
            std::time::Instant::now() < deadline,
            "post-configuration input was not routed"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    handle.shutdown().unwrap();
}

#[test]
fn neutralization_error_is_retained_and_shutdown_reports_it() {
    let consumers = Arc::new(FakeConsumers::default());
    let service = Arc::new(HardwareService::new(
        Arc::new(FakeTransport::new(Arc::new(AtomicBool::new(true)))),
        DiscoveryTiming {
            settle: Duration::ZERO,
            read_timeout: Duration::from_millis(2),
            attempts: 1,
        },
        ScriptedRepository::default(),
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
    assert!(
        result.is_err(),
        "unresolved neutralization must make shutdown fail"
    );
}

#[test]
fn shutdown_closes_shared_session_and_lease_admission() {
    let consumers = Arc::new(FakeConsumers::default());
    let service = Arc::new(HardwareService::new(
        Arc::new(FakeTransport::new(Arc::new(AtomicBool::new(false)))),
        DiscoveryTiming {
            settle: Duration::ZERO,
            read_timeout: Duration::from_millis(2),
            attempts: 1,
        },
        ScriptedRepository::default(),
        consumers,
    ));
    let mut handle = service.start().unwrap();
    let sessions = handle.sessions();
    let arbiter = handle.resource_arbiter();
    handle.shutdown().unwrap();
    assert!(matches!(
        handle.start_detection(
            trenino_core::SessionId(300),
            trenino_runtime::hardware::sessions::InputDetectionSession::new(
                InputKind::Button,
                Duration::from_millis(5)
            ),
        ),
        Err(trenino_runtime::hardware::sessions::SessionError::AdmissionClosed)
    ));
    assert!(matches!(
        sessions.insert_calibration(CalibrationSession::new(
            trenino_core::SessionId(301),
            EntityId(8),
            "SERVICE-PORT".into(),
            1,
            2,
            1023,
        )),
        Err(trenino_runtime::hardware::sessions::SessionError::AdmissionClosed)
    ));
    assert!(matches!(
        arbiter.acquire(trenino_runtime::resource::LeaseKind::Firmware {
            port: "SERVICE-PORT".into(),
            generation: 1,
        }),
        Err(trenino_runtime::resource::ResourceError::Busy)
    ));
    assert!(matches!(
        handle.start_detection(
            trenino_core::SessionId(302),
            trenino_runtime::hardware::sessions::InputDetectionSession::new(
                InputKind::Button,
                Duration::from_millis(5),
            ),
        ),
        Err(trenino_runtime::hardware::sessions::SessionError::AdmissionClosed)
    ));
    assert_eq!(
        handle.scan_now().unwrap_err(),
        "hardware service is shutting down"
    );
    assert_eq!(
        handle
            .send_message(
                "SERVICE-PORT",
                1,
                Message::Heartbeat,
                Duration::from_millis(10),
            )
            .unwrap_err(),
        "hardware service is shutting down"
    );
    assert!(matches!(
        handle.acquire_firmware_lease("SERVICE-PORT", 1),
        Err(trenino_runtime::resource::ResourceError::Busy)
    ));
    assert_eq!(
        handle
            .begin_configuration(ConfigurationApply {
                port_name: "SERVICE-PORT".into(),
                generation: 1,
                device_id: EntityId(4),
                config_id: ConfigId::new(1).unwrap(),
                messages: vec![Message::ConfigureButton {
                    config_id: 1,
                    total_parts: 1,
                    part_number: 0,
                    pin: 2,
                    debounce: 5,
                }],
                mappings: vec![],
                timeout: Duration::from_millis(10),
            })
            .unwrap_err(),
        "hardware service is shutting down"
    );
    assert_eq!(
        handle.delete_device(EntityId(4)).unwrap_err(),
        "hardware service is shutting down"
    );
}

struct BlockingServiceTransport {
    connected: Arc<AtomicBool>,
    unblock: Arc<AtomicBool>,
    entered: Arc<AtomicBool>,
}
struct BlockingServicePort {
    reads: VecDeque<Vec<u8>>,
    unblock: Arc<AtomicBool>,
    entered: Arc<AtomicBool>,
    discovered: bool,
}
impl SerialTransport for BlockingServiceTransport {
    fn enumerate(&self) -> io::Result<Vec<String>> {
        Ok(if self.connected.load(Ordering::SeqCst) {
            vec!["SERVICE-PORT".into()]
        } else {
            vec![]
        })
    }
    fn open(&self, _port: &str, _baud: u32, _timeout: Duration) -> io::Result<Box<dyn SerialIo>> {
        Ok(Box::new(BlockingServicePort {
            reads: VecDeque::new(),
            unblock: self.unblock.clone(),
            entered: self.entered.clone(),
            discovered: false,
        }))
    }
}
impl SerialIo for BlockingServicePort {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        if let Some(bytes) = self.reads.pop_front() {
            buffer[..bytes.len()].copy_from_slice(&bytes);
            self.discovered = true;
            return Ok(bytes.len());
        }
        if self.discovered {
            self.entered.store(true, Ordering::SeqCst);
            while self.unblock.load(Ordering::SeqCst) {
                std::thread::sleep(Duration::from_millis(1));
            }
        }
        Err(io::ErrorKind::TimedOut.into())
    }
    fn write_all(&mut self, bytes: &[u8]) -> io::Result<()> {
        let payload = FrameDecoder::default().push(bytes).remove(0).unwrap();
        if let Message::IdentityRequest { request_id } = decode_message(&payload).unwrap() {
            self.reads.push_back(FrameDecoder::encode_frame(
                &encode_message(&Message::IdentityResponse {
                    request_id,
                    major: 1,
                    minor: 0,
                    patch: 0,
                    config_id: 1,
                })
                .unwrap(),
            ));
        }
        Ok(())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

#[test]
fn pending_shutdown_closes_admission_and_retry_completes() {
    let consumers = Arc::new(FakeConsumers::default());
    let unblock = Arc::new(AtomicBool::new(true));
    let entered = Arc::new(AtomicBool::new(false));
    let service = Arc::new(
        HardwareService::new(
            Arc::new(BlockingServiceTransport {
                connected: Arc::new(AtomicBool::new(true)),
                unblock: unblock.clone(),
                entered: entered.clone(),
            }),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
            ScriptedRepository::default(),
            consumers.clone(),
        )
        .with_policy(
            Duration::from_secs(60),
            Duration::from_secs(1),
            Duration::from_millis(20),
        ),
    );
    let mut handle = service.start().unwrap();
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    while !entered.load(Ordering::SeqCst) {
        assert!(
            std::time::Instant::now() < deadline,
            "blocked port owner never started reading"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    assert!(handle.shutdown().is_err(), "shutdown must stay pending");
    // Every admission path is closed by the timed-out shutdown attempt, not only
    // after a fully successful one.
    assert!(matches!(
        handle.start_detection(
            trenino_core::SessionId(310),
            trenino_runtime::hardware::sessions::InputDetectionSession::new(
                InputKind::Button,
                Duration::from_millis(5),
            ),
        ),
        Err(trenino_runtime::hardware::sessions::SessionError::AdmissionClosed)
    ));
    assert_eq!(
        handle.scan_now().unwrap_err(),
        "hardware service is shutting down"
    );
    assert_eq!(
        handle
            .send_message(
                "SERVICE-PORT",
                1,
                Message::Heartbeat,
                Duration::from_millis(10),
            )
            .unwrap_err(),
        "hardware service is shutting down"
    );
    assert!(matches!(
        handle.acquire_firmware_lease("SERVICE-PORT", 1),
        Err(trenino_runtime::resource::ResourceError::Busy)
    ));
    assert!(handle
        .begin_configuration(ConfigurationApply {
            port_name: "SERVICE-PORT".into(),
            generation: 1,
            device_id: EntityId(4),
            config_id: ConfigId::new(1).unwrap(),
            messages: vec![Message::ConfigureButton {
                config_id: 1,
                total_parts: 1,
                part_number: 0,
                pin: 2,
                debounce: 5,
            }],
            mappings: vec![],
            timeout: Duration::from_millis(10),
        })
        .is_err());
    assert!(matches!(
        handle
            .sessions()
            .insert_calibration(CalibrationSession::new(
                trenino_core::SessionId(311),
                EntityId(8),
                "SERVICE-PORT".into(),
                1,
                2,
                1023,
            )),
        Err(trenino_runtime::hardware::sessions::SessionError::AdmissionClosed)
    ));
    assert!(matches!(
        handle
            .resource_arbiter()
            .acquire(trenino_runtime::resource::LeaseKind::Firmware {
                port: "SERVICE-PORT".into(),
                generation: 1,
            }),
        Err(trenino_runtime::resource::ResourceError::Busy)
    ));
    unblock.store(false, Ordering::SeqCst);
    handle.shutdown().unwrap();
}

#[test]
fn service_configures_initially_unconfigured_board_and_routes_new_config() {
    let consumers = Arc::new(FakeConsumers::default());
    let repo_state = Arc::new(ScriptedRepositoryState::default());
    repo_state.lookups.lock().unwrap().push_back(None);
    let service = Arc::new(
        HardwareService::new(
            Arc::new(FakeTransport::new(Arc::new(AtomicBool::new(true)))),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
            ScriptedRepository::new(repo_state.clone()),
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
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let generation = loop {
        if let Some(candidate) = (1..=6).find(|candidate| {
            !handle
                .input_cache()
                .snapshot("SERVICE-PORT", *candidate)
                .is_empty()
        }) {
            break candidate;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "unconfigured board was never discovered"
        );
        std::thread::sleep(Duration::from_millis(2));
    };
    assert!(
        consumers.inputs.lock().unwrap().is_empty(),
        "unconfigured board must not dispatch inputs"
    );
    let config_five = ConfigId::new(5).unwrap();
    let operation = handle
        .begin_configuration(ConfigurationApply {
            port_name: "SERVICE-PORT".into(),
            generation,
            device_id: EntityId(4),
            config_id: config_five,
            messages: vec![Message::ConfigureButton {
                config_id: config_five.get(),
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
            timeout: Duration::from_secs(2),
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
            "configuration of an unconfigured board did not finish"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    handle
        .send_message(
            "SERVICE-PORT",
            generation,
            Message::Heartbeat,
            Duration::from_secs(1),
        )
        .unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    loop {
        let inputs = consumers.inputs.lock().unwrap();
        if let Some(event) = inputs.last() {
            assert_eq!(event.port_generation, generation);
            assert_eq!(event.config_id, config_five);
            break;
        }
        drop(inputs);
        assert!(
            std::time::Instant::now() < deadline,
            "post-configuration input was not routed"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    assert_eq!(
        handle
            .resolver()
            .resolve("SERVICE-PORT", generation, config_five, 2),
        Some(InputIdentity {
            device_id: EntityId(4),
            input_id: EntityId(8)
        })
    );
    assert_eq!(
        repo_state.confirmed.lock().unwrap().as_slice(),
        &[(EntityId(4), config_five)],
        "confirmation must be persisted exactly once after the acknowledgement"
    );
    handle.shutdown().unwrap();
}

#[test]
fn configuration_pin_kind_change_updates_detection_classification() {
    let heartbeat_value = Arc::new(std::sync::atomic::AtomicI32::new(99));
    let consumers = Arc::new(FakeConsumers::default());
    let service = Arc::new(
        HardwareService::new(
            Arc::new(FakeTransport::with_heartbeat_value(
                Arc::new(AtomicBool::new(true)),
                heartbeat_value.clone(),
            )),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
            ScriptedRepository::default(),
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
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let generation = loop {
        if let Some(event) = consumers.inputs.lock().unwrap().last() {
            break event.port_generation;
        }
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    };
    handle
        .start_detection(
            trenino_core::SessionId(96),
            trenino_runtime::hardware::sessions::InputDetectionSession::new(
                InputKind::Analog,
                Duration::from_secs(30),
            ),
        )
        .unwrap();
    let wait_for_value = |value: i16| {
        let deadline = std::time::Instant::now() + Duration::from_secs(2);
        loop {
            if consumers
                .inputs
                .lock()
                .unwrap()
                .iter()
                .any(|event| event.value == value)
            {
                break;
            }
            assert!(
                std::time::Instant::now() < deadline,
                "input {value} was never dispatched"
            );
            std::thread::sleep(Duration::from_millis(2));
        }
    };
    // The persisted mapping classifies pin 2 as a button, so an analog filter must
    // not fire even for a large analog-range change.
    heartbeat_value.store(30, Ordering::SeqCst);
    handle
        .send_message(
            "SERVICE-PORT",
            generation,
            Message::Heartbeat,
            Duration::from_secs(1),
        )
        .unwrap();
    wait_for_value(30);
    heartbeat_value.store(90, Ordering::SeqCst);
    handle
        .send_message(
            "SERVICE-PORT",
            generation,
            Message::Heartbeat,
            Duration::from_secs(1),
        )
        .unwrap();
    wait_for_value(90);
    assert!(
        consumers.detections.lock().unwrap().is_empty(),
        "analog detection must not fire while the dispatcher still classifies the pin as a button"
    );
    // Reapplying the SAME ConfigId with an analog pin kind must refresh the
    // dispatcher's classification.
    let config_one = ConfigId::new(1).unwrap();
    let operation = handle
        .begin_configuration(ConfigurationApply {
            port_name: "SERVICE-PORT".into(),
            generation,
            device_id: EntityId(4),
            config_id: config_one,
            messages: vec![Message::ConfigureAnalog {
                config_id: config_one.get(),
                total_parts: 1,
                part_number: 0,
                pin: 2,
                sensitivity: 5,
            }],
            mappings: vec![(
                2,
                InputIdentity {
                    device_id: EntityId(4),
                    input_id: EntityId(8),
                },
            )],
            timeout: Duration::from_secs(2),
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
            "pin kind reconfiguration did not finish"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    // A small analog delta stays pending; only an analog-threshold change fires now.
    heartbeat_value.store(40, Ordering::SeqCst);
    handle
        .send_message(
            "SERVICE-PORT",
            generation,
            Message::Heartbeat,
            Duration::from_secs(1),
        )
        .unwrap();
    wait_for_value(40);
    assert!(consumers.detections.lock().unwrap().is_empty());
    heartbeat_value.store(100, Ordering::SeqCst);
    handle
        .send_message(
            "SERVICE-PORT",
            generation,
            Message::Heartbeat,
            Duration::from_secs(1),
        )
        .unwrap();
    wait_for_value(100);
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    loop {
        let detected = consumers
            .detections
            .lock()
            .unwrap()
            .iter()
            .any(|(id, outcome)| {
                *id == trenino_core::SessionId(96)
                    && matches!(
                        outcome,
                        trenino_runtime::hardware::sessions::DetectionOutcome::Detected {
                            pin: 2,
                            value: 100,
                            ..
                        }
                    )
            });
        if detected {
            break;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "analog detection never fired after the pin kind change"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    handle.shutdown().unwrap();
}

#[test]
fn reconnect_to_unconfigured_board_allows_fresh_generation_configuration() {
    let connected = Arc::new(AtomicBool::new(true));
    let consumers = Arc::new(FakeConsumers::default());
    let repo_state = Arc::new(ScriptedRepositoryState::default());
    repo_state
        .lookups
        .lock()
        .unwrap()
        .push_back(ScriptedRepositoryState::configured());
    repo_state.lookups.lock().unwrap().push_back(None);
    let service = Arc::new(
        HardwareService::new(
            Arc::new(FakeTransport::new(connected.clone())),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
            ScriptedRepository::new(repo_state),
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
    let config_one = ConfigId::new(1).unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let generation = loop {
        if let Some(event) = consumers.inputs.lock().unwrap().last() {
            break event.port_generation;
        }
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    };
    // The old generation disconnects and is tombstoned.
    connected.store(false, Ordering::SeqCst);
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    while handle
        .resolver()
        .resolve("SERVICE-PORT", generation, config_one, 2)
        .is_some()
    {
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    }
    // The replacement board has no persisted configuration.
    connected.store(true, Ordering::SeqCst);
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let replacement = loop {
        if let Some(candidate) = (generation + 1..=generation + 6).find(|candidate| {
            !handle
                .input_cache()
                .snapshot("SERVICE-PORT", *candidate)
                .is_empty()
        }) {
            break candidate;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "replacement board was never discovered"
        );
        std::thread::sleep(Duration::from_millis(2));
    };
    assert!(
        consumers
            .inputs
            .lock()
            .unwrap()
            .iter()
            .all(|event| event.port_generation == generation),
        "the unconfigured replacement must not dispatch routed inputs"
    );
    // Configuring the fresh generation must not inherit the revoked tombstone.
    let config_seven = ConfigId::new(7).unwrap();
    let operation = handle
        .begin_configuration(ConfigurationApply {
            port_name: "SERVICE-PORT".into(),
            generation: replacement,
            device_id: EntityId(4),
            config_id: config_seven,
            messages: vec![Message::ConfigureButton {
                config_id: config_seven.get(),
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
            timeout: Duration::from_secs(2),
        })
        .unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    loop {
        if let Some(result) = handle.take_configuration_result(operation) {
            result.expect("fresh-generation configuration must succeed after a revoked tombstone");
            break;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "fresh-generation configuration did not finish"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    handle
        .send_message(
            "SERVICE-PORT",
            replacement,
            Message::Heartbeat,
            Duration::from_secs(1),
        )
        .unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    loop {
        let routed =
            consumers.inputs.lock().unwrap().iter().any(|event| {
                event.port_generation == replacement && event.config_id == config_seven
            });
        if routed {
            break;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "post-reconfiguration input was not routed on the fresh generation"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    handle.shutdown().unwrap();
}

#[test]
fn neutralization_failure_suspends_reconnect_dispatch_until_recovered() {
    let connected = Arc::new(AtomicBool::new(true));
    let consumers = Arc::new(FakeConsumers::default());
    let service = Arc::new(
        HardwareService::new(
            Arc::new(FakeTransport::new(connected.clone())),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
            ScriptedRepository::default(),
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
    let config_one = ConfigId::new(1).unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let generation = loop {
        if let Some(event) = consumers.inputs.lock().unwrap().last() {
            break event.port_generation;
        }
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    };
    // The consumer cannot neutralize the lost source; the failure must be retained.
    consumers.fail_loss.store(true, Ordering::SeqCst);
    connected.store(false, Ordering::SeqCst);
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    while handle
        .resolver()
        .resolve("SERVICE-PORT", generation, config_one, 2)
        .is_some()
    {
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    }
    assert!(handle.resource_arbiter().is_suspended());
    let dispatched_before_failure = consumers.inputs.lock().unwrap().len();
    // A reconnect must stay suspended: inputs reach the cache but are never
    // dispatched, and no new lease can be acquired.
    connected.store(true, Ordering::SeqCst);
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let replacement = loop {
        if let Some(candidate) = (generation + 1..=generation + 6).find(|candidate| {
            !handle
                .input_cache()
                .snapshot("SERVICE-PORT", *candidate)
                .is_empty()
        }) {
            break candidate;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "reconnected board was never discovered"
        );
        std::thread::sleep(Duration::from_millis(2));
    };
    handle
        .send_message(
            "SERVICE-PORT",
            replacement,
            Message::Heartbeat,
            Duration::from_secs(1),
        )
        .unwrap();
    let deadline = std::time::Instant::now() + Duration::from_millis(300);
    while std::time::Instant::now() < deadline {
        std::thread::sleep(Duration::from_millis(5));
    }
    assert_eq!(
        consumers.inputs.lock().unwrap().len(),
        dispatched_before_failure,
        "reconnect actuation must stay suspended while neutralization is unresolved"
    );
    assert!(
        !handle
            .input_cache()
            .snapshot("SERVICE-PORT", replacement)
            .is_empty(),
        "suspended inputs must still be cached"
    );
    assert!(matches!(
        handle.acquire_firmware_lease("SERVICE-PORT", replacement),
        Err(trenino_runtime::resource::ResourceError::Busy)
    ));
    // An explicit successful source-loss retry clears the retained failure and
    // resumes dispatch on the next connection.
    consumers.fail_loss.store(false, Ordering::SeqCst);
    connected.store(false, Ordering::SeqCst);
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    while handle
        .resolver()
        .resolve("SERVICE-PORT", replacement, config_one, 2)
        .is_some()
    {
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    }
    assert!(
        !handle.resource_arbiter().is_suspended(),
        "successful neutralization retry must clear the suspended resource"
    );
    connected.store(true, Ordering::SeqCst);
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    loop {
        let dispatched = consumers
            .inputs
            .lock()
            .unwrap()
            .iter()
            .any(|event| event.port_generation > replacement);
        if dispatched {
            break;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "dispatch was not resumed after successful recovery"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    handle.shutdown().unwrap();
}

#[derive(Clone)]
struct GatedTwoPortTransport {
    present_b: Arc<AtomicBool>,
    ack_gate: Arc<AtomicBool>,
    b_identity_requested: Arc<AtomicBool>,
}
struct GatedPort {
    name: String,
    reads: VecDeque<Vec<u8>>,
    ack_gate: Arc<AtomicBool>,
    pending_ack: Option<Vec<u8>>,
    b_identity_requested: Option<Arc<AtomicBool>>,
}
impl SerialTransport for GatedTwoPortTransport {
    fn enumerate(&self) -> io::Result<Vec<String>> {
        let mut ports = vec!["PORT-A".to_string()];
        if self.present_b.load(Ordering::SeqCst) {
            ports.push("PORT-B".into());
        }
        Ok(ports)
    }
    fn open(&self, port: &str, _baud: u32, _timeout: Duration) -> io::Result<Box<dyn SerialIo>> {
        Ok(Box::new(GatedPort {
            name: port.to_owned(),
            reads: VecDeque::new(),
            ack_gate: self.ack_gate.clone(),
            pending_ack: None,
            b_identity_requested: (port == "PORT-B").then(|| self.b_identity_requested.clone()),
        }))
    }
}
impl SerialIo for GatedPort {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        if let Some(bytes) = self.reads.pop_front() {
            buffer[..bytes.len()].copy_from_slice(&bytes);
            return Ok(bytes.len());
        }
        if self.pending_ack.is_some() && self.ack_gate.load(Ordering::SeqCst) {
            let frame = self.pending_ack.take().expect("ack presence checked");
            buffer[..frame.len()].copy_from_slice(&frame);
            return Ok(frame.len());
        }
        Err(io::ErrorKind::TimedOut.into())
    }
    fn write_all(&mut self, bytes: &[u8]) -> io::Result<()> {
        let payload = FrameDecoder::default().push(bytes).remove(0).unwrap();
        match decode_message(&payload).unwrap() {
            Message::IdentityRequest { request_id } => {
                if let Some(flag) = &self.b_identity_requested {
                    flag.store(true, Ordering::SeqCst);
                }
                let frame =
                    |message| FrameDecoder::encode_frame(&encode_message(&message).unwrap());
                let mut output = frame(Message::IdentityResponse {
                    request_id,
                    major: 1,
                    minor: 0,
                    patch: 0,
                    config_id: 1,
                });
                if self.name == "PORT-A" {
                    output.extend(frame(Message::InputValue { pin: 2, value: 0 }));
                    output.extend(frame(Message::InputValue { pin: 2, value: 1 }));
                } else {
                    // PORT-B is a second configured board whose inputs dispatch on
                    // its own generation while PORT-A reconfigures.
                    output.extend(frame(Message::InputValue { pin: 2, value: 7 }));
                }
                self.reads.push_back(output);
            }
            message @ (Message::ConfigureButton { config_id, .. }
            | Message::ConfigureAnalog { config_id, .. }
            | Message::ConfigureMatrix { config_id, .. }) => {
                let _ = message;
                self.pending_ack = Some(FrameDecoder::encode_frame(
                    &encode_message(&Message::ConfigurationStored { config_id }).unwrap(),
                ));
            }
            Message::Heartbeat => {
                self.reads.push_back(FrameDecoder::encode_frame(
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

#[test]
fn parallel_discovery_lookup_does_not_block_ack_or_input_dispatch() {
    let consumers = Arc::new(FakeConsumers::default());
    let repo_state = Arc::new(ScriptedRepositoryState::default());
    let ack_gate = Arc::new(AtomicBool::new(false));
    let present_b = Arc::new(AtomicBool::new(false));
    let b_identity_requested = Arc::new(AtomicBool::new(false));
    let service = Arc::new(
        HardwareService::new(
            Arc::new(GatedTwoPortTransport {
                present_b: present_b.clone(),
                ack_gate: ack_gate.clone(),
                b_identity_requested: b_identity_requested.clone(),
            }),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
            ScriptedRepository::new(repo_state.clone()),
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
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let generation = loop {
        if let Some(event) = consumers.inputs.lock().unwrap().last() {
            break event.port_generation;
        }
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    };
    // PORT-A's configuration acknowledgement is withheld at the port.
    let config_two = ConfigId::new(2).unwrap();
    let operation = handle
        .begin_configuration(ConfigurationApply {
            port_name: "PORT-A".into(),
            generation,
            device_id: EntityId(4),
            config_id: config_two,
            messages: vec![Message::ConfigureButton {
                config_id: config_two.get(),
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
            timeout: Duration::from_secs(5),
        })
        .unwrap();
    // A second board appears while the configuration waits for its ACK; its
    // repository lookup runs on an owned worker and must not stall the dispatcher.
    present_b.store(true, Ordering::SeqCst);
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    while !b_identity_requested.load(Ordering::SeqCst) {
        assert!(
            std::time::Instant::now() < deadline,
            "PORT-B was never discovered"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    while !repo_state
        .lookups_seen
        .lock()
        .unwrap()
        .iter()
        .any(|port| port == "PORT-B")
    {
        assert!(
            std::time::Instant::now() < deadline,
            "PORT-B lookup never ran"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    assert!(
        handle.configuration_result(operation).is_none(),
        "PORT-A configuration must still be waiting for its withheld ACK"
    );
    // Unrelated input dispatch continues while the configuration waits: PORT-B's
    // freshly discovered generation routes its own input even though PORT-A's
    // routes are deliberately cleared during its reconfiguration.
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    loop {
        let dispatched = consumers
            .inputs
            .lock()
            .unwrap()
            .iter()
            .any(|event| event.port_generation != generation && event.value == 7);
        if dispatched {
            break;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "PORT-B input dispatch stalled behind PORT-A's configuration wait"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    assert!(
        handle.configuration_result(operation).is_none(),
        "PORT-A configuration must still be waiting for its withheld ACK"
    );
    // Releasing the ACK completes the configuration promptly; the confirmation is
    // persisted exactly once, after the acknowledgement.
    ack_gate.store(true, Ordering::SeqCst);
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    loop {
        if let Some(result) = handle.take_configuration_result(operation) {
            result.expect("configuration must complete once its ACK is released");
            break;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "configuration did not complete after ACK release"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    assert_eq!(
        repo_state.confirmed.lock().unwrap().as_slice(),
        &[(EntityId(4), config_two)]
    );
    handle.shutdown().unwrap();
}

#[test]
fn calibration_overflow_completes_lease_cleanup_without_listener() {
    let consumers = Arc::new(FakeConsumers::default());
    let service = Arc::new(
        HardwareService::new(
            Arc::new(FakeTransport::new(Arc::new(AtomicBool::new(true)))),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
            ScriptedRepository::default(),
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
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let generation = loop {
        if let Some(event) = consumers.inputs.lock().unwrap().last() {
            break event.port_generation;
        }
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    };
    let session = handle
        .start_calibration(CalibrationSession::with_capacity(
            trenino_core::SessionId(95),
            EntityId(8),
            "SERVICE-PORT".into(),
            generation,
            2,
            1023,
            1,
        ))
        .unwrap();
    assert!(handle
        .advance_calibration(trenino_core::SessionId(95))
        .unwrap()
        .is_none());
    // The UI listener goes away; only the dispatcher-owned lifecycle remains.
    drop(session);
    handle
        .send_message(
            "SERVICE-PORT",
            generation,
            Message::Heartbeat,
            Duration::from_secs(1),
        )
        .unwrap();
    handle
        .send_message(
            "SERVICE-PORT",
            generation,
            Message::Heartbeat,
            Duration::from_secs(1),
        )
        .unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    loop {
        if consumers
            .calibration_errors
            .lock()
            .unwrap()
            .iter()
            .any(|(id, error)| {
                *id == trenino_core::SessionId(95)
                    && matches!(
                        error,
                        trenino_runtime::hardware::sessions::SessionError::Overflow
                    )
            })
        {
            break;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "calibration overflow was never reported"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    let retained = handle
        .sessions()
        .calibration(trenino_core::SessionId(95))
        .expect("terminal session state must be retained");
    assert_eq!(
        retained.lock().unwrap().step(),
        trenino_runtime::hardware::sessions::CalibrationStep::Overflowed
    );
    assert!(matches!(
        retained.lock().unwrap().terminal_result(),
        Some(Err(
            trenino_runtime::hardware::sessions::SessionError::Overflow
        ))
    ));
    assert!(
        !handle.resource_arbiter().is_suspended(),
        "the overflowed calibration lease must be released without a UI listener"
    );
    let lease = handle
        .acquire_firmware_lease("SERVICE-PORT", generation)
        .expect("a released calibration lease must not block new leases");
    // The firmware lease release follows the fresh-sample contract: one more input
    // is dispatched after acquisition, before the release.
    handle
        .send_message(
            "SERVICE-PORT",
            generation,
            Message::Heartbeat,
            Duration::from_secs(1),
        )
        .unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    while consumers
        .inputs
        .lock()
        .unwrap()
        .iter()
        .filter(|event| event.port_generation == generation)
        .count()
        < 3
    {
        assert!(
            std::time::Instant::now() < deadline,
            "fresh input after firmware acquisition was never dispatched"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    handle.release_firmware_lease(lease).unwrap();
    handle.shutdown().unwrap();
}

#[test]
fn delete_device_refuses_connected_device_and_tombstones_deleted_device() {
    let connected = Arc::new(AtomicBool::new(true));
    let consumers = Arc::new(FakeConsumers::default());
    let repo_state = Arc::new(ScriptedRepositoryState::default());
    let service = Arc::new(
        HardwareService::new(
            Arc::new(FakeTransport::new(connected.clone())),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
            ScriptedRepository::new(repo_state.clone()),
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
    let config_one = ConfigId::new(1).unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let generation = loop {
        if let Some(event) = consumers.inputs.lock().unwrap().last() {
            break event.port_generation;
        }
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    };
    // Deleting the connected device is refused with an actionable error and the
    // destructive commit never runs.
    let refused = handle.delete_device(EntityId(4)).unwrap_err();
    assert!(
        refused.contains("connected on port SERVICE-PORT"),
        "refusal must name the connected port: {refused}"
    );
    assert!(repo_state.deletions.lock().unwrap().is_empty());
    // Once disconnected, the deletion commits.
    connected.store(false, Ordering::SeqCst);
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    while handle
        .resolver()
        .resolve("SERVICE-PORT", generation, config_one, 2)
        .is_some()
    {
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    }
    handle.delete_device(EntityId(4)).unwrap();
    assert_eq!(
        repo_state.deletions.lock().unwrap().as_slice(),
        &[EntityId(4)]
    );
    // A stale pre-deletion lookup result must never re-activate the device.
    let dispatched = consumers.inputs.lock().unwrap().len();
    connected.store(true, Ordering::SeqCst);
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let replacement = loop {
        if let Some(candidate) = (generation + 1..=generation + 6).find(|candidate| {
            !handle
                .input_cache()
                .snapshot("SERVICE-PORT", *candidate)
                .is_empty()
        }) {
            break candidate;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "reconnected board was never discovered"
        );
        std::thread::sleep(Duration::from_millis(2));
    };
    let deadline = std::time::Instant::now() + Duration::from_millis(300);
    while std::time::Instant::now() < deadline {
        std::thread::sleep(Duration::from_millis(5));
    }
    assert!(
        handle
            .resolver()
            .resolve("SERVICE-PORT", replacement, config_one, 2)
            .is_none(),
        "a deleted device must not be re-activated by a stale lookup"
    );
    assert_eq!(
        consumers.inputs.lock().unwrap().len(),
        dispatched,
        "a deleted device must not dispatch inputs"
    );
    assert!(
        consumers
            .protocol_errors
            .lock()
            .unwrap()
            .iter()
            .any(|(port, _, reason)| port == "SERVICE-PORT" && reason.contains("deleted")),
        "the refused activation must be diagnosed"
    );
    handle.shutdown().unwrap();
}

#[test]
fn device_deletion_fence_blocks_configuration_commit_for_deleted_device() {
    let consumers = Arc::new(FakeConsumers::default());
    let repo_state = Arc::new(ScriptedRepositoryState::default());
    repo_state.lookups.lock().unwrap().push_back(None);
    let (release_delete, release_delete_rx) = mpsc::channel::<()>();
    *repo_state.delete_release.lock().unwrap() = Some(release_delete_rx);
    let ack_gate = Arc::new(AtomicBool::new(false));
    let service = Arc::new(
        HardwareService::new(
            Arc::new(GatedTwoPortTransport {
                present_b: Arc::new(AtomicBool::new(false)),
                ack_gate: ack_gate.clone(),
                b_identity_requested: Arc::new(AtomicBool::new(false)),
            }),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
            ScriptedRepository::new(repo_state.clone()),
            consumers.clone(),
        )
        .with_policy(
            Duration::from_secs(60),
            Duration::from_secs(1),
            Duration::from_secs(1),
        ),
    );
    let handle = Arc::new(service.start().unwrap());
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let generation = loop {
        if let Some(candidate) = (1..=6).find(|candidate| {
            !handle
                .input_cache()
                .snapshot("PORT-A", *candidate)
                .is_empty()
        }) {
            break candidate;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "unconfigured board was never discovered"
        );
        std::thread::sleep(Duration::from_millis(2));
    };
    // The configuration's ACK is withheld while the deletion takes the fence.
    let config_nine = ConfigId::new(9).unwrap();
    let operation = handle
        .begin_configuration(ConfigurationApply {
            port_name: "PORT-A".into(),
            generation,
            device_id: EntityId(4),
            config_id: config_nine,
            messages: vec![Message::ConfigureButton {
                config_id: config_nine.get(),
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
            timeout: Duration::from_secs(5),
        })
        .unwrap();
    let delete_handle = handle.clone();
    let deletion = std::thread::spawn(move || delete_handle.delete_device(EntityId(4)));
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    while !repo_state.delete_entered.load(Ordering::SeqCst) {
        assert!(
            std::time::Instant::now() < deadline,
            "deletion never reached its commit"
        );
        std::thread::sleep(Duration::from_millis(2));
    }
    // The device is deleted mid-flight; the pending configuration must be refused
    // at commit even though its ACK and confirmation arrive afterwards.
    ack_gate.store(true, Ordering::SeqCst);
    release_delete.send(()).unwrap();
    deletion.join().unwrap().unwrap();
    assert_eq!(
        repo_state.deletions.lock().unwrap().as_slice(),
        &[EntityId(4)]
    );
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let result = loop {
        if let Some(result) = handle.take_configuration_result(operation) {
            break result;
        }
        assert!(
            std::time::Instant::now() < deadline,
            "mid-deletion configuration never finished"
        );
        std::thread::sleep(Duration::from_millis(2));
    };
    assert!(
        matches!(
            result,
            Err(trenino_runtime::hardware::configuration::ApplyError::Commit(_))
        ),
        "configuration for a deleted device must fail at commit: {result:?}"
    );
    assert!(handle
        .resolver()
        .resolve("PORT-A", generation, config_nine, 2)
        .is_none());
    assert!(handle
        .begin_configuration(ConfigurationApply {
            port_name: "PORT-A".into(),
            generation,
            device_id: EntityId(4),
            config_id: ConfigId::new(10).unwrap(),
            messages: vec![Message::ConfigureButton {
                config_id: 10,
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
            timeout: Duration::from_millis(50),
        })
        .is_err_and(|error| error.contains("deleted")));
    let mut handle = Arc::try_unwrap(handle)
        .ok()
        .expect("handle references must be released");
    handle.shutdown().unwrap();
}
