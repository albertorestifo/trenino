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
            axes: [(i64::from(range.min) + (i64::from(range.max) - i64::from(range.min)) / 2)
                as i32; 8],
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
    pub fn load(_interface_path: &std::path::Path) -> Result<Self, VJoyError> {
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
    pub struct NativeVJoy {
        backend: vjoy::VJoy,
    }
    impl NativeVJoy {
        pub fn load(interface_path: &std::path::Path) -> Result<Self, VJoyError> {
            let expected_name = interface_path
                .file_name()
                .and_then(|name| name.to_str())
                .is_some_and(|name| name.eq_ignore_ascii_case("vJoyInterface.dll"));
            if !interface_path.is_absolute() || !expected_name {
                return Err(VJoyError::Sdk {
                    operation: "load",
                    message: "vJoy interface must be an absolute path to vJoyInterface.dll".into(),
                });
            }
            let path = interface_path.to_str().ok_or_else(|| VJoyError::Sdk {
                operation: "load",
                message: "vJoy interface path is not valid UTF-8".into(),
            })?;
            let backend = vjoy::VJoy::from_dll_location_without_acquiring(path)
                .map_err(|error| sdk_error("load", error))?;
            Ok(Self { backend })
        }
    }

    fn axis_id(axis: Axis) -> u32 {
        match axis {
            Axis::X => 1,
            Axis::Y => 2,
            Axis::Z => 3,
            Axis::Rx => 4,
            Axis::Ry => 5,
            Axis::Rz => 6,
            Axis::Slider1 => 7,
            Axis::Slider2 => 8,
        }
    }

    fn sdk_error(operation: &'static str, error: impl std::fmt::Display) -> VJoyError {
        VJoyError::Sdk {
            operation,
            message: error.to_string(),
        }
    }

    fn error_for_device(
        backend: &vjoy::VJoy,
        device: u8,
        operation: &'static str,
        error: impl std::fmt::Display,
    ) -> VJoyError {
        if matches!(
            backend.device_status(device as u32),
            Ok(vjoy::VJoyDeviceStatus::Missing)
        ) {
            VJoyError::DeviceRemoved
        } else {
            sdk_error(operation, error)
        }
    }

    impl VJoy for NativeVJoy {
        fn enabled(&mut self) -> Result<bool, VJoyError> {
            Ok(self.backend.is_enabled())
        }
        fn status(&mut self, device: u8) -> Result<DeviceStatus, VJoyError> {
            Ok(
                match self
                    .backend
                    .device_status(device as u32)
                    .map_err(|error| sdk_error("GetVJDStatus", error))?
                {
                    vjoy::VJoyDeviceStatus::Owned => DeviceStatus::Owned,
                    vjoy::VJoyDeviceStatus::Free => DeviceStatus::Free,
                    vjoy::VJoyDeviceStatus::Busy => DeviceStatus::Busy,
                    vjoy::VJoyDeviceStatus::Missing => DeviceStatus::Missing,
                    vjoy::VJoyDeviceStatus::Unknown => {
                        return Err(VJoyError::Sdk {
                            operation: "GetVJDStatus",
                            message: format!("device {device} has unknown status"),
                        });
                    }
                },
            )
        }
        fn acquire(&mut self, device: u8) -> Result<(), VJoyError> {
            self.backend
                .acquire_device(device as u32)
                .map_err(|error| error_for_device(&self.backend, device, "AcquireVJD", error))?;

            let state = match self.backend.get_device_state(device as u32) {
                Ok(state) => state,
                Err(error) => {
                    let mapped =
                        error_for_device(&self.backend, device, "device_configuration", error);
                    self.backend.relinquish_device(device as u32);
                    return Err(mapped);
                }
            };
            let capability_error = if state.num_axes() != 8 {
                Some(format!(
                    "device {device} must have exactly 8 axes (has {})",
                    state.num_axes()
                ))
            } else if state.num_buttons() != 32 {
                Some(format!(
                    "device {device} must have exactly 32 buttons (has {})",
                    state.num_buttons()
                ))
            } else if state.num_hats() != 0 {
                Some(format!(
                    "device {device} must not have POV hats (has {})",
                    state.num_hats()
                ))
            } else {
                None
            };
            if let Some(message) = capability_error {
                self.backend.relinquish_device(device as u32);
                return Err(VJoyError::Sdk {
                    operation: "device_configuration",
                    message,
                });
            }
            let has_force_feedback = match self.backend.has_force_feedback(device as u32) {
                Ok(has_force_feedback) => has_force_feedback,
                Err(error) => {
                    let mapped = error_for_device(&self.backend, device, "IsDeviceFfb", error);
                    self.backend.relinquish_device(device as u32);
                    return Err(mapped);
                }
            };
            if has_force_feedback {
                self.backend.relinquish_device(device as u32);
                return Err(VJoyError::Sdk {
                    operation: "device_configuration",
                    message: format!("device {device} must not have force feedback enabled"),
                });
            }
            Ok(())
        }
        fn axis_range(&mut self, device: u8, axis: Axis) -> Result<AxisRange, VJoyError> {
            let (min, max) = self
                .backend
                .axis_range(device as u32, axis_id(axis))
                .map_err(|error| {
                    error_for_device(&self.backend, device, "GetVJDAxisMin/GetVJDAxisMax", error)
                })?;
            Ok(AxisRange { min, max })
        }
        fn update(&mut self, device: u8, report: &Report) -> Result<(), VJoyError> {
            let mut state = self
                .backend
                .get_device_state(device as u32)
                .map_err(|error| error_for_device(&self.backend, device, "UpdateVJD", error))?;
            for axis in Axis::ALL {
                state
                    .set_axis(axis_id(axis), report.axis(axis))
                    .map_err(|error| sdk_error("UpdateVJD", error))?;
            }
            for button in 1..=32 {
                state
                    .set_button(
                        button,
                        if report.button(button) {
                            vjoy::ButtonState::Pressed
                        } else {
                            vjoy::ButtonState::Released
                        },
                    )
                    .map_err(|error| sdk_error("UpdateVJD", error))?;
            }
            self.backend
                .update_device_state(&state)
                .map_err(|error| error_for_device(&self.backend, device, "UpdateVJD", error))
        }
        fn relinquish(&mut self, device: u8) {
            self.backend.relinquish_device(device as u32);
        }
    }

    #[cfg(test)]
    mod tests {
        use super::*;

        #[test]
        fn protocol_axes_use_the_vjoy_axis_ids_without_reordering() {
            assert_eq!(Axis::ALL.map(axis_id), [1, 2, 3, 4, 5, 6, 7, 8]);
        }
    }
}
#[cfg(windows)]
pub use windows::NativeVJoy;
