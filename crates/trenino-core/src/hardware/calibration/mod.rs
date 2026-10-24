#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Calibration {
    pub min_value: i32,
    pub max_value: i32,
    pub max_hardware_value: i32,
    pub inverted: bool,
    pub rollover: bool,
}

pub fn analyze_sweep(samples: &[i32], max_hw: i32) -> (bool, bool) {
    if samples.len() < 2 {
        return (false, false);
    }
    let deltas: Vec<i64> = samples
        .windows(2)
        .map(|w| i64::from(w[1]) - i64::from(w[0]))
        .collect();
    let inverted = median(&deltas) < 0;
    let abs: Vec<i64> = deltas.iter().map(|d| d.abs()).collect();
    let med = median(&abs);
    let peak = *abs.iter().max().unwrap_or(&0);
    (
        inverted,
        peak > (med.saturating_mul(3)).max(10) && (peak as f64) > (max_hw as f64 * 0.8),
    )
}

fn median(values: &[i64]) -> i64 {
    if values.is_empty() {
        return 0;
    }
    let mut sorted = values.to_vec();
    sorted.sort_unstable();
    let mid = sorted.len() / 2;
    if sorted.len().is_multiple_of(2) {
        ((i128::from(sorted[mid - 1]) + i128::from(sorted[mid])) / 2) as i64
    } else {
        sorted[mid]
    }
}

pub fn total_travel(c: &Calibration) -> i64 {
    match (c.inverted, c.rollover) {
        (false, false) => i64::from(c.max_value) - i64::from(c.min_value),
        (true, false) => i64::from(c.min_value) - i64::from(c.max_value),
        (false, true) => {
            i64::from(c.max_hardware_value) - i64::from(c.min_value) + 1 + i64::from(c.max_value)
        }
        (true, true) => {
            i64::from(c.min_value) + i64::from(c.max_hardware_value) - i64::from(c.max_value) + 1
        }
    }
}

pub fn normalize(raw: i32, c: &Calibration) -> i32 {
    let travel = total_travel(c).max(0);
    let raw = i64::from(raw);
    let min = i64::from(c.min_value);
    let max = i64::from(c.max_value);
    let hw = i64::from(c.max_hardware_value);
    let distance = match (c.inverted, c.rollover) {
        (false, false) => raw - min,
        (true, false) => min - raw,
        (false, true) => {
            if raw >= min {
                raw - min
            } else if raw <= max {
                hw - min + 1 + raw
            } else if raw < (max + min) / 2 {
                travel
            } else {
                0
            }
        }
        (true, true) => {
            if raw <= min {
                min - raw
            } else if raw >= max {
                min + hw - raw + 1
            } else if raw < (min + max) / 2 {
                0
            } else {
                travel
            }
        }
    };
    distance.clamp(0, travel).min(i64::from(i32::MAX)) as i32
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Analysis {
    pub inverted: bool,
    pub rollover: bool,
}
pub fn analyze(s: &[i32], max_hw: i32) -> Analysis {
    let (inverted, rollover) = analyze_sweep(s, max_hw);
    Analysis { inverted, rollover }
}
pub fn calculate_min(samples: &[i32], analysis: Analysis) -> Option<i32> {
    if samples.is_empty() {
        return None;
    }
    Some(if analysis.inverted {
        *samples.iter().max().unwrap()
    } else {
        *samples.iter().min().unwrap()
    })
}
pub fn calculate_max(samples: &[i32], analysis: Analysis) -> Option<i32> {
    if samples.is_empty() {
        return None;
    }
    Some(if analysis.inverted {
        *samples.iter().min().unwrap()
    } else {
        *samples.iter().max().unwrap()
    })
}
