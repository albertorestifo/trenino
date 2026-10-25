//! Convert calibrated hardware samples to native vJoy axis positions.

use trenino_core::hardware::calibration::{normalize, total_travel, Calibration};

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MappingError {
    InvalidRange,
    Uncalibrated,
}

/// Matches `Trenino.VirtualJoystick.Mapper.axis_value/4` (Elixir `round/1`).
pub fn axis_value(
    raw: i32,
    calibration: Option<&Calibration>,
    inverted: bool,
    (minimum, maximum): (i32, i32),
) -> Result<i32, MappingError> {
    if maximum <= minimum {
        return Err(MappingError::InvalidRange);
    }
    let calibration = calibration.ok_or(MappingError::Uncalibrated)?;
    let travel = total_travel(calibration);
    if travel <= 0 {
        return Err(MappingError::Uncalibrated);
    }
    let fraction = f64::from(normalize(raw, calibration)) / travel as f64;
    let fraction = if inverted { 1.0 - fraction } else { fraction };
    Ok((f64::from(minimum) + fraction * (f64::from(maximum) - f64::from(minimum))).round() as i32)
}
