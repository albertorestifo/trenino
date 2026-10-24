# Rust Simulator and Train Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move simulator integration, train configuration, controls, calibration, output displays, and Lua execution into Rust while retaining the Tauri desktop and the existing user workflows.

**Architecture:** `trenino-core` owns deterministic domain rules and DTOs; `trenino-runtime` owns simulator connections, train activation, controllers, sessions, script workers, and transactional persistence through the shared database worker. Tauri and the replacement presentation layer call service handles and render snapshots/events. No controller, HTTP call, script VM, or SQL belongs in a Tauri command.

**Tech Stack:** Proposed Tokio, reqwest, serde/serde_json, mlua (subject to compatibility gate), existing enigo, and the shared rusqlite database worker.

**Spec:** User-authorized full Rust migration on `codex/rust-rewrite`. Existing behavior references are `docs/train-configuration.md`, `docs/lever_input_mapping_architecture.md`, `docs/lua-scripting.md`, and the source/tests below. Reconcile interfaces with sibling hardware, desktop, persistence, and vJoy plans as each runtime slice is implemented.

## Global Constraints

- Implementation and local branch commits are authorized. Tests use disposable databases and fake simulator/hardware adapters; real user data and live effects are outside ordinary development verification.
- Preserve Tauri, visible train/device setup workflows, saved SQLite identities/relations, existing Lua scripts, and firmware wire protocol.
- Preserve two-decimal simulator/calibration/notch values per `CLAUDE.md`; define an Elixir-compatible rounding helper using golden cases rather than assuming Rust formatting is equivalent.
- Preserve database integer IDs, optional values, enum strings, enabled flags, ordered sequence commands, JSON triggers and timestamps; use shared DB transactions and publish reload events only after commit.
- vJoy and TSW exclusive routing uses the same transactional routing policy as the vJoy plan. No controller privately decides that exclusivity; no dual-live backend may write to the same simulator/device.
- Pure replay comparisons may run alongside Elixir; side-effecting parity runs use a fake simulator and fake hardware.

## Review Focus

- A stale request finishes after a train switch: its completion must never update the new train's cache or schedule another old write (Tasks 2, 4).
- A release arrives under input overload: it must not be coalesced away or leave a held key/button behind (Task 5).
- A wizard disappears mid-sweep: owner cancellation must remove subscriptions, stop future writes and discard uncommitted samples without undoing earlier committed wizard checkpoints (Task 4).
- An existing script loops, allocates heavily, or mutates state then fails: UI/runtime remain responsive and compatibility deviations are explicit (Task 7).
- Reconnection returns the same display value: hardware must still be reinitialized after lost state, while stale generations cannot redraw a cleared display (Task 6).

## Existing inventory and compatibility contracts

| Capability | Source of truth | Migration acceptance |
|---|---|---|
| Simulator HTTP and configuration | `lib/trenino/simulator/client.ex`, `connection.ex`, `connection_state.ex`; `lib/trenino/settings/simulator.ex`; `test/trenino/simulator/{client,connection,connection_state}_test.exs` | Preserve `DTGCommKey`, URL/path escaping, response envelopes, numeric/string decoding, explore/get/set/subscribe/get-subscription/unsubscribe operations and connection settings. Normal client uses 10s receive / 5s pool waits and two transient retries; fast client uses 1s receive / 500ms pool waits. Request deadlines and queue waits must be modeled separately; reqwest total timeout is not a literal replacement for Req's receive timeout. |
| Train detection and identifiers | `lib/trenino/train/detection.ex`, `identifier.ex`, `train_identifier.ex`, `lib/trenino/train.ex:83`; identifier/detection tests and `train_identifier_persistence_test.exs` | 5s normal poll; 30s disconnected grace with 200ms probes; preserve current profile while successful grace probes continue. Use drivable vehicle ObjectClass; actual fallback is index 0, despite common-prefix wording in module docs. Strip `_C` and trailing nonalphanumerics. Any stored identifier prefix may match; deduplicate matching profiles; multiple profiles cause ambiguity and deactivate instead of choosing the longest prefix. |
| Train/edit persistence | `lib/trenino/train.ex`, `train/{train,element,lever_config,notch,lever_input_binding,button_input_binding,sequence,sequence_command,output_binding,display_binding,script}.ex`; `test/trenino/train_test.exs`, context/schema tests | Port validation/defaults, relationship preloads, list ordering, cascade behavior and errors with the shared persistence plan. All CRUD paths (UI/API/MCP) use the same service operations. |
| Lever mapping and dispatch | `train/lever_mapper.ex`, `lever_controller.ex`; `hardware/calibration/calculator.ex`; mapper/controller/notch tests | Calibrated travel normalization, inversion including reversed-layout linear notches, gate centers, half-open ranges plus exact 1.0 boundary, missing mappings and two-decimal output. Existing controller already keeps one in-flight write and latest pending value per lever, acknowledges only successful writes, retries at 200/400/800ms and uses retry tokens. Preserve this instead of spawning per input sample. |
| Discovery and calibration | `simulator/control_detector.ex`, `control_detection_session.ex`, `lever_analyzer.ex`; `train/calibration/{lever_session,notch_mapping_session,session_supervisor}.ex`; matching tests | Preserve endpoint exploration/auto-suggestion, first-change threshold 0.01, 150ms detection poll and 30s timeout. Preserve analysis defaults: 0.02 sweep step, 150ms settling, snap 0.03, integer tolerance 0.05, five push attempts 30ms apart. Preserve wizard capture/navigation/preview/save, minimum ten notch samples and progress/error/cancel events. Hardware ADC calibration is owned by hardware plan; train-side interpretation is here. |
| Buttons, sequences, keyboard | `train/button_controller.ex`, `button_input_binding.ex`, `sequence*.ex`, `lib/trenino/keyboard.ex`, `tauri/keystroke/src/main.rs`; button and sequence tests | Simple on/off deduplication; matrix virtual inputs; momentary press `Interacting=1` before value, release value before `Interacting=0`; sequence command order with delay after each command; momentary release cancels, latching off-sequence starts. Existing momentary repeats immediately after each completed HTTP send, ignoring persisted `repeat_interval_ms`; retaining this baseline is distinct from a future rate-setting fix. Keep keystroke aliases and modifier press/reverse release order. |
| Outputs and displays | `train/{output_controller,output_binding,display_controller,display_binding,display_formatter}.ex`; matching tests; `hardware/ht16k33.ex` (hardware owner) | 200ms polling; output operators gt/gte/lt/lte/inclusive between and boolean-only eq_true/eq_false; mismatched types false. Display `{value}` / `{value:.Nf}` with N=0..10, numeric rounding, module minimum clamp, encode via existing chip parameters. Deduplicate only successful display sends, brightness on initialization, invalidate on reconnect, blank on cleanup. Preserve each controller's differing invalid subscription response behavior through fixtures. |
| Lua scripts | `train/{script_engine,script_runner,script}.ex`, `train/script/triggers_type.ex`; engine/runner/context/schema tests; `docs/lua-scripting.md` | VM per enabled script with persistent `state`; `on_change({source,value,data})`, manual/scheduled source strings, 200ms poll, change-only trigger comparison, ordered deferred effects and newest-first last 100 logs. `api.get` currently returns nil plus `not available` and records an ignored effect: do not silently add synchronous reads. `schedule` replaces the prior timer. `output.set` truncates IDs and uses Lua truthiness; `display.set` resolves the first matching global I2C address, which is ambiguous across devices. |

The current script runner enforces a 200ms execution window using `Task.yield` and `Task.shutdown(:brutal_kill)` (`script_runner.ex:375` onward). Loading/compiling executes top-level code synchronously without that runner timeout. These are different contracts. Replacing `api.get`, address resolution, momentary cadence or failed-write caching is a functional correction, not automatic migration parity.

## Proposed file ownership

All paths below are proposed additions, unless existing sources are explicitly named. Names are interface design to reconcile, not a claim of compile-ready signatures.

| Files | Responsibility |
|---|---|
| `crates/trenino-core/src/simulator/{dto,value}.rs` | Wire-independent endpoint/value/error DTOs and conversion rules |
| `crates/trenino-core/src/train/{model,identifier,validation,lever,output,display,script}.rs` | Saved model, prefix matching, validation, mapping, output predicates, formatting and script event/effect DTOs |
| `crates/trenino-core/src/calibration/{model,analysis,notch_mapping}.rs` | Pure analysis and wizard transitions |
| `crates/trenino-runtime/src/simulator/{client,connection,subscriptions,writer}.rs` | HTTP adapter, lifecycle, subscription leases, ordered/generation-checked writes |
| `crates/trenino-runtime/src/train/{service,detection,lever_controller,button_controller,sequence,output_controller,display_controller}.rs` | Runtime ownership and controller lifecycles |
| `crates/trenino-runtime/src/calibration/{registry,control_detection,lever_session,notch_session}.rs` | Cancellable sessions, monotonic timers and progress |
| `crates/trenino-runtime/src/scripts/{engine,worker,runner,effects}.rs` | Lua VM, worker supervision, trigger scheduling, typed effect execution |
| `crates/trenino-runtime/src/keyboard.rs` | Long-lived OS keyboard adapter and held-key ownership |
| `crates/trenino-runtime/src/storage/trains.rs` | Shared DB worker operations for train aggregate CRUD (coordinate persistence owner) |
| `crates/trenino-core/tests/controls_parity.rs`, `crates/trenino-runtime/tests/{simulator_lifecycle,train_sessions,control_dispatch,output_display,script_compatibility}.rs`, `tests/fixtures/controls/` | Golden fixtures, fake services, paused-clock and lifecycle acceptance |

## Shared interfaces and OTP replacement

Use named newtypes `TrainId`, `ElementId`, `BindingId`, `ScriptId`, `InputId`, `ModuleId`, `SessionId`, `DeviceId` and monotonic `Generation(u64)`. `Endpoint(String)` validates without rewriting existing paths. `SimValue` distinguishes Number(f64), Bool, String and Null; rejects non-finite external numbers with a typed validation error. DTOs carry unchanged external field names through serde attributes.

- `SimulatorHandle::get(endpoint: Endpoint) -> Result<SimResponse, SimulatorError>` and `set(write: SimulatorWrite) -> Result<WriteAck, SimulatorError>` are async; `SimulatorWrite` contains generation, ordered command ID, source owner, endpoint and SimValue. Check generation before dispatch and before processing completion. HTTP already accepted by TSW cannot be revoked; drain the old in-flight writer before new-generation actuation.
- `SubscriptionService::acquire(owner: OwnerId, generation: Generation, endpoints: Vec<Endpoint>) -> Result<SubscriptionLease, SimulatorError>` and `release(lease: SubscriptionLease)` are async. Lease has session-local token, generation and endpoint mapping. Service allocates collision-free simulator IDs (current consumers use 99, 1000+, 2000+, 3000+), deduplicates endpoints within a consumer and explicitly tracks cross-consumer ownership; never unsubscribe a live owner's lease.
- `TrainService::snapshot() -> TrainSnapshot`, `apply(command: TrainCommand) -> Result<TrainSnapshot, DomainError>` (async), and `subscribe() -> EventReceiver<TrainEvent>`. Snapshot carries generation, active ID, detected identifier, ambiguity candidates and binding revision. `TrainCommand` covers CRUD and forced detection sync; mutations are atomic DB operations before publication.
- `LeverMapper::map(config: &LeverConfig, normalized: f64) -> Result<f64, MappingError>`; `evaluate_output(binding: &OutputBinding, value: &SimValue) -> bool`; `format_display(template: &str, value: &SimValue) -> Result<String, FormatError>` are pure.
- `CalibrationService::start(request: SessionRequest, owner: OwnerId) -> Result<SessionId, SessionError>`, `command(id: SessionId, command: SessionCommand) -> Result<SessionSnapshot, SessionError>`, `cancel(id: SessionId)` are async. Session commands cover capture start/stop/reset, next/back/select-notch, preview/save. Save validates generation and binding revision in the DB transaction.
- Hardware boundary consumes ordered `InputEvent { device_id, connection_generation, input_id, sequence, value }`; output commands use durable device/module IDs resolved by hardware service, not captured port strings. `OutputSink` exposes async `set_output` and `write_display` and returns actual dispatch errors.
- Shared routing mutation applies `RoutingChange` transactionally, returns `RoutingSnapshot { revision, assignments }`, and only then emits `RoutingChanged`. TSW/vJoy controllers cancel old work, acknowledge the revision barrier, then activate the new route. During calibration a temporary endpoint/input lease suspends normal actuation for the leased resource. Conflict errors surface in UI/API/MCP consistently.

Each prior GenServer becomes one state-owning task with typed messages and reply channels. A runtime supervisor owns JoinHandles, child cancellation tokens and restart budget; do not assume Tokio tasks restart like OTP children. Controller panic invalidates generation, cancels children and reports degraded state; rebuild from committed configuration and fresh device/simulator snapshots, without replaying button edges or sequence effects. Session tasks are registered by ID/resource, removed on all exit paths, and cancelled when their UI/API owner ends.

Proposed bounded defaults for review: 256 ordered messages per controller, 64 script events per script, 256 effects per execution, one in-flight plus one latest value per lever. UI snapshots and analog latest-state telemetry may coalesce. Button edges, sequence commands, script effects and wizard transitions cannot coalesce. Backpressure uses bounded send with cancellation; input ingress that cannot wait must report overflow and reset/release the affected owner, never silently lose an edge. A separate cancellation/release path cannot wait behind a saturated normal queue. Script polling is already sampling, but observed trigger transitions are ordered; an overloaded script fails explicitly rather than silently skipping observations.

Shutdown order: stop admission/pollers; invalidate activation generation; cancel sessions, repeats, sequences and script timers; release held keyboard keys and simulator Interacting state while adapters remain alive; blank displays according to existing cleanup behavior; release subscriptions; await workers with deadlines; stop hardware/network and DB last. Cleanup failures become diagnostics, not a claim of successful release. Output relay reset policy must follow captured baseline or be separately approved; do not invent an all-off rule during a parity migration.

## Library candidates verified on 2026-10-24

- [Tokio bounded mpsc](https://docs.rs/tokio/latest/tokio/sync/mpsc/) supplies bounded mailboxes/backpressure; use latest-state channels only for replaceable snapshots. [Tokio shutdown guidance](https://tokio.rs/tokio/topics/shutdown) documents cancellation tokens and waiting for tracked tasks. Restart policies remain application code.
- [reqwest Client](https://docs.rs/reqwest/latest/reqwest/struct.Client.html) provides a reusable pooled async client; [ClientBuilder](https://docs.rs/reqwest/latest/reqwest/struct.ClientBuilder.html) documents total/read/connect deadlines. Disable proxy routing for configured local TSW connections where appropriate and explicitly map legacy timeout/retry policy. Never retry non-idempotent actions just because reads may retry.
- [mlua Lua](https://docs.rs/mlua/latest/mlua/struct.Lua.html) exposes instruction hooks and memory limits. Candidate is vendored standard Lua, not Luau by assumption; choose the Lua version only after running the current `lua` 1.0.2 compatibility corpus. Hooks require coverage of coroutines and cannot interrupt arbitrary blocking native callbacks.
- [enigo Keyboard](https://docs.rs/enigo/latest/enigo/trait.Keyboard.html) provides key press/release and raw key APIs. Existing sidecar already depends on enigo 0.6. Extract its parsing/aliases into the runtime adapter without changing logical keys into scan codes during migration.

Pin tested versions/features in the future Cargo lockfile only after toolchain/platform/license review. Primary documentation establishes capabilities, not parity proof.

## Task 1: Capture executable contracts and persisted aggregates

**Files:** Create `tests/fixtures/controls/`, `crates/trenino-core/tests/controls_parity.rs`; future fixture extraction helpers next to existing ExUnit tests; add `storage/trains.rs` with persistence owner.

**Interfaces:** Produces versioned fixtures containing input, saved DB row shape, expected DTO/errors, emitted commands/events and virtual-clock timestamps. Consumes existing schema/ExUnit expectations.

- [ ] Add failing Rust fixture tests for identifier prefix ambiguity/deduplication, mapper boundaries/reversal, output boolean-vs-number rules and display formatting; establish the old ExUnit output as oracle.
- [ ] Extract simulator request/response cases and script event/effect/state sequences, including errors and non-ASCII strings. Include older migrated DB profiles with missing optional values.
- [ ] Implement the pure model/validation helpers and DB aggregate transaction mapping; verify round-trip IDs, nulls, enum values, sequence order and trigger JSON.
- [ ] Run `cargo test -p trenino-core --test controls_parity`; expect exact fixture agreement. Run existing `mix test test/trenino/train_test.exs test/trenino/train test/trenino/simulator` when baseline toolchain is available; record unrelated baseline failures separately.
- [ ] Review fixture coverage and commit this independently testable foundation during approved execution.

## Task 2: Simulator lifecycle and owned subscriptions

**Files:** Create runtime `simulator/{client,connection,subscriptions,writer}.rs`, tests `simulator_lifecycle.rs`.

**Interfaces:** Produces SimulatorHandle and SubscriptionService above; consumes existing settings DTO and runtime supervisor.

- [ ] Write failing fake-HTTP tests for authentication, all endpoint operations, envelopes, fast/normal timeout classification, connected/retrying transitions, lease uniqueness and reference-counted cleanup.
- [ ] Implement HTTP client with pooled connections; preserve legacy health timing (30s healthy checks/retries, 2s fast checks) and exact failure threshold from `connection.ex` fixtures. Keep configuration updates atomic.
- [ ] Implement bounded writer ownership and generation fences; test an old request completing during switch, blocked server, invalid response and subscription creation failure. Discard stale completion; no new train write overtakes unresolved old transport work.
- [ ] Run `cargo test -p trenino-runtime --test simulator_lifecycle`; expect deterministic fake-server traces, no leaked leases/tasks and no unbounded queue growth.
- [ ] Review transport retry semantics and commit.

## Task 3: Detection and train activation

**Files:** Create core `train/identifier.rs`, runtime `train/{service,detection}.rs`; extend `train_sessions.rs` and storage fixtures.

**Interfaces:** Produces TrainSnapshot/TrainEvent and committed binding revisions; consumes SimulatorHandle, DB aggregate reads and shared RoutingSnapshot.

- [ ] Write paused-clock tests for drivable-index fallback, normalization, any-prefix matching, same-profile duplicates, cross-profile ambiguity, manual sync after CRUD and unchanged identifier.
- [ ] Implement activation coordinator; snapshot configuration once per revision and notify controllers through a cancellation/activation barrier. Port 5s polling and exact 30s grace semantics, including successful probes extending grace without changing the detected profile.
- [ ] Test disconnect/reconnect inside grace, grace expiry, no prior client and late timer messages; assert identical UI-visible events and no duplicate poll loops.
- [ ] Run `cargo test -p trenino-runtime --test train_sessions`; expect all activation traces and DB commit-before-event assertions passing; review and commit.

## Task 4: Levers, exploration and calibration sessions

**Files:** Create core `calibration/*`, runtime `train/lever_controller.rs`, `calibration/*`; extend `controls_parity.rs`, `control_dispatch.rs`, `train_sessions.rs`.

**Interfaces:** Produces pure LeverMapper and CalibrationService; consumes hardware calibration snapshots, SimulatorHandle and temporary routing leases.

- [ ] Port table-driven mapper/analyzer tests before implementation: 0/1 boundaries, missing ranges, zero travel, inverted and reversed hybrid layouts, gate centers, simulator range distinct from physical range and rounding ties.
- [ ] Implement one-in-flight/latest-pending dispatch with success-only acknowledgement and 200/400/800ms retry tokens; test 10,000 incoming samples leave bounded state and final value is delivered without stale retries.
- [ ] Port control discovery/auto-suggestion and analyzer using recorded API results and injected clock; preserve defaults above and non-default options.
- [ ] Implement session registry and wizard transitions from existing lever/notch session tests: capture at least ten samples, reset, back/select, preview and atomic save. Port error/progress payloads for UI/MCP consumers.
- [ ] Test owner disappearance, train switch, device disconnect and DB revision conflict during save. Cancellation prevents further sweeps, removes leases and discards uncommitted samples. It does not roll back already committed endpoint configuration, completed calibration, input binding or mapping saves. Test cancellation both before and after each persistence checkpoint; a commit already completed before cancellation remains visible.
- [ ] Run `cargo test -p trenino-core --test controls_parity` and `cargo test -p trenino-runtime --test control_dispatch --test train_sessions`; review recorded wizard walkthrough and commit.

## Task 5: Buttons, ordered sequences and keyboard

**Files:** Create runtime `train/{button_controller,sequence}.rs`, `keyboard.rs`; extend `control_dispatch.rs`; extract parser from existing keystroke sidecar only during execution.

**Interfaces:** Consumes ordered InputEvent and routing revision; produces ordered SimulatorWrite and Keyboard actions. Keyboard adapter owns held-key reference counts by binding/owner.

- [ ] Write failing traces for simple deduplication, momentary Interacting order, repeated press/release, matrix inputs, empty/missing sequences, momentary cancellation and latching off-sequence behavior.
- [ ] Implement sequence execution with cancellable post-command delays and owner-generation checks. Preserve failure/continuation behavior captured from existing controller; do not auto-replay a partly executed sequence.
- [ ] Extract keyboard parser and preserve aliases, modifier order and platform support. Add fake-adapter tests with shared modifiers, simultaneous bindings, release failures and shutdown.
- [ ] Preserve baseline request-paced momentary repeats while guaranteeing fairness and release priority. Treat honoring the stored interval as a separately reviewed product change.
- [ ] Test saturation, unplug while held, train switch during delay and route switch to vJoy; assert release cannot disappear. Explicitly review improved stuck-key cleanup as a safety correction beyond existing controller behavior.
- [ ] Run `cargo test -p trenino-runtime --test control_dispatch`; use opt-in Windows/macOS keyboard smoke checks only in a controlled target window; review and commit.

## Task 6: Output bindings and displays

**Files:** Create core `train/{output,display}.rs`, runtime output/display controllers, tests `output_display.rs`.

**Interfaces:** Consumes SubscriptionService, TrainSnapshot, hardware OutputSink and chip encoding DTOs owned by hardware plan.

- [ ] Write failing fixtures for all predicates, inclusive endpoints, wrong types/null, rounding, formats N=0..10/invalid N, min clamps, empty/error/node-invalid subscriptions and multiple bindings per endpoint.
- [ ] Implement 200ms polling with owned leases and bounded hardware dispatch. Match existing write suppression and cleanup; any change to failed-output-write deduplication must be documented separately.
- [ ] Test initial brightness before segments, no cached success on failed display send, same text after reconnect, train-switch blanking, module removal and delayed stale completions.
- [ ] Run `cargo test -p trenino-runtime --test output_display`; compare encoded hardware commands with hardware protocol golden fixtures; review and commit.

## Task 7: Lua compatibility gate and bounded execution

**Files:** Create core `train/script.rs`, runtime `scripts/*`, tests `script_compatibility.rs` and script fixture corpus.

**Interfaces:** `ScriptVm::compile(code: &str, limits: ScriptLimits) -> Result<ScriptVm, ScriptError>`; `execute(&mut self, event: ScriptEvent) -> Result<Vec<ScriptEffect>, ScriptError>`. Runner owns VM lifetime, trigger subscriptions, one replaceable timer and logs. Effects are typed ordered API/output/display/schedule/log intents; VM callbacks do no I/O.

- [ ] Capture current Lua dialect/library availability, number conversion, table/list/null representation, globals, state mutation, errors, return tuples, top-level code and per-script isolation. Run same corpus through candidate mlua versions before choosing interpreter/features; do not assume 5.4/5.5 or Luau compatibility.
- [ ] Preserve `api.get` placeholder returns and ignored effect, `api.set` success-intent result, truthiness (including zero), ID truncation, event shape, schedule replacement and newest-first 100 log entries. Characterize state retention on thrown error/timeout: Elixir returns no updated VM on failure, while an in-place Lua VM may already be mutated.
- [ ] Gate implementation on an explicit state-failure strategy. Preferred exact solution is execution in a killable worker process with per-invocation VM checkpoint/rollback only if interpreter supports faithful snapshots. Do not claim a generic JSON copy of `state` restores closures/upvalues/globals. If exact rollback is infeasible, document compatibility impact and obtain design approval before enabling scripts on Rust.
- [ ] Implement dedicated bounded worker ownership, instruction/deadline checks for compile and execute, coroutine hook coverage, memory limit and bounded effect/log payloads. Proposed review defaults: existing 200ms execution deadline, new 200ms compile deadline, 16MiB VM budget, 256 effects/run and 64 queued events. New compile/memory/effect limits are intentional safety changes and require corpus validation; users must see typed failures.
- [ ] Do not rely on Tokio timeout or aborting `spawn_blocking` to kill native execution. Use subprocess isolation where hard wall-clock kill or interpreter-native calls cannot be bounded; keep it Rust-owned and internal to packaging. Close filesystem/network/process/debug/native-loader access except explicitly approved compatible standard-library functions. Security restrictions that reject existing scripts require documented migration behavior.
- [ ] Test infinite loops at top level and in handlers, recursive allocation, native/string-heavy work, coroutines, schedule storms, compile errors, effect-then-error, disconnected hardware and train switch mid-execution. No effects commit after failed/cancelled execution; no stale timer fires on a newly loaded script with reused ID.
- [ ] Run `cargo test -p trenino-runtime --test script_compatibility`; require exact corpus agreement or a reviewed list of intentional changes. Keep the Elixir execution backend until this gate is resolved; review and commit only the agreed implementation.

## Task 8: Cross-controller integration and handoff

**Files:** Extend runtime tests and fixtures; adapter integration paths coordinated with desktop/API/MCP plan.

**Interfaces:** All service contracts above, shared routing transactions, UI snapshots/events and runtime shutdown.

- [ ] Create failing end-to-end fixture: open saved train, identify train, map hardware lever/button, run sequence/script, update output/display, disconnect/reconnect, cancel wizard, change route and close app.
- [ ] Bind existing UI workflow actions to services; verify train/identifier editors, endpoint explorer, lever wizard, button/sequence forms, output/display wizards and script run/log editor retain their user-facing data and errors.
- [ ] Run `cargo test -p trenino-core -p trenino-runtime`; run existing selected ExUnit suites for the legacy oracle and desktop UI acceptance prescribed by the desktop plan. Add fault injection for simultaneous simulator latency, serial reconnect and DB save.
- [ ] Record queue peaks, task counts, poll latency, memory plateau and shutdown completion under replay load. Verify the runtime remains responsive and no OS key or simulator interaction remains held after orderly shutdown.
- [ ] Review a single-writer cutover rehearsal against a copied user database; confirm rollback restores the previous executable/data contract. Commit and release only after sibling integration gates approve.

## Decisions requiring design review before execution

1. Interpreter selection and rollback after failed Lua calls are migration gates, not details to postpone until packaging.
2. Hard script isolation may require an internal Rust worker executable even with a fully Rust backend; an in-process-only restriction would change the guarantee and must be resolved explicitly.
3. Fixes to momentary interval handling, synchronous `api.get`, ambiguous display addresses, stuck-key cleanup and output retry behavior are separately identifiable changes. Default parity leaves the first three unchanged; proposed release cleanup is tested and reviewed as a safety correction.
4. Subscription IDs are internal but external API consumers may have assumed fixed ranges. Confirm compatibility before replacing them with a common allocator; preserve legacy ranges during mixed-backend trials and never run competing allocators against one TSW instance.
5. Bounded overload defaults and cleanup deadlines are proposed new runtime policies; approve measured limits against realistic device/profile/script loads rather than accepting arbitrary throughput claims.


## Cross-plan integration alignment

The root/platform plan is authoritative for common service names and lifecycle contracts. `storage/trains.rs` is the shared train persistence module. The hardware `SourceEvent` resolver produces the normalized input consumed here; controllers must not invent a second physical/matrix input identity resolver. Shared calibration/firmware-flash arbitration owns device/resource leases, and this plan's session leases delegate to that arbiter.

Routing distinguishes a committed **desired revision** from the **active revision**. A DB transaction records desired assignments, then old owners quiesce and release; only a successful release/activation barrier advances active routing. On release failure remain degraded/pending, report the error and do not enable the competing TSW/vJoy owner. The simplified `RoutingSnapshot` interface above must expose those two revisions when reconciled with platform types.

Wizard persistence is checkpoint-based, not one transaction spanning the dialog. Source evidence: `lever_setup_wizard.ex` requests calibration through its parent; `train_edit_live.ex:1178` runs analysis and then calls `Train.create_lever_config_with_analysis` or `Train.update_lever_config_with_analysis`, committing endpoints and analysis before the later wizard steps. The separate `lever_session.ex:195` path automatically calls `Train.save_calibration` on completion; `lever_setup_wizard.ex:595` binds the input before starting notch mapping, and `notch_mapping_session.ex:444` persists mapping via `Train.update_notch_input_ranges` before completion is published. Closing/cancelling discards only the outstanding session and uncommitted samples; completed checkpoints survive. `save_and_finish` saves mapping before closing, whereas `finish` only closes. Acceptance must reopen the wizard after cancellation at each checkpoint and verify the same persisted state as the legacy flow. Extending owner cancellation to stop an in-flight automatic calibration before its next commit is an explicit lifecycle safety change where the existing UI only stops the mapping session; it must not be presented as existing rollback semantics.

