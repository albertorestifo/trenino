//! Decimal rounding compatible with the project's Elixir float operations.

/// Round the exact binary value to decimal places using ties away from zero.
///
/// The multiplication-based `round(x * 10^n) / 10^n` idiom first rounds the
/// product to another binary float and incorrectly moves values such as 2.675
/// across a decimal midpoint. This routine decomposes the input float into its
/// exact mantissa and power of two, rounds the exact scaled rational, and then
/// parses its decimal representation back to `f64`.
pub fn round_elixir(value: f64, places: u32) -> Option<f64> {
    let fixed = decimal_fixed(value, places)?;
    fixed
        .parse::<f64>()
        .ok()
        .filter(|rounded| rounded.is_finite())
}

/// Render a finite float with a fixed decimal precision using Erlang's
/// `float_to_binary(value, decimals: n)` midpoint behavior.
pub fn format_elixir_decimal(value: f64, places: u32) -> Option<String> {
    if places > 10 || !value.is_finite() {
        return None;
    }
    let (negative, rounded_integer) = rounded_scaled_integer(value, places)?;
    let Some(integer) = rounded_integer else {
        // At this magnitude the float is already an exact multiple of the
        // requested decimal unit, so fixed formatting performs no rounding.
        return Some(format!("{value:.precision$}", precision = places as usize));
    };
    Some(format_scaled_integer(negative, integer, places))
}

fn decimal_fixed(value: f64, places: u32) -> Option<String> {
    if !value.is_finite() || places > 32 {
        return None;
    }
    let (negative, rounded_integer) = rounded_scaled_integer(value, places)?;
    let Some(integer) = rounded_integer else {
        return Some(format!("{value:.precision$}", precision = places as usize));
    };
    Some(format_scaled_integer(negative, integer, places))
}

/// `None` as the integer means the scaled value is already integral but too
/// large to materialize as u128; its original finite float is already rounded.
fn rounded_scaled_integer(value: f64, places: u32) -> Option<(bool, Option<u128>)> {
    if !value.is_finite() || places > 32 {
        return None;
    }
    let bits = value.to_bits();
    let negative = bits >> 63 != 0;
    let exponent_bits = ((bits >> 52) & 0x7ff) as i32;
    let fraction = bits & ((1_u64 << 52) - 1);
    if exponent_bits == 0 && fraction == 0 {
        return Some((negative, Some(0)));
    }
    let (mantissa, exponent) = if exponent_bits == 0 {
        (fraction as u128, -1074)
    } else {
        (
            ((1_u64 << 52) | fraction) as u128,
            exponent_bits - 1023 - 52,
        )
    };
    let five_power = 5_u128.checked_pow(places)?;
    let numerator = mantissa.checked_mul(five_power)?;
    let binary_exponent = exponent + places as i32;
    if binary_exponent >= 0 {
        return Some((negative, None));
    }
    let divisor_bits = (-binary_exponent) as u32;
    if divisor_bits >= 128 {
        return Some((negative, Some(0)));
    }
    let divisor = 1_u128 << divisor_bits;
    let mut rounded = numerator / divisor;
    let remainder = numerator % divisor;
    if remainder >= divisor / 2 {
        rounded = rounded.checked_add(1)?;
    }
    Some((negative, Some(rounded)))
}

fn format_scaled_integer(negative: bool, integer: u128, places: u32) -> String {
    let digits = integer.to_string();
    let sign = if negative { "-" } else { "" };
    if places == 0 {
        return format!("{sign}{digits}");
    }
    let places = places as usize;
    if digits.len() <= places {
        format!("{sign}0.{}{}", "0".repeat(places - digits.len()), digits)
    } else {
        let split = digits.len() - places;
        format!("{sign}{}.{}", &digits[..split], &digits[split..])
    }
}
