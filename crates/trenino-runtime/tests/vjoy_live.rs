//! Live-report behavior pinned to the Elixir mapper and manager oracles.
use std::sync::{Arc, Mutex};
use std::time::Duration;

use tempfile::tempdir;
use trenino_core::hardware::calibration::Calibration;
use trenino_core::{ConfigId, EntityId, OperationId};
use trenino_runtime::resource::{LeaseKind, ResourceArbiter, ResourceConsumers};
use trenino_runtime::routing::{InputEvent, InputIdentity};
use trenino_runtime::storage::{CalibrationRecord, Database, DeviceDraft, InputDraft, InputKind};
use trenino_runtime::vjoy::mapper::{axis_value, MappingError};
use trenino_runtime::vjoy::{
    AdapterEvent, FakeVjoyAdapter, MappingDraft, Target, VjoyAxis, VjoyManager, VjoyStatus,
};

struct Noop;
impl ResourceConsumers for Noop {
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

fn calibration() -> Calibration {
    Calibration {
        min_value: 0,
        max_value: 1024,
        max_hardware_value: 1024,
        inverted: false,
        rollover: false,
    }
}

#[test]
fn mapper_matches_elixir_axis_oracle() {
    let c = calibration();
    assert_eq!(axis_value(0, Some(&c), false, (0, 32768)), Ok(0));
    assert_eq!(axis_value(512, Some(&c), false, (0, 32768)), Ok(16384));
    assert_eq!(axis_value(1024, Some(&c), false, (0, 32768)), Ok(32768));
    assert_eq!(axis_value(-50, Some(&c), false, (0, 32768)), Ok(0));
    assert_eq!(axis_value(2000, Some(&c), false, (0, 32768)), Ok(32768));
    assert_eq!(axis_value(768, Some(&c), true, (0, 32768)), Ok(8192));
    assert_eq!(axis_value(768, Some(&c), false, (0, 10000)), Ok(7500));
    let reversed = Calibration {
        min_value: 1024,
        max_value: 0,
        inverted: true,
        ..c
    };
    assert_eq!(
        axis_value(256, Some(&reversed), false, (0, 32768)),
        Ok(24576)
    );
    assert_eq!(
        axis_value(512, None, false, (0, 32768)),
        Err(MappingError::Uncalibrated)
    );
    let no_travel = Calibration { max_value: 0, ..c };
    assert_eq!(
        axis_value(0, Some(&no_travel), false, (0, 32768)),
        Err(MappingError::Uncalibrated)
    );
    assert_eq!(
        axis_value(512, Some(&c), false, (10, 10)),
        Err(MappingError::InvalidRange)
    );
}

type Setup = (
    tempfile::TempDir,
    Database,
    Arc<Mutex<FakeVjoyAdapter>>,
    VjoyManager<Arc<Mutex<FakeVjoyAdapter>>>,
    InputIdentity,
    InputIdentity,
);

fn setup() -> Setup {
    let dir = tempdir().unwrap();
    let db = Database::open_full(dir.path().join("vjoy-live.db")).unwrap();
    db.allocate_epoch().unwrap();
    let device = db
        .create_device(
            OperationId(1),
            DeviceDraft {
                name: "Controller".into(),
                description: None,
                config_id: Some(ConfigId::new(101).unwrap()),
            },
        )
        .unwrap()
        .record;
    let analog = db
        .create_input(
            OperationId(2),
            device.id,
            InputDraft {
                pin: 5,
                kind: InputKind::Analog,
                sensitivity: Some(10),
                debounce: None,
                name: None,
                matrix_id: None,
            },
        )
        .unwrap()
        .record;
    let button = db
        .create_input(
            OperationId(3),
            device.id,
            InputDraft {
                pin: 6,
                kind: InputKind::Button,
                sensitivity: None,
                debounce: Some(50),
                name: None,
                matrix_id: None,
            },
        )
        .unwrap()
        .record;
    db.save_calibration(
        OperationId(4),
        analog.id,
        CalibrationRecord {
            max_hardware_value: Some(1024),
            min_value: Some(0),
            max_value: Some(1024),
            has_rollover: false,
            is_inverted: false,
        },
    )
    .unwrap();
    db.vjoy_put_mapping(
        OperationId(5),
        analog.id,
        MappingDraft {
            device_index: 1,
            target: Target::Axis(VjoyAxis::X),
            inverted: false,
        },
        false,
    )
    .unwrap();
    db.vjoy_put_mapping(
        OperationId(6),
        button.id,
        MappingDraft {
            device_index: 1,
            target: Target::Button(4),
            inverted: false,
        },
        false,
    )
    .unwrap();
    let fake = Arc::new(Mutex::new(FakeVjoyAdapter::new()));
    let manager = VjoyManager::new(
        db.clone(),
        Arc::new(ResourceArbiter::new(Arc::new(Noop))),
        fake.clone(),
    );
    (
        dir,
        db,
        fake,
        manager,
        InputIdentity {
            device_id: device.id,
            input_id: analog.id,
        },
        InputIdentity {
            device_id: device.id,
            input_id: button.id,
        },
    )
}

fn event(pin: u8, value: i16, generation: u64) -> InputEvent {
    InputEvent {
        config_id: ConfigId::new(101).unwrap(),
        pin,
        value,
        port_generation: generation,
    }
}

#[test]
fn cached_values_publish_on_activation_and_live_samples_drive_reports() {
    let (_dir, _db, fake, manager, analog, button) = setup();
    manager
        .input_value("COM1", analog, event(5, 1024, 7))
        .unwrap();
    manager.input_value("COM1", button, event(6, 1, 7)).unwrap();
    assert!(!fake
        .lock()
        .unwrap()
        .events()
        .iter()
        .any(|e| matches!(e, AdapterEvent::Axis { .. } | AdapterEvent::Button { .. })));
    manager.enable().unwrap();
    let events = fake.lock().unwrap().events().to_vec();
    assert!(events.contains(&AdapterEvent::Axis {
        device: 1,
        axis: VjoyAxis::X,
        value: 32767
    }));
    assert!(events.contains(&AdapterEvent::Button {
        device: 1,
        button: 4,
        pressed: true
    }));
    fake.lock().unwrap().clear_events();
    manager.input_value("COM1", analog, event(5, 0, 7)).unwrap();
    manager.input_value("COM1", button, event(6, 0, 7)).unwrap();
    let events = fake.lock().unwrap().events().to_vec();
    assert!(events.contains(&AdapterEvent::Axis {
        device: 1,
        axis: VjoyAxis::X,
        value: 0
    }));
    assert!(events.contains(&AdapterEvent::Button {
        device: 1,
        button: 4,
        pressed: false
    }));
}

#[test]
fn source_loss_neutralizes_only_its_targets_and_rejects_stale_samples() {
    let (_dir, _db, fake, manager, analog, button) = setup();
    manager
        .input_value("COM1", analog, event(5, 1024, 7))
        .unwrap();
    manager.input_value("COM2", button, event(6, 1, 3)).unwrap();
    manager.enable().unwrap();
    fake.lock().unwrap().clear_events();
    manager.source_lost("COM1", 7).unwrap();
    let events = fake.lock().unwrap().events().to_vec();
    assert!(events.contains(&AdapterEvent::Axis {
        device: 1,
        axis: VjoyAxis::X,
        value: 16384
    }));
    assert!(!events
        .iter()
        .any(|e| matches!(e, AdapterEvent::Button { .. })));
    fake.lock().unwrap().clear_events();
    manager.input_value("COM1", analog, event(5, 0, 7)).unwrap();
    assert!(fake.lock().unwrap().events().is_empty());
}

#[test]
fn inactive_neutralization_is_idempotent() {
    let (_dir, _db, _fake, manager, _, _) = setup();
    assert!(manager.neutralize_outputs().is_ok());
}

#[test]
fn source_loss_neutralizes_unsampled_mappings_on_its_port() {
    let (_dir, _db, fake, manager, _, _) = setup();
    manager
        .observe_port("COM1", 7, ConfigId::new(101).unwrap())
        .unwrap();
    manager.enable().unwrap();
    fake.lock().unwrap().clear_events();
    manager.source_lost("COM1", 7).unwrap();
    let events = fake.lock().unwrap().events().to_vec();
    assert!(events.contains(&AdapterEvent::Axis {
        device: 1,
        axis: VjoyAxis::X,
        value: 16384
    }));
    assert!(events.contains(&AdapterEvent::Button {
        device: 1,
        button: 4,
        pressed: false
    }));
}

#[test]
fn newly_added_mapping_uses_cached_input_after_reload() {
    let (_dir, db, fake, manager, analog, button) = setup();
    let button_mapping = db
        .vjoy_list_mappings()
        .unwrap()
        .into_iter()
        .find(|m| m.input_id == button.input_id)
        .unwrap();
    db.vjoy_delete_mapping(OperationId(8), button_mapping.id)
        .unwrap();
    manager.reload_mappings().unwrap();
    manager.input_value("COM1", button, event(6, 1, 7)).unwrap();
    manager.input_value("COM1", analog, event(5, 0, 7)).unwrap();
    manager.enable().unwrap();
    fake.lock().unwrap().clear_events();
    db.vjoy_put_mapping(OperationId(9), button.input_id, button_draft(), false)
        .unwrap();
    manager.reload_mappings().unwrap();
    assert!(fake
        .lock()
        .unwrap()
        .events()
        .contains(&AdapterEvent::Button {
            device: 1,
            button: 4,
            pressed: true
        }));
}

fn button_draft() -> MappingDraft {
    MappingDraft {
        device_index: 1,
        target: Target::Button(4),
        inverted: false,
    }
}

#[test]
fn native_report_loss_degrades_and_recovers_after_bounded_delay() {
    let (_dir, db, fake, manager, analog, _) = setup();
    manager.enable().unwrap();
    fake.lock().unwrap().set_report_error(1, Some("removed"));
    assert!(manager
        .input_value("COM1", analog, event(5, 1024, 7))
        .is_err());
    assert_eq!(manager.status(), VjoyStatus::Degraded);
    assert!(db.vjoy_configuration().unwrap().enabled);
    assert_eq!(manager.next_retry_delay(), Some(Duration::from_millis(250)));
    let deadline = manager.next_retry_deadline().unwrap();
    assert!(!manager
        .poll_recovery_at(deadline - Duration::from_millis(1))
        .unwrap());
    fake.lock().unwrap().set_report_error(1, None);
    assert!(manager.poll_recovery_at(deadline).unwrap());
    assert_eq!(manager.status(), VjoyStatus::Active);
    assert_eq!(manager.next_retry_delay(), None);
}

#[test]
fn repeated_runtime_loss_exhausts_retries_and_disable_cancels_them() {
    let (_dir, _db, fake, manager, analog, _) = setup();
    manager.enable().unwrap();
    fake.lock().unwrap().set_report_error(1, Some("removed"));
    assert!(manager.input_value("COM1", analog, event(5, 1, 7)).is_err());
    let delays = [250, 500, 1000, 2000, 4000];
    for (index, delay) in delays.into_iter().enumerate() {
        assert_eq!(
            manager.next_retry_delay(),
            Some(Duration::from_millis(delay))
        );
        let due = manager.next_retry_deadline().unwrap();
        assert!(manager.poll_recovery_at(due).is_err());
        assert_eq!(
            manager.status(),
            if index == 4 {
                VjoyStatus::Error
            } else {
                VjoyStatus::Degraded
            }
        );
    }
    assert_eq!(manager.next_retry_deadline(), None);
    manager.disable().unwrap();
    assert_eq!(manager.next_retry_delay(), None);
    assert_eq!(manager.status(), VjoyStatus::Off);
}

#[test]
fn mapping_deletion_releases_old_held_target_on_reload() {
    let (_dir, db, fake, manager, _, button) = setup();
    manager.input_value("COM1", button, event(6, 1, 7)).unwrap();
    manager.enable().unwrap();
    fake.lock().unwrap().clear_events();
    let mapping = db
        .vjoy_list_mappings()
        .unwrap()
        .into_iter()
        .find(|m| m.input_id == button.input_id)
        .unwrap();
    db.vjoy_delete_mapping(OperationId(80), mapping.id).unwrap();
    manager.reload_mappings().unwrap();
    assert!(fake
        .lock()
        .unwrap()
        .events()
        .contains(&AdapterEvent::Button {
            device: 1,
            button: 4,
            pressed: false
        }));
}

#[test]
fn unselected_device_mapping_never_reports_or_degrades() {
    let (_dir, db, fake, manager, analog, _) = setup();
    let mapping = db
        .vjoy_list_mappings()
        .unwrap()
        .into_iter()
        .find(|m| m.input_id == analog.input_id)
        .unwrap();
    db.vjoy_put_mapping(
        OperationId(81),
        analog.input_id,
        MappingDraft {
            device_index: 2,
            target: Target::Axis(VjoyAxis::X),
            inverted: false,
        },
        false,
    )
    .unwrap();
    assert_eq!(mapping.device_index, 1);
    manager.reload_mappings().unwrap();
    manager.enable().unwrap();
    fake.lock().unwrap().clear_events();
    manager
        .input_value("COM1", analog, event(5, 1024, 7))
        .unwrap();
    assert_eq!(manager.status(), VjoyStatus::Active);
    assert!(!fake
        .lock()
        .unwrap()
        .events()
        .iter()
        .any(|e| matches!(e, AdapterEvent::Axis { .. })));
}

#[test]
fn older_generation_cannot_override_newer_port_value() {
    let (_dir, _db, fake, manager, analog, _) = setup();
    manager.enable().unwrap();
    fake.lock().unwrap().clear_events();
    manager
        .input_value("COM1", analog, event(5, 1024, 8))
        .unwrap();
    manager.input_value("COM1", analog, event(5, 0, 7)).unwrap();
    let events = fake.lock().unwrap().events().to_vec();
    assert_eq!(
        events
            .iter()
            .filter(|e| matches!(e, AdapterEvent::Axis { .. }))
            .count(),
        1
    );
    assert!(events.contains(&AdapterEvent::Axis {
        device: 1,
        axis: VjoyAxis::X,
        value: 32767
    }));
}

#[test]
fn manual_retry_keeps_failed_report_degraded_until_it_can_publish() {
    let (_dir, _db, fake, manager, analog, _) = setup();
    manager.enable().unwrap();
    fake.lock().unwrap().set_report_error(1, Some("removed"));
    assert!(manager
        .input_value("COM1", analog, event(5, 1024, 7))
        .is_err());
    assert!(manager.retry().is_err());
    assert_eq!(manager.status(), VjoyStatus::Degraded);
    fake.lock().unwrap().set_report_error(1, None);
    manager.retry().unwrap();
    assert_eq!(manager.status(), VjoyStatus::Active);
}

#[test]
fn repair_rechecks_driver_without_acquiring_unrequested_device() {
    let (_dir, _db, fake, manager, _, _) = setup();
    fake.lock().unwrap().set_driver_available(false, "missing");
    assert!(manager.enable().is_err());
    assert_eq!(manager.status(), VjoyStatus::Error);
    fake.lock().unwrap().set_driver_available(true, "");
    manager.repair().unwrap();
    assert_eq!(manager.status(), VjoyStatus::NeedsCleanup);
    assert!(fake.lock().unwrap().acquired().is_empty());
}

#[test]
fn failed_report_during_mapping_reload_enters_recovery() {
    let (_dir, _db, fake, manager, _, _) = setup();
    manager.enable().unwrap();
    fake.lock().unwrap().set_report_error(1, Some("removed"));
    assert!(manager.reload_mappings().is_err());
    assert_eq!(manager.status(), VjoyStatus::Degraded);
    assert_eq!(manager.next_retry_delay(), Some(Duration::from_millis(250)));
}

#[test]
fn mapping_reload_does_not_reassert_cached_input_during_a_resource_lease() {
    let (_dir, db, fake, old_manager, _, button) = setup();
    drop(old_manager);
    let arbiter = Arc::new(ResourceArbiter::new(Arc::new(Noop)));
    let manager = VjoyManager::new(db.clone(), arbiter.clone(), fake.clone());
    manager.input_value("COM1", button, event(6, 1, 7)).unwrap();
    manager.enable().unwrap();
    let lease = arbiter
        .acquire(LeaseKind::Calibration {
            port: "COM1".into(),
            generation: 7,
        })
        .unwrap();
    manager.neutralize_outputs().unwrap();
    fake.lock().unwrap().clear_events();
    manager.reload_mappings().unwrap();
    assert!(!fake.lock().unwrap().events().iter().any(|e| matches!(
        e,
        AdapterEvent::Button { pressed: true, .. } | AdapterEvent::Axis { value: 32767, .. }
    )));
    arbiter.release(lease).unwrap();
    fake.lock().unwrap().clear_events();
    manager.input_value("COM1", button, event(6, 1, 7)).unwrap();
    assert!(fake
        .lock()
        .unwrap()
        .events()
        .contains(&AdapterEvent::Button {
            device: 1,
            button: 4,
            pressed: true
        }));
}

#[test]
fn failed_deleted_target_cleanup_cannot_republish_deleted_route_after_recovery() {
    let (_dir, db, fake, manager, _, button) = setup();
    manager.input_value("COM1", button, event(6, 1, 7)).unwrap();
    manager.enable().unwrap();
    let mapping = db
        .vjoy_list_mappings()
        .unwrap()
        .into_iter()
        .find(|m| m.input_id == button.input_id)
        .unwrap();
    db.vjoy_delete_mapping(OperationId(90), mapping.id).unwrap();
    fake.lock().unwrap().set_report_error(1, Some("removed"));
    assert!(manager.reload_mappings().is_err());
    fake.lock().unwrap().set_report_error(1, None);
    fake.lock().unwrap().clear_events();
    assert!(manager
        .poll_recovery_at(manager.next_retry_deadline().unwrap())
        .unwrap());
    assert!(!fake.lock().unwrap().events().iter().any(|e| matches!(
        e,
        AdapterEvent::Button {
            button: 4,
            pressed: true,
            ..
        }
    )));
    fake.lock().unwrap().clear_events();
    manager.input_value("COM1", button, event(6, 1, 7)).unwrap();
    assert!(!fake
        .lock()
        .unwrap()
        .events()
        .iter()
        .any(|e| matches!(e, AdapterEvent::Button { button: 4, .. })));
}

#[test]
fn suspending_unsampled_duplicate_port_preserves_other_ports_held_target() {
    let (_dir, _db, fake, manager, _, button) = setup();
    manager.input_value("COM1", button, event(6, 1, 7)).unwrap();
    manager
        .observe_port("COM2", 3, ConfigId::new(101).unwrap())
        .unwrap();
    manager.enable().unwrap();
    fake.lock().unwrap().clear_events();
    manager.suspend_port("COM2").unwrap();
    assert!(!fake.lock().unwrap().events().iter().any(|e| matches!(
        e,
        AdapterEvent::Button {
            button: 4,
            pressed: false,
            ..
        }
    )));
}

#[test]
fn suspending_current_supplier_restores_the_other_ports_latest_value() {
    let (_dir, _db, fake, manager, _, button) = setup();
    manager.input_value("COM1", button, event(6, 1, 7)).unwrap();
    manager.input_value("COM2", button, event(6, 0, 3)).unwrap();
    manager.enable().unwrap();
    fake.lock().unwrap().clear_events();
    manager.suspend_port("COM2").unwrap();
    assert!(fake
        .lock()
        .unwrap()
        .events()
        .contains(&AdapterEvent::Button {
            device: 1,
            button: 4,
            pressed: true
        }));
}

#[test]
fn newer_port_generation_releases_old_target_before_replacing_its_provenance() {
    let (_dir, _db, fake, manager, _, button) = setup();
    manager.input_value("COM1", button, event(6, 1, 7)).unwrap();
    manager.enable().unwrap();
    fake.lock().unwrap().clear_events();
    manager
        .observe_port("COM1", 8, ConfigId::new(101).unwrap())
        .unwrap();
    assert!(fake
        .lock()
        .unwrap()
        .events()
        .contains(&AdapterEvent::Button {
            device: 1,
            button: 4,
            pressed: false
        }));
    fake.lock().unwrap().clear_events();
    manager.input_value("COM1", button, event(6, 1, 7)).unwrap();
    assert!(fake.lock().unwrap().events().is_empty());
}

#[test]
fn failed_disable_neutralization_is_reported_after_release() {
    let (_dir, db, fake, manager, _, _) = setup();
    manager.enable().unwrap();
    fake.lock()
        .unwrap()
        .set_neutralize_error(1, Some("reset failed"));
    assert!(manager.disable().is_err());
    assert!(fake.lock().unwrap().acquired().is_empty());
    assert!(!db.vjoy_configuration().unwrap().enabled);
    assert_eq!(manager.status(), VjoyStatus::Error);
}

#[test]
fn port_loss_under_a_lease_never_replays_another_ports_cached_press() {
    let (_dir, db, fake, old_manager, _, button) = setup();
    drop(old_manager);
    let arbiter = Arc::new(ResourceArbiter::new(Arc::new(Noop)));
    let manager = VjoyManager::new(db, arbiter.clone(), fake.clone());
    manager.input_value("COM1", button, event(6, 1, 7)).unwrap();
    manager.input_value("COM2", button, event(6, 0, 3)).unwrap();
    manager.enable().unwrap();
    let lease = arbiter
        .acquire(LeaseKind::Calibration {
            port: "COM2".into(),
            generation: 3,
        })
        .unwrap();
    fake.lock().unwrap().clear_events();
    manager.source_lost("COM2", 3).unwrap();
    assert!(!fake
        .lock()
        .unwrap()
        .events()
        .iter()
        .any(|e| matches!(e, AdapterEvent::Button { pressed: true, .. })));
    arbiter.release(lease).unwrap();
}

#[test]
fn wrong_device_in_new_generation_cannot_revoke_current_held_report() {
    let (_dir, _db, fake, manager, _, button) = setup();
    manager.input_value("COM1", button, event(6, 1, 7)).unwrap();
    manager.enable().unwrap();
    fake.lock().unwrap().clear_events();
    let forged = InputIdentity {
        device_id: EntityId(999_999),
        input_id: button.input_id,
    };
    manager.input_value("COM1", forged, event(6, 0, 8)).unwrap();
    assert!(fake.lock().unwrap().events().is_empty());
    manager.input_value("COM1", button, event(6, 0, 7)).unwrap();
    assert!(fake
        .lock()
        .unwrap()
        .events()
        .contains(&AdapterEvent::Button {
            device: 1,
            button: 4,
            pressed: false
        }));
}

#[test]
fn wrong_pin_in_new_generation_cannot_revoke_current_held_report() {
    let (_dir, _db, fake, manager, _, button) = setup();
    manager.input_value("COM1", button, event(6, 1, 7)).unwrap();
    manager.enable().unwrap();
    fake.lock().unwrap().clear_events();
    manager.input_value("COM1", button, event(9, 0, 8)).unwrap();
    assert!(fake.lock().unwrap().events().is_empty());
    manager.input_value("COM1", button, event(6, 0, 7)).unwrap();
    assert!(fake
        .lock()
        .unwrap()
        .events()
        .contains(&AdapterEvent::Button {
            device: 1,
            button: 4,
            pressed: false
        }));
}
