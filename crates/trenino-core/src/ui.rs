//! Small, serializable presentation DTOs shared by the static desktop UI and Rust.
//!
//! These are contracts only. The Tauri command adapters that will provide them
//! are implemented alongside their owning services.

use crate::{AppError, ConfigId, Epoch, ErrorCode, Revision, Topic};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use ts_rs::TS;

#[derive(Clone, Copy, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
#[serde(rename_all = "snake_case")]
#[ts(rename_all = "snake_case")]
pub enum ConsentState {
    Unset,
    Enabled,
    Disabled,
}

impl From<Option<bool>> for ConsentState {
    fn from(value: Option<bool>) -> Self {
        match value {
            Some(true) => Self::Enabled,
            Some(false) => Self::Disabled,
            None => Self::Unset,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct SimulatorSettingsView {
    pub url: String,
    pub api_key_configured: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct SettingsView {
    pub error_reporting: ConsentState,
    pub simulator: SimulatorSettingsView,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct ConnectedDeviceView {
    pub name: String,
    pub port: String,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct ConfigurationSummaryView {
    /// Public firmware ConfigId; the checked positive i32 range is lossless in JS.
    #[ts(type = "number")]
    pub config_id: ConfigId,
    pub name: String,
    pub input_count: u32,
    pub description: Option<String>,
    pub active: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct TrainSummaryView {
    /// Database identity. The shared EntityId wire format is decimal text.
    #[ts(type = "string")]
    pub id: crate::EntityId,
    pub name: String,
    pub description: Option<String>,
    pub identifiers: Vec<String>,
    pub element_count: u32,
    pub active: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct UiSnapshot<T> {
    #[ts(type = "string")]
    pub epoch: Epoch,
    #[ts(type = "'settings' | 'hardware' | 'trains' | 'bindings' | 'scripts' | 'firmware'")]
    pub topic: Topic,
    #[ts(type = "string")]
    pub revision: Revision,
    pub value: T,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct UiChange<T> {
    #[ts(type = "string")]
    pub epoch: Epoch,
    #[ts(type = "'settings' | 'hardware' | 'trains' | 'bindings' | 'scripts' | 'firmware'")]
    pub topic: Topic,
    #[ts(type = "string")]
    pub revision: Revision,
    pub value: T,
}

/// UI-safe error contract; messages are suitable for display and contain no traces.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct UiFailure {
    #[ts(
        type = "'validation' | 'conflict' | 'not_found' | 'unavailable' | 'cancelled' | 'internal'"
    )]
    pub code: String,
    pub message: String,
    pub field_errors: BTreeMap<String, String>,
    pub retryable: bool,
}

impl From<AppError> for UiFailure {
    fn from(error: AppError) -> Self {
        Self {
            code: match error.code {
                ErrorCode::Validation => "validation",
                ErrorCode::Conflict => "conflict",
                ErrorCode::NotFound => "not_found",
                ErrorCode::Unavailable => "unavailable",
                ErrorCode::Cancelled => "cancelled",
                ErrorCode::Internal => "internal",
            }
            .into(),
            message: error.message,
            field_errors: error.field_errors,
            retryable: error.retryable,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn public_config_id_remains_numeric_and_stays_distinct_from_entity_id() {
        let view = ConfigurationSummaryView {
            config_id: ConfigId::new(i32::MAX as u32).unwrap(),
            name: "Main panel".into(),
            input_count: 0,
            description: None,
            active: false,
        };

        let json = serde_json::to_value(&view).unwrap();
        assert_eq!(json["config_id"], i32::MAX);
        let decoded: ConfigurationSummaryView = serde_json::from_value(json).unwrap();
        assert_eq!(decoded.config_id, view.config_id);
        assert!(serde_json::from_str::<ConfigurationSummaryView>(
            r#"{"config_id":2147483648,"name":"x","input_count":0,"description":null,"active":false}"#
        )
        .is_err());
    }

    #[test]
    fn settings_view_never_contains_api_key_material() {
        let view = SettingsView {
            error_reporting: ConsentState::Unset,
            simulator: SimulatorSettingsView {
                url: "http://127.0.0.1:31270".into(),
                api_key_configured: true,
            },
        };
        let json = serde_json::to_string(&view).unwrap();
        assert!(!json.contains("secret"));
        assert!(json.contains("api_key_configured"));
    }

    #[test]
    fn export_typescript_contracts() {
        let output = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../tauri/ui/src/bridge/generated"
        );
        let config = ts_rs::Config::new().with_out_dir(output);
        for result in [
            ConsentState::export_all(&config),
            SimulatorSettingsView::export_all(&config),
            SettingsView::export_all(&config),
            ConnectedDeviceView::export_all(&config),
            ConfigurationSummaryView::export_all(&config),
            TrainSummaryView::export_all(&config),
            UiSnapshot::<SettingsView>::export_all(&config),
            UiChange::<SettingsView>::export_all(&config),
            UiFailure::export_all(&config),
        ] {
            result.unwrap();
        }
    }
}
