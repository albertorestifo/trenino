//! Owned detection and calibration state machines. The host keeps them alive
//! independently of UI request cancellation and feeds authoritative ordered events.
use std::collections::{HashMap, HashSet};
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
    baselines: HashMap<(String, u8), i16>,
    cancelled: bool,
    source_lost: bool,
}

impl InputDetectionSession {
    pub fn new(filter: InputKind, timeout: Duration) -> Self {
        Self {
            filter,
            deadline: Instant::now() + timeout,
            baselines: HashMap::new(),
            cancelled: false,
            source_lost: false,
        }
    }
    pub fn cancel(&mut self) {
        self.cancelled = true;
    }
    pub fn source_lost(&mut self) {
        self.source_lost = true;
    }
    pub fn observe(
        &mut self,
        port: &str,
        pin: u8,
        value: i16,
        kind: InputKind,
        identity: Option<InputIdentity>,
    ) -> DetectionOutcome {
        if self.cancelled {
            return DetectionOutcome::Cancelled;
        }
        if self.source_lost {
            return DetectionOutcome::SourceLost;
        }
        if Instant::now() >= self.deadline {
            return DetectionOutcome::TimedOut;
        }
        let key = (port.to_owned(), pin);
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
                return DetectionOutcome::Detected {
                    identity,
                    pin,
                    value,
                };
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
        }
    }
    pub fn step(&self) -> CalibrationStep {
        self.step
    }
    pub fn cancel(&mut self) {
        self.step = CalibrationStep::Cancelled;
    }
    pub fn source_lost(&mut self) {
        self.step = CalibrationStep::SourceLost;
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
        if self.sample_events.push((generation, pin, value)).is_err() {
            self.step = CalibrationStep::Overflowed;
            return Err(SessionError::Overflow);
        }
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
            repository
                .persist_calibration(self.input_id, calibration)
                .map_err(SessionError::Persist)?;
            Ok(Some(calibration))
        } else {
            Ok(None)
        }
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
}

impl HardwareSessions {
    pub fn insert_calibration(
        &self,
        session: CalibrationSession,
    ) -> Result<Arc<Mutex<CalibrationSession>>, SessionError> {
        let mut sessions = self
            .calibrations
            .lock()
            .expect("calibration session registry poisoned");
        if sessions.contains_key(&session.id) {
            return Err(SessionError::DuplicateId);
        }
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
        let mut sessions = self
            .detections
            .lock()
            .expect("input detection session registry poisoned");
        if sessions.contains_key(&id) {
            return Err(SessionError::DuplicateId);
        }
        let session = Arc::new(Mutex::new(session));
        sessions.insert(id, session.clone());
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
    }

    pub fn shutdown(&self) {
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
    }
}

impl From<QueueError> for SessionError {
    fn from(_: QueueError) -> Self {
        Self::Overflow
    }
}
