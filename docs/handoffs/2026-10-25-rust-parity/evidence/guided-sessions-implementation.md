# Guided simulator desktop sessions — implementation handoff

## Delivered

- `composition/sessions.rs` owns one active simulator guidance slot and a bounded 16-command actor mailbox. It takes only `StatusSnapshot.client` from the accepted connection owner. No physical port or fabricated `ResourceArbiter` lease is used; the slot serializes detection subscription 99, lever sweeps, and manual sequence tests. Connection replacement cancels and joins the old worker before another session can start. Shutdown closes admission and cancels/joins the worker before the connection owner closes. Terminal snapshots are retained for UI polling, capped at 32.
- Control detection starts while the simulator is online even with no hardware. It reports all simultaneous changes and ambiguity, a 30-second timeout, remaining time, failures, and explicit cancellation. Unsubscribe is an acknowledged cleanup step; failure leaves the slot occupied and returns an error. Cancellation retries cleanup. No success is claimed from a failed unsubscribe.
- Lever analysis uses the accepted Rust analyzer and emits `analysis_progress` (`sampled`, `total`, `current_value`) plus an `AnalysisResult` with suggested simulator notches. Automatic lever calibration uses the accepted sweep algorithm and emits `progress` plus `CompletedCalibration` draft notches. Its new draft path **never calls the persistence port**. The user reviews and commits through the separate atomic mapping transaction. Simulator notch values/ranges are distinct from physical input captured ranges.
- Manual sequence testing now runs in the same host through `run_manual_sequence`. Every simulator set must succeed for `Ok(true)`; a failed send stops the run. It honors persisted order and the storage/Elixir 0–60,000 ms per-command delay rule, with no invented count or total-duration cap. Connection replacement and shutdown interrupt an in-progress delay or request before further commands.
- `explorer::resolve_lever_endpoints` lists one selected control using the existing `Function.GetNotchCount` classification and returns all five Rust-derived endpoints. `ui_resolve_lever_endpoints` calls it through the accepted client. Explorer accepts endpoint names from the legacy `Nodes` shape and the typed `Endpoints` shape.
- The legacy `SessionHandle::cancel(&mut self)` now has a 3-second retryable deadline and propagates unsubscribe/arbiter-release errors. A failed completion remains an error on later calls; it no longer silently reports success. The production simulator host does not use a physical hardware lease wrapper.

## Desktop IPC

All commands are registered in `rust_ui.rs`, implemented in `runtime_sessions.rs`, and use `snake_case` argument names.

- `ui_start_control_detection() -> {session_id:string}`
- `ui_start_lever_analysis(control_path:string, restore_position?:number|null) -> {session_id:string}`
- `ui_start_lever_calibration(control_path:string, lever_config_id?:number|null, endpoints?:{min_endpoint,max_endpoint,value_endpoint,notch_count_endpoint,notch_index_endpoint}) -> {session_id:string}`. An absent endpoints object derives the conventional five paths; explicit wizard-selected paths take precedence.
- Matching `ui_control_detection_status`, `ui_lever_analysis_status`, `ui_lever_calibration_status` take `session_id:string` and return `{session_id,state,changes,ambiguous,remaining_ms,analysis,analysis_progress,calibration,progress,message}`. States: `listening`, `running`, `cancelling`, `detected`, `timed_out`, `complete`, `failed`, `cancelled`.
- Matching `ui_cancel_control_detection`, `ui_cancel_lever_analysis`, `ui_cancel_lever_calibration` take `session_id:string` and return `bool` (true when an active session was cancelled; false when already terminal).
- `ui_resolve_lever_endpoints(control_path:string) -> {name,min_endpoint,max_endpoint,value_endpoint,notch_count_endpoint,notch_index_endpoint}`. `control_path` may be a base path or end in `.InputValue`.

The UI agent received these contracts. `runtime_composition` wired `ui_test_sequence` to `controls.sessions.run_manual_sequence` and removed the ad hoc simulator client.

## Verification

- `cargo test -p trenino-runtime --test guided_sessions -- --test-threads=1`: 11 passed. Fake HTTP covers online/no-hardware detection, ambiguity, timeout, unsubscribe cleanup/retry, replacement cancellation, analysis progress/result, calibration draft, shutdown no later PATCH writes, ordered manual sequence success/failure and replacement cancellation, valid 60-second persisted delay, and selected lever endpoint resolution.
- `cargo test -p trenino-runtime --lib -- --test-threads=1`: 20 passed, including legacy cleanup failure retention and a stalled cleanup timeout/retry.
- `cargo test -p trenino-runtime --test simulator_detection -- --test-threads=1`: 31 passed. One earlier combined run had the existing fake-clock race in `train_detection_polls_every_five_seconds` (2 observed vs 1); that exact test and the full simulator detection suite passed on isolated reruns.
- `cargo check --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui --quiet`: passed.
- `cargo clippy -p trenino-runtime --lib -- -D warnings`: passed.
- Scoped `git diff --check`: passed.

No real simulator, physical hardware, or packaged desktop smoke test was run. No commit was created. Shared unrelated WIP was preserved.

## Review notes

- An HTTP PATCH already accepted by a remote simulator may complete after local cancellation; the host joins its task and prevents later app-issued writes, but cannot roll back a request already received by the remote server. Tests assert no new PATCH requests after shutdown acknowledgement.
- `SessionHost` intentionally admits one guidance/manual sequence at a time because detection uses fixed subscription 99 and sweeps move controls. Hardware calibration retains its own physical-port `ResourceArbiter` lease; the simulator-only host never requests one.

## First adversarial review fixes

- A dropped connection-owner watch previously made the biased `status.changed()` branch permanently ready. The host now disables that branch after its first `Err`, closes admission, cancels/joins the active worker once, and continues serving status/shutdown requests. `owner_watch_drop_cancels_worker_and_keeps_status_shutdown_responsive` failed before the fix with a bounded status timeout, then passed. It also verifies unsubscribe cleanup and bounded shutdown acknowledgement.
- A queued Start whose caller disappeared previously spawned a hidden active session after cleanup unblocked. Start and manual-sequence commands now skip closed reply channels before work; if a Start receiver closes during spawn/ack delivery, the new worker is cancelled and joined. An abandoned manual-sequence caller is checked while the run is active and cancelled before later commands. `abandoned_queued_start_never_creates_hidden_session` failed before the fix with `Busy` on the next legitimate start, then passed. `abandoned_manual_sequence_cancels_before_later_commands` also passes.
- The actor now cancels the active worker when its command channel closes, avoiding a detached task after all host handles disappear.

Verification after these fixes: `cargo test -p trenino-runtime --test guided_sessions -- --test-threads=1` **14/14 passed**; `cargo clippy -p trenino-runtime --lib -- -D warnings` passed; scoped `git diff --check` passed. These are ready for a fresh review; the first review's verdict has not been reused as an approval.

## Second adversarial review fixes

- The manual sequence worker now observes its IPC caller directly at every command send and delay. A shared owned reply sender is held during each awaited operation; `tokio::select!` prioritizes its `closed()` notification over starting or continuing work. The former 50 ms abandonment poll is removed. The zero-delay second-PATCH regression held the first HTTP response, dropped the caller, then released the response. It failed before the fix (2 PATCH requests) and passes after (1 PATCH). A request already accepted by the remote server remains non-retractable.
- When the last session-host command sender closes, the actor closes admission and attempts cancellation. If detection unsubscribe fails, it retains the active cleanup owner and retries every second with missed ticks skipped, logging the unresolved error. It sets `finished` only after cleanup succeeds. The last-handle regression failed before the fix (no second unsubscribe), then passed after a failed unsubscribe followed by a successful retry; it also verified retries stop after success. Normal `shutdown()` keeps its bounded error/retained-owner path.

Verification after round 2: `cargo test -p trenino-runtime --test guided_sessions -- --test-threads=1` **16/16 passed**; `cargo clippy -p trenino-runtime --lib -- -D warnings` passed; desktop `cargo check --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui --quiet` passed. Awaiting a fresh adversarial review of this round.

## Guided UI cleanup ownership contract

- `SessionSnapshot.cleanup_pending` is a required serialized boolean. It is `true` when a failed unsubscribe or worker cleanup leaves the failed snapshot's session as the active cleanup owner. A successful cancel retry changes the snapshot to `cancelled` and clears the flag. Failures that finish and release their owner, such as a failed manual sequence write, report `failed` with `cleanup_pending: false`. The UI uses this field to await cancel acknowledgement before Close or Retry.
- The existing failed-cancel regression now asserts serialized `cleanup_pending: true` before retry and `false` after retry. A new detection-completion regression forces unsubscribe failure during `finish_active`, checks the same ownership flag, then retries cancellation. The manual-sequence failure regression checks a terminal `failed` snapshot has `cleanup_pending: false`.
- Red: the failed-cancel regression returned JSON `null` for `cleanup_pending` (expected `true`). Green: `cargo test -p trenino-runtime --test guided_sessions -- --test-threads=1` **17/17 passed**; `cargo clippy -p trenino-runtime --lib -- -D warnings` passed. Scoped rustfmt and diff checks passed. No desktop source change was needed; the surface agent is running the desktop check with the new DTO.

## Route-unmount cleanup retry

- The host's existing one-second cleanup retry now runs for any `active` session whose retained snapshot has `cleanup_pending: true`, even while command senders remain alive. It skips missed ticks, keeps the active owner on another unsubscribe failure, and clears the flag only after acknowledged cleanup. A healthy `listening` session is never selected. If all host handles disappeared, successful retry ends the actor; otherwise the actor stays available and admits a new session. Explicit shutdown still returns a bounded retryable error on cleanup failure.
- `failed_unsubscribe_retries_after_ui_caller_leaves` simulates the wizard unmount path: first cancel fails, no further caller cancel occurs, unsubscribe recovers, status changes from failed/pending to cancelled/clear, and a new detection starts. It also checks retry requests do not spin while the server keeps failing. `healthy_detection_is_not_cancelled_by_cleanup_retry_timer` checks the timed retry does not stop normal detection.
- Red: the unmount scenario timed out after three seconds waiting for the retained owner to clear. Green: `cargo test -p trenino-runtime --test guided_sessions -- --test-threads=1` **19/19 passed**; strict runtime lib Clippy, scoped rustfmt, and scoped diff checks passed. Ready for fresh scoped review.
