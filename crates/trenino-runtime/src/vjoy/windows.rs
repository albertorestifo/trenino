//! Windows vJoy adapter over the vendored `vjoy` crate
//! (`vendor/vjoy`, patched upstream 0.7.1).
//!
//! ## Contract (for the Windows build)
//!
//! - The interface DLL loads only from a trusted absolute installed resource
//!   directory anchored at the desktop executable. No PATH or current-working-
//!   directory fallback runs: the vendored loader receives one checked path.
//! - Construction uses `from_dll_location_without_acquiring`; the vendored
//!   all-device constructors are never called. Devices are acquired one at a
//!   time through [`VjoyAdapter::acquire_device`] for explicit selected IDs
//!   only.
//! - `acquire_device` delegates to the vendored `acquire_device`, which
//!   validates the descriptor (eight required axes, no extra axes, exactly 32
//!   buttons, zero POV, no force feedback), acquires, re-validates, and on a
//!   descriptor change neutralizes from the last verified ranges and releases.
//! - `neutralize_device` centers every axis at the Elixir-rounded midpoint of its
//!   driver-reported range (`round((min + max) / 2)` — the same convention as
//!   [`crate::vjoy::neutral_axis_value`]), releases every button and submits
//!   the report before returning. The vendored `Device::reset_all` is not
//!   used: it zeroes axis values instead of centering them.
//! - `release_device` calls the vendored quiet relinquish; the SDK's
//!   `RelinquishVJD` export is void, so release failures cannot be reported.

use crate::vjoy::adapter::{
    neutral_axis_value, DeviceDescriptor, VjoyAdapter, VjoyDeviceStatus, VjoyError,
};
use crate::vjoy::configurator::{trusted_resource, Configurator, ResourcePaths};
use crate::vjoy::store::VjoyAxis;
use std::path::PathBuf;

use vjoy::{ButtonState, Device, Error as VendoredError, VJoy, VJoyDeviceStatus as VendoredStatus};

pub use super::windows_configurator::status_worker_entry;

/// Windows adapter. `sdk` holds the loaded interface; it is created lazily by
/// [`VjoyAdapter::driver_available`] so merely constructing the manager never
/// touches native code.
pub struct WindowsVjoyAdapter {
    pub(super) dll_path: String,
    pub(super) paths: Option<ResourcePaths>,
    pub(super) sdk: Option<VJoy>,
    pub(super) started: std::time::Instant,
    pub(super) pending_elevated: Vec<super::windows_configurator::NativeChild>,
    pub(super) pending_status: Vec<std::process::Child>,
}

impl WindowsVjoyAdapter {
    pub fn new() -> Self {
        let resources = std::env::current_exe()
            .ok()
            .and_then(|exe| exe.parent().map(|dir| dir.join("resources")))
            .unwrap_or_default();
        Self::with_resource_dir(resources)
    }

    /// Installed Tauri resource directory, independently anchored at the
    /// running executable's directory. The caller supplies the resource path;
    /// validation rejects any path outside that installation root.
    pub fn with_resource_dir(resources: PathBuf) -> Self {
        let anchor = std::env::current_exe()
            .ok()
            .and_then(|exe| exe.parent().map(PathBuf::from))
            .unwrap_or_default();
        let dll_path = resources
            .join("vJoyInterface.dll")
            .to_string_lossy()
            .into_owned();
        Self {
            dll_path,
            paths: Some(ResourcePaths { anchor, resources }),
            sdk: None,
            started: std::time::Instant::now(),
            pending_elevated: Vec::new(),
            pending_status: Vec::new(),
        }
    }

    pub(super) fn raw_driver_available(&mut self) -> Result<(), VjoyError> {
        let paths = self.paths.as_ref().ok_or(VjoyError::Unsupported)?;
        if paths.resources != paths.anchor.join("resources") {
            return Err(VjoyError::Configurator(
                crate::vjoy::configurator::ConfiguratorError::UntrustedResource,
            ));
        }
        let trusted =
            trusted_resource(self, paths, "vJoyInterface.dll").map_err(VjoyError::Configurator)?;
        self.dll_path = trusted.to_string_lossy().into_owned();
        if self.sdk.is_none() {
            self.sdk =
                Some(VJoy::from_dll_location_without_acquiring(&self.dll_path).map_err(map_error)?);
        }
        if self.sdk.as_ref().expect("sdk loaded above").is_enabled() {
            Ok(())
        } else {
            Err(VjoyError::DriverUnavailable(
                "vJoy driver reports itself disabled".into(),
            ))
        }
    }

    pub(super) fn raw_device_status(&mut self, device: u8) -> Result<VjoyDeviceStatus, VjoyError> {
        let sdk = self.sdk.as_mut().ok_or_else(|| {
            VjoyError::DriverUnavailable("vJoy interface has not been loaded".into())
        })?;
        match sdk.device_status(device_id(device)) {
            Ok(VendoredStatus::Owned) => Ok(VjoyDeviceStatus::Owned),
            Ok(VendoredStatus::Free) => Ok(VjoyDeviceStatus::Free),
            Ok(VendoredStatus::Busy) => Ok(VjoyDeviceStatus::Busy),
            Ok(VendoredStatus::Missing) => Ok(VjoyDeviceStatus::Missing),
            Ok(VendoredStatus::Unknown) => Ok(VjoyDeviceStatus::Unknown),
            Err(error) => Err(map_error(error)),
        }
    }
}

impl Default for WindowsVjoyAdapter {
    fn default() -> Self {
        Self::new()
    }
}

fn device_id(device: u8) -> u32 {
    u32::from(device)
}

fn axis_id(axis: VjoyAxis) -> u32 {
    match axis {
        VjoyAxis::X => 1,
        VjoyAxis::Y => 2,
        VjoyAxis::Z => 3,
        VjoyAxis::Rx => 4,
        VjoyAxis::Ry => 5,
        VjoyAxis::Rz => 6,
        VjoyAxis::Slider1 => 7,
        VjoyAxis::Slider2 => 8,
    }
}

fn map_error(error: VendoredError) -> VjoyError {
    match &error {
        VendoredError::Ffi(vjoy::FFIError::DynamicLybraryNotFound(path)) => {
            VjoyError::DriverUnavailable(format!("vJoyInterface.dll not found at {path}"))
        }
        VendoredError::App(vjoy::AppError::DeviceConfigurationIncompatible(device, reason)) => {
            VjoyError::IncompatibleDevice(*device as u8, reason.clone())
        }
        VendoredError::App(vjoy::AppError::DeviceNotFound(device)) => {
            VjoyError::DeviceMissing(*device as u8)
        }
        VendoredError::Ffi(vjoy::FFIError::DeviceCouldNotBeAcquired(device, _)) => {
            VjoyError::AcquireFailed(*device as u8, error.to_string())
        }
        other => VjoyError::DriverUnavailable(other.to_string()),
    }
}

impl VjoyAdapter for WindowsVjoyAdapter {
    fn supported(&self) -> bool {
        true
    }

    fn driver_available(&mut self) -> Result<(), VjoyError> {
        super::windows_configurator::probe_driver(self)
    }

    fn device_status(&mut self, device: u8) -> Result<VjoyDeviceStatus, VjoyError> {
        super::windows_configurator::probe_device(self, device)
    }

    fn descriptor(&mut self, device: u8) -> Result<DeviceDescriptor, VjoyError> {
        if self.sdk.is_none() {
            self.raw_driver_available()?;
        }
        let sdk = self.sdk.as_ref().ok_or_else(|| {
            VjoyError::DriverUnavailable("vJoy interface has not been loaded".into())
        })?;
        // inspect_device refuses incompatible shapes (extra axes, POV, FFB,
        // wrong button count) with DeviceConfigurationIncompatible, which
        // map_error surfaces as IncompatibleDevice; a successful inspect
        // yields the required 8-axis/32-button device.
        let inspected: Device = sdk.inspect_device(device_id(device)).map_err(map_error)?;
        Ok(DeviceDescriptor {
            axes: u32::try_from(inspected.num_axes()).unwrap_or(u32::MAX),
            buttons: u32::try_from(inspected.num_buttons()).unwrap_or(u32::MAX),
            povs: u32::try_from(inspected.num_hats()).unwrap_or(u32::MAX),
            force_feedback: sdk
                .has_force_feedback(device_id(device))
                .map_err(map_error)?,
        })
    }

    fn acquire_device(&mut self, device: u8) -> Result<(), VjoyError> {
        let sdk = self.sdk.as_mut().ok_or_else(|| {
            VjoyError::DriverUnavailable("vJoy interface has not been loaded".into())
        })?;
        sdk.acquire_device(device_id(device)).map_err(map_error)
    }

    fn neutralize_device(&mut self, device: u8) -> Result<(), VjoyError> {
        let sdk = self.sdk.as_mut().ok_or_else(|| {
            VjoyError::DriverUnavailable("vJoy interface has not been loaded".into())
        })?;
        let id = device_id(device);
        let mut state = sdk.get_device_state(id).map_err(map_error)?;
        for axis_id in 1..=u32::try_from(state.num_axes()).unwrap_or(0) {
            let (min, max) = sdk.axis_range(id, axis_id).map_err(map_error)?;
            let center = neutral_axis_value(min, max);
            state.set_axis(axis_id, center).map_err(map_error)?;
        }
        for button_id in 1..=u32::try_from(state.num_buttons()).unwrap_or(0) {
            state
                .set_button(button_id as u8, ButtonState::Released)
                .map_err(map_error)?;
        }
        sdk.update_device_state(&state)
            .map_err(|error| VjoyError::NeutralizeFailed(device, map_error(error).to_string()))
    }

    fn axis_range(&mut self, device: u8, axis: VjoyAxis) -> Result<(i32, i32), VjoyError> {
        let sdk = self.sdk.as_ref().ok_or_else(|| {
            VjoyError::DriverUnavailable("vJoy interface has not been loaded".into())
        })?;
        sdk.axis_range(device_id(device), axis_id(axis))
            .map_err(map_error)
    }

    fn set_axis(&mut self, device: u8, axis: VjoyAxis, value: i32) -> Result<(), VjoyError> {
        let sdk = self.sdk.as_mut().ok_or_else(|| {
            VjoyError::DriverUnavailable("vJoy interface has not been loaded".into())
        })?;
        let mut state = sdk
            .get_device_state(device_id(device))
            .map_err(|e| VjoyError::ReportFailed(device, e.to_string()))?;
        state
            .set_axis(axis_id(axis), value)
            .map_err(|e| VjoyError::ReportFailed(device, e.to_string()))?;
        sdk.update_device_state(&state)
            .map_err(|e| VjoyError::ReportFailed(device, e.to_string()))
    }

    fn set_button(&mut self, device: u8, button: u8, pressed: bool) -> Result<(), VjoyError> {
        let sdk = self.sdk.as_mut().ok_or_else(|| {
            VjoyError::DriverUnavailable("vJoy interface has not been loaded".into())
        })?;
        let mut state = sdk
            .get_device_state(device_id(device))
            .map_err(|e| VjoyError::ReportFailed(device, e.to_string()))?;
        state
            .set_button(
                button,
                if pressed {
                    ButtonState::Pressed
                } else {
                    ButtonState::Released
                },
            )
            .map_err(|e| VjoyError::ReportFailed(device, e.to_string()))?;
        sdk.update_device_state(&state)
            .map_err(|e| VjoyError::ReportFailed(device, e.to_string()))
    }

    fn release_device(&mut self, device: u8) {
        if let Some(sdk) = self.sdk.as_mut() {
            // Quiet relinquish: the vendored patch suppresses upstream's
            // stdout cleanup noise; the SDK cannot report failure.
            sdk.relinquish_device(device_id(device));
        }
    }

    fn can_configure(&self) -> bool {
        self.paths.is_some()
    }

    fn ownership_marker(&mut self, device: u8) -> Result<bool, VjoyError> {
        <Self as crate::vjoy::configurator::ConfiguratorBackend>::owned(self, device)
            .map_err(VjoyError::Configurator)
    }

    fn creation_pending_marker(&mut self, device: u8) -> Result<bool, VjoyError> {
        <Self as crate::vjoy::configurator::ConfiguratorBackend>::pending(self, device)
            .map_err(VjoyError::Configurator)
    }

    fn creation_confirmed_marker(&mut self, device: u8) -> Result<bool, VjoyError> {
        <Self as crate::vjoy::configurator::ConfiguratorBackend>::confirmed(self, device)
            .map_err(VjoyError::Configurator)
    }

    fn configure_create(&mut self, device: u8) -> Result<(), VjoyError> {
        let paths = self.paths.clone().ok_or(VjoyError::Unsupported)?;
        Configurator::new(paths)
            .create(self, device)
            .map_err(VjoyError::Configurator)
    }

    fn configure_delete(&mut self, device: u8) -> Result<(), VjoyError> {
        let paths = self.paths.clone().ok_or(VjoyError::Unsupported)?;
        Configurator::new(paths)
            .delete(self, device)
            .map_err(VjoyError::Configurator)
    }

    fn settle_configurator(&mut self) -> Result<(), VjoyError> {
        <Self as crate::vjoy::configurator::ConfiguratorBackend>::reconcile_processes(self)
            .map_err(VjoyError::Configurator)
    }
}
