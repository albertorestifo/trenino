//! Thin commands for the real hardware service's owned operations.
use super::{parse_entity_id, publish_change, unavailable, validation_failure, RustAppState};
use tauri::{AppHandle, State};
use trenino_core::{ui::UiFailure, Topic};
use trenino_runtime::hardware::service::ConfigurationOperationId;

fn failure(message: impl Into<String>) -> UiFailure {
    UiFailure {
        code: "unavailable".into(),
        message: message.into(),
        field_errors: Default::default(),
        retryable: true,
    }
}
#[derive(serde::Serialize)]
pub(super) struct SerialPortView {
    port: String,
    generation: Option<u64>,
    config_id: Option<u32>,
    device_id: Option<String>,
    status: &'static str,
}
#[tauri::command]
pub(super) async fn ui_serial_ports(
    state: State<'_, RustAppState>,
) -> Result<Vec<SerialPortView>, UiFailure> {
    state.services()?;
    let hardware = state.hardware_runtime()?;
    tauri::async_runtime::spawn_blocking(move || {
        let (connected, available) = hardware.with_handle(|handle| {
            Ok((
                handle.connected_ports(),
                handle.available_port_generations().map_err(failure)?,
            ))
        })?;
        Ok(available
            .into_iter()
            .map(|(port, generation)| {
                let live = connected.iter().find(|p| p.port == port);
                SerialPortView {
                    generation: Some(generation),
                    config_id: live.and_then(|p| p.config_id.map(|v| v.get())),
                    device_id: live.and_then(|p| p.device_id.map(|id| id.0.to_string())),
                    status: if live.is_some() {
                        "connected"
                    } else {
                        "available"
                    },
                    port,
                }
            })
            .collect())
    })
    .await
    .map_err(|_| failure("Serial inventory task failed."))?
}
#[tauri::command]
pub(super) async fn ui_scan_devices(state: State<'_, RustAppState>) -> Result<bool, UiFailure> {
    state.services()?;
    let hardware = state.hardware_runtime()?;
    tauri::async_runtime::spawn_blocking(move || {
        hardware.with_handle(|handle| handle.scan_now().map(|()| true).map_err(failure))
    })
    .await
    .map_err(|_| failure("Device scan task failed."))?
}
#[derive(serde::Serialize)]
pub(super) struct ApplyOperationView {
    operation_id: String,
    config_id: u32,
}
#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_begin_apply_configuration(
    state: State<'_, RustAppState>,
    device_id: String,
    port: String,
    generation: u64,
) -> Result<ApplyOperationView, UiFailure> {
    let device_id = parse_entity_id("device_id", &device_id)?;
    let db = state.services()?.database();
    let hardware = state.hardware_runtime()?;
    tauri::async_runtime::spawn_blocking(move || {
        let request = trenino_runtime::hardware::plan::configuration_request(
            &db, device_id, &port, generation,
        )
        .map_err(|message| validation_failure("configuration", &message))?;
        let config_id = request.config_id.get();
        let operation = hardware.with_handle(|handle| {
            if !handle
                .connected_ports()
                .iter()
                .any(|p| p.port == port && p.generation == generation)
            {
                return Err(failure(
                    "Device connection changed. Select its current port again.",
                ));
            }
            handle.begin_configuration(request).map_err(failure)
        })?;
        Ok(ApplyOperationView {
            operation_id: operation.get().to_string(),
            config_id,
        })
    })
    .await
    .map_err(|_| failure("Configuration task failed."))?
}
#[derive(serde::Serialize)]
pub(super) struct ApplyStatusView {
    state: &'static str,
    message: Option<String>,
}
#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_configuration_status(
    app: AppHandle,
    state: State<'_, RustAppState>,
    operation_id: String,
) -> Result<ApplyStatusView, UiFailure> {
    let operation = operation_id
        .parse::<u64>()
        .ok()
        .and_then(ConfigurationOperationId::from_wire)
        .ok_or_else(|| {
            validation_failure("operation_id", "Select a valid configuration operation.")
        })?;
    let hardware = state.hardware_runtime()?;
    let services = state.services()?;
    let (view, snapshot) = tauri::async_runtime::spawn_blocking(move || {
        let result = hardware.with_handle(|handle| {
            if !handle.knows_configuration_operation(operation) {
                return Err(UiFailure {
                    code: "not_found".into(),
                    message: "Configuration operation not found.".into(),
                    field_errors: Default::default(),
                    retryable: false,
                });
            }
            Ok(handle.configuration_result(operation))
        })?;
        match result {
            None => Ok::<_, UiFailure>((
                ApplyStatusView {
                    state: "pending",
                    message: None,
                },
                None,
            )),
            Some(Ok(())) => Ok((
                ApplyStatusView {
                    state: "complete",
                    message: None,
                },
                Some(services.list_configurations().map_err(UiFailure::from)?),
            )),
            Some(Err(error)) => Ok((
                ApplyStatusView {
                    state: "failed",
                    message: Some(format!("Configuration was not applied: {error:?}")),
                },
                None,
            )),
        }
    })
    .await
    .map_err(|_| UiFailure::from(unavailable("Configuration status is unavailable.")))??;
    if let Some(snapshot) = snapshot {
        publish_change(&app, Topic::Hardware, &snapshot);
    }
    Ok(view)
}

#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_disconnect_device(
    state: State<'_, RustAppState>,
    port: String,
    generation: u64,
) -> Result<bool, UiFailure> {
    state.services()?;
    let hardware = state.hardware_runtime()?;
    tauri::async_runtime::spawn_blocking(move || {
        hardware.with_handle(|handle| {
            handle
                .disconnect_port(&port, generation)
                .map(|()| true)
                .map_err(failure)
        })
    })
    .await
    .map_err(|_| failure("Device disconnect task failed."))?
}

#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_set_physical_output(
    state: State<'_, RustAppState>,
    output_id: String,
    high: bool,
    port: String,
    generation: u64,
) -> Result<bool, UiFailure> {
    let id = parse_entity_id("output_id", &output_id)?;
    let db = state.services()?.database();
    let hardware = state.hardware_runtime()?;
    tauri::async_runtime::spawn_blocking(move || {
        use trenino_runtime::train::output_controller::OutputLevel;
        let output = db
            .get_output(id)
            .map_err(|_| failure("Output data is unavailable."))?
            .ok_or_else(|| failure("Output not found."))?;
        let config = db
            .get_device(output.device_id)
            .map_err(|_| failure("Configuration is unavailable."))?
            .and_then(|d| d.config_id)
            .ok_or_else(|| failure("Device is not configured."))?;
        let matches = hardware.with_handle(|handle| {
            Ok(expected_owner(
                &handle.connected_ports(),
                &port,
                generation,
                config,
            ))
        })?;
        if !matches {
            return Err(failure(
                "Device connection changed. Select its current port again.",
            ));
        }
        hardware
            .effects
            .set_output_at(
                &port,
                generation,
                output.pin,
                if high {
                    OutputLevel::High
                } else {
                    OutputLevel::Low
                },
            )
            .map_err(failure)?;
        Ok(true)
    })
    .await
    .map_err(|_| failure("Output task failed."))?
}
#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_test_display(
    state: State<'_, RustAppState>,
    module_id: String,
    text: String,
    port: String,
    generation: u64,
) -> Result<bool, UiFailure> {
    let id = parse_entity_id("module_id", &module_id)?;
    let db = state.services()?.database();
    let hardware = state.hardware_runtime()?;
    tauri::async_runtime::spawn_blocking(move || {
        let (snapshot, _) = db
            .hardware_snapshot()
            .map_err(|_| failure("Display configuration is unavailable."))?;
        let module = snapshot
            .i2c_modules
            .iter()
            .find(|m| m.id == id)
            .ok_or_else(|| failure("Display module not found."))?;
        let params = module
            .params
            .as_ref()
            .ok_or_else(|| failure("Display parameters are missing."))?;
        let config = snapshot
            .devices
            .iter()
            .find(|d| d.id == module.device_id)
            .and_then(|d| d.config_id)
            .ok_or_else(|| failure("Device is not configured."))?;
        let matches = hardware.with_handle(|handle| {
            Ok(expected_owner(
                &handle.connected_ports(),
                &port,
                generation,
                config,
            ))
        })?;
        if !matches {
            return Err(failure(
                "Device connection changed. Select its current port again.",
            ));
        }
        let segments = trenino_core::hardware::ht16k33::encode_string(
            &text,
            params.num_digits as usize,
            params.display_type == trenino_runtime::storage::DisplayType::SevenSegment,
            params.has_dot,
            params.align_right,
        );
        hardware
            .effects
            .set_module_brightness_at(&port, generation, module.i2c_address, params.brightness)
            .map_err(failure)?;
        hardware
            .effects
            .write_segments_at(&port, generation, module.i2c_address, segments)
            .map_err(failure)?;
        Ok(true)
    })
    .await
    .map_err(|_| failure("Display test task failed."))?
}

fn expected_owner(
    ports: &[trenino_runtime::hardware::service::ConnectedPort],
    port: &str,
    generation: u64,
    config: trenino_core::ConfigId,
) -> bool {
    ports.iter().any(|owner| {
        owner.port == port && owner.generation == generation && owner.config_id == Some(config)
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn manual_actions_reject_a_configuration_that_moved_from_the_displayed_board() {
        let config = trenino_core::ConfigId::new(17).unwrap();
        let ports = vec![trenino_runtime::hardware::service::ConnectedPort {
            port: "B".into(),
            generation: 9,
            config_id: Some(config),
            device_id: None,
            firmware_version: None,
        }];
        assert!(!expected_owner(&ports, "A", 8, config));
        assert!(!expected_owner(&ports, "B", 8, config));
        assert!(expected_owner(&ports, "B", 9, config));
    }
}
