use super::FirmwareSelection;
use reqwest::{Client, Url};
use std::time::Duration;
use std::{
    collections::HashMap,
    fs::{self, OpenOptions},
    io::Write,
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
            Self::LengthMismatch => {
                f.write_str("firmware asset length does not match release metadata")
            }
            Self::CacheIo => f.write_str("firmware cache could not be written"),
            Self::Cancelled => f.write_str("firmware download was cancelled"),
        }
    }
}
impl std::error::Error for DownloadError {}

pub struct FirmwareDownloader {
    client: Client,
    cache_dir: PathBuf,
    max_bytes: u64,
    concurrency: Arc<Semaphore>,
    locks: Mutex<HashMap<i64, Arc<AsyncMutex<()>>>>,
    timeout: Duration,
}
impl FirmwareDownloader {
    pub fn new(
        client: Client,
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
        }
    }
    pub fn with_timeout(mut self, timeout: Duration) -> Self {
        self.timeout = timeout;
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
    pub fn cache_path(&self, selection: &FirmwareSelection) -> Result<PathBuf, DownloadError> {
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
        Ok(self
            .cache_dir
            .join(format!("{}_{}.hex", selection.version, identifier)))
    }
    pub async fn download(&self, selection: &FirmwareSelection) -> Result<PathBuf, DownloadError> {
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
                .entry(asset.id.0)
                .or_insert_with(|| Arc::new(AsyncMutex::new(())))
                .clone()
        };
        let _same_asset = lock.lock().await;
        if valid_cache(&destination, asset.size, self.max_bytes) {
            return Ok(destination);
        }
        let _permit = self
            .concurrency
            .acquire()
            .await
            .map_err(|_| DownloadError::Cancelled)?;
        fs::create_dir_all(&self.cache_dir).map_err(|_| DownloadError::CacheIo)?;
        let partial = unique_partial(&destination);
        let mut cleanup = PartialFile(Some(partial.clone()));
        let response = self
            .client
            .get(asset.download_url.clone())
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
        let mut file = OpenOptions::new()
            .write(true)
            .create_new(true)
            .open(&partial)
            .map_err(|_| DownloadError::CacheIo)?;
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
        file.sync_all().map_err(|_| DownloadError::CacheIo)?;
        drop(file);
        if destination.exists() {
            return Err(DownloadError::LengthMismatch);
        }
        fs::rename(&partial, &destination).map_err(|_| DownloadError::CacheIo)?;
        cleanup.0 = None;
        Ok(destination)
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
struct PartialFile(Option<PathBuf>);
impl Drop for PartialFile {
    fn drop(&mut self) {
        if let Some(path) = self.0.take() {
            let _ = fs::remove_file(path);
        }
    }
}
