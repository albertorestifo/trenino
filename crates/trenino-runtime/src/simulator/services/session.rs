//! Shared plumbing for simulator sessions that own a resource-arbiter lease.
//!
//! Every session acquires its [`LeaseKind`] up front (so a busy resource fails
//! the start call) and releases it on every exit path: natural completion,
//! timeout, explicit cancellation, handle drop, or disappearance of the event
//! listener. This mirrors the Elixir GenServer `terminate/2` guarantees without
//! requiring a UI subscriber to drive cleanup.

use crate::resource::{LeaseKind, ResourceArbiter, ResourceError};
use std::future::Future;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::{mpsc, watch, Mutex};

pub type Cancel = watch::Sender<bool>;
type SessionWorker = tokio::task::JoinHandle<Result<(), SessionClosed>>;

#[derive(Clone, Debug, PartialEq, Eq)]
pub enum SessionClosed {
    WorkerFailed,
    Deadline,
    CleanupFailed(String),
    LeaseReleaseFailed(ResourceError),
}

/// Handle to one running session: owns the event stream and the cancellation
/// signal. Dropping the handle cancels the session and releases its lease.
pub struct SessionHandle<Event> {
    events: mpsc::Receiver<Event>,
    worker: Arc<Mutex<Option<SessionWorker>>>,
    cancel: Arc<Cancel>,
    completion_error: Option<SessionClosed>,
}

impl<Event> SessionHandle<Event> {
    pub fn events(&mut self) -> &mut mpsc::Receiver<Event> {
        &mut self.events
    }

    /// Cancel the session, wait for its cleanup (including lease release) and
    /// the worker to finish.
    pub async fn cancel(&mut self) -> Result<(), SessionClosed> {
        let _ = self.cancel.send(true);
        let mut slot = self.worker.lock().await;
        if let Some(handle) = slot.as_mut() {
            let result = tokio::time::timeout(Duration::from_secs(3), handle)
                .await
                .map_err(|_| SessionClosed::Deadline)?;
            *slot = None;
            let result = result.map_err(|_| SessionClosed::WorkerFailed)?;
            self.completion_error = result.clone().err();
            return result;
        }
        self.completion_error.clone().map_or(Ok(()), Err)
    }

    /// The shared cancellation signal, for callers that need to observe it.
    pub fn cancel_signal(&self) -> Arc<Cancel> {
        self.cancel.clone()
    }
}

impl<Event> Drop for SessionHandle<Event> {
    fn drop(&mut self) {
        let _ = self.cancel.send(true);
    }
}
/// Spawn a session body under a freshly acquired lease. The body is built with
/// the session's event sender (multi-event sessions publish progress through
/// it and return only their final event); `cleanup` runs on every exit path
/// before the lease is released, mirroring `terminate/2`.
#[allow(clippy::type_complexity)]
pub fn spawn_leased_session<Event, Cleanup, CleanupFuture, Build, Run>(
    arbiter: &Arc<ResourceArbiter>,
    lease: LeaseKind,
    build_run: Build,
    cleanup: Cleanup,
) -> Result<SessionHandle<Event>, ResourceError>
where
    Event: Send + 'static,
    Run: Future<Output = Option<Event>> + Send + 'static,
    Build: FnOnce(mpsc::Sender<Event>) -> Run + 'static,
    Cleanup: FnOnce() -> CleanupFuture + Send + 'static,
    CleanupFuture: Future<Output = Result<(), SessionClosed>> + Send + 'static,
{
    let token = arbiter.acquire(lease)?;
    let (events_tx, events_rx) = mpsc::channel::<Event>(16);
    let run = build_run(events_tx.clone());
    let (cancel_tx, mut cancel_rx) = watch::channel(false);
    let release_arbiter = arbiter.clone();
    let worker = tokio::spawn(async move {
        let outcome = tokio::select! {
            biased;
            _ = cancelled(&mut cancel_rx) => None,
            _ = events_tx.closed() => None,
            outcome = run => outcome,
        };
        let cleanup_result = cleanup().await;
        let release_result = release_arbiter
            .release(token)
            .map_err(SessionClosed::LeaseReleaseFailed);
        let result = cleanup_result.and(release_result);
        if result.is_ok() {
            if let Some(event) = outcome {
                let _ = events_tx.try_send(event);
            }
        }
        result
    });
    Ok(SessionHandle {
        events: events_rx,
        worker: Arc::new(Mutex::new(Some(worker))),
        cancel: Arc::new(cancel_tx),
        completion_error: None,
    })
}

/// Wait until `probe` returns a value, bounded by `deadline`; panics like a
/// normal test assertion helper when the condition never holds.
pub async fn eventually<T>(probe: impl FnMut() -> Option<T>, deadline: Duration) -> T {
    let mut probe = probe;
    let deadline = Instant::now() + deadline;
    loop {
        if let Some(value) = probe() {
            return value;
        }
        if Instant::now() >= deadline {
            panic!("condition never observed before deadline");
        }
        tokio::time::sleep(Duration::from_millis(5)).await;
    }
}

pub async fn cancelled(signal: &mut watch::Receiver<bool>) {
    loop {
        if *signal.borrow() {
            return;
        }
        if signal.changed().await.is_err() {
            return;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::resource::ResourceConsumers;
    struct Noop;
    impl ResourceConsumers for Noop {
        fn suspend_actuation(&self, _: &str) -> Result<(), String> {
            Ok(())
        }
        fn cancel_calibration(&self, _: &str) -> Result<(), String> {
            Ok(())
        }
        fn source_lost(&self, _: &str, _: u64) -> Result<(), String> {
            Ok(())
        }
        fn resume_after_fresh_sample(&self, _: &str) -> Result<(), String> {
            Ok(())
        }
    }
    #[tokio::test]
    async fn cancellation_reports_cleanup_failure_on_every_retry() {
        let arbiter = Arc::new(ResourceArbiter::new(Arc::new(Noop)));
        let mut session = spawn_leased_session::<(), _, _, _, _>(
            &arbiter,
            LeaseKind::Calibration {
                port: "p".into(),
                generation: 1,
            },
            |_| async { std::future::pending().await },
            || async { Err(SessionClosed::CleanupFailed("unsubscribe failed".into())) },
        )
        .unwrap();
        assert_eq!(
            session.cancel().await,
            Err(SessionClosed::CleanupFailed("unsubscribe failed".into()))
        );
        assert_eq!(
            session.cancel().await,
            Err(SessionClosed::CleanupFailed("unsubscribe failed".into()))
        );
    }

    #[tokio::test]
    async fn stalled_cleanup_times_out_then_can_be_joined() {
        let arbiter = Arc::new(ResourceArbiter::new(Arc::new(Noop)));
        let release = Arc::new(tokio::sync::Notify::new());
        let cleanup = release.clone();
        let mut session = spawn_leased_session::<(), _, _, _, _>(
            &arbiter,
            LeaseKind::Calibration {
                port: "p".into(),
                generation: 1,
            },
            |_| async { std::future::pending().await },
            move || async move {
                cleanup.notified().await;
                Ok(())
            },
        )
        .unwrap();
        assert_eq!(session.cancel().await, Err(SessionClosed::Deadline));
        assert!(arbiter.is_suspended());
        release.notify_one();
        assert_eq!(session.cancel().await, Ok(()));
        assert!(!arbiter.is_suspended());
    }
}
