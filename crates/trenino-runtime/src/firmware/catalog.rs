use super::{http::permitted_url, FirmwareHttpClient, FirmwareRepository, RepositoryError};
use reqwest::Url;
use serde::Deserialize;
use std::sync::Arc;
use std::time::Duration;
use trenino_core::firmware::{FirmwareManifest, FirmwareRequirement, ManifestDevice, UploadConfig};
use trenino_core::EntityId;

const RELEASES_API: &str = "https://api.github.com/repos/albertorestifo/trenino_firmware/releases";

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FirmwareAsset {
    /// Stable firmware_files row ID, assigned by the repository adapter.
    pub id: EntityId,
    /// GitHub's asset ID, retained as upstream catalog metadata.
    pub github_asset_id: Option<i64>,
    pub filename: String,
    pub download_url: Url,
    pub size: Option<u64>,
    pub environment: Option<String>,
    pub board_type: String,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FirmwareDevice {
    pub manifest: ManifestDevice,
    pub asset: Option<FirmwareAsset>,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CatalogRelease {
    pub id: EntityId,
    pub version: String,
    pub tag_name: String,
    pub release_url: Option<Url>,
    pub release_notes: Option<String>,
    pub published_at: Option<String>,
    pub manifest: FirmwareManifest,
    pub devices: Vec<FirmwareDevice>,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ReleaseInput {
    pub version: String,
    pub tag_name: String,
    pub release_url: Option<Url>,
    pub release_notes: Option<String>,
    pub published_at: Option<String>,
    pub manifest: FirmwareManifest,
    pub devices: Vec<FirmwareDevice>,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FirmwareSelection {
    pub release_id: EntityId,
    pub version: String,
    pub device: FirmwareDevice,
    pub upload_config: UploadConfig,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CatalogError {
    Http,
    InvalidResponse,
    MissingManifest,
    InvalidManifest,
    InvalidAsset,
    Repository(RepositoryError),
    NotFound,
    Incompatible,
}
impl std::fmt::Display for CatalogError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Repository(_) => f.write_str("firmware catalog storage failed"),
            Self::Http => f.write_str("could not retrieve firmware release information"),
            Self::InvalidResponse => f.write_str("firmware release response was invalid"),
            Self::MissingManifest => f.write_str("release.json is missing"),
            Self::InvalidManifest => f.write_str("release manifest is invalid"),
            Self::InvalidAsset => f.write_str("firmware asset reference is invalid"),
            Self::NotFound => f.write_str("firmware release or environment was not found"),
            Self::Incompatible => {
                f.write_str("firmware release is incompatible with this application")
            }
        }
    }
}
impl std::error::Error for CatalogError {}
impl From<RepositoryError> for CatalogError {
    fn from(e: RepositoryError) -> Self {
        Self::Repository(e)
    }
}

pub struct FirmwareCatalog<R: FirmwareRepository> {
    client: FirmwareHttpClient,
    repository: Arc<R>,
    endpoint: Url,
    requirement: FirmwareRequirement,
    timeout: Duration,
}
impl<R: FirmwareRepository> FirmwareCatalog<R> {
    pub fn new(
        client: FirmwareHttpClient,
        repository: Arc<R>,
        requirement: FirmwareRequirement,
    ) -> Self {
        Self {
            client,
            repository,
            endpoint: Url::parse(RELEASES_API).expect("static GitHub API URL"),
            requirement,
            timeout: Duration::from_secs(30),
        }
    }
    /// Endpoint injection is intended for controlled deployments and local HTTP tests.
    pub fn with_endpoint(mut self, endpoint: Url) -> Self {
        self.endpoint = endpoint;
        self
    }
    pub fn with_timeout(mut self, timeout: Duration) -> Self {
        self.timeout = timeout;
        self
    }
    pub async fn refresh(&self) -> Result<Vec<CatalogRelease>, CatalogError> {
        let request = self
            .client
            .get(&self.endpoint)
            .map_err(|_| CatalogError::InvalidAsset)?
            .timeout(self.timeout);
        let response = self
            .client
            .github_headers(request)
            .send()
            .await
            .map_err(|_| CatalogError::Http)?;
        if !permitted_url(response.url()) {
            return Err(CatalogError::Http);
        }
        if !response.status().is_success() {
            return Err(CatalogError::Http);
        }
        let body = read_limited(response, 16 * 1024 * 1024).await?;
        let releases: Vec<GithubRelease> =
            serde_json::from_slice(&body).map_err(|_| CatalogError::InvalidResponse)?;
        let mut parsed = Vec::new();
        for release in releases {
            match parse_release(&self.client, self.timeout, release).await {
                Ok(input) => parsed.push(input),
                Err(
                    CatalogError::MissingManifest
                    | CatalogError::InvalidResponse
                    | CatalogError::InvalidManifest
                    | CatalogError::InvalidAsset,
                ) => continue,
                Err(error) => return Err(error),
            }
        }
        self.repository.upsert_catalog(&parsed).map_err(Into::into)
    }
    pub fn list(&self) -> Result<Vec<CatalogRelease>, CatalogError> {
        self.repository.list_releases().map_err(Into::into)
    }
    pub fn select(
        &self,
        release_id: EntityId,
        environment: &str,
    ) -> Result<FirmwareSelection, CatalogError> {
        let release = self
            .repository
            .get_release(release_id)?
            .ok_or(CatalogError::NotFound)?;
        if !self.requirement.matches(&release.version) {
            return Err(CatalogError::Incompatible);
        }
        let device = release
            .devices
            .into_iter()
            .find(|d| {
                d.manifest.environment == environment
                    && d.asset.is_some()
                    && d.manifest.upload_config.protocol.is_supported()
            })
            .ok_or(CatalogError::NotFound)?;
        Ok(FirmwareSelection {
            release_id,
            version: release.version,
            upload_config: device.manifest.upload_config.clone(),
            device,
        })
    }
    pub fn latest_compatible(&self) -> Result<Option<CatalogRelease>, CatalogError> {
        Ok(self
            .repository
            .list_releases()?
            .into_iter()
            .filter(|r| self.requirement.matches(&r.version))
            .max_by(|a, b| a.published_at.cmp(&b.published_at)))
    }
    /// Manifest-backed device choices. Unsupported upload protocols and missing
    /// release assets remain visible in the saved release but cannot be selected.
    pub fn available_devices(
        &self,
        release_id: EntityId,
    ) -> Result<Vec<FirmwareDevice>, CatalogError> {
        let release = self
            .repository
            .get_release(release_id)?
            .ok_or(CatalogError::NotFound)?;
        Ok(release
            .devices
            .into_iter()
            .filter(|d| d.asset.is_some() && d.manifest.upload_config.protocol.is_supported())
            .collect())
    }
}

impl<R: FirmwareRepository> FirmwareCatalog<R> {
    /// Catalog-backed filename detection: every environment known from the
    /// persisted releases (the startup backfill source — the Elixir registry
    /// is populated from saved manifests at boot and on download) is offered
    /// to [`detect_device_from_filename`].
    pub fn detect_device_from_filename(
        &self,
        filename: &str,
    ) -> Result<Option<String>, CatalogError> {
        let environments = self
            .repository
            .list_releases()?
            .into_iter()
            .flat_map(|release| {
                release
                    .devices
                    .into_iter()
                    .map(|device| device.manifest.environment)
            })
            .collect::<Vec<_>>();
        Ok(detect_device_from_filename(filename, &environments))
    }
}

/// Ports `DeviceRegistry.detect_device_from_filename/1`
/// (device_registry.ex:85-97): matches `trenino-{environment}.firmware.hex`
/// or `trenino-{environment}.hex` (regex `trenino-([^.]+)(?:\.firmware)?\.hex$`,
/// searched anywhere in the filename) and returns the environment only when
/// it is present in the known registry; `None` otherwise (Elixir `:error`).
pub fn detect_device_from_filename(
    filename: &str,
    known_environments: &[String],
) -> Option<String> {
    let mut search_from = 0usize;
    while let Some(offset) = filename[search_from..].find("trenino-") {
        let candidate = &filename[search_from + offset + "trenino-".len()..];
        let Some(stem) = candidate.strip_suffix(".hex") else {
            search_from += offset + "trenino-".len();
            continue;
        };
        let environment = stem.strip_suffix(".firmware").unwrap_or(stem);
        if !environment.is_empty()
            && !environment.contains('.')
            && known_environments.iter().any(|env| env == environment)
        {
            return Some(environment.to_string());
        }
        search_from += offset + "trenino-".len();
    }
    None
}

#[derive(Deserialize)]
struct GithubRelease {
    tag_name: String,
    html_url: Option<String>,
    body: Option<String>,
    published_at: Option<String>,
    #[serde(default)]
    assets: Vec<GithubAsset>,
}
#[derive(Deserialize)]
struct GithubAsset {
    id: i64,
    name: String,
    browser_download_url: String,
    size: Option<u64>,
}
async fn parse_release(
    client: &FirmwareHttpClient,
    timeout: Duration,
    release: GithubRelease,
) -> Result<ReleaseInput, CatalogError> {
    let tag = release.tag_name;
    let version = tag.strip_prefix('v').unwrap_or(&tag).to_owned();
    if trenino_core::firmware::FirmwareVersion::parse(&version).is_err() {
        return Err(CatalogError::InvalidResponse);
    }
    let manifest_asset = release
        .assets
        .iter()
        .find(|a| a.name == "release.json")
        .ok_or(CatalogError::MissingManifest)?;
    let manifest_url =
        Url::parse(&manifest_asset.browser_download_url).map_err(|_| CatalogError::InvalidAsset)?;
    if !permitted_url(&manifest_url) {
        return Err(CatalogError::InvalidAsset);
    }
    let manifest_response = client
        .get(&manifest_url)
        .map_err(|_| CatalogError::InvalidAsset)?
        .timeout(timeout)
        .send()
        .await
        .map_err(|_| CatalogError::Http)?;
    if !permitted_url(manifest_response.url()) {
        return Err(CatalogError::Http);
    }
    if matches!(manifest_response.status().as_u16(), 404 | 410) {
        return Err(CatalogError::MissingManifest);
    }
    if !manifest_response.status().is_success() {
        return Err(CatalogError::Http);
    }
    let manifest_json = read_limited(manifest_response, 1024 * 1024).await?;
    let manifest_json =
        std::str::from_utf8(&manifest_json).map_err(|_| CatalogError::InvalidManifest)?;
    let manifest =
        FirmwareManifest::parse_json(manifest_json).map_err(|_| CatalogError::InvalidManifest)?;
    if manifest
        .version
        .strip_prefix('v')
        .unwrap_or(&manifest.version)
        != version
    {
        return Err(CatalogError::InvalidManifest);
    }
    let devices = manifest
        .devices
        .iter()
        .map(|device| {
            let asset = release
                .assets
                .iter()
                .find(|a| a.name == device.firmware_file)
                .and_then(|a| {
                    Url::parse(&a.browser_download_url)
                        .ok()
                        .filter(permitted_url)
                        .map(|download_url| FirmwareAsset {
                            id: EntityId(0),
                            github_asset_id: Some(a.id),
                            filename: a.name.clone(),
                            download_url,
                            size: a.size,
                            environment: Some(device.environment.clone()),
                            board_type: device.environment.clone(),
                        })
                });
            FirmwareDevice {
                manifest: device.clone(),
                asset,
            }
        })
        .collect::<Vec<_>>();
    let release_url = release.html_url.and_then(|u| {
        Url::parse(&u).ok().filter(|url| {
            url.scheme() == "https" && url.username().is_empty() && url.password().is_none()
        })
    });
    Ok(ReleaseInput {
        version,
        tag_name: tag,
        release_url,
        release_notes: release.body,
        published_at: release.published_at,
        manifest,
        devices,
    })
}
async fn read_limited(
    mut response: reqwest::Response,
    max: usize,
) -> Result<Vec<u8>, CatalogError> {
    let mut body = Vec::new();
    while let Some(chunk) = response.chunk().await.map_err(|_| CatalogError::Http)? {
        if body.len().saturating_add(chunk.len()) > max {
            return Err(CatalogError::InvalidResponse);
        }
        body.extend_from_slice(&chunk);
    }
    Ok(body)
}
