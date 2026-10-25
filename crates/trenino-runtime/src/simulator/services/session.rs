//! Shared plumbing for simulator sessions that own a resource-arbiter lease.
//!
//! Every session acquires its [`LeaseKind`] up front (so a busy resource fails
//! the start call) and releases it on every exit path: natural completion,
//! timeout, explicit cancellation, handle drop, or disappearance of the event
//! listener. This mirrors the Elixir GenServer `terminate/2` guarantees without
//! requiring a UI subscriber to drive cleanup.

use std::future::Future;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::{mpsc, watch, Mutex};
use crate::resource::{LeaseKind, ResourceArbiter, ResourceError};

pub type Cancel = watch::Sender<bool>;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SessionClosed {
    WorkerFailed,
}

/// Handle to one running session: owns the event stream and the cancellation
/// signal. Dropping the handle cancels the session and releases its lease.
pub struct SessionHandle<Event> {
    events: mpsc::Receiver<Event>,
    worker: Arc<Mutex<Option<tokio::task::JoinHandle<()>>>>,
    cancel: Arc<Cancel>,
}

impl<Event> SessionHandle<Event> {
    pub fn events(&mut self) -> &mut mpsc::Receiver<Event> {
        &mut self.events
    }

    /// Cancel the session, wait for its cleanup (including lease release) and
    /// the worker to finish.
    pub async fn cancel(self) -> Result<(), SessionClosed> {
        let _ = self.cancel.send(true);
        let mut slot = self.worker.lock().await;
        if let Some(handle) = slot.as_mut() {
            handle.await.map_err(|_| SessionClosed::WorkerFailed)?;
            *slot = None;
        }
        Ok(())
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
    CleanupFuture: Future<Output = ()> + Send + 'static,
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
        cleanup().await;
        let _ = release_arbiter.release(token);
        if let Some(event) = outcome {
            let _ = events_tx.send(event).await;
        }
    });
    Ok(SessionHandle {
        events: events_rx,
        worker: Arc::new(Mutex::new(Some(worker))),
        cancel: Arc::new(cancel_tx),
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
