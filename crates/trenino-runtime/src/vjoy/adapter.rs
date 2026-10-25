//! The adapter contract between the vJoy manager and the native vJoy SDK, the
//! shared neutral-report arithmetic, and an event-logging fake for tests.
//!
//! The Windows implementation ([`crate::vjoy::windows`]) wraps the vendored
//! `vjoy` crate; every other platform reports `supported() == false` and the
//! manager stays `VjoyStatus::Unsupported` without touching native code.

use std::collections::{BTreeMap, BTreeSet};

use super::configurator::ConfiguratorError;
use super::store::VjoyAxis;
use crate::storage::StorageError;

/// Device enumeration state as reported by the vJoy interface. Mirrors the
/// vendored `VJoyDeviceStatus`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum VjoyDeviceStatus {
    /// Owned by this process.
    Owned,
    /// Configured in the driver but not owned by anyone.
    Free,
    /// Owned by another process.
    Busy,
    /// Not configured in the driver.
    Missing,
    /// The interface could not classify the device.
    Unknown,
}

/// Descriptor facts for one device. The manager compares these against
/// [`REQUIRED_DESCRIPTOR`]; adapters report facts and never decide policy.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct DeviceDescriptor {
    pub axes: u32,
    pub buttons: u32,
    pub povs: u32,
    pub force_feedback: bool,
}

/// The exact Trenino device shape: eight axes (`x`, `y`, `z`, `rx`, `ry`, `rz`,
/// `slider_1`, `slider_2`), 32 buttons, no POV hats and no force feedback.
pub const REQUIRED_DESCRIPTOR: DeviceDescriptor = DeviceDescriptor {
    axes: 8,
    buttons: 32,
    povs: 0,
    force_feedback: false,
};

/// Manager-facing error categories. Ported from the Elixir manager/configurator
/// status reasons plus the vendored SDK error surface.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum VjoyError {
    /// This platform cannot host vJoy.
    Unsupported,
    /// The vJoy interface DLL is missing or the driver is not enabled.
    DriverUnavailable(String),
    /// A selected device is not configured in the driver.
    DeviceMissing(u8),
    /// A selected device exists but cannot be owned by this process.
    DeviceBusy(u8),
    /// A selected device's descriptor does not match [`REQUIRED_DESCRIPTOR`].
    IncompatibleDevice(u8, String),
    /// Acquiring a selected device failed; the device stays quarantined until
    /// an explicit [`crate::vjoy::VjoyManager::retry`].
    AcquireFailed(u8, String),
    /// Applying the neutral report to an acquired device failed.
    NeutralizeFailed(u8, String),
    /// A report could not be delivered to an acquired device.
    ReportFailed(u8, String),
    Configurator(ConfiguratorError),
    /// The command is invalid for the current status.
    InvalidState(&'static str),
    /// A previous failed acquire quarantined a selected device.
    Quarantined(u8, String),
    /// The shared resource arbiter holds a calibration/firmware lease.
    ArbiterBusy,
    /// Persistence failed.
    Storage(String),
}

impl From<StorageError> for VjoyError {
    fn from(error: StorageError) -> Self {
        // StorageError's Display omits field-level details; carry them through
        // so conflict/constraint categories keep their meaning at this boundary.
        let detail = match &error {
            StorageError::Conflict { detail }
            | StorageError::Constraint { detail }
            | StorageError::ForeignKey { detail }
            | StorageError::InvalidLegacyData { detail }
            | StorageError::InvalidHardware { detail }
            | StorageError::Backup { detail } => format!("{error}: {detail}"),
            _ => error.to_string(),
        };
        Self::Storage(detail)
    }
}

impl std::fmt::Display for VjoyError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Unsupported => f.write_str("virtual joystick is unsupported on this platform"),
            Self::DriverUnavailable(detail) => {
                write!(f, "vJoy driver is unavailable: {detail}")
            }
            Self::DeviceMissing(device) => write!(f, "vJoy device {device} is missing"),
            Self::DeviceBusy(device) => write!(f, "vJoy device {device} is busy"),
            Self::IncompatibleDevice(device, detail) => {
                write!(f, "vJoy device {device} is incompatible: {detail}")
            }
            Self::AcquireFailed(device, detail) => {
                write!(f, "vJoy device {device} could not be acquired: {detail}")
            }
            Self::NeutralizeFailed(device, detail) => {
                write!(f, "vJoy device {device} could not be neutralized: {detail}")
            }
            Self::ReportFailed(device, detail) => {
                write!(f, "vJoy device {device} report failed: {detail}")
            }
            Self::Configurator(error) => write!(f, "vJoy configurator failed: {error}"),
            Self::InvalidState(detail) => write!(f, "invalid state for command: {detail}"),
            Self::Quarantined(device, detail) => {
                write!(f, "vJoy device {device} is quarantined: {detail}")
            }
            Self::ArbiterBusy => {
                f.write_str("a calibration or firmware lease is active on the shared arbiter")
            }
            Self::Storage(detail) => write!(f, "storage error: {detail}"),
        }
    }
}

impl std::error::Error for VjoyError {}

/// Overflow-safe Elixir `round((min + max) / 2)` midpoint. Ties round away
/// from zero, so `[0, 32767]` centers at `16384`.
pub fn neutral_axis_value(min: i32, max: i32) -> i32 {
    let sum = i64::from(min) + i64::from(max);
    (if sum >= 0 {
        (sum + 1) / 2
    } else {
        (sum - 1) / 2
    }) as i32
}

/// The one acquisition path for native vJoy access. Implementations must
/// acquire devices individually and only for explicit IDs; the vendored crate's
/// all-device constructors are never used.
///
/// All methods are synchronous native calls; the manager serializes them under
/// its own lock.
pub trait VjoyAdapter: Send + 'static {
    /// Whether this platform can host vJoy at all. When false the manager
    /// reports [`crate::vjoy::VjoyStatus::Unsupported`] and makes no further
    /// adapter calls.
    fn supported(&self) -> bool;

    /// Validate that the vJoy interface DLL is present from its trusted
    /// absolute installed location and that the driver reports itself enabled.
    fn driver_available(&mut self) -> Result<(), VjoyError>;

    /// Report the enumeration/ownership state of one device without acquiring
    /// it. `device` is always in `1..=16`.
    fn device_status(&mut self, device: u8) -> Result<VjoyDeviceStatus, VjoyError>;

    /// Report descriptor facts for one device without acquiring it.
    fn descriptor(&mut self, device: u8) -> Result<DeviceDescriptor, VjoyError>;

    /// Acquire exactly `device`. Idempotent for an already-owned device.
    /// Adapters must first validate the descriptor and must acquire no device
    /// other than `device`.
    fn acquire_device(&mut self, device: u8) -> Result<(), VjoyError>;

    /// Apply the full neutral report to an acquired device: every axis set to
    /// [`neutral_axis_value`] over its driver-reported range and every button
    /// released, then submitted to the driver.
    fn neutralize_device(&mut self, device: u8) -> Result<(), VjoyError>;

    fn can_configure(&self) -> bool {
        false
    }
    fn ownership_marker(&mut self, _device: u8) -> Result<bool, VjoyError> {
        Ok(false)
    }
    fn creation_pending_marker(&mut self, _device: u8) -> Result<bool, VjoyError> {
        Ok(false)
    }
    fn creation_confirmed_marker(&mut self, _device: u8) -> Result<bool, VjoyError> {
        Ok(false)
    }
    fn configure_create(&mut self, device: u8) -> Result<(), VjoyError> {
        Err(VjoyError::DeviceMissing(device))
    }
    fn configure_delete(&mut self, _device: u8) -> Result<(), VjoyError> {
        Err(VjoyError::Unsupported)
    }
    /// Acknowledge that no privileged helper/status worker remains live.
    fn settle_configurator(&mut self) -> Result<(), VjoyError> {
        Ok(())
    }

    /// Native range for one mapped axis. Default keeps existing adapters
    /// source-compatible while refusing unsupported live reporting.
    fn axis_range(&mut self, _device: u8, _axis: VjoyAxis) -> Result<(i32, i32), VjoyError> {
        Err(VjoyError::Unsupported)
    }

    fn set_axis(&mut self, _device: u8, _axis: VjoyAxis, _value: i32) -> Result<(), VjoyError> {
        Err(VjoyError::Unsupported)
    }

    fn set_button(&mut self, _device: u8, _button: u8, _pressed: bool) -> Result<(), VjoyError> {
        Err(VjoyError::Unsupported)
    }

    /// Release an acquired device. The vJoy SDK's relinquish export is void, so
    /// release cannot report failure; callers must neutralize first.
    fn release_device(&mut self, device: u8);
}

/// One recorded adapter call, in order. Tests assert the acquire-only-selected
/// invariant and neutralize-before-release ordering against this log.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AdapterEvent {
    DriverCheck,
    Status(u8),
    Descriptor(u8),
    Acquire(u8),
    /// The neutral report applied to `device`; `center` is the
    /// [`neutral_axis_value`] computed from the scripted range.
    Neutralize {
        device: u8,
        center: i32,
    },
    Axis {
        device: u8,
        axis: VjoyAxis,
        value: i32,
    },
    Button {
        device: u8,
        button: u8,
        pressed: bool,
    },
    Release(u8),
    ConfigureCreate(u8),
    ConfigureDelete(u8),
}

/// Scripted per-device state for [`FakeVjoyAdapter`].
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FakeDevice {
    /// Status reported while the fake does not own the device.
    pub status: VjoyDeviceStatus,
    /// Descriptor facts; defaults to [`REQUIRED_DESCRIPTOR`].
    pub descriptor: DeviceDescriptor,
    /// Axis range used to compute the neutral center.
    pub axis_range: (i32, i32),
    /// When set, [`VjoyAdapter::acquire_device`] fails with this detail.
    pub acquire_error: Option<String>,
}

impl Default for FakeDevice {
    fn default() -> Self {
        Self {
            status: VjoyDeviceStatus::Free,
            descriptor: REQUIRED_DESCRIPTOR,
            axis_range: (0, 32767),
            acquire_error: None,
        }
    }
}

/// Event-logging in-memory [`VjoyAdapter`] for tests. Every call is appended to
/// `events`; `acquired` reflects current fake ownership.
#[derive(Default)]
pub struct FakeVjoyAdapter {
    supported: bool,
    driver_available: bool,
    driver_detail: String,
    devices: BTreeMap<u8, FakeDevice>,
    events: Vec<AdapterEvent>,
    acquired: BTreeSet<u8>,
    report_errors: BTreeMap<u8, String>,
    neutralize_errors: BTreeMap<u8, String>,
    owned: BTreeSet<u8>,
    pending: BTreeSet<u8>,
    confirmed: BTreeSet<u8>,
    marker_read_error: Option<u8>,
    configurator_enabled: bool,
}

impl FakeVjoyAdapter {
    /// A supported fake with a healthy driver and all sixteen devices free with
    /// the required descriptor.
    pub fn new() -> Self {
        Self {
            supported: true,
            driver_available: true,
            driver_detail: String::new(),
            devices: (1..=16).map(|id| (id, FakeDevice::default())).collect(),
            events: Vec::new(),
            acquired: BTreeSet::new(),
            report_errors: BTreeMap::new(),
            neutralize_errors: BTreeMap::new(),
            owned: (1..=16).collect(),
            pending: BTreeSet::new(),
            confirmed: BTreeSet::new(),
            marker_read_error: None,
            configurator_enabled: false,
        }
    }

    pub fn set_supported(&mut self, supported: bool) {
        self.supported = supported;
    }

    pub fn set_driver_available(&mut self, available: bool, detail: &str) {
        self.driver_available = available;
        self.driver_detail = detail.to_owned();
    }

    pub fn set_device(&mut self, device: u8, state: FakeDevice) {
        assert!((1..=16).contains(&device), "fake device id must be 1..=16");
        self.devices.insert(device, state);
    }

    pub fn set_report_error(&mut self, device: u8, detail: Option<&str>) {
        match detail {
            Some(detail) => {
                self.report_errors.insert(device, detail.to_owned());
            }
            None => {
                self.report_errors.remove(&device);
            }
        }
    }

    pub fn set_neutralize_error(&mut self, device: u8, detail: Option<&str>) {
        match detail {
            Some(detail) => {
                self.neutralize_errors.insert(device, detail.to_owned());
            }
            None => {
                self.neutralize_errors.remove(&device);
            }
        }
    }

    pub fn set_owned(&mut self, device: u8, owned: bool) {
        if owned {
            self.owned.insert(device);
        } else {
            self.owned.remove(&device);
        }
    }

    pub fn owned(&self, device: u8) -> bool {
        self.owned.contains(&device)
    }

    pub fn set_pending(&mut self, device: u8, pending: bool) {
        if pending {
            self.pending.insert(device);
        } else {
            self.pending.remove(&device);
        }
    }
    pub fn set_confirmed(&mut self, device: u8, confirmed: bool) {
        if confirmed {
            self.confirmed.insert(device);
        } else {
            self.confirmed.remove(&device);
        }
    }
    pub fn set_marker_read_error(&mut self, device: Option<u8>) {
        self.marker_read_error = device;
    }

    pub fn set_configurator_enabled(&mut self, enabled: bool) {
        self.configurator_enabled = enabled;
    }

    /// Recorded adapter calls, in order.
    pub fn events(&self) -> &[AdapterEvent] {
        &self.events
    }

    /// Devices currently owned by the fake.
    pub fn acquired(&self) -> &BTreeSet<u8> {
        &self.acquired
    }

    /// Drop the recorded call log (test setup helper between phases).
    pub fn clear_events(&mut self) {
        self.events.clear();
    }
}

impl VjoyAdapter for FakeVjoyAdapter {
    fn can_configure(&self) -> bool {
        self.configurator_enabled
    }
    fn ownership_marker(&mut self, device: u8) -> Result<bool, VjoyError> {
        if self.marker_read_error == Some(device) {
            return Err(VjoyError::Configurator(
                ConfiguratorError::MarkerWriteFailed,
            ));
        }
        Ok(self.owned(device))
    }
    fn creation_pending_marker(&mut self, device: u8) -> Result<bool, VjoyError> {
        Ok(self.pending.contains(&device))
    }
    fn creation_confirmed_marker(&mut self, device: u8) -> Result<bool, VjoyError> {
        Ok(self.confirmed.contains(&device))
    }
    fn configure_create(&mut self, device: u8) -> Result<(), VjoyError> {
        if !self.configurator_enabled {
            return Err(VjoyError::DeviceMissing(device));
        }
        let state = self
            .devices
            .get_mut(&device)
            .ok_or(VjoyError::DeviceMissing(device))?;
        if state.status == VjoyDeviceStatus::Free && self.confirmed.contains(&device) {
            self.events.push(AdapterEvent::ConfigureCreate(device));
            self.owned.insert(device);
            self.pending.remove(&device);
            self.confirmed.remove(&device);
            return Ok(());
        }
        if state.status != VjoyDeviceStatus::Missing {
            return Err(VjoyError::InvalidState("device already present"));
        }
        self.events.push(AdapterEvent::ConfigureCreate(device));
        state.status = VjoyDeviceStatus::Free;
        self.owned.insert(device);
        self.pending.remove(&device);
        self.confirmed.remove(&device);
        Ok(())
    }
    fn configure_delete(&mut self, device: u8) -> Result<(), VjoyError> {
        if !self.configurator_enabled {
            return Err(VjoyError::Unsupported);
        }
        let missing_with_intent = self.pending.contains(&device)
            && self
                .devices
                .get(&device)
                .is_some_and(|d| d.status == VjoyDeviceStatus::Missing);
        if !self.owned(device) && !missing_with_intent {
            return Err(VjoyError::Configurator(ConfiguratorError::ForeignDevice));
        }
        if self.acquired.contains(&device) {
            return Err(VjoyError::DeviceBusy(device));
        }
        let state = self
            .devices
            .get_mut(&device)
            .ok_or(VjoyError::DeviceMissing(device))?;
        if state.status == VjoyDeviceStatus::Busy {
            return Err(VjoyError::DeviceBusy(device));
        }
        self.events.push(AdapterEvent::ConfigureDelete(device));
        state.status = VjoyDeviceStatus::Missing;
        self.owned.remove(&device);
        self.pending.remove(&device);
        self.confirmed.remove(&device);
        Ok(())
    }
    fn supported(&self) -> bool {
        self.supported
    }

    fn driver_available(&mut self) -> Result<(), VjoyError> {
        self.events.push(AdapterEvent::DriverCheck);
        if self.driver_available {
            Ok(())
        } else {
            Err(VjoyError::DriverUnavailable(self.driver_detail.clone()))
        }
    }

    fn device_status(&mut self, device: u8) -> Result<VjoyDeviceStatus, VjoyError> {
        self.events.push(AdapterEvent::Status(device));
        match self.acquired.contains(&device) {
            true => Ok(VjoyDeviceStatus::Owned),
            false => Ok(self
                .devices
                .get(&device)
                .map(|state| state.status)
                .unwrap_or(VjoyDeviceStatus::Missing)),
        }
    }

    fn descriptor(&mut self, device: u8) -> Result<DeviceDescriptor, VjoyError> {
        self.events.push(AdapterEvent::Descriptor(device));
        match self.devices.get(&device) {
            Some(state) => Ok(state.descriptor),
            None => Err(VjoyError::DeviceMissing(device)),
        }
    }

    fn acquire_device(&mut self, device: u8) -> Result<(), VjoyError> {
        self.events.push(AdapterEvent::Acquire(device));
        if self.acquired.contains(&device) {
            return Ok(());
        }
        let Some(state) = self.devices.get(&device) else {
            return Err(VjoyError::DeviceMissing(device));
        };
        if let Some(detail) = &state.acquire_error {
            return Err(VjoyError::AcquireFailed(device, detail.clone()));
        }
        match state.status {
            VjoyDeviceStatus::Busy | VjoyDeviceStatus::Owned => Err(VjoyError::DeviceBusy(device)),
            VjoyDeviceStatus::Missing => Err(VjoyError::DeviceMissing(device)),
            VjoyDeviceStatus::Free | VjoyDeviceStatus::Unknown => {
                self.acquired.insert(device);
                Ok(())
            }
        }
    }

    fn neutralize_device(&mut self, device: u8) -> Result<(), VjoyError> {
        let (min, max) = self
            .devices
            .get(&device)
            .map(|state| state.axis_range)
            .unwrap_or((0, 32767));
        let center = neutral_axis_value(min, max);
        self.events
            .push(AdapterEvent::Neutralize { device, center });
        if let Some(detail) = self.neutralize_errors.get(&device) {
            return Err(VjoyError::NeutralizeFailed(device, detail.clone()));
        }
        if self.acquired.contains(&device) {
            Ok(())
        } else {
            Err(VjoyError::NeutralizeFailed(
                device,
                "device is not acquired".into(),
            ))
        }
    }

    fn axis_range(&mut self, device: u8, _axis: VjoyAxis) -> Result<(i32, i32), VjoyError> {
        self.devices
            .get(&device)
            .map(|state| state.axis_range)
            .ok_or(VjoyError::DeviceMissing(device))
    }

    fn set_axis(&mut self, device: u8, axis: VjoyAxis, value: i32) -> Result<(), VjoyError> {
        if !self.acquired.contains(&device) {
            return Err(VjoyError::ReportFailed(
                device,
                "device is not acquired".into(),
            ));
        }
        if let Some(detail) = self.report_errors.get(&device) {
            return Err(VjoyError::ReportFailed(device, detail.clone()));
        }
        self.events.push(AdapterEvent::Axis {
            device,
            axis,
            value,
        });
        Ok(())
    }

    fn set_button(&mut self, device: u8, button: u8, pressed: bool) -> Result<(), VjoyError> {
        if !self.acquired.contains(&device) {
            return Err(VjoyError::ReportFailed(
                device,
                "device is not acquired".into(),
            ));
        }
        if let Some(detail) = self.report_errors.get(&device) {
            return Err(VjoyError::ReportFailed(device, detail.clone()));
        }
        self.events.push(AdapterEvent::Button {
            device,
            button,
            pressed,
        });
        Ok(())
    }

    fn release_device(&mut self, device: u8) {
        self.events.push(AdapterEvent::Release(device));
        self.acquired.remove(&device);
    }
}

/// Shared-handle delegation so tests (and only tests) can keep observing the
/// event log while the manager owns the adapter.
impl VjoyAdapter for std::sync::Arc<std::sync::Mutex<FakeVjoyAdapter>> {
    fn can_configure(&self) -> bool {
        self.lock()
            .expect("fake vjoy adapter poisoned")
            .can_configure()
    }
    fn ownership_marker(&mut self, device: u8) -> Result<bool, VjoyError> {
        self.lock()
            .expect("fake vjoy adapter poisoned")
            .ownership_marker(device)
    }
    fn creation_pending_marker(&mut self, device: u8) -> Result<bool, VjoyError> {
        self.lock()
            .expect("fake vjoy adapter poisoned")
            .creation_pending_marker(device)
    }
    fn creation_confirmed_marker(&mut self, device: u8) -> Result<bool, VjoyError> {
        self.lock()
            .expect("fake vjoy adapter poisoned")
            .creation_confirmed_marker(device)
    }
    fn configure_create(&mut self, device: u8) -> Result<(), VjoyError> {
        self.lock()
            .expect("fake vjoy adapter poisoned")
            .configure_create(device)
    }
    fn configure_delete(&mut self, device: u8) -> Result<(), VjoyError> {
        self.lock()
            .expect("fake vjoy adapter poisoned")
            .configure_delete(device)
    }
    fn supported(&self) -> bool {
        self.lock().expect("fake vjoy adapter poisoned").supported
    }

    fn driver_available(&mut self) -> Result<(), VjoyError> {
        self.lock()
            .expect("fake vjoy adapter poisoned")
            .driver_available()
    }

    fn device_status(&mut self, device: u8) -> Result<VjoyDeviceStatus, VjoyError> {
        self.lock()
            .expect("fake vjoy adapter poisoned")
            .device_status(device)
    }

    fn descriptor(&mut self, device: u8) -> Result<DeviceDescriptor, VjoyError> {
        self.lock()
            .expect("fake vjoy adapter poisoned")
            .descriptor(device)
    }

    fn acquire_device(&mut self, device: u8) -> Result<(), VjoyError> {
        self.lock()
            .expect("fake vjoy adapter poisoned")
            .acquire_device(device)
    }

    fn neutralize_device(&mut self, device: u8) -> Result<(), VjoyError> {
        self.lock()
            .expect("fake vjoy adapter poisoned")
            .neutralize_device(device)
    }

    fn axis_range(&mut self, device: u8, axis: VjoyAxis) -> Result<(i32, i32), VjoyError> {
        self.lock()
            .expect("fake vjoy adapter poisoned")
            .axis_range(device, axis)
    }

    fn set_axis(&mut self, device: u8, axis: VjoyAxis, value: i32) -> Result<(), VjoyError> {
        self.lock()
            .expect("fake vjoy adapter poisoned")
            .set_axis(device, axis, value)
    }

    fn set_button(&mut self, device: u8, button: u8, pressed: bool) -> Result<(), VjoyError> {
        self.lock()
            .expect("fake vjoy adapter poisoned")
            .set_button(device, button, pressed)
    }

    fn release_device(&mut self, device: u8) {
        self.lock()
            .expect("fake vjoy adapter poisoned")
            .release_device(device)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn neutral_axis_value_uses_elixir_midpoint() {
        assert_eq!(neutral_axis_value(0, 32767), 16384);
        assert_eq!(neutral_axis_value(-32768, 32767), -1);
        assert_eq!(neutral_axis_value(i32::MIN, i32::MAX), -1);
        assert_eq!(neutral_axis_value(5, 5), 5);
    }
}
