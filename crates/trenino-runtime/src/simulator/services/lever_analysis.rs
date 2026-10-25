//! Lever analysis session.
//!
//! Port of `Trenino.Simulator.LeverAnalyzer` (lib/trenino/simulator/lever_analyzer.ex):
//! sweeps a lever across its input range (defaults 0.02 step, 150ms settling,
//! five push attempts 30ms apart when initializing), samples the actual input,
//! output value and current notch index at every position, and hands the
//! samples to the accepted pure analyzer in `trenino-core` which classifies
//! discrete/continuous/hybrid levers and produces notch/level candidates.
//! `quick_check` samples the five strategic positions for a fast verdict.

use std::sync::Arc;
use std::time::Duration;
use trenino_core::calibration::analysis::{analyze_samples, AnalysisError, AnalysisResult, Sample};
use trenino_core::rounding::round_elixir;
use crate::resource::{LeaseKind, ResourceArbiter, ResourceError};
use crate::simulator::client::{SimulatorClient, SimulatorError};

use super::clock::Clock;
use super::session::{spawn_leased_session, SessionHandle};

pub const SWEEP_STEP: f64 = 0.02;
pub const SETTLING_TIME: Duration = Duration::from_millis(150);
pub const SNAP_THRESHOLD: f64 = 0.03;
pub const OUTPUT_INTEGER_TOLERANCE: f64 = 0.05;
pub const PUSH_ATTEMPTS: usize = 5;
pub const PUSH_DELAY: Duration = Duration::from_millis(30);
pub const MIN_SAMPLES: usize = 10;
pub const QUICK_CHECK_DELAY: Duration = Duration::from_millis(100);

#[derive(Clone, Debug, PartialEq)]
pub struct AnalysisOptions {
    pub sweep_step: f64,
    pub settling_time: Duration,
    pub restore_position: Option<f64>,
}

impl Default for AnalysisOptions {
    fn default() -> Self {
        Self {
            sweep_step: SWEEP_STEP,
            settling_time: SETTLING_TIME,
            restore_position: None,
        }
    }
}

#[derive(Clone, Debug, PartialEq)]
pub enum AnalysisFailure {
    /// Fewer than ten samples survived the sweep
    /// (mirrors `{:error, :insufficient_samples}`).
    InsufficientSamples,
    Simulator(SimulatorError),
    InvalidSamples(AnalysisError),
}

impl From<SimulatorError> for AnalysisFailure {
    fn from(error: SimulatorError) -> Self {
        Self::Simulator(error)
    }
}

#[derive(Clone, Debug, PartialEq)]
pub enum AnalysisEvent {
    /// Notch/level candidates for the analyzed lever (see
    /// `AnalysisResult::suggested_notches`).
    Completed(AnalysisResult),
    Failed(AnalysisFailure),
}

/// Start a cancellable lever analysis holding `lease` for the whole sweep.
pub fn start_lever_analysis(
    client: Arc<SimulatorClient>,
    arbiter: &Arc<ResourceArbiter>,
    lease: LeaseKind,
    clock: Arc<dyn Clock>,
    control_path: String,
    options: AnalysisOptions,
) -> Result<SessionHandle<AnalysisEvent>, ResourceError> {
    spawn_leased_session(
        arbiter,
        lease,
        |_| async move {
            match analyze(&client, &clock, &control_path, &options).await {
                Ok(result) => Some(AnalysisEvent::Completed(result)),
                Err(failure) => Some(AnalysisEvent::Failed(failure)),
            }
        },
        || async {},
    )
}

/// Sweeps the lever and analyzes the samples, mirroring
/// `LeverAnalyzer.analyze/3` (including `restore_position` after success).
pub async fn analyze(
    client: &SimulatorClient,
    clock: &Arc<dyn Clock>,
    control_path: &str,
    options: &AnalysisOptions,
) -> Result<AnalysisResult, AnalysisFailure> {
    let samples = sweep_lever(client, clock, control_path, options).await?;
    let result = analyze_samples(&samples).map_err(AnalysisFailure::InvalidSamples)?;
    if let Some(restore_position) = options.restore_position {
        let _ = client
            .set(
                &format!("{control_path}.InputValue"),
                &json_number(restore_position),
            )
            .await;
    }
    Ok(result)
}

async fn sweep_lever(
    client: &SimulatorClient,
    clock: &Arc<dyn Clock>,
    control_path: &str,
    options: &AnalysisOptions,
) -> Result<Vec<Sample>, AnalysisFailure> {
    let (min_input, max_input) = read_input_range(client, control_path).await;
    let input_values = generate_sweep_values(min_input, max_input, options.sweep_step);
    let value_endpoint = format!("{control_path}.InputValue");
    let output_endpoint = format!("{control_path}.Function.GetCurrentOutputValue");
    let notch_endpoint = format!("{control_path}.Function.GetCurrentNotchIndex");

    initialize_lever_position(client, clock, &value_endpoint, options.settling_time, min_input)
        .await;

    let mut samples = Vec::new();
    for set_input in input_values {
        let Ok(_) = client
            .set(&value_endpoint, &json_number(set_input))
            .await
        else {
            // Failed positions are skipped, matching Enum.reduce_while's continue.
            continue;
        };
        clock.sleep(options.settling_time).await;
        let sample = async {
            let actual_input = client.get_float(&value_endpoint).await?;
            let output = client.get_float(&output_endpoint).await?;
            let notch_index = client.get_float(&notch_endpoint).await?;
            Ok::<Sample, SimulatorError>(Sample {
                set_input: round_elixir(set_input, 2).unwrap_or(set_input),
                actual_input,
                output,
                notch_index: notch_index.round() as i64,
                snapped: (actual_input - set_input).abs() > SNAP_THRESHOLD,
            })
        }
        .await;
        if let Ok(sample) = sample {
            samples.push(sample);
        }
    }
    if samples.len() < MIN_SAMPLES {
        return Err(AnalysisFailure::InsufficientSamples);
    }
    Ok(samples)
}

/// `get_float` already rounds to two decimals, matching the Elixir
/// `Float.round(..., 2)` of the accepted client.
async fn read_input_range(client: &SimulatorClient, control_path: &str) -> (f64, f64) {
    let minimum = client
        .get_float(&format!("{control_path}.Function.GetMinimumInputValue"))
        .await;
    let maximum = client
        .get_float(&format!("{control_path}.Function.GetMaximumInputValue"))
        .await;
    match (minimum, maximum) {
        (Ok(min_value), Ok(max_value)) if min_value < max_value => (min_value, max_value),
        // Could not read a usable range: default to 0.0..1.0.
        _ => (0.0, 1.0),
    }
}

async fn initialize_lever_position(
    client: &SimulatorClient,
    clock: &Arc<dyn Clock>,
    value_endpoint: &str,
    settling_time: Duration,
    min_input: f64,
) {
    for _ in 0..PUSH_ATTEMPTS {
        let _ = client.set(value_endpoint, &json_number(min_input)).await;
        clock.sleep(PUSH_DELAY).await;
    }
    clock.sleep(settling_time).await;
}

fn generate_sweep_values(min_input: f64, max_input: f64, step: f64) -> Vec<f64> {
    if step <= 0.0 {
        return Vec::new();
    }
    let count = ((max_input - min_input) / step).round().max(0.0) as i64;
    (0..=count)
        .filter_map(|i| round_elixir(min_input + i as f64 * step, 2))
        .filter(|value| *value <= max_input)
        .collect()
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum QuickCheck {
    Discrete,
    Continuous,
    Unknown,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum QuickCheckError {
    /// At least one sample point failed (mirrors `{:error, :sample_failed}`).
    SampleFailed,
}

/// Fast discrete/continuous verdict, mirroring `LeverAnalyzer.quick_check/3`:
/// all five strategic positions are sampled even when an earlier one fails
/// (the Elixir `Enum.map` does not short-circuit), integer outputs with at
/// most five distinct values are discrete; any fractional output is
/// continuous; anything else is unknown. Any failed sample point surfaces as
/// `SampleFailed`, discarding the underlying reason like the Elixir wrapper.
pub async fn quick_check(
    client: &SimulatorClient,
    clock: &Arc<dyn Clock>,
    control_path: &str,
    delay: Duration,
) -> Result<QuickCheck, QuickCheckError> {
    let test_points = [0.0, 0.25, 0.5, 0.75, 1.0];
    let mut outputs = Vec::with_capacity(test_points.len());
    let mut sample_failed = false;
    for input in test_points {
        let outcome = async {
            client
                .set(
                    &format!("{control_path}.InputValue"),
                    &json_number(input),
                )
                .await?;
            if !delay.is_zero() {
                clock.sleep(delay).await;
            }
            client
                .get_float(&format!("{control_path}.Function.GetCurrentOutputValue"))
                .await
        }
        .await;
        match outcome {
            Ok(output) => outputs.push(output),
            Err(_) => sample_failed = true,
        }
    }
    if sample_failed {
        return Err(QuickCheckError::SampleFailed);
    }
    let all_integers = outputs.iter().all(integer_value);
    let mut unique = outputs.clone();
    unique.sort_by(f64::total_cmp);
    unique.dedup();
    if all_integers && unique.len() <= 5 {
        Ok(QuickCheck::Discrete)
    } else if !all_integers {
        Ok(QuickCheck::Continuous)
    } else {
        Ok(QuickCheck::Unknown)
    }
}
fn integer_value(value: &f64) -> bool {
    (*value - value.round()).abs() < OUTPUT_INTEGER_TOLERANCE
}

fn json_number(value: f64) -> serde_json::Value {
    serde_json::Value::from(value)
}
