//! Firmware catalog, safe cache downloads, and update scheduling.
mod catalog;
mod downloads;
mod repository;
mod updates;

pub use catalog::{
    CatalogError, CatalogRelease, FirmwareAsset, FirmwareCatalog, FirmwareDevice,
    FirmwareSelection, ReleaseInput,
};
pub use downloads::{DownloadError, FirmwareDownloader};
pub use repository::{FirmwareRepository, RepositoryError};
pub use updates::{
    CheckOutcome, CheckStatus, ConnectedFirmware, FirmwareUpdateScheduler, SchedulerConfig,
    SchedulerTask, UpdateCheckRecord, UpdateNotice,
};
