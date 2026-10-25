use super::{FirmwareRepository, RepositoryError};
use std::{future::Future, sync::Arc, time::Duration};
use tokio::{sync::watch, task::JoinHandle};
use trenino_core::firmware::FirmwareVersion;
use trenino_core::EntityId;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct SchedulerConfig {
    pub startup_delay: Duration,
    pub cadence: Duration,
    pub min_interval: Duration,
}
impl Default for SchedulerConfig {
    fn default() -> Self {
        Self {
            startup_delay: Duration::from_secs(5),
            cadence: Duration::from_secs(24 * 60 * 60),
            min_interval: Duration::from_secs(60 * 60),
        }
    }
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UpdateCheckRecord {
    pub checked_at_ms: u64,
    pub found_updates: bool,
    pub latest_version: Option<String>,
    pub error_message: Option<String>,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct CheckStatus {
    pub checking: bool,
    pub checked_at_ms: Option<u64>,
    pub found_updates: bool,
    pub latest_version: Option<String>,
    pub error_message: Option<String>,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ConnectedFirmware {
    pub device_id: EntityId,
    pub connected: bool,
    pub version: Option<String>,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ConnectedUnconfiguredFirmware {
    pub port: String,
    pub connected: bool,
    pub version: Option<String>,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct UpdateNotice {
    pub version: String,
    pub outdated_devices: Vec<EntityId>,
    pub outdated_ports: Vec<String>,
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum CheckOutcome {
    Started,
    RateLimited,
    InProgress,
    Persisted(CheckStatus),
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SchedulerError {
    Repository(RepositoryError),
    ClockOverflow,
}
impl From<RepositoryError> for SchedulerError {
    fn from(e: RepositoryError) -> Self {
        Self::Repository(e)
    }
}

pub struct FirmwareUpdateScheduler<R: FirmwareRepository> {
    repository: Arc<R>,
    config: SchedulerConfig,
    status: CheckStatus,
    dismissed_key: Option<String>,
}
impl<R: FirmwareRepository> FirmwareUpdateScheduler<R> {
    pub fn new(repository: Arc<R>, config: SchedulerConfig) -> Result<Self, SchedulerError> {
        let last = repository.latest_check()?;
        let dismissed_key = repository.dismissed_notice()?;
        Ok(Self {
            repository,
            config,
            status: CheckStatus {
                checking: false,
                checked_at_ms: last.as_ref().map(|x| x.checked_at_ms),
                found_updates: last.as_ref().is_some_and(|x| x.found_updates),
                latest_version: last.as_ref().and_then(|x| x.latest_version.clone()),
                error_message: last.and_then(|x| x.error_message),
            },
            dismissed_key,
        })
    }
    pub fn status(&self) -> &CheckStatus {
        &self.status
    }
    pub fn startup_at(&self, now_ms: u64) -> Result<u64, SchedulerError> {
        now_ms
            .checked_add(self.config.startup_delay.as_millis() as u64)
            .ok_or(SchedulerError::ClockOverflow)
    }
    pub fn next_periodic_at(&self, now_ms: u64) -> Result<u64, SchedulerError> {
        now_ms
            .checked_add(self.config.cadence.as_millis() as u64)
            .ok_or(SchedulerError::ClockOverflow)
    }
    pub fn can_check(&self, now_ms: u64) -> bool {
        !self.status.checking
            && self.status.checked_at_ms.is_none_or(|last| {
                now_ms.saturating_sub(last) >= self.config.min_interval.as_millis() as u64
            })
    }
    pub fn begin_check(&mut self, now_ms: u64) -> CheckOutcome {
        self.begin_check_with_force(now_ms, false)
    }
    /// Legacy check_now forces a retry; concurrent work still shares the active check.
    pub fn begin_check_with_force(&mut self, now_ms: u64, force: bool) -> CheckOutcome {
        if self.status.checking {
            return CheckOutcome::InProgress;
        }
        if !force && !self.can_check(now_ms) {
            return CheckOutcome::RateLimited;
        }
        self.status.checking = true;
        CheckOutcome::Started
    }
    /// Persist first; update the in-memory snapshot only after the repository confirms commit.
    pub fn record_check(
        &mut self,
        record: UpdateCheckRecord,
        now_ms: u64,
    ) -> Result<CheckOutcome, SchedulerError> {
        self.commit_check(record, now_ms, false)
    }
    /// Failed refresh history stays truthful while an already known live notice remains visible.
    pub fn record_failed_check(
        &mut self,
        record: UpdateCheckRecord,
        now_ms: u64,
    ) -> Result<CheckOutcome, SchedulerError> {
        self.commit_check(record, now_ms, true)
    }
    fn commit_check(
        &mut self,
        record: UpdateCheckRecord,
        now_ms: u64,
        preserve_known_version: bool,
    ) -> Result<CheckOutcome, SchedulerError> {
        if !self.status.checking && !self.can_check(now_ms) {
            return Ok(CheckOutcome::RateLimited);
        }
        if let Err(error) = self.repository.record_check(&record) {
            self.status.checking = false;
            return Err(error.into());
        }
        self.status = CheckStatus {
            checking: false,
            checked_at_ms: Some(record.checked_at_ms),
            found_updates: record.found_updates,
            latest_version: if preserve_known_version {
                self.status.latest_version.clone()
            } else {
                record.latest_version
            },
            error_message: record.error_message,
        };
        self.dismissed_key = self.repository.dismissed_notice()?;
        Ok(CheckOutcome::Persisted(self.status.clone()))
    }
    pub fn set_checking(&mut self, checking: bool) {
        self.status.checking = checking;
    }
    pub fn notice(&self, devices: &[ConnectedFirmware]) -> Option<UpdateNotice> {
        self.notice_with_unconfigured(devices, &[])
    }
    pub fn notice_with_unconfigured(
        &self,
        devices: &[ConnectedFirmware],
        unconfigured: &[ConnectedUnconfiguredFirmware],
    ) -> Option<UpdateNotice> {
        let latest = self.status.latest_version.as_ref()?;
        let mut outdated_devices = devices
            .iter()
            .filter(|d| d.connected)
            .filter(|d| {
                d.version
                    .as_deref()
                    .map(|v| is_older_or_unparseable(v, latest))
                    .unwrap_or(false)
            })
            .map(|d| d.device_id)
            .collect::<Vec<_>>();
        outdated_devices.sort();
        outdated_devices.dedup();
        let mut outdated_ports = unconfigured
            .iter()
            .filter(|d| d.connected)
            .filter(|d| {
                d.version
                    .as_deref()
                    .is_some_and(|v| is_older_or_unparseable(v, latest))
            })
            .map(|d| d.port.clone())
            .collect::<Vec<_>>();
        outdated_ports.sort();
        outdated_ports.dedup();
        if outdated_devices.is_empty() && outdated_ports.is_empty() {
            return None;
        }
        let key = dismissal_key(latest, &outdated_devices, &outdated_ports);
        if self.dismissed_key.as_deref() == Some(&key) {
            return None;
        }
        Some(UpdateNotice {
            version: latest.clone(),
            outdated_devices,
            outdated_ports,
        })
    }
    pub fn dismiss(&mut self, devices: &[ConnectedFirmware]) -> Result<(), SchedulerError> {
        self.dismiss_with_unconfigured(devices, &[])
    }
    pub fn dismiss_with_unconfigured(
        &mut self,
        devices: &[ConnectedFirmware],
        unconfigured: &[ConnectedUnconfiguredFirmware],
    ) -> Result<(), SchedulerError> {
        let Some(notice) = self.notice_with_unconfigured(devices, unconfigured) else {
            return Ok(());
        };
        let key = Some(dismissal_key(
            &notice.version,
            &notice.outdated_devices,
            &notice.outdated_ports,
        ));
        self.repository.set_dismissed_notice(key.as_deref())?;
        self.dismissed_key = key;
        Ok(())
    }
}
fn is_older_or_unparseable(current: &str, latest: &str) -> bool {
    match (
        FirmwareVersion::parse(current),
        FirmwareVersion::parse(latest),
    ) {
        (Ok(a), Ok(b)) => a < b,
        _ => true,
    }
}
fn dismissal_key(version: &str, ids: &[EntityId], ports: &[String]) -> String {
    let mut key = format!(
        "{version}:{}",
        ids.iter()
            .map(|id| id.0.to_string())
            .collect::<Vec<_>>()
            .join(",")
    );
    // Preserve existing persisted keys when no unknown ports participate.
    if !ports.is_empty() {
        key.push_str(&format!(
            ":ports:{}",
            serde_json::to_string(ports).expect("string ports serialize")
        ));
    }
    key
}

/// Cancellable periodic owner. The first tick waits startup_delay; later ticks use cadence.
pub struct SchedulerTask {
    cancel: watch::Sender<bool>,
    join: JoinHandle<()>,
}
impl SchedulerTask {
    pub fn spawn<F, Fut>(config: SchedulerConfig, mut check: F) -> Self
    where
        F: FnMut() -> Fut + Send + 'static,
        Fut: Future<Output = ()> + Send + 'static,
    {
        let (cancel, mut rx) = watch::channel(false);
        let join = tokio::spawn(async move {
            tokio::select! { _ = tokio::time::sleep(config.startup_delay) => {}, _ = rx.changed() => return }
            loop {
                tokio::select! { _ = check() => {}, _ = rx.changed() => return }
                tokio::select! { _ = tokio::time::sleep(config.cadence) => {}, _ = rx.changed() => return }
            }
        });
        Self { cancel, join }
    }
    pub async fn cancel(self) {
        let _ = self.cancel.send(true);
        let _ = self.join.await;
    }
}
