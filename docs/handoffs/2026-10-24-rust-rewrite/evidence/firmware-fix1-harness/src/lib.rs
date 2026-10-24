extern crate self as trenino_runtime;
#[path = "C:/Users/Alberto/.codex/worktrees/rust-rewrite/tsw_io/crates/trenino-runtime/src/firmware/mod.rs"]
pub mod firmware;
#[cfg(test)]
mod probes {
include!("C:/Users/Alberto/.codex/worktrees/rust-rewrite/tsw_io/crates/trenino-runtime/tests/firmware_catalog.rs");
#[tokio::test]
async fn fix1_success_overwrites_previously_returned_pinned_path() {
 let temp = TempDir::new().unwrap();
 let a = selection("1.2.3", "uno", fake_http(vec![(200, "AAAA".into())]), Some(4));
 let mut b = a.clone();
 b.device.asset.as_mut().unwrap().github_asset_id = Some(99);
 b.device.asset.as_mut().unwrap().download_url = fake_http(vec![(200, "BBBB".into())]);
 let downloader = FirmwareDownloader::new(http_client(), temp.path(), 1024, 2);
 let a_result = downloader.download(&a).await.unwrap();
 let b_result = downloader.download(&b).await.unwrap();
 assert_eq!(a_result.path, b_result.path);
 assert_eq!(std::fs::read(a_result.path).unwrap(), b"BBBB");
}
#[cfg(windows)]
#[tokio::test]
async fn fix1_receipt_failure_associates_new_bytes_with_old_asset() {
 use std::os::windows::fs::OpenOptionsExt;
 let temp = TempDir::new().unwrap();
 let a = selection("1.2.3", "uno", fake_http(vec![(200, "AAAA".into())]), Some(4));
 let mut b = a.clone();
 b.device.asset.as_mut().unwrap().github_asset_id = Some(99);
 b.device.asset.as_mut().unwrap().download_url = fake_http(vec![(200, "BBBB".into())]);
 let downloader = FirmwareDownloader::new(http_client(), temp.path(), 1024, 2);
 let a_result = downloader.download(&a).await.unwrap();
 let receipt = a_result.path.with_file_name("v1.2.3_uno.hex.trenino-meta.json");
 let locked = std::fs::OpenOptions::new().read(true).share_mode(1).open(&receipt).unwrap();
 assert_eq!(downloader.download(&b).await.unwrap_err(), trenino_runtime::firmware::DownloadError::CacheIo);
 assert_eq!(std::fs::read(&a_result.path).unwrap(), b"BBBB");
 drop(locked);
 let reused = downloader.download(&a).await.unwrap();
 assert_eq!(reused.provenance, trenino_runtime::firmware::CacheProvenance::ReceiptMatched);
 assert_eq!(std::fs::read(reused.path).unwrap(), b"BBBB");
}
#[test]
fn fix1_prerelease_conjunction_differs_from_elixir() {
 assert!(FirmwareRequirement::parse(Some(">= 1.0.0 and < 1.2.3")).unwrap().matches("1.2.3-rc.2"));
 for input in ["~> 1.2+build.1", "~> 1.2-rc.1"] {
   assert!(FirmwareRequirement::parse(Some(input)).is_err());
 }
}
}
