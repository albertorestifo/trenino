use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NotchType {
    Gate,
    Linear,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct Notch {
    pub kind: NotchType,
    pub input_min: Option<f64>,
    pub input_max: Option<f64>,
    pub sim_input_min: Option<f64>,
    pub sim_input_max: Option<f64>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct LeverConfig {
    #[serde(default)]
    pub inverted: bool,
    pub notches: Vec<Notch>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MappingError {
    NoNotch,
    UnmappedNotch,
    NoSimulatorRange,
    InvalidRange,
}

/// Mirrors Trenino.Train.LeverMapper.map_input/2, including 2dp inversion and simulator rounding.
pub fn map_input(config: &LeverConfig, input: f64) -> Result<f64, MappingError> {
    if !input.is_finite() || !(0.0..=1.0).contains(&input) {
        return Err(MappingError::NoNotch);
    }
    let effective = if config.inverted {
        round2(1.0 - input)
    } else {
        input
    };
    let notch = config
        .notches
        .iter()
        .find(|n| match (n.input_min, n.input_max) {
            (Some(min), Some(max)) => effective >= min && effective < max,
            _ => false,
        })
        .or_else(|| {
            config.notches.iter().find(|n| {
                n.input_min.is_some() && n.input_max == Some(1.0) && n.input_max == Some(effective)
            })
        });
    let notch = notch.ok_or(MappingError::NoNotch)?;
    let (sim_min, sim_max) = match (notch.sim_input_min, notch.sim_input_max) {
        (Some(min), Some(max)) => (min, max),
        _ => return Err(MappingError::NoSimulatorRange),
    };
    match notch.kind {
        NotchType::Gate => Ok(round2((sim_min + sim_max) / 2.0)),
        NotchType::Linear => {
            let (input_min, input_max) = match (notch.input_min, notch.input_max) {
                (Some(min), Some(max)) => (min, max),
                _ => return Err(MappingError::UnmappedNotch),
            };
            let range = input_max - input_min;
            if range == 0.0 {
                return Err(MappingError::InvalidRange);
            }
            let mut position = (effective - input_min) / range;
            if config.inverted && reversed_layout(&config.notches) {
                position = 1.0 - position;
            }
            Ok(round2(sim_min + position * (sim_max - sim_min)))
        }
    }
}

pub fn reversed_layout(notches: &[Notch]) -> bool {
    let mut mapped: Vec<&Notch> = notches
        .iter()
        .filter(|n| {
            n.input_min.is_some()
                && n.input_max.is_some()
                && n.sim_input_min.is_some()
                && n.sim_input_max.is_some()
        })
        .collect();
    if mapped.len() < 2 {
        return false;
    }
    mapped.sort_by(|a, b| a.input_min.unwrap().total_cmp(&b.input_min.unwrap()));
    let first = mapped[0];
    let last = *mapped
        .iter()
        .max_by(|a, b| a.input_max.unwrap().total_cmp(&b.input_max.unwrap()))
        .unwrap();
    first.sim_input_min.unwrap() > last.sim_input_max.unwrap()
}

fn round2(value: f64) -> f64 {
    (value * 100.0).round() / 100.0
}
