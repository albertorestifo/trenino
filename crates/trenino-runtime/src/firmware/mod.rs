//! Firmware catalog, safe cache downloads, and update scheduling.
mod catalog;
mod downloads;
mod http;
mod repository;
mod updates;
mod upload;

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
pub use upload::{
    parse_error_output, retryable_baud_rates, run_device_upload, CancelKind, DeviceUpload,
    UploadCancelError, UploadCancelHandle, UploadEvent, UploadFailure, UploadHistoryPort,
    UploadHooks, UploadInfo, UploadManager, UploadOutcome, UploadRequest, UploadRunResult,
    UploadStartError, UploadStartRecord, UploadStatus, UploadTimings, UploadTooling,
};
