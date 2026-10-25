//! Windows vJoy adapter over the vendored `vjoy` crate
//! (`vendor/vjoy`, patched upstream 0.7.1).
//!
//! ## Contract (for the Windows build)
//!
//! - The interface DLL loads only from a trusted absolute installed path —
//!   [`DEFAULT_DLL_PATH`] mirrors the merged Windows packaging baseline
//!   (`vJoyInterface.dll` beside the installed vJoy driver). No PATH or
//!   current-working-directory fallback ever runs: the vendored crate's loader
//!   receives one explicit path and fails closed when it is absent.
//! - Construction uses `from_dll_location_without_acquiring`; the vendored
//!   all-device constructors are never called. Devices are acquired one at a
//!   time through [`VjoyAdapter::acquire_device`] for explicit selected IDs
//!   only.
//! - `acquire_device` delegates to the vendored `acquire_device`, which
//!   validates the descriptor (eight required axes, no extra axes, exactly 32
//!   buttons, zero POV, no force feedback), acquires, re-validates, and on a
//!   descriptor change neutralizes from the last verified ranges and releases.
//! - `neutralize_device` centers every axis at the widened midpoint of its
//!   driver-reported range (`min + (max - min) / 2` — the same convention as
//!   [`crate::vjoy::neutral_axis_value`]), releases every button and submits
//!   the report before returning. The vendored `Device::reset_all` is not
//!   used: it zeroes axis values instead of centering them.
//! - `release_device` calls the vendored quiet relinquish; the SDK's
//!   `RelinquishVJD` export is void, so release failures cannot be reported.

use crate::vjoy::adapter::{
    neutral_axis_value, DeviceDescriptor, VjoyAdapter, VjoyDeviceStatus, VjoyError,
};

use vjoy::{ButtonState, Device, Error as VendoredError, VJoy, VJoyDeviceStatus as VendoredStatus};

/// Trusted absolute location of the installed vJoy interface DLL (the same
/// baseline the Windows installer stages and verifies). Adapters never resolve
/// the DLL through PATH or the current working directory.
pub const DEFAULT_DLL_PATH: &str = "C:/Program Files/vJoy/x64/vJoyInterface.dll";

/// Windows adapter. `sdk` holds the loaded interface; it is created lazily by
/// [`VjoyAdapter::driver_available`] so merely constructing the manager never
/// touches native code.
pub struct WindowsVjoyAdapter {
    dll_path: String,
    sdk: Option<VJoy>,
}

impl WindowsVjoyAdapter {
    pub fn new() -> Self {
        Self {
            dll_path: DEFAULT_DLL_PATH.to_owned(),
            sdk: None,
        }
    }

    /// Build with an explicit trusted absolute DLL path (used by packaging
    /// tests and the installed-app compositor).
    pub fn with_dll_path(path: impl Into<String>) -> Self {
        Self {
            dll_path: path.into(),
            sdk: None,
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
        if self.sdk.is_none() {
            let sdk = VJoy::from_dll_location_without_acquiring(&self.dll_path)
                .map_err(map_error)?;
            self.sdk = Some(sdk);
        }
        match self.sdk.as_ref().expect("sdk loaded above").is_enabled() {
            true => Ok(()),
            false => Err(VjoyError::DriverUnavailable(
                "vJoy driver reports itself disabled".into(),
            )),
        }
    }

    fn device_status(&mut self, device: u8) -> Result<VjoyDeviceStatus, VjoyError> {
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

    fn descriptor(&mut self, device: u8) -> Result<DeviceDescriptor, VjoyError> {
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
            force_feedback: sdk.has_force_feedback(device_id(device)).map_err(map_error)?,
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

    fn release_device(&mut self, device: u8) {
        if let Some(sdk) = self.sdk.as_mut() {
            // Quiet relinquish: the vendored patch suppresses upstream's
            // stdout cleanup noise; the SDK cannot report failure.
            sdk.relinquish_device(device_id(device));
        }
    }
}
