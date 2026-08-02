use crate::protocol::Axis;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct AxisRange {
    pub min: i32,
    pub max: i32,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Report {
    axes: [i32; 8],
    buttons: [bool; 32],
}
impl Report {
    pub fn centered(range: AxisRange) -> Self {
        Self {
            axes: [range.min + (range.max - range.min) / 2; 8],
            buttons: [false; 32],
        }
    }
    pub fn axis(&self, axis: Axis) -> i32 {
        self.axes[axis_index(axis)]
    }
    pub fn set_axis(&mut self, axis: Axis, value: i32) {
        self.axes[axis_index(axis)] = value;
    }
    pub fn button(&self, button: u8) -> bool {
        self.buttons[(button - 1) as usize]
    }
    pub fn set_button(&mut self, button: u8, pressed: bool) {
        self.buttons[(button - 1) as usize] = pressed;
    }
    pub fn reset(&mut self, range: AxisRange) {
        *self = Self::centered(range);
    }
}
fn axis_index(axis: Axis) -> usize {
    match axis {
        Axis::X => 0,
        Axis::Y => 1,
        Axis::Z => 2,
        Axis::Rx => 3,
        Axis::Ry => 4,
        Axis::Rz => 5,
        Axis::Slider1 => 6,
        Axis::Slider2 => 7,
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum DeviceStatus {
    Free,
    Owned,
    Busy,
    Missing,
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum VJoyError {
    UnsupportedPlatform,
    DeviceRemoved,
    Sdk {
        operation: &'static str,
        message: String,
    },
}
pub trait VJoy {
    fn enabled(&mut self) -> Result<bool, VJoyError>;
    fn status(&mut self, device: u8) -> Result<DeviceStatus, VJoyError>;
    fn acquire(&mut self, device: u8) -> Result<(), VJoyError>;
    fn axis_range(&mut self, device: u8, axis: Axis) -> Result<AxisRange, VJoyError>;
    fn update(&mut self, device: u8, report: &Report) -> Result<(), VJoyError>;
    fn relinquish(&mut self, device: u8);
}

#[cfg(not(windows))]
pub struct NativeVJoy;
#[cfg(not(windows))]
impl NativeVJoy {
    pub fn load() -> Result<Self, VJoyError> {
        Ok(Self)
    }
}
#[cfg(not(windows))]
impl VJoy for NativeVJoy {
    fn enabled(&mut self) -> Result<bool, VJoyError> {
        Err(VJoyError::UnsupportedPlatform)
    }
    fn status(&mut self, _: u8) -> Result<DeviceStatus, VJoyError> {
        Err(VJoyError::UnsupportedPlatform)
    }
    fn acquire(&mut self, _: u8) -> Result<(), VJoyError> {
        Err(VJoyError::UnsupportedPlatform)
    }
    fn axis_range(&mut self, _: u8, _: Axis) -> Result<AxisRange, VJoyError> {
        Err(VJoyError::UnsupportedPlatform)
    }
    fn update(&mut self, _: u8, _: &Report) -> Result<(), VJoyError> {
        Err(VJoyError::UnsupportedPlatform)
    }
    fn relinquish(&mut self, _: u8) {}
}

#[cfg(windows)]
mod windows {
    use super::*;
    use libloading::Library;
    use std::path::Path;
    #[repr(C)]
    struct JoystickPositionV2 {
        b_device: u8,
        w_throttle: i32,
        w_rudder: i32,
        w_aileron: i32,
        w_axis_x: i32,
        w_axis_y: i32,
        w_axis_z: i32,
        w_axis_x_rot: i32,
        w_axis_y_rot: i32,
        w_axis_z_rot: i32,
        w_slider: i32,
        w_dial: i32,
        w_wheel: i32,
        w_axis_vx: i32,
        w_axis_vy: i32,
        w_axis_vz: i32,
        w_axis_vbrx: i32,
        w_axis_vbry: i32,
        w_axis_vbrz: i32,
        buttons: i32,
        b_hats: u32,
        b_hats_ex1: u32,
        b_hats_ex2: u32,
        b_hats_ex3: u32,
        l_buttons_ex1: i32,
        l_buttons_ex2: i32,
        l_buttons_ex3: i32,
    }
    type Enabled = unsafe extern "C" fn() -> i32;
    type Status = unsafe extern "C" fn(u32) -> i32;
    type Acquire = unsafe extern "C" fn(u32) -> i32;
    type Relinquish = unsafe extern "C" fn(u32);
    type AxisRangeFn = unsafe extern "C" fn(u32, u32, *mut i32) -> i32;
    type Update = unsafe extern "C" fn(u32, *const JoystickPositionV2) -> i32;

    const _: () = assert!(std::mem::size_of::<JoystickPositionV2>() == 108);
    const _: () = assert!(std::mem::offset_of!(JoystickPositionV2, w_axis_x) == 16);
    const _: () = assert!(std::mem::offset_of!(JoystickPositionV2, w_wheel) == 48);
    const _: () = assert!(std::mem::offset_of!(JoystickPositionV2, buttons) == 76);
    const _: () = assert!(std::mem::offset_of!(JoystickPositionV2, l_buttons_ex1) == 96);
    pub struct NativeVJoy {
        _library: Library,
        enabled_fn: Enabled,
        status_fn: Status,
        acquire_fn: Acquire,
        relinquish_fn: Relinquish,
        min_fn: AxisRangeFn,
        max_fn: AxisRangeFn,
        update_fn: Update,
    }
    impl NativeVJoy {
        pub fn load() -> Result<Self, VJoyError> {
            unsafe {
                let library =
                    Library::new(Path::new("vJoyInterface.dll")).map_err(|e| err("load", e))?;
                let enabled_fn = symbol(&library, b"vJoyEnabled\0", "vJoyEnabled")?;
                let status_fn = symbol(&library, b"GetVJDStatus\0", "GetVJDStatus")?;
                let acquire_fn = symbol(&library, b"AcquireVJD\0", "AcquireVJD")?;
                let relinquish_fn = symbol(&library, b"RelinquishVJD\0", "RelinquishVJD")?;
                let min_fn = symbol(&library, b"GetVJDAxisMin\0", "GetVJDAxisMin")?;
                let max_fn = symbol(&library, b"GetVJDAxisMax\0", "GetVJDAxisMax")?;
                let update_fn = symbol(&library, b"UpdateVJD\0", "UpdateVJD")?;
                Ok(Self {
                    _library: library,
                    enabled_fn,
                    status_fn,
                    acquire_fn,
                    relinquish_fn,
                    min_fn,
                    max_fn,
                    update_fn,
                })
            }
        }
    }
    unsafe fn symbol<T: Copy>(
        library: &Library,
        name: &[u8],
        operation: &'static str,
    ) -> Result<T, VJoyError> {
        Ok(*library.get::<T>(name).map_err(|e| err(operation, e))?)
    }
    fn err(operation: &'static str, error: impl std::fmt::Display) -> VJoyError {
        VJoyError::Sdk {
            operation,
            message: error.to_string(),
        }
    }
    fn usage(axis: Axis) -> u32 {
        match axis {
            Axis::X => 0x30,
            Axis::Y => 0x31,
            Axis::Z => 0x32,
            Axis::Rx => 0x33,
            Axis::Ry => 0x34,
            Axis::Rz => 0x35,
            Axis::Slider1 => 0x36,
            Axis::Slider2 => 0x37,
        }
    }
    impl VJoy for NativeVJoy {
        fn enabled(&mut self) -> Result<bool, VJoyError> {
            Ok(unsafe { (self.enabled_fn)() != 0 })
        }
        fn status(&mut self, device: u8) -> Result<DeviceStatus, VJoyError> {
            Ok(match unsafe { (self.status_fn)(device as u32) } {
                0 => DeviceStatus::Owned,
                1 => DeviceStatus::Free,
                2 => DeviceStatus::Busy,
                _ => DeviceStatus::Missing,
            })
        }
        fn acquire(&mut self, device: u8) -> Result<(), VJoyError> {
            if unsafe { (self.acquire_fn)(device as u32) != 0 } {
                Ok(())
            } else {
                Err(err("AcquireVJD", "call returned false"))
            }
        }
        fn axis_range(&mut self, device: u8, axis: Axis) -> Result<AxisRange, VJoyError> {
            let (mut min, mut max) = (0, 0);
            if unsafe {
                (self.min_fn)(device as u32, usage(axis), &mut min) != 0
                    && (self.max_fn)(device as u32, usage(axis), &mut max) != 0
            } {
                Ok(AxisRange { min, max })
            } else {
                Err(err("GetVJDAxisMin/GetVJDAxisMax", "call returned false"))
            }
        }
        fn update(&mut self, device: u8, report: &Report) -> Result<(), VJoyError> {
            let native = JoystickPositionV2 {
                b_device: device,
                w_throttle: 0,
                w_rudder: 0,
                w_aileron: 0,
                w_axis_x: report.axis(Axis::X),
                w_axis_y: report.axis(Axis::Y),
                w_axis_z: report.axis(Axis::Z),
                w_axis_x_rot: report.axis(Axis::Rx),
                w_axis_y_rot: report.axis(Axis::Ry),
                w_axis_z_rot: report.axis(Axis::Rz),
                w_slider: report.axis(Axis::Slider1),
                w_dial: report.axis(Axis::Slider2),
                w_wheel: 0,
                w_axis_vx: 0,
                w_axis_vy: 0,
                w_axis_vz: 0,
                w_axis_vbrx: 0,
                w_axis_vbry: 0,
                w_axis_vbrz: 0,
                buttons: (1..=32).fold(0_u32, |bits, n| {
                    bits | ((report.button(n) as u32) << (n - 1))
                }) as i32,
                b_hats: 0,
                b_hats_ex1: 0,
                b_hats_ex2: 0,
                b_hats_ex3: 0,
                l_buttons_ex1: 0,
                l_buttons_ex2: 0,
                l_buttons_ex3: 0,
            };
            if unsafe { (self.update_fn)(device as u32, &native) != 0 } {
                Ok(())
            } else {
                Err(err("UpdateVJD", "call returned false"))
            }
        }
        fn relinquish(&mut self, device: u8) {
            unsafe { (self.relinquish_fn)(device as u32) }
        }
    }

    #[cfg(test)]
    mod tests {
        use super::JoystickPositionV2;

        #[test]
        fn joystick_position_v2_matches_pinned_vjoy_header_layout() {
            assert_eq!(std::mem::size_of::<JoystickPositionV2>(), 108);
            assert_eq!(std::mem::offset_of!(JoystickPositionV2, b_device), 0);
            assert_eq!(std::mem::offset_of!(JoystickPositionV2, w_axis_x), 16);
            assert_eq!(std::mem::offset_of!(JoystickPositionV2, w_wheel), 48);
            assert_eq!(std::mem::offset_of!(JoystickPositionV2, buttons), 76);
            assert_eq!(std::mem::offset_of!(JoystickPositionV2, b_hats), 80);
            assert_eq!(std::mem::offset_of!(JoystickPositionV2, l_buttons_ex1), 96);
            assert_eq!(std::mem::offset_of!(JoystickPositionV2, l_buttons_ex3), 104);
        }
    }
}
#[cfg(windows)]
pub use windows::NativeVJoy;
