//! vJoy runtime manager: persisted selected-device ownership, mappings and
//! configurator lifecycle. Native vJoy access is Windows-only and cfg-gated.
//!
//! The manager owns exactly the persisted selected-device set (IDs 1 through
//! 16), never acquiring unrelated devices, and integrates activation with the
//! shared [`crate::resource::ResourceArbiter`]: a held calibration/firmware
//! lease refuses activation, and acquired devices are neutralized (axes
//! centered, buttons released) before every release, including rollback and
//! drop paths.
//!
//! Ported from the Elixir `Trenino.VirtualJoystick` context: lifecycle states
//! and persistence-only-after-confirmation semantics follow
//! `Trenino.VirtualJoystick.Manager`; mapping CRUD, validation categories and
//! ordering follow `Trenino.VirtualJoystick` and `Mapping`.

pub mod adapter;
pub mod manager;
pub mod store;

#[cfg(windows)]
pub mod windows;

pub use adapter::{
    neutral_axis_value, AdapterEvent, DeviceDescriptor, FakeDevice, FakeVjoyAdapter, VjoyAdapter,
    VjoyDeviceStatus, VjoyError, REQUIRED_DESCRIPTOR,
};
pub use manager::{VjoyManager, VjoyStatus};
pub use store::{
    MappingDraft, MappingRecord, Target, VjoyAxis, VjoyConfiguration, VjoyStoreError, MAX_BUTTON,
    MAX_DEVICE_INDEX, MIN_DEVICE_INDEX,
};
