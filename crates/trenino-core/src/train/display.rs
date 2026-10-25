use super::output::SimValue;
use crate::rounding::format_elixir_decimal;

const FORMAT_ERROR: &str = "Use {value} or {value:.Nf}, with precision from 0 to 10";

pub fn validate_format(format: &str) -> Result<(), &'static str> {
    let mut remaining = format;
    while let Some(index) = remaining.find("{value") {
        remaining = &remaining[index..];
        if let Some(end) = matching_token_end(remaining) {
            remaining = &remaining[end..];
        } else {
            return Err(FORMAT_ERROR);
        }
    }
    Ok(())
}

pub fn format_display(format: &str, value: &SimValue) -> String {
    let raw = raw_value(value);
    let mut output = String::with_capacity(format.len());
    let mut remaining = format;
    while let Some(index) = remaining.find("{value") {
        output.push_str(&remaining[..index]);
        remaining = &remaining[index..];
        if remaining.starts_with("{value}") {
            output.push_str(&raw);
            remaining = &remaining[7..];
        } else if let Some((end, precision_text)) = formatted_token(remaining) {
            let precision = valid_precision(precision_text)
                .then(|| precision_text.parse::<usize>().ok())
                .flatten();
            match (value, precision) {
                (SimValue::Number(number), Some(precision)) if number.is_finite() => {
                    output.push_str(&format_elixir_decimal(*number, precision as u32).unwrap())
                }
                (SimValue::Integer(number), Some(precision)) => output
                    .push_str(&format_elixir_decimal(*number as f64, precision as u32).unwrap()),
                _ => output.push_str(&raw),
            }
            remaining = &remaining[end..];
        } else {
            // The Elixir regex only replaces complete recognized tokens.
            output.push_str("{value");
            remaining = &remaining[6..];
        }
    }
    output.push_str(remaining);
    output
}

fn matching_token_end(s: &str) -> Option<usize> {
    if s.starts_with("{value}") {
        return Some(7);
    }
    formatted_token(s).and_then(|(end, precision)| valid_precision(precision).then_some(end))
}
fn formatted_token(s: &str) -> Option<(usize, &str)> {
    let rest = s.strip_prefix("{value:.")?;
    let digits = rest.bytes().take_while(u8::is_ascii_digit).count();
    if digits == 0 || !rest[digits..].starts_with("f}") {
        return None;
    }
    Some((10 + digits, &rest[..digits]))
}
fn valid_precision(s: &str) -> bool {
    matches!(
        s,
        "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" | "10"
    )
}
fn raw_value(value: &SimValue) -> String {
    value.to_legacy_string()
}

/// `DisplayController.clamp_to_min/2`: a numeric reading below a persisted
/// numeric minimum is raised to the minimum before formatting; a nil minimum,
/// non-numeric readings, and readings already at or above the minimum pass
/// through unchanged.
pub fn clamp_to_min(value: SimValue, min_value: Option<f64>) -> SimValue {
    match (value, min_value) {
        (SimValue::Number(raw), Some(min)) if raw < min => SimValue::Number(min),
        (SimValue::Integer(raw), Some(min)) if (raw as f64) < min => SimValue::Number(min),
        (value, _) => value,
    }
}

/// `DisplayBinding.changeset/2` format-string validation: grapheme length
/// between 1 and 200 plus the token rules of [`validate_format`]. On failure
/// the message matches the Elixir changeset error for `:format_string`.
pub fn validate_display_format_string(format: &str) -> Result<(), &'static str> {
    use unicode_segmentation::UnicodeSegmentation;
    let graphemes = format.graphemes(true).count();
    if graphemes < 1 {
        return Err("should be at least 1 character(s)");
    }
    if graphemes > 200 {
        return Err("should be at most 200 character(s)");
    }
    validate_format(format)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn min_clamp_only_raises_numeric_readings_below_the_minimum() {
        // display_controller_test.exs "a persisted nil minimum renders negative
        // simulator values" and the min_value: 50.0 replay fixture
        assert_eq!(clamp_to_min(SimValue::Number(42.5), Some(50.0)), SimValue::Number(50.0));
        assert_eq!(clamp_to_min(SimValue::Number(50.0), Some(50.0)), SimValue::Number(50.0));
        assert_eq!(clamp_to_min(SimValue::Number(51.2), Some(50.0)), SimValue::Number(51.2));
        assert_eq!(clamp_to_min(SimValue::Number(-12.5), None), SimValue::Number(-12.5));
        assert_eq!(clamp_to_min(SimValue::Number(-12.5), Some(0.0)), SimValue::Number(0.0));
        assert_eq!(clamp_to_min(SimValue::Integer(3), Some(4.5)), SimValue::Number(4.5));
        // non-numeric readings pass through even with a minimum configured
        assert_eq!(clamp_to_min(SimValue::Bool(true), Some(4.5)), SimValue::Bool(true));
        assert_eq!(clamp_to_min(SimValue::String("x".into()), Some(4.5)), SimValue::String("x".into()));
        assert_eq!(clamp_to_min(SimValue::Null, Some(4.5)), SimValue::Null);
    }

    #[test]
    fn validate_display_format_string_mirrors_the_changeset_rules() {
        assert!(validate_display_format_string("literal").is_ok());
        assert!(validate_display_format_string("{value}").is_ok());
        assert!(validate_display_format_string("{value:.0f}").is_ok());
        assert!(validate_display_format_string("{value:.10f}").is_ok());
        assert_eq!(
            validate_display_format_string(""),
            Err("should be at least 1 character(s)")
        );
        let too_long = format!("{}{}", "a".repeat(200), "b");
        assert_eq!(
            validate_display_format_string(&too_long),
            Err("should be at most 200 character(s)")
        );
        assert!(validate_display_format_string(&"a".repeat(200)).is_ok());
        for invalid in [
            "{value:.11f}",
            "{value:.999999999999999999999999f}",
            "{value:.2g}",
            "{value:bad}",
            "{value",
            "{value:.2f",
        ] {
            assert_eq!(
                validate_display_format_string(invalid),
                Err("Use {value} or {value:.Nf}, with precision from 0 to 10"),
                "{invalid} must be rejected"
            );
        }
    }

    #[test]
    fn format_display_covers_every_valid_precision_and_the_legacy_invalid_fallbacks() {
        // display_formatter_test.exs
        assert_eq!(format_display("{value}", &SimValue::Number(42.5)), "42.5");
        assert_eq!(format_display("{value}", &SimValue::String("hello".into())), "hello");
        assert_eq!(format_display("{value}", &SimValue::Bool(true)), "true");
        assert_eq!(format_display("{value:.0f}", &SimValue::Number(42.5)), "43");
        assert_eq!(format_display("{value:.1f}", &SimValue::Number(42.5)), "42.5");
        assert_eq!(format_display("{value:.2f}", &SimValue::Number(42.5)), "42.50");
        assert_eq!(format_display("{value:.1f}", &SimValue::Integer(42)), "42.0");
        assert_eq!(format_display("V:{value:.1f}", &SimValue::Number(42.5)), "V:42.5");
        assert_eq!(format_display("~{value}~", &SimValue::Integer(42)), "~42~");
        assert_eq!(format_display("HELLO", &SimValue::Integer(42)), "HELLO");
        for (precision, expected) in [
            (3u32, "42.500"),
            (4, "42.5000"),
            (5, "42.50000"),
            (6, "42.500000"),
            (7, "42.5000000"),
            (8, "42.50000000"),
            (9, "42.500000000"),
            (10, "42.5000000000"),
        ] {
            let format = format!("{{value:.{precision}f}}");
            assert_eq!(format_display(&format, &SimValue::Number(42.5)), expected);
        }
        // "legacy invalid precision remains safe to render"
        assert_eq!(
            format_display("{value:.999999999999999999999999f}", &SimValue::Number(42.5)),
            "42.5"
        );
        assert_eq!(format_display("{value:.11f}", &SimValue::Number(42.5)), "42.5");
        assert_eq!(format_display("{value:.01f}", &SimValue::Number(42.56)), "42.56");
    }

    #[test]
    fn format_display_renders_null_and_booleans_through_the_raw_token() {
        assert_eq!(format_display("{value}", &SimValue::Null), "");
        assert_eq!(format_display("x{value:.2f}y", &SimValue::Null), "xy");
        assert_eq!(format_display("{value:.2f}", &SimValue::Bool(true)), "true");
        assert_eq!(format_display("{value:.2f}", &SimValue::String("7".into())), "7");
    }
}
