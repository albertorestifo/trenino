use std::{
    future::Future,
    sync::{
        atomic::{AtomicUsize, Ordering},
        Arc, Mutex,
    },
    task::Poll,
    time::Duration,
};
use trenino_core::EntityId;
use trenino_runtime::{
    firmware::{owner::*, *},
    simulator::services::clock::{Clock, FakeClock},
};
#[derive(Default)]
struct Repo {
    check: Mutex<Option<UpdateCheckRecord>>,
    dismissed: Mutex<Option<String>>,
    fail: Mutex<bool>,
    block: Mutex<Option<(std::sync::mpsc::Sender<()>, std::sync::mpsc::Receiver<()>)>>,
}
impl FirmwareRepository for Repo {
    fn upsert_catalog(&self, _: &[ReleaseInput]) -> Result<Vec<CatalogRelease>, RepositoryError> {
        Ok(vec![])
    }
    fn list_releases(&self) -> Result<Vec<CatalogRelease>, RepositoryError> {
        Ok(vec![])
    }
    fn get_release(&self, _: EntityId) -> Result<Option<CatalogRelease>, RepositoryError> {
        Ok(None)
    }
    fn latest_check(&self) -> Result<Option<UpdateCheckRecord>, RepositoryError> {
        Ok(self.check.lock().unwrap().clone())
    }
    fn record_check(&self, value: &UpdateCheckRecord) -> Result<(), RepositoryError> {
        if let Some((entered, release)) = self.block.lock().unwrap().take() {
            entered.send(()).unwrap();
            release.recv().unwrap();
        }
        if *self.fail.lock().unwrap() {
            return Err(RepositoryError { code: "injected" });
        }
        *self.check.lock().unwrap() = Some(value.clone());
        Ok(())
    }
    fn dismissed_notice(&self) -> Result<Option<String>, RepositoryError> {
        Ok(self.dismissed.lock().unwrap().clone())
    }
    fn set_dismissed_notice(&self, key: Option<&str>) -> Result<(), RepositoryError> {
        *self.dismissed.lock().unwrap() = key.map(str::to_owned);
        Ok(())
    }
}
struct FakeHttp {
    calls: AtomicUsize,
    active: Arc<AtomicUsize>,
    permits: tokio::sync::Semaphore,
    result: Mutex<Result<Option<String>, String>>,
}
impl FakeHttp {
    fn new() -> Self {
        Self {
            calls: AtomicUsize::new(0),
            active: Arc::default(),
            permits: tokio::sync::Semaphore::new(0),
            result: Mutex::new(Ok(Some("1.2.0".into()))),
        }
    }
}
impl FirmwareCheckPort for FakeHttp {
    fn check(&self) -> CheckFuture<'_> {
        Box::pin(async move {
            struct Active(Arc<AtomicUsize>);
            impl Drop for Active {
                fn drop(&mut self) {
                    self.0.fetch_sub(1, Ordering::SeqCst);
                }
            }
            self.calls.fetch_add(1, Ordering::SeqCst);
            self.active.fetch_add(1, Ordering::SeqCst);
            let _active = Active(self.active.clone());
            self.permits.acquire().await.unwrap().forget();
            self.result
                .lock()
                .unwrap()
                .clone()
                .map(|latest_version| FirmwareCheckResult {
                    found_updates: latest_version.is_some(),
                    latest_version,
                })
        })
    }
}
async fn until(mut predicate: impl FnMut() -> bool) {
    tokio::time::timeout(Duration::from_secs(3), async {
        while !predicate() {
            tokio::time::sleep(Duration::from_millis(1)).await;
        }
    })
    .await
    .unwrap();
}
fn inventory() -> FirmwareInventory {
    FirmwareInventory {
        configured: vec![ConnectedFirmware {
            device_id: EntityId(7),
            connected: true,
            version: Some("1.0.0".into()),
        }],
        unconfigured: vec![ConnectedUnconfiguredFirmware {
            port: "COM9".into(),
            connected: true,
            version: Some("1.0.1".into()),
        }],
    }
}
fn start(
    repo: Arc<Repo>,
    http: Arc<FakeHttp>,
    clock: Arc<FakeClock>,
    epoch: u64,
) -> Arc<FirmwareUpdateOwner> {
    Arc::new(
        FirmwareUpdateOwner::start(repo, http, clock, epoch, SchedulerConfig::default()).unwrap(),
    )
}

#[tokio::test]
async fn startup_cadence_manual_coalescing_and_persisted_rate_limit_share_one_owner() {
    let repo = Arc::new(Repo::default());
    let http = Arc::new(FakeHttp::new());
    let clock = Arc::new(FakeClock::new());
    let published = Arc::new(AtomicUsize::new(0));
    let count = published.clone();
    let owner = Arc::new(
        FirmwareUpdateOwner::start_with_observer(
            repo.clone(),
            http.clone(),
            clock.clone(),
            10_000_000,
            Default::default(),
            Arc::new(move || {
                count.fetch_add(1, Ordering::SeqCst);
            }),
        )
        .unwrap(),
    );
    until(|| !clock.pending_deadlines().is_empty()).await;
    clock.advance(Duration::from_secs(4));
    assert_eq!(http.calls.load(Ordering::SeqCst), 0);
    clock.advance(Duration::from_secs(1));
    until(|| http.calls.load(Ordering::SeqCst) == 1).await;
    assert!(owner.status(inventory()).await.unwrap().check.checking);
    let mut a = Box::pin(owner.check());
    let mut b = Box::pin(owner.check());
    std::future::poll_fn(|cx| {
        assert!(a.as_mut().poll(cx).is_pending());
        assert!(b.as_mut().poll(cx).is_pending());
        Poll::Ready(())
    })
    .await;
    // Both requests have been enqueued; this later status request is an actor barrier.
    assert!(owner.status(inventory()).await.unwrap().check.checking);
    assert_eq!(http.calls.load(Ordering::SeqCst), 1);
    http.permits.add_permits(1);
    a.await.unwrap();
    b.await.unwrap();
    assert_eq!(published.load(Ordering::SeqCst), 1);
    assert_eq!(http.calls.load(Ordering::SeqCst), 1);
    http.permits.add_permits(1);
    owner.check().await.unwrap();
    assert_eq!(http.calls.load(Ordering::SeqCst), 2);
    owner.shutdown(Duration::from_secs(1)).unwrap();
    let restarted = start(repo.clone(), http.clone(), clock.clone(), 10_005_000);
    until(|| !clock.pending_deadlines().is_empty()).await;
    clock.advance(Duration::from_secs(5));
    // Status command is a barrier after the timer; eventual poll lets it rearm.
    until(|| {
        clock
            .pending_deadlines()
            .iter()
            .any(|d| *d >= clock.now() + Duration::from_secs(24 * 3600))
    })
    .await;
    assert_eq!(
        http.calls.load(Ordering::SeqCst),
        2,
        "automatic startup must respect persisted cooldown"
    );
    clock.advance(Duration::from_secs(24 * 3600));
    until(|| http.calls.load(Ordering::SeqCst) == 3).await;
    http.permits.add_permits(1);
    until(|| repo.check.lock().unwrap().as_ref().unwrap().checked_at_ms > 10_005_000).await;
    restarted.shutdown(Duration::from_secs(1)).unwrap();
}

#[tokio::test]
async fn connected_and_unconfigured_notices_dismiss_persistently_and_new_ports_reappear() {
    let repo = Arc::new(Repo::default());
    let http = Arc::new(FakeHttp::new());
    let clock = Arc::new(FakeClock::new());
    let owner = start(repo.clone(), http.clone(), clock.clone(), 20_000_000);
    http.permits.add_permits(1);
    owner.check().await.unwrap();
    let status = owner.status(inventory()).await.unwrap();
    let notice = status.notice.unwrap();
    assert_eq!(notice.outdated_devices, vec![EntityId(7)]);
    assert_eq!(notice.outdated_ports, vec!["COM9"]);
    assert!(owner
        .status(FirmwareInventory::default())
        .await
        .unwrap()
        .notice
        .is_none());
    assert!(owner.dismiss(inventory()).await.unwrap().notice.is_none());
    owner.shutdown(Duration::from_secs(1)).unwrap();
    let restarted = start(repo, http, clock, 20_001_000);
    assert!(restarted
        .status(inventory())
        .await
        .unwrap()
        .notice
        .is_none());
    let mut changed = inventory();
    changed.unconfigured[0].port = "COM10".into();
    assert!(restarted.status(changed).await.unwrap().notice.is_some());
    restarted.shutdown(Duration::from_secs(1)).unwrap();
}

#[tokio::test]
async fn http_and_repository_errors_are_visible_and_shutdown_cancels_pending_http() {
    let repo = Arc::new(Repo::default());
    let http = Arc::new(FakeHttp::new());
    let clock = Arc::new(FakeClock::new());
    *http.result.lock().unwrap() = Err("offline".into());
    let owner = start(repo.clone(), http.clone(), clock.clone(), 30_000_000);
    http.permits.add_permits(1);
    assert_eq!(owner.check().await, Err("offline".into()));
    assert_eq!(
        owner
            .status(inventory())
            .await
            .unwrap()
            .check
            .error_message
            .as_deref(),
        Some("offline")
    );
    clock.advance(Duration::from_secs(3600));
    *repo.fail.lock().unwrap() = true;
    http.permits.add_permits(1);
    assert!(owner.check().await.unwrap_err().contains("persistence"));
    assert!(owner
        .status(inventory())
        .await
        .unwrap()
        .check
        .error_message
        .unwrap()
        .contains("persistence"));
    let pending = {
        let owner = owner.clone();
        tokio::spawn(async move { owner.check().await })
    };
    until(|| http.active.load(Ordering::SeqCst) == 1).await;
    owner.shutdown(Duration::from_secs(1)).unwrap();
    assert!(pending.await.unwrap().is_err());
    assert_eq!(http.active.load(Ordering::SeqCst), 0);
    assert!(owner.check().await.is_err());
    owner.shutdown(Duration::from_secs(1)).unwrap();
}

#[tokio::test]
async fn blocked_persistence_retains_join_for_retry_before_database_close() {
    let repo = Arc::new(Repo::default());
    let http = Arc::new(FakeHttp::new());
    let clock = Arc::new(FakeClock::new());
    let (entered_tx, entered_rx) = std::sync::mpsc::channel();
    let (release_tx, release_rx) = std::sync::mpsc::channel();
    *repo.block.lock().unwrap() = Some((entered_tx, release_rx));
    let owner = start(repo.clone(), http.clone(), clock, 40_000_000);
    http.permits.add_permits(1);
    let pending = {
        let owner = owner.clone();
        tokio::spawn(async move { owner.check().await })
    };
    tokio::task::spawn_blocking(move || entered_rx.recv_timeout(Duration::from_secs(2)).unwrap())
        .await
        .unwrap();
    assert!(owner.shutdown(Duration::from_millis(20)).is_err());
    release_tx.send(()).unwrap();
    owner.shutdown(Duration::from_secs(1)).unwrap();
    let _ = pending.await.unwrap();
    assert!(owner.status(inventory()).await.is_err());
    let after = repo.check.lock().unwrap().clone();
    tokio::time::sleep(Duration::from_millis(10)).await;
    assert_eq!(*repo.check.lock().unwrap(), after);
}

#[tokio::test]
async fn panicked_owner_cannot_report_success_on_later_shutdown_retry() {
    struct PanicCheck;
    impl FirmwareCheckPort for PanicCheck {
        fn check(&self) -> CheckFuture<'_> {
            Box::pin(async { panic!("injected check panic") })
        }
    }
    let owner = FirmwareUpdateOwner::start(
        Arc::new(Repo::default()),
        Arc::new(PanicCheck),
        Arc::new(FakeClock::new()),
        0,
        Default::default(),
    )
    .unwrap();
    assert!(owner.check().await.is_err());
    assert!(owner.shutdown(Duration::from_secs(1)).is_err());
    assert!(owner.shutdown(Duration::from_secs(1)).is_err());
}

#[tokio::test]
async fn manual_retry_after_failed_automatic_check_bypasses_cooldown() {
    let repo = Arc::new(Repo::default());
    let http = Arc::new(FakeHttp::new());
    let clock = Arc::new(FakeClock::new());
    *http.result.lock().unwrap() = Err("offline".into());
    let owner = start(repo.clone(), http.clone(), clock.clone(), 50_000_000);
    until(|| !clock.pending_deadlines().is_empty()).await;
    http.permits.add_permits(1);
    clock.advance(Duration::from_secs(5));
    until(|| repo.check.lock().unwrap().is_some()).await;
    assert_eq!(
        owner
            .status(inventory())
            .await
            .unwrap()
            .check
            .error_message
            .as_deref(),
        Some("offline")
    );
    *http.result.lock().unwrap() = Ok(Some("1.2.0".into()));
    http.permits.add_permits(1);
    owner.check().await.unwrap();
    assert_eq!(http.calls.load(Ordering::SeqCst), 2);
    assert_eq!(
        owner.status(inventory()).await.unwrap().check.error_message,
        None
    );
    owner.shutdown(Duration::from_secs(1)).unwrap();
}

#[tokio::test]
async fn failed_manual_refresh_preserves_known_notice_and_later_success_replaces_it() {
    let repo = Arc::new(Repo::default());
    let http = Arc::new(FakeHttp::new());
    let clock = Arc::new(FakeClock::new());
    let owner = start(repo.clone(), http.clone(), clock, 60_000_000);
    http.permits.add_permits(1);
    owner.check().await.unwrap();
    let known = owner.status(inventory()).await.unwrap().notice.unwrap();
    assert_eq!(known.version, "1.2.0");
    *http.result.lock().unwrap() = Err("temporary offline".into());
    http.permits.add_permits(1);
    assert!(owner.check().await.is_err());
    let failed = owner.status(inventory()).await.unwrap();
    assert_eq!(
        failed.check.error_message.as_deref(),
        Some("temporary offline")
    );
    assert_eq!(failed.notice, Some(known));
    let persisted = repo.check.lock().unwrap().clone().unwrap();
    assert_eq!(persisted.latest_version, None);
    assert_eq!(
        persisted.error_message.as_deref(),
        Some("temporary offline")
    );
    *http.result.lock().unwrap() = Ok(Some("1.3.0".into()));
    http.permits.add_permits(1);
    owner.check().await.unwrap();
    let next = owner.status(inventory()).await.unwrap();
    assert_eq!(next.check.error_message, None);
    assert_eq!(next.notice.unwrap().version, "1.3.0");
    *http.result.lock().unwrap() = Ok(None);
    http.permits.add_permits(1);
    owner.check().await.unwrap();
    let incompatible = owner.status(inventory()).await.unwrap();
    assert!(incompatible.notice.is_none());
    assert_eq!(
        incompatible.check.error_message.as_deref(),
        Some("No compatible firmware releases found.")
    );
    owner.shutdown(Duration::from_secs(1)).unwrap();
}

#[test]
fn scheduler_failed_history_preserves_warm_latest_but_empty_success_clears_it() {
    let repo = Arc::new(Repo::default());
    let mut scheduler = FirmwareUpdateScheduler::new(repo.clone(), Default::default()).unwrap();
    scheduler.begin_check_with_force(1000, true);
    scheduler
        .record_check(
            UpdateCheckRecord {
                checked_at_ms: 1000,
                found_updates: true,
                latest_version: Some("1.2.0".into()),
                error_message: None,
            },
            1000,
        )
        .unwrap();
    scheduler.begin_check_with_force(2000, true);
    scheduler
        .record_failed_check(
            UpdateCheckRecord {
                checked_at_ms: 2000,
                found_updates: false,
                latest_version: None,
                error_message: Some("offline".into()),
            },
            2000,
        )
        .unwrap();
    assert_eq!(scheduler.status().latest_version.as_deref(), Some("1.2.0"));
    assert_eq!(scheduler.status().error_message.as_deref(), Some("offline"));
    assert_eq!(
        repo.check.lock().unwrap().as_ref().unwrap().latest_version,
        None
    );
    scheduler.begin_check_with_force(3000, true);
    scheduler
        .record_check(
            UpdateCheckRecord {
                checked_at_ms: 3000,
                found_updates: false,
                latest_version: None,
                error_message: Some("No compatible firmware releases found.".into()),
            },
            3000,
        )
        .unwrap();
    assert_eq!(scheduler.status().latest_version, None);
}
