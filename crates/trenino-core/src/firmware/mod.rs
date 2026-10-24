//! Firmware metadata rules shared by the runtime and presentation layers.
mod compatibility;
mod manifest;

pub use compatibility::{FirmwareRequirement, FirmwareVersion, RequirementError};
pub use manifest::{FirmwareManifest, ManifestDevice, ManifestError, Programmer, UploadConfig};
