# Guided route-unmount cleanup fix rereview (2026-10-25)

## Verdict

**Addressed in the scoped contract.** I found no remaining route-unmount cleanup defect in the new host retry path. This is a source and regression review; I did not rerun the reported 19 Rust guided tests or a live simulator/WebView.

## Evidence

- `crates/trenino-runtime/src/composition/sessions.rs:267-271,313-320` starts a one-second retry timer with missed ticks skipped. Its branch is enabled only for the active session whose retained snapshot has `cleanup_pending=true`, regardless of whether UI/host command senders are still open. It calls the same `cancel_active` cleanup as explicit Cancel. A failure retains the active owner and logs the error; success clears the owner. With live handles, the actor continues accepting a new Start; after the last sender closes, it exits only after cleanup succeeds.
- `sessions.rs:491-529,530-550` sets `cleanup_pending=true` when abort/join or unsubscribe cleanup fails and retains `active`. Only acknowledged cleanup sets `state=Cancelled`, clears the flag, and removes `active`. A healthy listening session has `cleanup_pending=false`, so the autonomous timer leaves it alone.
- `crates/trenino-runtime/tests/guided_sessions.rs:337-386` exercises the route-style case through the real fake HTTP simulator: first Cancel fails at unsubscribe, no second UI Cancel is sent, the server continues failing through a timed retry, then recovers. The test observes `failed/pending` become `cancelled/clear` and starts a new detection successfully. It bounds failed unsubscribe responses to exclude a hot loop. `:389-433` verifies the timer does not cancel a healthy detection.
- The already reviewed UI explicit Close, outer modal dismissal, and Retry still use acknowledged cancellation and retain the session ID on error (`tauri/ui/src/components/GuidedSimulatorSession.svelte:62-95,127-156`). On a forced route unmount, its single best-effort cancellation can now hand off a failed cleanup to the host's autonomous retry. The prior finding in `tmp/ui-guided-fix2-review.md` is closed.

If the remote simulator never acknowledges cleanup, the host deliberately keeps the slot occupied and retries at a bounded interval; it does not claim success. That is the intended ownership policy, not a regression in this fix.
