use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};
use trenino_runtime::lifecycle::{ShutdownCoordinator, ShutdownParticipant};

struct Recorder(Mutex<Vec<&'static str>>);

impl ShutdownParticipant for Recorder {
    fn stop_admission(&self) -> Result<(), String> {
        self.0.lock().unwrap().push("admission");
        Ok(())
    }

    fn cancel_and_join_producers(&self) -> Result<(), String> {
        self.0.lock().unwrap().push("producers");
        Ok(())
    }

    fn neutralize_and_release_outputs(&self) -> Result<(), String> {
        self.0.lock().unwrap().push("outputs");
        Ok(())
    }

    fn close_ports_and_network(&self) -> Result<(), String> {
        self.0.lock().unwrap().push("transports");
        Ok(())
    }
}

#[test]
fn shutdown_quiesces_real_participants_in_order_and_closes_database_last() {
    let coordinator = ShutdownCoordinator::default();
    let recorder = Arc::new(Recorder(Mutex::new(Vec::new())));
    coordinator.register(recorder.clone()).unwrap();
    coordinator
        .shutdown(|| {
            recorder.0.lock().unwrap().push("database");
            Ok(())
        })
        .unwrap();
    assert_eq!(
        *recorder.0.lock().unwrap(),
        [
            "admission",
            "producers",
            "outputs",
            "transports",
            "database"
        ]
    );
}

struct NeutralizationFailure;
impl ShutdownParticipant for NeutralizationFailure {
    fn stop_admission(&self) -> Result<(), String> {
        Ok(())
    }
    fn cancel_and_join_producers(&self) -> Result<(), String> {
        Ok(())
    }
    fn neutralize_and_release_outputs(&self) -> Result<(), String> {
        Err("output adapter failed".into())
    }
    fn close_ports_and_network(&self) -> Result<(), String> {
        panic!("transports must remain open after failure")
    }
}

#[test]
fn shutdown_failure_keeps_adapters_and_database_open_for_recovery() {
    let coordinator = ShutdownCoordinator::default();
    coordinator
        .register(Arc::new(NeutralizationFailure))
        .unwrap();
    let mut database_closed = false;
    assert!(coordinator
        .shutdown(|| {
            database_closed = true;
            Ok(())
        })
        .is_err());
    assert!(!database_closed);
}

struct RetryableOutputFailure {
    output_attempts: AtomicBool,
    log: Arc<Mutex<Vec<&'static str>>>,
}

impl ShutdownParticipant for RetryableOutputFailure {
    fn stop_admission(&self) -> Result<(), String> {
        self.log.lock().unwrap().push("admission");
        Ok(())
    }
    fn cancel_and_join_producers(&self) -> Result<(), String> {
        self.log.lock().unwrap().push("producers");
        Ok(())
    }
    fn neutralize_and_release_outputs(&self) -> Result<(), String> {
        self.log.lock().unwrap().push("outputs");
        if !self.output_attempts.swap(true, Ordering::AcqRel) {
            Err("output adapter temporarily busy".into())
        } else {
            Ok(())
        }
    }
    fn close_ports_and_network(&self) -> Result<(), String> {
        self.log.lock().unwrap().push("transports");
        Ok(())
    }
}

#[test]
fn failed_shutdown_can_retry_cleanup_but_cannot_register_new_participants() {
    let coordinator = ShutdownCoordinator::default();
    let log = Arc::new(Mutex::new(Vec::new()));
    coordinator
        .register(Arc::new(RetryableOutputFailure {
            output_attempts: AtomicBool::new(false),
            log: log.clone(),
        }))
        .unwrap();
    assert!(coordinator
        .shutdown(|| panic!("database must remain open on failure"))
        .is_err());
    assert!(coordinator
        .register(Arc::new(Recorder(Mutex::new(Vec::new()))))
        .is_err());
    coordinator
        .shutdown(|| {
            log.lock().unwrap().push("database");
            Ok(())
        })
        .unwrap();
    assert!(coordinator.is_complete());
    assert_eq!(
        *log.lock().unwrap(),
        [
            "admission",
            "producers",
            "outputs",
            "admission",
            "producers",
            "outputs",
            "transports",
            "database"
        ]
    );
}
