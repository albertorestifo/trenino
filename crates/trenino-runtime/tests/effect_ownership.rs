use std::{
    collections::HashSet,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    },
    time::Duration,
};
use trenino_core::{hardware::protocol::Message, ConfigId, OperationId};
use trenino_runtime::{
    composition::hardware::{EffectTransport, LiveHardwareEffects},
    hardware::service::ConnectedPort,
    storage::{Database, DeviceDraft, OutputDraft},
    train::output_controller::{HardwareDispatch, OutputLevel},
};
struct Consumers(Arc<LiveHardwareEffects>);
impl trenino_runtime::resource::ResourceConsumers for Consumers {
    fn suspend_actuation(&self, port: &str) -> Result<(), String> {
        self.0.suspend(port)
    }
    fn source_lost(&self, port: &str, _: u64) -> Result<(), String> {
        self.0.suspend(port)
    }
    fn cancel_calibration(&self, _: &str) -> Result<(), String> {
        Ok(())
    }
    fn resume_after_fresh_sample(&self, _: &str) -> Result<(), String> {
        Ok(())
    }
}
struct Serial {
    port: ConnectedPort,
    reports: Mutex<Vec<Message>>,
    fail: AtomicBool,
}
impl EffectTransport for Serial {
    fn connected_ports(&self) -> Vec<ConnectedPort> {
        vec![self.port.clone()]
    }
    fn send_message(&self, _: &str, _: u64, message: Message, _: Duration) -> Result<(), String> {
        self.reports.lock().unwrap().push(message);
        if self.fail.swap(false, Ordering::SeqCst) {
            return Err("serial acknowledgement lost after write".into());
        }
        Ok(())
    }
}
#[test]
fn deleted_high_output_remains_in_lease_neutralization_and_retry_set() {
    let dir = tempfile::tempdir().unwrap();
    let db = Arc::new(Database::open_full(dir.path().join("effects.db")).unwrap());
    db.allocate_epoch().unwrap();
    let device = db
        .create_device(
            OperationId(1),
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
            OperationId(2),
            device.id,
            OutputDraft { pin: 4, name: None },
        )
        .unwrap()
        .record;
    let serial = Arc::new(Serial {
        port: ConnectedPort {
            port: "panel".into(),
            generation: 1,
            config_id: device.config_id,
            device_id: Some(device.id),
            firmware_version: None,
        },
        reports: Mutex::new(vec![]),
        fail: AtomicBool::new(false),
    });
    let effect = Arc::new(LiveHardwareEffects::new(
        serial.clone(),
        db.clone(),
        Arc::new(Mutex::new(HashSet::new())),
    ));
    let arbiter =
        trenino_runtime::resource::ResourceArbiter::new(Arc::new(Consumers(effect.clone())));
    effect.set_output("panel", 4, OutputLevel::High).unwrap();
    db.delete_output(OperationId(3), output.id).unwrap();
    serial.fail.store(true, Ordering::SeqCst);
    assert!(arbiter
        .acquire(trenino_runtime::resource::LeaseKind::Calibration {
            port: "panel".into(),
            generation: 1
        })
        .is_err());
    assert!(effect.set_output("panel", 4, OutputLevel::High).is_err());
    arbiter.shutdown().unwrap();
    assert_eq!(
        *serial.reports.lock().unwrap(),
        vec![
            Message::SetOutput { pin: 4, high: true },
            Message::SetOutput {
                pin: 4,
                high: false
            },
            Message::SetOutput {
                pin: 4,
                high: false
            }
        ]
    );
}
#[test]
fn moved_and_deleted_display_still_gets_original_width_blank_before_suspend_ack() {
    let dir = tempfile::tempdir().unwrap();
    let db = Arc::new(Database::open_full(dir.path().join("effects.db")).unwrap());
    db.allocate_epoch().unwrap();
    let device = db
        .create_device(
            OperationId(1),
            DeviceDraft {
                name: "Panel".into(),
                description: None,
                config_id: Some(ConfigId::new(10).unwrap()),
            },
        )
        .unwrap()
        .record;
    let serial = Arc::new(Serial {
        port: ConnectedPort {
            port: "panel".into(),
            generation: 1,
            config_id: device.config_id,
            device_id: Some(device.id),
            firmware_version: None,
        },
        reports: Mutex::new(vec![]),
        fail: AtomicBool::new(false),
    });
    let draft = |address, digits| trenino_runtime::storage::I2cModuleDraft {
        name: None,
        module_chip: "ht16k33".into(),
        i2c_address: address,
        params: Some(trenino_runtime::storage::Ht16k33Params {
            brightness: 8,
            num_digits: digits,
            display_type: trenino_runtime::storage::DisplayType::SevenSegment,
            has_dot: true,
            align_right: true,
            min_value: None,
        }),
    };
    let module = db
        .create_i2c_module(OperationId(2), device.id, draft(0x70, 4))
        .unwrap()
        .record;
    let effect = LiveHardwareEffects::new(
        serial.clone(),
        db.clone(),
        Arc::new(Mutex::new(HashSet::new())),
    );
    effect.write_segments("panel", 0x70, vec![3; 8]).unwrap();
    db.update_i2c_module(OperationId(3), module.id, draft(0x71, 8))
        .unwrap();
    effect.write_segments("panel", 0x71, vec![7; 16]).unwrap();
    db.delete_i2c_module(OperationId(4), module.id).unwrap();
    // A shortened blank only clears its own prefix; retain the widest live write.
    effect.write_segments("panel", 0x71, vec![0; 8]).unwrap();
    effect.suspend("panel").unwrap();
    let reports = serial.reports.lock().unwrap();
    assert!(reports.contains(&Message::WriteSegments {
        address: 0x70,
        data: vec![0; 8]
    }));
    assert!(reports.contains(&Message::WriteSegments {
        address: 0x71,
        data: vec![0; 16]
    }));
}

#[test]
fn uncertain_high_is_not_forgotten_after_row_deletion() {
    let dir = tempfile::tempdir().unwrap();
    let db = Arc::new(Database::open_full(dir.path().join("effects.db")).unwrap());
    db.allocate_epoch().unwrap();
    let device = db
        .create_device(
            OperationId(1),
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
            OperationId(2),
            device.id,
            OutputDraft { pin: 4, name: None },
        )
        .unwrap()
        .record;
    let serial = Arc::new(Serial {
        port: ConnectedPort {
            port: "panel".into(),
            generation: 1,
            config_id: device.config_id,
            device_id: Some(device.id),
            firmware_version: None,
        },
        reports: Mutex::new(vec![]),
        fail: AtomicBool::new(false),
    });
    let effect = Arc::new(LiveHardwareEffects::new(
        serial.clone(),
        db.clone(),
        Arc::new(Mutex::new(HashSet::new())),
    ));
    serial.fail.store(true, Ordering::SeqCst);
    assert!(effect.set_output("panel", 4, OutputLevel::High).is_err());
    db.delete_output(OperationId(3), output.id).unwrap();
    effect.suspend("panel").unwrap();
    assert_eq!(
        *serial.reports.lock().unwrap(),
        vec![
            Message::SetOutput { pin: 4, high: true },
            Message::SetOutput {
                pin: 4,
                high: false
            }
        ]
    );
}

#[test]
fn uncertain_display_write_and_blank_retain_full_cleanup_until_acknowledged() {
    let dir = tempfile::tempdir().unwrap();
    let db = Arc::new(Database::open_full(dir.path().join("effects.db")).unwrap());
    let serial = Arc::new(Serial {
        port: ConnectedPort {
            port: "panel".into(),
            generation: 1,
            config_id: None,
            device_id: None,
            firmware_version: None,
        },
        reports: Mutex::new(vec![]),
        fail: AtomicBool::new(true),
    });
    let effect = LiveHardwareEffects::new(serial.clone(), db, Arc::new(Mutex::new(HashSet::new())));
    assert!(effect.write_segments("panel", 0x70, vec![7; 16]).is_err());
    serial.fail.store(true, Ordering::SeqCst);
    assert!(effect.write_segments("panel", 0x70, vec![0; 16]).is_err());
    serial.fail.store(true, Ordering::SeqCst);
    assert!(effect.suspend("panel").is_err());
    effect.suspend("panel").unwrap();
    assert_eq!(
        *serial.reports.lock().unwrap(),
        vec![
            Message::WriteSegments {
                address: 0x70,
                data: vec![7; 16]
            },
            Message::WriteSegments {
                address: 0x70,
                data: vec![0; 16]
            },
            Message::WriteSegments {
                address: 0x70,
                data: vec![0; 16]
            },
            Message::WriteSegments {
                address: 0x70,
                data: vec![0; 16]
            },
        ]
    );
}

#[test]
fn shutdown_neutralizes_manual_effects_and_retains_failed_targets_for_retry() {
    let dir = tempfile::tempdir().unwrap();
    let db = Arc::new(Database::open_full(dir.path().join("effects.db")).unwrap());
    let serial = Arc::new(Serial {
        port: ConnectedPort {
            port: "panel".into(),
            generation: 1,
            config_id: None,
            device_id: None,
            firmware_version: None,
        },
        reports: Mutex::new(vec![]),
        fail: AtomicBool::new(false),
    });
    let effect = LiveHardwareEffects::new(serial.clone(), db, Arc::new(Mutex::new(HashSet::new())));
    effect.set_output("panel", 4, OutputLevel::High).unwrap();
    effect.write_segments("panel", 0x70, vec![7; 16]).unwrap();
    serial.fail.store(true, Ordering::SeqCst);
    assert!(effect.neutralize_all(Duration::from_secs(1)).is_err());
    assert!(effect.set_output("panel", 4, OutputLevel::High).is_err());
    effect.neutralize_all(Duration::from_secs(1)).unwrap();
    let reports = serial.reports.lock().unwrap();
    assert_eq!(
        reports
            .iter()
            .filter(|m| **m
                == Message::SetOutput {
                    pin: 4,
                    high: false
                })
            .count(),
        2
    );
    assert!(reports.contains(&Message::WriteSegments {
        address: 0x70,
        data: vec![0; 16]
    }));
    let count = reports.len();
    drop(reports);
    effect.neutralize_all(Duration::from_secs(1)).unwrap();
    assert_eq!(serial.reports.lock().unwrap().len(), count);
}

#[test]
fn explicit_generation_never_dispatches_to_a_replacement_connection() {
    struct Reconnected(Mutex<Vec<(u64, Message)>>);
    impl EffectTransport for Reconnected {
        fn connected_ports(&self) -> Vec<ConnectedPort> {
            vec![ConnectedPort {
                port: "panel".into(),
                generation: 1,
                config_id: None,
                device_id: None,
                firmware_version: None,
            }]
        }
        fn send_message(
            &self,
            _: &str,
            generation: u64,
            message: Message,
            _: Duration,
        ) -> Result<(), String> {
            self.0.lock().unwrap().push((generation, message));
            // Replacement generation 2 appeared after the inventory read.
            if generation != 2 {
                Err("stale port generation".into())
            } else {
                Ok(())
            }
        }
    }
    let dir = tempfile::tempdir().unwrap();
    let db = Arc::new(Database::open_full(dir.path().join("effects.db")).unwrap());
    let serial = Arc::new(Reconnected(Mutex::new(vec![])));
    let effect = LiveHardwareEffects::new(serial.clone(), db, Arc::new(Mutex::new(HashSet::new())));
    assert!(effect
        .set_output_at("panel", 0, 4, OutputLevel::High)
        .is_err());
    assert!(effect
        .set_module_brightness_at("panel", 0, 0x70, 8)
        .is_err());
    assert!(effect
        .write_segments_at("panel", 0, 0x70, vec![7; 8])
        .is_err());
    assert!(serial.0.lock().unwrap().is_empty());
    assert!(effect
        .set_output_at("panel", 1, 4, OutputLevel::High)
        .is_err());
    assert!(effect.neutralize_all(Duration::from_secs(1)).is_err());
    assert_eq!(
        *serial.0.lock().unwrap(),
        vec![
            (1, Message::SetOutput { pin: 4, high: true }),
            (
                1,
                Message::SetOutput {
                    pin: 4,
                    high: false
                }
            ),
        ]
    );
}

#[test]
fn shutdown_deadline_bounds_waiting_for_an_inflight_effect_gate() {
    let dir = tempfile::tempdir().unwrap();
    let db = Arc::new(Database::open_full(dir.path().join("effects.db")).unwrap());
    let serial = Arc::new(Serial {
        port: ConnectedPort {
            port: "panel".into(),
            generation: 1,
            config_id: None,
            device_id: None,
            firmware_version: None,
        },
        reports: Mutex::new(vec![]),
        fail: AtomicBool::new(false),
    });
    let gate = Arc::new(Mutex::new(HashSet::new()));
    let effect = LiveHardwareEffects::new(serial.clone(), db, gate.clone());
    effect.set_output("panel", 4, OutputLevel::High).unwrap();
    let held = gate.lock().unwrap();
    let started = std::time::Instant::now();
    assert!(effect.neutralize_all(Duration::from_millis(20)).is_err());
    assert!(started.elapsed() < Duration::from_millis(200));
    drop(held);
    effect.neutralize_all(Duration::from_secs(1)).unwrap();
    assert_eq!(
        serial.reports.lock().unwrap().last(),
        Some(&Message::SetOutput {
            pin: 4,
            high: false
        })
    );
}
