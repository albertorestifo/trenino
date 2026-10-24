//! Process-wide ownership for calibration and firmware access.
use std::sync::{Arc, Condvar, Mutex};
use std::time::{Duration, Instant};

pub trait ResourceConsumers: Send + Sync + 'static {
    /// Suspend ordinary actuation only for this resource's port.
    fn suspend_actuation(&self, port: &str) -> Result<(), String>;
    /// Request cancellation of the affected calibration. Its lease owner must release
    /// after its own cleanup; firmware acquisition waits for that release.
    fn cancel_calibration(&self, port: &str) -> Result<(), String>;
    fn source_lost(&self, port: &str, generation: u64) -> Result<(), String>;
    /// Must wait until the current generation has produced a fresh sample before resuming.
    fn resume_after_fresh_sample(&self, port: &str) -> Result<(), String>;
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum LeaseKind {
    Calibration { port: String, generation: u64 },
    Firmware { port: String, generation: u64 },
}

impl LeaseKind {
    fn port(&self) -> &str {
        match self {
            Self::Calibration { port, .. } | Self::Firmware { port, .. } => port,
        }
    }
    fn generation(&self) -> u64 {
        match self {
            Self::Calibration { generation, .. } | Self::Firmware { generation, .. } => *generation,
        }
    }
    fn is_firmware(&self) -> bool {
        matches!(self, Self::Firmware { .. })
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct LeaseToken(u64);

/// Capability proving a live firmware lease for one exact port generation. It is
/// borrowed from its arbiter so the lease cannot be released while handoff begins.
pub struct FirmwareHandoffPermit<'a> {
    arbiter: &'a ResourceArbiter,
    token: LeaseToken,
    port: String,
    generation: u64,
}

impl FirmwareHandoffPermit<'_> {
    pub fn authorizes(&self, port: &str, generation: u64) -> bool {
        if self.port != port || self.generation != generation {
            return false;
        }
        let state = self
            .arbiter
            .state
            .lock()
            .expect("resource arbiter poisoned");
        !state.transitioning
            && !state.fail_closed
            && matches!(
                &state.active,
                Some((token, LeaseKind::Firmware { port: active_port, generation: active_generation }))
                    if *token == self.token && active_port == port && *active_generation == generation
            )
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ResourceError {
    Busy,
    InvalidLease,
    CalibrationReleaseTimeout,
    ConsumerFailed(String),
}

#[derive(Default)]
struct State {
    next_id: u64,
    active: Option<(LeaseToken, LeaseKind)>,
    fail_closed: bool,
    transitioning: bool,
    release_in_progress: bool,
    shutting_down: bool,
}

/// Every simulator/vJoy and hardware service must share the same arbiter instance.
/// Its state lock and condition variable serialize lease transitions without holding
/// the lock while consumer callbacks run.
pub struct ResourceArbiter {
    state: Mutex<State>,
    released: Condvar,
    consumers: Arc<dyn ResourceConsumers>,
    handoff_timeout: Duration,
}

impl ResourceArbiter {
    pub fn new(consumers: Arc<dyn ResourceConsumers>) -> Self {
        Self {
            state: Mutex::new(State::default()),
            released: Condvar::new(),
            consumers,
            handoff_timeout: Duration::from_millis(5_000),
        }
    }

    pub fn with_handoff_timeout(mut self, timeout: Duration) -> Self {
        self.handoff_timeout = timeout;
        self
    }

    pub fn firmware_handoff_permit(
        &self,
        token: LeaseToken,
    ) -> Result<FirmwareHandoffPermit<'_>, ResourceError> {
        let state = self.state.lock().expect("resource arbiter poisoned");
        if state.transitioning || state.fail_closed || state.shutting_down {
            return Err(ResourceError::Busy);
        }
        let Some((active_token, LeaseKind::Firmware { port, generation })) = state.active.as_ref()
        else {
            return Err(ResourceError::InvalidLease);
        };
        if *active_token != token {
            return Err(ResourceError::InvalidLease);
        }
        Ok(FirmwareHandoffPermit {
            arbiter: self,
            token,
            port: port.clone(),
            generation: *generation,
        })
    }

    pub fn acquire(&self, kind: LeaseKind) -> Result<LeaseToken, ResourceError> {
        let mut state = self.state.lock().expect("resource arbiter poisoned");
        if state.transitioning || state.fail_closed {
            return Err(ResourceError::Busy);
        }
        let same_port_calibration = match (&kind, &state.active) {
            (
                LeaseKind::Firmware { port, .. },
                Some((
                    _,
                    LeaseKind::Calibration {
                        port: active_port, ..
                    },
                )),
            ) if port == active_port => true,
            (_, Some(_)) => return Err(ResourceError::Busy),
            _ => false,
        };

        if same_port_calibration {
            let (port, generation) = match &kind {
                LeaseKind::Firmware { port, generation } => (port.clone(), *generation),
                _ => unreachable!(),
            };
            state.transitioning = true;
            drop(state);
            if let Err(error) = self.consumers.cancel_calibration(&port) {
                self.fail_closed_transition();
                return Err(ResourceError::ConsumerFailed(error));
            }
            let deadline = Instant::now() + self.handoff_timeout;
            state = self.state.lock().expect("resource arbiter poisoned");
            while state.active.is_some() && Instant::now() < deadline {
                let remaining = deadline.saturating_duration_since(Instant::now());
                let (next, timeout) = self
                    .released
                    .wait_timeout(state, remaining)
                    .expect("resource arbiter poisoned");
                state = next;
                if timeout.timed_out() {
                    break;
                }
            }
            if state.active.is_some() {
                state.fail_closed = true;
                state.transitioning = false;
                return Err(ResourceError::CalibrationReleaseTimeout);
            }
            drop(state);
            if let Err(error) = self.consumers.source_lost(&port, generation) {
                self.fail_closed_transition();
                return Err(ResourceError::ConsumerFailed(error));
            }
            state = self.state.lock().expect("resource arbiter poisoned");
            let token = Self::next_token(&mut state);
            state.active = Some((token, kind));
            state.transitioning = false;
            self.released.notify_all();
            return Ok(token);
        }

        let token = Self::next_token(&mut state);
        state.active = Some((token, kind.clone()));
        state.transitioning = true;
        drop(state);
        let transition = (|| {
            self.consumers
                .suspend_actuation(kind.port())
                .map_err(ResourceError::ConsumerFailed)?;
            if kind.is_firmware() {
                self.consumers
                    .cancel_calibration(kind.port())
                    .map_err(ResourceError::ConsumerFailed)?;
                self.consumers
                    .source_lost(kind.port(), kind.generation())
                    .map_err(ResourceError::ConsumerFailed)?;
            }
            Ok(())
        })();
        let mut state = self.state.lock().expect("resource arbiter poisoned");
        state.transitioning = false;
        if transition.is_err() {
            state.fail_closed = true;
            self.released.notify_all();
            return transition.map(|()| token);
        }
        self.released.notify_all();
        Ok(token)
    }

    fn next_token(state: &mut State) -> LeaseToken {
        state.next_id = state.next_id.wrapping_add(1).max(1);
        LeaseToken(state.next_id)
    }

    fn fail_closed_transition(&self) {
        let mut state = self.state.lock().expect("resource arbiter poisoned");
        state.fail_closed = true;
        state.transitioning = false;
        state.release_in_progress = false;
        self.released.notify_all();
    }

    pub fn release(&self, token: LeaseToken) -> Result<(), ResourceError> {
        let mut state = self.state.lock().expect("resource arbiter poisoned");
        let Some((active_token, kind)) = state.active.as_ref() else {
            return Err(ResourceError::InvalidLease);
        };
        if *active_token != token {
            return Err(ResourceError::InvalidLease);
        }
        // A calibration being cancelled for firmware relinquishes ownership without
        // resuming actuation; the firmware handoff continues under the same suspension.
        if state.transitioning && !state.release_in_progress {
            state.active = None;
            self.released.notify_all();
            return Ok(());
        }
        if state.transitioning || state.fail_closed {
            return Err(ResourceError::Busy);
        }
        if state.shutting_down {
            state.active = None;
            state.fail_closed = true;
            self.released.notify_all();
            return Ok(());
        }
        let port = kind.port().to_owned();
        state.transitioning = true;
        state.release_in_progress = true;
        drop(state);
        let resumed = self.consumers.resume_after_fresh_sample(&port);
        let mut state = self.state.lock().expect("resource arbiter poisoned");
        state.transitioning = false;
        state.release_in_progress = false;
        match resumed {
            Ok(()) => {
                state.active = None;
                state.fail_closed = false;
                self.released.notify_all();
                Ok(())
            }
            Err(error) => {
                state.fail_closed = true;
                self.released.notify_all();
                Err(ResourceError::ConsumerFailed(error))
            }
        }
    }

    pub fn is_suspended(&self) -> bool {
        let state = self.state.lock().expect("resource arbiter poisoned");
        state.active.is_some() || state.fail_closed || state.transitioning || state.shutting_down
    }

    /// Stop lease admission and neutralize the active resource without resuming output.
    /// Shutdown deliberately leaves the arbiter suspended because no new sample owner
    /// will remain to establish a safe generation after the service closes.
    pub fn shutdown(&self) -> Result<(), ResourceError> {
        let active = {
            let mut state = self.state.lock().expect("resource arbiter poisoned");
            if state.transitioning {
                return Err(ResourceError::Busy);
            }
            state.shutting_down = true;
            let active = state.active.clone();
            state.transitioning = true;
            active
        };
        let transition = if let Some((_, kind)) = &active {
            self.consumers
                .cancel_calibration(kind.port())
                .map_err(ResourceError::ConsumerFailed)
                .and_then(|()| {
                    self.consumers
                        .source_lost(kind.port(), kind.generation())
                        .map_err(ResourceError::ConsumerFailed)
                })
        } else {
            Ok(())
        };
        let mut state = self.state.lock().expect("resource arbiter poisoned");
        state.transitioning = false;
        state.release_in_progress = false;
        if transition.is_ok() {
            state.active = None;
        }
        state.fail_closed = true;
        self.released.notify_all();
        transition
    }
}
