# Independent adversarial review: hardware runtime slice

Scope: committed `6c2d99b..8723455` hardware/routing/resource/codec implementation, read at `e9ef8d9` where these source files are unchanged. Reproductions below are source-level call sequences with specified disposable fake behavior; I did not run executable probes or the broad test suites reported by the implementer. No real ports, drivers, simulator, flash, or user database were accessed.

## Findings

### P0 — Timed-out cleanup abandons a live serial owner and permits a second owner

**Location:** `crates/trenino-runtime/src/hardware/mod.rs:239-255`, `:431-456`, `:485-499`, `:521-535`, `:577-592`.

**Reproduction:** Supply a fake `SerialIo` whose `read` (or `write_all`) blocks longer than `cleanup_deadline`. After discovery, request handoff or remove the port from enumeration. `OwnedPortTask::close` takes and drops its `JoinHandle` on timeout and returns an error. The scanner has already removed the task from `ports`; for handoff it does not reserve the port on error. On a later scan it can spawn another task for the same path while the first fake still owns its serial handle. During `shutdown`, the scanner reports the timeout event but `DiscoveryHandle::shutdown` joins only the scanner and returns `Ok(())` even though the port worker continues running. The same failure path exists in failed-port retry.

**Required fix:** Retain timed-out workers in an owned closing/failed state, never reopen or hand off that port until the worker has joined and the handle has closed, and propagate unresolved owner failure from shutdown. A timeout must be observable without detaching the native owner.

### P1 — Write and firmware handoff commands can cross reconnect generations

**Location:** `crates/trenino-runtime/src/hardware/mod.rs:265-276`, `:296-337`, `:415-456`.

**Reproduction:** Observe generation 8 on `COM8`, then disconnect and reconnect it as generation 9. A request prepared using generation 8 calls `send_message("COM8", ConfigureAnalog { .. }, ...)`; the scanner looks up only the port name and writes to generation 9. Likewise, a stale `handoff_port("COM8", ...)` closes generation 9, even if the firmware lease was acquired for generation 8. The worker's event callback fence does not cover these outgoing commands.

**Required fix:** Require expected generation in send and handoff commands and compare it with the active owner before enqueueing/writing/closing. Return a typed stale-generation result. Bind the handoff reservation to the matched generation and lease.

### P1 — Resolver invalidation does not fence a disconnected or reconfigured generation

**Location:** `crates/trenino-runtime/src/routing.rs:29-75`; configuration uses it at `crates/trenino-runtime/src/hardware/configuration.rs:69-70`, `:125-132`.

**Reproduction:** `replace_port("COM8", 8, cfg, map)`, then `invalidate_port("COM8", 8)`, then `replace_port("COM8", 8, cfg, map)` succeeds and routes the supposedly invalidated source. `invalidate_port` removes a route but does not advance a tombstone or reject later replacements at the same generation; `replace_port` rejects only *lower* generations. This also permits a delayed configuration ACK/persist continuation to publish a mapping after source loss when no external actor has installed a newer generation. The cache's `activate` has a parallel same-generation resurrection path (`routing.rs:181-208`).

**Required fix:** Keep authoritative generation and connection/configuration epoch state for each port. Invalidation must mark that generation unusable until a specifically authorized current-generation configuration activation, under one coordinated transition for resolver and cache. A late call must not reactivate after disconnect.

### P1 — Handoff timeout can orphan a reservation

**Location:** `crates/trenino-runtime/src/hardware/mod.rs:318-337`, `:431-469`.

**Reproduction:** Use a fake port whose close finishes after the caller's `handoff_port` timeout but before the scanner's cleanup deadline. The caller gets `"port handoff timed out"`; the scanner then inserts `reserved_ports[port]` and sends the token into a dropped reply channel. Only `release_handoff(token)` can remove the reservation, so the port is not rediscovered for the rest of that runtime. The same request/reply design allows release timeout to hide whether release happened.

**Required fix:** Make handoff cancellation/commit explicit. After caller timeout, either abort reservation safely or expose a retrievable operation/token state. Do not commit a handoff whose reply receiver is gone without an owner that can release it.

### P1 — Public port handoff does not require a firmware lease or neutralization

**Location:** `crates/trenino-runtime/src/hardware/mod.rs:318-327`, `:431-456`; `crates/trenino-runtime/src/resource.rs:83-170`.

**Reproduction:** Start an owned port and call `DiscoveryHandle::handoff_port("COM8", ...)` directly, without calling `ResourceArbiter::acquire`. The scanner closes the port and returns its reservation. It has no arbiter reference or lease token, so there is no required `suspend_actuation`, calibration cancellation, or `source_lost` acknowledgment before the port becomes available to a flasher. Separate documentation tells a future caller to order these APIs, but the ownership boundary does not enforce it.

**Required fix:** Put firmware handoff behind one operation that validates an active same-port, same-generation firmware lease and completed consumer neutralization, or give the scanner a verifiable capability produced by the arbiter. Prevent direct bypass through the public handle.

### P1 — Detection source loss and calibration save failure have no correct terminal ownership

**Location:** `crates/trenino-runtime/src/hardware/sessions.rs:32-38`, `:56-92`, `:223-273`, `:282-399`.

**Reproduction:** Insert a detection session and call `HardwareSessions::source_lost("COM8", 8)`: only calibrations are transitioned; the detection stays pending and can later detect from a reused `COM8` because its baseline key has no generation. There is no registry-owned clock operation to publish `TimedOut` unless a caller happens to call `observe`. For calibration, use a repository fake returning an error from `persist_calibration`: `advance_and_persist` returns `Persist`, but `advance` has already set `Complete`, so retrying persist returns `InvalidStep` and the result is not retained.

**Required fix:** Bind detection to source generation and transition it on source loss and owned timeout independent of incoming samples/UI listeners. Keep calibration in an explicit save-pending/save-failed state with the computed result so persistence errors can be reported and retried or explicitly terminated without losing operation ownership.

### P1 — Discovery's flush phase is unbounded despite the 10-second budget

**Location:** `crates/trenino-runtime/src/hardware/discovery.rs:47-108`; `DISCOVERY_TIMEOUT` is declared but unused at `crates/trenino-runtime/src/hardware/mod.rs:21`.

**Reproduction:** A fake `SerialIo::read` that repeatedly returns one byte in the stale-byte drain loop never reaches an empty read or timeout. The owned discovery task never sends an identity request or a failure event and can remain there indefinitely. Five read attempts and the configured per-read timeout do not bound this phase. Its later cleanup can hit the detached-owner path above.

**Required fix:** Enforce one outer discovery deadline across settle, drain, attempts and writes; check time and cancellation after every read, including successful reads. Return a bounded discovery failure and preserve the worker until joined.

### P2 — Serial command queues are unbounded under blocked I/O

**Location:** `crates/trenino-runtime/src/hardware/mod.rs:80`, `:230-236`, `:392-393`, `:302-316`.

**Reproduction:** Hold a fake serial write, then issue many concurrent `send_message` calls. Both scanner and per-port `mpsc::channel()` accept commands without a capacity or overflow result. Timed-out callers mark their writes cancelled, but queued messages/reply channels stay allocated until the worker drains them. The `EventQueue` bound does not apply to these commands.

**Required fix:** Use bounded command queues, return explicit busy/overflow, and ensure pending commands are failed or drained on teardown. Preserve ordered authoritative input separately from optional preview coalescing.

## Verdict

**Specification: not accepted.** The P0 cleanup path violates persistent per-port ownership, and P1 paths violate generation fencing, handoff recoverability, discovery deadline, and session lifecycle requirements. **Quality: changes required before adapter integration or hardware acceptance.** Existing fake tests cover normal flows but do not establish these failure transitions. The database adapter, desktop wiring, firmware caller integration, real consumers, and physical-board acceptance remain separate declared gates; this review does not attribute sibling AppServices or firmware work to this commit.
