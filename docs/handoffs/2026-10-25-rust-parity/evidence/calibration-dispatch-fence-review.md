# Calibration dispatch and retained-owner closing review — 2026-10-25

## Verdict

**The calibration cleanup ownership finding and its partial-resume integration blocker are closed. No remaining Important/Critical defect established in this scope.** Reviewed the frozen production source, the preceding ownership review and both implementation reports. Independently executed the focused behavioral checks below; aggregate test totals supplied by root were not used as a substitute for this review.

## Production dispatch and cache-only behavior

`AppHardwareConsumers::dispatch_port_input` (`tauri/src-tauri/src/rust_ui.rs:1111-1165`) checks the actual named port's retained lease, recorded neutralization failure and shared suspended set. A retained lease prevents implicit resume from a sample. The production path calls `composition::input::{port_is_fenced, dispatch_control_input}`, rather than leaving the repaired gate only in a test helper. An aggregate resume error remains an error, while the received sample still goes through the fenced observation path before its error is returned. The physical output gate is removed only after the complete resume callback succeeds (`resume_suspended_port`).

The immutable observation intent is carried inside each bounded worker-queue message. `LeverController::try_observe` and `ButtonController::try_observe` therefore remain cache-only even if a resume command is processed before that queued sample. Both worker handlers resolve the authoritative port/generation/config/pin first, then record the bound input's observed baseline and neutralize that port's outstanding work without scheduling a new effect. A valid sample of another binding kind still reaches port cleanup, covering a held button key when initial suspension stopped before the button callback. Queue admission attempts both workers and propagates failures; it is not misrepresented as a synchronous cleanup acknowledgement.

Observed values are keyed by actual input identity with source port and generation. After successful release, repeating the observed level does not replay a deferred lever value or button edge; a changed value/edge can act normally. Controller activation/release clears those baselines. The gate is port-scoped, so COM1's retained lease does not suppress COM2's simulator/button input. Existing held-key failures and cancelled child work remain in their established retained cleanup state.

The actual-worker integration regression deliberately resumes lever and button workers, fails the final aggregate resume, and retains the real arbiter lease. It verifies no leased throttle/key effects, fresh baseline updates, no replay on release, later changed input working, and another port continuing to work. This directly addresses the previous source-review failure ordering.

## Retained lease and cancellation acknowledgement

`CoordinatedConsumers::release_calibration_lease` (`hardware/service.rs:241-270`) checks the exact `(session ID, token)`, calls the arbiter and removes that same entry only after acknowledgement. Cancellation, terminal advance and coordinated takeover use this helper. Registration precedes session insertion, leaving cleanup discoverable even when insertion fails. Later resource admission retries terminal/missing-session cleanup without cancelling a healthy live session.

`ResourceArbiter::release` (`resource.rs:319-373`) validates the active token and permits failed-resume recovery only for that retained token. Wrong tokens, unrelated fail-closed conditions and recorded neutralization failures remain blocked. The lease stays active while callbacks run, so partial resume cannot bypass the new ingress gate. Successful retry clears the owner and failure state. Repeated terminal Advance returns the recorded result after cleanup rather than repeating persistence.

`ui_cancel_calibration` propagates cleanup failure as a retryable error. The wizard retains its session and dialog after an error/exception, ignores duplicate close actions while pending, and closes only after a successful backend result, including an already-clean false result. An abandoned UI listener does not erase backend cleanup ownership; later admission has the reviewed recovery path.

## Fresh executed evidence

- `cargo test -p trenino-runtime --test control_dispatch cache`: **2 passed** — retained-lease/partial-resume baseline and other-port behavior; cache-only cleanup after initial suspension never reached buttons.
- Four exact tests from the freshly built `hardware_service` test binary: **4 passed** — failed cancel retained/retried, completed calibration returns its persisted result after cleanup retry, failed registration retains ownership, and later admission recovers cleanup after the listener disappears.
- Rebuilt the original reviewer `/tmp/trenino-final-lease-review.rs` against the current runtime: `review_failed_calibration_release_must_keep_retry_owner` **GREEN**. The original false `Ok(true)` with a still-suspended arbiter is no longer reproduced.
- `cargo test -p trenino-runtime --test resource_arbiter failed_resume_can_retry_only_the_retained_owner_without_reopening_admission --quiet`: **1 passed**.
- `npm --prefix tauri/ui test -- --run tests/wizards.test.ts -t 'retains the session|duplicate|pending|cancels the session' --reporter=dot`: **4 passed**, including cancellation success, failed-ACK retry with the same ID, and duplicate-close suppression.

Twelve focused checks passed. No production edits or subagents. No physical hardware, native key presses, simulator, real calibration DB or Windows operations. Full workspace/UI/desktop aggregates and root's native smoke remain separately recorded evidence; this report closes the specific calibration blockers without claiming native hardware/driver/installer acceptance.
