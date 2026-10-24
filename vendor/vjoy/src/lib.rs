#![doc = include_str!("../README.md")]

mod vjoy;
pub use crate::vjoy::VJoy;
pub use crate::vjoy::VJoyDeviceStatus;

mod error;
pub use error::*;

mod device;
pub use device::Device;

mod axis;
pub use axis::Axis;

mod hat;
pub use hat::{FourWayHat, Hat, HatState};

mod button;
pub use button::{Button, ButtonState};
