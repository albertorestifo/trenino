//! Ordered shutdown for registered, real application services.
use std::sync::{
    atomic::{AtomicBool, Ordering},
    Arc, Mutex,
};

/// A service must implement each cleanup phase it actually owns. Services are
/// called in phase order, and database closure runs only after every phase.
pub trait ShutdownParticipant: Send + Sync {
    fn stop_admission(&self) -> Result<(), String>;
    fn cancel_and_join_producers(&self) -> Result<(), String>;
    fn neutralize_and_release_outputs(&self) -> Result<(), String>;
    fn close_ports_and_network(&self) -> Result<(), String>;
}

#[derive(Default)]
pub struct ShutdownCoordinator {
    participants: Mutex<Vec<Arc<dyn ShutdownParticipant>>>,
    shutdown_lock: Mutex<()>,
    started: AtomicBool,
    complete: AtomicBool,
}

impl ShutdownCoordinator {
    /// Register a live service before shutdown begins. No participant receives
    /// implicit successful cleanup hooks.
    pub fn register(&self, participant: Arc<dyn ShutdownParticipant>) -> Result<(), &'static str> {
        if self.started.load(Ordering::Acquire) {
            return Err("shutdown has already begun");
        }
        let mut participants = self
            .participants
            .lock()
            .map_err(|_| "shutdown participant registry is unavailable")?;
        if self.started.load(Ordering::Acquire) {
            return Err("shutdown has already begun");
        }
        participants.push(participant);
        Ok(())
    }

    /// Run cleanup phases in order, then close the database last. A failed
    /// phase leaves later resources open and permits a retry with the same
    /// participants; phase hooks therefore must be safe to retry.
    pub fn shutdown(
        &self,
        close_database: impl FnOnce() -> Result<(), String>,
    ) -> Result<(), String> {
        let _shutdown = self
            .shutdown_lock
            .lock()
            .map_err(|_| "shutdown coordinator is unavailable")?;
        if self.complete.load(Ordering::Acquire) {
            return Ok(());
        }
        self.started.store(true, Ordering::Release);
        let participants = self
            .participants
            .lock()
            .map_err(|_| "shutdown participant registry is unavailable")?
            .clone();

        run_phase(&participants, "stop admission", |service| {
            service.stop_admission()
        })?;
        run_phase(&participants, "cancel and join producers", |service| {
            service.cancel_and_join_producers()
        })?;
        run_phase(&participants, "neutralize and release outputs", |service| {
            service.neutralize_and_release_outputs()
        })?;
        run_phase(&participants, "close ports and network", |service| {
            service.close_ports_and_network()
        })?;

        close_database().map_err(|error| format!("database shutdown failed: {error}"))?;
        self.complete.store(true, Ordering::Release);
        Ok(())
    }

    pub fn is_complete(&self) -> bool {
        self.complete.load(Ordering::Acquire)
    }
}

fn run_phase(
    participants: &[Arc<dyn ShutdownParticipant>],
    phase: &str,
    action: impl Fn(&dyn ShutdownParticipant) -> Result<(), String>,
) -> Result<(), String> {
    for participant in participants {
        action(participant.as_ref())
            .map_err(|error| format!("shutdown phase '{phase}' failed: {error}"))?;
    }
    Ok(())
}
