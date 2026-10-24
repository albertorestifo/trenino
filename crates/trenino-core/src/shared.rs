//! Domain types shared by the runtime and UI boundaries.
use serde::{de, Deserialize, Deserializer, Serialize, Serializer};
use std::collections::BTreeMap;

macro_rules! string_number {
    ($name:ident, $inner:ty) => {
        #[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord)]
        pub struct $name(pub $inner);
        impl Serialize for $name {
            fn serialize<S: Serializer>(&self, serializer: S) -> Result<S::Ok, S::Error> {
                serializer.serialize_str(&self.0.to_string())
            }
        }
        impl<'de> Deserialize<'de> for $name {
            fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
                let value = String::deserialize(deserializer)?;
                value.parse::<$inner>().map(Self).map_err(de::Error::custom)
            }
        }
    };
}

string_number!(EntityId, i64);
string_number!(OperationId, u128);
string_number!(SessionId, u128);
string_number!(Revision, u64);
string_number!(Epoch, u64);

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize)]
#[serde(transparent)]
pub struct ConfigId(u32);

impl ConfigId {
    /// Construct a firmware route ID, distinct from a database row ID.
    pub fn new(value: u32) -> Result<Self, &'static str> {
        if (1..=i32::MAX as u32).contains(&value) {
            Ok(Self(value))
        } else {
            Err("configuration ID must be a positive signed 32-bit value")
        }
    }

    pub fn get(self) -> u32 {
        self.0
    }
}

impl<'de> Deserialize<'de> for ConfigId {
    fn deserialize<D: Deserializer<'de>>(deserializer: D) -> Result<Self, D::Error> {
        let value = u32::deserialize(deserializer)?;
        Self::new(value).map_err(de::Error::custom)
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Topic {
    Settings,
    Hardware,
    Trains,
    Bindings,
    Scripts,
    Firmware,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Snapshot<T> {
    pub epoch: Epoch,
    pub topic: Topic,
    pub revision: Revision,
    pub value: T,
}

impl<T> Snapshot<T> {
    pub fn new(epoch: Epoch, topic: Topic, revision: Revision, value: T) -> Self {
        Self {
            epoch,
            topic,
            revision,
            value,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct Change<T> {
    pub epoch: Epoch,
    pub topic: Topic,
    pub revision: Revision,
    pub value: T,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum ErrorCode {
    Validation,
    Conflict,
    NotFound,
    Unavailable,
    Cancelled,
    Internal,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
pub struct AppError {
    pub code: ErrorCode,
    pub message: String,
    pub field_errors: BTreeMap<String, String>,
    pub retryable: bool,
}

impl AppError {
    pub fn internal(message: impl Into<String>) -> Self {
        Self {
            code: ErrorCode::Internal,
            message: message.into(),
            field_errors: BTreeMap::new(),
            retryable: false,
        }
    }
}
