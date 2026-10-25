//! Injectable monotonic clock for detection, grace and calibration timing.
//!
//! Mirrors the Elixir services' use of `Process.send_after`/`System.monotonic_time`
//! (train detection 5s poll / 30s grace with 200ms probes) with an injectable
//! fake so tests advance time without sleeping.

use std::collections::HashMap;
use std::future::Future;
use std::pin::Pin;
use std::sync::{
    atomic::{AtomicU64, Ordering},
    Arc, Mutex,
};
use std::time::{Duration, Instant};
use tokio::sync::watch;

pub type Sleep = Pin<Box<dyn Future<Output = ()> + Send + 'static>>;

pub trait Clock: Send + Sync + 'static {
    fn now(&self) -> Instant;
    fn sleep(&self, duration: Duration) -> Sleep;
    fn elapsed_since(&self, earlier: Instant) -> Duration {
        self.now().saturating_duration_since(earlier)
    }
}

/// Real wall-clock time backed by `tokio::time`.
#[derive(Clone, Copy, Debug, Default)]
pub struct SystemClock;

impl Clock for SystemClock {
    fn now(&self) -> Instant {
        Instant::now()
    }
    fn sleep(&self, duration: Duration) -> Sleep {
        Box::pin(tokio::time::sleep(duration))
    }
}

/// Deterministic clock that only advances through explicit `advance` calls.
#[derive(Clone, Debug)]
pub struct FakeClock {
    time: watch::Sender<Instant>,
    pending: Arc<Mutex<HashMap<u64, Instant>>>,
    next_sleep: Arc<AtomicU64>,
}

impl FakeClock {
    pub fn new() -> Self {
        let (time, _) = watch::channel(Instant::now());
        Self {
            time,
            pending: Arc::default(),
            next_sleep: Arc::default(),
        }
    }

    /// Test orchestration barrier: active fake sleeps, including futures
    /// constructed but not yet polled. Tests can wait for a poll to rearm
    /// after HTTP completion instead of guessing a wall-clock settle time.
    pub fn pending_deadlines(&self) -> Vec<Instant> {
        self.pending
            .lock()
            .expect("fake clock pending sleeps poisoned")
            .values()
            .copied()
            .collect()
    }

    pub fn advance(&self, duration: Duration) {
        self.time.send_modify(|now| *now += duration);
    }
}

impl Default for FakeClock {
    fn default() -> Self {
        Self::new()
    }
}

struct PendingSleep {
    token: u64,
    registry: Arc<Mutex<HashMap<u64, Instant>>>,
}
impl Drop for PendingSleep {
    fn drop(&mut self) {
        self.registry
            .lock()
            .expect("fake clock pending sleeps poisoned")
            .remove(&self.token);
    }
}

impl Clock for FakeClock {
    fn now(&self) -> Instant {
        *self.time.borrow()
    }
    fn sleep(&self, duration: Duration) -> Sleep {
        let deadline = self.now() + duration;
        let mut receiver = self.time.subscribe();
        let token = self.next_sleep.fetch_add(1, Ordering::Relaxed);
        self.pending
            .lock()
            .expect("fake clock pending sleeps poisoned")
            .insert(token, deadline);
        let registration = PendingSleep {
            token,
            registry: self.pending.clone(),
        };
        Box::pin(async move {
            let _registration = registration;
            loop {
                if *receiver.borrow_and_update() >= deadline {
                    return;
                }
                if receiver.changed().await.is_err() {
                    return;
                }
            }
        })
    }
}
