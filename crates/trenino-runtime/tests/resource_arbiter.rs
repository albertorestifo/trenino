use std::sync::Condvar;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;
use trenino_runtime::resource::{LeaseKind, ResourceArbiter, ResourceConsumers};

struct FakeConsumers(Arc<Mutex<Vec<&'static str>>>);
impl ResourceConsumers for FakeConsumers {
    fn suspend_actuation(&self, _port: &str) -> Result<(), String> {
        self.0.lock().unwrap().push("suspend");
        Ok(())
    }
    fn cancel_calibration(&self, _port: &str) -> Result<(), String> {
        self.0.lock().unwrap().push("cancel-calibration");
        Ok(())
    }
    fn source_lost(&self, _port: &str, _generation: u64) -> Result<(), String> {
        self.0.lock().unwrap().push("source-lost");
        Ok(())
    }
    fn resume_after_fresh_sample(&self, _port: &str) -> Result<(), String> {
        self.0.lock().unwrap().push("resume-fresh");
        Ok(())
    }
}

#[test]
fn firmware_lease_neutralizes_consumers_before_port_handoff_and_resumes_on_release() {
    let log = Arc::new(Mutex::new(Vec::new()));
    let arbiter = ResourceArbiter::new(Arc::new(FakeConsumers(log.clone())));
    let lease = arbiter
        .acquire(LeaseKind::Firmware {
            port: "COM8".into(),
            generation: 9,
        })
        .unwrap();
    assert_eq!(
        *log.lock().unwrap(),
        vec!["suspend", "cancel-calibration", "source-lost"]
    );
    arbiter.release(lease).unwrap();
    assert_eq!(log.lock().unwrap().last(), Some(&"resume-fresh"));
}

#[test]
fn only_one_hardware_resource_lease_can_be_active() {
    let log = Arc::new(Mutex::new(Vec::new()));
    let arbiter = ResourceArbiter::new(Arc::new(FakeConsumers(log)));
    let lease = arbiter
        .acquire(LeaseKind::Calibration {
            port: "COM8".into(),
            generation: 9,
        })
        .unwrap();
    assert!(arbiter
        .acquire(LeaseKind::Firmware {
            port: "COM9".into(),
            generation: 4,
        })
        .is_err());
    arbiter.release(lease).unwrap();
}

#[test]
fn firmware_handoff_cancels_same_port_calibration_and_waits_for_lease_release() {
    let log = Arc::new(Mutex::new(Vec::new()));
    let arbiter = Arc::new(ResourceArbiter::new(Arc::new(FakeConsumers(log.clone()))));
    let calibration = arbiter
        .acquire(LeaseKind::Calibration {
            port: "COM8".into(),
            generation: 9,
        })
        .unwrap();
    let acquiring = arbiter.clone();
    let firmware = thread::spawn(move || {
        acquiring.acquire(LeaseKind::Firmware {
            port: "COM8".into(),
            generation: 9,
        })
    });
    for _ in 0..100 {
        if log.lock().unwrap().contains(&"cancel-calibration") {
            break;
        }
        thread::sleep(Duration::from_millis(1));
    }
    assert!(log.lock().unwrap().contains(&"cancel-calibration"));
    assert!(arbiter.is_suspended());
    arbiter.release(calibration).unwrap();
    let firmware = firmware.join().unwrap().unwrap();
    let events = log.lock().unwrap().clone();
    assert_eq!(events, vec!["suspend", "cancel-calibration", "source-lost"]);
    arbiter.release(firmware).unwrap();
}

struct FreshSampleGate {
    fresh: Mutex<bool>,
    changed: Condvar,
}
impl ResourceConsumers for FreshSampleGate {
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
        let mut fresh = self.fresh.lock().unwrap();
        while !*fresh {
            fresh = self.changed.wait(fresh).unwrap();
        }
        Ok(())
    }
}

#[test]
fn release_stays_suspended_until_consumer_observes_a_fresh_sample() {
    let consumer = Arc::new(FreshSampleGate {
        fresh: Mutex::new(false),
        changed: Condvar::new(),
    });
    let arbiter = Arc::new(ResourceArbiter::new(consumer.clone()));
    let lease = arbiter
        .acquire(LeaseKind::Calibration {
            port: "COM8".into(),
            generation: 9,
        })
        .unwrap();
    let release_arbiter = arbiter.clone();
    let release = thread::spawn(move || release_arbiter.release(lease));
    thread::sleep(Duration::from_millis(10));
    assert!(arbiter.is_suspended());
    *consumer.fresh.lock().unwrap() = true;
    consumer.changed.notify_all();
    release.join().unwrap().unwrap();
    assert!(!arbiter.is_suspended());
}

#[test]
fn shutdown_cancels_active_lease_without_resuming_actuation() {
    let log = Arc::new(Mutex::new(Vec::new()));
    let arbiter = ResourceArbiter::new(Arc::new(FakeConsumers(log.clone())));
    let lease = arbiter
        .acquire(LeaseKind::Calibration {
            port: "COM8".into(),
            generation: 9,
        })
        .unwrap();
    arbiter.shutdown().unwrap();
    assert_eq!(
        *log.lock().unwrap(),
        vec!["suspend", "cancel-calibration", "source-lost"]
    );
    assert!(arbiter.is_suspended());
    assert_eq!(
        arbiter.acquire(LeaseKind::Firmware {
            port: "COM8".into(),
            generation: 9
        }),
        Err(trenino_runtime::resource::ResourceError::Busy)
    );
    assert_eq!(
        arbiter.release(lease),
        Err(trenino_runtime::resource::ResourceError::InvalidLease)
    );
    assert!(!log.lock().unwrap().contains(&"resume-fresh"));
}
