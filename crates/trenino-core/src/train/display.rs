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
