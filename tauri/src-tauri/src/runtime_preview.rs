//! Typed, read-only previews used by the desktop wizard UI.

use tauri::State;
use trenino_core::train::output::OutputOperator;
use trenino_core::ui::UiFailure;
use trenino_runtime::preview::{
    self, CapturedRange, DisplayPreview, InputPreview, NotchMappingPreview, NotchSimulatorRange,
    OutputConditionPreview, PreviewError,
};

use super::{parse_entity_id, RustAppState};

fn failure(error: PreviewError) -> UiFailure {
    let (code, message, retryable) = match error {
        PreviewError::NotFound => (
            "not_found",
            "The selected record was not found.".to_owned(),
            false,
        ),
        PreviewError::Invalid(message) => ("validation", message.to_owned(), false),
        PreviewError::Storage(_) => (
            "unavailable",
            "Preview data is unavailable. Try again.".to_owned(),
            true,
        ),
    };
    UiFailure {
        code: code.into(),
        message,
        field_errors: Default::default(),
        retryable,
    }
}

#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_calibration_ceiling(
    state: State<'_, RustAppState>,
    input_id: String,
) -> Result<i32, UiFailure> {
    let id = parse_entity_id("input_id", &input_id)?;
    preview::calibration_ceiling(&state.services()?.database(), id).map_err(failure)
}

#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_preview_input(
    state: State<'_, RustAppState>,
    input_id: String,
    raw: i32,
) -> Result<InputPreview, UiFailure> {
    let id = parse_entity_id("input_id", &input_id)?;
    preview::preview_input(&state.services()?.database(), id, raw).map_err(failure)
}

#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_preview_notch_mapping(
    state: State<'_, RustAppState>,
    input_id: String,
    notches: Vec<NotchSimulatorRange>,
    captured: Vec<CapturedRange>,
    auto_distribute: bool,
) -> Result<NotchMappingPreview, UiFailure> {
    let id = parse_entity_id("input_id", &input_id)?;
    preview::preview_notch_mapping(
        &state.services()?.database(),
        id,
        &notches,
        &captured,
        auto_distribute,
    )
    .map_err(failure)
}

#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_preview_display(
    state: State<'_, RustAppState>,
    module_id: String,
    format_string: String,
    sample_value: f64,
) -> Result<DisplayPreview, UiFailure> {
    let id = parse_entity_id("module_id", &module_id)?;
    preview::preview_display(
        &state.services()?.database(),
        id,
        &format_string,
        sample_value,
    )
    .map_err(failure)
}

#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_preview_output_condition(
    state: State<'_, RustAppState>,
    operator: OutputOperator,
    value_a: Option<f64>,
    value_b: Option<f64>,
) -> Result<OutputConditionPreview, UiFailure> {
    state.services()?;
    Ok(preview::preview_output_condition(
        operator, value_a, value_b,
    ))
}
