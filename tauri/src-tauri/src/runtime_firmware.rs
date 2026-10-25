//! Firmware-only checking status and notices. Application updates remain separate.
use super::*;
use trenino_runtime::firmware::{
    owner::{FirmwareInventory, FirmwareOwnerStatus, FirmwareUpdateOwner},
    ConnectedFirmware, ConnectedUnconfiguredFirmware,
};

#[derive(Debug, serde::Serialize)]
pub(super) struct FirmwareNoticeView {
    version: String,
    outdated_devices: Vec<String>,
    outdated_ports: Vec<String>,
}
#[derive(Debug, serde::Serialize)]
pub(super) struct FirmwareUpdateStatus {
    checking: bool,
    checked_at_ms: Option<u64>,
    found_updates: bool,
    latest_version: Option<String>,
    error_message: Option<String>,
    notice: Option<FirmwareNoticeView>,
}
impl From<FirmwareOwnerStatus> for FirmwareUpdateStatus {
    fn from(value: FirmwareOwnerStatus) -> Self {
        Self {
            checking: value.check.checking,
            checked_at_ms: value.check.checked_at_ms,
            found_updates: value.check.found_updates,
            latest_version: value.check.latest_version,
            error_message: value.check.error_message,
            notice: value.notice.map(|n| FirmwareNoticeView {
                version: n.version,
                outdated_devices: n
                    .outdated_devices
                    .into_iter()
                    .map(|id| id.0.to_string())
                    .collect(),
                outdated_ports: n.outdated_ports,
            }),
        }
    }
}
pub(super) fn failure(message: String) -> UiFailure {
    UiFailure {
        code: "unavailable".into(),
        message,
        field_errors: Default::default(),
        retryable: true,
    }
}
pub(super) fn owner(state: &RustAppState) -> Result<Arc<FirmwareUpdateOwner>, UiFailure> {
    state.services()?;
    state
        .firmware
        .lock()
        .map_err(|_| failure("Firmware checker state unavailable.".into()))?
        .clone()
        .ok_or_else(|| failure("Firmware checker is unavailable.".into()))
}
fn inventory(state: &RustAppState) -> Result<FirmwareInventory, UiFailure> {
    let hardware = state
        .hardware
        .lock()
        .map_err(|_| failure("Hardware state unavailable.".into()))?
        .clone()
        .ok_or_else(|| failure("Hardware runtime is unavailable.".into()))?;
    Ok(inventory_from_ports(
        hardware.effects.command.connected_ports(),
    ))
}
fn inventory_from_ports(
    ports: Vec<trenino_runtime::hardware::service::ConnectedPort>,
) -> FirmwareInventory {
    let mut result = FirmwareInventory::default();
    for port in ports {
        match port.device_id {
            Some(device_id) => result.configured.push(ConnectedFirmware {
                device_id,
                connected: true,
                version: port.firmware_version,
            }),
            None => result.unconfigured.push(ConnectedUnconfiguredFirmware {
                port: port.port,
                connected: true,
                version: port.firmware_version,
            }),
        }
    }
    result
}
#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_firmware_update_status(
    state: State<'_, RustAppState>,
) -> Result<FirmwareUpdateStatus, UiFailure> {
    owner(&state)?
        .status(inventory(&state)?)
        .await
        .map(Into::into)
        .map_err(failure)
}
#[tauri::command(rename_all = "snake_case")]
pub(super) async fn ui_dismiss_firmware_update(
    state: State<'_, RustAppState>,
) -> Result<FirmwareUpdateStatus, UiFailure> {
    owner(&state)?
        .dismiss(inventory(&state)?)
        .await
        .map(Into::into)
        .map_err(failure)
}
pub(super) struct FirmwareParticipant(pub Arc<FirmwareUpdateOwner>);
impl ShutdownParticipant for FirmwareParticipant {
    fn stop_admission(&self) -> Result<(), String> {
        self.0.stop_admission();
        Ok(())
    }
    fn cancel_and_join_producers(&self) -> Result<(), String> {
        self.0.shutdown(Duration::from_secs(2))
    }
    fn neutralize_and_release_outputs(&self) -> Result<(), String> {
        Ok(())
    }
    fn close_ports_and_network(&self) -> Result<(), String> {
        Ok(())
    }
}

/// Parse legacy SQLite/Ecto UTC timestamps and current ISO UTC check records.
pub(super) fn checked_at_ms(value: &str) -> Option<u64> {
    let bytes = value.as_bytes();
    if bytes.len() < 19
        || bytes[4] != b'-'
        || bytes[7] != b'-'
        || ![b'T', b' '].contains(&bytes[10])
        || bytes[13] != b':'
        || bytes[16] != b':'
    {
        return None;
    }
    let year: i64 = value.get(0..4)?.parse().ok()?;
    let month: i64 = value.get(5..7)?.parse().ok()?;
    let day: i64 = value.get(8..10)?.parse().ok()?;
    let hour: i64 = value.get(11..13)?.parse().ok()?;
    let minute: i64 = value.get(14..16)?.parse().ok()?;
    let second: i64 = value.get(17..19)?.parse().ok()?;
    if !(1..=12).contains(&month)
        || !(1..=31).contains(&day)
        || !(0..24).contains(&hour)
        || !(0..60).contains(&minute)
        || !(0..60).contains(&second)
    {
        return None;
    }
    let y = year - i64::from(month <= 2);
    let era = y.div_euclid(400);
    let yoe = y - era * 400;
    let doy = (153 * (month + if month > 2 { -3 } else { 9 }) + 2) / 5 + day - 1;
    let days = era * 146097 + yoe * 365 + yoe / 4 - yoe / 100 + doy - 719468;
    let seconds = days * 86400 + hour * 3600 + minute * 60 + second;
    if format_checked_at(seconds).get(..10)? != value.get(..10)? {
        return None;
    }
    let suffix = &value[19..];
    let millis = match suffix.strip_prefix('.') {
        None if suffix.is_empty() || suffix == "Z" => 0,
        Some(fraction) => {
            let fraction = fraction.strip_suffix('Z').unwrap_or(fraction);
            if fraction.is_empty() || !fraction.bytes().all(|b| b.is_ascii_digit()) {
                return None;
            }
            format!("{fraction:0<3}").get(..3)?.parse::<u64>().ok()?
        }
        _ => return None,
    };
    u64::try_from(seconds)
        .ok()?
        .checked_mul(1000)?
        .checked_add(millis)
}

#[cfg(test)]
mod tests {
    use super::*;
    use trenino_runtime::firmware::FirmwareRepository;
    #[test]
    fn persisted_check_timestamp_restores_rate_limit_across_restart() {
        assert_eq!(checked_at_ms("1970-01-01T00:00:01Z"), Some(1000));
        assert_eq!(
            checked_at_ms("2026-10-25 08:09:10.123000"),
            checked_at_ms("2026-10-25T08:09:10.123Z")
        );
        assert!(checked_at_ms("2026-02-30T08:09:10Z").is_none());
        assert!(checked_at_ms("2026-10-25T28:09:10Z").is_none());
        let directory = tempfile::tempdir().unwrap();
        let repository = Arc::new(DbFirmwareRepository {
            db: trenino_runtime::storage::Database::open_full(directory.path().join("firmware.db"))
                .unwrap(),
        });
        repository.db.allocate_epoch().unwrap();
        let timestamp = checked_at_ms("2026-10-25T08:09:10Z").unwrap();
        repository
            .record_check(&trenino_runtime::firmware::UpdateCheckRecord {
                checked_at_ms: timestamp,
                found_updates: false,
                latest_version: None,
                error_message: None,
            })
            .unwrap();
        let scheduler =
            trenino_runtime::firmware::FirmwareUpdateScheduler::new(repository, Default::default())
                .unwrap();
        assert_eq!(scheduler.status().checked_at_ms, Some(timestamp));
        assert!(!scheduler.can_check(timestamp + 3599999));
        assert!(scheduler.can_check(timestamp + 3600000));
    }
    #[test]
    fn discovered_versions_include_unconfigured_ports_without_fabricated_ids() {
        use trenino_runtime::hardware::service::ConnectedPort;
        let inventory = inventory_from_ports(vec![
            ConnectedPort {
                port: "COM1".into(),
                generation: 4,
                config_id: None,
                device_id: Some(trenino_core::EntityId(8)),
                firmware_version: Some("1.0.0".into()),
            },
            ConnectedPort {
                port: "COM2".into(),
                generation: 9,
                config_id: None,
                device_id: None,
                firmware_version: Some("0.5.0".into()),
            },
        ]);
        assert_eq!(inventory.configured[0].device_id, trenino_core::EntityId(8));
        assert_eq!(inventory.configured[0].version.as_deref(), Some("1.0.0"));
        assert_eq!(inventory.unconfigured[0].port, "COM2");
        assert_eq!(inventory.unconfigured[0].version.as_deref(), Some("0.5.0"));
    }
    #[test]
    fn actual_manual_command_forces_new_check_through_same_owner() {
        use trenino_runtime::firmware::owner::{CheckFuture, FirmwareCheckPort};
        struct Check(std::sync::atomic::AtomicUsize);
        impl FirmwareCheckPort for Check {
            fn check(&self) -> CheckFuture<'_> {
                Box::pin(async move {
                    self.0.fetch_add(1, Ordering::SeqCst);
                    Ok(trenino_runtime::firmware::owner::FirmwareCheckResult {
                        latest_version: Some("1.2.0".into()),
                        found_updates: true,
                    })
                })
            }
        }
        let directory = tempfile::tempdir().unwrap();
        let state = RustAppState::empty();
        state
            .install(AppServices::open_full(directory.path().join("manual.db"), None).unwrap())
            .unwrap();
        let repository = Arc::new(DbFirmwareRepository {
            db: (*state.services().unwrap().database()).clone(),
        });
        let check = Arc::new(Check(std::sync::atomic::AtomicUsize::new(0)));
        let owner = Arc::new(
            FirmwareUpdateOwner::start(
                repository.clone(),
                check.clone(),
                Arc::new(trenino_runtime::simulator::services::clock::FakeClock::new()),
                1_700_000_000_000,
                Default::default(),
            )
            .unwrap(),
        );
        *state.firmware.lock().unwrap() = Some(owner.clone());
        let app = tauri::test::mock_builder()
            .manage(state)
            .invoke_handler(tauri::generate_handler![ui_check_firmware_updates])
            .build(tauri::test::mock_context(tauri::test::noop_assets()))
            .unwrap();
        let webview = tauri::WebviewWindowBuilder::new(&app, "main", Default::default())
            .build()
            .unwrap();
        for _ in 0..2 {
            let result = tauri::test::get_ipc_response(
                &webview,
                tauri::webview::InvokeRequest {
                    cmd: "ui_check_firmware_updates".into(),
                    callback: tauri::ipc::CallbackFn(0),
                    error: tauri::ipc::CallbackFn(1),
                    url: if cfg!(windows) {
                        "http://tauri.localhost"
                    } else {
                        "tauri://localhost"
                    }
                    .parse()
                    .unwrap(),
                    body: tauri::ipc::InvokeBody::Json(serde_json::json!({})),
                    headers: Default::default(),
                    invoke_key: tauri::test::INVOKE_KEY.into(),
                },
            )
            .unwrap()
            .deserialize::<serde_json::Value>()
            .unwrap();
            assert_eq!(result["topic"], "firmware");
        }
        assert_eq!(check.0.load(Ordering::SeqCst), 2);
        assert_eq!(
            repository
                .latest_check()
                .unwrap()
                .unwrap()
                .latest_version
                .as_deref(),
            Some("1.2.0")
        );
        owner.shutdown(Duration::from_secs(1)).unwrap();
    }
}
