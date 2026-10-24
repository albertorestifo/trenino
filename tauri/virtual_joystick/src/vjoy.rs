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
    fn neutralize(&mut self, device: u8) -> Result<(), VJoyError> {
        let mut report = Report::centered(AxisRange { min: 0, max: 0 });
        for axis in Axis::ALL {
            let range = self.axis_range(device, axis)?;
            if range.min > range.max {
                return Err(VJoyError::Sdk {
                    operation: "neutralize",
                    message: format!("axis {axis:?} has an inverted range"),
                });
            }
            let center =
                (i64::from(range.min) + (i64::from(range.max) - i64::from(range.min)) / 2) as i32;
            report.set_axis(axis, center);
        }
        self.update(device, &report)
    }
    fn relinquish(&mut self, device: u8) -> Result<(), VJoyError>;
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
    fn relinquish(&mut self, _: u8) -> Result<(), VJoyError> {
        Ok(())
    }
}

#[cfg(windows)]
mod windows {
    use super::*;
    use vjoy::VJoyDeviceStatus;

    trait NativeApi {
        fn enabled(&mut self) -> Result<bool, VJoyError>;
        fn status(&mut self, device: u8) -> Result<DeviceStatus, VJoyError>;
        fn acquire(&mut self, device: u8) -> Result<(), VJoyError>;
        fn axis_range(&mut self, device: u8, axis: u32) -> Result<AxisRange, VJoyError>;
        fn update(&mut self, device: u8, report: &Report) -> Result<(), VJoyError>;
        fn relinquish(&mut self, device: u8) -> Result<(), VJoyError>;
    }

    pub struct NativeVJoy {
        backend: Box<dyn NativeApi>,
    }

    struct CrateNativeApi(vjoy::VJoy);

    impl NativeVJoy {
        fn with_backend(backend: impl NativeApi + 'static) -> Self {
            Self {
                backend: Box::new(backend),
            }
        }
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
            Ok(Self::with_backend(CrateNativeApi(backend)))
        }
    }

    impl NativeApi for CrateNativeApi {
        fn enabled(&mut self) -> Result<bool, VJoyError> {
            Ok(self.0.is_enabled())
        }

        fn status(&mut self, device: u8) -> Result<DeviceStatus, VJoyError> {
            Ok(
                match self
                    .0
                    .device_status(device as u32)
                    .map_err(|error| sdk_error("GetVJDStatus", error))?
                {
                    VJoyDeviceStatus::Owned => DeviceStatus::Owned,
                    VJoyDeviceStatus::Free => DeviceStatus::Free,
                    VJoyDeviceStatus::Busy => DeviceStatus::Busy,
                    VJoyDeviceStatus::Missing => DeviceStatus::Missing,
                    VJoyDeviceStatus::Unknown => {
                        return Err(VJoyError::Sdk {
                            operation: "GetVJDStatus",
                            message: format!("device {device} has unknown status"),
                        });
                    }
                },
            )
        }

        fn acquire(&mut self, device: u8) -> Result<(), VJoyError> {
            self.0
                .acquire_device(device as u32)
                .map_err(|error| error_for_device(&self.0, device, "AcquireVJD", error))
        }

        fn axis_range(&mut self, device: u8, axis: u32) -> Result<AxisRange, VJoyError> {
            let (min, max) = self.0.axis_range(device as u32, axis).map_err(|error| {
                error_for_device(&self.0, device, "GetVJDAxisMin/GetVJDAxisMax", error)
            })?;
            Ok(AxisRange { min, max })
        }

        fn update(&mut self, device: u8, report: &Report) -> Result<(), VJoyError> {
            let mut state = self
                .0
                .get_device_state(device as u32)
                .map_err(|error| error_for_device(&self.0, device, "UpdateVJD", error))?;
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
            self.0
                .update_device_state(&state)
                .map_err(|error| error_for_device(&self.0, device, "UpdateVJD", error))
        }

        fn relinquish(&mut self, device: u8) -> Result<(), VJoyError> {
            // The native RelinquishVJD export returns void, so native release
            // failures cannot be detected or surfaced here.
            self.0.relinquish_device(device as u32);
            Ok(())
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
            self.backend.enabled()
        }
        fn status(&mut self, device: u8) -> Result<DeviceStatus, VJoyError> {
            self.backend.status(device)
        }
        fn acquire(&mut self, device: u8) -> Result<(), VJoyError> {
            self.backend.acquire(device)
        }
        fn axis_range(&mut self, device: u8, axis: Axis) -> Result<AxisRange, VJoyError> {
            self.backend.axis_range(device, axis_id(axis))
        }
        fn update(&mut self, device: u8, report: &Report) -> Result<(), VJoyError> {
            self.backend.update(device, report)
        }
        fn relinquish(&mut self, device: u8) -> Result<(), VJoyError> {
            self.backend.relinquish(device)
        }
    }

    #[cfg(test)]
    mod tests {
        use super::*;
        use crate::protocol::{Response, Session};
        use std::cell::RefCell;
        use std::rc::Rc;

        #[derive(Clone, Default)]
        struct FakeNativeState(Rc<RefCell<FakeNativeData>>);

        struct FakeNativeData {
            status: DeviceStatus,
            fail_acquire: bool,
            acquire_attempts: Vec<u8>,
            acquired: Vec<u8>,
            released: Vec<u8>,
            range_axes: Vec<u32>,
            reports: Vec<(u8, Report)>,
            events: Vec<&'static str>,
        }

        impl Default for FakeNativeData {
            fn default() -> Self {
                Self {
                    status: DeviceStatus::Free,
                    fail_acquire: false,
                    acquire_attempts: Vec::new(),
                    acquired: Vec::new(),
                    released: Vec::new(),
                    range_axes: Vec::new(),
                    reports: Vec::new(),
                    events: Vec::new(),
                }
            }
        }

        impl NativeApi for FakeNativeState {
            fn enabled(&mut self) -> Result<bool, VJoyError> {
                Ok(true)
            }

            fn status(&mut self, _device: u8) -> Result<DeviceStatus, VJoyError> {
                Ok(self.0.borrow().status.clone())
            }

            fn acquire(&mut self, device: u8) -> Result<(), VJoyError> {
                let mut state = self.0.borrow_mut();
                state.events.push("acquire");
                state.acquire_attempts.push(device);
                if state.fail_acquire {
                    return Err(VJoyError::Sdk {
                        operation: "AcquireVJD",
                        message: "device became busy".into(),
                    });
                }
                state.acquired.push(device);
                Ok(())
            }

            fn axis_range(&mut self, device: u8, axis: u32) -> Result<AxisRange, VJoyError> {
                let mut state = self.0.borrow_mut();
                state.range_axes.push(axis);
                state.events.push("axis_range");
                let _ = device;
                Ok(AxisRange {
                    min: -100,
                    max: 100,
                })
            }

            fn update(&mut self, device: u8, report: &Report) -> Result<(), VJoyError> {
                let mut state = self.0.borrow_mut();
                state.events.push("update");
                state.reports.push((device, report.clone()));
                Ok(())
            }

            fn relinquish(&mut self, device: u8) -> Result<(), VJoyError> {
                let mut state = self.0.borrow_mut();
                state.events.push("relinquish");
                state.released.push(device);
                Ok(())
            }
        }

        #[test]
        fn protocol_axes_use_the_vjoy_axis_ids_without_reordering() {
            assert_eq!(Axis::ALL.map(axis_id), [1, 2, 3, 4, 5, 6, 7, 8]);
        }

        #[test]
        fn protocol_session_uses_selected_sparse_device_maps_reports_and_cleans_up() {
            let fake = FakeNativeState::default();
            let state = fake.0.clone();
            let mut session = Session::new(NativeVJoy::with_backend(fake));

            assert_eq!(
                session
                    .handle_line(r#"{"command":"hello","protocol":1,"device":16}"#)
                    .response,
                Response::Ready {
                    protocol: 1,
                    device: 16,
                    axis_min: -100,
                    axis_max: 100,
                }
            );
            session.handle_line(
                r#"{"command":"set_axis","request_id":1,"device":16,"axis":"slider_1","value":70}"#,
            );
            session.handle_line(
                r#"{"command":"set_axis","request_id":2,"device":16,"axis":"slider_2","value":80}"#,
            );
            session.handle_line(
                r#"{"command":"set_button","request_id":3,"device":16,"button":32,"pressed":true}"#,
            );
            assert_eq!(
                session.handle_line(r#"{"command":"shutdown"}"#).response,
                Response::Stopped
            );

            let state = state.borrow();
            assert_eq!(state.acquire_attempts, [16]);
            assert_eq!(state.acquired, [16]);
            assert_eq!(state.released, [16]);
            assert_eq!(
                state.range_axes,
                [1, 2, 3, 4, 5, 6, 7, 8, 1, 2, 3, 4, 5, 6, 7, 8]
            );
            assert_eq!(state.reports.len(), 5);
            assert_eq!(state.reports[2].0, 16);
            assert_eq!(state.reports[2].1.axis(Axis::Slider1), 70);
            assert_eq!(state.reports[3].1.axis(Axis::Slider2), 80);
            assert!(state.reports[3].1.button(32));
            assert!(!state.reports[4].1.button(32));
            assert_eq!(state.events.last(), Some(&"relinquish"));
        }

        #[test]
        fn acquire_race_does_not_release_a_device_not_acquired_by_this_session() {
            let fake = FakeNativeState::default();
            fake.0.borrow_mut().fail_acquire = true;
            let state = fake.0.clone();
            let mut session = Session::new(NativeVJoy::with_backend(fake));

            assert!(matches!(
                session
                    .handle_line(r#"{"command":"hello","protocol":1,"device":9}"#)
                    .response,
                Response::Error {
                    code: "sdk_error",
                    ..
                }
            ));
            let state = state.borrow();
            assert_eq!(state.acquire_attempts, [9]);
            assert!(state.acquired.is_empty());
            assert!(state.released.is_empty());
            assert!(state.reports.is_empty());
        }
    }
}
#[cfg(windows)]
pub use windows::NativeVJoy;
