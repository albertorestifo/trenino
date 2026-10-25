//! Firmware/scanner ownership adapter. Every wait is outside the hardware
//! handle lock and every accepted operation remains tracked until confirmed.
use super::{HardwareRuntime, UiFailure};
use std::{
    collections::HashMap,
    sync::{Mutex, Weak},
    time::{Duration, Instant},
};
use tauri::{AppHandle, Emitter};
use trenino_runtime::{
    firmware::{UploadCancelHandle, UploadEvent, UploadHooks, UploadSerialOwnership},
    hardware::{HandoffOperationId, PortHandoff},
    resource::LeaseToken,
};

const HANDOFF_TIMEOUT: Duration = Duration::from_secs(5);
const POLL_INTERVAL: Duration = Duration::from_millis(5);
#[derive(Clone)]
enum Pending {
    Acquiring(HandoffOperationId),
    Reserved(PortHandoff),
    Releasing {
        operation: HandoffOperationId,
        handoff: PortHandoff,
    },
}
pub(super) struct RuntimeUploadOwnership {
    hardware: Weak<HardwareRuntime>,
    pending: Mutex<HashMap<LeaseToken, Pending>>,
}
impl RuntimeUploadOwnership {
    pub(super) fn new(hardware: Weak<HardwareRuntime>) -> Self {
        Self {
            hardware,
            pending: Mutex::new(HashMap::new()),
        }
    }
    fn with_hardware<T>(
        &self,
        operation: impl FnOnce(&super::HardwareHandle) -> Result<T, String>,
    ) -> Result<T, String> {
        let hardware = self
            .hardware
            .upgrade()
            .ok_or("hardware service no longer exists")?;
        hardware
            .with_handle(|handle| {
                operation(handle).map_err(|message| UiFailure {
                    code: "unavailable".into(),
                    message,
                    field_errors: Default::default(),
                    retryable: true,
                })
            })
            .map_err(|error| error.message)
    }
    fn acquire_result(
        &self,
        lease: LeaseToken,
        operation: HandoffOperationId,
    ) -> Result<bool, String> {
        match self.with_hardware(|handle| Ok(handle.take_handoff_result(operation)))? {
            None => Ok(false),
            Some(Ok(handoff)) => {
                self.pending
                    .lock()
                    .map_err(|_| "upload handoff registry poisoned")?
                    .insert(lease, Pending::Reserved(handoff));
                Ok(true)
            }
            Some(Err(error)) => {
                self.pending
                    .lock()
                    .map_err(|_| "upload handoff registry poisoned")?
                    .remove(&lease);
                Err(error)
            }
        }
    }
}
impl UploadSerialOwnership for RuntimeUploadOwnership {
    fn prepare(
        &self,
        lease: LeaseToken,
        port: &str,
        generation: u64,
        cancel: &UploadCancelHandle,
    ) -> Result<(), String> {
        let operation = self.with_hardware(|handle| {
            if !handle
                .available_port_generations()?
                .iter()
                .any(|(available, current)| available == port && *current == generation)
            {
                return Err("serial port generation changed; select its current port again".into());
            }
            handle.begin_firmware_handoff(lease, port, generation)
        })?;
        self.pending
            .lock()
            .map_err(|_| "upload handoff registry poisoned")?
            .insert(lease, Pending::Acquiring(operation));
        let deadline = Instant::now() + HANDOFF_TIMEOUT;
        loop {
            if self.acquire_result(lease, operation)? {
                return Ok(());
            }
            if cancel.is_cancelled() {
                return Err("upload cancelled during serial handoff".into());
            }
            if Instant::now() >= deadline {
                return Err(
                    "serial handoff is still pending; reservation retained for cleanup".into(),
                );
            }
            std::thread::sleep(POLL_INTERVAL);
        }
    }
    fn finish(&self, lease: LeaseToken, _port: &str, _generation: u64) -> Result<(), String> {
        let deadline = Instant::now() + HANDOFF_TIMEOUT;
        loop {
            let pending = self
                .pending
                .lock()
                .map_err(|_| "upload handoff registry poisoned")?
                .get(&lease)
                .cloned();
            match pending {
                None => return Ok(()),
                Some(Pending::Acquiring(operation)) => {
                    // If the scanner refused the acquire, it owns no handoff
                    // and there is no reservation to release.
                    match self.acquire_result(lease, operation) {
                        Ok(_) => {}
                        Err(error) => {
                            if !self
                                .pending
                                .lock()
                                .map_err(|_| "upload handoff registry poisoned")?
                                .contains_key(&lease)
                            {
                                return Ok(());
                            }
                            return Err(error);
                        }
                    }
                }
                Some(Pending::Reserved(handoff)) => {
                    let operation = self.with_hardware(|handle| {
                        handle.release_firmware_handoff(lease, handoff.clone())
                    })?;
                    self.pending
                        .lock()
                        .map_err(|_| "upload handoff registry poisoned")?
                        .insert(lease, Pending::Releasing { operation, handoff });
                }
                Some(Pending::Releasing { operation, handoff }) => {
                    match self
                        .with_hardware(|handle| Ok(handle.take_handoff_release_result(operation)))?
                    {
                        None => {}
                        Some(Ok(())) => {
                            self.pending
                                .lock()
                                .map_err(|_| "upload handoff registry poisoned")?
                                .remove(&lease);
                            return Ok(());
                        }
                        Some(Err(error)) => {
                            self.pending
                                .lock()
                                .map_err(|_| "upload handoff registry poisoned")?
                                .insert(lease, Pending::Reserved(handoff));
                            return Err(error);
                        }
                    }
                }
            }
            if Instant::now() >= deadline {
                return Err("serial cleanup is still pending; firmware lease retained".into());
            }
            std::thread::sleep(POLL_INTERVAL);
        }
    }
}

pub(super) fn upload_hooks(app: AppHandle, hardware: Weak<HardwareRuntime>) -> UploadHooks {
    UploadHooks {
        on_event: Some(std::sync::Arc::new(move |event| {
            let value = match event {
                UploadEvent::Started {
                    upload_id,
                    port,
                    environment,
                } => {
                    serde_json::json!({"status":"started","upload_id":upload_id,"port":port,"environment":environment})
                }
                UploadEvent::Progress {
                    upload_id,
                    percent,
                    message,
                } => {
                    serde_json::json!({"status":"progress","upload_id":upload_id,"percent":percent,"message":message})
                }
                UploadEvent::Completed {
                    upload_id,
                    duration_ms,
                } => {
                    serde_json::json!({"status":"completed","upload_id":upload_id,"duration_ms":duration_ms})
                }
                UploadEvent::Failed {
                    upload_id,
                    reason,
                    message,
                } => {
                    serde_json::json!({"status":"failed","upload_id":upload_id,"reason":reason.error_key(),"message":message})
                }
            };
            let _ = app.emit("ui://firmware/upload", value);
        })),
        reconnect: Some(std::sync::Arc::new(move |_| {
            if let Some(hardware) = hardware.upgrade() {
                let _ = hardware.with_handle(|handle| {
                    handle.scan_now().map_err(|message| UiFailure {
                        code: "unavailable".into(),
                        message,
                        field_errors: Default::default(),
                        retryable: true,
                    })
                });
            }
        })),
    }
}
