//! One owned automatic/manual firmware checker; all network work dies before join ACK.
use super::{
    CheckOutcome, CheckStatus, ConnectedFirmware, ConnectedUnconfiguredFirmware, FirmwareCatalog,
    FirmwareRepository, FirmwareUpdateScheduler, SchedulerConfig, UpdateCheckRecord, UpdateNotice,
};
use crate::simulator::services::clock::Clock;
use std::{
    future::Future,
    pin::Pin,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc, Mutex,
    },
    thread,
    time::{Duration, Instant},
};
use tokio::sync::{mpsc, oneshot, watch};

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FirmwareCheckResult {
    pub latest_version: Option<String>,
    pub found_updates: bool,
}
pub type CheckFuture<'a> =
    Pin<Box<dyn Future<Output = Result<FirmwareCheckResult, String>> + Send + 'a>>;
pub trait FirmwareCheckPort: Send + Sync + 'static {
    fn check(&self) -> CheckFuture<'_>;
}
impl<R: FirmwareRepository> FirmwareCheckPort for FirmwareCatalog<R> {
    fn check(&self) -> CheckFuture<'_> {
        Box::pin(async move {
            let known = self
                .list()
                .map_err(|e| e.to_string())?
                .into_iter()
                .map(|r| r.version)
                .collect::<std::collections::HashSet<_>>();
            let releases = self.refresh().await.map_err(|e| e.to_string())?;
            let latest = self.latest_compatible().map_err(|e| e.to_string())?;
            Ok(FirmwareCheckResult {
                found_updates: latest.is_some()
                    && releases.iter().any(|r| !known.contains(&r.version)),
                latest_version: latest.map(|r| r.version),
            })
        })
    }
}
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct FirmwareOwnerStatus {
    pub check: CheckStatus,
    pub notice: Option<UpdateNotice>,
}
#[derive(Clone, Debug, Default)]
pub struct FirmwareInventory {
    pub configured: Vec<ConnectedFirmware>,
    pub unconfigured: Vec<ConnectedUnconfiguredFirmware>,
}
type Reply<T> = oneshot::Sender<Result<T, String>>;
enum Command {
    Check(Reply<()>),
    Status(FirmwareInventory, Reply<FirmwareOwnerStatus>),
    Dismiss(FirmwareInventory, Reply<FirmwareOwnerStatus>),
}
pub struct FirmwareUpdateOwner {
    commands: mpsc::Sender<Command>,
    cancel: watch::Sender<bool>,
    stopping: AtomicBool,
    failed: AtomicBool,
    join: Mutex<Option<thread::JoinHandle<()>>>,
}
impl FirmwareUpdateOwner {
    pub fn start<R: FirmwareRepository>(
        repository: Arc<R>,
        port: Arc<dyn FirmwareCheckPort>,
        clock: Arc<dyn Clock>,
        epoch_ms: u64,
        config: SchedulerConfig,
    ) -> Result<Self, String> {
        Self::start_with_observer(repository, port, clock, epoch_ms, config, Arc::new(|| {}))
    }
    pub fn start_with_observer<R: FirmwareRepository>(
        repository: Arc<R>,
        port: Arc<dyn FirmwareCheckPort>,
        clock: Arc<dyn Clock>,
        epoch_ms: u64,
        config: SchedulerConfig,
        committed: Arc<dyn Fn() + Send + Sync>,
    ) -> Result<Self, String> {
        let scheduler =
            FirmwareUpdateScheduler::new(repository, config).map_err(|e| format!("{e:?}"));
        Self::start_scheduler(scheduler, port, clock, epoch_ms, config, committed)
    }
    fn start_scheduler<R: FirmwareRepository>(
        scheduler: Result<FirmwareUpdateScheduler<R>, String>,
        port: Arc<dyn FirmwareCheckPort>,
        clock: Arc<dyn Clock>,
        epoch_ms: u64,
        config: SchedulerConfig,
        committed: Arc<dyn Fn() + Send + Sync>,
    ) -> Result<Self, String> {
        let scheduler = scheduler?;
        let (commands, rx) = mpsc::channel(64);
        let (cancel, cancelled) = watch::channel(false);
        let runtime = tokio::runtime::Builder::new_current_thread()
            .enable_all()
            .build()
            .map_err(|e| e.to_string())?;
        let anchor = clock.now();
        let join = thread::Builder::new()
            .name("firmware-checker".into())
            .spawn(move || {
                runtime.block_on(run(
                    scheduler, port, clock, anchor, epoch_ms, config, rx, cancelled, committed,
                ));
            })
            .map_err(|e| e.to_string())?;
        Ok(Self {
            commands,
            cancel,
            stopping: AtomicBool::new(false),
            failed: AtomicBool::new(false),
            join: Mutex::new(Some(join)),
        })
    }
    fn send(&self, command: Command) -> Result<(), String> {
        if self.stopping.load(Ordering::Acquire) {
            return Err("Firmware checker is stopping.".into());
        }
        self.commands
            .try_send(command)
            .map_err(|_| "Firmware checker is unavailable or busy.".into())
    }
    pub async fn check(&self) -> Result<(), String> {
        let (tx, rx) = oneshot::channel();
        self.send(Command::Check(tx))?;
        receive(rx, Duration::from_secs(95)).await
    }
    pub async fn status(&self, devices: FirmwareInventory) -> Result<FirmwareOwnerStatus, String> {
        let (tx, rx) = oneshot::channel();
        self.send(Command::Status(devices, tx))?;
        receive(rx, Duration::from_secs(2)).await
    }
    pub async fn dismiss(&self, devices: FirmwareInventory) -> Result<FirmwareOwnerStatus, String> {
        let (tx, rx) = oneshot::channel();
        self.send(Command::Dismiss(devices, tx))?;
        receive(rx, Duration::from_secs(2)).await
    }
    pub fn stop_admission(&self) {
        self.stopping.store(true, Ordering::Release);
        self.cancel.send_replace(true);
    }
    /// A failed join retains the actual owner; retry is required before database closure.
    pub fn shutdown(&self, budget: Duration) -> Result<(), String> {
        self.stop_admission();
        let deadline = Instant::now() + budget;
        let mut slot = self
            .join
            .lock()
            .map_err(|_| "Firmware checker join is unavailable.")?;
        if self.failed.load(Ordering::Acquire) {
            return Err("Firmware checker host failed.".into());
        }
        if let Some(join) = slot.as_ref() {
            while !join.is_finished() {
                if Instant::now() >= deadline {
                    return Err("Firmware checker has not stopped yet.".into());
                }
                thread::sleep(Duration::from_millis(2));
            }
        }
        if let Some(join) = slot.take() {
            if join.join().is_err() {
                self.failed.store(true, Ordering::Release);
                return Err("Firmware checker host failed.".into());
            }
        }
        Ok(())
    }
}
async fn receive<T>(
    rx: oneshot::Receiver<Result<T, String>>,
    duration: Duration,
) -> Result<T, String> {
    tokio::time::timeout(duration, rx)
        .await
        .map_err(|_| "Firmware checker request timed out.".to_owned())?
        .map_err(|_| "Firmware checker stopped.".to_owned())?
}
#[allow(clippy::too_many_arguments)]
async fn run<R: FirmwareRepository>(
    mut scheduler: FirmwareUpdateScheduler<R>,
    port: Arc<dyn FirmwareCheckPort>,
    clock: Arc<dyn Clock>,
    anchor: Instant,
    epoch_ms: u64,
    config: SchedulerConfig,
    mut commands: mpsc::Receiver<Command>,
    mut cancel: watch::Receiver<bool>,
    committed: Arc<dyn Fn() + Send + Sync>,
) {
    let mut timer = clock.sleep(config.startup_delay);
    let mut active: Option<CheckFuture<'static>> = None;
    let mut waiters: Vec<Reply<()>> = Vec::new();
    let mut persistence_error = None;
    loop {
        let now = || epoch_ms.saturating_add(clock.elapsed_since(anchor).as_millis() as u64);
        let status = |scheduler: &FirmwareUpdateScheduler<R>,
                      devices: &FirmwareInventory,
                      error: &Option<String>| {
            let mut check = scheduler.status().clone();
            if let Some(error) = error {
                check.error_message = Some(error.clone());
            }
            FirmwareOwnerStatus {
                check,
                notice: scheduler
                    .notice_with_unconfigured(&devices.configured, &devices.unconfigured),
            }
        };
        tokio::select! { biased;
            _ = cancel.changed() => break,
            command = commands.recv() => match command {
                None => break,
                Some(Command::Status(devices, reply)) => { let _ = reply.send(Ok(status(&scheduler, &devices, &persistence_error))); }
                Some(Command::Dismiss(devices, reply)) => {
                    let result = scheduler.dismiss_with_unconfigured(&devices.configured, &devices.unconfigured).map_err(|e| format!("{e:?}"))
                        .map(|_| status(&scheduler, &devices, &persistence_error));
                    let _ = reply.send(result);
                }
                Some(Command::Check(reply)) => {
                    if active.is_some() {
                        if waiters.len() < 64 { waiters.push(reply); }
                        else { let _ = reply.send(Err("Firmware checker is busy.".into())); }
                    } else if scheduler.begin_check_with_force(now(), true) == CheckOutcome::Started {
                        waiters.push(reply); active = Some(check_future(port.clone()));
                    } else { let _ = reply.send(Ok(())); }
                }
            },
            result = async { active.as_mut().expect("guarded active check").await }, if active.is_some() => {
                active = None;
                let record = UpdateCheckRecord { checked_at_ms: now(), found_updates: result.as_ref().ok().is_some_and(|r| r.found_updates),
                    latest_version: result.as_ref().ok().and_then(|r| r.latest_version.clone()),
                    error_message: match &result {
                        Err(error) => Some(error.clone()),
                        Ok(result) if result.latest_version.is_none() => Some("No compatible firmware releases found.".into()),
                        Ok(_) => None,
                    } };
                let persisted = if result.is_err() { scheduler.record_failed_check(record, now()) }
                    else { scheduler.record_check(record, now()) }
                    .map_err(|e| format!("Firmware check persistence failed: {e:?}"));
                persistence_error = persisted.as_ref().err().cloned();
                if persisted.is_ok() { committed(); }
                let outcome = persisted.and(result.map(|_| ()));
                for reply in waiters.drain(..) { let _ = reply.send(outcome.clone()); }
            },
            _ = &mut timer => {
                timer = clock.sleep(config.cadence);
                if scheduler.begin_check(now()) == CheckOutcome::Started {
                    active = Some(check_future(port.clone()));
                }
            }
        }
        if *cancel.borrow() {
            break;
        }
    }
    drop(active); // Drop the in-flight HTTP future before any shutdown acknowledgement.
    for reply in waiters {
        let _ = reply.send(Err("Firmware checker stopped.".into()));
    }
}
fn check_future(port: Arc<dyn FirmwareCheckPort>) -> CheckFuture<'static> {
    Box::pin(async move {
        tokio::time::timeout(Duration::from_secs(90), port.check())
            .await
            .map_err(|_| "Firmware check timed out.".to_owned())?
    })
}
