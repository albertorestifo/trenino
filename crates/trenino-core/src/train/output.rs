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

/// Decode a `GET /subscription` response body exactly like the controllers:
/// `{:ok, %{"Entries" => [%{"Values" => values, "NodeValid" => true} | _]}}
/// when map_size(values) > 0` (`OutputController.process_subscription/4`,
/// `DisplayController.process_subscription/4`). Any other shape —
/// `NodeValid: false`, a missing `NodeValid`, an empty or missing `Values`
/// map, missing/empty `Entries` — returns `None` and must leave controller
/// state untouched.
///
/// The matched value is normalized like `normalize_value/1`: numbers are
/// rounded to two decimals (`Float.round(value * 1.0, 2)`), booleans, strings
/// and null pass through. Elixir picks `values |> Map.values() |> List.first()`,
/// i.e. an arbitrary entry for multi-key maps; here the JSON object's first
/// key is used, which agrees for the single-key maps TSW produces.
pub fn subscription_reading(envelope: &serde_json::Value) -> Option<SimValue> {
    let entry = envelope.get("Entries")?.as_array()?.first()?;
    if entry.get("NodeValid") != Some(&serde_json::Value::Bool(true)) {
        return None;
    }
    let values = entry.get("Values")?.as_object()?;
    if values.is_empty() {
        return None;
    }
    values.values().next().map(normalize_subscription_value)
}

fn normalize_subscription_value(raw: &serde_json::Value) -> SimValue {
    match raw {
        serde_json::Value::Bool(value) => SimValue::Bool(*value),
        serde_json::Value::String(value) => SimValue::String(value.clone()),
        serde_json::Value::Number(number) => {
            // `normalize_value/1`: every number (integers included) becomes
            // `Float.round(value * 1.0, 2)` — a float, so a JSON `7` renders
            // as "7.0" on displays and compares as 7.0 in predicates.
            // `as_f64` only misses NaN/Infinity literals, which JSON cannot
            // contain; fall back to null like an unusable term.
            let Some(value) = number.as_f64() else {
                return SimValue::Null;
            };
            // Keep the raw value when the exact-decimal helper cannot
            // represent the magnitude (Float.round never fails).
            SimValue::Number(crate::rounding::round_elixir(value, 2).unwrap_or(value))
        }
        // Elixir passes any other term through verbatim; TSW `Values` maps only
        // contain scalars, and SimValue cannot represent containers, so nested
        // values collapse to null (predicates false, displays render empty).
        _ => SimValue::Null,
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn reading(body: serde_json::Value) -> Option<SimValue> {
        subscription_reading(&body)
    }

    #[test]
    fn predicates_match_the_output_controller_fixture_matrix() {
        // test/trenino/train/output_controller_test.exs "evaluate_condition/2 logic"
        let gt = OutputBinding {
            operator: OutputOperator::Gt,
            value_a: Some(50.0),
            value_b: None,
        };
        assert!(evaluate_output(&gt, &SimValue::Number(50.01)));
        assert!(evaluate_output(&gt, &SimValue::Number(100.0)));
        assert!(!evaluate_output(&gt, &SimValue::Number(50.0)));
        assert!(!evaluate_output(&gt, &SimValue::Number(49.99)));
        assert!(!evaluate_output(&gt, &SimValue::Number(0.0)));

        let gte = OutputBinding {
            operator: OutputOperator::Gte,
            value_a: Some(50.0),
            value_b: None,
        };
        assert!(evaluate_output(&gte, &SimValue::Number(50.0)));
        assert!(!evaluate_output(&gte, &SimValue::Number(49.99)));
        assert!(!evaluate_output(&gte, &SimValue::Number(0.0)));

        let lt = OutputBinding {
            operator: OutputOperator::Lt,
            value_a: Some(50.0),
            value_b: None,
        };
        assert!(evaluate_output(&lt, &SimValue::Number(49.99)));
        assert!(evaluate_output(&lt, &SimValue::Number(-10.0)));
        assert!(!evaluate_output(&lt, &SimValue::Number(50.0)));
        assert!(!evaluate_output(&lt, &SimValue::Number(50.01)));

        let lte = OutputBinding {
            operator: OutputOperator::Lte,
            value_a: Some(50.0),
            value_b: None,
        };
        assert!(evaluate_output(&lte, &SimValue::Number(50.0)));
        assert!(evaluate_output(&lte, &SimValue::Number(0.0)));
        assert!(!evaluate_output(&lte, &SimValue::Number(50.01)));
    }

    #[test]
    fn between_is_inclusive_at_both_edges_and_acts_as_equals_when_degenerate() {
        let between = OutputBinding {
            operator: OutputOperator::Between,
            value_a: Some(30.0),
            value_b: Some(60.0),
        };
        assert!(evaluate_output(&between, &SimValue::Number(30.0)));
        assert!(evaluate_output(&between, &SimValue::Number(60.0)));
        assert!(evaluate_output(&between, &SimValue::Number(45.0)));
        assert!(!evaluate_output(&between, &SimValue::Number(29.99)));
        assert!(!evaluate_output(&between, &SimValue::Number(60.01)));

        let equals = OutputBinding {
            operator: OutputOperator::Between,
            value_a: Some(50.0),
            value_b: Some(50.0),
        };
        assert!(evaluate_output(&equals, &SimValue::Number(50.0)));
        assert!(!evaluate_output(&equals, &SimValue::Number(50.01)));
        assert!(!evaluate_output(&equals, &SimValue::Number(49.99)));
    }

    #[test]
    fn thresholds_cover_negatives_zero_and_precision_edges() {
        let gt = OutputBinding {
            operator: OutputOperator::Gt,
            value_a: Some(-10.0),
            value_b: None,
        };
        assert!(evaluate_output(&gt, &SimValue::Number(-9.0)));
        assert!(!evaluate_output(&gt, &SimValue::Number(-10.0)));
        assert!(!evaluate_output(&gt, &SimValue::Number(-11.0)));

        let gte = OutputBinding {
            operator: OutputOperator::Gte,
            value_a: Some(0.0),
            value_b: None,
        };
        assert!(evaluate_output(&gte, &SimValue::Number(0.0)));
        assert!(evaluate_output(&gte, &SimValue::Number(0.01)));
        assert!(!evaluate_output(&gte, &SimValue::Number(-0.01)));

        let precise = OutputBinding {
            operator: OutputOperator::Gt,
            value_a: Some(50.55),
            value_b: None,
        };
        assert!(evaluate_output(&precise, &SimValue::Number(50.56)));
        assert!(!evaluate_output(&precise, &SimValue::Number(50.55)));
        assert!(!evaluate_output(&precise, &SimValue::Number(50.54)));

        let large = OutputBinding {
            operator: OutputOperator::Lt,
            value_a: Some(1_000_000.0),
            value_b: None,
        };
        assert!(evaluate_output(&large, &SimValue::Number(999_999.99)));
        assert!(!evaluate_output(&large, &SimValue::Number(1_000_000.0)));

        let small = OutputBinding {
            operator: OutputOperator::Gt,
            value_a: Some(0.01),
            value_b: None,
        };
        assert!(evaluate_output(&small, &SimValue::Number(0.02)));
        assert!(!evaluate_output(&small, &SimValue::Number(0.01)));
    }

    #[test]
    fn boolean_operators_are_boolean_only_and_numeric_are_number_only() {
        let eq_true = OutputBinding {
            operator: OutputOperator::EqTrue,
            value_a: None,
            value_b: None,
        };
        let eq_false = OutputBinding {
            operator: OutputOperator::EqFalse,
            value_a: None,
            value_b: None,
        };
        assert!(evaluate_output(&eq_true, &SimValue::Bool(true)));
        assert!(!evaluate_output(&eq_true, &SimValue::Bool(false)));
        assert!(evaluate_output(&eq_false, &SimValue::Bool(false)));
        assert!(!evaluate_output(&eq_false, &SimValue::Bool(true)));
        // "boolean operators return false for non-boolean values"
        assert!(!evaluate_output(&eq_true, &SimValue::Integer(1)));
        assert!(!evaluate_output(&eq_true, &SimValue::Integer(0)));
        assert!(!evaluate_output(&eq_true, &SimValue::Number(1.0)));

        let gt = OutputBinding {
            operator: OutputOperator::Gt,
            value_a: Some(0.5),
            value_b: None,
        };
        // "numeric operators return false for boolean values"
        assert!(!evaluate_output(&gt, &SimValue::Bool(true)));
        assert!(!evaluate_output(&gt, &SimValue::Bool(false)));
        // strings and null are type mismatches too
        assert!(!evaluate_output(&gt, &SimValue::String("1".into())));
        assert!(!evaluate_output(&gt, &SimValue::Null));
        assert!(!evaluate_output(&eq_true, &SimValue::Null));
    }

    #[test]
    fn integer_values_compare_exactly_against_float_thresholds() {
        let gte = OutputBinding {
            operator: OutputOperator::Gte,
            value_a: Some(50.0),
            value_b: None,
        };
        assert!(evaluate_output(&gte, &SimValue::Integer(50)));
        assert!(evaluate_output(&gte, &SimValue::Integer(51)));
        assert!(!evaluate_output(&gte, &SimValue::Integer(49)));

        let between = OutputBinding {
            operator: OutputOperator::Between,
            value_a: Some(0.0),
            value_b: Some(10.0),
        };
        assert!(evaluate_output(&between, &SimValue::Integer(0)));
        assert!(evaluate_output(&between, &SimValue::Integer(10)));
        assert!(!evaluate_output(&between, &SimValue::Integer(11)));
    }

    #[test]
    fn subscription_readings_require_node_valid_true_and_a_non_empty_values_map() {
        let valid = json!({"Entries": [{"NodeValid": true, "Values": {"Speed": 42.5}}]});
        assert_eq!(reading(valid), Some(SimValue::Number(42.5)));

        let node_invalid = json!({"Entries": [{"NodeValid": false, "Values": {"Speed": 42.5}}]});
        assert_eq!(reading(node_invalid), None);

        let missing_flag = json!({"Entries": [{"Values": {"Speed": 42.5}}]});
        assert_eq!(reading(missing_flag), None);

        let empty_values = json!({"Entries": [{"NodeValid": true, "Values": {}}]});
        assert_eq!(reading(empty_values), None);

        let missing_values = json!({"Entries": [{"NodeValid": true}]});
        assert_eq!(reading(missing_values), None);

        let empty_entries = json!({"Entries": []});
        assert_eq!(reading(empty_entries), None);
        assert_eq!(reading(json!({})), None);
        assert_eq!(reading(json!({"Entries": "nope"})), None);
        // only the first entry matters, later entries are ignored
        let extra = json!({"Entries": [
            {"NodeValid": true, "Values": {"Speed": 1.0}},
            {"NodeValid": false, "Values": {}}
        ]});
        assert_eq!(reading(extra), Some(SimValue::Number(1.0)));
    }

    #[test]
    fn subscription_readings_round_numbers_to_two_decimals_and_pass_other_scalars() {
        let read =
            |value| reading(json!({"Entries": [{"NodeValid": true, "Values": {"Speed": value}}]}));
        assert_eq!(read(json!(50.006)), Some(SimValue::Number(50.01)));
        assert_eq!(read(json!(50.004)), Some(SimValue::Number(50.0)));
        assert_eq!(read(json!(42.485)), Some(SimValue::Number(42.48)));
        // normalize_value turns integers into rounded floats (Float.round(7 * 1.0, 2))
        assert_eq!(read(json!(7)), Some(SimValue::Number(7.0)));
        assert_eq!(read(json!(true)), Some(SimValue::Bool(true)));
        assert_eq!(read(json!("text")), Some(SimValue::String("text".into())));
        assert_eq!(read(serde_json::Value::Null), Some(SimValue::Null));
    }
}
