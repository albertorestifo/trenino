//! Read-only UI previews. Persisted calibration and display parameters come
//! from the single storage owner; no browser copy of these rules is trusted.

use serde::{Deserialize, Serialize};
use trenino_core::hardware::calibration::{normalize, total_travel, Calibration};
use trenino_core::rounding::round_elixir;
use trenino_core::simulator::SimValue;
use trenino_core::train::display::{clamp_to_min, format_display, validate_display_format_string};
use trenino_core::train::output::{evaluate_output, OutputBinding, OutputOperator};
use trenino_core::EntityId;

use crate::simulator::services::calibration::{
    calibrated_to_normalized, detect_inversion, NotchDefinition, NotchKind, SampleRange,
    MIN_SAMPLE_COUNT,
};
use crate::storage::bindings::{validate_output_condition, OutputBindingOperator};
use crate::storage::{Database, InputRecord, StorageError};
use crate::vjoy::mapper::axis_value;

// Mirrors `Trenino.Hardware.start_calibration/5` for a fresh AVR input.
// Recalibration uses the previously persisted ceiling when present.
const FRESH_CALIBRATION_CEILING: i32 = 1023;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum PreviewError {
    NotFound,
    Invalid(&'static str),
    Storage(String),
}

impl From<StorageError> for PreviewError {
    fn from(error: StorageError) -> Self {
        Self::Storage(error.to_string())
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize)]
pub struct InputPreview {
    pub calibrated: i32,
    pub travel: i64,
    pub axis_percent: i32,
    pub max_hardware_value: i32,
    pub min_notch_samples: usize,
}

pub fn calibration_ceiling(db: &Database, input_id: EntityId) -> Result<i32, PreviewError> {
    let input = db.get_input(input_id)?.ok_or(PreviewError::NotFound)?;
    Ok(input
        .calibration
        .as_ref()
        .and_then(|row| row.value.max_hardware_value)
        .filter(|ceiling| *ceiling > 0)
        .unwrap_or(FRESH_CALIBRATION_CEILING))
}

fn stored_calibration(input: &InputRecord) -> Result<Calibration, PreviewError> {
    let row = input
        .calibration
        .as_ref()
        .ok_or(PreviewError::Invalid("Input is not calibrated."))?;
    let value = &row.value;
    let calibration = Calibration {
        min_value: value
            .min_value
            .ok_or(PreviewError::Invalid("Calibration minimum is missing."))?,
        max_value: value
            .max_value
            .ok_or(PreviewError::Invalid("Calibration maximum is missing."))?,
        max_hardware_value: value.max_hardware_value.ok_or(PreviewError::Invalid(
            "Calibration hardware ceiling is missing.",
        ))?,
        inverted: value.is_inverted,
        rollover: value.has_rollover,
    };
    if calibration.max_hardware_value <= 0 || total_travel(&calibration) <= 0 {
        return Err(PreviewError::Invalid("Calibration travel is invalid."));
    }
    Ok(calibration)
}

pub fn preview_input(
    db: &Database,
    input_id: EntityId,
    raw: i32,
) -> Result<InputPreview, PreviewError> {
    let input = db.get_input(input_id)?.ok_or(PreviewError::NotFound)?;
    let calibration = stored_calibration(&input)?;
    let travel = total_travel(&calibration);
    let calibrated = normalize(raw, &calibration);
    let axis_percent = axis_value(raw, Some(&calibration), false, (0, 100))
        .map_err(|_| PreviewError::Invalid("Calibration travel is invalid."))?;
    Ok(InputPreview {
        calibrated,
        travel,
        axis_percent,
        max_hardware_value: calibration.max_hardware_value,
        min_notch_samples: MIN_SAMPLE_COUNT,
    })
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Deserialize)]
pub struct CapturedRange {
    pub min: i64,
    pub max: i64,
    pub sample_count: usize,
}

#[derive(Clone, Copy, Debug, PartialEq, Deserialize)]
pub struct NotchSimulatorRange {
    pub sim_input_min: Option<f64>,
    pub sim_input_max: Option<f64>,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize)]
pub struct NormalizedRange {
    pub min: f64,
    pub max: f64,
}

#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct NotchMappingPreview {
    pub inverted: bool,
    pub ranges: Vec<NormalizedRange>,
    pub travel: i64,
}

pub fn preview_notch_mapping(
    db: &Database,
    input_id: EntityId,
    notches: &[NotchSimulatorRange],
    captured: &[CapturedRange],
    auto_distribute: bool,
) -> Result<NotchMappingPreview, PreviewError> {
    let input = db.get_input(input_id)?.ok_or(PreviewError::NotFound)?;
    preview_notch_mapping_for_input(&input, notches, captured, auto_distribute)
}

pub(crate) fn preview_notch_mapping_for_input(
    input: &InputRecord,
    notches: &[NotchSimulatorRange],
    captured: &[CapturedRange],
    auto_distribute: bool,
) -> Result<NotchMappingPreview, PreviewError> {
    if notches.is_empty() || (!auto_distribute && notches.len() != captured.len()) {
        return Err(PreviewError::Invalid("Capture every notch before saving."));
    }
    if !auto_distribute
        && captured
            .iter()
            .any(|range| range.sample_count < MIN_SAMPLE_COUNT)
    {
        return Err(PreviewError::Invalid(
            "Collect enough samples for every notch.",
        ));
    }
    let travel = total_travel(&stored_calibration(input)?);
    if auto_distribute {
        let count = notches.len() as f64;
        let ranges = (0..notches.len())
            .map(|index| NormalizedRange {
                min: round_elixir(index as f64 / count, 2).unwrap_or(0.0),
                max: round_elixir((index + 1) as f64 / count, 2).unwrap_or(1.0),
            })
            .collect();
        return Ok(NotchMappingPreview {
            inverted: false,
            ranges,
            travel,
        });
    }
    if captured
        .iter()
        .any(|range| range.min < 0 || range.max < range.min || range.max > travel)
    {
        return Err(PreviewError::Invalid(
            "Captured range is outside the calibrated travel.",
        ));
    }
    let definitions: Vec<_> = notches
        .iter()
        .enumerate()
        .map(|(index, notch)| NotchDefinition {
            id: index as i64,
            index: index as i64,
            kind: NotchKind::Linear,
            description: String::new(),
            sim_input_min: notch.sim_input_min,
            sim_input_max: notch.sim_input_max,
        })
        .collect();
    let samples: Vec<_> = captured
        .iter()
        .map(|range| {
            Some(SampleRange {
                min: range.min,
                max: range.max,
            })
        })
        .collect();
    let inverted = detect_inversion(&definitions, &samples);
    let ranges = captured
        .iter()
        .map(|range| {
            let (min, max) = calibrated_to_normalized(range.min, range.max, travel, inverted);
            NormalizedRange { min, max }
        })
        .collect();
    Ok(NotchMappingPreview {
        inverted,
        ranges,
        travel,
    })
}

#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct DisplayPreview {
    pub valid: bool,
    pub error: Option<String>,
    pub rendered: String,
    pub overflow: bool,
    pub missing_dot: bool,
}

pub fn preview_display(
    db: &Database,
    module_id: EntityId,
    format: &str,
    sample: f64,
) -> Result<DisplayPreview, PreviewError> {
    let (snapshot, _) = db.hardware_snapshot()?;
    let module = snapshot
        .i2c_modules
        .iter()
        .find(|module| module.id == module_id)
        .ok_or(PreviewError::NotFound)?;
    if !sample.is_finite() {
        return Err(PreviewError::Invalid("Sample value must be finite."));
    }
    if let Err(message) = validate_display_format_string(format) {
        return Ok(DisplayPreview {
            valid: false,
            error: Some(message.into()),
            rendered: String::new(),
            overflow: false,
            missing_dot: false,
        });
    }
    let clamped = clamp_to_min(
        SimValue::Number(sample),
        module.params.as_ref().and_then(|params| params.min_value),
    );
    let rendered = format_display(format, &clamped);
    let overflow = module.params.as_ref().is_some_and(|params| {
        rendered.replace('.', "").chars().count() > params.num_digits.max(0) as usize
    });
    let missing_dot = module
        .params
        .as_ref()
        .is_some_and(|params| !params.has_dot && rendered.contains('.'));
    Ok(DisplayPreview {
        valid: true,
        error: None,
        rendered,
        overflow,
        missing_dot,
    })
}

#[derive(Clone, Debug, PartialEq, Serialize)]
pub struct OutputConditionPreview {
    pub valid: bool,
    pub error: Option<String>,
    pub explanation: String,
    pub example_on: bool,
}

pub fn preview_output_condition(
    operator: OutputOperator,
    value_a: Option<f64>,
    value_b: Option<f64>,
) -> OutputConditionPreview {
    let boolean = matches!(operator, OutputOperator::EqTrue | OutputOperator::EqFalse);
    let storage_operator = match operator {
        OutputOperator::Gt => OutputBindingOperator::Gt,
        OutputOperator::Gte => OutputBindingOperator::Gte,
        OutputOperator::Lt => OutputBindingOperator::Lt,
        OutputOperator::Lte => OutputBindingOperator::Lte,
        OutputOperator::Between => OutputBindingOperator::Between,
        OutputOperator::EqTrue => OutputBindingOperator::EqTrue,
        OutputOperator::EqFalse => OutputBindingOperator::EqFalse,
    };
    let error = validate_output_condition(storage_operator, value_a, value_b)
        .err()
        .map(|message| match message {
            "value_a can't be blank" => "Enter a numeric threshold.",
            "value_b can't be blank" => "Enter the upper threshold.",
            _ => "Thresholds must be finite numbers.",
        });
    let explanation = match operator {
        OutputOperator::EqTrue => "LED turns ON when value is true".into(),
        OutputOperator::EqFalse => "LED turns ON when value is false".into(),
        OutputOperator::Gt => format!(
            "LED turns ON when value > {}",
            value_a.map_or("?".into(), |v| v.to_string())
        ),
        OutputOperator::Gte => format!(
            "LED turns ON when value >= {}",
            value_a.map_or("?".into(), |v| v.to_string())
        ),
        OutputOperator::Lt => format!(
            "LED turns ON when value < {}",
            value_a.map_or("?".into(), |v| v.to_string())
        ),
        OutputOperator::Lte => format!(
            "LED turns ON when value <= {}",
            value_a.map_or("?".into(), |v| v.to_string())
        ),
        OutputOperator::Between => format!(
            "LED turns ON when {} <= value <= {}",
            value_a.map_or("?".into(), |v| v.to_string()),
            value_b.map_or("?".into(), |v| v.to_string())
        ),
    };
    let binding = OutputBinding {
        operator,
        value_a,
        value_b,
    };
    let example = if boolean {
        SimValue::Bool(true)
    } else {
        SimValue::Number(value_a.unwrap_or(0.0))
    };
    OutputConditionPreview {
        valid: error.is_none(),
        error: error.map(str::to_owned),
        explanation,
        example_on: evaluate_output(&binding, &example),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::storage::{
        CalibrationRecord, DeviceDraft, DisplayType, Ht16k33Params, I2cModuleDraft, InputDraft,
        InputKind,
    };
    use tempfile::tempdir;
    use trenino_core::OperationId;

    #[test]
    fn previews_read_persisted_ceiling_and_display_minimum() {
        let dir = tempdir().unwrap();
        let db = Database::open_full(dir.path().join("preview.db")).unwrap();
        db.allocate_epoch().unwrap();
        let device = db
            .create_device(
                OperationId(1),
                DeviceDraft {
                    name: "Panel".into(),
                    description: None,
                    config_id: None,
                },
            )
            .unwrap()
            .record;
        let input = db
            .create_input(
                OperationId(2),
                device.id,
                InputDraft {
                    pin: 1,
                    kind: InputKind::Analog,
                    sensitivity: Some(5),
                    debounce: None,
                    name: None,
                    matrix_id: None,
                },
            )
            .unwrap()
            .record;
        assert_eq!(calibration_ceiling(&db, input.id), Ok(1023));
        db.save_calibration(
            OperationId(3),
            input.id,
            CalibrationRecord {
                max_hardware_value: Some(4095),
                min_value: Some(4000),
                max_value: Some(100),
                has_rollover: true,
                is_inverted: false,
            },
        )
        .unwrap();
        assert_eq!(calibration_ceiling(&db, input.id), Ok(4095));
        let live = preview_input(&db, input.id, 50).unwrap();
        assert_eq!(live.travel, 196);
        assert_eq!(live.calibrated, 146);
        assert_eq!(live.axis_percent, 74);
        assert_eq!(live.max_hardware_value, 4095);
        assert_eq!(live.min_notch_samples, 10);
        assert_eq!(
            preview_notch_mapping(
                &db,
                input.id,
                &[NotchSimulatorRange {
                    sim_input_min: None,
                    sim_input_max: None
                }],
                &[CapturedRange {
                    min: 0,
                    max: 20,
                    sample_count: 9
                }],
                false,
            ),
            Err(PreviewError::Invalid(
                "Collect enough samples for every notch."
            ))
        );
        let mapping = preview_notch_mapping(
            &db,
            input.id,
            &[
                NotchSimulatorRange {
                    sim_input_min: Some(1.0),
                    sim_input_max: Some(1.0),
                },
                NotchSimulatorRange {
                    sim_input_min: Some(0.0),
                    sim_input_max: Some(0.0),
                },
            ],
            &[
                CapturedRange {
                    min: 0,
                    max: 20,
                    sample_count: 10,
                },
                CapturedRange {
                    min: 176,
                    max: 196,
                    sample_count: 10,
                },
            ],
            false,
        )
        .unwrap();
        assert!(mapping.inverted);
        assert_eq!(
            mapping.ranges[0],
            NormalizedRange {
                min: 0.898,
                max: 1.0
            }
        );
        let auto = preview_notch_mapping(
            &db,
            input.id,
            &[NotchSimulatorRange {
                sim_input_min: None,
                sim_input_max: None,
            }; 3],
            &[],
            true,
        )
        .unwrap();
        assert_eq!(
            auto.ranges,
            vec![
                NormalizedRange {
                    min: 0.0,
                    max: 0.33
                },
                NormalizedRange {
                    min: 0.33,
                    max: 0.67
                },
                NormalizedRange {
                    min: 0.67,
                    max: 1.0
                },
            ]
        );
        let module = db
            .create_i2c_module(
                OperationId(4),
                device.id,
                I2cModuleDraft {
                    name: Some("Speed".into()),
                    module_chip: "ht16k33".into(),
                    i2c_address: 112,
                    params: Some(Ht16k33Params {
                        brightness: 8,
                        num_digits: 4,
                        display_type: DisplayType::SevenSegment,
                        has_dot: false,
                        align_right: false,
                        min_value: Some(50.0),
                    }),
                },
            )
            .unwrap()
            .record;
        let displayed = preview_display(&db, module.id, "S:{value:.1f}", 42.5).unwrap();
        assert_eq!(displayed.rendered, "S:50.0");
        assert!(displayed.overflow);
        assert!(displayed.missing_dot);
        let invalid = preview_display(&db, module.id, "{value:.11f}", 42.5).unwrap();
        assert!(!invalid.valid);
        assert!(invalid.error.is_some());
    }

    #[test]
    fn notch_inversion_and_elixir_rounding_match_mapping_oracle() {
        let notches = [
            NotchDefinition {
                id: 1,
                index: 0,
                kind: NotchKind::Linear,
                description: String::new(),
                sim_input_min: Some(1.0),
                sim_input_max: Some(1.0),
            },
            NotchDefinition {
                id: 2,
                index: 1,
                kind: NotchKind::Linear,
                description: String::new(),
                sim_input_min: Some(0.0),
                sim_input_max: Some(0.0),
            },
        ];
        let captured = [
            SampleRange { min: 100, max: 200 },
            SampleRange { min: 700, max: 800 },
        ];
        let samples = captured.map(Some);
        assert!(detect_inversion(&notches, &samples));
        assert_eq!(calibrated_to_normalized(100, 200, 1000, true), (0.8, 0.9));
        assert_eq!(calibrated_to_normalized(1, 1, 3, false), (0.3333, 0.3333));
    }

    #[test]
    fn output_preview_uses_shared_runtime_predicate() {
        let result = preview_output_condition(OutputOperator::Between, Some(2.0), Some(4.0));
        assert!(result.valid);
        assert!(result.example_on);
        assert!(!preview_output_condition(OutputOperator::Between, Some(2.0), None).valid);
    }
}
