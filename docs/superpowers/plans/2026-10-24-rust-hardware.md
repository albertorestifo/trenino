# Rust Hardware and Firmware Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Status:** Implementation authorized on `codex/rust-rewrite`. Pure protocol, model and calibration code has passed scoped review; runtime ownership and integration are underway. Existing firmware remains unchanged, and ordinary tests must not access real hardware.

**Goal:** Move serial devices, hardware configuration, input detection/calibration, I2C modules, and firmware management to Rust while retaining existing device firmware, wire protocol, stored configurations, and user workflows.

**Architecture:** `trenino-core` owns pure codecs, validation, calibration mathematics, and public DTOs. `trenino-runtime` owns serial actors, cancellable sessions, database transactions, downloads, and avrdude child processes. Tauri is a thin command/event adapter; browser presentation replaces LiveView without moving authoritative hardware state into JavaScript.

**Tech Stack:** Rust, Tokio; proposed serialport/tokio-serial, reqwest, serde JSON, and semver; existing SQLite storage and avrdude. Final dependency versions and supported-platform minimums belong to the foundation/release plan.

**Spec:** The user request to plan a complete Rust backend migration while retaining Tauri and the UI experience, with a small TypeScript frontend and all application logic in Rust; see [the platform proposal](2026-10-24-rust-platform.md). This file is the hardware subsystem proposal and records decisions needing approval before implementation.

## Global constraints

- Preserve existing firmware and wire bytes, including message IDs, little-endian fields, matrix virtual pins, and configuration identifiers.
- Preserve existing SQLite identifiers, relationships, firmware history, cache lookup semantics, and calibration records through the shared persistence migration.
- Runtime is the sole owner of serial ports and flash subprocesses. Never run Elixir and Rust hardware discovery against the same real ports during comparison.
- Keep avrdude and its platform resources. Reimplementing AVR bootloaders is outside this migration.
- No automatic real-port access or firmware flashes in ordinary tests; use explicit opt-in hardware acceptance runs.
- Proposed paths and interface names below are coordination contracts, subject to reconciliation with the root architecture plan.

## Existing functionality and evidence

| Area | Existing sources and tests | Behavior to preserve |
| --- | --- | --- |
| Wire framing and messages | `lib/trenino/serial/framing.ex`; `lib/trenino/serial/protocol/*.ex`; `test/trenino/serial/framing_test.exs`, `test/trenino/serial/protocol/*_test.exs` | Streaming zero-delimited COBS with a custom trailing-zero convention; fragmented/coalesced reads; malformed-frame discard. IDs 0x00–0x08, reserved 0x09–0x0C, display write 0x0D, brightness 0x0E, module error 0x0F. |
| Discovery and connection | `lib/trenino/serial/discovery.ex`, `connection.ex`, `connection/state.ex`, `connection/device_connection.ex`; matching serial tests and `connection_port_timeout_test.exs` | Enumerate/filter ports, scan manually/periodically, identity discovery, connected/discovering/failed/uploading states, retry/backoff, async cleanup, input-message fanout, exclusive upload token. Normal baud 115200, settle 3000 ms, five actual discovery attempts with 1000 ms reads (module comment incorrectly says three), scan 60000 ms, failed retry 30000 ms, discovery timeout 10000 ms, cleanup timeout 5000 ms. |
| Configuration persistence/application | `lib/trenino/hardware.ex`, `hardware/{device,input,output,matrix,config_id,configuration_manager}.ex`; `test/trenino/hardware_test.exs`, `hardware/configuration_manager_test.exs` | CRUD configurations, analog/button inputs, output pins, matrices and generated virtual buttons; random unique positive signed-32-bit config ID; ordered multipart apply; configuration acknowledgment/error and 10000 ms timeout; auto matching by config ID; cached current input values. |
| Detection and calibration | `hardware/input_detection_session.ex`, `hardware/calibration/{session,session_supervisor,analyzer,calculator}.ex`, `hardware/input/calibration.ex`; detection and calculator/analyzer tests; `test/trenino_web/live/calibration_wizard_test.exs` | First sample establishes baseline; button change or analog delta strictly greater than 50 selects input; type filter and default 60000 ms detection timeout. Calibration ready → collecting_min → sweeping → collecting_max → analyzing → complete; endpoints need at least 10 samples and 3 distinct values, sweep needs 10. Inversion/rollover detection, integer median, normalized clamping, and persisted result. |
| Matrix and I2C | `hardware/matrix.ex`, `hardware/input/matrix_pin.ex`, `hardware/i2c_module.ex`, `hardware/ht16k33.ex`, `hardware/ht16k33/params.ex`; HT16K33/I2C/protocol tests; matrix/display LiveView tests | Matrix virtual pin formula `128 + row * num_cols + col`; row/column order by position. HT16K33 configuration, segment encoding, brightness, module errors, display test. Address validation currently accepts 0–255 and decimal/lowercase `0x` input; brightness 0–15, digits 4 or 8; seven/fourteen segment types, dot/alignment/min-value parameters. |
| Firmware catalog/download | `lib/trenino/firmware.ex`, `firmware/{downloader,device_registry,compatibility,file_path,firmware_release,firmware_file,update_check,update_checker}.ex`; firmware/downloader/registry/compatibility/manifest integration tests | GitHub releases from `albertorestifo/trenino_firmware`; required `release.json`; manifest-driven device environments and upload settings; persistent releases/files/check results, cache on disk; startup and periodic checks, manual check, update badge/dismissal, matching connected device versions. |
| Upload workflow | `firmware/{upload_manager,uploader,avrdude,avrdude_runner,upload_history,board_config}.ex`; `test/trenino/firmware/{upload_flow,upload_manager,uploader,avrdude,upload_history}_test.exs`, `test/support/avrdude_fixtures.ex` | Single active upload; exclusive serial access, download/read cached HEX, 1200-bps touch, changed bootloader port, avrdude argument/progress/error handling, alternate Nano baud retry, 120000 ms timeout/cancel, history/logs, release lease and rediscover. |
| UI and packaging | `lib/trenino_web/live/{configuration_list_live,configuration_edit_live,calibration_wizard,firmware_live}.ex`, configuration and I2C form components, display/matrix wizards; `tauri/src-tauri/tauri.conf.json`, `scripts/download-avrdude.ps1`, `scripts/build-macos.sh`, `.github/workflows` | Same configuration editing, feedback, live values, calibration and display test steps, firmware selection/progress/history/error explanations. Tauri currently bundles avrdude and `avrdude.conf` alongside other sidecars. |

Additional invariants: physical input pins 0–127, virtual matrix pins 128–255, analog sensitivity 1–10, button debounce 0–255, uniqueness by device/pin and device/I2C address. Configure packets contain physical inputs, then matrices, then I2C modules; matrix child buttons are not standalone configure parts. The supported registry programmer list is `arduino`, `avr109`, `wiring`, `avrisp`, `usbasp`. `BoardConfig` contains legacy Uno/Nano/Leonardo/Micro/Mega2560/Pro Micro tables, but runtime registry deliberately stays empty when no manifest is available; do not accidentally restore a static fallback.

## Proposed files, interfaces, and ownership

All listed paths are new unless noted. Shared ID/error/event envelope definitions should be supplied by the foundation plan rather than duplicated here.

| Path under `crates/` | Responsibility |
| --- | --- |
| `trenino-core/src/hardware/protocol/{mod,framing,messages}.rs` | Explicit byte codecs and streaming frame decoder; no I/O or DB. |
| `trenino-core/src/hardware/{mod,model,configuration,matrix,i2c,ht16k33}.rs` | DTOs, validators, configure-part builder, virtual pins, display segment encoding. |
| `trenino-core/src/hardware/calibration/{mod,analyzer,calculator,state}.rs` | Sample analysis, normalization, and pure calibration transitions. |
| `trenino-core/src/hardware/detection.rs` | Baseline comparison and type filtering. |
| `trenino-core/src/firmware/{mod,manifest,compatibility,upload}.rs` | Manifest/device model, version policy, avrdude arguments/output classification. |
| `trenino-runtime/src/hardware/{mod,transport,discovery,connections,configuration,sessions,repository}.rs` | Native transport abstraction, per-port workers/coordinator, configuration operations, session ownership and persistence access. |
| `trenino-runtime/src/firmware/{mod,catalog,downloads,updates,uploads,avrdude,repository}.rs` | Catalog transactions, cache writes, scheduler, upload lifecycle/child ownership and history. |
| `trenino-runtime/tests/{hardware_protocol,hardware_connections,hardware_configuration,hardware_sessions,firmware_catalog,firmware_uploads}.rs` | Fake transport, clock, child process, HTTP and temporary DB acceptance scenarios. |

Proposed public contracts (async runtime calls return shared typed `AppError`, including stable machine codes plus display-safe detail):

```rust
// Core
fn encode_message(message: &Message) -> Result<Vec<u8>, ProtocolError>;
fn decode_message(bytes: &[u8]) -> Result<Message, ProtocolError>;
impl FrameDecoder { fn push(&mut self, bytes: &[u8]) -> Vec<Result<Vec<u8>, ProtocolError>>; }
fn build_configuration(config: &DeviceConfiguration, id: ConfigId) -> Result<Vec<Message>, ValidationError>;
fn normalize(raw: i32, calibration: &Calibration) -> i32;
fn analyze_sweep(samples: &[i32], max_hardware_value: i32) -> Analysis;
fn compatible(version: &str, policy: &FirmwarePolicy) -> bool;

// Runtime service handles; methods below are async except snapshot subscriptions.
impl HardwareService {
    async fn scan(&self) -> Result<(), AppError>;
    async fn connections(&self) -> Result<Vec<ConnectionSnapshot>, AppError>;
    async fn send(&self, target: ConnectionId, message: Message) -> Result<(), AppError>;
    async fn apply_configuration(&self, target: ConnectionId, device: DeviceId) -> Result<OperationId, AppError>;
    async fn start_detection(&self, owner: ClientId, filter: InputFilter) -> Result<SessionId, AppError>;
    async fn start_calibration(&self, owner: ClientId, input: InputId, target: ConnectionId) -> Result<SessionId, AppError>;
    async fn advance_calibration(&self, session: SessionId) -> Result<CalibrationSnapshot, AppError>;
    async fn cancel_session(&self, session: SessionId) -> Result<(), AppError>;
}
impl FirmwareService {
    async fn check_updates(&self) -> Result<OperationId, AppError>;
    async fn download(&self, file: FirmwareFileId) -> Result<OperationId, AppError>;
    async fn start_upload(&self, request: UploadRequest) -> Result<UploadId, AppError>;
    async fn cancel_upload(&self, upload: UploadId) -> Result<(), AppError>;
}
```

`UploadRequest` carries selected port, firmware file ID, and environment; runtime verifies that file/environment/release match before acquiring a lease. `ConnectionId` includes a generation so an old timer or input cannot mutate a replacement connection using the same port name. `ConfigId` remains the firmware's persistent integer identity, distinct from database `DeviceId` and transient connection identity. `SessionId`, `OperationId`, and `UploadId` are opaque values suitable for Tauri DTOs; never expose raw process/task handles.

The connection coordinator owns the port map and upload leases; each connection task owns its serial handle, buffer, timers, and write queue. Configuration service owns pending acknowledgments and latest input cache. Repository methods own DB transactions; actors never hold a DB transaction while awaiting serial I/O. On acknowledgment, persist configuration confirmation before emitting success. Input events carry connection generation, config ID, pin, raw value and monotonic ordering metadata; train/joystick consumers use runtime subscriptions. Do not coalesce button edges. UI may receive coalesced analog previews, while calibration receives complete samples or an explicit overflow failure.

Use the platform proposal's dedicated owning `rusqlite` worker for repository operations; subsystem services send typed requests to that worker rather than open competing connections. Cross-domain changes use its common transaction boundary and publish events only after commit. TypeScript handles presentation, navigation and user interaction; configuration validation, wizard decisions, detection thresholds and calibration mathematics remain Rust-owned.

**Cross-subsystem coordination contract:** The root/platform proposal is authoritative for input routing and resource arbitration. One shared input resolver maps wire `ConfigId`, pin and connection generation to persisted device/input IDs; hardware, train and virtual-joystick services must not maintain competing identity maps. One shared resource arbiter grants calibration/flashing ownership. Calibration suspends TSW and vJoy actuation for the affected resource while retaining calibration sampling. Flashing cancels affected calibration sessions and delivers source-loss/neutralization to active routes before the serial worker closes. On release or reconnect, routes resume only after a fresh sample from the current connection generation; cached values and stale events cannot reactivate controls. Tasks 2, 4 and 6 must test these ordering guarantees with train/vJoy consumer fakes and the shared arbiter, rather than implement independent local suspension flags.

Each calibration/detection session owns samples and cancellation, scoped by input and connection rather than pin alone. The UI consumes snapshot-plus-event updates containing wizard step, sample counts, can-advance, result/error and session ID; reconnect requests a fresh snapshot. Cancel on explicit wizard close/client disposal. UI disconnection must not cancel a firmware flash implicitly: the runtime owns it until explicit cancellation or shutdown. The desktop shutdown path must await child termination and history finalization before releasing ports.

Exclusive flashing uses a coordinator-issued lease with token and connection generation. Acquire closes/joins the normal port worker before starting touch/avrdude; discovery and ordinary writes reject leased ports. A 1200-bps bootloader may reappear under another name: reserve the original device and resolved bootloader port through one upload lifecycle. Terminal success/failure/cancellation kills and reaps any child, persists history, then releases the lease and requests rediscovery. RAII can notify a supervisor on drop but cannot replace asynchronous cleanup.

## Dependency assessment (primary documentation checked 2026-10-24)

- Prefer [tokio-serial](https://docs.rs/tokio-serial/latest/tokio_serial/) for async serial streams and [serialport](https://docs.rs/serialport/latest/serialport/) for enumeration/settings/platform APIs. Validate Windows COM, macOS `/dev/cu.*`, Linux permissions and unplug behavior in a spike before locking this choice. A dedicated blocking serial thread behind the same transport trait is an acceptable fallback if async cancellation is unreliable on a supported platform.
- Use [Tokio process](https://docs.rs/tokio/latest/tokio/process/index.html) for avrdude. Its documented cancellation semantics mean dropping a child future alone does not guarantee process termination; explicit kill-and-wait is required. Capture both output streams without pipe deadlock, retain bounded log history, and hide Windows console windows.
- Use a shared [reqwest Client](https://docs.rs/reqwest/latest/reqwest/) for GitHub API/manifests/assets with explicit timeouts and redirect policy. TLS/provider and proxy behavior must match the foundation decision and installed-platform matrix.
- Use [semver](https://docs.rs/semver/latest/semver/struct.VersionReq.html) for parsed versions and comparisons, not as a blind replacement for Elixir `Version.Requirement`: requirement syntax and prerelease rules differ. Translate the supported configured policy explicitly and retain fixtures for `~>`, conjunction/disjunction if configured, leading `v`, invalid values, and prereleases.
- Keep [avrdude's documented CLI](https://avrdudes.github.io/avrdude/8.1/avrdude_4.html), including selected programmer, MCU, baud, config and HEX format. Documentation version is a reference, not an instruction to upgrade the currently bundled binary.
- Implement the short COBS compatibility codec locally first, since the current trailing-zero behavior must match golden bytes rather than a crate's default COBS convention. Reassess a codec dependency only after proving equivalent behavior at 254-byte block boundaries.

## Compatibility decisions and explicit behavior changes to review

1. Preserve normal observed behavior, not misleading comments: discovery retries are five; missing manifest means no upload devices. `Configure` currently encodes HT16K33 but has no corresponding HT16K33 decode branch; host only needs the transmit direction. Do not infer firmware support or widen accepted incoming packets silently.
2. `firmware_version_requirement` is currently `nil` in `config/config.exs`. That permits any parseable version, including prereleases; a configured requirement uses `allow_pre: false`. Catalog filtering and compatibility are separate decisions. Preserve both using fixtures.
3. Current framing stores an unused `max_length`; proposed bounded buffer/discard-until-delimiter is a resilience improvement requiring an explicit accepted maximum after measuring all legal packets. It must not reject legal existing configurations.
4. Current bootloader selection picks lexicographically greatest newly appeared port if several appear. Proposed improvement: correlate USB identity where available and otherwise return a clear ambiguity error rather than risk flashing another device. This is a deliberate behavior change requiring review and hardware validation.
5. Existing checksum field does not establish that all downloads are verified. Preserve the existing catalog format; atomically download to a temporary file, validate available size/checksum metadata, and rename only on success. Do not invent mandatory signatures/checksums absent from releases. Restrict manifest-derived cache path components to prevent escaping the cache root.
6. Preserve current I2C address range and case parsing even though a generic I2C API might use a narrower range. Likewise preserve endpoint uniqueness thresholds and integer median/dead-zone rounding, which can affect the feel of calibrated controls.
7. Config collisions, duplicate applying operations, late acknowledgments and unplugged sessions need explicit error outcomes. Tightening inconsistent historical DB values should use migration diagnostics, not silently discard users' configurations.

## Review focus

- Port reused or USB unplugged during discovery/configure/flash: old callbacks cannot act on a replacement device (tasks 2, 3, 6).
- Avrdude cancellation, app shutdown, or hung child: exactly one terminal history transition and no orphan child/lease (task 6).
- Multiple boards and duplicate pin numbers: detection/calibration only consumes the selected device; ambiguous bootloader port is not guessed (tasks 4, 6).
- Malformed/truncated/oversized serial or remote data: no panic, unbounded buffer, partial cache considered valid, or stalled unrelated ports (tasks 1, 5).
- Existing rollover and matrix/display configurations: unchanged normalized values, virtual pins, segments and stored identity after upgrade (tasks 1, 3, 4, 7).

## Proposed phased work and acceptance gates

### Task 1: Lock protocol and pure hardware rules

**Files:** core hardware protocol/model/matrix/I2C/HT16K33 files above; `crates/trenino-core/tests/hardware_protocol.rs` and `hardware_models.rs`; golden fixtures under `crates/trenino-core/tests/fixtures/hardware/`.

**Interfaces:** Produces `Message`, `FrameDecoder`, `encode_message`, `decode_message`, and validated `DeviceConfiguration`; consumes shared identity/error types.

- [ ] Capture golden payloads/frames from current protocol tests, including every message type, zero bytes, 254-byte COBS boundary, split frames, empty delimiters, malformed codes and unknown/reserved IDs.
- [ ] Write failing Rust fixture tests for exact wire bytes and validation: physical pin 127/128, virtual pin 127/128/255/256, sensitivity 0/1/10/11, debounce 255/256, I2C 255/256 and brightness 15/16.
- [ ] Implement codec/validators and segment mapping; preserve four/eight-digit ordering, dot and seven/fourteen-segment maps from current tests.
- [ ] Run `cargo test -p trenino-core --test hardware_protocol --test hardware_models`; all fixtures pass and randomized chunk boundaries reproduce the same decoded messages. Run the corresponding Elixir protocol tests while available; fixture discrepancies block the next task.

### Task 2: Own serial connections and leases

**Files:** runtime hardware transport/discovery/connections files and `crates/trenino-runtime/tests/hardware_connections.rs`.

**Interfaces:** Produces the `HardwareService` connection methods and internal `acquire_upload(port) -> UploadLease` / `release_upload(lease)` operations. A fake `SerialTransportFactory` supplies enumeration/open/read/write/close behavior and virtual time.

- [ ] Write failing deterministic tests for five identity attempts, settle/read/backoff timing, ignored ports, busy/open failures, unplug, cleanup timeout, manual/periodic scans, worker failure and stale connection generation.
- [ ] Implement transport adapter and per-port workers; ensure slow/opening port A cannot stall input from B. Add fake-only defaults to test harness, preserving the protection provided by `test/support/{serial_safety_case,forbidden_serial,serial_test_helpers}.ex`.
- [ ] Implement exclusive leases and test concurrent scan/write/acquire, invalid token, duplicate release and stale worker exit.
- [ ] Run `cargo test -p trenino-runtime --test hardware_connections`; no test opens an actual port. Complete platform spike with opt-in real serial read/write/unplug smoke tests before choosing async versus blocking transport.

### Task 3: Configuration persistence and application

**Files:** core hardware/configuration.rs; runtime hardware/configuration.rs and repository.rs; `crates/trenino-runtime/tests/hardware_configuration.rs`; shared persistence plan supplies schema migration.

**Interfaces:** Consumes validated configuration/connection handle; produces configuration CRUD/application service, operation snapshots and ordered raw input stream.

- [ ] Port database-context acceptance tests for create/update/delete, cascading binding behavior, collision retries for config ID 1..2147483647, matrix virtual-button creation/update and address/pin uniqueness using temporary migrated databases.
- [ ] Write packet-order and acknowledgment fixtures: physical inputs → matrices → modules, sorted matrix pins, uint8 part count limits, zero parts, reject, timeout, unplug, mismatched/late config ID and duplicate apply.
- [ ] Implement transactional repository changes and asynchronous apply tracking. Preserve stored config confirmation semantics and auto association after discovery; publish input snapshots independently from raw ordered input events.
- [ ] Run `cargo test -p trenino-runtime --test hardware_configuration`; migration fixture retains IDs, associations and calibration records, and failed/rejected apply never reports success.

### Task 4: Detection and calibration sessions

**Files:** core hardware/detection.rs and calibration files; runtime hardware/sessions.rs; `crates/trenino-core/tests/hardware_calibration.rs`; runtime hardware_sessions test.

**Interfaces:** Produces detection/session commands and snapshots listed above; consumes ordered device input events and repository calibration save operation. Train lever/notch mapping calibration belongs to the train subsystem; share normalization DTOs rather than merge the wizards.

- [ ] Write differential tests for all four inversion/rollover combinations, negative delta integer median, dead-zone midpoint ties, clamping and short sweeps against existing calculator/analyzer fixtures.
- [ ] Write session tests for baseline then delta 50/51, button press/release, type filters, timeout, two devices sharing a pin, disconnect, cancellation, insufficient sample/unique counts and save failure.
- [ ] Implement pure transitions and runtime session ownership; retain chronological sweep order and endpoint sample semantics. Abort explicitly if an input stream overflows rather than quietly calculating from incomplete data.
- [ ] Run `cargo test -p trenino-core --test hardware_calibration` and `cargo test -p trenino-runtime --test hardware_sessions`; resulting calibration records and normalized control traces match legacy fixtures.

### Task 5: Firmware catalog, compatibility, downloads and updates

**Files:** core firmware manifest/compatibility files; runtime firmware catalog/downloads/updates/repository; `crates/trenino-runtime/tests/firmware_catalog.rs` and core firmware compatibility tests.

**Interfaces:** Produces release/device/environment listings, file availability, update operations and notification snapshots. Consumes common HTTP client, application paths and persistence layer.

- [ ] Write fixture tests from existing manifest integration tests: required top-level/device/upload fields, unsupported programmer, missing asset, MCU normalization, empty registry, malformed JSON/version, leading `v`, nil policy and configured prerelease exclusion.
- [ ] Implement per-release parsed manifests and selected-release upload configuration; do not let a later registry refresh change parameters for an already selected upload.
- [ ] Write fake HTTP/cache tests for 200/non-200, timeout, offline cached use, truncated body, invalid path component, partial file cleanup and concurrent download of same asset; implement atomic cache publication.
- [ ] Port update scheduler behavior: 5-second startup delay, 24-hour periodic cadence, 1-hour minimum interval, persisted check status, connected-device comparison and dismissal semantics. Use virtual clocks; no GitHub traffic in unit tests.
- [ ] Run `cargo test -p trenino-runtime --test firmware_catalog` and core compatibility tests; saved release/history relationships survive reopening the legacy DB fixture and firmware cache is reusable.

### Task 6: Reliable flashing with avrdude

**Files:** core firmware/upload.rs; runtime firmware/uploads.rs and avrdude.rs; `crates/trenino-runtime/tests/firmware_uploads.rs`; copied textual avrdude fixtures.

**Interfaces:** Produces `FirmwareService::start_upload/cancel_upload` and progress/history snapshots; consumes pinned firmware file/environment, connection lease, path resolver and injectable child process runner.

- [ ] Write failing tests for single active upload, incompatible/wrong-environment file, missing HEX/avrdude, acquisition failure, exact argument vectors, progress/error parsing, history terminal transitions, timeout and cancellation.
- [ ] Port 1200-bps touch (100 ms), enumeration polling (300 ms, 5000 ms deadline), original/changed/ambiguous ports, port-not-found retry, and Arduino-only 57600/115200 alternate baud retry on bootloader-not-responding. Test no retry for wrong board or verification failure.
- [ ] Implement process ownership with explicit kill/reap and release only after completion. Cover child crash, stdout/stderr saturation, application shutdown, stale timeout arriving after success and DB history write failure; retain recoverable operation state if history cannot be committed.
- [ ] On startup, reconcile previously `started` histories without a live upload into an explicit interrupted failure; never resume flashing automatically.
- [ ] Run `cargo test -p trenino-runtime --test firmware_uploads`; fake child reports zero survivors, lease count zero and one terminal transition for every terminal path. Actual flashing belongs exclusively to the opt-in gate below.

### Task 7: UI contract and packaged-device acceptance

**Files:** thin `tauri/src-tauri/src/commands/{hardware,firmware}.rs` adapters and UI route/component files chosen by the frontend plan; packaging changes owned by the release plan; browser tests ported from configuration/calibration/matrix/display/firmware LiveView flows.

**Interfaces:** Consumes service snapshots/events and returns typed IDs/validation errors. JavaScript renders wizard state and progress; it does not own serial connections, firmware download paths or avrdude arguments.

- [ ] Port UI acceptance flows for configuration CRUD/apply acknowledgment, connected status/error/retry, live analog/button values, input auto-detection, calibration counts/advance/cancel, matrix test, I2C form/display test, release check/download/selection/upload/cancel/history and update dismissal.
- [ ] Verify navigation and subscription cleanup, reload during an upload, cancelled wizard cleanup, two simultaneous windows, and resynchronization after event loss.
- [ ] Verify installed executable/config path discovery with spaces/non-ASCII names, bundled avrdude resources, macOS bundle layout and Windows no-console launch. Keep existing avrdude version/package/license decisions unless independently approved.
- [ ] Run an explicitly opt-in hardware matrix on supported release targets: Uno; Nano including old-bootloader baud fallback; Mega with slow boot; Leonardo/Micro/Pro Micro touch and port change; analog rollover; matrix; HT16K33 4/8-digit variants. Record exact board, firmware version, OS, and binary artifact.
- [ ] Accept only when discovery/reconnect, unchanged wire bytes, raw-to-normalized traces, display output, successful flash/re-discovery, cancellation recovery and persisted history match expectations. Do not claim hardware parity from mock tests alone.

## Sequencing, scope boundaries, and unresolved risks

Tasks 1–2 establish transport; task 3 depends on both plus shared persistence. Task 4 follows ordered input delivery. Task 5 can proceed independently once persistence/paths are defined. Task 6 joins tasks 2 and 5; task 7 joins all plus the frontend/release plan. During transition select one hardware owner per run; use recorded byte/event traces for cross-runtime comparisons. Remove old Elixir services only after consumers (train mapping, joystick, UI and MCP) use the Rust facade.

No new firmware protocol, native I2C host driver, USB firmware uploader replacement, board redesign or train-specific lever/notch wizard is included. Generic segment encoding is owned here; simulator-value formatting and train display/output policy remain with train integration.

Remaining risks to resolve during approved implementation: availability of representative physical boards and target hosts; bootloader identity when USB metadata is absent; serial driver cancellation differences; historical malformed configurations; matching Elixir requirement semantics without over-generalizing the parser; shutdown during a flash; UI event throughput without losing button edges; and missing real-firmware coverage in the current test suite. Each has an explicit task/gate above. Dependency documentation proves API availability, not compatibility with Trenino's physical hardware.

## Planning verification

Reviewed existing modules and test inventory, checked proposed dependency capabilities against the primary documentation linked above, and mapped each review-focus failure mode to an acceptance task. No Rust implementation, test execution, device connection, download, firmware flash or product-code change was performed while preparing this proposal.
