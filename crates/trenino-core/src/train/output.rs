pub use crate::simulator::SimValue;
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum OutputOperator {
    Gt,
    Gte,
    Lt,
    Lte,
    Between,
    EqTrue,
    EqFalse,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
pub struct OutputBinding {
    pub operator: OutputOperator,
    pub value_a: Option<f64>,
    pub value_b: Option<f64>,
}

/// Apply the legacy output predicate. A type mismatch always evaluates false.
pub fn evaluate_output(binding: &OutputBinding, value: &SimValue) -> bool {
    match (binding.operator, value) {
        (OutputOperator::Gt, SimValue::Number(value)) => {
            binding.value_a.is_some_and(|a| *value > a)
        }
        (OutputOperator::Gt, SimValue::Integer(value)) => binding
            .value_a
            .is_some_and(|a| compare_integer_float(*value, a) == Some(std::cmp::Ordering::Greater)),
        (OutputOperator::Gte, SimValue::Number(value)) => {
            binding.value_a.is_some_and(|a| *value >= a)
        }
        (OutputOperator::Gte, SimValue::Integer(value)) => binding.value_a.is_some_and(|a| {
            matches!(
                compare_integer_float(*value, a),
                Some(std::cmp::Ordering::Greater | std::cmp::Ordering::Equal)
            )
        }),
        (OutputOperator::Lt, SimValue::Number(value)) => {
            binding.value_a.is_some_and(|a| *value < a)
        }
        (OutputOperator::Lt, SimValue::Integer(value)) => binding
            .value_a
            .is_some_and(|a| compare_integer_float(*value, a) == Some(std::cmp::Ordering::Less)),
        (OutputOperator::Lte, SimValue::Number(value)) => {
            binding.value_a.is_some_and(|a| *value <= a)
        }
        (OutputOperator::Lte, SimValue::Integer(value)) => binding.value_a.is_some_and(|a| {
            matches!(
                compare_integer_float(*value, a),
                Some(std::cmp::Ordering::Less | std::cmp::Ordering::Equal)
            )
        }),
        (OutputOperator::Between, SimValue::Number(value)) => {
            match (binding.value_a, binding.value_b) {
                (Some(min), Some(max)) => *value >= min && *value <= max,
                _ => false,
            }
        }
        (OutputOperator::Between, SimValue::Integer(value)) => {
            match (binding.value_a, binding.value_b) {
                (Some(min), Some(max)) => {
                    matches!(
                        compare_integer_float(*value, min),
                        Some(std::cmp::Ordering::Greater | std::cmp::Ordering::Equal)
                    ) && matches!(
                        compare_integer_float(*value, max),
                        Some(std::cmp::Ordering::Less | std::cmp::Ordering::Equal)
                    )
                }
                _ => false,
            }
        }
        (OutputOperator::EqTrue, SimValue::Bool(value)) => *value,
        (OutputOperator::EqFalse, SimValue::Bool(value)) => !*value,
        _ => false,
    }
}

fn compare_integer_float(integer: i128, float: f64) -> Option<std::cmp::Ordering> {
    use std::cmp::Ordering;

    if float.is_nan() {
        return None;
    }
    const I128_UPPER_EXCLUSIVE: f64 = 170_141_183_460_469_231_731_687_303_715_884_105_728.0;
    if float >= I128_UPPER_EXCLUSIVE {
        return Some(Ordering::Less);
    }
    if float < -I128_UPPER_EXCLUSIVE {
        return Some(Ordering::Greater);
    }
    let whole = float.trunc() as i128;
    match integer.cmp(&whole) {
        Ordering::Equal if float.fract() > 0.0 => Some(Ordering::Less),
        Ordering::Equal if float.fract() < 0.0 => Some(Ordering::Greater),
        ordering => Some(ordering),
    }
}
