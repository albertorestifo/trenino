use crate::axis::Axis;
use crate::button::{Button, ButtonState};
use crate::device::Device;
use crate::error::{AppError, Error, FFIError};
use crate::hat::HatState;
use crate::{FourWayHat, Hat};
use log::trace;
use vjoy_sys::{AXES_DISPLAY_NAMES, AXES_HID_USAGE, JOYSTICK_POSITION, VjdStat};

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
    ffi: vjoy_sys::vJoyInterface,
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
        unsafe { self.ffi.vJoyEnabled() != 0 }
    }

    /// Returns the current status of one device without acquiring it.
    #[profiling::function]
    pub fn device_status(&self, device_id: u32) -> Result<VJoyDeviceStatus, Error> {
        validate_device_id(device_id)?;
        Ok(match unsafe { self.ffi.GetVJDStatus(device_id) } {
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

        let sdk = NativeDeviceSdk { ffi: &self.ffi };
        self.devices.push(fetch_device(&sdk, device_id)?);
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
            unsafe { self.ffi.RelinquishVJD(device_id) };
        }
    }

    /// Reads the logical range for one axis ID (1 through 8).
    #[profiling::function]
    pub fn axis_range(&self, device_id: u32, axis_id: u32) -> Result<(i32, i32), Error> {
        validate_device_id(device_id)?;
        if !(1..=8).contains(&axis_id) {
            return Err(Error::App(AppError::AxisNotFound(device_id, axis_id)));
        }

        let usage = AXES_HID_USAGE[(axis_id - 1) as usize];
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

    /// Reports whether the selected device supports force feedback.
    #[profiling::function]
    pub fn has_force_feedback(&self, device_id: u32) -> Result<bool, Error> {
        validate_device_id(device_id)?;
        Ok(unsafe { self.ffi.IsDeviceFfb(device_id) != 0 })
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
            Self::update_device_data(&self.ffi, device.id, &mut data)?;
        }

        Ok(())
    }

    #[profiling::function]
    pub fn update_device_state(&mut self, new_device_state: &Device) -> Result<(), Error> {
        if new_device_state.id == 0 {
            return Err(Error::App(AppError::DeviceNotFound(new_device_state.id)));
        }

        let device = match self
            .devices
            .iter_mut()
            .find(|device| device.id == new_device_state.id)
        {
            Some(device) => device,
            None => return Err(Error::App(AppError::DeviceNotFound(new_device_state.id))),
        };

        *device = new_device_state.clone();
        let mut data = position_for_device(device);
        Self::update_device_data(&self.ffi, device.id, &mut data)?;

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
        unsafe {
            let Ok(ffi) = vjoy_sys::vJoyInterface::new(path) else {
                return Err(Error::Ffi(FFIError::DynamicLybraryNotFound(
                    path.to_string(),
                )));
            };

            Ok(Self {
                ffi,
                devices: Vec::new(),
            })
        }
    }

    #[profiling::function]
    fn fetch_devices(&mut self) {
        for device_id in 1..=16 {
            let _ = self.acquire_device(device_id);
        }
    }

    #[profiling::function]
    fn update_device_data(
        ffi: &vjoy_sys::vJoyInterface,
        device_id: u32,
        data: &mut JOYSTICK_POSITION,
    ) -> Result<(), Error> {
        unsafe {
            let ptr = data as *mut JOYSTICK_POSITION;
            let result = ffi.UpdateVJD(device_id, ptr);
            if result != 1 {
                let device_state = Self::get_device_ffi_status(ffi, device_id);
                return Err(Error::Ffi(FFIError::DeviceDataCouldNotBeUpdated(
                    device_id,
                    device_state,
                )));
            }
        }
        Ok(())
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
    fn acquire_device(&self, device_id: u32) -> Result<(), Error>;
    fn button_count(&self, device_id: u32) -> u32;
    fn axis_exists(&self, device_id: u32, hid_usage: u32) -> bool;
    fn discrete_pov_count(&self, device_id: u32) -> u32;
    fn continuous_pov_count(&self, device_id: u32) -> u32;
}

struct NativeDeviceSdk<'a> {
    ffi: &'a vjoy_sys::vJoyInterface,
}

impl DeviceSdk for NativeDeviceSdk<'_> {
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

    fn button_count(&self, device_id: u32) -> u32 {
        unsafe { self.ffi.GetVJDButtonNumber(device_id).max(0).min(128) as u32 }
    }

    fn axis_exists(&self, device_id: u32, hid_usage: u32) -> bool {
        unsafe { self.ffi.GetVJDAxisExist(device_id, hid_usage) == 1 }
    }

    fn discrete_pov_count(&self, device_id: u32) -> u32 {
        unsafe { self.ffi.GetVJDDiscPovNumber(device_id).max(0).min(4) as u32 }
    }

    fn continuous_pov_count(&self, device_id: u32) -> u32 {
        unsafe { self.ffi.GetVJDContPovNumber(device_id).max(0).min(4) as u32 }
    }
}

fn fetch_device(sdk: &impl DeviceSdk, device_id: u32) -> Result<Device, Error> {
    validate_device_id(device_id)?;
    sdk.acquire_device(device_id)?;

    let buttons = (1..=sdk.button_count(device_id))
        .map(|button_id| Button {
            id: button_id as u8,
            state: ButtonState::Released,
        })
        .collect();
    let axes = (1..=8)
        .filter_map(|axis_id| {
            let axis_index = (axis_id - 1) as usize;
            let display_name = AXES_DISPLAY_NAMES[axis_index].to_string();
            let hid_usage = AXES_HID_USAGE[axis_index];
            sdk.axis_exists(device_id, hid_usage).then_some(Axis {
                display_name,
                hid_usage,
                id: axis_id,
                value: 0,
            })
        })
        .collect();

    let discrete_count = sdk.discrete_pov_count(device_id);
    let continuous_count = sdk.continuous_pov_count(device_id);
    let hats = if discrete_count > 0 {
        (1..=discrete_count)
            .map(|hat_id| Hat {
                id: hat_id as u8,
                state: HatState::Discrete(FourWayHat::Centered),
            })
            .collect()
    } else {
        (1..=continuous_count)
            .map(|hat_id| Hat {
                id: hat_id as u8,
                state: HatState::Continuous(u32::MAX),
            })
            .collect()
    };

    Ok(Device {
        id: device_id,
        buttons,
        axes,
        hats,
    })
}

fn position_for_device(device: &Device) -> JOYSTICK_POSITION {
    let mut axis_data = [16384; 16];
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
            unsafe { self.ffi.RelinquishVJD(device.id) };
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::cell::RefCell;

    struct FakeDeviceSdk {
        acquired: RefCell<Vec<u32>>,
    }

    impl DeviceSdk for FakeDeviceSdk {
        fn acquire_device(&self, device_id: u32) -> Result<(), Error> {
            self.acquired.borrow_mut().push(device_id);
            Ok(())
        }

        fn button_count(&self, _device_id: u32) -> u32 {
            32
        }

        fn axis_exists(&self, _device_id: u32, _hid_usage: u32) -> bool {
            true
        }

        fn discrete_pov_count(&self, _device_id: u32) -> u32 {
            0
        }

        fn continuous_pov_count(&self, _device_id: u32) -> u32 {
            0
        }
    }

    #[test]
    fn fetching_one_device_acquires_only_the_selected_id() {
        let sdk = FakeDeviceSdk {
            acquired: RefCell::default(),
        };

        let device = fetch_device(&sdk, 9).unwrap();

        assert_eq!(device.id(), 9);
        assert_eq!(sdk.acquired.borrow().as_slice(), [9]);
        assert_eq!(device.num_axes(), 8);
        assert_eq!(device.num_buttons(), 32);
    }

    #[test]
    fn invalid_selected_id_is_rejected_before_sdk_acquisition() {
        let sdk = FakeDeviceSdk {
            acquired: RefCell::default(),
        };

        assert!(matches!(
            fetch_device(&sdk, 0),
            Err(Error::App(AppError::DeviceNotFound(0)))
        ));
        assert!(matches!(
            fetch_device(&sdk, 17),
            Err(Error::App(AppError::DeviceNotFound(17)))
        ));
        assert!(sdk.acquired.borrow().is_empty());
    }

    #[test]
    fn slider_axes_keep_their_hid_report_slots() {
        let mut device = fetch_device(
            &FakeDeviceSdk {
                acquired: RefCell::default(),
            },
            9,
        )
        .unwrap();
        for axis in device.axes_mut() {
            axis.set(axis.id as i32 * 100);
        }

        let report = position_for_device(&device);

        assert_eq!(report.wSlider, 700);
        assert_eq!(report.wDial, 800);
    }

    #[test]
    fn selected_constructor_validates_id_before_loading_a_path() {
        assert!(matches!(
            VJoy::from_dll_location_for_device("missing.dll", 17),
            Err(Error::App(AppError::DeviceNotFound(17)))
        ));
    }
}
