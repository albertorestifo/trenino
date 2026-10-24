use crate::{rounding::round_elixir, simulator::SimValue};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;

const SNAP_THRESHOLD: f64 = 0.03;
const GATE_RANGE_THRESHOLD: f64 = 0.15;
const INTEGER_TOLERANCE: f64 = 0.05;
const MAX_DISCRETE_OUTPUTS: usize = 15;
const MIN_CONTINUOUS_OUTPUTS: usize = 20;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Sample {
    pub set_input: f64,
    pub actual_input: f64,
    pub output: f64,
    pub notch_index: i64,
    #[serde(default)]
    pub snapped: bool,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ZoneType {
    Gate,
    Linear,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Zone {
    pub kind: ZoneType,
    pub value: Option<f64>,
    pub output_min: f64,
    pub output_max: f64,
    pub set_input_min: f64,
    pub set_input_max: f64,
    pub actual_input_min: f64,
    pub actual_input_max: f64,
    pub notch_indices: Vec<i64>,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LeverType {
    Discrete,
    Continuous,
    Hybrid,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct SuggestedNotch {
    pub kind: ZoneType,
    pub index: usize,
    pub value: Option<f64>,
    pub min_value: Option<f64>,
    pub max_value: Option<f64>,
    pub input_min: f64,
    pub input_max: f64,
    pub actual_input_min: f64,
    pub actual_input_max: f64,
    pub description: String,
}
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct AnalysisResult {
    pub lever_type: LeverType,
    pub samples: Vec<Sample>,
    pub zones: Vec<Zone>,
    pub suggested_notches: Vec<SuggestedNotch>,
    pub min_output: f64,
    pub max_output: f64,
    pub unique_output_count: usize,
    pub all_outputs_integers: bool,
}
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AnalysisError {
    EmptySamples,
    NonFiniteSample,
    InvalidDerivedResult,
}

pub fn analyze_samples(samples: &[Sample]) -> Result<AnalysisResult, AnalysisError> {
    if samples.is_empty() {
        return Err(AnalysisError::EmptySamples);
    }
    if samples
        .iter()
        .any(|s| !s.set_input.is_finite() || !s.actual_input.is_finite() || !s.output.is_finite())
    {
        return Err(AnalysisError::NonFiniteSample);
    }
    let mut outputs: Vec<f64> = samples.iter().map(|s| s.output).collect();
    outputs.sort_by(f64::total_cmp);
    outputs.dedup_by(|a, b| *a == *b);
    let all_outputs_integers = outputs
        .iter()
        .all(|v| (v - v.round()).abs() < INTEGER_TOLERANCE);
    let min_output = *outputs.first().unwrap();
    let max_output = *outputs.last().unwrap();
    let mut groups: BTreeMap<i64, Vec<&Sample>> = BTreeMap::new();
    for sample in samples {
        groups.entry(sample.notch_index).or_default().push(sample);
    }
    let mut ordered: Vec<Vec<&Sample>> = groups.into_values().collect();
    for group in &mut ordered {
        group.sort_by(|a, b| a.set_input.total_cmp(&b.set_input));
    }
    ordered.sort_by(|a, b| a[0].set_input.total_cmp(&b[0].set_input));
    let mut zones: Vec<Zone> = Vec::new();
    for group in ordered {
        let notch_index = group[0].notch_index;
        if let Some(current) = zones.last_mut() {
            if (group[0].actual_input - current.actual_input_max).abs() <= SNAP_THRESHOLD {
                merge(current, &group, notch_index)?;
                continue;
            }
        }
        zones.push(create_zone(&group, notch_index)?);
    }
    let has_gate = zones.iter().any(|z| z.kind == ZoneType::Gate);
    let has_linear = zones.iter().any(|z| z.kind == ZoneType::Linear);
    let lever_type = if all_outputs_integers && outputs.len() <= MAX_DISCRETE_OUTPUTS && !has_linear
    {
        LeverType::Discrete
    } else if outputs.len() >= MIN_CONTINUOUS_OUTPUTS && !has_gate {
        LeverType::Continuous
    } else if has_gate && has_linear {
        LeverType::Hybrid
    } else if outputs.len() >= MIN_CONTINUOUS_OUTPUTS {
        LeverType::Continuous
    } else {
        LeverType::Discrete
    };
    let mut ordered_zones = zones.clone();
    ordered_zones.sort_by(|a, b| a.set_input_min.total_cmp(&b.set_input_min));
    let suggested_notches = ordered_zones
        .iter()
        .enumerate()
        .map(|(index, zone)| {
            let description = match zone.kind {
                ZoneType::Gate => format!(
                    "Gate at output {}",
                    SimValue::Number(zone.value.unwrap()).to_legacy_string()
                ),
                ZoneType::Linear => format!(
                    "Linear {} to {}",
                    SimValue::Number(zone.output_min).to_legacy_string(),
                    SimValue::Number(zone.output_max).to_legacy_string()
                ),
            };
            SuggestedNotch {
                kind: zone.kind,
                index,
                value: zone.value,
                min_value: (zone.kind == ZoneType::Linear).then_some(zone.output_min),
                max_value: (zone.kind == ZoneType::Linear).then_some(zone.output_max),
                input_min: zone.set_input_min,
                input_max: zone.set_input_max,
                actual_input_min: zone.actual_input_min,
                actual_input_max: zone.actual_input_max,
                description,
            }
        })
        .collect();
    Ok(AnalysisResult {
        lever_type,
        samples: samples.to_vec(),
        zones,
        suggested_notches,
        min_output,
        max_output,
        unique_output_count: outputs.len(),
        all_outputs_integers,
    })
}

fn zone_type(min: f64, max: f64) -> Result<ZoneType, AnalysisError> {
    let min = round_elixir(min, 1).ok_or(AnalysisError::InvalidDerivedResult)?;
    let max = round_elixir(max, 1).ok_or(AnalysisError::InvalidDerivedResult)?;
    let width = max - min;
    if !width.is_finite() {
        return Err(AnalysisError::InvalidDerivedResult);
    }
    Ok(if width.abs() < GATE_RANGE_THRESHOLD {
        ZoneType::Gate
    } else {
        ZoneType::Linear
    })
}
fn create_zone(group: &[&Sample], index: i64) -> Result<Zone, AnalysisError> {
    let output_min = group
        .iter()
        .map(|s| s.output)
        .min_by(f64::total_cmp)
        .unwrap();
    let output_max = group
        .iter()
        .map(|s| s.output)
        .max_by(f64::total_cmp)
        .unwrap();
    let kind = zone_type(output_min, output_max)?;
    let value = if kind == ZoneType::Gate {
        let midpoint = legacy_midpoint(output_min, output_max);
        Some(round_elixir(midpoint, 2).ok_or(AnalysisError::InvalidDerivedResult)?)
    } else {
        None
    };
    Ok(Zone {
        kind,
        value,
        output_min,
        output_max,
        set_input_min: group
            .iter()
            .map(|s| s.set_input)
            .min_by(f64::total_cmp)
            .unwrap(),
        set_input_max: group
            .iter()
            .map(|s| s.set_input)
            .max_by(f64::total_cmp)
            .unwrap(),
        actual_input_min: group
            .iter()
            .map(|s| s.actual_input)
            .min_by(f64::total_cmp)
            .unwrap(),
        actual_input_max: group
            .iter()
            .map(|s| s.actual_input)
            .max_by(f64::total_cmp)
            .unwrap(),
        notch_indices: vec![index],
    })
}
fn merge(zone: &mut Zone, group: &[&Sample], index: i64) -> Result<(), AnalysisError> {
    for sample in group {
        zone.output_min = zone.output_min.min(sample.output);
        zone.output_max = zone.output_max.max(sample.output);
        zone.set_input_min = zone.set_input_min.min(sample.set_input);
        zone.set_input_max = zone.set_input_max.max(sample.set_input);
        zone.actual_input_min = zone.actual_input_min.min(sample.actual_input);
        zone.actual_input_max = zone.actual_input_max.max(sample.actual_input);
    }
    zone.kind = zone_type(zone.output_min, zone.output_max)?;
    zone.value = if zone.kind == ZoneType::Gate {
        let midpoint = legacy_midpoint(zone.output_min, zone.output_max);
        Some(round_elixir(midpoint, 2).ok_or(AnalysisError::InvalidDerivedResult)?)
    } else {
        None
    };
    zone.notch_indices.push(index);
    Ok(())
}

fn legacy_midpoint(min: f64, max: f64) -> f64 {
    let legacy = (min + max) / 2.0;
    if legacy.is_finite() {
        legacy
    } else {
        min / 2.0 + max / 2.0
    }
}
