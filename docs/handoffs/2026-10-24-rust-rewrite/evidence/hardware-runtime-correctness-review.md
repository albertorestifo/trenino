# Hardware runtime correctness review

Scope: committed diff `6c2d99b..8723455` on `codex/rust-rewrite`. I read the implementation, focused tests, core configuration builder and legacy detection/calibration behavior. Scoped hardware files match the commit; sibling working-tree changes were excluded. This is a static call-path review with concrete fake reproductions below, not a physical-device run.

## Verdict

**Spec: not accepted. Quality: not accepted.** The bounded codec itself has a credible 523-byte derivation and its focused tests cover the largest matrix payload and discard/resynchronization. The runtime still lacks the required owned route/configuration/session/arbiter integration, and several port lifecycle paths can abandon an open serial owner or reopen a reserved port. Existing tests exercise isolated helpers and a happy-path scanner but not these failure paths. Full repository adapter, desktop wiring and board acceptance remain explicit later gates, as the implementation report states.

## Findings

### P0 — Cleanup timeout abandons the live port owner and can reopen its port

**Lines:** `crates/trenino-runtime/src/hardware/mod.rs:239-255`, `:431-455`, `:485-500`, `:521-556`, `:578-592`.

`OwnedPortTask::close(self, deadline)` consumes its `JoinHandle`; at the deadline it returns an error and drops that handle. The worker may still be blocked in `SerialIo::read`, `write_all`, `flush`, `transport.open`, or the event sink. The scanner has already removed the owner from `ports`. On failed-port cleanup it schedules retry; on removed-port cleanup it may reach the same scan's `available` loop; on handoff failure it leaves no reservation. Any of these can start another owner for the same OS port while the old one is alive. `shutdown()` emits a `Failed` event for a timed-out close and still returns `Ok(())` after joining only the scanner.

**Fake reproduction:** make `SerialIo::read` block on a condition variable beyond a short `with_policy(..., cleanup_deadline)`; discover it, request handoff or remove it from enumeration, and observe `close` time out while the old fake handle remains held. A subsequent scan attempts `open` again; `shutdown()` returns success with the fake read still blocked. This follows directly from the `JoinHandle` being dropped on the timeout path.

**Required fix:** retain a joining/closing owner state and its handle until it actually exits, prohibit reopen and firmware handoff while that owner exists, and propagate unresolved shutdown failure to the caller. Define cancellation or bounded native I/O for reads and writes, including open/discovery and sink delivery; a deadline error must preserve the ability to join later.

### P1 — A second handoff replaces the first reservation and can resume scanning during firmware use

**Lines:** `crates/trenino-runtime/src/hardware/mod.rs:279-283`, `:431-467`.

After the first successful handoff removes the port task and stores its generation, another `handoff_port` for the same port takes the `else` branch and overwrites the reservation with generation `0`. Releasing the second token removes that reservation and sets `next_scan = now`, although the first caller can still be flashing. A public, cloneable token consisting only of port and generation also lets any caller construct a matching release from a known discovered generation.

**Fake reproduction:** discover `COM42` at generation 1; hand it off twice; the second call returns generation 0; release that second handoff and observe a new fake `open` while the first handoff remains outstanding.

**Required fix:** reject an already reserved port with a typed `Busy` result, make the token opaque and unique per handoff, and preserve the reservation until its original owner releases it after the flash process exits.

### P1 — The scanner does not own routing, configuration acknowledgments, detection or calibration

**Lines:** `crates/trenino-runtime/src/hardware/mod.rs:24-45`, `:114-119`, `:154-174`, `:387-599`; `crates/trenino-runtime/src/hardware/configuration.rs:7-11`, `:45-52`; `crates/trenino-runtime/src/hardware/sessions.rs:279-399`.

The only integration from a per-port task is a raw `PortEvent` callback. No committed hardware runtime path owns a shared `InputResolver`, `InputValueCache`, `HardwareSessions`, or `ResourceArbiter`; no event path looks up `ConfigId`/pin, queues button edges, feeds samples, delivers a current-generation configuration ACK, invalidates mapping/cache on disconnect, or invokes session source loss. `ConfigurationPort` has only a test fake implementation; `DiscoveryHandle` cannot implement its `receive` contract and `send_message` has no generation argument. The tests call each helper independently, so a discovered `InputValue` currently produces only a raw event and no authoritative routed effect. This is more than the explicitly deferred database/desktop/consumer adapters: the required task ownership and internal connection among already delivered components is absent.

**Fake reproduction:** use the existing `FakeTransport` and emit a discovered `InputValue`, then `Closed`; there is no runtime-owned resolver/cache/session state to inspect or update. Supplying an external callback to do all of that moves the required ownership outside this slice and must still invent an ACK stream and ordering contract.

**Required fix:** add a single runtime-owned dispatcher/state owner for generation-checked discovery, input routing/cache, ordered authoritative queues, configuration ACKs, and session lifecycle. Keep repository and actual simulator/vJoy adapters injectable, but prove the internal ownership and event ordering with a fake end-to-end test.

### P1 — Discovery loses frames coalesced after the identity response

**Lines:** `crates/trenino-runtime/src/hardware/discovery.rs:84-100`; `crates/trenino-runtime/src/hardware/mod.rs:97-119`.

`decoder.push(read_bytes)` returns all frames from a read. `discover_with_cancel` returns immediately on the matching identity response, dropping the rest of that vector and any partial bytes held by its local decoder. `OwnedPortTask` then creates a fresh decoder. Thus a button edge or calibration sample in the same read, or the beginning of its frame, disappears. The contract explicitly requires partial/coalesced reads and preserved ordered edges/samples.

**Fake reproduction:** have one fake `read` return `IdentityResponse(request_id)` followed by `InputValue(pin=2,value=1)` in the same byte slice, or identity plus the first half of an input frame and the remainder in the next read. Discovery succeeds but the port sink never receives that input.

**Required fix:** carry the decoder and all trailing decoded/partial data across the discovery-to-connected transition, then deliver trailing messages in original byte order before the next read.

### P1 — Detection timeout and source-loss transitions are not owned

**Lines:** `crates/trenino-runtime/src/hardware/sessions.rs:32-56`, `:56-93`, `:279-399`.

Detection checks its deadline only inside `observe`; a quiet device never causes a `TimedOut` transition. The registry has no clock task/tick or terminal notification. `HardwareSessions::source_lost` visits only calibrations, while detection sessions lack a port/generation binding, so a disconnected and reconnected port leaves old baselines active. Its next value can be reported as a detection for the new source against the prior source's baseline. A `source_lost` method exists on the individual detection type but is never called by the registry.

**Fake reproduction:** insert a detection with a 1 ms deadline, wait without feeding input, and it remains merely stored/Pending; call `HardwareSessions::source_lost("COM1", 3)` and its detection still reports `Pending` or `Detected` on a later `observe` rather than `SourceLost` (before the deadline).

**Required fix:** bind detections to current source generations, drive deadlines independently of input traffic, dispatch source-loss on disconnect/handoff, and expose a terminal outcome that survives listener/UI cancellation.

### P1 — Calibration reports Complete before its save succeeds

**Lines:** `crates/trenino-runtime/src/hardware/sessions.rs:238-267`.

`advance()` sets `step = Complete` before `advance_and_persist()` calls the repository. If persistence fails, the caller gets `SessionError::Persist`, but `step()` remains `Complete` and a retry of `advance_and_persist()` returns `InvalidStep`; there is no stored result/error. The legacy session broadcasts the save error as its terminal result. This violates preservation of save errors and makes recovery impossible without discarding samples and starting over.

**Fake reproduction:** feed the minimum ten/ten/ten valid samples as in the existing test, use a repository fake returning `Err("database unavailable")`, call `advance_and_persist`, then inspect `step() == Complete` and a second call returning `InvalidStep`.

**Required fix:** keep analysis/persistence in an explicit pending state until save succeeds; record and publish the save error, with a defined retry or terminal failure transition. Do not claim completion on a failed save.

### P1 — Generation-unbound write and handoff commands can target a replacement connection

**Lines:** `crates/trenino-runtime/src/hardware/mod.rs:265-276`, `:296-337`, `:415-455`.

`SendMessage` and `HandoffPort` carry only a port name, not the generation the caller observed. The scanner resolves the command against `ports` when it eventually dequeues it. If the old connection fails or is removed and a new generation opens before a queued command is processed, the old caller's output or handoff can affect the new device on the same OS port. The scanner can be delayed by synchronous sends, close, enumeration, and callbacks. This breaks the brief's generation fencing for writes and handoff.

**Fake reproduction:** queue a command behind a deliberately blocked scanner operation, replace the fake port identity/generation, then release the block. The command is dispatched to `ports.get(&port)` for the new generation; no comparison with the caller's generation occurs.

**Required fix:** require the observed generation for each write and handoff request and reject stale commands at dispatch. Make reservation identity independent of public generation fields.

### P2 — The 10-second discovery deadline is declared but unenforced

**Lines:** `crates/trenino-runtime/src/hardware/mod.rs:21`, `:84-113`; `crates/trenino-runtime/src/hardware/discovery.rs:47-106`.

`DISCOVERY_TIMEOUT` is never used. The stale-byte drain loops until a timeout/zero, and `open`, `write_all`, and `flush` are blocking with no outer deadline. Continuous boot chatter can hold discovery forever; the five per-attempt timers do not bound total elapsed time. A blocked discovery then falls into the abandoned-owner path above on cleanup.

**Fake reproduction:** implement `SerialIo::read` to return nonempty garbage forever during the drain phase, with zero settle. `discover_with_cancel` never reaches the first identity request or a 10-second failure unless an external caller changes its cancel flag.

**Required fix:** enforce one monotonic discovery deadline across open/settle/drain/attempts and ensure each blocking native operation can be interrupted or retained for eventual join. Test with a fake continuous byte stream.

### P2 — Malformed frames force connection failure instead of delimiter recovery

**Lines:** `crates/trenino-core/src/hardware/protocol/codec.rs:424-457`; `crates/trenino-runtime/src/hardware/mod.rs:154-174`, `:473-499`.

The decoder correctly bounds an overlong frame and discards through its delimiter, but the real port loop marks any decoder/decode error as port failure and stops handling the remaining packets from that same read. The scanner then closes and retries the port. Thus a valid frame after the malformed delimiter in a coalesced read is lost, despite the required successful resynchronization at the transport boundary.

**Fake reproduction:** after discovery, return `524` nonzero bytes, delimiter, and an encoded valid `InputValue` in one fake read. The decoder returns error then valid message, but the port loop breaks at the error, emits `Failed`, and the scanner closes the connection.

**Required fix:** report malformed-frame diagnostics without poisoning the connection; continue processing decoder results after the delimiter and retain the same owner unless actual I/O or repeated failures require teardown.

## Coverage and boundaries

The committed tests cover isolated resolver replacement, cache invalidation, configuration fake persistence, calibration thresholds/overflow, discovery retry, happy-path handoff, and codec frame bound. They do not cover blocked read/write/open cleanup, repeated reservation, coalesced post-identity input, quiet detection timeout, source loss for detection, save failure state, stale-generation output dispatch, or malformed-frame recovery in the port loop. I did not touch production code or run physical I/O, drivers, simulator, flashing, or a user database.
