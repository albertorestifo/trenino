use reqwest::Url;
use std::{
    io::{Read, Write},
    net::TcpListener,
    sync::{Arc, Mutex},
    thread,
    time::Duration,
};
use tempfile::TempDir;
use trenino_core::firmware::{FirmwareManifest, FirmwareRequirement, Programmer, UploadConfig};
use trenino_runtime::firmware::{
    CatalogRelease, ConnectedFirmware, FirmwareAsset, FirmwareCatalog, FirmwareDevice,
    FirmwareDownloader, FirmwareHttpClient, FirmwareRepository, FirmwareSelection,
    FirmwareUpdateScheduler, ReleaseInput, RepositoryError, SchedulerConfig, UpdateCheckRecord,
};

fn http_client() -> FirmwareHttpClient {
    FirmwareHttpClient::new(Duration::from_secs(30)).unwrap()
}

#[derive(Default)]
struct Repo {
    releases: Mutex<Vec<CatalogRelease>>,
    check: Mutex<Option<UpdateCheckRecord>>,
    dismissed: Mutex<Option<String>>,
    fail_check: Mutex<bool>,
    fail_dismiss: Mutex<bool>,
}
impl FirmwareRepository for Repo {
    fn upsert_catalog(
        &self,
        inputs: &[ReleaseInput],
    ) -> Result<Vec<CatalogRelease>, RepositoryError> {
        let releases = inputs
            .iter()
            .enumerate()
            .map(|(i, x)| CatalogRelease {
                id: trenino_core::EntityId(i as i64 + 1),
                version: x.version.clone(),
                tag_name: x.tag_name.clone(),
                release_url: x.release_url.clone(),
                release_notes: x.release_notes.clone(),
                published_at: x.published_at.clone(),
                manifest: x.manifest.clone(),
                devices: x
                    .devices
                    .iter()
                    .enumerate()
                    .map(|(j, d)| {
                        let mut d = d.clone();
                        if let Some(asset) = d.asset.as_mut() {
                            asset.id = trenino_core::EntityId((i * 100 + j + 1) as i64);
                        }
                        d
                    })
                    .collect(),
            })
            .collect::<Vec<_>>();
        *self.releases.lock().unwrap() = releases.clone();
        Ok(releases)
    }
    fn list_releases(&self) -> Result<Vec<CatalogRelease>, RepositoryError> {
        Ok(self.releases.lock().unwrap().clone())
    }
    fn get_release(
        &self,
        id: trenino_core::EntityId,
    ) -> Result<Option<CatalogRelease>, RepositoryError> {
        Ok(self
            .releases
            .lock()
            .unwrap()
            .iter()
            .find(|r| r.id == id)
            .cloned())
    }
    fn record_check(&self, x: &UpdateCheckRecord) -> Result<(), RepositoryError> {
        if *self.fail_check.lock().unwrap() {
            return Err(RepositoryError { code: "injected" });
        }
        *self.check.lock().unwrap() = Some(x.clone());
        Ok(())
    }
    fn latest_check(&self) -> Result<Option<UpdateCheckRecord>, RepositoryError> {
        Ok(self.check.lock().unwrap().clone())
    }
    fn dismissed_notice(&self) -> Result<Option<String>, RepositoryError> {
        Ok(self.dismissed.lock().unwrap().clone())
    }
    fn set_dismissed_notice(&self, x: Option<&str>) -> Result<(), RepositoryError> {
        if *self.fail_dismiss.lock().unwrap() {
            return Err(RepositoryError { code: "injected" });
        }
        *self.dismissed.lock().unwrap() = x.map(str::to_owned);
        Ok(())
    }
}

fn fake_http(responses: Vec<(u16, String)>) -> Url {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    thread::spawn(move || {
        for (status, body) in responses {
            let (mut stream, _) = listener.accept().unwrap();
            let mut request = [0u8; 4096];
            let _ = stream.read(&mut request);
            let phrase = if status == 200 { "OK" } else { "Not Found" };
            write!(stream, "HTTP/1.1 {status} {phrase}\r\nContent-Length: {}\r\nConnection: close\r\nContent-Type: application/json\r\n\r\n{body}", body.len()).unwrap();
        }
    });
    Url::parse(&format!("http://{addr}/")).unwrap()
}
fn one_redirect(location: String) -> Url {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    thread::spawn(move || {
        let (mut stream, _) = listener.accept().unwrap();
        let mut request = [0u8; 512];
        let _ = stream.read(&mut request);
        write!(stream, "HTTP/1.1 302 Found\r\nLocation: {location}\r\nContent-Length: 0\r\nConnection: close\r\n\r\n").unwrap();
    });
    Url::parse(&format!("http://{addr}/redirect")).unwrap()
}
/// Rejected redirect target that keeps the counting listener's full
/// host-and-port authority while adding disallowed userinfo, so a zero-hit
/// assertion proves the boundary blocked the real listener, not some other
/// port.
fn disallowed_with_userinfo(target: &Url) -> String {
    let mut disallowed = target.clone();
    disallowed.set_username("user").unwrap();
    disallowed.set_password(Some("pass")).unwrap();
    disallowed.to_string()
}
fn counted_http(body: &'static str) -> (Url, Arc<std::sync::atomic::AtomicUsize>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    let hits = Arc::new(std::sync::atomic::AtomicUsize::new(0));
    let count = hits.clone();
    thread::spawn(move || {
        listener.set_nonblocking(true).unwrap();
        for _ in 0..200 {
            if let Ok((mut stream, _)) = listener.accept() {
                count.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
                // Drain the request and close cleanly so concurrent clients
                // never observe a reset racing the response bytes.
                stream.set_nonblocking(false).unwrap();
                let mut request = Vec::new();
                let mut chunk = [0u8; 512];
                while let Ok(n) = stream.read(&mut chunk) {
                    if n == 0 {
                        break;
                    }
                    request.extend_from_slice(&chunk[..n]);
                    if request.windows(4).any(|window| window == b"\r\n\r\n") {
                        break;
                    }
                }
                write!(
                    stream,
                    "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                    body.len()
                )
                .unwrap();
                stream.flush().unwrap();
                let _ = stream.shutdown(std::net::Shutdown::Write);
                let mut drain = [0u8; 512];
                while matches!(stream.read(&mut drain), Ok(n) if n > 0) {}
                break;
            }
            thread::sleep(Duration::from_millis(1));
        }
    });
    (Url::parse(&format!("http://{addr}/target")).unwrap(), hits)
}
fn redirect_loop_http() -> (Url, Arc<std::sync::atomic::AtomicUsize>) {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    let url = format!("http://{addr}/loop");
    let redirect_url = url.clone();
    let hits = Arc::new(std::sync::atomic::AtomicUsize::new(0));
    let count = hits.clone();
    thread::spawn(move || {
        for _ in 0..10 {
            let Ok((mut stream, _)) = listener.accept() else {
                break;
            };
            count.fetch_add(1, std::sync::atomic::Ordering::SeqCst);
            let mut request = [0u8; 512];
            let _ = stream.read(&mut request);
            let _ = write!(stream, "HTTP/1.1 302 Found\r\nLocation: {redirect_url}\r\nContent-Length: 0\r\nConnection: close\r\n\r\n");
        }
    });
    (Url::parse(&url).unwrap(), hits)
}
fn stalled_http() -> Url {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    thread::spawn(move || {
        let (mut stream, _) = listener.accept().unwrap();
        let mut request = [0u8; 512];
        let _ = stream.read(&mut request);
        thread::sleep(Duration::from_millis(100));
        let _ = write!(
            stream,
            "HTTP/1.1 200 OK\r\nContent-Length: 4\r\nConnection: close\r\n\r\nHEX!"
        );
    });
    Url::parse(&format!("http://{addr}/")).unwrap()
}
fn held_response_http() -> Url {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    thread::spawn(move || {
        let (mut stream, _) = listener.accept().unwrap();
        let mut request = [0u8; 512];
        let _ = stream.read(&mut request);
        let _ = write!(
            stream,
            "HTTP/1.1 200 OK\r\nContent-Length: 100\r\nConnection: keep-alive\r\n\r\nHEX!"
        );
        let _ = stream.flush();
        let mut closed = [0u8; 1];
        let _ = stream.read(&mut closed);
    });
    Url::parse(&format!("http://{addr}/")).unwrap()
}
fn github_release(base: &Url) -> String {
    format!(
        r#"[{{"tag_name":"v1.2.3","html_url":"https://github.com/albertorestifo/trenino_firmware/releases/tag/v1.2.3","body":"notes","published_at":"2026-01-01T00:00:00Z","assets":[{{"id":1,"name":"release.json","size":10,"browser_download_url":"{base}manifest"}},{{"id":2,"name":"uno.hex","size":4,"browser_download_url":"{base}file"}},{{"id":3,"name":"due.bin","size":8,"browser_download_url":"{base}due"}}]}}]"#
    )
}
fn manifest() -> String {
    r#"{"version":"v1.2.3","project":"trenino","devices":[{"environment":"uno","displayName":"Arduino Uno","firmwareFile":"uno.hex","uploadConfig":{"protocol":"arduino","mcu":"atmega328p","speed":115200}},{"environment":"due","displayName":"Arduino Due","firmwareFile":"due.bin","uploadConfig":{"protocol":"sam-ba","mcu":"at91sam3x8e","speed":115200}},{"environment":"missing","displayName":"Missing asset","firmwareFile":"missing.hex","uploadConfig":{"protocol":"avrisp","mcu":"m328p","speed":57600}}]}"#.into()
}
fn catalog_http() -> Url {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    let base = Url::parse(&format!("http://{addr}/")).unwrap();
    let release_body = github_release(&base);
    thread::spawn(move || {
        for _ in 0..2 {
            let (mut stream, _) = listener.accept().unwrap();
            let mut request = [0u8; 4096];
            let _ = stream.read(&mut request);
            let request = String::from_utf8_lossy(&request);
            let body = if request.contains("GET /manifest ") {
                manifest()
            } else {
                release_body.clone()
            };
            write!(stream, "HTTP/1.1 200 OK\r\nContent-Length: {}\r\nConnection: close\r\nContent-Type: application/json\r\n\r\n{body}", body.len()).unwrap();
        }
    });
    base
}

fn catalog_missing_manifest_http() -> Url {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    let base = Url::parse(&format!("http://{addr}/")).unwrap();
    let releases = format!(
        r#"[{{"tag_name":"v1.0.0","assets":[{{"id":11,"name":"release.json","browser_download_url":"{base}a-manifest"}}]}},{{"tag_name":"v1.2.3","assets":[{{"id":22,"name":"release.json","browser_download_url":"{base}b-manifest"}},{{"id":23,"name":"uno.hex","browser_download_url":"{base}uno"}}]}}]"#
    );
    thread::spawn(move || {
        for _ in 0..3 {
            let (mut stream, _) = listener.accept().unwrap();
            let mut request = [0u8; 4096];
            let _ = stream.read(&mut request);
            let request = String::from_utf8_lossy(&request);
            let (status, body) = if request.contains("GET /a-manifest ") {
                (404, "missing".to_owned())
            } else if request.contains("GET /b-manifest ") {
                (200, manifest())
            } else {
                (200, releases.clone())
            };
            let phrase = if status == 200 { "OK" } else { "Not Found" };
            write!(stream, "HTTP/1.1 {status} {phrase}\r\nContent-Length: {}\r\nConnection: close\r\nContent-Type: application/json\r\n\r\n{body}", body.len()).unwrap();
        }
    });
    base
}

fn catalog_server_error_http() -> Url {
    let listener = TcpListener::bind("127.0.0.1:0").unwrap();
    let addr = listener.local_addr().unwrap();
    let base = Url::parse(&format!("http://{addr}/")).unwrap();
    let releases = format!(
        r#"[{{"tag_name":"v2.0.0","assets":[{{"id":22,"name":"release.json","browser_download_url":"{base}manifest"}}]}}]"#
    );
    thread::spawn(move || {
        for index in 0..2 {
            let (mut stream, _) = listener.accept().unwrap();
            let mut request = [0u8; 1024];
            let _ = stream.read(&mut request);
            let (status, body) = if index == 0 {
                (200, releases.clone())
            } else {
                (500, "server error".to_owned())
            };
            write!(
                stream,
                "HTTP/1.1 {status} Error\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
                body.len()
            )
            .unwrap();
        }
    });
    base
}

#[tokio::test]
async fn catalog_requires_release_manifest_and_pins_asset_and_upload_configuration() {
    let endpoint = catalog_http();
    let repo = Arc::new(Repo::default());
    let catalog = FirmwareCatalog::new(
        http_client(),
        repo.clone(),
        FirmwareRequirement::parse(None).unwrap(),
    )
    .with_endpoint(endpoint);
    let releases = catalog.refresh().await.unwrap();
    assert_eq!(releases.len(), 1);
    let selected = catalog.select(releases[0].id, "uno").unwrap();
    assert_eq!(selected.upload_config.normalized_mcu(), "m328p");
    assert_eq!(selected.device.asset.as_ref().unwrap().filename, "uno.hex");
    assert_eq!(
        selected.device.asset.as_ref().unwrap().id,
        trenino_core::EntityId(1)
    );
    assert_eq!(
        selected.device.asset.as_ref().unwrap().github_asset_id,
        Some(2)
    );
    let original = &releases[0];
    let mut refreshed_manifest = original.manifest.clone();
    refreshed_manifest.devices[0].upload_config.speed = 57600;
    let mut refreshed_devices = original.devices.clone();
    refreshed_devices[0].manifest.upload_config.speed = 57600;
    repo.upsert_catalog(&[ReleaseInput {
        version: original.version.clone(),
        tag_name: original.tag_name.clone(),
        release_url: original.release_url.clone(),
        release_notes: original.release_notes.clone(),
        published_at: original.published_at.clone(),
        manifest: refreshed_manifest,
        devices: refreshed_devices,
    }])
    .unwrap();
    assert_eq!(selected.upload_config.speed, 115200);
    assert_eq!(catalog.available_devices(releases[0].id).unwrap().len(), 1);
    assert!(catalog.select(releases[0].id, "due").is_err());
    assert!(catalog.select(releases[0].id, "missing").is_err());
    assert_eq!(
        catalog
            .select(releases[0].id, "missing")
            .unwrap_err()
            .to_string(),
        "firmware release or environment was not found"
    );
}

#[tokio::test]
async fn a_missing_manifest_skips_only_that_release_and_keeps_valid_releases() {
    let repo = Arc::new(Repo::default());
    let catalog = FirmwareCatalog::new(
        http_client(),
        repo,
        FirmwareRequirement::parse(None).unwrap(),
    )
    .with_endpoint(catalog_missing_manifest_http());
    let releases = catalog.refresh().await.unwrap();
    assert_eq!(releases.len(), 1);
    assert_eq!(releases[0].version, "1.2.3");
}

#[tokio::test]
async fn manifest_server_failure_aborts_refresh_without_fake_success() {
    let repo = Arc::new(Repo::default());
    let catalog = FirmwareCatalog::new(
        http_client(),
        repo.clone(),
        FirmwareRequirement::parse(None).unwrap(),
    )
    .with_endpoint(catalog_server_error_http());
    assert!(catalog.refresh().await.is_err());
    assert!(repo.list_releases().unwrap().is_empty());
}

#[tokio::test]
async fn downloader_publishes_only_complete_files_and_reuses_offline_cache() {
    let tmp = TempDir::new().unwrap();
    let endpoint = fake_http(vec![(200, "HEX!".into())]);
    let selection = selection("1.2.3", "uno", endpoint, Some(4));
    let downloader = FirmwareDownloader::new(http_client(), tmp.path(), 1024, 2);
    let result = downloader.download(&selection).await.unwrap();
    assert_eq!(
        result.provenance,
        trenino_runtime::firmware::CacheProvenance::Downloaded
    );
    let path = result.path;
    assert_eq!(std::fs::read(&path).unwrap(), b"HEX!");
    let offline = FirmwareDownloader::new(http_client(), tmp.path(), 1024, 2);
    let cached = offline.download(&selection).await.unwrap();
    assert_eq!(cached.path, path);
    assert_eq!(
        cached.provenance,
        trenino_runtime::firmware::CacheProvenance::ReceiptMatched
    );
    assert!(std::fs::read_dir(tmp.path()).unwrap().all(|e| !e
        .unwrap()
        .file_name()
        .to_string_lossy()
        .ends_with(".partial")));
}

#[tokio::test]
async fn downloading_a_replacement_asset_never_mutates_a_previously_returned_path() {
    let tmp = TempDir::new().unwrap();
    let first = selection(
        "1.2.3",
        "uno",
        fake_http(vec![(200, "OLD!".into())]),
        Some(4),
    );
    let downloader = FirmwareDownloader::new(http_client(), tmp.path(), 1024, 2);
    let first_result = downloader.download(&first).await.unwrap();
    let mut replacement = first.clone();
    replacement.device.asset.as_mut().unwrap().github_asset_id = Some(23);
    replacement.device.asset.as_mut().unwrap().download_url = fake_http(vec![(200, "NEW!".into())]);
    let replacement_result = downloader.download(&replacement).await.unwrap();
    // Different remote assets get distinct immutable destinations even for the
    // same version/environment: consuming the retained first result after the
    // replacement completes still yields the first asset's bytes.
    assert_ne!(replacement_result.path, first_result.path);
    assert_eq!(std::fs::read(&first_result.path).unwrap(), b"OLD!");
    assert_eq!(std::fs::read(&replacement_result.path).unwrap(), b"NEW!");
    // The first asset's association still reuses its own bytes offline.
    let offline = FirmwareDownloader::new(http_client(), tmp.path(), 1024, 2);
    let cached = offline.download(&first).await.unwrap();
    assert_eq!(cached.path, first_result.path);
    assert_eq!(
        cached.provenance,
        trenino_runtime::firmware::CacheProvenance::ReceiptMatched
    );
    assert_eq!(std::fs::read(&cached.path).unwrap(), b"OLD!");
}

#[tokio::test]
async fn failed_receipt_publication_never_falsely_certifies_cache_bytes() {
    let tmp = TempDir::new().unwrap();
    let selected = selection(
        "1.2.3",
        "uno",
        fake_http(vec![(200, "AAAA".into()), (200, "AAAA".into())]),
        Some(4),
    );
    let downloader = FirmwareDownloader::new(http_client(), tmp.path(), 1024, 1);
    let destination = downloader.cache_path(&selected).unwrap();
    let file_name = destination
        .file_name()
        .unwrap()
        .to_str()
        .unwrap()
        .to_owned();
    let receipt = destination.with_file_name(format!("{file_name}.trenino-meta.json"));
    // A directory squatting the receipt name makes the receipt replacement
    // fail deterministically on every platform (rename never replaces a
    // directory), like a held Windows share-mode handle on the receipt file.
    std::fs::create_dir(&receipt).unwrap();
    assert_eq!(
        downloader.download(&selected).await.unwrap_err(),
        trenino_runtime::firmware::DownloadError::CacheIo
    );
    // The data file was published, but no readable receipt certifies it, so a
    // retry must not report a receipt hit for those bytes.
    assert!(std::fs::read(&destination).is_ok());
    assert!(serde_json::from_slice::<serde_json::Value>(
        &std::fs::read(&receipt).unwrap_or_default()
    )
    .is_err());
    assert!(downloader.download(&selected).await.is_err());
    // A different asset publishes independently and never touches the failed
    // destination, and no owned partial files are left behind.
    let mut other = selected.clone();
    other.device.asset.as_mut().unwrap().github_asset_id = Some(99);
    other.device.asset.as_mut().unwrap().download_url = fake_http(vec![(200, "BBBB".into())]);
    let other_result = downloader.download(&other).await.unwrap();
    assert_eq!(std::fs::read(&other_result.path).unwrap(), b"BBBB");
    assert_eq!(std::fs::read(&destination).unwrap(), b"AAAA");
    assert!(std::fs::read_dir(tmp.path())
        .unwrap()
        .filter_map(Result::ok)
        .all(|entry| !entry.file_name().to_string_lossy().contains(".partial")));
}

#[tokio::test]
async fn concurrent_different_assets_for_one_environment_are_each_fetched_once() {
    let tmp = TempDir::new().unwrap();
    let (url_a, hits_a) = counted_http("AAAA");
    let (url_b, hits_b) = counted_http("BBBB");
    let mut selection_a = selection("1.2.3", "uno", url_a, Some(4));
    let mut selection_b = selection("1.2.3", "uno", url_b, Some(4));
    selection_a.device.asset.as_mut().unwrap().github_asset_id = Some(101);
    selection_b.device.asset.as_mut().unwrap().github_asset_id = Some(202);
    let downloader = Arc::new(FirmwareDownloader::new(http_client(), tmp.path(), 1024, 2));
    let d1 = downloader.clone();
    let s1 = selection_a;
    let d2 = downloader.clone();
    let s2 = selection_b;
    let (a, b) = tokio::join!(async move { d1.download(&s1).await }, async move {
        d2.download(&s2).await
    });
    let a = a.unwrap();
    let b = b.unwrap();
    // Each pinned asset resolves its own immutable destination and bytes.
    assert_eq!(
        a.provenance,
        trenino_runtime::firmware::CacheProvenance::Downloaded
    );
    assert_eq!(
        b.provenance,
        trenino_runtime::firmware::CacheProvenance::Downloaded
    );
    assert_ne!(a.path, b.path);
    assert_eq!(std::fs::read(&a.path).unwrap(), b"AAAA");
    assert_eq!(std::fs::read(&b.path).unwrap(), b"BBBB");
    assert_eq!(hits_a.load(std::sync::atomic::Ordering::SeqCst), 1);
    assert_eq!(hits_b.load(std::sync::atomic::Ordering::SeqCst), 1);
}

#[tokio::test]
async fn a_valid_unambiguous_legacy_cache_path_is_reused_offline() {
    let tmp = TempDir::new().unwrap();
    let selected = selection("1.2.3", "uno", fake_http(vec![]), Some(4));
    let legacy_path = tmp.path().join("v1.2.3_uno.hex");
    std::fs::write(&legacy_path, b"OLD!").unwrap();
    let unrelated_path = tmp.path().join("keep-me.txt");
    std::fs::write(&unrelated_path, b"unrelated").unwrap();
    let downloader = FirmwareDownloader::new(http_client(), tmp.path(), 1024, 1)
        .with_legacy_cache_policy(
            trenino_runtime::firmware::LegacyCachePolicy::AllowUnverifiedMatchingPath,
        );
    let cached = downloader.download(&selected).await.unwrap();
    assert_eq!(cached.path, legacy_path);
    assert_eq!(
        cached.provenance,
        trenino_runtime::firmware::CacheProvenance::LegacyUnverified
    );
    assert_eq!(std::fs::read(&cached.path).unwrap(), b"OLD!");
    assert_eq!(std::fs::read(unrelated_path).unwrap(), b"unrelated");
}

#[tokio::test]
async fn downloader_rejects_truncated_assets_and_cleans_partial_files() {
    let tmp = TempDir::new().unwrap();
    let endpoint = fake_http(vec![(200, "HEX".into())]);
    let selection = selection("1.2.3", "uno", endpoint, Some(4));
    let downloader = FirmwareDownloader::new(http_client(), tmp.path(), 1024, 1);
    assert!(downloader.download(&selection).await.is_err());
    assert_eq!(
        std::fs::read_dir(tmp.path())
            .map(|x| x.count())
            .unwrap_or(0),
        0
    );
}

#[tokio::test]
async fn downloader_rejects_empty_assets_with_known_or_unknown_size() {
    for size in [Some(0), None] {
        let tmp = TempDir::new().unwrap();
        let selected = selection("1.2.3", "uno", fake_http(vec![(200, String::new())]), size);
        let downloader = FirmwareDownloader::new(http_client(), tmp.path(), 1024, 1);
        assert!(downloader.download(&selected).await.is_err());
        assert_eq!(std::fs::read_dir(tmp.path()).unwrap().count(), 0);
    }
}

#[tokio::test]
async fn concurrent_downloads_of_the_same_asset_share_one_complete_cache_file() {
    let tmp = TempDir::new().unwrap();
    let endpoint = fake_http(vec![(200, "HEX!".into())]);
    let selection = selection("1.2.3", "uno", endpoint, Some(4));
    let downloader = Arc::new(FirmwareDownloader::new(http_client(), tmp.path(), 1024, 2));
    let d1 = downloader.clone();
    let s1 = selection.clone();
    let d2 = downloader.clone();
    let s2 = selection;
    let (a, b) = tokio::join!(async move { d1.download(&s1).await }, async move {
        d2.download(&s2).await
    });
    assert_eq!(a.unwrap().path, b.unwrap().path);
    // The final firmware and its provenance receipt are published together.
    assert_eq!(std::fs::read_dir(tmp.path()).unwrap().count(), 2);
}

#[tokio::test]
async fn downloader_refuses_non_success_status_without_cache_files() {
    let tmp = TempDir::new().unwrap();
    let endpoint = fake_http(vec![(404, "missing".into())]);
    let selection = selection("1.2.3", "uno", endpoint, Some(4));
    let downloader = FirmwareDownloader::new(http_client(), tmp.path(), 1024, 1);
    assert!(matches!(
        downloader.download(&selection).await,
        Err(trenino_runtime::firmware::DownloadError::Status(404))
    ));
    assert_eq!(std::fs::read_dir(tmp.path()).unwrap().count(), 0);
}

#[tokio::test]
async fn downloader_enforces_the_configured_stream_size_bound() {
    let tmp = TempDir::new().unwrap();
    let selection = selection(
        "1.2.3",
        "uno",
        fake_http(vec![(200, "FOUR".into())]),
        Some(4),
    );
    let downloader = FirmwareDownloader::new(http_client(), tmp.path(), 3, 1);
    assert!(matches!(
        downloader.download(&selection).await,
        Err(trenino_runtime::firmware::DownloadError::TooLarge)
    ));
    assert_eq!(std::fs::read_dir(tmp.path()).unwrap().count(), 0);
}

#[tokio::test]
async fn downloader_timeout_leaves_no_partial_cache_file() {
    let tmp = TempDir::new().unwrap();
    let selection = selection("1.2.3", "uno", stalled_http(), Some(4));
    let downloader = FirmwareDownloader::new(http_client(), tmp.path(), 1024, 1)
        .with_timeout(Duration::from_millis(10));
    assert!(downloader.download(&selection).await.is_err());
    assert_eq!(std::fs::read_dir(tmp.path()).unwrap().count(), 0);
}

#[tokio::test]
async fn cancelling_a_streaming_download_removes_its_partial_file() {
    let tmp = TempDir::new().unwrap();
    let selection = selection("1.2.3", "uno", held_response_http(), None);
    let downloader = Arc::new(FirmwareDownloader::new(http_client(), tmp.path(), 1024, 1));
    let d = downloader.clone();
    let task = tokio::spawn(async move { d.download(&selection).await });
    let mut partial_seen = false;
    for _ in 0..100 {
        partial_seen = std::fs::read_dir(tmp.path())
            .map(|entries| {
                entries
                    .filter_map(Result::ok)
                    .any(|e| e.file_name().to_string_lossy().ends_with(".partial"))
            })
            .unwrap_or(false);
        if partial_seen {
            break;
        }
        tokio::time::sleep(Duration::from_millis(2)).await;
    }
    assert!(
        partial_seen,
        "transfer should have created a partial file before cancellation"
    );
    task.abort();
    let _ = task.await;
    assert_eq!(std::fs::read_dir(tmp.path()).unwrap().count(), 0);
}

#[tokio::test]
async fn downloader_rejects_non_loopback_http_urls() {
    let tmp = TempDir::new().unwrap();
    let selection = selection(
        "1.2.3",
        "uno",
        Url::parse("http://example.com/file").unwrap(),
        Some(4),
    );
    let downloader = FirmwareDownloader::new(http_client(), tmp.path(), 1024, 1);
    assert!(matches!(
        downloader.download(&selection).await,
        Err(trenino_runtime::firmware::DownloadError::InvalidUrl)
    ));
}

#[tokio::test]
async fn firmware_http_boundary_blocks_disallowed_redirect_hops_and_bounds_chains() {
    let client = FirmwareHttpClient::new(Duration::from_secs(1)).unwrap();
    let (target, hits) = counted_http("unsafe");
    let blocked = one_redirect(disallowed_with_userinfo(&target));
    assert!(client.get(&blocked).unwrap().send().await.is_err());
    tokio::time::sleep(Duration::from_millis(20)).await;
    assert_eq!(hits.load(std::sync::atomic::Ordering::SeqCst), 0);

    let tmp = TempDir::new().unwrap();
    let (download_target, download_hits) = counted_http("unsafe");
    let download_redirect = one_redirect(disallowed_with_userinfo(&download_target));
    let selected = selection("1.2.3", "uno", download_redirect, Some(4));
    let downloader = FirmwareDownloader::new(client.clone(), tmp.path(), 1024, 1);
    assert!(downloader.download(&selected).await.is_err());
    assert_eq!(std::fs::read_dir(tmp.path()).unwrap().count(), 0);
    tokio::time::sleep(Duration::from_millis(20)).await;
    assert_eq!(download_hits.load(std::sync::atomic::Ordering::SeqCst), 0);

    let (allowed_target, allowed_hits) = counted_http("ok");
    let allowed = one_redirect(allowed_target.to_string());
    let response = client.get(&allowed).unwrap().send().await.unwrap();
    assert_eq!(response.text().await.unwrap(), "ok");
    assert_eq!(allowed_hits.load(std::sync::atomic::Ordering::SeqCst), 1);

    let (loop_url, loop_hits) = redirect_loop_http();
    assert!(client.get(&loop_url).unwrap().send().await.is_err());
    assert!(loop_hits.load(std::sync::atomic::Ordering::SeqCst) <= 6);
}

#[test]
fn cache_path_rejects_untrusted_environment_components() {
    let tmp = TempDir::new().unwrap();
    let selection = selection(
        "1.2.3",
        "../escape",
        Url::parse("https://example.test/file").unwrap(),
        Some(1),
    );
    let downloader = FirmwareDownloader::new(http_client(), tmp.path(), 1024, 1);
    assert!(downloader.cache_path(&selection).is_err());
    assert_eq!(
        FirmwareDownloader::cache_directory(
            true,
            std::path::Path::new("C:/Users/example"),
            std::path::Path::new("app")
        ),
        std::path::PathBuf::from("C:/Users/example/.trenino/firmware_cache")
    );
    assert_eq!(
        FirmwareDownloader::cache_directory(
            false,
            std::path::Path::new("home"),
            std::path::Path::new("app")
        ),
        std::path::PathBuf::from("app/priv/firmware_cache")
    );
}

#[test]
fn cache_path_prefers_environment_and_falls_back_to_board_type() {
    let tmp = TempDir::new().unwrap();
    let mut selected = selection(
        "1.2.3",
        "uno",
        Url::parse("https://example.test/uno.hex").unwrap(),
        Some(4),
    );
    selected.device.asset.as_mut().unwrap().board_type = "legacy_board".into();
    let downloader = FirmwareDownloader::new(http_client(), tmp.path(), 1024, 1);
    let named = |path: std::path::PathBuf| path.file_name().unwrap().to_str().unwrap().to_owned();
    // Asset-bound names extend the legacy stem with a provenance key.
    let environment_name = named(downloader.cache_path(&selected).unwrap());
    let key = environment_name
        .strip_prefix("v1.2.3_uno.")
        .and_then(|stem| stem.strip_suffix(".hex"))
        .unwrap();
    assert_eq!(key.len(), 16);
    assert!(key.bytes().all(|byte| byte.is_ascii_hexdigit()));
    selected.device.asset.as_mut().unwrap().environment = None;
    let board_name = named(downloader.cache_path(&selected).unwrap());
    assert!(board_name.starts_with("v1.2.3_legacy_board."));
    assert!(board_name.ends_with(".hex"));
    let build_version = selection(
        "1.2.3+build.1",
        "uno",
        Url::parse("https://example.test/uno.hex").unwrap(),
        Some(4),
    );
    assert!(downloader.cache_path(&build_version).is_ok());
    // Two remote assets for one environment resolve distinct destinations.
    let mut other = selected.clone();
    other.device.asset.as_mut().unwrap().github_asset_id = Some(99);
    assert_ne!(
        downloader.cache_path(&selected).unwrap(),
        downloader.cache_path(&other).unwrap()
    );
}

#[test]
fn scheduler_persists_before_publishing_and_respects_rate_limit_and_dismissal() {
    let repo = Arc::new(Repo::default());
    let cfg = SchedulerConfig {
        startup_delay: Duration::from_secs(5),
        cadence: Duration::from_secs(86400),
        min_interval: Duration::from_secs(3600),
    };
    let mut scheduler = FirmwareUpdateScheduler::new(repo.clone(), cfg).unwrap();
    assert_eq!(scheduler.startup_at(0).unwrap(), 5000);
    assert_eq!(scheduler.next_periodic_at(0).unwrap(), 86_400_000);
    assert!(matches!(
        scheduler
            .record_check(
                UpdateCheckRecord {
                    checked_at_ms: 1,
                    found_updates: true,
                    latest_version: Some("2.0.0".into()),
                    error_message: None
                },
                1
            )
            .unwrap(),
        trenino_runtime::firmware::CheckOutcome::Persisted(_)
    ));
    let devices = [ConnectedFirmware {
        device_id: trenino_core::EntityId(10),
        connected: true,
        version: Some("1.0.0".into()),
    }];
    assert!(scheduler.notice(&devices).is_some());
    scheduler.dismiss(&devices).unwrap();
    assert!(scheduler.notice(&devices).is_none());
    scheduler.dismiss(&devices).unwrap();
    scheduler.dismiss(&[]).unwrap();
    assert!(scheduler.notice(&devices).is_none());
    let restored = FirmwareUpdateScheduler::new(repo.clone(), cfg).unwrap();
    assert!(restored.notice(&devices).is_none());
    let new_device = [
        devices[0].clone(),
        ConnectedFirmware {
            device_id: trenino_core::EntityId(11),
            connected: true,
            version: Some("1.0.0".into()),
        },
    ];
    assert!(restored.notice(&new_device).is_some());
    assert!(matches!(
        scheduler
            .record_check(
                UpdateCheckRecord {
                    checked_at_ms: 2,
                    found_updates: false,
                    latest_version: None,
                    error_message: None
                },
                2
            )
            .unwrap(),
        trenino_runtime::firmware::CheckOutcome::RateLimited
    ));
}

#[test]
fn failed_dismissal_persistence_preserves_current_notice() {
    let repo = Arc::new(Repo::default());
    let mut scheduler =
        FirmwareUpdateScheduler::new(repo.clone(), SchedulerConfig::default()).unwrap();
    scheduler
        .record_check(
            UpdateCheckRecord {
                checked_at_ms: 1,
                found_updates: true,
                latest_version: Some("2.0.0".into()),
                error_message: None,
            },
            1,
        )
        .unwrap();
    let devices = [ConnectedFirmware {
        device_id: trenino_core::EntityId(30),
        connected: true,
        version: Some("1.0.0".into()),
    }];
    assert!(scheduler.notice(&devices).is_some());
    *repo.fail_dismiss.lock().unwrap() = true;
    assert!(scheduler.dismiss(&devices).is_err());
    assert!(scheduler.notice(&devices).is_some());
}

#[test]
fn scheduler_does_not_report_check_success_when_persistence_fails() {
    let repo = Arc::new(Repo::default());
    let mut scheduler =
        FirmwareUpdateScheduler::new(repo.clone(), SchedulerConfig::default()).unwrap();
    *repo.fail_check.lock().unwrap() = true;
    assert!(scheduler
        .record_check(
            UpdateCheckRecord {
                checked_at_ms: 1000,
                found_updates: true,
                latest_version: Some("2.0.0".into()),
                error_message: None
            },
            1000
        )
        .is_err());
    assert_eq!(scheduler.status().checked_at_ms, None);
}

fn selection(version: &str, environment: &str, url: Url, size: Option<u64>) -> FirmwareSelection {
    let manifest: FirmwareManifest = serde_json::from_str(&format!(r#"{{"version":"{version}","project":"trenino","devices":[{{"environment":"{environment}","displayName":"Uno","firmwareFile":"uno.hex","uploadConfig":{{"protocol":"arduino","mcu":"atmega328p","speed":115200}}}}]}}"#)).unwrap();
    let device = FirmwareDevice {
        manifest: manifest.devices[0].clone(),
        asset: Some(FirmwareAsset {
            id: trenino_core::EntityId(22),
            github_asset_id: Some(22),
            filename: "uno.hex".into(),
            download_url: url,
            size,
            environment: Some(environment.into()),
            board_type: environment.into(),
        }),
    };
    FirmwareSelection {
        release_id: trenino_core::EntityId(4),
        version: version.into(),
        upload_config: UploadConfig {
            protocol: Programmer::Arduino,
            mcu: "atmega328p".into(),
            speed: 115200,
            requires_1200bps_touch: false,
        },
        device,
    }
}
