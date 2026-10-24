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
        let (code, internal) = match error.code {
            ErrorCode::Validation => ("validation", false),
            ErrorCode::Conflict => ("conflict", false),
            ErrorCode::NotFound => ("not_found", false),
            ErrorCode::Unavailable => ("unavailable", false),
            ErrorCode::Cancelled => ("cancelled", false),
            ErrorCode::Internal => ("internal", true),
        };
        Self {
            code: code.into(),
            message: if internal {
                "The service could not complete the request.".into()
            } else {
                error.message
            },
            field_errors: if internal {
                BTreeMap::new()
            } else {
                error.field_errors
            },
            retryable: error.retryable,
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::{Path, PathBuf};
    use std::time::{SystemTime, UNIX_EPOCH};

    const GENERATED_TYPES: &[&str] = &[
        "ConfigurationSummaryView.ts",
        "ConnectedDeviceView.ts",
        "ConsentState.ts",
        "SettingsView.ts",
        "SimulatorSettingsView.ts",
        "TrainSummaryView.ts",
        "UiChange.ts",
        "UiFailure.ts",
        "UiSnapshot.ts",
    ];

    fn export_typescript_contracts(output: &Path) -> Result<(), ts_rs::ExportError> {
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
            result?;
        }
        Ok(())
    }

    fn compare_generated_files(
        generated: &Path,
        checked_in: &Path,
        files: &[&str],
    ) -> Result<(), String> {
        for file in files {
            let generated_file = generated.join(file);
            let checked_file = checked_in.join(file);
            let generated_text = fs::read(&generated_file)
                .map_err(|error| format!("missing generated {file}: {error}"))?;
            let checked_text = fs::read(&checked_file)
                .map_err(|error| format!("missing checked-in {file}: {error}"))?;
            if generated_text != checked_text {
                return Err(format!("generated TypeScript differs: {file}"));
            }
        }
        Ok(())
    }

    fn unique_temp_dir(label: &str) -> PathBuf {
        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!(
            "trenino-ui-types-{label}-{}-{timestamp}",
            std::process::id()
        ))
    }

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
    fn internal_failures_redact_messages_and_field_details() {
        let failure = UiFailure::from(AppError {
            code: ErrorCode::Internal,
            message: "token=super-secret database stack trace".into(),
            field_errors: BTreeMap::from([("token".into(), "super-secret".into())]),
            retryable: true,
        });

        assert_eq!(failure.code, "internal");
        assert_eq!(
            failure.message,
            "The service could not complete the request."
        );
        assert!(failure.field_errors.is_empty());
        assert!(failure.retryable);
    }

    #[test]
    fn generated_types_are_current_without_mutating_checked_in_files() {
        let generated = unique_temp_dir("check");
        fs::create_dir_all(&generated).unwrap();
        export_typescript_contracts(&generated).unwrap();
        let checked_in =
            Path::new(env!("CARGO_MANIFEST_DIR")).join("../../tauri/ui/src/bridge/generated");
        compare_generated_files(&generated, &checked_in, GENERATED_TYPES).unwrap();

        let generated_files = fs::read_dir(&generated)
            .unwrap()
            .map(|entry| entry.unwrap().file_name().to_string_lossy().into_owned())
            .collect::<std::collections::BTreeSet<_>>();
        let checked_files = fs::read_dir(&checked_in)
            .unwrap()
            .map(|entry| entry.unwrap().file_name().to_string_lossy().into_owned())
            .collect::<std::collections::BTreeSet<_>>();
        let expected = GENERATED_TYPES
            .iter()
            .map(|name| (*name).to_owned())
            .collect::<std::collections::BTreeSet<_>>();
        assert_eq!(
            generated_files, expected,
            "unexpected generated declarations"
        );
        assert_eq!(checked_files, expected, "stale checked-in declarations");
        fs::remove_dir_all(generated).unwrap();
    }

    #[test]
    fn stale_typescript_fixture_fails_the_drift_check() {
        let generated = unique_temp_dir("stale-generated");
        let checked_in = unique_temp_dir("stale-checked-in");
        fs::create_dir_all(&generated).unwrap();
        fs::create_dir_all(&checked_in).unwrap();
        fs::write(
            generated.join("ConsentState.ts"),
            "export type ConsentState = string;\n",
        )
        .unwrap();
        fs::write(
            checked_in.join("ConsentState.ts"),
            "export type ConsentState = boolean;\n",
        )
        .unwrap();
        let result = compare_generated_files(&generated, &checked_in, &["ConsentState.ts"]);
        assert_eq!(
            result.unwrap_err(),
            "generated TypeScript differs: ConsentState.ts"
        );
        fs::remove_dir_all(generated).unwrap();
        fs::remove_dir_all(checked_in).unwrap();
    }

    #[test]
    fn generated_types_match_rust_wire_envelopes() {
        let output = concat!(
            env!("CARGO_MANIFEST_DIR"),
            "/../../tauri/ui/src/bridge/generated"
        );
        let settings_json = serde_json::to_value(UiSnapshot {
            epoch: Epoch(18446744073709551614),
            topic: Topic::Settings,
            revision: Revision(18446744073709551615),
            value: SettingsView {
                error_reporting: ConsentState::Disabled,
                simulator: SimulatorSettingsView {
                    url: "http://127.0.0.1:31270".into(),
                    api_key_configured: false,
                },
            },
        })
        .unwrap();
        assert_eq!(settings_json["epoch"], "18446744073709551614");
        assert_eq!(settings_json["revision"], "18446744073709551615");
        assert_eq!(settings_json["topic"], "settings");
        assert!(Path::new(output).join("UiSnapshot.ts").exists());
    }
}
