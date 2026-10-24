# Hardware runtime fix 1 review

Target: `e9ef8d9..6b20a81`. Scoped hardware/routing/resource sources remain identical to `6b20a81`; later runtime/storage/Tauri changes are excluded. Reviewed the supplied diff, updated implementation matrix, original aggregate, actual source and focused tests. No new child reviewers were used.

**Verdict: changes required.** This round substantially repairs the original low-level serial defects and delivers a real dispatcher. It is not yet acceptable as the canonical runtime because configuration completion, shutdown admission/neutralization and asynchronous handoff ownership still have correctness gaps. Six P1 and three P2 remaining findings are below.

## Evidence and limits

No production edits, commits, physical ports, driver, simulator, flashing or user database access. Four bounded executable fake probes were added only to `hardware-runtime-fix1-probes.rs` in this report directory and run against the exact production modules through Rust `#[path]` imports. They passed in 0.09 seconds; **pass means the defect was reproduced**, not that the intended behavior is correct. They show:

- Successful apply of ConfigId 2 after ConfigId 1 leaves subsequent input cached but unrouted.
- A detection session starts and publishes a timeout after successful service shutdown.
- Beginning reconfiguration at generation 2 after generation 1 was revoked retains the old revoked flag.
- Service shutdown returns success after the fake consumer reports neutralization failure.

The probe fixture is a report-directory copy of the existing fake service test fixture, extended to produce an input on Heartbeat and optionally fail source loss. Only `supervisor_` tests were executed. Initial linking to separately built runtime/core artifacts encountered a crate-version mismatch; recompiling the scoped modules directly resolved that harness issue. The final probes all compiled and completed. Coder-reported 33 focused tests, 8 core protocol tests, 121 runtime tests, Clippy and formatting were read and assessed; they were not blindly rerun. Remaining source-level reproductions are labeled below.

## Original eleven-finding disposition

| # | Disposition | Assessment |
|---|---|---|
| 1 cleanup ownership | Original blocked-I/O path fixed; related failures remain | `close(&mut self)` retains an unfinished join; scanner quarantines the owner, and retryable shutdown retains ownership. Reservation shutdown is explicitly pending until release. R4 concerns newly added service neutralization; R9 covers the joined-panic path. |
| 2 reservation overwrite/lost result | Original defects fixed | Opaque unique reservation tokens, Busy on repeat handoff, retained handoff/release results and operation IDs resolve both baseline reproductions. R5 concerns the new lease authorization boundary. |
| 3 coalesced discovery tail | Accepted | Persistent decoder and trailing messages are transferred to the port worker; focused complete/partial-tail regressions exercise this. |
| 4 malformed-frame resync | Accepted | ProtocolError is diagnostic, and the worker continues processing decoder results instead of poisoning the owner. |
| 5 stale-generation writes | Accepted for the baseline defect | Expected generation is in scanner and port commands and checked at both boundaries. |
| 6 resolver/cache resurrection | Partially accepted | Terminal same-generation resurrection is rejected. Fresh-generation `begin_reconfiguration` has R2. |
| 7 owned detection | Partially accepted | Autonomous timer, retained terminal outcome, generation baselines and source-loss dispatch exist. Shutdown admission remains open (R3). Unbound detection may keep waiting across source changes with old baselines removed; bound detection terminates on its matching generation. |
| 8 discovery budget | Partially accepted | Continuous successful garbage reads are now bounded; remaining time is applied to reads/writes. Native open and blocking flush are outside enforceable deadline reporting (R7). |
| 9 retained calibration results/bounds | Accepted for the baseline defects | Retained sample count is independent of notification draining; save success/error survives listener loss and terminal states latch. R8 concerns service lease cleanup on overflow. |
| 10 canonical owner/dispatcher | Delivered but not accepted | The owner now genuinely connects scanner, routes, cache, sessions, repository, configuration workers and arbiter. R1/R3/R4/R5/R6 prevent acceptance of that orchestration. |
| 11 bounded command queues | Accepted for the baseline defect | Runtime/per-port commands use bounded channels with visible full errors. Dispatcher backpressure preserves events, ACK inbox and retained sessions/operations are bounded. This does not imply every callback or shutdown join has a bounded duration. |

## Remaining actionable findings

### R1 — P1: Successful configuration never updates the dispatcher's active configuration

**Locations:** `hardware/service.rs:715-740`, `:955-990`; `hardware/configuration.rs:128-139`.

The configuration worker replaces the resolver and activates cache, then publishes success. It never updates `DispatcherState::ports[port]` (`CurrentPort.config_id`, device identity or pin kinds). Subsequent inputs resolve using the configuration captured during discovery. A ConfigId change therefore makes every input unresolved; configuring an initially unconfigured board has the same problem. Changing pin kind with the same ID also leaves detection classification stale.

**Executed reproduction:** `supervisor_config_success_keeps_old_dispatcher_config`: discover configuration 1, successfully apply configuration 2, verify the resolver contains configuration 2, emit input 99, observe cache 99 but no new consumer input. The existing service apply test reapplies ID 1 and does not send post-apply input, so misses this.

**Required fix:** Commit the complete current configuration (including pin kinds) to the dispatcher together with route/cache activation under the current operation/generation fence, before publishing success. Carry or load the kind metadata explicitly. Add configured-to-new-ID and unconfigured-to-configured end-to-end tests, including a pin type change.

### R2 — P1: A fresh generation can inherit the previous generation's tombstone

**Locations:** `routing.rs:67-79`, `:182-194`.

Both `begin_reconfiguration` methods allow a strictly newer generation and replace `state.generation`, but leave `state.revoked` unchanged. If the previous generation was revoked, the next `replace_port`/`activate` now sees equal generation plus `revoked=true` and rejects it. This occurs in the service when the old generation disconnects, the replacement board has no matching persisted configuration, and a new configuration is applied: the resolver's old tombstone survives discovery's unsuccessful lookup.

**Executed reproduction:** `supervisor_new_generation_reconfiguration_inherits_old_tombstone`: invalidate generation 1, begin reconfiguration generation 2 succeeds, then replace/activate generation 2 both fail.

**Required fix:** When advancing to a validated strictly newer connection, initialize fresh lifecycle state rather than copying the previous tombstone. Preserve rejection of the revoked equal generation. Add the actual reconnect-to-unconfigured-board service case as well as the direct resolver/cache regression.

### R3 — P1: Shutdown does not close service/session admission

**Locations:** `hardware/service.rs:426-437`, `:463-472`, `:551-581`, `:657-664`, `:794-841`; `hardware/sessions.rs:396-480`, `:667-696`.

Only `begin_configuration` checks `stopping`. `start_detection` still spawns a timer after `HardwareServiceHandle::shutdown()` has returned success. The exposed session registry similarly has no admission closure. At the first shutdown attempt, arbiter admission is not closed until after scanner/dispatcher/operation shutdown; an early scanner timeout returns before that step. Mutating entry points and retained registry/arbiter handles therefore do not share the service's closing state.

**Executed reproduction:** `supervisor_detection_is_admitted_after_successful_shutdown`: stop an empty service successfully, start detection, receive its timeout callback, then stop again to join the newly admitted worker.

**Required fix:** Close admission atomically at shutdown entry across all session/configuration/lease/command entry points and their exposed shared handles. Keep cleanup/result/reservation-release paths available. Reject new work after a timeout as well as after success. Separate arbiter admission closure from final neutralization so pending firmware reservations can still be released. Test both completed shutdown and retryable pending shutdown.

### R4 — P1: Neutralization errors are discarded and shutdown can falsely succeed

**Locations:** `hardware/service.rs:1081-1111`, `:794-841`.

`mark_source_lost` removes dispatcher state and invalidates routes/cache, then discards `coordinated_consumers.source_lost(...)` failure with `.ok()`. The arbiter is not informed of this failure. A reconnect can route input normally; if no lease was active, final arbiter shutdown has nothing to neutralize and returns success even though the actual consumer never acknowledged neutral output.

**Executed reproduction:** `supervisor_shutdown_reports_success_after_neutralization_error`: discover a fake board, configure consumer source loss to return `Err`, then shutdown returns `Ok` despite the recorded failing call.

**Required fix:** Retain source-loss/neutralization failure in the shared resource lifecycle, keep the resource suspended across reconnect until explicit successful recovery, surface the error and propagate unresolved failure from shutdown. Do not remove the only state needed to retry cleanup. Test ordinary disconnect, consumer-dispatch failure and shutdown with no active lease.

### R5 — P1: Firmware authorization is checked before enqueue, not owned until handoff/release

**Locations:** `resource.rs:41-69`, `:113-133`, `:239-283`; `hardware/mod.rs:329`, `:413-453`, `:674-709`; `hardware/service.rs:474-488`, `:547-549`.

`FirmwareHandoffPermit` borrows `&ResourceArbiter`; this does not prevent `release(&self, token)`, contrary to its comment. `begin_handoff` checks `authorizes`, then enqueues only port/generation/operation ID. The scanner has no lease/capability when it later closes the port. `release_firmware_lease` also does not check pending or active reservations. A queued handoff can therefore execute after its lease is released and consumer actuation resumed; early release after reservation can also strand the reservation because its required permit can no longer be obtained.

**Source-level reproduction:** hold scanner progress in a fake enumeration/write; acquire firmware lease and obtain a fresh current sample; enqueue handoff; release the lease; unblock scanner. The queued command still closes and reserves the port without an active lease. No Rust borrow error prevents the release, since both calls borrow the arbiter immutably.

**Required fix:** The owned handoff operation must retain a live arbiter capability/pin through queued dispatch, close, reservation lifetime and reservation release. Prevent lease release while dependent work/reservation exists, or cancel and await it before release. Validate capability at the actual close boundary. Do not solve this by a second non-atomic pre-check. Add blocked-scanner cancellation/release race tests.

### R6 — P1: A configuration worker holds the repository mutex while waiting for dispatcher ACKs

**Locations:** `hardware/service.rs:726-740`, `:886-894`; `hardware/configuration.rs:94-119`.

The worker locks the single repository before invoking all of `apply_configuration`, including serial writes and the ACK wait. The dispatcher synchronously takes the same mutex for discovery lookup. A discovery event for another board can block the sole dispatcher while configuration waits for an ACK queued behind that event. The operation times out even though the ACK arrived, and unrelated input/source-loss dispatch is stopped for the entire wait. A queued stale ACK is then retained for a later operation.

**Source-level reproduction:** configure port A with its ACK temporarily held in the fake; introduce port B and let its Discovered event reach repository lookup; then deliver A's ACK. Dispatcher is blocked on repository owned by A's worker, so it cannot deliver the ACK until A times out. This is a deterministic lock/wait dependency, not a missing real database adapter.

**Required fix:** Restrict repository locking to individual load/confirm/save calls, never serial sends or ACK waits. Keep blocking repository work off the sole authoritative event dispatcher, return results with current-generation/operation checks, and isolate ACKs by owned port/operation. Add a two-port discovery-during-configuration regression and assert unrelated inputs/source-loss continue.

### R7 — P2: Discovery still cannot report its deadline while open/flush is blocked

**Locations:** `hardware/mod.rs:100-116`; `hardware/discovery.rs:69`, `:119-127`; `hardware/transport.rs:29-39`.

The new deadline begins only after `transport.open` returns. `io.flush()` is synchronous and has no deadline/cancellation parameter or independent watchdog. `set_timeout` adjusts serial read/write timeouts; the pinned native Windows adapter delegates flush directly to `FlushFileBuffers` (`serialport-4.10.1/src/windows/com.rs:255-259`) rather than implementing a deadline-aware flush. The scanner does not monitor a discovery start deadline independently. Thus the report's claim of an enforced outer budget spanning all I/O is too strong.

**Source-level reproduction:** a fake open, or flush after the identity request, waits on a condition variable beyond the discovery budget. No discovery timeout event is emitted until it returns or an unrelated shutdown request closes/quarantines the owner. Continuous nonblocking noise is fixed and is not being re-reported.

**Required fix:** Track the discovery deadline at the owner/coordinator boundary, report timeout and revoke the source independently of blocked native calls, and retain/quarantine the owner until join. Where native interruption is available, use it; otherwise state the retained-owner limitation accurately. Test a blocked open and blocked flush with bounded externally released fakes.

### R8 — P2: Calibration overflow does not finish the owned lease lifecycle

**Locations:** `hardware/sessions.rs:294-303`; `hardware/service.rs:975-984`, `:1037-1079`, `:610-654`.

Overflow latches a terminal result, but dispatcher handling only publishes `calibration_error`. Automatic lease release handles only SourceLost; completion release is inside the caller-invoked `advance_calibration`. If the UI listener has gone away, an overflowed terminal session leaves its calibration lease active, suspending the port and making unrelated lease acquisition Busy until another caller explicitly cancels/advances it.

**Source-level reproduction:** start a calibration with capacity one, advance to collecting, deliver two samples while the listener is absent; state becomes Overflowed but the arbiter retains the calibration token indefinitely.

**Required fix:** Have the operation owner handle terminal overflow/error cleanup independently of UI calls, retaining the terminal result while completing the lease transition under the fresh-input rule. If overflow intentionally requires manual fail-closed recovery, expose that as an explicit failed-resource state and recovery contract rather than leaving an apparently live calibration lease.

### R9 — P2: Retrying a joined-but-panicked port owner panics the scanner

**Locations:** `hardware/mod.rs:286-307`, `:695-709`, `:728-750`, `:781-806`.

`close` takes the JoinHandle before `join()`. A panicked worker returns an I/O error with `join=None`. Scanner error paths retain that task just as they retain a timeout, then call `close` again, whose `expect("port task already joined")` panics. This can terminate the scanner and drop handles for other live ports. A joined worker panic is materially different from an unfinished worker timeout.

**Source-level reproduction:** fake serial read panics after discovery; trigger close/handoff or shutdown. First close reports the join panic, next cleanup pass panics the scanner. Other fake owners can still be active then.

**Required fix:** Represent unfinished, joined-success and joined-failure outcomes explicitly. Retain only unfinished owners; report a joined worker failure without retrying an absent handle or dropping unrelated live owners. Add a two-port fake test with one worker panic and prove the other remains owned and is joined on shutdown.

## Integration and shutdown boundaries

The service is now a genuine internal owner; this is substantial progress over isolated helper types. The low-level blocked-port timeout is accurately retryable and does not silently release the port, and shutdown correctly stays pending while a firmware reservation is held. Final service shutdown still performs synchronous dispatcher/configuration/timer joins and synchronous consumer callbacks without a bounded timeout, so it must not be advertised as universally deadline-bounded. No new detached-owner claim is made for those ordinary joins; the specific false-success and admission defects are R3/R4.

The next database adapter should implement short repository operations and must not inherit the lock-across-ACK design. AppServices/desktop registration, concrete simulator/vJoy adapters, actual flasher integration and physical-board acceptance remain declared later gates. None of those gates resolves the defects above. Prior independent review artifacts remain unchanged.
