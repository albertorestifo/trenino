//! Firmware catalog, safe cache downloads, and update scheduling.
mod catalog;
mod downloads;
mod http;
pub mod owner;
mod repository;
mod updates;
mod upload;

pub use catalog::{
    detect_device_from_filename, CatalogError, CatalogRelease, FirmwareAsset, FirmwareCatalog,
    FirmwareDevice, FirmwareSelection, ReleaseInput,
};
pub use downloads::{
    CacheProvenance, DownloadError, DownloadResult, FirmwareDownloader, LegacyCachePolicy,
};
pub use http::{FirmwareHttpClient, HttpUrlError};
pub use repository::{FirmwareRepository, RepositoryError};
pub use updates::{
    CheckOutcome, CheckStatus, ConnectedFirmware, ConnectedUnconfiguredFirmware,
    FirmwareUpdateScheduler, SchedulerConfig, SchedulerTask, UpdateCheckRecord, UpdateNotice,
};
pub use upload::{
    parse_error_output, retryable_baud_rates, run_device_upload, CancelKind, DeviceUpload,
    UploadCancelError, UploadCancelHandle, UploadEvent, UploadFailure, UploadHistoryPort,
    UploadHooks, UploadInfo, UploadManager, UploadOutcome, UploadRequest, UploadRunResult,
    UploadSerialOwnership, UploadStartError, UploadStartRecord, UploadStatus, UploadTimings,
    UploadTooling,
};
