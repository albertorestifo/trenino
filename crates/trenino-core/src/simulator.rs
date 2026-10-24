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
        #[derive(Deserialize)]
        #[serde(untagged)]
        enum Repr {
            Bool(bool),
            Number(f64),
            String(String),
            Null(()),
        }

        match Repr::deserialize(deserializer)? {
            Repr::Bool(value) => Ok(Self::Bool(value)),
            Repr::Number(value) => Self::number(value).map_err(de::Error::custom),
            Repr::String(value) => Ok(Self::String(value)),
            Repr::Null(()) => Ok(Self::Null),
        }
    }
}
