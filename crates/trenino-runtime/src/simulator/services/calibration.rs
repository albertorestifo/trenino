//! Live lever/notch calibration.
//!
//! Ports of `Trenino.Train.Calibration.LeverSession`
//! (lib/trenino/train/calibration/lever_session.ex — automated sweep with step
//! 0.025, gate tolerance 0.001, 5ms step delay, progress broadcasts and a final
//! committed save) and `Trenino.Train.Calibration.NotchMappingSession`
//! (lib/trenino/train/calibration/notch_mapping_session.ex — the wizard that
//! captures hardware notch ranges, validates them, auto-detects inversion and
//! saves normalized 0.0-1.0 input ranges).
//!
//! Persistence goes through the small [`CalibrationStore`] port (fake in tests;
//! wave 2 wires the trains repository). The notch mapping wizard checkpoints
//! every captured range so a cancelled session resumes where it left off;
//! cancellation discards uncommitted samples without rolling back checkpoints
//! that were already committed.

use crate::resource::{LeaseKind, ResourceArbiter, ResourceError};
use crate::simulator::client::{SimulatorClient, SimulatorError};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::sync::Arc;
use std::time::Duration;
use tokio::sync::{mpsc, oneshot, Mutex};
use trenino_core::hardware::calibration::{normalize, total_travel, Calibration};
use trenino_core::rounding::round_elixir;

use super::clock::Clock;
use super::session::{spawn_leased_session, SessionHandle};

pub const CALIBRATION_STEP: f64 = 0.025;
pub const GATE_TOLERANCE: f64 = 0.001;
pub const STEP_DELAY: Duration = Duration::from_millis(5);
pub const MIN_SAMPLE_COUNT: usize = 10;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NotchKind {
    Gate,
    Linear,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct NotchDraft {
    pub index: i64,
    pub kind: NotchKind,
    pub value: Option<f64>,
    pub min_value: Option<f64>,
    pub max_value: Option<f64>,
    pub description: String,
}

/// The lever-config endpoints a calibration sweep drives, mirroring the
/// `LeverConfig` fields consumed by `LeverSession`.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct LeverEndpointSet {
    pub lever_config_id: i64,
    pub min_endpoint: String,
    pub max_endpoint: String,
    pub value_endpoint: String,
    pub notch_count_endpoint: String,
    pub notch_index_endpoint: String,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CalibrationStep {
    Initializing,
    Calibrating,
    Saving,
    Complete,
    Error,
}

#[derive(Clone, Debug, PartialEq)]
pub struct CalibrationProgress {
    pub lever_config_id: i64,
    pub step: CalibrationStep,
    pub progress: f64,
    pub current_value: f64,
    pub notch_count: usize,
}

#[derive(Clone, Debug, PartialEq)]
pub struct CompletedCalibration {
    pub lever_config_id: i64,
    pub notches: Vec<NotchDraft>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum CalibrationFailure {
    Simulator(SimulatorError),
    Store(CalibrationStoreError),
}

#[derive(Clone, Debug, PartialEq)]
pub enum CalibrationEvent {
    Progress(CalibrationProgress),
    Result(Result<CompletedCalibration, CalibrationFailure>),
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CalibrationStoreError(pub String);

/// Persistence port for the calibration wizard (fake in tests; the trains
/// repository implements it in wave 2).
pub trait CalibrationStore: Send + Sync + 'static {
    /// Mirrors `Train.save_calibration/2` (committed when LeverSession finishes).
    fn save_lever_calibration(
        &self,
        lever_config_id: i64,
        notches: &[NotchDraft],
    ) -> Result<(), CalibrationStoreError>;
    /// Mirrors `Train.update_notch_input_ranges/3`.
    fn save_notch_input_ranges(
        &self,
        lever_config_id: i64,
        updates: &[NotchRangeUpdate],
        inverted: bool,
    ) -> Result<(), CalibrationStoreError>;
    /// Wizard checkpoint of notch-mapping progress (persist + resume).
    fn save_mapping_checkpoint(
        &self,
        lever_config_id: i64,
        checkpoint: &MappingCheckpoint,
    ) -> Result<(), CalibrationStoreError>;
    fn load_mapping_checkpoint(
        &self,
        lever_config_id: i64,
    ) -> Result<Option<MappingCheckpoint>, CalibrationStoreError>;
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct SampleRange {
    pub min: i64,
    pub max: i64,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct MappingCheckpoint {
    pub lever_config_id: i64,
    pub captured_ranges: Vec<Option<SampleRange>>,
    pub next_notch_index: usize,
}

#[derive(Clone, Debug, PartialEq)]
pub struct NotchRangeUpdate {
    pub notch_id: i64,
    pub input_min: f64,
    pub input_max: f64,
}

// ---------------------------------------------------------------------------
// Lever calibration session (LeverSession port)
// ---------------------------------------------------------------------------
/// Start the automated lever calibration holding `lease` for the whole sweep.
pub fn start_lever_calibration(
    client: Arc<SimulatorClient>,
    arbiter: &Arc<ResourceArbiter>,
    lease: LeaseKind,
    clock: Arc<dyn Clock>,
    endpoints: LeverEndpointSet,
    store: Arc<dyn CalibrationStore>,
) -> Result<SessionHandle<CalibrationEvent>, ResourceError> {
    spawn_leased_session(
        arbiter,
        lease,
        |progress| async move { calibrate(&client, &clock, &endpoints, &store, &progress).await },
        || async {},
    )
}

async fn calibrate(
    client: &Arc<SimulatorClient>,
    clock: &Arc<dyn Clock>,
    endpoints: &LeverEndpointSet,
    store: &Arc<dyn CalibrationStore>,
    progress: &mpsc::Sender<CalibrationEvent>,
) -> Option<CalibrationEvent> {
    match run_calibration(client, clock, endpoints, store, progress).await {
        Ok(Some(event)) | Err(event) => Some(event),
        Ok(None) => None,
    }
}

/// Runs the LeverSession flow. `Ok(None)` marks a failure already reported
/// through the progress channel (init errors broadcast only the result).
type CalibrationResult = Result<Option<CalibrationEvent>, CalibrationEvent>;

async fn run_calibration(
    client: &Arc<SimulatorClient>,
    clock: &Arc<dyn Clock>,
    endpoints: &LeverEndpointSet,
    store: &Arc<dyn CalibrationStore>,
    progress: &mpsc::Sender<CalibrationEvent>,
) -> CalibrationResult {
    // initialize_calibration/1
    let init = async {
        let min_value = client.get_float(&endpoints.min_endpoint).await?;
        let max_value = client.get_float(&endpoints.max_endpoint).await?;
        let notch_count = client.get_int(&endpoints.notch_count_endpoint).await?;
        Ok::<(f64, f64, i64), SimulatorError>((min_value, max_value, notch_count))
    }
    .await;
    let (min_value, max_value, notch_count) = match init {
        Ok(values) => values,
        Err(reason) => {
            return Err(CalibrationEvent::Result(Err(
                CalibrationFailure::Simulator(reason),
            )))
        }
    };
    let mut sweep = SweepState {
        min_value,
        max_value,
        current_value: min_value,
        current_notch_index: 0,
        current_notch_start: min_value,
        current_notch_type: None,
        current_gate_value: None,
        notches: Vec::new(),
        progress: 0.0,
    };
    if notch_count == 1 {
        // Single notch: a linear notch spanning the full range, saved directly.
        sweep.notches.push(NotchDraft {
            index: 0,
            kind: NotchKind::Linear,
            value: None,
            min_value: Some(min_value),
            max_value: Some(max_value),
            description: "Notch 0".into(),
        });
        sweep.progress = 1.0;
        publish_calibration_progress(
            progress,
            endpoints.lever_config_id,
            &sweep,
            CalibrationStep::Saving,
        );
        return finish_calibration(endpoints.lever_config_id, &sweep.notches, store).await;
    }
    // Multi-notch: park the lever at the minimum and read the starting notch.
    if let Err(reason) = client
        .set(&endpoints.value_endpoint, &Value::from(min_value))
        .await
    {
        return Err(CalibrationEvent::Result(Err(
            CalibrationFailure::Simulator(reason),
        )));
    }
    sweep.current_notch_index = match client.get_int(&endpoints.notch_index_endpoint).await {
        Ok(index) => index,
        Err(reason) => {
            return Err(CalibrationEvent::Result(Err(
                CalibrationFailure::Simulator(reason),
            )))
        }
    };
    publish_calibration_progress(
        progress,
        endpoints.lever_config_id,
        &sweep,
        CalibrationStep::Calibrating,
    );
    // calibrate_step loop
    loop {
        let next_value = sweep.current_value + CALIBRATION_STEP;
        if next_value >= sweep.max_value - GATE_TOLERANCE {
            break;
        }
        sweep = match calibrate_step(client, clock, endpoints, sweep, next_value, progress).await {
            Ok(sweep) => sweep,
            Err(reason) => {
                return Err(CalibrationEvent::Result(Err(
                    CalibrationFailure::Simulator(reason),
                )))
            }
        };
    }
    // finalize_notches/1: the last notch ends at the maximum value.
    sweep
        .notches
        .push(build_notch_from_state(&sweep, sweep.max_value));
    finish_calibration(endpoints.lever_config_id, &sweep.notches, store).await
}

async fn finish_calibration(
    lever_config_id: i64,
    notches: &[NotchDraft],
    store: &Arc<dyn CalibrationStore>,
) -> CalibrationResult {
    let result = store
        .save_lever_calibration(lever_config_id, notches)
        .map_err(CalibrationFailure::Store);
    Ok(Some(CalibrationEvent::Result(match result {
        Ok(()) => Ok(CompletedCalibration {
            lever_config_id,
            notches: notches.to_vec(),
        }),
        Err(failure) => Err(failure),
    })))
}

async fn calibrate_step(
    client: &Arc<SimulatorClient>,
    clock: &Arc<dyn Clock>,
    endpoints: &LeverEndpointSet,
    mut sweep: SweepState,
    next_value: f64,
    progress: &mpsc::Sender<CalibrationEvent>,
) -> Result<SweepState, SimulatorError> {
    client
        .set(&endpoints.value_endpoint, &Value::from(next_value))
        .await?;
    let read_value = client.get_float(&endpoints.value_endpoint).await?;
    let notch_index = client.get_int(&endpoints.notch_index_endpoint).await?;
    sweep.progress = (next_value - sweep.min_value) / (sweep.max_value - sweep.min_value);
    if notch_index != sweep.current_notch_index {
        // Notch changed: record the completed notch and start a new one.
        let notch = build_notch_from_state(&sweep, next_value);
        sweep.notches.push(notch);
        sweep.current_notch_index = notch_index;
        sweep.current_notch_start = next_value;
        sweep.current_notch_type = None;
        sweep.current_gate_value = None;
    } else {
        update_notch_type(&mut sweep, next_value, read_value);
    }
    sweep.current_value = next_value;
    publish_calibration_progress(
        progress,
        endpoints.lever_config_id,
        &sweep,
        CalibrationStep::Calibrating,
    );
    clock.sleep(STEP_DELAY).await;
    Ok(sweep)
}

fn publish_calibration_progress(
    progress: &mpsc::Sender<CalibrationEvent>,
    lever_config_id: i64,
    sweep: &SweepState,
    step: CalibrationStep,
) {
    let _ = progress.try_send(CalibrationEvent::Progress(CalibrationProgress {
        lever_config_id,
        step,
        progress: sweep.progress,
        current_value: sweep.current_value,
        notch_count: sweep.notches.len(),
    }));
}

struct SweepState {
    min_value: f64,
    max_value: f64,
    current_value: f64,
    current_notch_index: i64,
    current_notch_start: f64,
    current_notch_type: Option<NotchKind>,
    current_gate_value: Option<f64>,
    notches: Vec<NotchDraft>,
    progress: f64,
}

fn update_notch_type(sweep: &mut SweepState, set_value: f64, read_value: f64) {
    let is_gate = (set_value - read_value).abs() >= GATE_TOLERANCE;
    if is_gate {
        // Gate behavior takes precedence and captures the snapped position.
        sweep.current_notch_type = Some(NotchKind::Gate);
        sweep.current_gate_value = Some(read_value);
    } else if sweep.current_notch_type != Some(NotchKind::Gate) {
        sweep.current_notch_type = Some(NotchKind::Linear);
    }
}

fn build_notch_from_state(sweep: &SweepState, end_value: f64) -> NotchDraft {
    let index = sweep.current_notch_index;
    let description = format!("Notch {index}");
    match sweep.current_notch_type.unwrap_or(NotchKind::Gate) {
        NotchKind::Gate => NotchDraft {
            index,
            kind: NotchKind::Gate,
            value: Some(round2(
                sweep
                    .current_gate_value
                    .unwrap_or(sweep.current_notch_start),
            )),
            min_value: None,
            max_value: None,
            description,
        },
        NotchKind::Linear => NotchDraft {
            index,
            kind: NotchKind::Linear,
            value: None,
            min_value: Some(round2(sweep.current_notch_start)),
            max_value: Some(round2(end_value)),
            description,
        },
    }
}

fn round2(value: f64) -> f64 {
    round_elixir(value, 2).unwrap_or(value)
}

// ---------------------------------------------------------------------------
// Notch mapping session (NotchMappingSession port)
// ---------------------------------------------------------------------------

#[derive(Clone, Debug, PartialEq)]
pub struct NotchDefinition {
    pub id: i64,
    pub index: i64,
    pub kind: NotchKind,
    pub description: String,
    pub sim_input_min: Option<f64>,
    pub sim_input_max: Option<f64>,
}

#[derive(Clone)]
pub struct NotchMappingConfig {
    pub lever_config_id: i64,
    pub pin: u8,
    pub calibration: Calibration,
    pub notches: Vec<NotchDefinition>,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum MappingStep {
    Ready,
    Notch(usize),
    Preview,
    Saving,
    Complete,
}

#[derive(Clone, Debug, PartialEq)]
pub struct MappingPublicState {
    pub lever_config_id: i64,
    pub notch_count: usize,
    pub notches: Vec<NotchDefinition>,
    pub total_travel: i64,
    pub current_step: MappingStep,
    pub current_notch_index: Option<usize>,
    pub is_capturing: bool,
    pub captured_ranges: Vec<Option<SampleRange>>,
    pub current_value: Option<i64>,
    pub current_min: Option<i64>,
    pub current_max: Option<i64>,
    pub sample_count: usize,
    pub can_capture: bool,
    pub all_captured: bool,
    pub is_stable: bool,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum MappingError {
    InvalidStep,
    NoSamples,
    NoRangeDetected,
    InvalidNotchIndex,
    IncompleteRanges,
    Store(CalibrationStoreError),
}

#[derive(Clone, Debug, PartialEq)]
pub struct CompletedMapping {
    pub lever_config_id: i64,
    pub inverted: bool,
    pub updates: Vec<NotchRangeUpdate>,
}

#[derive(Clone, Debug, PartialEq)]
pub enum MappingEvent {
    SessionStarted(MappingPublicState),
    StepChanged(MappingPublicState),
    SampleUpdated(MappingPublicState),
    CaptureStarted(MappingPublicState),
    CaptureStopped(MappingPublicState),
    MappingResult(Result<CompletedMapping, MappingError>),
}

enum MappingCommand {
    StartMapping(oneshot::Sender<Result<(), MappingError>>),
    StartCapturing(oneshot::Sender<Result<(), MappingError>>),
    StopCapturing(oneshot::Sender<Result<(), MappingError>>),
    ResetSamples(oneshot::Sender<Result<(), MappingError>>),
    CaptureRange(oneshot::Sender<Result<(), MappingError>>),
    GoToNotch(usize, oneshot::Sender<Result<(), MappingError>>),
    GoToPreview(oneshot::Sender<Result<(), MappingError>>),
    SaveMapping(oneshot::Sender<Result<CompletedMapping, MappingError>>),
    InputSample { pin: u8, raw_value: i32 },
    Cancel,
}

struct MappingState {
    config: NotchMappingConfig,
    total_travel: i64,
    current_step: MappingStep,
    is_capturing: bool,
    captured_ranges: Vec<Option<SampleRange>>,
    current_samples: Vec<i64>,
    current_value: Option<i64>,
    current_min: Option<i64>,
    current_max: Option<i64>,
}

#[derive(Debug)]
pub enum MappingStartError {
    Resource(ResourceError),
    Store(CalibrationStoreError),
}

impl From<ResourceError> for MappingStartError {
    fn from(error: ResourceError) -> Self {
        Self::Resource(error)
    }
}

pub struct NotchMappingMonitor {
    commands: mpsc::Sender<MappingCommand>,
    worker: Arc<Mutex<Option<tokio::task::JoinHandle<()>>>>,
}

impl NotchMappingMonitor {
    pub async fn start_mapping(&self) -> Result<(), MappingError> {
        self.call(MappingCommand::StartMapping).await
    }
    pub async fn start_capturing(&self) -> Result<(), MappingError> {
        self.call(MappingCommand::StartCapturing).await
    }
    pub async fn stop_capturing(&self) -> Result<(), MappingError> {
        self.call(MappingCommand::StopCapturing).await
    }
    pub async fn reset_samples(&self) -> Result<(), MappingError> {
        self.call(MappingCommand::ResetSamples).await
    }
    pub async fn capture_range(&self) -> Result<(), MappingError> {
        self.call(MappingCommand::CaptureRange).await
    }
    pub async fn go_to_notch(&self, index: usize) -> Result<(), MappingError> {
        self.call(move |reply| MappingCommand::GoToNotch(index, reply))
            .await
    }
    pub async fn go_to_preview(&self) -> Result<(), MappingError> {
        self.call(MappingCommand::GoToPreview).await
    }
    pub async fn save_mapping(&self) -> Result<CompletedMapping, MappingError> {
        self.call(MappingCommand::SaveMapping).await
    }
    pub async fn input_sample(&self, pin: u8, raw_value: i32) {
        let _ = self
            .commands
            .send(MappingCommand::InputSample { pin, raw_value })
            .await;
    }
    /// Cancel the wizard; committed checkpoints remain persisted.
    pub async fn cancel(self) -> Result<(), MappingError> {
        self.commands
            .send(MappingCommand::Cancel)
            .await
            .map_err(|_| MappingError::InvalidStep)?;
        let mut slot = self.worker.lock().await;
        if let Some(handle) = slot.as_mut() {
            handle.await.map_err(|_| MappingError::InvalidStep)?;
            *slot = None;
        }
        Ok(())
    }

    async fn call<T>(
        &self,
        build: impl FnOnce(oneshot::Sender<Result<T, MappingError>>) -> MappingCommand,
    ) -> Result<T, MappingError> {
        let (reply, reply_receiver) = oneshot::channel();
        self.commands
            .send(build(reply))
            .await
            .map_err(|_| MappingError::InvalidStep)?;
        reply_receiver
            .await
            .unwrap_or(Err(MappingError::InvalidStep))
    }
}

/// Dropping the monitor stops the session and releases its lease; committed
/// wizard checkpoints stay visible in the store.
impl Drop for NotchMappingMonitor {
    fn drop(&mut self) {}
}

/// Start the notch mapping wizard. Restores any persisted checkpoint so a
/// cancelled wizard resumes its captured ranges.
pub fn start_notch_mapping(
    arbiter: &Arc<ResourceArbiter>,
    lease: LeaseKind,
    config: NotchMappingConfig,
    store: Arc<dyn CalibrationStore>,
) -> Result<(NotchMappingMonitor, mpsc::Receiver<MappingEvent>), MappingStartError> {
    let token = arbiter.acquire(lease)?;
    let (commands, mut command_receiver) = mpsc::channel(64);
    let (events, event_receiver) = mpsc::channel(64);
    let mut notches = config.notches.clone();
    notches.sort_by_key(|notch| notch.index);
    let mut state = MappingState {
        total_travel: total_travel(&config.calibration),
        current_step: MappingStep::Ready,
        is_capturing: false,
        captured_ranges: vec![None; notches.len()],
        current_samples: Vec::new(),
        current_value: None,
        current_min: None,
        current_max: None,
        config,
    };
    state.config.notches = notches;
    // Resume: a stored checkpoint restores captured ranges (Rust-wave
    // extension; the Elixir wizard always starts from scratch).
    if let Ok(Some(checkpoint)) = store.load_mapping_checkpoint(state.config.lever_config_id) {
        if checkpoint.captured_ranges.len() == state.captured_ranges.len() {
            state.captured_ranges = checkpoint.captured_ranges;
        }
    }
    publish(&events, MappingEvent::SessionStarted(public_state(&state)));
    let release_arbiter = arbiter.clone();
    let worker = tokio::spawn(async move {
        while let Some(command) = command_receiver.recv().await {
            match command {
                MappingCommand::StartMapping(reply) => {
                    let result = if state.current_step == MappingStep::Ready {
                        let first_open = state
                            .captured_ranges
                            .iter()
                            .position(|range| range.is_none())
                            .unwrap_or(0);
                        state.current_step = MappingStep::Notch(first_open);
                        state.is_capturing = false;
                        state.current_samples.clear();
                        state.current_min = None;
                        state.current_max = None;
                        publish(&events, MappingEvent::StepChanged(public_state(&state)));
                        Ok(())
                    } else {
                        Err(MappingError::InvalidStep)
                    };
                    let _ = reply.send(result);
                }
                MappingCommand::StartCapturing(reply) => {
                    let result = if matches!(state.current_step, MappingStep::Notch(_)) {
                        state.is_capturing = true;
                        state.current_samples.clear();
                        state.current_min = None;
                        state.current_max = None;
                        publish(&events, MappingEvent::CaptureStarted(public_state(&state)));
                        Ok(())
                    } else {
                        Err(MappingError::InvalidStep)
                    };
                    let _ = reply.send(result);
                }
                MappingCommand::StopCapturing(reply) => {
                    let result = if matches!(state.current_step, MappingStep::Notch(_)) {
                        state.is_capturing = false;
                        state.current_samples.clear();
                        state.current_min = None;
                        state.current_max = None;
                        publish(&events, MappingEvent::CaptureStopped(public_state(&state)));
                        Ok(())
                    } else {
                        Err(MappingError::InvalidStep)
                    };
                    let _ = reply.send(result);
                }
                MappingCommand::ResetSamples(reply) => {
                    let result = if matches!(state.current_step, MappingStep::Notch(_)) {
                        state.is_capturing = false;
                        state.current_samples.clear();
                        state.current_min = None;
                        state.current_max = None;
                        publish(&events, MappingEvent::SampleUpdated(public_state(&state)));
                        Ok(())
                    } else {
                        Err(MappingError::InvalidStep)
                    };
                    let _ = reply.send(result);
                }
                MappingCommand::CaptureRange(reply) => {
                    let result = capture_range(&mut state, &events, &store);
                    let _ = reply.send(result);
                }
                MappingCommand::GoToNotch(index, reply) => {
                    let result = if index < state.config.notches.len() {
                        state.current_step = MappingStep::Notch(index);
                        state.is_capturing = false;
                        state.current_samples.clear();
                        state.current_min = None;
                        state.current_max = None;
                        publish(&events, MappingEvent::StepChanged(public_state(&state)));
                        Ok(())
                    } else {
                        Err(MappingError::InvalidNotchIndex)
                    };
                    let _ = reply.send(result);
                }
                MappingCommand::GoToPreview(reply) => {
                    let result = if state.captured_ranges.iter().all(|range| range.is_some()) {
                        state.current_step = MappingStep::Preview;
                        publish(&events, MappingEvent::StepChanged(public_state(&state)));
                        Ok(())
                    } else {
                        Err(MappingError::IncompleteRanges)
                    };
                    let _ = reply.send(result);
                }
                MappingCommand::SaveMapping(reply) => {
                    let result = save_mapping(&mut state, &events, &store);
                    let _ = reply.send(result);
                }
                MappingCommand::InputSample { pin, raw_value } => {
                    if pin == state.config.pin
                        && matches!(state.current_step, MappingStep::Notch(_))
                    {
                        let calibrated = i64::from(normalize(raw_value, &state.config.calibration));
                        update_mapping_sample(&mut state, calibrated);
                        publish(&events, MappingEvent::SampleUpdated(public_state(&state)));
                    }
                }
                MappingCommand::Cancel => break,
            }
        }
        let _ = release_arbiter.release(token);
    });
    Ok((
        NotchMappingMonitor {
            commands,
            worker: Arc::new(Mutex::new(Some(worker))),
        },
        event_receiver,
    ))
}

fn capture_range(
    state: &mut MappingState,
    events: &mpsc::Sender<MappingEvent>,
    store: &Arc<dyn CalibrationStore>,
) -> Result<(), MappingError> {
    let MappingStep::Notch(index) = state.current_step.clone() else {
        return Err(MappingError::InvalidStep);
    };
    if state.current_samples.is_empty() {
        return Err(MappingError::NoSamples);
    }
    let (Some(min), Some(max)) = (state.current_min, state.current_max) else {
        return Err(MappingError::NoRangeDetected);
    };
    let mut captured = state.captured_ranges.clone();
    captured[index] = Some(SampleRange { min, max });
    let next_step = if index + 1 >= state.config.notches.len() {
        MappingStep::Preview
    } else {
        MappingStep::Notch(index + 1)
    };
    // Checkpoint first: only advance the wizard when the capture is committed.
    let checkpoint = MappingCheckpoint {
        lever_config_id: state.config.lever_config_id,
        captured_ranges: captured.clone(),
        next_notch_index: (index + 1).min(state.config.notches.len().saturating_sub(1)),
    };
    store
        .save_mapping_checkpoint(state.config.lever_config_id, &checkpoint)
        .map_err(MappingError::Store)?;
    state.captured_ranges = captured;
    state.current_step = next_step;
    state.is_capturing = false;
    state.current_samples.clear();
    state.current_min = None;
    state.current_max = None;
    publish(events, MappingEvent::StepChanged(public_state(state)));
    Ok(())
}

fn save_mapping(
    state: &mut MappingState,
    events: &mpsc::Sender<MappingEvent>,
    store: &Arc<dyn CalibrationStore>,
) -> Result<CompletedMapping, MappingError> {
    if state.current_step != MappingStep::Preview {
        return Err(MappingError::InvalidStep);
    }
    state.current_step = MappingStep::Saving;
    publish(events, MappingEvent::StepChanged(public_state(state)));
    let inverted = detect_inversion(&state.config.notches, &state.captured_ranges);
    let updates: Vec<NotchRangeUpdate> = state
        .config
        .notches
        .iter()
        .enumerate()
        .map(|(index, notch)| {
            let range = state
                .captured_ranges
                .get(index)
                .and_then(|range| range.as_ref())
                .map(|range| (range.min, range.max))
                .unwrap_or((0, 0));
            let (input_min, input_max) =
                calibrated_to_normalized(range.0, range.1, state.total_travel, inverted);
            NotchRangeUpdate {
                notch_id: notch.id,
                input_min,
                input_max,
            }
        })
        .collect();
    let completed = CompletedMapping {
        lever_config_id: state.config.lever_config_id,
        inverted,
        updates: updates.clone(),
    };
    let result = store
        .save_notch_input_ranges(state.config.lever_config_id, &updates, inverted)
        .map_err(MappingError::Store);
    state.current_step = MappingStep::Complete;
    publish(events, MappingEvent::StepChanged(public_state(state)));
    let mapped = result.map(|()| completed.clone());
    publish(events, MappingEvent::MappingResult(mapped.clone()));
    mapped
}

fn update_mapping_sample(state: &mut MappingState, calibrated: i64) {
    if state.is_capturing {
        state.current_samples.push(calibrated);
        state.current_value = Some(calibrated);
        state.current_min = Some(
            state
                .current_min
                .map_or(calibrated, |min| min.min(calibrated)),
        );
        state.current_max = Some(
            state
                .current_max
                .map_or(calibrated, |max| max.max(calibrated)),
        );
    } else {
        state.current_value = Some(calibrated);
    }
}

/// Inverted when the notch at the lowest hardware position has a higher sim
/// input center than the notch at the highest hardware position
/// (mirrors `NotchMappingSession.detect_inversion/3`).
fn detect_inversion(notches: &[NotchDefinition], captured: &[Option<SampleRange>]) -> bool {
    let valid: Vec<(&NotchDefinition, &SampleRange)> = notches
        .iter()
        .zip(captured)
        .filter_map(|(notch, range)| range.as_ref().map(|range| (notch, range)))
        .filter(|(notch, _)| notch.sim_input_min.is_some() && notch.sim_input_max.is_some())
        .collect();
    if valid.len() < 2 {
        return false;
    }
    let hardware_center =
        |pair: &(&NotchDefinition, &SampleRange)| (pair.1.min + pair.1.max) as f64 / 2.0;
    let sim_center = |notch: &NotchDefinition| {
        (notch.sim_input_min.unwrap() + notch.sim_input_max.unwrap()) / 2.0
    };
    // First extreme wins ties, like Enum.min_by/Enum.max_by.
    let mut first = &valid[0];
    for pair in &valid[1..] {
        if hardware_center(pair) < hardware_center(first) {
            first = pair;
        }
    }
    let mut last = &valid[0];
    for pair in &valid[1..] {
        if hardware_center(pair) > hardware_center(last) {
            last = pair;
        }
    }
    sim_center(first.0) > sim_center(last.0)
}

/// Calibrated positions normalized to 0.0-1.0 (four decimals), swapped when
/// inverted, mirroring `NotchMappingSession.calibrated_to_normalized/4`.
fn calibrated_to_normalized(
    min_calibrated: i64,
    max_calibrated: i64,
    total_travel: i64,
    inverted: bool,
) -> (f64, f64) {
    if total_travel <= 0 {
        return (0.0, 0.0);
    }
    let norm_min = round_elixir(min_calibrated as f64 / total_travel as f64, 4).unwrap_or(0.0);
    let norm_max = round_elixir(max_calibrated as f64 / total_travel as f64, 4).unwrap_or(0.0);
    if inverted {
        (
            round_elixir(1.0 - norm_max, 4).unwrap_or(0.0),
            round_elixir(1.0 - norm_min, 4).unwrap_or(0.0),
        )
    } else {
        (norm_min, norm_max)
    }
}

fn public_state(state: &MappingState) -> MappingPublicState {
    let current_notch_index = match state.current_step {
        MappingStep::Notch(index) => Some(index),
        _ => None,
    };
    let can_capture = matches!(state.current_step, MappingStep::Notch(_))
        && !state.current_samples.is_empty()
        && state.current_min.is_some()
        && state.current_max.is_some();
    MappingPublicState {
        lever_config_id: state.config.lever_config_id,
        notch_count: state.config.notches.len(),
        notches: state.config.notches.clone(),
        total_travel: state.total_travel,
        current_step: state.current_step.clone(),
        current_notch_index,
        is_capturing: state.is_capturing,
        captured_ranges: state.captured_ranges.clone(),
        current_value: state.current_value,
        current_min: state.current_min,
        current_max: state.current_max,
        sample_count: state.current_samples.len(),
        can_capture,
        all_captured: state.captured_ranges.iter().all(|range| range.is_some()),
        is_stable: state.current_samples.len() >= MIN_SAMPLE_COUNT,
    }
}

fn publish(events: &mpsc::Sender<MappingEvent>, event: MappingEvent) {
    let _ = events.try_send(event);
}
