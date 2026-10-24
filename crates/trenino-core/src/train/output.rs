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
        (OutputOperator::Gte, SimValue::Number(value)) => {
            binding.value_a.is_some_and(|a| *value >= a)
        }
        (OutputOperator::Lt, SimValue::Number(value)) => {
            binding.value_a.is_some_and(|a| *value < a)
        }
        (OutputOperator::Lte, SimValue::Number(value)) => {
            binding.value_a.is_some_and(|a| *value <= a)
        }
        (OutputOperator::Between, SimValue::Number(value)) => {
            match (binding.value_a, binding.value_b) {
                (Some(min), Some(max)) => *value >= min && *value <= max,
                _ => false,
            }
        }
        (OutputOperator::EqTrue, SimValue::Bool(value)) => *value,
        (OutputOperator::EqFalse, SimValue::Bool(value)) => !*value,
        _ => false,
    }
}
