//! Small, serializable presentation DTOs shared by the static desktop UI and Rust.
//!
//! These are contracts only. The Tauri command adapters that will provide them
//! are implemented alongside their owning services.

use crate::{AppError, ConfigId, EntityId, Epoch, ErrorCode, Revision, Topic};
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::path::Path;
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
    /// Database identity. The shared EntityId wire format is decimal text.
    #[ts(type = "string")]
    pub device_id: EntityId,
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
pub struct CalibrationView {
    pub min_value: Option<i32>,
    pub max_value: Option<i32>,
    pub has_rollover: bool,
    pub is_inverted: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct InputView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    pub pin: Option<i32>,
    /// Storage wire name: "analog" or "button".
    pub kind: String,
    pub sensitivity: Option<i32>,
    pub debounce: Option<i32>,
    pub name: Option<String>,
    pub calibration: Option<CalibrationView>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct MatrixPinView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    pub pin: i32,
    /// "row" or "col".
    pub pin_type: String,
    pub position: i32,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct MatrixView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    pub name: String,
    pub row_pins: Vec<MatrixPinView>,
    pub col_pins: Vec<MatrixPinView>,
    pub buttons: Vec<InputView>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct OutputView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    pub pin: i32,
    pub name: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
pub struct Ht16k33ParamsView {
    pub brightness: i32,
    pub num_digits: i32,
    /// "seven_segment" or "fourteen_segment".
    pub display_type: String,
    pub has_dot: bool,
    pub align_right: bool,
    pub min_value: Option<f64>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
pub struct I2cModuleView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    pub name: Option<String>,
    pub module_chip: String,
    pub i2c_address: i32,
    pub params: Option<Ht16k33ParamsView>,
}

/// Full persisted state of one hardware configuration (device row plus its
/// inputs, outputs, matrices and I2C modules).
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
pub struct DeviceDetailView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    pub name: Option<String>,
    pub description: Option<String>,
    #[ts(type = "number | null")]
    pub config_id: Option<ConfigId>,
    pub inputs: Vec<InputView>,
    pub outputs: Vec<OutputView>,
    pub matrices: Vec<MatrixView>,
    pub i2c_modules: Vec<I2cModuleView>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
pub struct NotchView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    #[ts(type = "number")]
    pub index: i64,
    /// "gate" or "linear".
    pub kind: String,
    pub value: Option<f64>,
    pub min_value: Option<f64>,
    pub max_value: Option<f64>,
    pub input_min: Option<f64>,
    pub input_max: Option<f64>,
    pub sim_input_min: Option<f64>,
    pub sim_input_max: Option<f64>,
    pub description: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
pub struct LeverConfigView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    pub min_endpoint: String,
    pub max_endpoint: String,
    pub value_endpoint: String,
    pub notch_count_endpoint: Option<String>,
    pub notch_index_endpoint: Option<String>,
    /// "discrete", "continuous" or "hybrid".
    pub lever_type: Option<String>,
    pub inverted: bool,
    pub calibrated_at: Option<String>,
    pub notches: Vec<NotchView>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
pub struct ElementView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    /// "lever" or "button".
    pub kind: String,
    pub name: String,
    pub lever_config: Option<LeverConfigView>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
pub struct SequenceCommandView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    #[ts(type = "number")]
    pub position: i64,
    pub endpoint: String,
    pub value: f64,
    #[ts(type = "number")]
    pub delay_ms: i64,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
pub struct SequenceView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    #[ts(type = "string")]
    pub train_id: crate::EntityId,
    pub name: String,
    pub commands: Vec<SequenceCommandView>,
}

/// Everything the train editor page renders: the train row, its elements with
/// lever configs and notches, identifiers, and its sequences with commands.
#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
pub struct TrainDetailView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    pub name: String,
    pub description: Option<String>,
    pub identifiers: Vec<String>,
    pub elements: Vec<ElementView>,
    pub sequences: Vec<SequenceView>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct LeverBindingView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    #[ts(type = "string")]
    pub lever_config_id: crate::EntityId,
    #[ts(type = "string")]
    pub input_id: crate::EntityId,
    pub enabled: bool,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
pub struct ButtonBindingView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    #[ts(type = "string")]
    pub element_id: crate::EntityId,
    #[ts(type = "string")]
    pub input_id: crate::EntityId,
    pub endpoint: Option<String>,
    pub on_value: f64,
    pub off_value: f64,
    pub enabled: bool,
    /// "simple", "momentary", "sequence" or "keystroke".
    pub mode: String,
    /// "momentary" or "latching".
    pub hardware_type: String,
    #[ts(type = "number")]
    pub repeat_interval_ms: i64,
    pub keystroke: Option<String>,
    #[ts(type = "string | null")]
    pub on_sequence_id: Option<crate::EntityId>,
    #[ts(type = "string | null")]
    pub off_sequence_id: Option<crate::EntityId>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
pub struct OutputBindingView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    #[ts(type = "string")]
    pub train_id: crate::EntityId,
    pub name: String,
    /// Storage wire name for the output kind.
    pub output_type: String,
    #[ts(type = "string")]
    pub output_id: crate::EntityId,
    pub endpoint: String,
    /// "gt", "gte", "lt", "lte", "between", "eq_true" or "eq_false".
    pub operator: String,
    pub value_a: Option<f64>,
    pub value_b: Option<f64>,
    pub enabled: bool,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct DisplayBindingView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    #[ts(type = "string")]
    pub train_id: crate::EntityId,
    #[ts(type = "string")]
    pub i2c_module_id: crate::EntityId,
    pub name: Option<String>,
    pub endpoint: String,
    pub format_string: String,
    pub enabled: bool,
    #[ts(type = "string | null")]
    pub script_id: Option<crate::EntityId>,
}

/// The whole bindings topic: every persisted binding family.
#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize, TS)]
pub struct BindingsView {
    pub lever: Vec<LeverBindingView>,
    pub button: Vec<ButtonBindingView>,
    pub output: Vec<OutputBindingView>,
    pub display: Vec<DisplayBindingView>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct ScriptView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    #[ts(type = "string")]
    pub train_id: crate::EntityId,
    pub name: String,
    pub enabled: bool,
    pub code: String,
    pub triggers: Vec<String>,
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct ScriptsView {
    pub scripts: Vec<ScriptView>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct FirmwareFileView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    #[ts(type = "string")]
    pub release_id: crate::EntityId,
    pub board_type: String,
    pub environment: Option<String>,
    pub download_url: String,
    #[ts(type = "number | null")]
    pub file_size: Option<i64>,
    pub checksum_sha256: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct FirmwareReleaseView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    pub version: String,
    pub tag_name: String,
    pub release_url: Option<String>,
    pub release_notes: Option<String>,
    pub published_at: Option<String>,
    pub files: Vec<FirmwareFileView>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct UpdateCheckView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    pub checked_at: String,
    pub found_updates: bool,
    pub latest_version: Option<String>,
    pub error_message: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct UploadHistoryView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    pub upload_id: String,
    pub port: String,
    pub board_type: String,
    #[ts(type = "string | null")]
    pub firmware_file_id: Option<crate::EntityId>,
    /// "running", "success", "failed" or "cancelled".
    pub status: String,
    pub error_message: Option<String>,
    #[ts(type = "number | null")]
    pub duration_ms: Option<i64>,
    pub started_at: Option<String>,
    pub completed_at: Option<String>,
}

#[derive(Clone, Debug, Default, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct FirmwareView {
    pub releases: Vec<FirmwareReleaseView>,
    pub update_checks: Vec<UpdateCheckView>,
    pub upload_history: Vec<UploadHistoryView>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct VjoyMappingView {
    #[ts(type = "string")]
    pub id: crate::EntityId,
    #[ts(type = "string")]
    pub input_id: crate::EntityId,
    #[ts(type = "number")]
    pub device_index: u8,
    /// Target wire name, e.g. "axis/x" or "button/3".
    pub target: String,
    pub inverted: bool,
    /// "analog" or "button".
    pub input_kind: String,
    pub input_pin: Option<i32>,
    #[ts(type = "string | null")]
    pub input_device: Option<crate::EntityId>,
    pub input_name: Option<String>,
}

/// Virtual joystick requested state: persisted configuration, selected
/// devices and mappings. Live driver status is runtime state, not a database
/// snapshot, and is served by the dedicated vJoy commands.
#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct VjoyView {
    pub enabled: bool,
    #[ts(type = "number")]
    pub device_index: u8,
    pub selected_devices: Vec<u8>,
    pub mappings: Vec<VjoyMappingView>,
}

#[derive(Clone, Copy, Debug, PartialEq, Serialize, Deserialize, TS)]
pub struct NotchRangeGapView {
    pub from: f64,
    pub to: f64,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize, TS)]
pub struct NotchRangesValidationView {
    pub valid: bool,
    pub gaps: Vec<NotchRangeGapView>,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct UiSnapshot<T> {
    #[ts(type = "string")]
    pub epoch: Epoch,
    #[ts(
        type = "'settings' | 'hardware' | 'trains' | 'bindings' | 'scripts' | 'firmware' | 'vjoy'"
    )]
    pub topic: Topic,
    #[ts(type = "string")]
    pub revision: Revision,
    pub value: T,
}

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize, TS)]
pub struct UiChange<T> {
    #[ts(type = "string")]
    pub epoch: Epoch,
    #[ts(
        type = "'settings' | 'hardware' | 'trains' | 'bindings' | 'scripts' | 'firmware' | 'vjoy'"
    )]
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

/// Regenerate the checked-in TypeScript declarations under
/// `tauri/ui/src/bridge/generated`. The byte-compare test pins the output.
pub fn export_typescript_contracts(output: &Path) -> Result<(), ts_rs::ExportError> {
    let config = ts_rs::Config::new().with_out_dir(output);
    for result in [
        BindingsView::export_all(&config),
        ButtonBindingView::export_all(&config),
        CalibrationView::export_all(&config),
        ConfigurationSummaryView::export_all(&config),
        ConnectedDeviceView::export_all(&config),
        ConsentState::export_all(&config),
        DeviceDetailView::export_all(&config),
        DisplayBindingView::export_all(&config),
        ElementView::export_all(&config),
        FirmwareFileView::export_all(&config),
        FirmwareReleaseView::export_all(&config),
        FirmwareView::export_all(&config),
        Ht16k33ParamsView::export_all(&config),
        I2cModuleView::export_all(&config),
        InputView::export_all(&config),
        LeverBindingView::export_all(&config),
        LeverConfigView::export_all(&config),
        MatrixPinView::export_all(&config),
        MatrixView::export_all(&config),
        NotchRangeGapView::export_all(&config),
        NotchRangesValidationView::export_all(&config),
        NotchView::export_all(&config),
        OutputBindingView::export_all(&config),
        OutputView::export_all(&config),
        ScriptView::export_all(&config),
        ScriptsView::export_all(&config),
        SequenceCommandView::export_all(&config),
        SequenceView::export_all(&config),
        SettingsView::export_all(&config),
        SimulatorSettingsView::export_all(&config),
        TrainDetailView::export_all(&config),
        TrainSummaryView::export_all(&config),
        UpdateCheckView::export_all(&config),
        UploadHistoryView::export_all(&config),
        UiFailure::export_all(&config),
        VjoyMappingView::export_all(&config),
        VjoyView::export_all(&config),
        UiSnapshot::<SettingsView>::export_all(&config),
        UiChange::<SettingsView>::export_all(&config),
    ] {
        result?;
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::{Path, PathBuf};
    use std::time::{SystemTime, UNIX_EPOCH};

    const GENERATED_TYPES: &[&str] = &[
        "BindingsView.ts",
        "ButtonBindingView.ts",
        "CalibrationView.ts",
        "ConfigurationSummaryView.ts",
        "ConnectedDeviceView.ts",
        "ConsentState.ts",
        "DeviceDetailView.ts",
        "DisplayBindingView.ts",
        "ElementView.ts",
        "FirmwareFileView.ts",
        "FirmwareReleaseView.ts",
        "FirmwareView.ts",
        "Ht16k33ParamsView.ts",
        "I2cModuleView.ts",
        "InputView.ts",
        "LeverBindingView.ts",
        "LeverConfigView.ts",
        "MatrixPinView.ts",
        "MatrixView.ts",
        "NotchRangeGapView.ts",
        "NotchRangesValidationView.ts",
        "NotchView.ts",
        "OutputBindingView.ts",
        "OutputView.ts",
        "ScriptView.ts",
        "ScriptsView.ts",
        "SequenceCommandView.ts",
        "SequenceView.ts",
        "SettingsView.ts",
        "SimulatorSettingsView.ts",
        "TrainDetailView.ts",
        "TrainSummaryView.ts",
        "UpdateCheckView.ts",
        "UploadHistoryView.ts",
        "UiChange.ts",
        "UiFailure.ts",
        "UiSnapshot.ts",
        "VjoyMappingView.ts",
        "VjoyView.ts",
    ];

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
            device_id: EntityId(7),
            config_id: ConfigId::new(i32::MAX as u32).unwrap(),
            name: "Main panel".into(),
            input_count: 0,
            description: None,
            active: false,
        };

        let json = serde_json::to_value(&view).unwrap();
        assert_eq!(json["config_id"], i32::MAX);
        assert_eq!(json["device_id"], "7");
        let decoded: ConfigurationSummaryView = serde_json::from_value(json).unwrap();
        assert_eq!(decoded.config_id, view.config_id);
        assert!(serde_json::from_str::<ConfigurationSummaryView>(
            r#"{"device_id":"7","config_id":2147483648,"name":"x","input_count":0,"description":null,"active":false}"#
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
        super::export_typescript_contracts(&generated).unwrap();
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
