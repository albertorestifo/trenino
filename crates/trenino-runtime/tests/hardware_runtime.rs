use std::collections::VecDeque;
use std::io;
use std::sync::{
    atomic::{AtomicBool, AtomicUsize, Ordering},
    mpsc, Arc, Mutex,
};
use std::time::Duration;
use trenino_core::hardware::protocol::{decode_message, encode_message, FrameDecoder, Message};
use trenino_core::SessionId;
use trenino_core::{ConfigId, EntityId};
use trenino_runtime::hardware::configuration::{
    apply_configuration, ApplyError, ConfigurationApply, ConfigurationPort, ConfigurationRepository,
};
use trenino_runtime::hardware::discovery::{discover, DiscoveryTiming};
use trenino_runtime::hardware::sessions::{
    CalibrationRepository, CalibrationSession, CalibrationStep, DetectionOutcome, HardwareSessions,
    InputDetectionSession, InputKind, SessionError,
};
use trenino_runtime::hardware::transport::SerialIo;
use trenino_runtime::hardware::transport::SerialTransport;
use trenino_runtime::hardware::{HardwareRuntime, PortEvent};
use trenino_runtime::resource::{LeaseKind, ResourceArbiter, ResourceConsumers};
use trenino_runtime::routing::{InputIdentity, InputResolver, InputValueCache};

#[test]
fn resolver_replaces_a_port_map_atomically_and_fences_old_generations() {
    let resolver = InputResolver::default();
    let config = ConfigId::new(7).unwrap();
    let input = InputIdentity {
        device_id: EntityId(10),
        input_id: EntityId(20),
    };
    resolver.replace_port("COM4", 3, config, [(2, input)]);
    assert_eq!(resolver.resolve("COM4", 3, config, 2), Some(input));

    resolver.replace_port("COM4", 4, config, [(3, input)]);
    assert_eq!(resolver.resolve("COM4", 3, config, 2), None);
    assert_eq!(resolver.resolve("COM4", 4, config, 2), None);
    assert_eq!(resolver.resolve("COM4", 4, config, 3), Some(input));
    assert!(!resolver.replace_port("COM4", 3, config, [(2, input)]));
    assert_eq!(resolver.resolve("COM4", 4, config, 3), Some(input));
}

#[test]
fn invalidating_a_port_removes_routing_before_reconfiguration() {
    let resolver = InputResolver::default();
    let config = ConfigId::new(7).unwrap();
    let input = InputIdentity {
        device_id: EntityId(10),
        input_id: EntityId(20),
    };
    resolver.replace_port("COM4", 3, config, [(2, input)]);
    resolver.invalidate_port("COM4", 3);
    assert_eq!(resolver.resolve("COM4", 3, config, 2), None);
}

#[test]
fn disconnect_tombstone_rejects_late_same_generation_route_replacement() {
    let resolver = InputResolver::default();
    let config = ConfigId::new(7).unwrap();
    let input = InputIdentity {
        device_id: EntityId(10),
        input_id: EntityId(20),
    };
    assert!(resolver.replace_port("COM4", 5, config, [(2, input)]));
    assert!(resolver.invalidate_port("COM4", 5));
    assert!(!resolver.replace_port("COM4", 5, config, [(2, input)]));
    assert_eq!(resolver.resolve("COM4", 5, config, 2), None);
}

#[test]
fn newer_connection_generation_can_reactivate_after_disconnect_tombstone() {
    let resolver = InputResolver::default();
    let cache = InputValueCache::default();
    let config = ConfigId::new(7).unwrap();
    let input = InputIdentity {
        device_id: EntityId(10),
        input_id: EntityId(20),
    };
    assert!(resolver.replace_port("COM4", 5, config, [(2, input)]));
    assert!(cache.activate("COM4", 5));
    assert!(resolver.invalidate_port("COM4", 6));
    assert!(cache.invalidate("COM4", 6));
    assert!(!resolver.replace_port("COM4", 6, config, [(2, input)]));
    assert!(resolver.replace_port("COM4", 7, config, [(2, input)]));
    assert!(cache.activate("COM4", 7));
    assert!(cache.update("COM4", 7, 2, 15));
    assert_eq!(resolver.resolve("COM4", 7, config, 2), Some(input));
}

#[test]
fn newer_generation_reconfiguration_clears_old_tombstone() {
    let resolver = InputResolver::default();
    let cache = InputValueCache::default();
    assert!(resolver.invalidate_port("COM-R2", 1));
    assert!(cache.invalidate("COM-R2", 1));
    assert!(resolver.begin_reconfiguration("COM-R2", 2));
    assert!(cache.begin_reconfiguration("COM-R2", 2));
    let id = InputIdentity {
        device_id: EntityId(1),
        input_id: EntityId(2),
    };
    let config = ConfigId::new(2).unwrap();
    assert!(resolver.replace_port("COM-R2", 2, config, [(3, id)]));
    assert!(cache.activate("COM-R2", 2));
    assert_eq!(resolver.resolve("COM-R2", 2, config, 3), Some(id));
    assert!(cache.update("COM-R2", 2, 3, 42));
    assert_eq!(cache.snapshot("COM-R2", 2).get(&3), Some(&42));
    assert!(resolver.invalidate_port("COM-R2", 2));
    assert!(cache.invalidate("COM-R2", 2));
    assert!(!resolver.begin_reconfiguration("COM-R2", 2));
    assert!(!cache.begin_reconfiguration("COM-R2", 2));
}

#[test]
fn cache_rejects_stale_generations_and_same_generation_samples_after_disconnect() {
    let cache = InputValueCache::default();
    assert!(cache.update("COM4", 8, 2, 40));
    assert!(cache.update("COM4", 9, 2, 50));
    assert!(!cache.update("COM4", 8, 2, 99));
    assert_eq!(cache.snapshot("COM4", 9).get(&2), Some(&50));
    assert!(cache.invalidate("COM4", 9));
    assert!(!cache.update("COM4", 9, 2, 100));
    assert!(!cache.activate("COM4", 9));
    assert!(cache.activate("COM4", 10));
    assert!(cache.update("COM4", 10, 2, 60));
}

struct DiscoveryPort {
    reads: VecDeque<Vec<u8>>,
    writes: usize,
}
impl SerialIo for DiscoveryPort {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        let Some(bytes) = self.reads.pop_front() else {
            return Err(io::ErrorKind::TimedOut.into());
        };
        buffer[..bytes.len()].copy_from_slice(&bytes);
        Ok(bytes.len())
    }
    fn write_all(&mut self, bytes: &[u8]) -> io::Result<()> {
        let decoded =
            decode_message(&FrameDecoder::default().push(bytes).remove(0).unwrap()).unwrap();
        let Message::IdentityRequest { request_id } = decoded else {
            panic!("identity request expected")
        };
        self.writes += 1;
        let response_id = if self.writes == 1 {
            request_id.wrapping_add(1)
        } else {
            request_id
        };
        let payload = encode_message(&Message::IdentityResponse {
            request_id: response_id,
            major: 1,
            minor: 2,
            patch: 3,
            config_id: 0,
        })
        .unwrap();
        let frame = FrameDecoder::encode_frame(&payload);
        if self.writes == 1 {
            self.reads.push_back(frame[..2].to_vec());
            self.reads.push_back(frame[2..].to_vec());
        } else {
            self.reads.push_back(
                [
                    frame,
                    FrameDecoder::encode_frame(&encode_message(&Message::Heartbeat).unwrap()),
                ]
                .concat(),
            );
        }
        Ok(())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

#[test]
fn discovery_retries_a_stale_identity_and_accepts_only_matching_request_id() {
    let mut serial = DiscoveryPort {
        reads: VecDeque::new(),
        writes: 0,
    };
    let found = discover(
        &mut serial,
        DiscoveryTiming {
            settle: Duration::ZERO,
            read_timeout: Duration::from_millis(5),
            attempts: 5,
        },
    )
    .unwrap();
    assert_eq!(serial.writes, 2);
    assert!(matches!(
        found,
        Message::IdentityResponse {
            major: 1,
            config_id: 0,
            ..
        }
    ));
}

#[test]
fn discovery_returns_coalesced_and_partial_trailing_messages_to_port_owner() {
    use trenino_runtime::hardware::discovery::discover_owned;
    struct CoalescedDiscoveryPort {
        read: Option<Vec<u8>>,
    }
    impl SerialIo for CoalescedDiscoveryPort {
        fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
            let bytes = self.read.take().ok_or(io::ErrorKind::TimedOut)?;
            buffer[..bytes.len()].copy_from_slice(&bytes);
            Ok(bytes.len())
        }
        fn write_all(&mut self, bytes: &[u8]) -> io::Result<()> {
            let request =
                decode_message(&FrameDecoder::default().push(bytes).remove(0).unwrap()).unwrap();
            let Message::IdentityRequest { request_id } = request else {
                panic!("identity request expected")
            };
            let frame = |message| FrameDecoder::encode_frame(&encode_message(&message).unwrap());
            let trailing = frame(Message::InputValue { pin: 8, value: 9 });
            let partial = frame(Message::InputValue { pin: 9, value: 10 });
            let mut coalesced = frame(Message::IdentityResponse {
                request_id,
                major: 1,
                minor: 0,
                patch: 0,
                config_id: 1,
            });
            coalesced.extend(trailing);
            coalesced.extend(&partial[..partial.len() - 2]);
            self.read = Some(coalesced);
            Ok(())
        }
        fn flush(&mut self) -> io::Result<()> {
            Ok(())
        }
    }
    let partial = FrameDecoder::encode_frame(
        &encode_message(&Message::InputValue { pin: 9, value: 10 }).unwrap(),
    );
    let mut serial = CoalescedDiscoveryPort { read: None };
    let mut found = discover_owned(
        &mut serial,
        DiscoveryTiming {
            settle: Duration::ZERO,
            read_timeout: Duration::from_millis(5),
            attempts: 1,
        },
        Duration::from_millis(100),
        || false,
    )
    .unwrap();
    assert!(matches!(found.identity, Message::IdentityResponse { .. }));
    assert_eq!(
        found.trailing_messages,
        vec![Message::InputValue { pin: 8, value: 9 }]
    );
    assert_eq!(
        found.decoder.push(&partial[partial.len() - 2..]),
        vec![Ok(encode_message(&Message::InputValue {
            pin: 9,
            value: 10
        })
        .unwrap())]
    );
}

#[test]
fn discovery_retains_protocol_diagnostic_and_valid_frame_after_malformed_message() {
    use trenino_runtime::hardware::discovery::discover_owned;
    struct OverflowThenInput {
        response: VecDeque<Vec<u8>>,
    }
    impl SerialIo for OverflowThenInput {
        fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
            let bytes = self.response.pop_front().ok_or(io::ErrorKind::TimedOut)?;
            buffer[..bytes.len()].copy_from_slice(&bytes);
            Ok(bytes.len())
        }
        fn write_all(&mut self, bytes: &[u8]) -> io::Result<()> {
            let request =
                decode_message(&FrameDecoder::default().push(bytes).remove(0).unwrap()).unwrap();
            let Message::IdentityRequest { request_id } = request else {
                unreachable!()
            };
            let identity = FrameDecoder::encode_frame(
                &encode_message(&Message::IdentityResponse {
                    request_id,
                    major: 1,
                    minor: 0,
                    patch: 0,
                    config_id: 1,
                })
                .unwrap(),
            );
            let input = FrameDecoder::encode_frame(
                &encode_message(&Message::InputValue { pin: 4, value: 12 }).unwrap(),
            );
            let mut bytes = identity;
            bytes.extend(FrameDecoder::encode_frame(&[255]));
            bytes.extend(input);
            self.response = bytes.chunks(512).map(<[u8]>::to_vec).collect();
            Ok(())
        }
        fn flush(&mut self) -> io::Result<()> {
            Ok(())
        }
    }
    let mut serial = OverflowThenInput {
        response: VecDeque::new(),
    };
    let result = discover_owned(
        &mut serial,
        DiscoveryTiming {
            settle: Duration::ZERO,
            read_timeout: Duration::from_millis(5),
            attempts: 1,
        },
        Duration::from_millis(100),
        || false,
    )
    .unwrap();
    assert_eq!(result.protocol_errors.len(), 1);
    assert_eq!(
        result.trailing_messages,
        vec![Message::InputValue { pin: 4, value: 12 }]
    );
}

#[test]
fn discovery_outer_deadline_bounds_a_port_that_never_stops_sending_noise() {
    use trenino_runtime::hardware::discovery::{discover_owned, DiscoveryError};
    struct NoisyPort(usize);
    impl SerialIo for NoisyPort {
        fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
            self.0 += 1;
            buffer[0] = 0x55;
            Ok(1)
        }
        fn write_all(&mut self, _bytes: &[u8]) -> io::Result<()> {
            Ok(())
        }
        fn flush(&mut self) -> io::Result<()> {
            Ok(())
        }
    }
    let mut serial = NoisyPort(0);
    let started = std::time::Instant::now();
    let result = discover_owned(
        &mut serial,
        DiscoveryTiming {
            settle: Duration::ZERO,
            read_timeout: Duration::from_millis(3),
            attempts: 5,
        },
        Duration::from_millis(15),
        || false,
    );
    assert!(matches!(result, Err(DiscoveryError::DeadlineExceeded)));
    assert!(started.elapsed() < Duration::from_millis(250));
    assert!(serial.0 > 0);
}

struct ConfigPortFake {
    generation: u64,
    replies: VecDeque<Message>,
    sent: Vec<Message>,
}
impl ConfigurationPort for ConfigPortFake {
    fn generation(&self) -> u64 {
        self.generation
    }
    fn send(&mut self, message: &Message) -> Result<(), String> {
        self.sent.push(message.clone());
        Ok(())
    }
    fn receive(&mut self, _timeout: Duration) -> Result<Option<Message>, String> {
        Ok(self.replies.pop_front())
    }
}
struct ConfigRepoFake {
    fail: bool,
    confirmed: usize,
}
impl ConfigurationRepository for ConfigRepoFake {
    fn confirm_configuration(
        &mut self,
        _device_id: EntityId,
        _config_id: ConfigId,
    ) -> Result<(), String> {
        self.confirmed += 1;
        if self.fail {
            Err("database unavailable".into())
        } else {
            Ok(())
        }
    }
}

#[test]
fn configuration_persistence_precedes_success_publication_and_route_activation() {
    let config = ConfigId::new(55).unwrap();
    let device = EntityId(3);
    let input = InputIdentity {
        device_id: device,
        input_id: EntityId(4),
    };
    let mut port = ConfigPortFake {
        generation: 9,
        replies: VecDeque::from([Message::ConfigurationStored {
            config_id: config.get(),
        }]),
        sent: Vec::new(),
    };
    let mut repo = ConfigRepoFake {
        fail: true,
        confirmed: 0,
    };
    let resolver = InputResolver::default();
    let cache = InputValueCache::default();
    let mut published = false;
    let result = apply_configuration(
        &mut port,
        &mut repo,
        &resolver,
        &cache,
        ConfigurationApply {
            port_name: "COM1".into(),
            generation: 9,
            device_id: device,
            config_id: config,
            messages: vec![Message::ConfigureButton {
                config_id: config.get(),
                total_parts: 1,
                part_number: 0,
                pin: 2,
                debounce: 5,
            }],
            mappings: [(2, input)],
            timeout: Duration::from_millis(10),
        },
        || {
            published = true;
            Ok(())
        },
    );
    assert!(matches!(result, Err(ApplyError::Persist(_))));
    assert!(!published);
    assert_eq!(resolver.resolve("COM1", 9, config, 2), None);
}

#[test]
fn stale_configuration_ack_is_ignored_and_success_routes_only_after_persist() {
    let config = ConfigId::new(56).unwrap();
    let device = EntityId(3);
    let input = InputIdentity {
        device_id: device,
        input_id: EntityId(4),
    };
    let mut port = ConfigPortFake {
        generation: 12,
        replies: VecDeque::from([
            Message::ConfigurationStored {
                config_id: config.get() + 1,
            },
            Message::ConfigurationStored {
                config_id: config.get(),
            },
        ]),
        sent: Vec::new(),
    };
    let mut repo = ConfigRepoFake {
        fail: false,
        confirmed: 0,
    };
    let resolver = InputResolver::default();
    let cache = InputValueCache::default();
    let mut published = false;
    apply_configuration(
        &mut port,
        &mut repo,
        &resolver,
        &cache,
        ConfigurationApply {
            port_name: "COM5".into(),
            generation: 12,
            device_id: device,
            config_id: config,
            messages: vec![Message::ConfigureButton {
                config_id: config.get(),
                total_parts: 1,
                part_number: 0,
                pin: 7,
                debounce: 5,
            }],
            mappings: [(7, input)],
            timeout: Duration::from_millis(50),
        },
        || {
            published = true;
            Ok(())
        },
    )
    .unwrap();
    assert_eq!(repo.confirmed, 1);
    assert!(published);
    assert_eq!(resolver.resolve("COM5", 12, config, 7), Some(input));
    assert!(cache.update("COM5", 12, 7, 1));
}

#[test]
fn calibration_uses_legacy_minimum_counts_and_reports_bounded_sample_overflow() {
    let mut session =
        CalibrationSession::with_capacity(SessionId(1), EntityId(4), "COM1".into(), 3, 2, 1023, 2);
    assert_eq!(session.advance().unwrap(), None);
    for value in [1, 2] {
        session.observe(3, 2, value).unwrap();
    }
    assert_eq!(session.observe(3, 2, 3), Err(SessionError::Overflow));
    assert_eq!(session.step(), CalibrationStep::Overflowed);
}

#[test]
fn draining_calibration_notifications_does_not_unbound_retained_analysis_samples() {
    let mut session =
        CalibrationSession::with_capacity(SessionId(3), EntityId(4), "COM1".into(), 3, 2, 1023, 2);
    session.advance().unwrap();
    session.observe(3, 2, 1).unwrap();
    session.take_sample_event().unwrap();
    session.observe(3, 2, 2).unwrap();
    session.take_sample_event().unwrap();
    assert_eq!(session.observe(3, 2, 3), Err(SessionError::Overflow));
}

struct CalibrationRepoFake(usize);
impl CalibrationRepository for CalibrationRepoFake {
    fn persist_calibration(
        &mut self,
        _input_id: EntityId,
        _calibration: trenino_core::hardware::calibration::Calibration,
    ) -> Result<(), String> {
        self.0 += 1;
        Ok(())
    }
}

#[test]
fn calibration_persists_only_after_legacy_collection_steps_complete() {
    let mut session = CalibrationSession::new(SessionId(2), EntityId(4), "COM1".into(), 3, 2, 1023);
    let mut repository = CalibrationRepoFake(0);
    session.advance().unwrap();
    for value in [10, 11, 12, 13, 14, 15, 16, 17, 18, 19] {
        session.observe(3, 2, value).unwrap();
    }
    session.advance().unwrap();
    for value in 0..10 {
        session.observe(3, 2, value * 10).unwrap();
    }
    session.advance().unwrap();
    for value in [900, 901, 902, 903, 904, 905, 906, 907, 908, 909] {
        session.observe(3, 2, value).unwrap();
    }
    assert!(session
        .advance_and_persist(&mut repository)
        .unwrap()
        .is_some());
    assert_eq!(repository.0, 1);
    let result = session.terminal_result();
    session.cancel();
    assert_eq!(session.step(), CalibrationStep::Complete);
    assert_eq!(session.terminal_result(), result);
}

#[test]
fn calibration_persistence_failure_is_retained_as_terminal_operation_result() {
    struct FailingCalibrationRepository;
    impl CalibrationRepository for FailingCalibrationRepository {
        fn persist_calibration(
            &mut self,
            _input_id: EntityId,
            _calibration: trenino_core::hardware::calibration::Calibration,
        ) -> Result<(), String> {
            Err("save failed".into())
        }
    }
    let mut session = CalibrationSession::new(SessionId(4), EntityId(4), "COM1".into(), 3, 2, 1023);
    session.advance().unwrap();
    for value in 10..20 {
        session.observe(3, 2, value).unwrap();
    }
    session.advance().unwrap();
    for value in 0..10 {
        session.observe(3, 2, value * 10).unwrap();
    }
    session.advance().unwrap();
    for value in 900..910 {
        session.observe(3, 2, value).unwrap();
    }
    assert_eq!(
        session.advance_and_persist(&mut FailingCalibrationRepository),
        Err(SessionError::Persist("save failed".into()))
    );
    assert_eq!(
        session.terminal_result(),
        Some(Err(SessionError::Persist("save failed".into())))
    );
}

#[test]
fn input_detection_uses_baseline_then_legacy_button_and_analog_thresholds() {
    let identity = InputIdentity {
        device_id: EntityId(1),
        input_id: EntityId(2),
    };
    let mut button = InputDetectionSession::new(InputKind::Button, Duration::from_secs(1));
    assert_eq!(
        button.observe("COM1", 2, 0, InputKind::Button, Some(identity)),
        DetectionOutcome::Pending
    );
    assert_eq!(
        button.observe("COM1", 2, 1, InputKind::Button, Some(identity)),
        DetectionOutcome::Detected {
            identity,
            pin: 2,
            value: 1
        }
    );
    let mut analog = InputDetectionSession::new(InputKind::Analog, Duration::from_secs(1));
    analog.observe("COM1", 3, 100, InputKind::Analog, Some(identity));
    assert_eq!(
        analog.observe("COM1", 3, 150, InputKind::Analog, Some(identity)),
        DetectionOutcome::Pending
    );
    assert!(matches!(
        analog.observe("COM1", 3, 151, InputKind::Analog, Some(identity)),
        DetectionOutcome::Detected { .. }
    ));
}

#[test]
fn owned_detection_times_out_autonomously_and_retains_terminal_success() {
    let sessions = HardwareSessions::default();
    let detection = sessions
        .insert_detection(
            SessionId(77),
            InputDetectionSession::new(InputKind::Button, Duration::from_millis(30)),
        )
        .unwrap();
    for _ in 0..100 {
        if detection.lock().unwrap().terminal_outcome().is_some() {
            break;
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    assert_eq!(
        detection.lock().unwrap().terminal_outcome(),
        Some(DetectionOutcome::TimedOut)
    );
    assert!(sessions.reap_terminal(SessionId(77)));
    assert!(sessions.detection(SessionId(77)).is_none());

    let id = InputIdentity {
        device_id: EntityId(1),
        input_id: EntityId(2),
    };
    let mut success = InputDetectionSession::new(InputKind::Button, Duration::from_secs(1));
    success.bind_source("COM9", 4);
    success.observe_generation("COM9", 4, 2, 0, InputKind::Button, Some(id));
    assert!(matches!(
        success.observe_generation("COM9", 4, 2, 1, InputKind::Button, Some(id)),
        DetectionOutcome::Detected { .. }
    ));
    success.cancel();
    assert!(matches!(
        success.terminal_outcome(),
        Some(DetectionOutcome::Detected { .. })
    ));
    sessions.shutdown();
}

#[test]
fn source_loss_terminates_only_matching_detection_generation() {
    let registry = HardwareSessions::default();
    let mut session = InputDetectionSession::new(InputKind::Button, Duration::from_secs(1));
    session.bind_source("COM8", 5);
    let session = registry.insert_detection(SessionId(78), session).unwrap();
    registry.source_lost("COM8", 4);
    assert_eq!(session.lock().unwrap().terminal_outcome(), None);
    registry.source_lost("COM8", 5);
    assert_eq!(
        session.lock().unwrap().terminal_outcome(),
        Some(DetectionOutcome::SourceLost)
    );
}

#[test]
fn owned_session_survives_dropped_ui_handle_and_shutdown_cancels_pending_work() {
    let sessions = HardwareSessions::default();
    let ui_handle = sessions
        .insert_detection(
            SessionId(44),
            InputDetectionSession::new(InputKind::Any, Duration::from_secs(60)),
        )
        .unwrap();
    drop(ui_handle);
    let owned = sessions.detection(SessionId(44)).unwrap();
    sessions.shutdown();
    assert_eq!(
        owned
            .lock()
            .unwrap()
            .observe("COM4", 1, 0, InputKind::Button, None),
        DetectionOutcome::Cancelled
    );
}

struct FakeTransport {
    enumerations: AtomicUsize,
}

struct NoopResourceConsumers;
impl ResourceConsumers for NoopResourceConsumers {
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
struct FakeOwnedPort {
    reads: VecDeque<Vec<u8>>,
}
impl SerialIo for FakeOwnedPort {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        let Some(bytes) = self.reads.pop_front() else {
            return Err(io::ErrorKind::TimedOut.into());
        };
        buffer[..bytes.len()].copy_from_slice(&bytes);
        Ok(bytes.len())
    }
    fn write_all(&mut self, bytes: &[u8]) -> io::Result<()> {
        let payload = FrameDecoder::default().push(bytes).remove(0).unwrap();
        if let Message::IdentityRequest { request_id } = decode_message(&payload).unwrap() {
            let reply = encode_message(&Message::IdentityResponse {
                request_id,
                major: 1,
                minor: 0,
                patch: 0,
                config_id: 0,
            })
            .unwrap();
            self.reads.push_back(FrameDecoder::encode_frame(&reply));
        }
        Ok(())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}
impl SerialTransport for FakeTransport {
    fn enumerate(&self) -> io::Result<Vec<String>> {
        self.enumerations.fetch_add(1, Ordering::SeqCst);
        Ok(vec!["COM42".into(), "Bluetooth debug".into()])
    }
    fn open(&self, _port: &str, _baud: u32, _timeout: Duration) -> io::Result<Box<dyn SerialIo>> {
        Ok(Box::new(FakeOwnedPort {
            reads: VecDeque::new(),
        }))
    }
}

#[test]
fn runtime_is_inert_until_started_then_discovers_owned_port_and_joins_on_shutdown() {
    let transport = Arc::new(FakeTransport {
        enumerations: AtomicUsize::new(0),
    });
    let runtime = Arc::new(
        HardwareRuntime::new(
            transport.clone(),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
        )
        .with_policy(
            Duration::from_secs(60),
            Duration::from_secs(30),
            Duration::from_secs(5),
        ),
    );
    assert_eq!(runtime.enumerate_ports().unwrap(), vec!["COM42"]);
    assert_eq!(transport.enumerations.load(Ordering::SeqCst), 1);
    let (events, receive) = mpsc::channel();
    let mut handle = runtime.start(move |event| {
        let _ = events.send(event);
    });
    handle.scan_now().unwrap();
    let found = receive.recv_timeout(Duration::from_secs(2)).unwrap();
    let generation = match found {
        PortEvent::Discovered {
            port, generation, ..
        } => {
            assert_eq!(port, "COM42");
            generation
        }
        other => panic!("unexpected event: {other:?}"),
    };
    assert!(generation > 0);
    handle
        .send_message(
            "COM42",
            generation,
            Message::Heartbeat,
            Duration::from_millis(100),
        )
        .unwrap();
    let arbiter = ResourceArbiter::new(Arc::new(NoopResourceConsumers));
    let lease = arbiter
        .acquire(LeaseKind::Firmware {
            port: "COM42".into(),
            generation,
        })
        .unwrap();
    let permit = arbiter.firmware_handoff_permit(lease).unwrap();
    assert!(handle
        .begin_handoff("COM42", generation + 1, &permit)
        .is_err());
    let operation = handle.begin_handoff("COM42", generation, &permit).unwrap();
    let handoff = handle
        .wait_handoff(operation, Duration::from_secs(2))
        .unwrap()
        .unwrap();
    assert_eq!(handoff.generation(), generation);
    assert!(
        matches!(receive.recv_timeout(Duration::from_secs(2)).unwrap(), PortEvent::Closed { generation: closed, .. } if closed == generation)
    );
    let release = handle.begin_release_handoff(handoff, &permit).unwrap();
    loop {
        if let Some(result) = handle.release_result(release) {
            result.unwrap();
            break;
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    arbiter.release(lease).unwrap();
    let reconnected = receive.recv_timeout(Duration::from_secs(2)).unwrap();
    let next_generation = match reconnected {
        PortEvent::Discovered { generation, .. } => generation,
        other => panic!("unexpected event after handoff: {other:?}"),
    };
    assert!(next_generation > generation);
    assert!(handle
        .send_message(
            "COM42",
            generation,
            Message::Heartbeat,
            Duration::from_millis(100),
        )
        .is_err());
    handle.shutdown().unwrap();
    assert!(receive.try_iter().any(|event| matches!(event, PortEvent::Closed { generation: closed, .. } if closed == next_generation)));
}

#[test]
fn handoff_reservation_cannot_be_overwritten_and_timed_out_wait_is_recoverable() {
    let transport = Arc::new(FakeTransport {
        enumerations: AtomicUsize::new(0),
    });
    let runtime = Arc::new(
        HardwareRuntime::new(
            transport,
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
        )
        .with_policy(
            Duration::from_secs(60),
            Duration::from_secs(1),
            Duration::from_secs(1),
        ),
    );
    let (events, receive) = mpsc::channel();
    let mut handle = runtime.start(move |event| {
        let _ = events.send(event);
    });
    handle.scan_now().unwrap();
    let generation = match receive.recv_timeout(Duration::from_secs(1)).unwrap() {
        PortEvent::Discovered { generation, .. } => generation,
        other => panic!("unexpected event: {other:?}"),
    };
    let arbiter = ResourceArbiter::new(Arc::new(NoopResourceConsumers));
    let lease = arbiter
        .acquire(LeaseKind::Firmware {
            port: "COM42".into(),
            generation,
        })
        .unwrap();
    let permit = arbiter.firmware_handoff_permit(lease).unwrap();
    let operation = handle.begin_handoff("COM42", generation, &permit).unwrap();
    assert!(handle.wait_handoff(operation, Duration::ZERO).is_none());
    let handoff = handle
        .wait_handoff(operation, Duration::from_secs(1))
        .unwrap()
        .unwrap();
    let second = handle.begin_handoff("COM42", generation, &permit).unwrap();
    assert_eq!(
        handle.wait_handoff(second, Duration::from_secs(1)).unwrap(),
        Err("port is already reserved".into())
    );
    let release = handle.begin_release_handoff(handoff, &permit).unwrap();
    loop {
        if let Some(result) = handle.release_result(release) {
            result.unwrap();
            break;
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    arbiter.release(lease).unwrap();
    handle.shutdown().unwrap();
}

#[test]
fn shutdown_waits_for_firmware_reservation_release_and_remains_retryable() {
    let transport = Arc::new(FakeTransport {
        enumerations: AtomicUsize::new(0),
    });
    let runtime = Arc::new(
        HardwareRuntime::new(
            transport,
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
        )
        .with_policy(
            Duration::from_secs(60),
            Duration::from_secs(1),
            Duration::from_millis(20),
        ),
    );
    let (events, receive) = mpsc::channel();
    let mut handle = runtime.start(move |event| {
        let _ = events.send(event);
    });
    handle.scan_now().unwrap();
    let generation = loop {
        if let PortEvent::Discovered { generation, .. } =
            receive.recv_timeout(Duration::from_secs(1)).unwrap()
        {
            break generation;
        }
    };
    let arbiter = ResourceArbiter::new(Arc::new(NoopResourceConsumers));
    let lease = arbiter
        .acquire(LeaseKind::Firmware {
            port: "COM42".into(),
            generation,
        })
        .unwrap();
    let permit = arbiter.firmware_handoff_permit(lease).unwrap();
    let operation = handle.begin_handoff("COM42", generation, &permit).unwrap();
    let handoff = handle
        .wait_handoff(operation, Duration::from_secs(1))
        .unwrap()
        .unwrap();
    assert!(handle.shutdown().is_err());
    let release = handle.begin_release_handoff(handoff, &permit).unwrap();
    loop {
        if let Some(result) = handle.release_result(release) {
            result.unwrap();
            break;
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    arbiter.release(lease).unwrap();
    handle.shutdown().unwrap();
}

struct BlockingOwnerTransport {
    unblock: Arc<AtomicBool>,
    entered: Arc<AtomicBool>,
    drops: Arc<AtomicUsize>,
}
struct BlockingOwnerPort {
    reads: VecDeque<Vec<u8>>,
    unblock: Arc<AtomicBool>,
    entered: Arc<AtomicBool>,
    drops: Arc<AtomicUsize>,
    discovered: bool,
}
impl Drop for BlockingOwnerPort {
    fn drop(&mut self) {
        self.drops.fetch_add(1, Ordering::SeqCst);
    }
}
impl SerialIo for BlockingOwnerPort {
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
        let Message::IdentityRequest { request_id } = decode_message(&payload).unwrap() else {
            return Ok(());
        };
        let response = encode_message(&Message::IdentityResponse {
            request_id,
            major: 1,
            minor: 0,
            patch: 0,
            config_id: 1,
        })
        .unwrap();
        self.reads.push_back(FrameDecoder::encode_frame(&response));
        Ok(())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}
impl SerialTransport for BlockingOwnerTransport {
    fn enumerate(&self) -> io::Result<Vec<String>> {
        Ok(vec!["BLOCKED".into()])
    }
    fn open(&self, _port: &str, _baud: u32, _timeout: Duration) -> io::Result<Box<dyn SerialIo>> {
        Ok(Box::new(BlockingOwnerPort {
            reads: VecDeque::new(),
            unblock: self.unblock.clone(),
            entered: self.entered.clone(),
            drops: self.drops.clone(),
            discovered: false,
        }))
    }
}

#[test]
fn shutdown_timeout_retains_worker_and_can_be_retried_after_cleanup() {
    let transport = Arc::new(BlockingOwnerTransport {
        unblock: Arc::new(AtomicBool::new(true)),
        entered: Arc::new(AtomicBool::new(false)),
        drops: Arc::new(AtomicUsize::new(0)),
    });
    let runtime = Arc::new(
        HardwareRuntime::new(
            transport.clone(),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
        )
        .with_policy(
            Duration::from_secs(60),
            Duration::from_secs(1),
            Duration::from_millis(20),
        ),
    );
    let (events, receive) = mpsc::channel();
    let mut handle = runtime.start(move |event| {
        let _ = events.send(event);
    });
    handle.scan_now().unwrap();
    assert!(matches!(
        receive.recv_timeout(Duration::from_secs(1)).unwrap(),
        PortEvent::Discovered { .. }
    ));
    for _ in 0..100 {
        if transport.entered.load(Ordering::SeqCst) {
            break;
        }
        std::thread::sleep(Duration::from_millis(1));
    }
    assert!(transport.entered.load(Ordering::SeqCst));
    assert!(handle.shutdown().is_err());
    assert_eq!(transport.drops.load(Ordering::SeqCst), 0);
    transport.unblock.store(false, Ordering::SeqCst);
    handle.shutdown().unwrap();
    assert_eq!(transport.drops.load(Ordering::SeqCst), 1);
}

struct RecoveryTransport;
struct RecoveryPort(VecDeque<Vec<u8>>);
impl SerialTransport for RecoveryTransport {
    fn enumerate(&self) -> io::Result<Vec<String>> {
        Ok(vec!["RECOVER".into()])
    }
    fn open(&self, _port: &str, _baud: u32, _timeout: Duration) -> io::Result<Box<dyn SerialIo>> {
        Ok(Box::new(RecoveryPort(VecDeque::new())))
    }
}
impl SerialIo for RecoveryPort {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        let Some(bytes) = self.0.pop_front() else {
            return Err(io::ErrorKind::TimedOut.into());
        };
        let count = bytes.len().min(buffer.len());
        buffer[..count].copy_from_slice(&bytes[..count]);
        if count < bytes.len() {
            self.0.push_front(bytes[count..].to_vec());
        }
        Ok(count)
    }
    fn write_all(&mut self, bytes: &[u8]) -> io::Result<()> {
        let request =
            decode_message(&FrameDecoder::default().push(bytes).remove(0).unwrap()).unwrap();
        let Message::IdentityRequest { request_id } = request else {
            unreachable!()
        };
        let mut stream = FrameDecoder::encode_frame(
            &encode_message(&Message::IdentityResponse {
                request_id,
                major: 1,
                minor: 0,
                patch: 0,
                config_id: 1,
            })
            .unwrap(),
        );
        stream.extend(std::iter::repeat_n(1, 524));
        stream.push(0);
        stream.extend(FrameDecoder::encode_frame(
            &encode_message(&Message::InputValue { pin: 3, value: 77 }).unwrap(),
        ));
        self.0.extend(stream.chunks(512).map(<[u8]>::to_vec));
        Ok(())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

#[test]
fn malformed_overflow_reports_error_and_worker_processes_resynchronized_input() {
    let runtime = Arc::new(
        HardwareRuntime::new(
            Arc::new(RecoveryTransport),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
        )
        .with_policy(
            Duration::from_secs(60),
            Duration::from_secs(1),
            Duration::from_secs(1),
        ),
    );
    let (events, receive) = mpsc::channel();
    let mut handle = runtime.start(move |event| {
        let _ = events.send(event);
    });
    handle.scan_now().unwrap();
    let generation = loop {
        if let PortEvent::Discovered { generation, .. } =
            receive.recv_timeout(Duration::from_secs(1)).unwrap()
        {
            break generation;
        }
    };
    let mut saw_protocol_error = false;
    let mut saw_input = false;
    for _ in 0..10 {
        match receive.recv_timeout(Duration::from_secs(1)).unwrap() {
            PortEvent::ProtocolError {
                generation: event_generation,
                ..
            } => {
                assert_eq!(event_generation, generation);
                saw_protocol_error = true;
            }
            PortEvent::Message {
                generation: event_generation,
                message: Message::InputValue { pin: 3, value: 77 },
                ..
            } => {
                assert_eq!(event_generation, generation);
                saw_input = true;
                break;
            }
            _ => {}
        }
    }
    assert!(saw_protocol_error);
    assert!(saw_input);
    handle.shutdown().unwrap();
}

struct BlockingWriteTransport {
    block: Arc<AtomicBool>,
    entered: Arc<AtomicBool>,
}
struct BlockingWritePort {
    reads: VecDeque<Vec<u8>>,
    block: Arc<AtomicBool>,
    entered: Arc<AtomicBool>,
}
impl SerialTransport for BlockingWriteTransport {
    fn enumerate(&self) -> io::Result<Vec<String>> {
        Ok(vec!["WRITE-BLOCK".into()])
    }
    fn open(&self, _port: &str, _baud: u32, _timeout: Duration) -> io::Result<Box<dyn SerialIo>> {
        Ok(Box::new(BlockingWritePort {
            reads: VecDeque::new(),
            block: self.block.clone(),
            entered: self.entered.clone(),
        }))
    }
}
impl SerialIo for BlockingWritePort {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        let Some(bytes) = self.reads.pop_front() else {
            return Err(io::ErrorKind::TimedOut.into());
        };
        buffer[..bytes.len()].copy_from_slice(&bytes);
        Ok(bytes.len())
    }
    fn write_all(&mut self, bytes: &[u8]) -> io::Result<()> {
        let message =
            decode_message(&FrameDecoder::default().push(bytes).remove(0).unwrap()).unwrap();
        if let Message::IdentityRequest { request_id } = message {
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
        } else {
            self.entered.store(true, Ordering::SeqCst);
            while self.block.load(Ordering::SeqCst) {
                std::thread::sleep(Duration::from_millis(1));
            }
        }
        Ok(())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}

#[test]
fn blocked_write_applies_bounded_command_backpressure() {
    let transport = Arc::new(BlockingWriteTransport {
        block: Arc::new(AtomicBool::new(true)),
        entered: Arc::new(AtomicBool::new(false)),
    });
    let runtime = Arc::new(
        HardwareRuntime::new(
            transport.clone(),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
        )
        .with_policy(
            Duration::from_secs(60),
            Duration::from_secs(1),
            Duration::from_millis(20),
        ),
    );
    let (events, receive) = mpsc::channel();
    let handle = runtime.start(move |event| {
        let _ = events.send(event);
    });
    handle.scan_now().unwrap();
    let generation = loop {
        if let PortEvent::Discovered { generation, .. } =
            receive.recv_timeout(Duration::from_secs(1)).unwrap()
        {
            break generation;
        }
    };
    let handle = Arc::new(handle);
    let first_handle = handle.clone();
    let first = std::thread::spawn(move || {
        first_handle.send_message(
            "WRITE-BLOCK",
            generation,
            Message::Heartbeat,
            Duration::from_secs(2),
        )
    });
    for _ in 0..100 {
        if transport.entered.load(Ordering::SeqCst) {
            break;
        }
        std::thread::sleep(Duration::from_millis(1));
    }
    assert!(transport.entered.load(Ordering::SeqCst));
    let mut callers = Vec::new();
    for _ in 0..80 {
        let handle = handle.clone();
        callers.push(std::thread::spawn(move || {
            handle.send_message(
                "WRITE-BLOCK",
                generation,
                Message::Heartbeat,
                Duration::from_millis(100),
            )
        }));
    }
    let outcomes = callers
        .into_iter()
        .map(|caller| caller.join().unwrap())
        .collect::<Vec<_>>();
    assert!(outcomes.iter().any(|result| result
        .as_ref()
        .is_err_and(|error| error == "runtime command queue is full")));
    transport.block.store(false, Ordering::SeqCst);
    let _ = first.join().unwrap();
    let mut handle = Arc::try_unwrap(handle)
        .ok()
        .expect("command handle references must be released");
    handle.shutdown().unwrap();
}

#[test]
fn queued_handoff_pin_blocks_lease_release_until_reservation_released() {
    let transport = Arc::new(BlockingWriteTransport {
        block: Arc::new(AtomicBool::new(true)),
        entered: Arc::new(AtomicBool::new(false)),
    });
    let runtime = Arc::new(
        HardwareRuntime::new(
            transport.clone(),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
        )
        .with_policy(
            Duration::from_secs(60),
            Duration::from_secs(1),
            Duration::from_secs(1),
        ),
    );
    let (events, receive) = mpsc::channel();
    let handle = Arc::new(runtime.start(move |event| {
        let _ = events.send(event);
    }));
    handle.scan_now().unwrap();
    let generation = loop {
        if let PortEvent::Discovered { generation, .. } =
            receive.recv_timeout(Duration::from_secs(1)).unwrap()
        {
            break generation;
        }
    };
    drop(receive);
    let arbiter = ResourceArbiter::new(Arc::new(NoopResourceConsumers));
    let lease = arbiter
        .acquire(LeaseKind::Firmware {
            port: "WRITE-BLOCK".into(),
            generation,
        })
        .unwrap();
    let permit = arbiter.firmware_handoff_permit(lease).unwrap();
    // A blocked write keeps the scanner busy, so the handoff command stays queued.
    let sender = {
        let handle = handle.clone();
        std::thread::spawn(move || {
            handle.send_message(
                "WRITE-BLOCK",
                generation,
                Message::Heartbeat,
                Duration::from_secs(5),
            )
        })
    };
    for _ in 0..500 {
        if transport.entered.load(Ordering::SeqCst) {
            break;
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    assert!(transport.entered.load(Ordering::SeqCst));
    let operation = handle
        .begin_handoff("WRITE-BLOCK", generation, &permit)
        .unwrap();
    assert!(
        handle.wait_handoff(operation, Duration::ZERO).is_none(),
        "handoff must still be queued behind the blocked scanner"
    );
    // The queued handoff's lease pin prevents premature lease release.
    assert!(matches!(
        arbiter.release(lease),
        Err(trenino_runtime::resource::ResourceError::Busy)
    ));
    transport.block.store(false, Ordering::SeqCst);
    sender.join().unwrap().unwrap();
    let handoff = handle
        .wait_handoff(operation, Duration::from_secs(2))
        .unwrap()
        .unwrap();
    // The live reservation keeps the lease pinned until the handoff is released.
    assert!(matches!(
        arbiter.release(lease),
        Err(trenino_runtime::resource::ResourceError::Busy)
    ));
    let release = handle.begin_release_handoff(handoff, &permit).unwrap();
    loop {
        if let Some(result) = handle.release_result(release) {
            result.unwrap();
            break;
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    arbiter.release(lease).unwrap();
    let mut handle = Arc::try_unwrap(handle)
        .ok()
        .expect("handle references must be released");
    handle.shutdown().unwrap();
}

struct BlockedOpenTransport {
    unblock: Arc<AtomicBool>,
    entered: Arc<AtomicBool>,
    opens: Arc<AtomicUsize>,
}
struct NeverRespondingPort;
impl SerialIo for NeverRespondingPort {
    fn read(&mut self, _buffer: &mut [u8]) -> io::Result<usize> {
        Err(io::ErrorKind::TimedOut.into())
    }
    fn write_all(&mut self, _bytes: &[u8]) -> io::Result<()> {
        Ok(())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}
impl SerialTransport for BlockedOpenTransport {
    fn enumerate(&self) -> io::Result<Vec<String>> {
        Ok(vec!["BLOCKED-OPEN".into()])
    }
    fn open(&self, _port: &str, _baud: u32, _timeout: Duration) -> io::Result<Box<dyn SerialIo>> {
        self.entered.store(true, Ordering::SeqCst);
        while self.unblock.load(Ordering::SeqCst) {
            std::thread::sleep(Duration::from_millis(1));
        }
        self.opens.fetch_add(1, Ordering::SeqCst);
        Ok(Box::new(NeverRespondingPort))
    }
}

#[test]
fn discovery_coordinator_deadline_reports_blocked_open_and_retains_owner() {
    let transport = Arc::new(BlockedOpenTransport {
        unblock: Arc::new(AtomicBool::new(true)),
        entered: Arc::new(AtomicBool::new(false)),
        opens: Arc::new(AtomicUsize::new(0)),
    });
    let runtime = Arc::new(
        HardwareRuntime::new(
            transport.clone(),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
        )
        .with_policy(
            Duration::from_secs(60),
            Duration::from_secs(1),
            Duration::from_millis(200),
        )
        .with_discovery_timeout(Duration::from_millis(150)),
    );
    let (events, receive) = mpsc::channel();
    let mut handle = runtime.start(move |event| {
        let _ = events.send(event);
    });
    handle.scan_now().unwrap();
    for _ in 0..100 {
        if transport.entered.load(Ordering::SeqCst) {
            break;
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    assert!(transport.entered.load(Ordering::SeqCst));
    // The coordinator reports its deadline although the native open never returned.
    let started = std::time::Instant::now();
    let mut saw_deadline = false;
    while !saw_deadline {
        let event = receive
            .recv_timeout(Duration::from_secs(2))
            .expect("no discovery event was reported");
        if let PortEvent::Failed { reason, .. } = &event {
            if reason.contains("discovery coordinator deadline exceeded") {
                saw_deadline = true;
            }
        }
    }
    assert!(started.elapsed() < Duration::from_secs(2));
    assert_eq!(
        transport.opens.load(Ordering::SeqCst),
        0,
        "the owner must be retained while its open is blocked"
    );
    transport.unblock.store(false, Ordering::SeqCst);
    handle.shutdown().unwrap();
}

struct BlockedFlushTransport {
    unblock: Arc<AtomicBool>,
    entered: Arc<AtomicBool>,
}
struct BlockedFlushPort {
    reads: VecDeque<Vec<u8>>,
    unblock: Arc<AtomicBool>,
    entered: Arc<AtomicBool>,
    wrote_identity: bool,
}
impl SerialTransport for BlockedFlushTransport {
    fn enumerate(&self) -> io::Result<Vec<String>> {
        Ok(vec!["BLOCKED-FLUSH".into()])
    }
    fn open(&self, _port: &str, _baud: u32, _timeout: Duration) -> io::Result<Box<dyn SerialIo>> {
        Ok(Box::new(BlockedFlushPort {
            reads: VecDeque::new(),
            unblock: self.unblock.clone(),
            entered: self.entered.clone(),
            wrote_identity: false,
        }))
    }
}
impl SerialIo for BlockedFlushPort {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        let Some(bytes) = self.reads.pop_front() else {
            return Err(io::ErrorKind::TimedOut.into());
        };
        buffer[..bytes.len()].copy_from_slice(&bytes);
        Ok(bytes.len())
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
            self.wrote_identity = true;
        }
        Ok(())
    }
    fn flush(&mut self) -> io::Result<()> {
        if self.wrote_identity {
            self.entered.store(true, Ordering::SeqCst);
            while self.unblock.load(Ordering::SeqCst) {
                std::thread::sleep(Duration::from_millis(1));
            }
        }
        Ok(())
    }
}

#[test]
fn discovery_coordinator_deadline_covers_blocked_flush_after_identity_request() {
    let transport = Arc::new(BlockedFlushTransport {
        unblock: Arc::new(AtomicBool::new(true)),
        entered: Arc::new(AtomicBool::new(false)),
    });
    let runtime = Arc::new(
        HardwareRuntime::new(
            transport.clone(),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
        )
        .with_policy(
            Duration::from_secs(60),
            Duration::from_secs(1),
            Duration::from_millis(200),
        )
        .with_discovery_timeout(Duration::from_millis(150)),
    );
    let (events, receive) = mpsc::channel();
    let mut handle = runtime.start(move |event| {
        let _ = events.send(event);
    });
    handle.scan_now().unwrap();
    for _ in 0..100 {
        if transport.entered.load(Ordering::SeqCst) {
            break;
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    assert!(transport.entered.load(Ordering::SeqCst));
    let started = std::time::Instant::now();
    let mut saw_deadline = false;
    while !saw_deadline {
        let event = receive
            .recv_timeout(Duration::from_secs(2))
            .expect("no discovery event was reported");
        if let PortEvent::Failed { reason, .. } = &event {
            if reason.contains("discovery coordinator deadline exceeded") {
                saw_deadline = true;
            }
        }
    }
    assert!(started.elapsed() < Duration::from_secs(2));
    transport.unblock.store(false, Ordering::SeqCst);
    handle.shutdown().unwrap();
}

struct PanicTwoPortTransport {
    drop_panic: Arc<AtomicBool>,
    panic_read_started: Arc<AtomicBool>,
}
struct PanicPort {
    reads: VecDeque<Vec<u8>>,
    panic_read_started: Arc<AtomicBool>,
    wrote_identity: bool,
}
struct OkayPort {
    reads: VecDeque<Vec<u8>>,
}
impl SerialTransport for PanicTwoPortTransport {
    fn enumerate(&self) -> io::Result<Vec<String>> {
        Ok(if self.drop_panic.load(Ordering::SeqCst) {
            vec!["OKAY".into()]
        } else {
            vec!["OKAY".into(), "PANIC".into()]
        })
    }
    fn open(&self, port: &str, _baud: u32, _timeout: Duration) -> io::Result<Box<dyn SerialIo>> {
        Ok(if port == "PANIC" {
            Box::new(PanicPort {
                reads: VecDeque::new(),
                panic_read_started: self.panic_read_started.clone(),
                wrote_identity: false,
            })
        } else {
            Box::new(OkayPort {
                reads: VecDeque::new(),
            })
        })
    }
}
impl SerialIo for PanicPort {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        if let Some(bytes) = self.reads.pop_front() {
            buffer[..bytes.len()].copy_from_slice(&bytes);
            return Ok(bytes.len());
        }
        if !self.wrote_identity {
            return Err(io::ErrorKind::TimedOut.into());
        }
        // Discovery consumed the identity response; the owned read loop panics.
        self.panic_read_started.store(true, Ordering::SeqCst);
        panic!("injected serial reader panic");
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
            self.wrote_identity = true;
        }
        Ok(())
    }
    fn flush(&mut self) -> io::Result<()> {
        Ok(())
    }
}
impl SerialIo for OkayPort {
    fn read(&mut self, buffer: &mut [u8]) -> io::Result<usize> {
        let Some(bytes) = self.reads.pop_front() else {
            return Err(io::ErrorKind::TimedOut.into());
        };
        buffer[..bytes.len()].copy_from_slice(&bytes);
        Ok(bytes.len())
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
fn joined_worker_panic_is_reported_without_retry_and_other_owners_survive() {
    let transport = Arc::new(PanicTwoPortTransport {
        drop_panic: Arc::new(AtomicBool::new(false)),
        panic_read_started: Arc::new(AtomicBool::new(false)),
    });
    let runtime = Arc::new(
        HardwareRuntime::new(
            transport.clone(),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
        )
        .with_policy(
            Duration::from_secs(60),
            Duration::from_secs(1),
            Duration::from_millis(200),
        ),
    );
    let (events, receive) = mpsc::channel();
    let mut handle = runtime.start(move |event| {
        let _ = events.send(event);
    });
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let mut okay_generation = None;
    while okay_generation.is_none() {
        assert!(
            std::time::Instant::now() < deadline,
            "ports never discovered"
        );
        if let Ok(PortEvent::Discovered {
            port, generation, ..
        }) = receive.try_recv()
        {
            if port == "OKAY" {
                okay_generation = Some(generation);
            }
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    let okay_generation = okay_generation.unwrap();
    for _ in 0..500 {
        if transport.panic_read_started.load(Ordering::SeqCst) {
            break;
        }
        std::thread::sleep(Duration::from_millis(2));
    }
    assert!(
        transport.panic_read_started.load(Ordering::SeqCst),
        "panic port reader never ran"
    );
    // Unplug the panicked port; its joined-panic outcome must be reported once and
    // must neither panic the scanner nor drop the healthy owner.
    transport.drop_panic.store(true, Ordering::SeqCst);
    handle.scan_now().unwrap();
    let mut panic_reported = false;
    while !panic_reported {
        let event = receive
            .recv_timeout(Duration::from_secs(2))
            .expect("no cleanup event for the panicked port");
        if let PortEvent::Failed { port, reason, .. } = &event {
            if port == "PANIC" && reason.contains("serial task panicked") {
                panic_reported = true;
            }
        }
    }
    assert!(panic_reported);
    handle
        .send_message(
            "OKAY",
            okay_generation,
            Message::Heartbeat,
            Duration::from_secs(1),
        )
        .expect("the healthy owner must stay operational");
    let shutdown = handle.shutdown();
    assert!(
        shutdown.is_err(),
        "the joined panic must surface from shutdown instead of a false success"
    );
    // Retrying after the recorded join outcome must not unwrap a consumed handle.
    assert!(handle.shutdown().is_err());
    assert!(receive
        .try_iter()
        .any(|event| matches!(event, PortEvent::Closed { port, .. } if port == "OKAY")));
}

// Ports connection.ex handle_cast(:scan) → clear_failed_ports/1
// (connection.ex:261-267): a manual scan must bypass the failure backoff and
// retry failed ports immediately instead of waiting failure_retry (30 s).
struct FailingOpenTransport {
    opens: std::sync::atomic::AtomicUsize,
}

impl SerialTransport for FailingOpenTransport {
    fn enumerate(&self) -> io::Result<Vec<String>> {
        Ok(vec!["SCANFAIL".into()])
    }
    fn open(&self, _port: &str, _baud: u32, _timeout: Duration) -> io::Result<Box<dyn SerialIo>> {
        self.opens.fetch_add(1, Ordering::SeqCst);
        Err(io::Error::new(io::ErrorKind::PermissionDenied, "busy"))
    }
}

#[test]
fn manual_scan_clears_failed_port_backoff() {
    let transport = Arc::new(FailingOpenTransport {
        opens: std::sync::atomic::AtomicUsize::new(0),
    });
    let runtime = Arc::new(
        HardwareRuntime::new(
            transport.clone(),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
        )
        // 300 s failure backoff: without the clear, the second open attempt
        // could never happen inside this test.
        .with_policy(
            Duration::from_secs(300),
            Duration::from_secs(300),
            Duration::from_secs(1),
        ),
    );
    let (events, receive) = mpsc::channel();
    let mut handle = runtime.start(move |event| {
        let _ = events.send(event);
    });

    let mut failures = 0;
    let deadline = std::time::Instant::now() + Duration::from_secs(3);
    while failures < 2 {
        match receive
            .recv_timeout(deadline.saturating_duration_since(std::time::Instant::now()))
            .unwrap()
        {
            PortEvent::Failed { port, .. } => {
                assert_eq!(port, "SCANFAIL");
                failures += 1;
                if failures == 1 {
                    handle.scan_now().unwrap();
                }
            }
            PortEvent::Closed { .. } => {} // joined failed owner, before retry
            other => panic!("unexpected event: {other:?}"),
        }
    }
    assert_eq!(failures, 2);
    assert!(
        transport.opens.load(Ordering::SeqCst) >= 2,
        "manual scan must re-open the failed port, bypassing the backoff"
    );
    handle.shutdown().unwrap();
}

// Ports DeviceConnection.format_error_reason/1
// (lib/trenino/serial/connection/device_connection.ex:124-145): human-readable
// port error strings for the UI, including the generic atom fallback
// (underscores to spaces, capitalized).
#[test]
fn format_error_reason_matches_oracle_strings() {
    use trenino_runtime::hardware::{format_error_reason, format_io_error_reason};
    assert_eq!(format_error_reason("eacces"), "Permission denied");
    assert_eq!(format_error_reason("enoent"), "Port not found");
    assert_eq!(
        format_error_reason("ebusy"),
        "Port is busy (in use by another program)"
    );
    assert_eq!(
        format_error_reason("eagain"),
        "Resource temporarily unavailable"
    );
    assert_eq!(format_error_reason("eio"), "I/O error");
    assert_eq!(format_error_reason("einval"), "Invalid port configuration");
    assert_eq!(format_error_reason("enxio"), "Device not configured");
    assert_eq!(format_error_reason("eperm"), "Operation not permitted");
    assert_eq!(
        format_error_reason("no_valid_response"),
        "No Trenino firmware detected"
    );
    assert_eq!(format_error_reason("timeout"), "Connection timed out");
    assert_eq!(
        format_error_reason("port_timed_out"),
        "Device not responding"
    );
    // Oracle fallback: `reason |> Atom.to_string() |> replace("_"," ") |> capitalize`.
    assert_eq!(format_error_reason("device_orphaned"), "Device orphaned");
    // Binary reasons pass through unchanged.
    assert_eq!(format_error_reason("custom failure"), "custom failure");
    // errno mapping for OS open failures.
    assert_eq!(
        format_io_error_reason(&io::Error::from_raw_os_error(2)),
        "Port not found"
    );
    assert_eq!(
        format_io_error_reason(&io::Error::from_raw_os_error(13)),
        "Permission denied"
    );
    assert_eq!(
        format_io_error_reason(&io::Error::new(io::ErrorKind::TimedOut, "boom")),
        "boom"
    );
}

struct BootloaderTransport {
    bootloader: AtomicBool,
    enumerations: AtomicUsize,
    opened: Mutex<Vec<String>>,
}
impl SerialTransport for BootloaderTransport {
    fn enumerate(&self) -> io::Result<Vec<String>> {
        self.enumerations.fetch_add(1, Ordering::SeqCst);
        Ok(vec![if self.bootloader.load(Ordering::SeqCst) {
            "COM99".into()
        } else {
            "COM42".into()
        }])
    }
    fn open(&self, port: &str, _baud: u32, _timeout: Duration) -> io::Result<Box<dyn SerialIo>> {
        self.opened.lock().unwrap().push(port.into());
        Ok(Box::new(FakeOwnedPort {
            reads: VecDeque::new(),
        }))
    }
}

#[test]
fn firmware_handoff_keeps_scanner_off_a_new_bootloader_port() {
    let transport = Arc::new(BootloaderTransport {
        bootloader: AtomicBool::new(false),
        enumerations: AtomicUsize::new(0),
        opened: Mutex::new(Vec::new()),
    });
    let runtime = Arc::new(
        HardwareRuntime::new(
            transport.clone(),
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
        )
        .with_policy(
            Duration::from_secs(60),
            Duration::from_secs(1),
            Duration::from_secs(1),
        ),
    );
    let (events, receive) = mpsc::channel();
    let mut handle = runtime.start(move |event| {
        let _ = events.send(event);
    });
    handle.scan_now().unwrap();
    let generation = loop {
        if let PortEvent::Discovered { generation, .. } =
            receive.recv_timeout(Duration::from_secs(2)).unwrap()
        {
            break generation;
        }
    };
    let arbiter = ResourceArbiter::new(Arc::new(NoopResourceConsumers));
    let lease = arbiter
        .acquire(LeaseKind::Firmware {
            port: "COM42".into(),
            generation,
        })
        .unwrap();
    let permit = arbiter.firmware_handoff_permit(lease).unwrap();
    let operation = handle.begin_handoff("COM42", generation, &permit).unwrap();
    let handoff = handle
        .wait_handoff(operation, Duration::from_secs(2))
        .unwrap()
        .unwrap();
    transport.bootloader.store(true, Ordering::SeqCst);
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(1);
    while transport.enumerations.load(Ordering::SeqCst) < 2 {
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    }
    std::thread::sleep(Duration::from_millis(40));
    let premature = transport.opened.lock().unwrap().contains(&"COM99".into());
    let release = handle.begin_release_handoff(handoff, &permit).unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(1);
    loop {
        if let Some(result) = handle.release_result(release) {
            result.unwrap();
            break;
        }
        assert!(std::time::Instant::now() < deadline);
        std::thread::sleep(Duration::from_millis(2));
    }
    arbiter.release(lease).unwrap();
    handle.shutdown().unwrap();
    assert!(
        !premature,
        "scanner opened the changed bootloader port while flashing owned serial access"
    );
}

#[test]
fn io_error_formatting_uses_portable_error_kinds() {
    use trenino_runtime::hardware::format_io_error_reason;
    assert_eq!(
        format_io_error_reason(&io::Error::new(io::ErrorKind::WouldBlock, "blocked")),
        "Resource temporarily unavailable"
    );
    assert_eq!(
        format_io_error_reason(&io::Error::new(io::ErrorKind::PermissionDenied, "denied")),
        "Permission denied"
    );
}

#[test]
fn firmware_can_reserve_an_available_unrecognized_port_before_discovery() {
    let transport = Arc::new(BootloaderTransport {
        bootloader: AtomicBool::new(false),
        enumerations: AtomicUsize::new(0),
        opened: Mutex::new(Vec::new()),
    });
    let runtime = Arc::new(HardwareRuntime::new(
        transport.clone(),
        DiscoveryTiming {
            settle: Duration::ZERO,
            read_timeout: Duration::from_millis(2),
            attempts: 1,
        },
    ));
    let mut handle = runtime.start(|_| {});
    let arbiter = ResourceArbiter::new(Arc::new(NoopResourceConsumers));
    let lease = arbiter
        .acquire(LeaseKind::Firmware {
            port: "COM42".into(),
            generation: 0,
        })
        .unwrap();
    let permit = arbiter.firmware_handoff_permit(lease).unwrap();
    let op = handle.begin_handoff("COM42", 0, &permit).unwrap();
    let result = handle.wait_handoff(op, Duration::from_secs(2)).unwrap();
    let success = result.is_ok();
    if let Ok(handoff) = result {
        let release = handle.begin_release_handoff(handoff, &permit).unwrap();
        let deadline = std::time::Instant::now() + Duration::from_secs(2);
        loop {
            if let Some(result) = handle.release_result(release) {
                result.unwrap();
                break;
            }
            assert!(std::time::Instant::now() < deadline);
            std::thread::sleep(Duration::from_millis(2));
        }
    }
    arbiter.release(lease).unwrap();
    handle.shutdown().unwrap();
    assert!(
        success,
        "firmware upload must reserve an available board even without a Trenino identity"
    );
}

#[test]
fn manual_disconnect_is_generation_fenced_and_manual_scan_reconnects() {
    let transport = Arc::new(FakeTransport {
        enumerations: AtomicUsize::new(0),
    });
    let runtime = Arc::new(
        HardwareRuntime::new(
            transport,
            DiscoveryTiming {
                settle: Duration::ZERO,
                read_timeout: Duration::from_millis(2),
                attempts: 1,
            },
        )
        .with_policy(
            Duration::from_secs(60),
            Duration::from_secs(30),
            Duration::from_secs(1),
        ),
    );
    let (events, receive) = mpsc::channel();
    let mut handle = runtime.start(move |e| {
        let _ = events.send(e);
    });
    handle.scan_now().unwrap();
    let generation = loop {
        if let PortEvent::Discovered { generation, .. } =
            receive.recv_timeout(Duration::from_secs(2)).unwrap()
        {
            break generation;
        }
    };
    assert!(handle.disconnect_port("COM42", generation + 1).is_err());
    assert_eq!(handle.port_generations().get("COM42"), Some(&generation));
    handle.disconnect_port("COM42", generation).unwrap();
    assert!(!handle.port_generations().contains_key("COM42"));
    handle.scan_now().unwrap();
    let deadline = std::time::Instant::now() + Duration::from_secs(2);
    let next = loop {
        if let PortEvent::Discovered { generation, .. } = receive
            .recv_timeout(deadline.saturating_duration_since(std::time::Instant::now()))
            .unwrap()
        {
            break generation;
        }
    };
    handle.shutdown().unwrap();
    assert!(next > generation);
}
