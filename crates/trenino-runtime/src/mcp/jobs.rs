//! Admission and drain fence shared by external HTTP and MCP operations.
//! Guards live on the blocking job itself, so dropping an HTTP future cannot
//! hide a mutation still queued/running on the worker pool.
use std::{
    sync::{Arc, Condvar, Mutex},
    time::{Duration, Instant},
};
#[derive(Default)]
struct State {
    closed: bool,
    count: usize,
}
#[derive(Default)]
pub(crate) struct JobDrain {
    state: Mutex<State>,
    changed: Condvar,
}
pub(crate) struct JobGuard(Arc<JobDrain>);
impl JobDrain {
    pub(crate) fn admit(self: &Arc<Self>) -> Option<JobGuard> {
        let mut state = self.state.lock().ok()?;
        if state.closed {
            return None;
        }
        state.count += 1;
        Some(JobGuard(self.clone()))
    }
    pub(crate) fn close(&self) {
        if let Ok(mut state) = self.state.lock() {
            state.closed = true;
        }
    }
    pub(crate) fn reopen(&self) -> Result<(), String> {
        let mut state = self
            .state
            .lock()
            .map_err(|_| "external operation registry unavailable")?;
        if state.count != 0 {
            return Err("external operations still running".into());
        }
        state.closed = false;
        Ok(())
    }
    pub(crate) fn drain(&self, budget: Duration) -> Result<(), String> {
        let deadline = Instant::now() + budget;
        let mut state = self
            .state
            .lock()
            .map_err(|_| "external operation registry unavailable")?;
        while state.count != 0 {
            let now = Instant::now();
            if now >= deadline {
                return Err("External requests are still running; shutdown was not acknowledged. Retry after they finish.".into());
            }
            state = self
                .changed
                .wait_timeout(state, deadline.saturating_duration_since(now))
                .map_err(|_| "external operation registry unavailable")?
                .0;
        }
        Ok(())
    }
}
impl Drop for JobGuard {
    fn drop(&mut self) {
        if let Ok(mut state) = self.0.state.lock() {
            state.count -= 1;
            self.0.changed.notify_all();
        }
    }
}
