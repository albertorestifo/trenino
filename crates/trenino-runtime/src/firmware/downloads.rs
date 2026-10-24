use super::FirmwareHttpClient;
use super::FirmwareSelection;
use reqwest::Url;
use serde::{Deserialize, Serialize};
use std::time::Duration;
use std::{
    collections::HashMap,
    fs::{self, File, OpenOptions},
    io::{ErrorKind, Write},
    path::{Path, PathBuf},
    sync::{
        atomic::{AtomicU64, Ordering},
        Arc, Mutex,
    },
};
use tokio::sync::{Mutex as AsyncMutex, Semaphore};
use trenino_core::firmware::FirmwareVersion;

static PARTIAL_SEQUENCE: AtomicU64 = AtomicU64::new(0);

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum DownloadError {
    InvalidUrl,
    InvalidPath,
    Http,
    Status(u16),
    TooLarge,
    EmptyAsset,
    LengthMismatch,
    CacheIo,
    Cancelled,
}
impl std::fmt::Display for DownloadError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Status(status) => write!(f, "firmware server returned HTTP {status}"),
            Self::InvalidUrl => f.write_str("firmware download URL is invalid"),
            Self::InvalidPath => f.write_str("firmware cache path is invalid"),
            Self::Http => f.write_str("firmware transfer failed"),
            Self::TooLarge => f.write_str("firmware asset exceeds the configured size limit"),
            Self::EmptyAsset => f.write_str("firmware asset is empty"),
            Self::LengthMismatch => {
                f.write_str("firmware asset length does not match release metadata")
            }
            Self::CacheIo => f.write_str("firmware cache could not be written"),
            Self::Cancelled => f.write_str("firmware download was cancelled"),
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum CacheProvenance {
    Downloaded,
    ReceiptMatched,
    LegacyUnverified,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum LegacyCachePolicy {
    RejectUnverified,
    AllowUnverifiedMatchingPath,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DownloadResult {
    pub path: PathBuf,
    pub provenance: CacheProvenance,
}

#[derive(Clone, Debug, Deserialize, Serialize, PartialEq, Eq)]
struct CacheReceipt {
    release_id: i64,
    github_asset_id: Option<i64>,
    download_url: String,
    filename: String,
    size: Option<u64>,
}
impl std::error::Error for DownloadError {}

pub struct FirmwareDownloader {
    client: FirmwareHttpClient,
    cache_dir: PathBuf,
    max_bytes: u64,
    concurrency: Arc<Semaphore>,
    locks: Mutex<HashMap<PathBuf, Arc<AsyncMutex<()>>>>,
    timeout: Duration,
    legacy_policy: LegacyCachePolicy,
}
impl FirmwareDownloader {
    pub fn new(
        client: FirmwareHttpClient,
        cache_dir: impl Into<PathBuf>,
        max_bytes: u64,
        max_concurrent: usize,
    ) -> Self {
        Self {
            client,
            cache_dir: cache_dir.into(),
            max_bytes,
            concurrency: Arc::new(Semaphore::new(max_concurrent.max(1))),
            locks: Mutex::new(HashMap::new()),
            timeout: Duration::from_secs(30),
            legacy_policy: LegacyCachePolicy::RejectUnverified,
        }
    }
    pub fn with_timeout(mut self, timeout: Duration) -> Self {
        self.timeout = timeout;
        self
    }
    pub fn with_legacy_cache_policy(mut self, policy: LegacyCachePolicy) -> Self {
        self.legacy_policy = policy;
        self
    }
    /// Legacy location convention: production uses the user's `.trenino` cache;
    /// development uses the application's bundled `priv/firmware_cache` path.
    pub fn cache_directory(production: bool, user_home: &Path, app_dir: &Path) -> PathBuf {
        if production {
            user_home.join(".trenino").join("firmware_cache")
        } else {
            app_dir.join("priv").join("firmware_cache")
        }
    }
    /// Immutable cache path bound to the selected remote asset.
    ///
    /// The file name extends the legacy `v{version}_{environment-or-board}.hex`
    /// convention with a key derived from the asset provenance, so two pinned
    /// selections that share a version/environment but differ in remote asset
    /// never share a mutable destination: publishing one leaves the bytes the
    /// other already received untouched.
    pub fn cache_path(&self, selection: &FirmwareSelection) -> Result<PathBuf, DownloadError> {
        let (version, identifier) = self.validated_cache_stem(selection)?;
        let key = asset_key(selection);
        Ok(self
            .cache_dir
            .join(format!("v{version}_{identifier}.{key}.hex")))
    }
    /// Legacy `v{version}_{environment-or-board}.hex` location. Files written
    /// by the legacy Elixir downloader (or the receipt-based Rust scheme that
    /// preceded asset-bound paths) live here and are only ever read, never
    /// replaced, so results returned for them stay immutable.
    fn legacy_cache_path(&self, selection: &FirmwareSelection) -> Result<PathBuf, DownloadError> {
        let (version, identifier) = self.validated_cache_stem(selection)?;
        Ok(self.cache_dir.join(format!("v{version}_{identifier}.hex")))
    }
    fn validated_cache_stem(
        &self,
        selection: &FirmwareSelection,
    ) -> Result<(String, String), DownloadError> {
        let asset = selection
            .device
            .asset
            .as_ref()
            .ok_or(DownloadError::InvalidPath)?;
        let identifier = asset.environment.as_deref().unwrap_or(&asset.board_type);
        if FirmwareVersion::parse(&selection.version).is_err()
            || !safe_component(&selection.version)
            || !safe_component(identifier)
        {
            return Err(DownloadError::InvalidPath);
        }
        Ok((selection.version.clone(), identifier.to_owned()))
    }
    pub async fn download(
        &self,
        selection: &FirmwareSelection,
    ) -> Result<DownloadResult, DownloadError> {
        let asset = selection
            .device
            .asset
            .as_ref()
            .ok_or(DownloadError::InvalidPath)?;
        validate_url(&asset.download_url)?;
        let destination = self.cache_path(selection)?;
        let lock = {
            let mut locks = self.locks.lock().map_err(|_| DownloadError::CacheIo)?;
            locks
                .entry(destination.clone())
                .or_insert_with(|| Arc::new(AsyncMutex::new(())))
                .clone()
        };
        let _same_asset = lock.lock().await;
        if valid_cache(&destination, asset.size, self.max_bytes)
            && receipt_matches(&receipt_path(&destination), selection)
        {
            return Ok(DownloadResult {
                path: destination,
                provenance: CacheProvenance::ReceiptMatched,
            });
        }
        // Legacy destinations are only read, never replaced, so they keep
        // satisfying every selection that already received them.
        if let Ok(legacy) = self.legacy_cache_path(selection) {
            if valid_cache(&legacy, asset.size, self.max_bytes)
                && receipt_matches(&receipt_path(&legacy), selection)
            {
                return Ok(DownloadResult {
                    path: legacy,
                    provenance: CacheProvenance::ReceiptMatched,
                });
            }
            if valid_cache(&legacy, asset.size, self.max_bytes)
                && !receipt_path(&legacy).exists()
                && self.legacy_policy == LegacyCachePolicy::AllowUnverifiedMatchingPath
                && is_unambiguous_legacy_cache(selection, asset.size)
            {
                return Ok(DownloadResult {
                    path: legacy,
                    provenance: CacheProvenance::LegacyUnverified,
                });
            }
        }
        let _permit = self
            .concurrency
            .acquire()
            .await
            .map_err(|_| DownloadError::Cancelled)?;
        fs::create_dir_all(&self.cache_dir).map_err(|_| DownloadError::CacheIo)?;
        let (mut file, mut cleanup) = create_partial_file(&destination)?;
        let response = self
            .client
            .get(&asset.download_url)
            .map_err(|_| DownloadError::InvalidUrl)?
            .timeout(self.timeout)
            .send()
            .await
            .map_err(|_| DownloadError::Http)?;
        validate_url(response.url())?;
        if !response.status().is_success() {
            return Err(DownloadError::Status(response.status().as_u16()));
        }
        if let (Some(expected), Some(content_length)) = (asset.size, response.content_length()) {
            if expected != content_length {
                return Err(DownloadError::LengthMismatch);
            }
        }
        let mut response = response;
        let mut transferred = 0u64;
        while let Some(chunk) = response.chunk().await.map_err(|_| DownloadError::Http)? {
            transferred = transferred
                .checked_add(chunk.len() as u64)
                .ok_or(DownloadError::TooLarge)?;
            if transferred > self.max_bytes
                || asset.size.is_some_and(|expected| transferred > expected)
            {
                return Err(DownloadError::TooLarge);
            }
            file.write_all(&chunk).map_err(|_| DownloadError::CacheIo)?;
        }
        if asset.size.is_some_and(|expected| expected != transferred) {
            return Err(DownloadError::LengthMismatch);
        }
        if transferred == 0 {
            return Err(DownloadError::EmptyAsset);
        }
        file.sync_all().map_err(|_| DownloadError::CacheIo)?;
        drop(file);
        let receipt = cache_receipt(selection);
        let receipt_bytes = serde_json::to_vec(&receipt).map_err(|_| DownloadError::CacheIo)?;
        let (mut receipt_file, mut receipt_cleanup) =
            create_partial_file(&receipt_path(&destination))?;
        receipt_file
            .write_all(&receipt_bytes)
            .map_err(|_| DownloadError::CacheIo)?;
        receipt_file
            .sync_all()
            .map_err(|_| DownloadError::CacheIo)?;
        drop(receipt_file);
        // Publication replaces the data first and the receipt second. Both
        // live at an asset-bound destination, so a receipt-replacement failure
        // can only leave the previous receipt of this very identity beside
        // freshly fetched bytes of the same identity — never another asset's
        // receipt over these bytes, and never a valid receipt over missing
        // bytes (an unpublished first download simply re-downloads).
        atomic_replace(cleanup.path(), &destination)?;
        cleanup.disarm();
        atomic_replace(receipt_cleanup.path(), &receipt_path(&destination))?;
        receipt_cleanup.disarm();
        Ok(DownloadResult {
            path: destination,
            provenance: CacheProvenance::Downloaded,
        })
    }
}

fn safe_component(s: &str) -> bool {
    !s.is_empty()
        && s.len() <= 100
        && s != "."
        && s != ".."
        && s.bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'.' || b == b'_' || b == b'-' || b == b'+')
}
fn validate_url(url: &Url) -> Result<(), DownloadError> {
    let loopback_http = url.scheme() == "http"
        && url.host_str().is_some_and(|host| {
            host == "localhost"
                || host
                    .parse::<std::net::IpAddr>()
                    .is_ok_and(|ip| ip.is_loopback())
        });
    if (url.scheme() == "https" || loopback_http)
        && url.username().is_empty()
        && url.password().is_none()
    {
        Ok(())
    } else {
        Err(DownloadError::InvalidUrl)
    }
}
fn valid_cache(path: &Path, expected: Option<u64>, max_bytes: u64) -> bool {
    fs::symlink_metadata(path)
        .map(|m| {
            m.file_type().is_file()
                && m.len() > 0
                && m.len() <= max_bytes
                && expected.is_none_or(|n| n == m.len())
        })
        .unwrap_or(false)
}
fn unique_partial(path: &Path) -> PathBuf {
    let seq = PARTIAL_SEQUENCE.fetch_add(1, Ordering::Relaxed);
    let mut name = path.file_name().unwrap_or_default().to_os_string();
    name.push(format!(".{}.{}.partial", std::process::id(), seq));
    path.with_file_name(name)
}
fn receipt_path(path: &Path) -> PathBuf {
    let mut name = path.file_name().unwrap_or_default().to_os_string();
    name.push(".trenino-meta.json");
    path.with_file_name(name)
}
/// Stable key for the selected asset's provenance (the same fields a cache
/// receipt certifies). Deterministic across runs so an offline downloader
/// instance resolves the same immutable cache entry.
fn asset_key(selection: &FirmwareSelection) -> String {
    let receipt = cache_receipt(selection);
    let github_asset_id = receipt
        .github_asset_id
        .map_or_else(|| "-".into(), |id| id.to_string());
    let size = receipt
        .size
        .map_or_else(|| "-".into(), |size| size.to_string());
    let identity = format!(
        "{}\u{1f}{}\u{1f}{}\u{1f}{}\u{1f}{}",
        receipt.release_id, github_asset_id, receipt.download_url, receipt.filename, size
    );
    format!("{:016x}", fnv1a64(identity.as_bytes()))
}
/// FNV-1a 64-bit: a small, fixed, dependency-free digest that is stable
/// across processes, platforms and releases — unlike `DefaultHasher`.
fn fnv1a64(bytes: &[u8]) -> u64 {
    bytes.iter().fold(0xcbf2_9ce4_8422_2325, |hash, byte| {
        (hash ^ u64::from(*byte)).wrapping_mul(0x0000_0100_0000_01b3)
    })
}
fn cache_receipt(selection: &FirmwareSelection) -> CacheReceipt {
    let asset = selection
        .device
        .asset
        .as_ref()
        .expect("validated selection has asset");
    CacheReceipt {
        release_id: selection.release_id.0,
        github_asset_id: asset.github_asset_id,
        download_url: asset.download_url.to_string(),
        filename: asset.filename.clone(),
        size: asset.size,
    }
}
fn receipt_matches(path: &Path, selection: &FirmwareSelection) -> bool {
    fs::read(path)
        .ok()
        .and_then(|bytes| serde_json::from_slice::<CacheReceipt>(&bytes).ok())
        .is_some_and(|stored| stored == cache_receipt(selection))
}
fn is_unambiguous_legacy_cache(selection: &FirmwareSelection, size: Option<u64>) -> bool {
    let Some(asset) = selection.device.asset.as_ref() else {
        return false;
    };
    let identifier = asset.environment.as_deref().unwrap_or(&asset.board_type);
    size.is_some()
        && selection.device.manifest.firmware_file == asset.filename
        && selection.device.manifest.environment == identifier
}
fn create_partial_file(path: &Path) -> Result<(File, PartialFile), DownloadError> {
    create_partial_file_with(path, || unique_partial(path))
}
fn create_partial_file_with(
    _destination: &Path,
    mut next_candidate: impl FnMut() -> PathBuf,
) -> Result<(File, PartialFile), DownloadError> {
    for _ in 0..128 {
        let candidate = next_candidate();
        match OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&candidate)
        {
            Ok(file) => return Ok((file, PartialFile(Some(candidate)))),
            Err(error) if error.kind() == ErrorKind::AlreadyExists => continue,
            Err(_) => return Err(DownloadError::CacheIo),
        }
    }
    Err(DownloadError::CacheIo)
}
fn atomic_replace(source: &Path, destination: &Path) -> Result<(), DownloadError> {
    #[cfg(windows)]
    {
        use std::os::windows::ffi::OsStrExt;
        use windows_sys::Win32::Storage::FileSystem::{
            MoveFileExW, MOVEFILE_REPLACE_EXISTING, MOVEFILE_WRITE_THROUGH,
        };
        let source: Vec<u16> = source.as_os_str().encode_wide().chain(Some(0)).collect();
        let destination: Vec<u16> = destination
            .as_os_str()
            .encode_wide()
            .chain(Some(0))
            .collect();
        let ok = unsafe {
            MoveFileExW(
                source.as_ptr(),
                destination.as_ptr(),
                MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH,
            )
        };
        if ok == 0 {
            return Err(DownloadError::CacheIo);
        }
        Ok(())
    }
    #[cfg(not(windows))]
    {
        fs::rename(source, destination).map_err(|_| DownloadError::CacheIo)
    }
}
struct PartialFile(Option<PathBuf>);
impl PartialFile {
    fn path(&self) -> &Path {
        self.0.as_deref().expect("partial file is armed")
    }
    fn disarm(&mut self) {
        self.0 = None;
    }
}
impl Drop for PartialFile {
    fn drop(&mut self) {
        if let Some(path) = self.0.take() {
            let _ = fs::remove_file(path);
        }
    }
}

#[cfg(test)]
mod partial_file_tests {
    use super::*;
    use std::collections::VecDeque;

    #[test]
    fn create_new_collision_is_retried_without_deleting_unowned_file() {
        let directory = tempfile::tempdir().unwrap();
        let destination = directory.path().join("v1.2.3_uno.hex");
        let collision = directory.path().join("collision.partial");
        let owned = directory.path().join("owned.partial");
        fs::write(&collision, b"preexisting").unwrap();
        let mut candidates = VecDeque::from([collision.clone(), owned.clone()]);
        let (mut file, guard) =
            create_partial_file_with(&destination, || candidates.pop_front().unwrap()).unwrap();
        file.write_all(b"new").unwrap();
        drop(file);
        drop(guard);
        assert_eq!(fs::read(&collision).unwrap(), b"preexisting");
        assert!(!owned.exists());
    }
}
