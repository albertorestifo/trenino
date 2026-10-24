use std::collections::VecDeque;
use std::io;
use std::sync::{
    atomic::{AtomicUsize, Ordering},
    mpsc, Arc,
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
fn cache_rejects_stale_generations_and_same_generation_samples_after_disconnect() {
    let cache = InputValueCache::default();
    assert!(cache.update("COM4", 8, 2, 40));
    assert!(cache.update("COM4", 9, 2, 50));
    assert!(!cache.update("COM4", 8, 2, 99));
    assert_eq!(cache.snapshot("COM4", 9).get(&2), Some(&50));
    assert!(cache.invalidate("COM4", 9));
    assert!(!cache.update("COM4", 9, 2, 100));
    assert!(cache.activate("COM4", 9));
    assert!(cache.update("COM4", 9, 2, 60));
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
        || published = true,
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
        || published = true,
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
    let handle = runtime.start(move |event| {
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
        .send_message("COM42", Message::Heartbeat, Duration::from_millis(100))
        .unwrap();
    let handoff = handle
        .handoff_port("COM42", Duration::from_secs(2))
        .unwrap();
    assert_eq!(handoff.generation, generation);
    assert!(
        matches!(receive.recv_timeout(Duration::from_secs(2)).unwrap(), PortEvent::Closed { generation: closed, .. } if closed == generation)
    );
    handle
        .release_handoff(handoff, Duration::from_secs(2))
        .unwrap();
    let reconnected = receive.recv_timeout(Duration::from_secs(2)).unwrap();
    let next_generation = match reconnected {
        PortEvent::Discovered { generation, .. } => generation,
        other => panic!("unexpected event after handoff: {other:?}"),
    };
    assert!(next_generation > generation);
    handle.shutdown().unwrap();
    assert!(receive.try_iter().any(|event| matches!(event, PortEvent::Closed { generation: closed, .. } if closed == next_generation)));
}
