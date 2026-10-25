//! The explicit wizard Save commits all lever edits in one database transaction.
use super::{notch_draft, parse_entity_id, publish_change, AppServices, NotchInput, RustAppState};
use serde::{Deserialize, Serialize};
use tauri::{AppHandle, State};
use trenino_core::{
    ui::{NotchRangesValidationView, TrainDetailView, UiFailure, UiSnapshot},
    Topic,
};
use trenino_runtime::{
    preview::CapturedRange,
    storage::trains::{LeverConfigDraft, LeverMappingDraft, LeverType},
};

#[derive(Deserialize)]
pub(super) struct MappingEndpoints {
    min_endpoint: String,
    max_endpoint: String,
    value_endpoint: String,
    notch_count_endpoint: Option<String>,
    notch_index_endpoint: Option<String>,
    lever_type: Option<String>,
}
#[derive(Deserialize)]
pub(super) struct MappingInput {
    element_id: String,
    lever_config_id: Option<String>,
    input_id: String,
    replace_binding: bool,
    endpoints: MappingEndpoints,
    notches: Vec<NotchInput>,
    captured_ranges: Vec<CapturedRange>,
    auto_distribute: bool,
    #[serde(default)]
    calibration_completed: bool,
}
#[derive(Serialize)]
pub(super) struct MappingCommitView {
    committed: bool,
    lever_config_id: String,
    inverted: bool,
    train_detail: Option<UiSnapshot<TrainDetailView>>,
    validation: UiSnapshot<NotchRangesValidationView>,
    refresh_required: bool,
    #[serde(skip)]
    bindings: Option<UiSnapshot<trenino_core::ui::BindingsView>>,
    #[serde(skip)]
    trains: Option<UiSnapshot<Vec<trenino_core::ui::TrainSummaryView>>>,
}
fn commit(services: &AppServices, input: MappingInput) -> Result<MappingCommitView, UiFailure> {
    let endpoints = input.endpoints;
    let lever_type = match endpoints.lever_type.as_deref() {
        None => None,
        Some("continuous") => Some(LeverType::Continuous),
        Some("discrete") => Some(LeverType::Discrete),
        Some("hybrid") => Some(LeverType::Hybrid),
        Some(_) => {
            return Err(super::validation_failure(
                "lever_type",
                "Select a valid lever type.",
            ))
        }
    };
    let draft = LeverMappingDraft {
        element_id: parse_entity_id("element_id", &input.element_id)?,
        lever_config_id: input
            .lever_config_id
            .map(|id| parse_entity_id("lever_config_id", &id))
            .transpose()?,
        input_id: parse_entity_id("input_id", &input.input_id)?,
        replace_binding: input.replace_binding,
        endpoints: LeverConfigDraft {
            min_endpoint: endpoints.min_endpoint,
            max_endpoint: endpoints.max_endpoint,
            value_endpoint: endpoints.value_endpoint,
            notch_count_endpoint: endpoints.notch_count_endpoint,
            notch_index_endpoint: endpoints.notch_index_endpoint,
            lever_type,
            inverted: false,
        },
        notches: input
            .notches
            .into_iter()
            .map(notch_draft)
            .collect::<Result<_, _>>()?,
        captured_ranges: input.captured_ranges,
        auto_distribute: input.auto_distribute,
        calibration_completed: input.calibration_completed,
    };
    let saved = services
        .commit_lever_mapping(draft)
        .map_err(UiFailure::from)?;
    Ok(MappingCommitView {
        committed: true,
        lever_config_id: saved.lever_config_id.0.to_string(),
        inverted: saved.inverted,
        refresh_required: saved.train_detail.is_none()
            || saved.bindings.is_none()
            || saved.trains.is_none(),
        train_detail: saved.train_detail,
        validation: saved.validation,
        bindings: saved.bindings,
        trains: saved.trains,
    })
}
#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_commit_lever_mapping(
    app: AppHandle,
    state: State<'_, RustAppState>,
    mapping: MappingInput,
) -> Result<MappingCommitView, UiFailure> {
    let services = state.services()?;
    let _publication = state.publication.lock().await;
    let result = tauri::async_runtime::spawn_blocking(move || commit(&services, mapping))
        .await
        .map_err(|_| UiFailure::from(super::AppError::internal("Mapping save task failed.")))??;
    if let Some(snapshot) = &result.trains {
        publish_change(&app, Topic::Trains, snapshot);
    }
    if let Some(snapshot) = &result.bindings {
        publish_change(&app, Topic::Bindings, snapshot);
    }
    Ok(result)
}
