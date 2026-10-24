//! Firmware catalog, safe cache downloads, and update scheduling.
mod catalog;
mod downloads;
mod http;
mod repository;
mod updates;

pub use catalog::{
    CatalogError, CatalogRelease, FirmwareAsset, FirmwareCatalog, FirmwareDevice,
    FirmwareSelection, ReleaseInput,
};
pub use downloads::{
    CacheProvenance, DownloadError, DownloadResult, FirmwareDownloader, LegacyCachePolicy,
};
pub use http::{FirmwareHttpClient, HttpUrlError};
pub use repository::{FirmwareRepository, RepositoryError};
pub use updates::{
    CheckOutcome, CheckStatus, ConnectedFirmware, FirmwareUpdateScheduler, SchedulerConfig,
    SchedulerTask, UpdateCheckRecord, UpdateNotice,
};
