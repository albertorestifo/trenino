//! Owned detection and calibration state machines. The host keeps them alive
//! independently of UI request cancellation and feeds authoritative ordered events.
use std::collections::{HashMap, HashSet};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};

use trenino_core::hardware::calibration::{analyze, calculate_max, calculate_min, Calibration};
use trenino_core::{EntityId, SessionId};

use crate::routing::{EventQueue, InputIdentity, QueueError};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum InputKind {
    Any,
    Analog,
    Button,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DetectionOutcome {
    Detected {
        identity: InputIdentity,
        pin: u8,
        value: i16,
    },
    Pending,
    TimedOut,
    Cancelled,
    SourceLost,
}

pub struct InputDetectionSession {
    filter: InputKind,
    deadline: Instant,
    baselines: HashMap<(String, u64, u8), i16>,
    source: Option<(String, u64)>,
    terminal: Option<DetectionOutcome>,
    cancelled: bool,
    source_lost: bool,
}

impl InputDetectionSession {
    pub fn new(filter: InputKind, timeout: Duration) -> Self {
        Self {
            filter,
            deadline: Instant::now() + timeout,
            baselines: HashMap::new(),
            source: None,
            terminal: None,
            cancelled: false,
            source_lost: false,
        }
    }
    pub fn cancel(&mut self) {
        self.cancelled = true;
        if self.terminal.is_none() {
            self.terminal = Some(DetectionOutcome::Cancelled);
        }
    }
    pub fn source_lost(&mut self) {
        self.source_lost = true;
        self.baselines.clear();
        if self.terminal.is_none() {
            self.terminal = Some(DetectionOutcome::SourceLost);
        }
    }
    pub fn bind_source(&mut self, port: impl Into<String>, generation: u64) {
        self.source = Some((port.into(), generation));
    }
    pub fn terminal_outcome(&self) -> Option<DetectionOutcome> {
        self.terminal
    }
    pub fn deadline(&self) -> Instant {
        self.deadline
    }
    pub fn expire_if_due(&mut self, now: Instant) -> Option<DetectionOutcome> {
        if self.terminal.is_none() && now >= self.deadline {
            self.terminal = Some(DetectionOutcome::TimedOut);
        }
        self.terminal
    }
    pub fn source_lost_generation(&mut self, port: &str, generation: u64) {
        self.baselines
            .retain(|(baseline_port, baseline_gen, _), _| {
                baseline_port != port || *baseline_gen != generation
            });
        if self
            .source
            .as_ref()
            .is_some_and(|(source_port, source_generation)| {
                source_port == port && *source_generation == generation
            })
            && self.terminal.is_none()
        {
            self.source_lost = true;
            self.terminal = Some(DetectionOutcome::SourceLost);
        }
    }
    pub fn observe(
        &mut self,
        port: &str,
        pin: u8,
        value: i16,
        kind: InputKind,
        identity: Option<InputIdentity>,
    ) -> DetectionOutcome {
        self.observe_generation(port, 0, pin, value, kind, identity)
    }
    pub fn observe_generation(
        &mut self,
        port: &str,
        generation: u64,
        pin: u8,
        value: i16,
        kind: InputKind,
        identity: Option<InputIdentity>,
    ) -> DetectionOutcome {
        if let Some(terminal) = self.expire_if_due(Instant::now()) {
            return terminal;
        }
        if self.cancelled {
            return DetectionOutcome::Cancelled;
        }
        if self.source_lost {
            return DetectionOutcome::SourceLost;
        }
        if self
            .source
            .as_ref()
            .is_some_and(|(source_port, source_generation)| {
                source_port != port || *source_generation != generation
            })
        {
            return DetectionOutcome::Pending;
        }
        let key = (port.to_owned(), generation, pin);
        let Some(previous) = self.baselines.get(&key).copied() else {
            self.baselines.insert(key, value);
            return DetectionOutcome::Pending;
        };
        let threshold = match kind {
            InputKind::Button => previous != value,
            InputKind::Analog => (i32::from(previous) - i32::from(value)).abs() > 50,
            InputKind::Any => false,
        };
        if threshold && (self.filter == InputKind::Any || self.filter == kind) {
            if let Some(identity) = identity {
                let outcome = DetectionOutcome::Detected {
                    identity,
                    pin,
                    value,
                };
                self.terminal = Some(outcome);
                return outcome;
            }
        }
        DetectionOutcome::Pending
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CalibrationStep {
    Ready,
    CollectingMin,
    Sweeping,
    CollectingMax,
    Analyzing,
    Complete,
    Cancelled,
    SourceLost,
    Overflowed,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum SessionError {
    InvalidStep,
    InsufficientSamples,
    InsufficientSweepSamples,
    Overflow,
    Persist(String),
    DuplicateId,
    RegistryFull,
    AdmissionClosed,
}

pub trait CalibrationRepository {
    fn persist_calibration(
        &mut self,
        input_id: EntityId,
        calibration: Calibration,
    ) -> Result<(), String>;
}

pub struct CalibrationSession {
    pub id: SessionId,
    pub input_id: EntityId,
    pub port: String,
    pub generation: u64,
    pub pin: u8,
    pub max_hardware_value: i32,
    step: CalibrationStep,
    min_samples: Vec<i32>,
    sweep_samples: Vec<i32>,
    max_samples: Vec<i32>,
    sample_events: EventQueue<(u64, u8, i32)>,
    sample_limit: usize,
    retained_samples: usize,
    terminal_result: Option<Result<Calibration, SessionError>>,
}

impl CalibrationSession {
    pub const DEFAULT_QUEUE_CAPACITY: usize = 65_536;
    pub fn new(
        id: SessionId,
        input_id: EntityId,
        port: String,
        generation: u64,
        pin: u8,
        max_hardware_value: i32,
    ) -> Self {
        Self::with_capacity(
            id,
            input_id,
            port,
            generation,
            pin,
            max_hardware_value,
            Self::DEFAULT_QUEUE_CAPACITY,
        )
    }
    pub fn with_capacity(
        id: SessionId,
        input_id: EntityId,
        port: String,
        generation: u64,
        pin: u8,
        max_hardware_value: i32,
        capacity: usize,
    ) -> Self {
        Self {
            id,
            input_id,
            port,
            generation,
            pin,
            max_hardware_value,
            step: CalibrationStep::Ready,
            min_samples: Vec::new(),
            sweep_samples: Vec::new(),
            max_samples: Vec::new(),
            sample_events: EventQueue::new(capacity),
            sample_limit: capacity.max(1),
            retained_samples: 0,
            terminal_result: None,
        }
    }
    pub fn step(&self) -> CalibrationStep {
        self.step
    }
    pub fn cancel(&mut self) {
        if !matches!(
            self.step,
            CalibrationStep::Complete
                | CalibrationStep::Cancelled
                | CalibrationStep::Overflowed
                | CalibrationStep::SourceLost
        ) {
            self.step = CalibrationStep::Cancelled;
        }
    }
    pub fn source_lost(&mut self) {
        if !matches!(
            self.step,
            CalibrationStep::Complete
                | CalibrationStep::Cancelled
                | CalibrationStep::Overflowed
                | CalibrationStep::SourceLost
        ) {
            self.step = CalibrationStep::SourceLost;
        }
    }
    pub fn observe(&mut self, generation: u64, pin: u8, value: i32) -> Result<bool, SessionError> {
        if generation != self.generation || pin != self.pin {
            return Ok(false);
        }
        if !matches!(
            self.step,
            CalibrationStep::CollectingMin
                | CalibrationStep::Sweeping
                | CalibrationStep::CollectingMax
        ) {
            return Ok(false);
        }
        if self.retained_samples >= self.sample_limit {
            self.step = CalibrationStep::Overflowed;
            self.terminal_result = Some(Err(SessionError::Overflow));
            return Err(SessionError::Overflow);
        }
        if self.sample_events.push((generation, pin, value)).is_err() {
            self.step = CalibrationStep::Overflowed;
            self.terminal_result = Some(Err(SessionError::Overflow));
            return Err(SessionError::Overflow);
        }
        self.retained_samples += 1;
        match self.step {
            CalibrationStep::CollectingMin => self.min_samples.push(value),
            CalibrationStep::Sweeping => self.sweep_samples.push(value),
            CalibrationStep::CollectingMax => self.max_samples.push(value),
            _ => unreachable!(),
        }
        Ok(true)
    }
    pub fn sample_count(&self) -> usize {
        self.sample_events.len()
    }
    pub fn take_sample_event(&self) -> Option<(u64, u8, i32)> {
        self.sample_events.pop()
    }
    pub fn advance(&mut self) -> Result<Option<Calibration>, SessionError> {
        match self.step {
            CalibrationStep::Ready => self.step = CalibrationStep::CollectingMin,
            CalibrationStep::CollectingMin => {
                if !valid(&self.min_samples) {
                    return Err(SessionError::InsufficientSamples);
                }
                self.step = CalibrationStep::Sweeping;
            }
            CalibrationStep::Sweeping => {
                if self.sweep_samples.len() < 10 {
                    return Err(SessionError::InsufficientSweepSamples);
                }
                self.step = CalibrationStep::CollectingMax;
            }
            CalibrationStep::CollectingMax => {
                if !valid(&self.max_samples) {
                    return Err(SessionError::InsufficientSamples);
                }
                self.step = CalibrationStep::Analyzing;
                let analysis = analyze(&self.sweep_samples, self.max_hardware_value);
                let result = Calibration {
                    min_value: calculate_min(&self.min_samples, analysis).unwrap(),
                    max_value: calculate_max(&self.max_samples, analysis).unwrap(),
                    max_hardware_value: self.max_hardware_value,
                    inverted: analysis.inverted,
                    rollover: analysis.rollover,
                };
                self.step = CalibrationStep::Complete;
                self.terminal_result = Some(Ok(result));
                return Ok(Some(result));
            }
            _ => return Err(SessionError::InvalidStep),
        }
        Ok(None)
    }

    pub fn advance_and_persist<R: CalibrationRepository>(
        &mut self,
        repository: &mut R,
    ) -> Result<Option<Calibration>, SessionError> {
        let result = self.advance()?;
        if let Some(calibration) = result {
            if let Err(error) = repository.persist_calibration(self.input_id, calibration) {
                let error = SessionError::Persist(error);
                self.terminal_result = Some(Err(error.clone()));
                return Err(error);
            }
            Ok(Some(calibration))
        } else {
            Ok(None)
        }
    }

    pub fn terminal_result(&self) -> Option<Result<Calibration, SessionError>> {
        self.terminal_result.clone()
    }
}

fn valid(samples: &[i32]) -> bool {
    samples.len() >= 10 && samples.iter().copied().collect::<HashSet<_>>().len() >= 3
}

/// Runtime-owned session registry: dropping a UI handle does not destroy a session.
/// Lifecycle changes are explicit through cancel/source-loss/shutdown transitions.
#[derive(Default)]
pub struct HardwareSessions {
    calibrations: Mutex<HashMap<SessionId, Arc<Mutex<CalibrationSession>>>>,
    detections: Mutex<HashMap<SessionId, Arc<Mutex<InputDetectionSession>>>>,
    detection_workers: Mutex<HashMap<SessionId, std::thread::JoinHandle<()>>>,
    session_count: AtomicUsize,
    admission_closed: Mutex<bool>,
}

const MAX_OWNED_SESSIONS: usize = 1024;

impl HardwareSessions {
    pub fn insert_calibration(
        &self,
        session: CalibrationSession,
    ) -> Result<Arc<Mutex<CalibrationSession>>, SessionError> {
        let admission = self.admission_closed.lock().expect("session admission poisoned");
        if *admission { return Err(SessionError::AdmissionClosed); }
        let mut sessions = self
            .calibrations
            .lock()
            .expect("calibration session registry poisoned");
        if sessions.contains_key(&session.id) {
            return Err(SessionError::DuplicateId);
        }
        self.reserve_slot()?;
        let session = Arc::new(Mutex::new(session));
        let id = session.lock().expect("calibration session poisoned").id;
        sessions.insert(id, session.clone());
        Ok(session)
    }

    pub fn insert_detection(
        &self,
        id: SessionId,
        session: InputDetectionSession,
    ) -> Result<Arc<Mutex<InputDetectionSession>>, SessionError> {
        self.insert_detection_with_callback(id, session, |_| {})
    }

    pub fn insert_detection_with_callback<F>(
        &self,
        id: SessionId,
        session: InputDetectionSession,
        on_terminal: F,
    ) -> Result<Arc<Mutex<InputDetectionSession>>, SessionError>
    where
        F: FnOnce(DetectionOutcome) + Send + 'static,
    {
        let admission = self.admission_closed.lock().expect("session admission poisoned");
        if *admission { return Err(SessionError::AdmissionClosed); }
        let mut sessions = self
            .detections
            .lock()
            .expect("input detection session registry poisoned");
        if sessions.contains_key(&id) {
            return Err(SessionError::DuplicateId);
        }
        self.reserve_slot()?;
        let session = Arc::new(Mutex::new(session));
        sessions.insert(id, session.clone());
        drop(sessions);
        let owned_session = session.clone();
        let mut on_terminal = Some(on_terminal);
        let worker = match std::thread::Builder::new()
            .name(format!("input-detection-{}", id.0))
            .spawn(move || loop {
                let mut session = owned_session
                    .lock()
                    .expect("input detection session poisoned");
                if let Some(outcome) = session.expire_if_due(Instant::now()) {
                    drop(session);
                    on_terminal
                        .take()
                        .expect("terminal callback is consumed once")(outcome);
                    break;
                }
                let remaining = session.deadline().saturating_duration_since(Instant::now());
                drop(session);
                std::thread::sleep(remaining.min(Duration::from_millis(10)));
            }) {
            Ok(worker) => worker,
            Err(error) => {
                self.detections
                    .lock()
                    .expect("input detection session registry poisoned")
                    .remove(&id);
                self.session_count.fetch_sub(1, Ordering::AcqRel);
                return Err(SessionError::Persist(format!(
                    "failed to spawn detection owner: {error}"
                )));
            }
        };
        self.detection_workers
            .lock()
            .expect("detection worker registry poisoned")
            .insert(id, worker);
        drop(admission);
        Ok(session)
    }

    pub fn calibration(&self, id: SessionId) -> Option<Arc<Mutex<CalibrationSession>>> {
        self.calibrations
            .lock()
            .expect("calibration session registry poisoned")
            .get(&id)
            .cloned()
    }

    pub fn detection(&self, id: SessionId) -> Option<Arc<Mutex<InputDetectionSession>>> {
        self.detections
            .lock()
            .expect("input detection session registry poisoned")
            .get(&id)
            .cloned()
    }

    fn reserve_slot(&self) -> Result<(), SessionError> {
        self.session_count
            .fetch_update(Ordering::AcqRel, Ordering::Acquire, |count| {
                (count < MAX_OWNED_SESSIONS).then_some(count + 1)
            })
            .map(|_| ())
            .map_err(|_| SessionError::RegistryFull)
    }

    /// Remove a terminal session and join its owned timer task. Nonterminal work is
    /// retained and cannot be accidentally garbage-collected by a dropped UI handle.
    pub fn reap_terminal(&self, id: SessionId) -> bool {
        let detection_terminal = self.detection(id).is_some_and(|session| {
            session
                .lock()
                .expect("input detection session poisoned")
                .terminal_outcome()
                .is_some()
        });
        if detection_terminal {
            self.detections
                .lock()
                .expect("input detection session registry poisoned")
                .remove(&id);
            self.session_count.fetch_sub(1, Ordering::AcqRel);
            if let Some(worker) = self
                .detection_workers
                .lock()
                .expect("detection worker registry poisoned")
                .remove(&id)
            {
                let _ = worker.join();
            }
            return true;
        }
        let calibration_terminal = self.calibration(id).is_some_and(|session| {
            matches!(
                session.lock().expect("calibration session poisoned").step(),
                CalibrationStep::Complete
                    | CalibrationStep::Cancelled
                    | CalibrationStep::SourceLost
                    | CalibrationStep::Overflowed
            )
        });
        if calibration_terminal {
            self.calibrations
                .lock()
                .expect("calibration session registry poisoned")
                .remove(&id);
            self.session_count.fetch_sub(1, Ordering::AcqRel);
            return true;
        }
        false
    }

    pub fn cancel_calibration(&self, id: SessionId) -> bool {
        if let Some(session) = self.calibration(id) {
            session
                .lock()
                .expect("calibration session poisoned")
                .cancel();
            true
        } else {
            false
        }
    }

    pub fn cancel_calibrations_on(&self, port: &str) -> Vec<SessionId> {
        let sessions = self
            .calibrations
            .lock()
            .expect("calibration session registry poisoned");
        let mut cancelled = Vec::new();
        for (id, session) in sessions.iter() {
            let mut session = session.lock().expect("calibration session poisoned");
            if session.port == port
                && !matches!(
                    session.step(),
                    CalibrationStep::Complete
                        | CalibrationStep::Cancelled
                        | CalibrationStep::SourceLost
                        | CalibrationStep::Overflowed
                )
            {
                session.cancel();
                cancelled.push(*id);
            }
        }
        cancelled
    }

    pub fn cancel_detection(&self, id: SessionId) -> bool {
        if let Some(session) = self.detection(id) {
            session
                .lock()
                .expect("input detection session poisoned")
                .cancel();
            true
        } else {
            false
        }
    }

    pub fn source_lost(&self, port: &str, generation: u64) {
        for session in self
            .calibrations
            .lock()
            .expect("calibration session registry poisoned")
            .values()
        {
            let mut session = session.lock().expect("calibration session poisoned");
            if session.port == port && session.generation == generation {
                session.source_lost();
            }
        }
        for session in self
            .detections
            .lock()
            .expect("input detection session registry poisoned")
            .values()
        {
            session
                .lock()
                .expect("input detection session poisoned")
                .source_lost_generation(port, generation);
        }
    }

    pub fn observe_input(
        &self,
        port: &str,
        generation: u64,
        pin: u8,
        value: i16,
        kind: InputKind,
        identity: Option<InputIdentity>,
    ) -> Vec<(SessionId, DetectionOutcome)> {
        self.detections
            .lock()
            .expect("input detection session registry poisoned")
            .iter()
            .map(|(id, session)| {
                let outcome = session
                    .lock()
                    .expect("input detection session poisoned")
                    .observe_generation(port, generation, pin, value, kind, identity);
                (*id, outcome)
            })
            .collect()
    }

    pub fn observe_calibrations(
        &self,
        port: &str,
        generation: u64,
        pin: u8,
        value: i16,
    ) -> Vec<(SessionId, Result<bool, SessionError>)> {
        self.calibrations
            .lock()
            .expect("calibration session registry poisoned")
            .iter()
            .filter_map(|(id, session)| {
                let mut session = session.lock().expect("calibration session poisoned");
                if session.port != port || session.generation != generation || session.pin != pin {
                    return None;
                }
                Some((*id, session.observe(generation, pin, i32::from(value))))
            })
            .collect()
    }

    pub fn shutdown(&self) {
        self.close_admission();
        for session in self
            .calibrations
            .lock()
            .expect("calibration session registry poisoned")
            .values()
        {
            session
                .lock()
                .expect("calibration session poisoned")
                .cancel();
        }
        for session in self
            .detections
            .lock()
            .expect("input detection session registry poisoned")
            .values()
        {
            session
                .lock()
                .expect("input detection session poisoned")
                .cancel();
        }
        let workers = std::mem::take(
            &mut *self
                .detection_workers
                .lock()
                .expect("detection worker registry poisoned"),
        );
        for (_, worker) in workers {
            let _ = worker.join();
        }
    }

    pub fn close_admission(&self) {
        *self.admission_closed.lock().expect("session admission poisoned") = true;
    }
}

impl From<QueueError> for SessionError {
    fn from(_: QueueError) -> Self {
        Self::Overflow
    }
}
