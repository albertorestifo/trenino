# Train shutdown lifecycle handoff

## Implemented

- `TrainServiceHandle::shutdown(&self) -> Result<(), train::button_controller::QueueError>` is retryable and idempotent across clones. The handle is retained after an error. `QueueError::Timeout` is new. Shutdown fences service and both controller admission immediately, aborts the detection event pump and button broadcast forwarding task, retains their `JoinHandle`s until joined, and concurrently stops detection and joins both controllers. It attempts every child even when another child times out or fails. `sync` and simulator connection notifications reject admission once shutdown begins.
- `TrainDetectionMonitor::shutdown(&self) -> Result<(), MonitorError>` is idempotent, serialized through its worker mutex, cancels an in-flight detection request by aborting the worker, and retains the join handle on `MonitorError::Timeout`. Its `connected`, `disconnected`, and `sync` commands reject admission after shutdown starts. The old command acknowledgement before worker exit was removed.
- `LeverController::shutdown(&self)` and `ButtonController::shutdown(&self)` now use shared clone lifecycle state and return `QueueError::Timeout` if the worker has not joined within one second. A timed-out attempt retains the worker handle and the already admitted shutdown command for retry. All public input/control admission is fenced. The worker exits only after cleanup and child cancellation settlement; no early reply can be mistaken for completion.
- Lever cancellation tracks both each writer and its completion watcher. Release, port suspension, and shutdown abort them; shutdown waits for every retained child abort handle to finish. Button cancellation retains aborted sequence runs, including prior release/repress/port-suspend runs, and shutdown waits for them to finish after held keys are released through `owner_gone`.
- `ScriptRunner::run_script(&self, id: i64) -> Result<bool, ScriptRunError>` now has an actual host acknowledgement (`ScriptRunError::{Timeout, HostClosed}`, 30-second bound). `Ok(true)` means a resident compiled VM was attempted; `Ok(false)` means no active executable script with that ID. Runtime execution errors still count as attempted and remain in the script log. The Tauri UI caller must map the result instead of returning unconditional `true`; `/root/runtime_composition` was informed.

## Tests and evidence

- `shutdown_is_shared_by_clones_and_rejects_new_admission`: concurrent and repeated train shutdown, then admission checks. Before the API change the test did not compile because `shutdown(self)` consumed the handle.
- `stalled_button_write_times_out_shutdown_then_retry_joins_worker`: a gated in-flight HTTP write causes a one-second timeout; new admission is rejected; releasing the gate permits a successful retry and another idempotent call.
- `shutdown_cancels_a_detection_pump_blocked_on_full_event_stream`: fills the unread 256-entry event receiver, queues more detection work, then proves shutdown joins within two seconds.
- `controller_shutdown_joins_once_across_concurrent_clones`: both lever and button workers accept concurrent clone shutdowns, repeated shutdowns, and reject input afterward.
- Detection monitor test now covers concurrent and repeated shutdown, and rejection of sync. Before the change the second shutdown failed with `Closed`.
- `manual_run_acknowledges_only_a_resident_compiled_script`: inactive, compile-error and unknown IDs return `false`; a compiled script returns `true` and its effects are visible; a stopped host returns an error. Before the API change the assertions did not compile (`run_script` returned `()`).

Final scoped verification (serial test threads):

```text
cargo test -p trenino-runtime --test control_dispatch --test output_display --test script_runner --test simulator_detection --test train_sessions -- --test-threads=1
control_dispatch: 31 passed
output_display: 30 passed
script_runner: 11 passed
simulator_detection: 31 passed
train_sessions: 14 passed
```

`git diff --check` on changed scoped files passed. An earlier parallel simulator detection run had a fake-clock probe timeout under concurrent load; the failing tests passed isolated and the entire simulator detection suite passed serially. No commits or real device side effects.

## Integration limits

- A timeout is explicitly **not** completion. Keep the train service/controller handles and IO adapters alive, retry shutdown after the blocked operation resolves, and fail closed while the result is outstanding.
- Button simple/momentary HTTP sends run inline on its worker. An already started request can delay worker shutdown until its bounded client/IO deadline; the service closes admission immediately and reports `Timeout` rather than detaching it.
- The script manual ACK has a 30-second deadline. A timeout means acceptance or completion is unknown; the host may still be processing the finite command. The UI should surface the error rather than report success.

## Round 1 routing release review fix

The review in `tmp/train-lifecycle-review.md` found that an earlier successful `TrainServiceHandle::shutdown` joined controller workers while leaving an engaged TSW route and `TrainSnapshot.active_train_id` set. This is fixed:

- `RoutingService::deactivate_destination(DestinationId, Revision) -> Result<(), RoutingError>` commits a newer desired revision without that one destination, invokes only its release callback, and preserves unrelated VJoy plans and driver state. A failed release leaves the TSW active/stale with a `DegradedReason::ReleaseFailed` carrying the underlying error; retry uses a newer revision.
- `TswDestination::release` now calls `LeverController::release_acknowledged()` and `ButtonController::release_acknowledged()` and propagates errors. Those synchronous acknowledgements wait for canceled writers/watchers and sequence runs. Button release checks every held key through the fallible `release` port; failed keys and their owner remain for retry. `owner_gone` runs after explicit releases succeed.
- Train shutdown fences public/controller input, joins the event producers and detection monitor, then runs the scoped TSW route release on a retained `spawn_blocking` task. It does not join controllers or clear the train snapshot until that route barrier succeeds. A timeout retains the route task for retry. After the release ACK it joins both controller workers and clears `active_train_id`, identifier, and ambiguity state. Repeated shutdown leaves the final snapshot unchanged.
- Normal service reconciliation also runs in `spawn_blocking`, so the synchronous release callback can wait for Tokio controller tasks even in current-thread test runtimes. No global `RoutingService::shutdown` call is made by the train service; VJoy stays owned by its own lifecycle.

New regression evidence:

- `shutdown_releases_held_state_and_stops_writers` now asserts that successful shutdown clears the active train and TSW route.
- `failed_key_release_keeps_tsw_route_and_snapshot_until_retry` injects a key-release error; the first shutdown returns an error, the routing degraded reason retains `key adapter busy`, input stays fenced, and retry releases the route and clears the snapshot.
- `scoped_tsw_deactivation_preserves_vjoy_plan_and_driver` proves the new routing operation releases TSW without a VJoy release or plan deletion.

Final scoped command passed **131 tests**:

```text
cargo test -p trenino-runtime --test control_dispatch --test output_display --test script_runner --test simulator_detection --test train_sessions --test routing_reconciliation -- --test-threads=1
31 + 30 + 11 + 31 + 15 + 13 passed
```

A routing release timeout or adapter failure remains a failed, retryable train shutdown. Keep the service/controllers and adapters alive until a later call succeeds; `RoutingSnapshot.degraded` supplies the release error detail. The second review finding on manual-run UI preflight is owned by the composition agent and was not changed in this round.
