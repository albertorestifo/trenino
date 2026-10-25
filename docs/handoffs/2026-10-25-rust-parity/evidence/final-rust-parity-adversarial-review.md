# Final Rust parity adversarial review — 2026-10-25

## Outcome

**Changes required: four Important findings, no Critical finding.** This is a review of the production composition and retained user workflows, not an inference from a passing primitive suite. Repairs were assigned while this review was running; the findings below describe the reviewed revision and require scoped repair verification. In particular, the newly reported IO generation repair has not been accepted by this report.

No production files were edited. Reproductions used copied test fixtures, the actual compiled runtime or an unchanged copy of the reviewed source, fake hardware, and loopback HTTP. No native key presses, physical hardware, user DB, Windows driver, elevation or installer were exercised.

## Important findings

### 1. A queued simulator write starts after its accepted client disconnects

Reviewed `crates/trenino-runtime/src/composition/io.rs`, `LiveSimulator::set_value` and `Subscriptions`, plus `IoBridge::start` (reactor at lines 35–43). The original implementation captures `self.client()?` before queueing work. The reactor checks only the request deadline and global IO shutdown; disconnect/reconfigure of the accepted client does not invalidate queued work. `SimulatorConnectionOwner` publishes `Disconnected` and clears its client before acknowledging disconnect, but that publication does not stop this queue. These are the production ports used by scripts and MCP; production wiring is `composition/mod.rs` and `rust_ui.rs::wire_runtime_services`.

**Executed RED regression:** `/tmp/trenino-final-io-review.rs`, `queued_simulator_write_must_not_start_after_accepted_client_disconnects`. It includes the reviewed `io.rs` unchanged except for removing module doc comments and adding the test, and links the repository's runtime dependencies. Hold the IO reactor on a oneshot, enqueue `set_value`, wait for queue capacity to prove the write is queued, publish `Disconnected`/`client=None`, then unblock. No HTTP request existed before disconnect. Actual result was `Ok(Object {})` and `PATCH /set/Horn.InputValue?Value=1`; expected an error and no request. This is a write initiated after revocation, not an already transmitted request whose remote outcome is uncertain.

Bind queued and in-flight ordinary operations to the exact accepted client generation and cancel/revalidate on status change. Keep explicit cleanup unsubscribe capable of addressing its original client. The owner is repairing this in `tmp/io-generation-implementation.md`; its repair tests need independent verification.

### 2. Automatic firmware checks and the update notification workflow have no production owner

Retained `lib/trenino/application.ex:141-147` starts `Firmware.UpdateChecker`; `lib/trenino/firmware/update_checker.ex:158-171,208-221` schedules the five-second startup check and 24-hour periodic check, with persisted one-hour rate limiting. Its device-update handling and `lib/trenino_web/live/nav_hook.ex:52-57,75-104` drive the connected-outdated-device banner and dismissal in `components/nav_components.ex:65-94`. The retained hardware contract explicitly includes startup/periodic checks, notification and dismissal (`docs/superpowers/plans/2026-10-24-rust-hardware.md:33,177,200`).

Rust has `FirmwareUpdateScheduler` and `SchedulerTask` in `crates/trenino-runtime/src/firmware/updates.rs`, but source-wide constructor/caller search finds only their declarations and catalog tests, not desktop composition. `rust_ui.rs::wire_runtime_services` never starts them. `ui_check_firmware_updates` at approximately lines 2915–2946 is an explicit manual command. `Firmware.svelte::onMount` loads stored snapshots/inventory; it does not start a scheduler. `App.svelte` and `Navigation.svelte` have no firmware update notice/dismiss wiring. Repository dismissal methods alone do not supply that workflow.

**Reproduction by production-path tracing:** start Rust desktop with no recent check, remain on Devices and wait beyond five seconds. There is no scheduled caller capable of performing the retained check; connecting an outdated device cannot produce the legacy banner. The user must discover the Firmware page and request a manual check. No external network smoke was needed or claimed to establish absent callers.

Wire an owned, cancellable scheduler with persisted rate-limit/check results and device-based notices into desktop startup/shutdown, and expose the notice/dismiss workflow globally. Backend implementation was assigned during review; the UI counterpart and integration verification remain required.

### 3. An abandoned manual Lua run remains executable in the mailbox

`crates/trenino-runtime/src/train/script/runner.rs:276-279` drops the response receiver when its 30-second acknowledgement timeout expires. The `RunScript` arm at lines 401–416 executes a resident script without checking whether that receiver still exists. A queued request can therefore actuate hardware after its caller has already received a timeout or cancelled the request. This differs from guided sequence execution, which now checks/owns its caller through dispatch and delays.

**Executed RED regression:** `/tmp/trenino-final-script-review.rs`, `review_abandoned_queued_manual_run_must_not_actuate`, links the actual runtime. It copies the checked-in script-runner fake fixtures, holds a subscription poll, polls `run_script` once so mailbox send completes and acknowledgement remains pending, drops that future, then releases the poll. Actual effect: `["output:4:true"]`; expected no effect. Dropping the future exercises the same response-receiver closure as the production acknowledgement timeout without sleeping 30 seconds. The host is acknowledged and joined afterward.

Reject abandoned requests before execution, and retain explicit cancellation checks between effects if a run outlives its caller. Test queued abandonment and an acknowledgement timeout/cancellation during multiple effects; do not imply cancellation can undo an effect already dispatched.

### 4. Failed hardware calibration release loses its retry owner and later reports false success

`crates/trenino-runtime/src/hardware/service.rs:910-923` removes the calibration lease from `calibration_lease` before `arbiter.release` acknowledges. If `resume_after_fresh_sample` fails, `ResourceArbiter::release` retains the active lease and sets `fail_closed` (`resource.rs`, release error branch). A later `cancel_calibration` sees no stored token and returns `Ok(true)` while the arbiter remains suspended. New calibration/upload work remains blocked until application shutdown. The production resume callback can return errors from controller acknowledgements/cache invalidation, so this is not an impossible fake-only failure.

The same early-removal pattern occurs in completed calibration at `hardware/service.rs:954-968` and coordinated firmware cancellation at `:247-260`. Retaining the map entry alone is insufficient: ordinary `ResourceArbiter::release` currently rejects `fail_closed`, so the retained owner also needs an acknowledged recovery path.

**Executed RED regression:** `/tmp/trenino-final-lease-review.rs`, `review_failed_calibration_release_must_keep_retry_owner`, links the actual runtime and uses the checked-in hardware-service fake with an injected resume error. Start a calibration, fail first cancellation's resume, recover the fake, then cancel again. Actual: `retry=Ok(true), arbiter remains suspended=true`. The test calls real service shutdown afterward; no physical port is opened.

Keep the owner until release is acknowledged, and ensure retry either performs and confirms the outstanding release or returns a truthful retained-cleanup error. Cover explicit cancellation, terminal calibration and firmware takeover failures.

## Additional requested race assessment

`ResourceArbiter::neutralize_source` records failure only after calling `consumers.source_lost` (reviewed `resource.rs:388-406`). A gated callback probe `/tmp/trenino-final-arbiter-review.rs` confirms that `is_suspended()` is false and `acquire(Calibration)` can succeed while the first callback is held; this observed-behavior probe passed.

**Not counted as a fifth Important finding:** the actual same-port acquisition independently invokes effects/lever/button/vJoy suspension, sharing downstream cleanup gates with source loss. The generic probe proves the missing pending-state fence, but does not by itself prove an unsafe physical handoff through those production adapters. A conservative pending-source-loss fence is reasonable, but this report does not substitute an artificial consumer that acknowledges everything for proof of a new production safety regression. The separately observed test barrier race (resolver invalidation preceding the callback acknowledgement) is likewise not product evidence by itself.

## Coverage and boundaries

- Compared retained route/workflow structure and the hardware, firmware, script and connection lifecycle contracts with actual desktop registrations, `ControlRuntime`, live effect ports, shared resolver/arbiter, serial handoff adapter and shutdown participants. Found the missing firmware production caller rather than treating its unit-tested scheduler as integrated.
- Revisited conservative HIGH/display cleanup, manual generation-explicit output paths, hardware-handle retention, producer ordering and DB-last shutdown. Earlier report findings are repaired in the examined source; the newly found calibration-release ownership hole is recorded above. Upload ownership retains acquiring/reserved/releasing handoffs and reports cleanup failure instead of declaring completion.
- Revisited guided sessions' abandoned-start protection, caller-owned sequence waits, accepted-client identity, failed cleanup snapshots and autonomous one-second retry. No additional Important defect established in those repaired paths.
- Applied the earlier detailed vJoy reviews to current production selected-ID calls, confirmed-versus-pending provenance, worker/broker early entry, parent/nested job containment, rollback and non-persisting runtime release. No newly established Important defect. Native Windows execution, signed installer behavior, driver/UAC timing and physical acceptance remain external gates, not passed results.
- Inspected REST compatibility routes against `lib/trenino_web/router.ex`, common MCP/REST ports and listener wiring, and blocking-job guard/drain ownership. No new concrete Important issue established. Did not rerun full HTTP/MCP suites.
- Examined installed keystroke discovery, Rust CLI overlays/wrapper prerequisites and `.github/workflows/rust-parity.yml`. The CI definition runs runtime/UI/desktop/updater checks across three OSes; its existence is not evidence those jobs or native packaging passed. Clean non-Windows packaging still requires genuine avrdude/config staging, as already explicitly documented.
- Read the accepted review chain and inspected current thin-UI registrations/route reachability, atomic mapping response, typed null handling and live activity paths. The separately assigned nullable/I2C and final UI reviews own their active fixes; their known issues were not duplicated here. Root's native CUA smoke and other agents' suite totals are reported evidence, not tests executed by this reviewer.
- This is a broad targeted adversarial pass, not an exhaustive proof of every retained function. No full workspace suite or native desktop smoke was repeated. The four findings must be repaired and scoped re-reviewed before this report can support a parity-complete claim.
