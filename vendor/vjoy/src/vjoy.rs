use crate::axis::Axis;
use crate::button::{Button, ButtonState};
use crate::device::Device;
use crate::error::{AppError, Error, FFIError};
use crate::hat::HatState;
use libloading::Library;
use log::trace;
use vjoy_sys::{AXES_DISPLAY_NAMES, AXES_HID_USAGE, JOYSTICK_POSITION, VjdStat};

const REQUIRED_HID_AXES: [u32; 8] = [0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37];
const UNSUPPORTED_EXTRA_HID_AXES: [u32; 8] = [0x38, 0xB0, 0xBA, 0xBB, 0xC4, 0xC5, 0xC6, 0xC8];
const REQUIRED_DLL_EXPORTS: [&str; 12] = [
    "vJoyEnabled",
    "GetVJDStatus",
    "GetVJDButtonNumber",
    "GetVJDAxisExist",
    "GetVJDDiscPovNumber",
    "GetVJDContPovNumber",
    "GetVJDAxisMin",
    "GetVJDAxisMax",
    "AcquireVJD",
    "RelinquishVJD",
    "UpdateVJD",
    "IsDeviceFfb",
];

/// Status for an individual vJoy device.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum VJoyDeviceStatus {
    Owned,
    Free,
    Busy,
    Missing,
    Unknown,
}

/// Main entry for this crate and controller for all vJoy devices.
///
/// [from_default_dll_location](Self::from_default_dll_location()) loads the vJoyInterface.dll from "C:/Program Files/vJoy/x64/vJoyInterface.dll".
/// Alternatively, you can provide a custom location via [from_dll_location](Self::from_dll_location()).
///
/// [get_device_state](Self::get_device_state()) returns the current state for a specific device.
/// You can alter this state and upload it to the virtual device via [update_device_state](Self::update_device_state()).
///
/// Note on IDs: Since the display names for the virtual devices and components are hardcoded into the .dll,
/// all IDs are one-based to avoid confusion.
/// ID-Ranges:
/// - Devices: 1..=16
/// - Buttons: 1..=128
/// - Axes: 1..=8
/// - Hat switches: 1..=4
/// ```no_run
/// # use vjoy::{VJoy, ButtonState, Error};///
/// let mut vjoy = VJoy::from_default_dll_location()?;
/// let mut device_1 = vjoy.get_device_state(1)?;
///
/// device_1.set_button(1, ButtonState::Pressed)?;
/// device_1.set_axis(1, i32::MAX)?;
///
/// vjoy.update_device_state(&device_1)?;
///
/// device_1.reset_all();
///
/// vjoy.update_device_state(&device_1)?;
/// # Ok::<(), Error>(())
/// ```
pub struct VJoy {
    sdk: Box<dyn DeviceSdk>,
    devices: Vec<Device>,
}

impl VJoy {
    #[profiling::function]
    pub fn from_default_dll_location() -> Result<Self, Error> {
        Self::from_dll_location("C:/Program Files/vJoy/x64/vJoyInterface.dll")
    }

    #[profiling::function]
    pub fn from_dll_location(path: &str) -> Result<Self, Error> {
        let mut vjoy = Self::new(path)?;
        vjoy.fetch_devices();

        Ok(vjoy)
    }

    /// Loads the explicit interface DLL without acquiring any virtual device.
    ///
    /// Call [`acquire_device`](Self::acquire_device) for each device this process
    /// intends to own. This constructor avoids the all-device acquisition behavior
    /// of [`from_dll_location`](Self::from_dll_location).
    #[profiling::function]
    pub fn from_dll_location_without_acquiring(path: &str) -> Result<Self, Error> {
        Self::new(path)
    }

    /// Loads the explicit interface DLL and acquires only `device_id`.
    #[profiling::function]
    pub fn from_dll_location_for_device(path: &str, device_id: u32) -> Result<Self, Error> {
        validate_device_id(device_id)?;
        let mut vjoy = Self::new(path)?;
        vjoy.acquire_device(device_id)?;
        Ok(vjoy)
    }

    /// Returns whether the loaded interface reports an enabled vJoy driver.
    #[profiling::function]
    pub fn is_enabled(&self) -> bool {
        self.sdk.is_enabled()
    }

    /// Returns the current status of one device without acquiring it.
    #[profiling::function]
    pub fn device_status(&self, device_id: u32) -> Result<VJoyDeviceStatus, Error> {
        validate_device_id(device_id)?;
        Ok(match self.sdk.device_status(device_id) {
            vjoy_sys::VjdStat_VJD_STAT_OWN => VJoyDeviceStatus::Owned,
            vjoy_sys::VjdStat_VJD_STAT_FREE => VJoyDeviceStatus::Free,
            vjoy_sys::VjdStat_VJD_STAT_BUSY => VJoyDeviceStatus::Busy,
            vjoy_sys::VjdStat_VJD_STAT_MISS => VJoyDeviceStatus::Missing,
            _ => VJoyDeviceStatus::Unknown,
        })
    }

    /// Acquires exactly the requested device and stores its configured state.
    #[profiling::function]
    pub fn acquire_device(&mut self, device_id: u32) -> Result<(), Error> {
        validate_device_id(device_id)?;
        if self.devices.iter().any(|device| device.id == device_id) {
            return Ok(());
        }

        self.devices
            .push(fetch_device(self.sdk.as_ref(), device_id)?);
        Ok(())
    }

    /// Relinquishes a device acquired through this controller.
    #[profiling::function]
    pub fn relinquish_device(&mut self, device_id: u32) {
        if let Some(index) = self
            .devices
            .iter()
            .position(|device| device.id == device_id)
        {
            self.devices.remove(index);
            self.sdk.relinquish_device(device_id);
        }
    }

    /// Reads the logical range for one axis ID (1 through 8).
    #[profiling::function]
    pub fn axis_range(&self, device_id: u32, axis_id: u32) -> Result<(i32, i32), Error> {
        validate_device_id(device_id)?;
        if !(1..=8).contains(&axis_id) {
            return Err(Error::App(AppError::AxisNotFound(device_id, axis_id)));
        }

        self.sdk.axis_range(device_id, axis_id)
    }

    /// Reports whether the selected device supports force feedback.
    #[profiling::function]
    pub fn has_force_feedback(&self, device_id: u32) -> Result<bool, Error> {
        validate_device_id(device_id)?;
        Ok(self.sdk.has_force_feedback(device_id))
    }

    /// Queries and validates a device descriptor without acquiring it.
    ///
    /// `IsDeviceFfb` returns false both for a non-FFB device and for some native
    /// query failures; this API cannot distinguish those cases.
    #[profiling::function]
    pub fn inspect_device(&self, device_id: u32) -> Result<Device, Error> {
        inspect_device(self.sdk.as_ref(), device_id)
    }

    #[profiling::function]
    pub fn devices_cloned(&self) -> Vec<Device> {
        self.devices.clone()
    }

    #[profiling::function]
    pub fn devices(&self) -> std::slice::Iter<'_, Device> {
        self.devices.iter()
    }

    #[profiling::function]
    pub fn devices_mut(&mut self) -> std::slice::IterMut<'_, Device> {
        self.devices.iter_mut()
    }

    #[profiling::function]
    pub fn get_device_state(&self, device_id: u32) -> Result<Device, Error> {
        match self.devices.iter().find(|device| device.id == device_id) {
            Some(device) => Ok(device.clone()),
            None => Err(Error::App(AppError::DeviceNotFound(device_id))),
        }
    }

    #[profiling::function]
    pub fn get_device_state_ref(&self, device_id: u32) -> Result<&Device, Error> {
        match self.devices.iter().find(|device| device.id == device_id) {
            Some(device) => Ok(device),
            None => Err(Error::App(AppError::DeviceNotFound(device_id))),
        }
    }

    #[profiling::function]
    pub fn get_device_state_mut(&mut self, device_id: u32) -> Result<&mut Device, Error> {
        match self
            .devices
            .iter_mut()
            .find(|device| device.id == device_id)
        {
            Some(device) => Ok(device),
            None => Err(Error::App(AppError::DeviceNotFound(device_id))),
        }
    }

    #[profiling::function]
    pub fn update_all_devices(&mut self) -> Result<(), Error> {
        for device in self.devices.iter() {
            let mut data = position_for_device(device);
            self.sdk.update_device_data(device.id, &mut data)?;
        }

        Ok(())
    }

    #[profiling::function]
    pub fn update_device_state(&mut self, new_device_state: &Device) -> Result<(), Error> {
        if new_device_state.id == 0 {
            return Err(Error::App(AppError::DeviceNotFound(new_device_state.id)));
        }

        let index = match self
            .devices
            .iter_mut()
            .position(|device| device.id == new_device_state.id)
        {
            Some(index) => index,
            None => return Err(Error::App(AppError::DeviceNotFound(new_device_state.id))),
        };

        let mut data = position_for_device(new_device_state);
        self.sdk
            .update_device_data(new_device_state.id, &mut data)?;
        self.devices[index] = new_device_state.clone();

        Ok(())
    }

    /// All vJoy devices share the same guid and vendor/device information.
    ///
    /// To differentiate between vJoy devices from other libraries (e.g. SDL2), you may use the configuration instead.
    #[profiling::function]
    pub fn get_id_for_configuration(
        &self,
        num_buttons: u32,
        num_axes: u32,
        num_hats: u32,
    ) -> Result<u32, Error> {
        let find: Vec<&Device> = self
            .devices
            .iter()
            .filter(|device| {
                device.buttons.len() as u32 == num_buttons
                    && device.axes.len() as u32 == num_axes
                    && device.hats.len() as u32 == num_hats
            })
            .collect();

        if find.len() > 1 {
            return Err(Error::App(AppError::DeviceConfigMultipleFound(
                num_buttons,
                num_axes,
                num_hats,
            )));
        }

        match find.first() {
            Some(device) => Ok(device.id),
            None => Err(Error::App(AppError::DeviceConfigNotFound(
                num_buttons,
                num_axes,
                num_hats,
            ))),
        }
    }

    #[profiling::function]
    fn new(path: &str) -> Result<Self, Error> {
        Ok(Self::with_sdk(Box::new(NativeDeviceSdk::load(path)?)))
    }

    fn with_sdk(sdk: Box<dyn DeviceSdk>) -> Self {
        Self {
            sdk,
            devices: Vec::new(),
        }
    }

    #[profiling::function]
    fn fetch_devices(&mut self) {
        for device_id in 1..=16 {
            let _ = self.acquire_device(device_id);
        }
    }

    #[profiling::function]
    fn set_button(
        ffi: &vjoy_sys::vJoyInterface,
        device_id: u32,
        button_id: u8,
        state: ButtonState,
    ) -> Result<(), Error> {
        unsafe {
            let result = ffi.SetBtn(state as i32, device_id, button_id);
            if result != 1 {
                let device_state = Self::get_device_ffi_status(ffi, device_id);
                return Err(Error::Ffi(FFIError::ButtonCouldNotBeSet(
                    device_id,
                    button_id,
                    device_state,
                )));
            }
        }
        Ok(())
    }

    #[profiling::function]
    fn set_axis(
        ffi: &vjoy_sys::vJoyInterface,
        device_id: u32,
        axis_id: u32,
        value: i32,
    ) -> Result<(), Error> {
        unsafe {
            let axis_index = (axis_id - 1) as usize;
            let axis_hid = AXES_HID_USAGE[axis_index];
            let result = ffi.SetAxis(value, device_id, axis_hid);
            if result != 1 {
                let device_state = Self::get_device_ffi_status(ffi, device_id);
                return Err(Error::Ffi(FFIError::AxisCouldNotBeSet(
                    device_id,
                    axis_id,
                    device_state,
                )));
            }
        }
        Ok(())
    }

    #[profiling::function]
    fn set_hat(
        ffi: &vjoy_sys::vJoyInterface,
        device_id: u32,
        hat_id: u8,
        state: HatState,
    ) -> Result<(), Error> {
        unsafe {
            let result = match state {
                HatState::Discrete(disc) => ffi.SetDiscPov(disc as i32, device_id, hat_id),
                HatState::Continuous(cont) => ffi.SetContPov(cont, device_id, hat_id),
            };
            if result != 1 {
                let device_state = Self::get_device_ffi_status(ffi, device_id);
                return Err(Error::Ffi(FFIError::HatCouldNotBeSet(
                    device_id,
                    hat_id,
                    device_state,
                )));
            }
        }
        Ok(())
    }

    #[profiling::function]
    fn get_device_ffi_status(ffi: &vjoy_sys::vJoyInterface, device_id: u32) -> VjdStat {
        unsafe { ffi.GetVJDStatus(device_id) }
    }
}

fn validate_device_id(device_id: u32) -> Result<(), Error> {
    if (1..=16).contains(&device_id) {
        Ok(())
    } else {
        Err(Error::App(AppError::DeviceNotFound(device_id)))
    }
}

trait DeviceSdk {
    fn is_enabled(&self) -> bool;
    fn device_status(&self, device_id: u32) -> VjdStat;
    fn acquire_device(&self, device_id: u32) -> Result<(), Error>;
    fn relinquish_device(&self, device_id: u32);
    fn button_count(&self, device_id: u32) -> i32;
    fn axis_exists(&self, device_id: u32, hid_usage: u32) -> bool;
    fn discrete_pov_count(&self, device_id: u32) -> i32;
    fn continuous_pov_count(&self, device_id: u32) -> i32;
    fn has_force_feedback(&self, device_id: u32) -> bool;
    fn axis_range(&self, device_id: u32, axis_id: u32) -> Result<(i32, i32), Error>;
    fn update_device_data(&self, device_id: u32, data: &mut JOYSTICK_POSITION)
    -> Result<(), Error>;
}

struct NativeDeviceSdk {
    ffi: vjoy_sys::vJoyInterface,
}

impl NativeDeviceSdk {
    fn load(path: &str) -> Result<Self, Error> {
        let library = unsafe { Library::new(path) }
            .map_err(|_| Error::Ffi(FFIError::DynamicLybraryNotFound(path.to_string())))?;
        validate_required_exports(|name| {
            let mut symbol = name.as_bytes().to_vec();
            symbol.push(0);
            unsafe { library.get::<*const ()>(&symbol).is_ok() }
        })?;
        let ffi = unsafe { vjoy_sys::vJoyInterface::from_library(library) }
            .map_err(|_| Error::Ffi(FFIError::DynamicLybraryNotFound(path.to_string())))?;
        Ok(Self { ffi })
    }
}

fn validate_required_exports(mut has_export: impl FnMut(&str) -> bool) -> Result<(), Error> {
    for name in REQUIRED_DLL_EXPORTS {
        if !has_export(name) {
            return Err(Error::Ffi(FFIError::RequiredExportMissing(name)));
        }
    }
    Ok(())
}

impl DeviceSdk for NativeDeviceSdk {
    fn is_enabled(&self) -> bool {
        unsafe { self.ffi.vJoyEnabled() != 0 }
    }

    fn device_status(&self, device_id: u32) -> VjdStat {
        unsafe { self.ffi.GetVJDStatus(device_id) }
    }

    fn acquire_device(&self, device_id: u32) -> Result<(), Error> {
        unsafe {
            let result = self.ffi.AcquireVJD(device_id);
            if result == 1 {
                trace!("Acquired device {}", device_id);
                Ok(())
            } else {
                Err(Error::Ffi(FFIError::DeviceCouldNotBeAcquired(
                    device_id, result,
                )))
            }
        }
    }

    fn relinquish_device(&self, device_id: u32) {
        unsafe { self.ffi.RelinquishVJD(device_id) };
    }

    fn button_count(&self, device_id: u32) -> i32 {
        unsafe { self.ffi.GetVJDButtonNumber(device_id) }
    }

    fn axis_exists(&self, device_id: u32, hid_usage: u32) -> bool {
        unsafe { self.ffi.GetVJDAxisExist(device_id, hid_usage) == 1 }
    }

    fn discrete_pov_count(&self, device_id: u32) -> i32 {
        unsafe { self.ffi.GetVJDDiscPovNumber(device_id) }
    }

    fn continuous_pov_count(&self, device_id: u32) -> i32 {
        unsafe { self.ffi.GetVJDContPovNumber(device_id) }
    }

    fn has_force_feedback(&self, device_id: u32) -> bool {
        // The native API returns FALSE both for "no FFB" and for some failures.
        unsafe { self.ffi.IsDeviceFfb(device_id) != 0 }
    }

    fn axis_range(&self, device_id: u32, axis_id: u32) -> Result<(i32, i32), Error> {
        let usage = *AXES_HID_USAGE
            .get((axis_id - 1) as usize)
            .ok_or(Error::App(AppError::AxisNotFound(device_id, axis_id)))?;
        let (mut min, mut max) = (0, 0);
        let success = unsafe {
            self.ffi.GetVJDAxisMin(device_id, usage, &mut min) != 0
                && self.ffi.GetVJDAxisMax(device_id, usage, &mut max) != 0
        };
        if success {
            Ok((min, max))
        } else {
            Err(Error::Ffi(FFIError::AxisRangeCouldNotBeRead(
                device_id, axis_id,
            )))
        }
    }

    fn update_device_data(
        &self,
        device_id: u32,
        data: &mut JOYSTICK_POSITION,
    ) -> Result<(), Error> {
        let result = unsafe {
            self.ffi
                .UpdateVJD(device_id, data as *mut JOYSTICK_POSITION)
        };
        if result == 1 {
            Ok(())
        } else {
            Err(Error::Ffi(FFIError::DeviceDataCouldNotBeUpdated(
                device_id,
                self.device_status(device_id),
            )))
        }
    }
}

fn inspect_device(sdk: &dyn DeviceSdk, device_id: u32) -> Result<Device, Error> {
    validate_device_id(device_id)?;

    let button_count = sdk.button_count(device_id);
    if button_count < 0 {
        return Err(Error::Ffi(FFIError::DeviceConfigurationQueryFailed(
            device_id,
            "GetVJDButtonNumber",
            button_count,
        )));
    }
    if button_count != 32 {
        return Err(incompatible_device(
            device_id,
            format!("device must have exactly 32 buttons (has {button_count})"),
        ));
    }
    let buttons = (1..=button_count as u32)
        .map(|button_id| Button {
            id: button_id as u8,
            state: ButtonState::Released,
        })
        .collect();

    let mut axes = Vec::with_capacity(REQUIRED_HID_AXES.len());
    for (index, hid_usage) in REQUIRED_HID_AXES.into_iter().enumerate() {
        if !sdk.axis_exists(device_id, hid_usage) {
            return Err(incompatible_device(
                device_id,
                format!("required axis HID usage 0x{hid_usage:02X} is missing"),
            ));
        }
        let axis_id = index as u32 + 1;
        let axis_index = (axis_id - 1) as usize;
        let (min, max) = sdk.axis_range(device_id, axis_id)?;
        if min > max {
            return Err(incompatible_device(
                device_id,
                format!("axis HID usage 0x{hid_usage:02X} has an inverted range"),
            ));
        }
        let center = (i64::from(min) + (i64::from(max) - i64::from(min)) / 2) as i32;
        axes.push(Axis {
            display_name: AXES_DISPLAY_NAMES[axis_index].to_string(),
            hid_usage,
            id: axis_id,
            value: center,
        });
    }
    for hid_usage in UNSUPPORTED_EXTRA_HID_AXES {
        if sdk.axis_exists(device_id, hid_usage) {
            return Err(incompatible_device(
                device_id,
                format!("unsupported extra axis HID usage 0x{hid_usage:02X} is enabled"),
            ));
        }
    }

    let discrete_count = sdk.discrete_pov_count(device_id);
    if discrete_count < 0 {
        return Err(Error::Ffi(FFIError::DeviceConfigurationQueryFailed(
            device_id,
            "GetVJDDiscPovNumber",
            discrete_count,
        )));
    }
    let continuous_count = sdk.continuous_pov_count(device_id);
    if continuous_count < 0 {
        return Err(Error::Ffi(FFIError::DeviceConfigurationQueryFailed(
            device_id,
            "GetVJDContPovNumber",
            continuous_count,
        )));
    }
    if discrete_count != 0 || continuous_count != 0 {
        return Err(incompatible_device(
            device_id,
            format!(
                "POV hats are unsupported (discrete {discrete_count}, continuous {continuous_count})"
            ),
        ));
    }
    if sdk.has_force_feedback(device_id) {
        return Err(incompatible_device(
            device_id,
            "force feedback is enabled".into(),
        ));
    }

    Ok(Device {
        id: device_id,
        buttons,
        axes,
        hats: Vec::new(),
    })
}

fn incompatible_device(device_id: u32, reason: String) -> Error {
    Error::App(AppError::DeviceConfigurationIncompatible(device_id, reason))
}

fn fetch_device(sdk: &dyn DeviceSdk, device_id: u32) -> Result<Device, Error> {
    let before = inspect_device(sdk, device_id)?;
    sdk.acquire_device(device_id)?;

    match inspect_device(sdk, device_id) {
        Ok(after) => Ok(after),
        Err(error) => {
            // The descriptor changed after the pre-acquisition check. Attempt
            // to neutralize using the last verified ranges, then always release.
            let mut neutral = position_for_device(&before);
            let _ = sdk.update_device_data(device_id, &mut neutral);
            sdk.relinquish_device(device_id);
            Err(error)
        }
    }
}

fn position_for_device(device: &Device) -> JOYSTICK_POSITION {
    let mut axis_data = [0; 16];
    for axis in &device.axes {
        if (1..=8).contains(&axis.id) {
            axis_data[(axis.id - 1) as usize] = axis.get();
        }
    }

    let mut button_fields = [0_i32; 4];
    for button in &device.buttons {
        if (1..=128).contains(&button.id) && button.get() == ButtonState::Pressed {
            let index = (button.id - 1) as usize;
            button_fields[index / 32] |= 1_i32 << (index % 32);
        }
    }

    let mut hats = [0_u32; 4];
    for hat in &device.hats {
        if (1..=4).contains(&hat.id) {
            hats[(hat.id - 1) as usize] = match hat.get() {
                HatState::Continuous(value) => value,
                HatState::Discrete(value) => value as u32,
            };
        }
    }

    JOYSTICK_POSITION {
        bDevice: device.id as u8,
        wAxisX: axis_data[0],
        wAxisY: axis_data[1],
        wAxisZ: axis_data[2],
        wAxisXRot: axis_data[3],
        wAxisYRot: axis_data[4],
        wAxisZRot: axis_data[5],
        // vJoy HID usage 0x36 is Slider and 0x37 is Dial/Slider2.
        wSlider: axis_data[6],
        wDial: axis_data[7],
        wWheel: axis_data[8],
        wAccelerator: axis_data[9],
        wBrake: axis_data[10],
        wClutch: axis_data[11],
        wSteering: axis_data[12],
        wAileron: axis_data[13],
        wRudder: axis_data[14],
        wThrottle: axis_data[15],
        wAxisVX: 0,
        wAxisVY: 0,
        wAxisVZ: 0,
        wAxisVBRX: 0,
        wAxisVBRY: 0,
        wAxisVBRZ: 0,
        lButtons: button_fields[0],
        lButtonsEx1: button_fields[1],
        lButtonsEx2: button_fields[2],
        lButtonsEx3: button_fields[3],
        bHats: hats[0],
        bHatsEx1: hats[1],
        bHatsEx2: hats[2],
        bHatsEx3: hats[3],
    }
}

impl Drop for VJoy {
    #[profiling::function]
    fn drop(&mut self) {
        for device in &self.devices {
            self.sdk.relinquish_device(device.id);
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;
    use std::collections::{HashSet, VecDeque};
    use std::rc::Rc;

    #[derive(Clone)]
    struct FakeDeviceSdk(Rc<RefCell<FakeState>>);

    struct FakeState {
        button_count: i32,
        missing_axes: HashSet<u32>,
        extra_axes: HashSet<u32>,
        extra_axis_after_acquire: Option<u32>,
        discrete_povs: i32,
        continuous_povs: i32,
        force_feedback: bool,
        acquire_status: VjdStat,
        acquire_result: bool,
        acquired: Vec<u32>,
        relinquished: Vec<u32>,
        events: Vec<String>,
        update_results: VecDeque<bool>,
        published_reports: Vec<(u32, JOYSTICK_POSITION)>,
    }

    impl Default for FakeDeviceSdk {
        fn default() -> Self {
            Self(Rc::new(RefCell::new(FakeState {
                button_count: 32,
                missing_axes: HashSet::new(),
                extra_axes: HashSet::new(),
                extra_axis_after_acquire: None,
                discrete_povs: 0,
                continuous_povs: 0,
                force_feedback: false,
                acquire_status: vjoy_sys::VjdStat_VJD_STAT_FREE,
                acquire_result: true,
                acquired: Vec::new(),
                relinquished: Vec::new(),
                events: Vec::new(),
                update_results: VecDeque::new(),
                published_reports: Vec::new(),
            })))
        }
    }

    impl DeviceSdk for FakeDeviceSdk {
        fn is_enabled(&self) -> bool {
            true
        }

        fn device_status(&self, _device_id: u32) -> VjdStat {
            self.0.borrow().acquire_status
        }

        fn acquire_device(&self, device_id: u32) -> Result<(), Error> {
            let mut state = self.0.borrow_mut();
            state.events.push(format!("acquire:{device_id}"));
            if !state.acquire_result {
                return Err(Error::Ffi(FFIError::DeviceCouldNotBeAcquired(
                    device_id,
                    vjoy_sys::VjdStat_VJD_STAT_BUSY,
                )));
            }
            state.acquired.push(device_id);
            Ok(())
        }

        fn relinquish_device(&self, device_id: u32) {
            let mut state = self.0.borrow_mut();
            state.events.push(format!("relinquish:{device_id}"));
            state.relinquished.push(device_id);
        }

        fn button_count(&self, _device_id: u32) -> i32 {
            self.0.borrow().button_count
        }

        fn axis_exists(&self, device_id: u32, hid_usage: u32) -> bool {
            let state = self.0.borrow();
            let acquired = state.acquired.contains(&device_id);
            if state.missing_axes.contains(&hid_usage) {
                return false;
            }
            if state.extra_axes.contains(&hid_usage)
                || (acquired && state.extra_axis_after_acquire == Some(hid_usage))
            {
                return true;
            }
            REQUIRED_HID_AXES.contains(&hid_usage)
        }

        fn discrete_pov_count(&self, _device_id: u32) -> i32 {
            self.0.borrow().discrete_povs
        }

        fn continuous_pov_count(&self, _device_id: u32) -> i32 {
            self.0.borrow().continuous_povs
        }

        fn has_force_feedback(&self, _device_id: u32) -> bool {
            self.0.borrow().force_feedback
        }

        fn axis_range(&self, _device_id: u32, _axis_id: u32) -> Result<(i32, i32), Error> {
            Ok((0, 32_767))
        }

        fn update_device_data(
            &self,
            device_id: u32,
            data: &mut JOYSTICK_POSITION,
        ) -> Result<(), Error> {
            let mut state = self.0.borrow_mut();
            state.events.push(format!("update:{device_id}"));
            if !state.update_results.pop_front().unwrap_or(true) {
                return Err(Error::Ffi(FFIError::DeviceDataCouldNotBeUpdated(
                    device_id,
                    state.acquire_status,
                )));
            }
            state.published_reports.push((device_id, *data));
            Ok(())
        }
    }

    fn fake_vjoy() -> (VJoy, FakeDeviceSdk) {
        let sdk = FakeDeviceSdk::default();
        (VJoy::with_sdk(Box::new(sdk.clone())), sdk)
    }

    #[test]
    fn public_sparse_device_api_acquires_updates_and_relinquishes_only_selected_ids() {
        let (mut vjoy, sdk) = fake_vjoy();
        vjoy.acquire_device(9).unwrap();
        vjoy.acquire_device(16).unwrap();
        assert_eq!(vjoy.get_device_state(9).unwrap().id(), 9);
        assert_eq!(vjoy.get_device_state(16).unwrap().id(), 16);

        let mut update = vjoy.get_device_state(16).unwrap();
        update.set_button(32, ButtonState::Pressed).unwrap();
        vjoy.update_device_state(&update).unwrap();
        assert_eq!(sdk.0.borrow().published_reports.last().unwrap().0, 16);

        vjoy.relinquish_device(9);
        assert!(matches!(
            vjoy.get_device_state(9),
            Err(Error::App(AppError::DeviceNotFound(9)))
        ));
        assert_eq!(vjoy.get_device_state(16).unwrap().id(), 16);
        assert_eq!(sdk.0.borrow().relinquished, [9]);
    }

    #[test]
    fn incompatible_descriptor_is_rejected_before_any_acquire() {
        for usage in UNSUPPORTED_EXTRA_HID_AXES {
            let (mut vjoy, sdk) = fake_vjoy();
            sdk.0.borrow_mut().extra_axes.insert(usage);
            assert!(matches!(
                vjoy.acquire_device(9),
                Err(Error::App(AppError::DeviceConfigurationIncompatible(9, _)))
            ));
            assert!(sdk.0.borrow().acquired.is_empty(), "usage {usage:#x}");
            assert!(sdk.0.borrow().published_reports.is_empty());
        }
    }

    #[test]
    fn other_incompatible_capabilities_are_rejected_before_acquire() {
        let configurations: [fn(&mut FakeState); 5] = [
            |state| state.button_count = 31,
            |state| {
                state.missing_axes.insert(REQUIRED_HID_AXES[3]);
            },
            |state| state.discrete_povs = 1,
            |state| state.continuous_povs = 1,
            |state| state.force_feedback = true,
        ];
        for configure in configurations {
            let (mut vjoy, sdk) = fake_vjoy();
            configure(&mut sdk.0.borrow_mut());
            assert!(vjoy.acquire_device(12).is_err());
            assert!(sdk.0.borrow().acquired.is_empty());
        }
    }

    #[test]
    fn signed_pov_query_failures_remain_errors_and_do_not_acquire() {
        for (discrete, continuous, operation) in [
            (-1, 0, "GetVJDDiscPovNumber"),
            (0, -2, "GetVJDContPovNumber"),
        ] {
            let (mut vjoy, sdk) = fake_vjoy();
            sdk.0.borrow_mut().discrete_povs = discrete;
            sdk.0.borrow_mut().continuous_povs = continuous;
            assert!(matches!(
                vjoy.acquire_device(5),
                Err(Error::Ffi(FFIError::DeviceConfigurationQueryFailed(
                    5,
                    error_operation,
                    count
                ))) if error_operation == operation && count < 0
            ));
            assert!(sdk.0.borrow().acquired.is_empty());
        }
    }

    #[test]
    fn descriptor_is_rechecked_after_acquire_and_released_if_it_changed() {
        let (mut vjoy, sdk) = fake_vjoy();
        sdk.0.borrow_mut().extra_axis_after_acquire = Some(0x38);

        assert!(matches!(
            vjoy.acquire_device(9),
            Err(Error::App(AppError::DeviceConfigurationIncompatible(9, _)))
        ));
        assert_eq!(sdk.0.borrow().acquired, [9]);
        assert_eq!(sdk.0.borrow().relinquished, [9]);
        assert_eq!(
            sdk.0.borrow().events,
            ["acquire:9", "update:9", "relinquish:9"]
        );
        assert!(vjoy.devices().next().is_none());
    }

    #[test]
    fn acquire_race_does_not_cache_or_relinquish_a_device_owned_elsewhere() {
        let (mut vjoy, sdk) = fake_vjoy();
        sdk.0.borrow_mut().acquire_result = false;

        assert!(matches!(
            vjoy.acquire_device(16),
            Err(Error::Ffi(FFIError::DeviceCouldNotBeAcquired(16, _)))
        ));
        assert!(vjoy.devices().next().is_none());
        assert_eq!(sdk.0.borrow().relinquished, []);
        assert_eq!(sdk.0.borrow().events.last().unwrap(), "acquire:16");
    }

    #[test]
    fn failed_update_does_not_publish_cached_state_and_retry_can_succeed() {
        let (mut vjoy, sdk) = fake_vjoy();
        vjoy.acquire_device(9).unwrap();
        let mut desired = vjoy.get_device_state(9).unwrap();
        desired.set_button(32, ButtonState::Pressed).unwrap();
        sdk.0.borrow_mut().update_results.extend([false, true]);

        assert!(vjoy.update_device_state(&desired).is_err());
        assert_eq!(
            vjoy.get_device_state(9)
                .unwrap()
                .buttons()
                .last()
                .unwrap()
                .get(),
            ButtonState::Released
        );
        vjoy.update_device_state(&desired).unwrap();
        assert_eq!(
            vjoy.get_device_state(9)
                .unwrap()
                .buttons()
                .last()
                .unwrap()
                .get(),
            ButtonState::Pressed
        );
    }

    #[test]
    fn report_keeps_all_buttons_slider_slots_and_unused_fields_correct() {
        let (mut vjoy, _) = fake_vjoy();
        vjoy.acquire_device(16).unwrap();
        let mut device = vjoy.get_device_state(16).unwrap();
        for button in 1..=32 {
            device.set_button(button, ButtonState::Pressed).unwrap();
        }
        for axis in device.axes_mut() {
            axis.set(axis.id as i32 * 100);
        }

        let report = position_for_device(&device);
        assert_eq!(report.bDevice, 16);
        assert_eq!(report.wSlider, 700);
        assert_eq!(report.wDial, 800);
        assert_eq!(report.lButtons, -1);
        assert_eq!(report.lButtonsEx1, 0);
        assert_eq!(report.lButtonsEx2, 0);
        assert_eq!(report.lButtonsEx3, 0);
        assert_eq!(report.wWheel, 0);
        assert_eq!(report.wAccelerator, 0);
        assert_eq!(report.wBrake, 0);
        assert_eq!(report.wClutch, 0);
        assert_eq!(report.wSteering, 0);
        assert_eq!(report.wAileron, 0);
        assert_eq!(report.wRudder, 0);
        assert_eq!(report.wThrottle, 0);
        assert_eq!(report.wAxisVX, 0);
        assert_eq!(report.wAxisVY, 0);
        assert_eq!(report.wAxisVZ, 0);
        assert_eq!(report.wAxisVBRX, 0);
        assert_eq!(report.wAxisVBRY, 0);
        assert_eq!(report.wAxisVBRZ, 0);
        assert_eq!(report.bHats, 0);
        assert_eq!(report.bHatsEx1, 0);
        assert_eq!(report.bHatsEx2, 0);
        assert_eq!(report.bHatsEx3, 0);
    }

    #[test]
    fn missing_early_and_late_required_exports_fail_with_the_export_name() {
        for missing in ["vJoyEnabled", "UpdateVJD", "IsDeviceFfb"] {
            let exports: HashSet<&str> = REQUIRED_DLL_EXPORTS
                .iter()
                .copied()
                .filter(|name| *name != missing)
                .collect();
            assert!(matches!(
                validate_required_exports(|name| exports.contains(name)),
                Err(Error::Ffi(FFIError::RequiredExportMissing(name))) if name == missing
            ));
        }
    }

    #[test]
    fn complete_fake_export_table_passes_preflight() {
        let exports: HashSet<&str> = REQUIRED_DLL_EXPORTS.into_iter().collect();
        assert!(validate_required_exports(|name| exports.contains(name)).is_ok());
    }

    #[test]
    fn invalid_selected_id_is_rejected_before_library_load() {
        assert!(matches!(
            VJoy::from_dll_location_for_device("missing.dll", 17),
            Err(Error::App(AppError::DeviceNotFound(17)))
        ));
    }
}
