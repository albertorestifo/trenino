//! Wire-independent simulator value types shared by domain and runtime code.

use serde::{de, Deserialize, Deserializer, Serialize, Serializer};
use std::{error::Error, fmt};

/// A simulator endpoint is kept byte-for-byte as supplied by the profile.
#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct Endpoint(String);

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct EndpointError;

impl Endpoint {
    pub fn new(value: impl Into<String>) -> Result<Self, EndpointError> {
        let value = value.into();
        if value.trim().is_empty() {
            return Err(EndpointError);
        }
        Ok(Self(value))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for EndpointError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("simulator endpoint cannot be blank")
    }
}

impl Error for EndpointError {}

impl Serialize for Endpoint {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(&self.0)
    }
}

impl<'de> Deserialize<'de> for Endpoint {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let value = String::deserialize(deserializer)?;
        Self::new(value).map_err(de::Error::custom)
    }
}

/// JSON-shaped simulator values. Numbers must be finite at serialization boundaries.
#[derive(Clone, Debug, PartialEq)]
pub enum SimValue {
    Integer(i128),
    Number(f64),
    Bool(bool),
    String(String),
    Null,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct SimValueError;

impl SimValue {
    pub fn number(value: f64) -> Result<Self, SimValueError> {
        if value.is_finite() {
            Ok(Self::Number(value))
        } else {
            Err(SimValueError)
        }
    }

    pub fn to_legacy_string(&self) -> String {
        match self {
            Self::Integer(value) => value.to_string(),
            Self::Number(value) => legacy_float_string(*value),
            Self::Bool(value) => value.to_string(),
            Self::String(value) => value.clone(),
            Self::Null => String::new(),
        }
    }
}

fn legacy_float_string(value: f64) -> String {
    if !value.is_finite() {
        return format!("{value:?}");
    }
    let rendered = format!("{value:?}");
    if value == 0.0 {
        return rendered;
    }
    let (negative, unsigned) = rendered
        .strip_prefix('-')
        .map_or((false, rendered.as_str()), |unsigned| (true, unsigned));
    let (mantissa, exponent) = unsigned
        .split_once(['e', 'E'])
        .map_or((unsigned, 0), |(mantissa, exponent)| {
            (mantissa, exponent.parse::<i32>().unwrap_or(0))
        });
    let decimal_position = mantissa.find('.').unwrap_or(mantissa.len()) as i32;
    let digits: String = mantissa.chars().filter(char::is_ascii_digit).collect();
    let first_nonzero = digits.find(|digit| digit != '0').unwrap_or(0);
    let mut significant = digits[first_nonzero..].trim_end_matches('0').to_owned();
    if significant.is_empty() {
        significant.push('0');
    }
    let exponent = exponent + decimal_position - first_nonzero as i32 - 1;
    let sign = if negative { "-" } else { "" };
    let mut scientific_mantissa = significant[..1].to_owned();
    if significant.len() == 1 {
        scientific_mantissa.push_str(".0");
    } else {
        scientific_mantissa.push('.');
        scientific_mantissa.push_str(&significant[1..]);
    }
    let scientific = format!("{sign}{scientific_mantissa}e{exponent}");
    let decimal_position = exponent + 1;
    let fixed = if decimal_position <= 0 {
        format!(
            "{sign}0.{}{significant}",
            "0".repeat((-decimal_position) as usize)
        )
    } else if decimal_position as usize >= significant.len() {
        format!(
            "{sign}{}{}.0",
            significant,
            "0".repeat(decimal_position as usize - significant.len())
        )
    } else {
        let split = decimal_position as usize;
        format!("{sign}{}.{}", &significant[..split], &significant[split..])
    };
    if scientific.len() < fixed.len() {
        scientific
    } else {
        fixed
    }
}

impl fmt::Display for SimValueError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str("simulator number must be finite")
    }
}

impl Error for SimValueError {}

impl Serialize for SimValue {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        match self {
            Self::Integer(value) => serializer.serialize_i128(*value),
            Self::Number(value) if value.is_finite() => serializer.serialize_f64(*value),
            Self::Number(_) => Err(serde::ser::Error::custom(SimValueError)),
            Self::Bool(value) => serializer.serialize_bool(*value),
            Self::String(value) => serializer.serialize_str(value),
            Self::Null => serializer.serialize_none(),
        }
    }
}

impl<'de> Deserialize<'de> for SimValue {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        struct SimValueVisitor;
        impl<'de> de::Visitor<'de> for SimValueVisitor {
            type Value = SimValue;

            fn expecting(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
                formatter.write_str("a finite JSON number, boolean, string, or null")
            }

            fn visit_i64<E>(self, value: i64) -> Result<Self::Value, E> {
                Ok(SimValue::Integer(value.into()))
            }

            fn visit_u64<E>(self, value: u64) -> Result<Self::Value, E> {
                Ok(SimValue::Integer(value.into()))
            }

            fn visit_f64<E>(self, value: f64) -> Result<Self::Value, E>
            where
                E: de::Error,
            {
                SimValue::number(value).map_err(E::custom)
            }

            fn visit_bool<E>(self, value: bool) -> Result<Self::Value, E> {
                Ok(SimValue::Bool(value))
            }

            fn visit_str<E>(self, value: &str) -> Result<Self::Value, E>
            where
                E: de::Error,
            {
                Ok(SimValue::String(value.to_owned()))
            }

            fn visit_string<E>(self, value: String) -> Result<Self::Value, E> {
                Ok(SimValue::String(value))
            }

            fn visit_unit<E>(self) -> Result<Self::Value, E> {
                Ok(SimValue::Null)
            }

            fn visit_none<E>(self) -> Result<Self::Value, E> {
                Ok(SimValue::Null)
            }
        }

        deserializer.deserialize_any(SimValueVisitor)
    }
}
