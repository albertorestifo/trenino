# Rust Virtual Joystick Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move joystick routing, lifecycle and configuration to Rust while preserving the generic Windows joystick and removing the separately packaged feeder executable.

**Architecture:** Keep the signed vJoy kernel driver and reuse `tauri/virtual_joystick` as a Rust library. Put pure mapping/types in `crates/trenino-core`, lifecycle services in `crates/trenino-runtime`, and thin UI/entry-point integration in `tauri/src-tauri`. Run the native SDK in a headless mode of the same installed application executable to retain fault isolation without a second build artifact.

**Tech Stack:** Existing Rust vJoy library, pinned vJoy 2.2.2.0 SDK/runtime, Windows APIs, shared runtime executor and persistence selected by the overall Rust migration.

**Spec:** `docs/superpowers/specs/2026-08-01-virtual-joystick-design.md`, with this plan's explicit architecture changes and safety corrections, coordinated with `docs/superpowers/plans/2026-10-24-rust-platform.md`. This is a planning deliverable, not authorization to implement or install drivers.

## Global Constraints

- Keep Tauri and existing user-facing workflows; the confirmed broader migration replaces LiveView with a TypeScript frontend and moves all application logic to Rust. Its UI plan owns rendering and transport.
- Device index is exactly 1; axes are `x`, `y`, `z`, `rx`, `ry`, `rz`, `slider_1`, `slider_2`; buttons are 1 through 32; no POV or force feedback.
- Windows-only virtual joystick support; other platforms return `unsupported` without starting workers or packaging vJoy.
- No new kernel-driver project, privileged resident service, Xbox emulation, or firmware changes in this workstream.
- Preserve existing SQLite rows and constraints; do not silently change bindings or adopt another application's device.
- Never run Elixir and Rust joystick owners simultaneously, including during incremental rollout.

## Review Focus

- A disconnected source must not replay an old pressed button after reconnect; connection generations invalidate cached samples (Task 4).
- Disable/uninstall must preserve a compatible device owned by another application (Tasks 3 and 6).
- SDK failure, worker exit, and application termination must not leave unbounded retries or claim a successfully neutralized device without evidence (Tasks 2 and 4).
- Reassigning a held input must release its old destination and never send to two outputs (Task 5).
- GUI-subsystem release builds must supply working worker pipes without launching a window or a second application instance (Task 2).

## What Rust can replace

The feeder is already Rust: `tauri/virtual_joystick/src/vjoy.rs` loads `vJoyInterface.dll`; `protocol.rs` maintains a complete eight-axis/32-button report. The Elixir manager, bridge, PowerShell/C# capability probe, registry commands, and separate feeder packaging are replaceable application plumbing. A Rust crate in Tauri alone does not cause Windows to enumerate a generic HID joystick.

Microsoft's cited VHF documentation describes **kernel-mode** source drivers using KMDF or WDM, with an INF and VHF linkage. Implementing that documented path in Rust is a driver-development project, not an ordinary user-mode library. This does not establish that every virtual HID architecture requires a custom kernel driver; alternative projects below advertise UMDF-based approaches. [Microsoft VHF architecture](https://learn.microsoft.com/en-us/windows-hardware/drivers/hid/virtual-hid-framework--vhf-).

Microsoft's Rust WDK repository supports driver development but explicitly says it is early-stage and not yet recommended for production. Language choice does not remove signing, installation, upgrade or compatibility responsibilities. [windows-drivers-rs](https://github.com/microsoft/windows-drivers-rs).

Hardware-dashboard submission requires an account with an associated valid EV certificate; this is distinct from signing the Tauri executable. Driver installation remains a privileged system operation; Microsoft documents running PnPUtil as administrator. Do not promise that Rust removes UAC or the driver package. [Signing requirements](https://learn.microsoft.com/en-us/windows-hardware/drivers/dashboard/code-signing-reqs), [PnPUtil](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/pnputil-command-syntax).

Driver acceptance must be validated against current patched Windows: Microsoft's current policy describes tighter treatment of legacy cross-signed drivers after the April 2026 update. Installer Authenticode success alone is not proof that the kernel accepts a driver under Secure Boot and Memory Integrity. This is a release-test requirement, not a claim that the pinned vJoy release is incompatible. [Windows Driver Policy](https://support.microsoft.com/en-us/windows/hardware/drivers/the-windows-driver-policy).

| Approach | Complexity and consequence | Decision |
|---|---|---|
| Rust feeder inside Tauri process | Least IPC; a native DLL crash/hang affects UI and all runtime services. A dedicated thread does not isolate native crashes. | Possible later optimization, not initial default. |
| Same executable, headless worker | One shipped application executable, one extra process; bounded protocol, supervision and crash isolation remain. | Recommended. |
| Retain existing standalone Rust sidecar | Lowest migration risk, but preserves extra release/build artifact. | Transitional fallback until release-mode worker smoke test passes. |
| Custom Rust VHF driver | New driver, descriptor, IOCTL security, WDK, signing, testing and support lifecycle. | Separate future product decision; excluded. |
| ViGEmBus | Emulates fixed gamepads, is archived/retired, and still needs a kernel driver. | Does not satisfy this generic joystick contract. [Project](https://github.com/nefarius/ViGEmBus). |
| Physical USB HID firmware | Could change the system architecture, but requires board/firmware and device identity work. | Outside this Rust backend migration. |

Research checked 2026-10-24. These recommendations infer engineering scope from the cited platform requirements; they do not assert all possible virtual-device products have been evaluated.

### Existing Rust packages and newer alternatives

The user has explicitly accepted retaining vJoy if no suitable existing Rust replacement is found. The existing [`vjoy` 0.7.1 Rust crate](https://docs.rs/vjoy/latest/vjoy/) wraps the SDK and explicitly requires installed vJoy 2.2.2.0; it can replace handwritten bindings, but cannot remove the driver. Evaluate it only if it reduces maintenance while preserving trusted DLL loading and existing ABI tests.

[HIDMaestro](https://github.com/hifihedgehog/HIDMaestro) advertises virtual DirectInput/game controllers using user-mode infrastructure and provides a different native/.NET integration stack. It is a real alternative to investigate, not evidence of a ready pure-Rust drop-in. [LizardByte Virtual HID Driver](https://app.lizardbyte.dev/libvirtualhid/virtual-hid-driver/) likewise documents a UMDF2 driver package with a C++ client API, matching protocol requirements, AMD64 packaging and a required Windows license. Its process-owned cleanup is interesting, but descriptor equivalence, redistribution terms and clean-system compatibility would require a separate spike.

These alternatives mean the conclusion is **no verified suitable Rust-only replacement identified in this review**, not “no alternatives exist.” The user accepted retaining vJoy; this proposed migration plan therefore avoids adding an unvalidated driver stack during the backend migration.

## Existing implementation and behavior inventory

- `lib/trenino/virtual_joystick.ex`, `mapping.ex`, `configuration.ex`: singleton requested enable state; one source per target and one target per source; analog-to-axis and button-to-button validation; immediate SQLite transaction enforces conflict with enabled simulator bindings. Explicit replacement removes prior enabled bindings.
- `mapper.ex`: calibrated total-travel normalization, inversion, range scaling and rounding; nil/zero-travel calibration errors. Reuse the shared calibration implementation, including wrap behavior, rather than inventing a second normalizer.
- `manager.ex`: states `unsupported`, `off`, `enabling`, `active`, `disabling`, `needs_setup`, `needs_cleanup`, `degraded`, `error`; separate requested state from runtime state; retry delays 250, 500, 1000, 2000, 4000 ms; persist enabled only after successful acquisition, persist disabled after confirmed removal; reject overlapping transitions; ignore stale transition replies.
- `bridge.ex` and `bridge/port_adapter.ex`: newline JSON protocol v1, 16 KiB line bound, request IDs, 5-second default request deadline, per-control latest-value coalescing, stderr separated from protocol stdout.
- `configurator.ex` and `configurator/system_adapter.ex`: device create arguments `1 -a x y z rx ry rz sl0 sl1 -b 32 -p 0`; delete arguments `-d 1`; capability probe requires all eight axes, no additional axes, exactly 32 buttons, zero POVs and no FFB. Poll every 100 ms for up to 10 seconds; UAC cancellation is code 1223.
- `tauri/virtual_joystick/src/vjoy.rs`: full SDK v3 report including zeroed unused fields; current x64 layout test asserts 124 bytes and offsets; slider 1 maps to `w_slider`, slider 2 to `w_dial`; button n maps to bit n-1. Current handshake obtains X range; validate all eight ranges before assuming one shared range.
- `tauri/src-tauri/windows/installer-hooks.nsh`: pinned 2.2.2.0 install; preserve pre-existing/unverified shared installations; HKLM `Software\Trenino\VJoyInstalledByTrenino` marks driver install; HKCU `Software\Trenino\VJoyDevice1CreatedByTrenino` marks device creation. Uninstall checks descriptor and marker before device deletion. Shared-driver removal additionally requires exact version, healthy enumeration with all 16 devices missing, and explicit interactive choice defaulting to No; silent uninstall retains driver.
- `scripts/download-vjoy.ps1`, `scripts/stage-vjoy-resources.ps1`, `tauri/src-tauri/resources/vjoy.sha256`, Windows Tauri config, CI/nightly/release workflows: pinned hashes, signature checks, DLL/configurator/license staging and extracted-installer smoke tests. These remain relevant after feeder consolidation.

### Deliberate safety corrections, not blind parity

Current `Configurator.delete` does not consult ownership before deleting a compatible device. Current Rust `hello` centers memory but does not submit that initial report, and EOF has no explicit session reset/relinquish. Current reconnect cache is keyed only by port/pin. The manager rounds midpoint while `Report::centered` truncates. Correct these with tests: use one overflow-safe midpoint `min + (max-min)/2` in widened integer arithmetic; reset/release owned sessions on orderly exits; invalidate source samples on generation change; reject destructive configuration of foreign devices. A midpoint is a neutral joystick convention, not a guarantee that a game's throttle/brake interpretation is safe.

## Proposed file ownership and interfaces

| File | Responsibility |
|---|---|
| `crates/trenino-core/src/joystick.rs` | Axis/target/status types, checked button index, descriptor, calibrated value mapping and safe report construction; no Tauri/OS dependencies. |
| `crates/trenino-runtime/src/joystick/mod.rs` | Public commands, status snapshots and dependency assembly. |
| `crates/trenino-runtime/src/joystick/manager.rs` | Single owner actor, transitions, generations, retries and output routing. |
| `crates/trenino-runtime/src/joystick/worker.rs` | Child spawn, bounded protocol, request deadlines, orderly stop and worker supervision. |
| `crates/trenino-runtime/src/joystick/configurator.rs` | Probe, create/delete coordination, deadline and ownership policies. |
| `crates/trenino-runtime/src/joystick/windows.rs` | Native elevation, registry and trusted resource-path operations. |
| `tauri/virtual_joystick/src/{lib,protocol,vjoy}.rs` | Reused SDK implementation and worker protocol; remove standalone packaging only after parity. |
| `tauri/src-tauri/src/main.rs` | Dispatch `--internal-vjoy-worker` before Tauri initialization/single-instance hooks. |
| `tauri/src-tauri/src/commands/joystick.rs` | Thin existing-UI-compatible status/control/mapping adapter. |

Core interfaces: `Axis`, `ButtonIndex::try_from(u8)`, `Target::{Axis(Axis), Button(ButtonIndex)}`, `AxisRange { min: i32, max: i32 }`, `JoystickReport { axes: [i32; 8], buttons: u32 }`, `JoystickStatus`, `JoystickSnapshot { requested: bool, status: JoystickStatus, reason: Option<JoystickError> }`; `map_axis(raw: i32, calibration: &Calibration, inverted: bool, range: AxisRange) -> Result<i32, MappingError>`. `Calibration` comes from the shared hardware/core plan and must not be duplicated.

Runtime interface: `JoystickHandle::command(JoystickCommand) -> Result<JoystickSnapshot, JoystickError>` asynchronously, where commands are Enable, Disable, Retry, Repair, RemoveLeftover; `input(SourceSample)` and `source_lost(SourceId, generation: u64)` enqueue events; `replace_mappings(Vec<ResolvedMapping>, revision: u64)` applies committed snapshots. Source samples carry stable input identity, connection generation and raw value. Shared hardware/router plan owns these source types. Internally one actor owns the worker and current report. UI and MCP adapters call this same service.

Configurator interface: `probe(deadline: Instant) -> Result<DeviceProbe, JoystickError>`, `create_owned(deadline: Instant) -> Result<(), JoystickError>`, `delete_owned(deadline: Instant) -> Result<(), JoystickError>`. `DeviceProbe` carries driver/device status, exact descriptor and ownership separately. Ownership is not implied by descriptor compatibility or successful acquisition.

## Task 1: Establish parity fixtures and pure mapping contract

**Files:** Create core module and `crates/trenino-core/tests/joystick.rs`; read existing `test/trenino/virtual_joystick/{mapper,manager,configurator,bridge}_test.exs`, `test/trenino/virtual_joystick_test.exs`, and migration `priv/repo/migrations/20260801000000_create_virtual_joystick_tables.exs`.

**Consumes:** Shared calibration types and workspace crate setup. **Produces:** Core types/functions above and checked compatibility fixtures.

- [ ] Add failing tests for all eight serialized axis names, button 0/33 rejection, endpoints, inversion, wrapped calibration, zero travel, out-of-range raw values and widened midpoint arithmetic; `[min,max]=[0,32767]` must center at 16383 consistently.
- [ ] Run `cargo test -p trenino-core --test joystick`; confirm tests expose absent behavior, then implement pure types and mapping using the shared calibration normalizer.
- [ ] Capture persisted mapping/enable fixtures and compare migrated values and uniqueness constraints without changing IDs; record current Elixir parity commands in the test notes.
- [ ] Rerun core tests and review the explicit midpoint difference; commit this self-contained contract change during implementation.

## Task 2: Reuse Rust SDK and consolidate the executable

**Files:** Modify `tauri/virtual_joystick/src/{lib,protocol,vjoy}.rs`, its existing tests, Tauri manifest/main; create runtime worker module and `crates/trenino-runtime/tests/joystick_worker.rs`.

**Consumes:** Task 1 core types, existing `VJoy` fakeable trait and protocol. **Produces:** Same-executable worker and bounded supervisor; old sidecar remains available only during transition.

- [ ] Add failing SDK/session tests proving initial full neutral report is applied before Ready, all eight ranges are validated, orderly Shutdown/EOF/error cleanup resets then relinquishes once, and report state is committed only after successful SDK update.
- [ ] Implement typed session operations beneath JSON parsing; reuse existing native ABI mapping and layout tests. Add capability methods for the Rust probe; keep DLL loading constrained to verified absolute installed resources.
- [ ] Dispatch worker mode before UI setup; spawn `current_exe()` with explicit inherited pipe handles and hidden-window creation flags. Verify release GUI-subsystem handles work; do not assume debug-console behavior matches release. Retain v1 request framing initially, with 16 KiB limits and 5-second deadlines.
- [ ] Add fake-child tests for fragmented frames, malformed/oversized output, stderr noise, timeout, early exit, unknown IDs and bounded queue pressure. Preserve button edges in order; coalesce analog latest values only. On bounded button queue overflow, stop/degrade and neutralize rather than silently losing a release.
- [ ] Run `cargo test --manifest-path tauri/virtual_joystick/Cargo.toml` and `cargo test -p trenino-runtime --test joystick_worker`; build Tauri release and run its worker mode through a harness from an unrelated working directory with missing driver. Require structured failure, no UI, no recursive single-instance launch, and no process leak. Commit after passing.

## Task 3: Move configuration and ownership checks into Rust

**Files:** Create runtime configurator/windows modules and `crates/trenino-runtime/tests/joystick_configuration.rs`; retain existing installer hooks/resources.

**Consumes:** Rust SDK capability probe from Task 2. **Produces:** Configurator interface above, replacing runtime PowerShell/C# and `reg.exe` subprocesses.

- [ ] Add failing tests for exact descriptor versus extra axes/POV/FFB, busy/missing driver, absent/stale ownership marker, malicious resource paths/reparse ancestors, marker-write failure and delayed arrival/removal.
- [ ] Implement Rust Windows API registry/probe operations; use narrowly scoped ShellExecuteEx `runas` for bundled `vJoyConfig.exe` with fixed arguments, mapping UAC 1223 explicitly. Keep runtime process unelevated and avoid generalized executable/argument commands exposed to UI.
- [ ] Preserve 100 ms polling and a single 10-second monotonic deadline; account for probe duration. Scope the deadline after UAC acceptance; cancelling consent leaves requested state unchanged. Do not abandon an elevated operation and assume no later device mutation occurred: reconcile after process completion/timeout.
- [ ] Set ownership only after this operation creates an absent device and verifies descriptor; if marker persistence fails, retain cleanup diagnostics and do not report success. A compatible pre-existing unowned device is a conflict: no automatic adoption/deletion. Disabling releases local acquisition and reports the conflict without deleting foreign state.
- [ ] Require both ownership and fresh descriptor match before runtime deletion. Preserve installer marker interoperability; test alternate-credential elevation/HKCU identity because the creating user's marker and an administrator's HKCU may differ.
- [ ] Run `cargo test -p trenino-runtime --test joystick_configuration`; confirm all mock elevation/registry/probe cases pass and real UAC cancellation is checked on Windows. Commit the configuration implementation.

## Task 4: Port lifecycle, source safety and recovery

**Files:** Create runtime manager module and `crates/trenino-runtime/tests/joystick_lifecycle.rs`.

**Consumes:** Tasks 1–3; shared serial input events, clock and persistence services. **Produces:** `JoystickHandle` commands/status/events with no dependency on UI lifetime.

- [ ] Port startup/enable/disable/error tests from the Elixir manager with a fake clock and SDK/worker. Preserve states, durable requested setting, 250/500/1000/2000/4000 ms retries, stale transition rejection and reason-only status updates.
- [ ] Add failing tests for disconnect while a button is held, same-port reconnect with a new generation, source lag/overflow, calibration removal, mapping removal, worker restart, and shutdown with pending mutations. Disconnected controls center/release while other sources retain state; reconnect starts neutral until a fresh sample from its new generation arrives.
- [ ] Implement one owner actor. Cache only currently connected generations; seed enable from a current-generation snapshot; reject stale input and transition generations. Do not declare Active until acquisition and initial full report are acknowledged. On invalid calibration, release the affected axis to center and report mapping error instead of retaining old output.
- [ ] Sequence graceful shutdown/reset acknowledgement before relinquish; retries start by neutralizing and then publishing only fresh source state. Device removal/busy status does not trigger automatic privileged repair. Exhausted retries expose Error and a manual retry action.
- [ ] On worker parent-pipe EOF, reset/relinquish where possible. On native crash or hang, the OS/driver may retain state: report uncertain output, restart/reacquire within the bounded policy and neutralize first. Do not claim cleanup can be guaranteed during a kernel failure, hard kill or power loss; verify actual pinned-driver behavior in Task 6.
- [ ] Run `cargo test -p trenino-runtime --test joystick_lifecycle`; require deterministic ordering assertions rather than timing sleeps; commit lifecycle service.

## Task 5: Integrate exclusive routing, persistence and existing UI

**Files:** Runtime shared routing/repository modules owned by the overall migration, Tauri joystick adapter, `crates/trenino-runtime/tests/joystick_routing.rs`; reference existing joystick LiveView and MCP tools for parity.

**Consumes:** Task 4 service, shared repository and input router. **Produces:** UI/MCP operations using one durable routing contract.

- [ ] Add failing tests for concurrent simulator/vJoy binding edits, replacement confirmation, duplicate targets, analog/button mismatch and rollback. Keep immediate transaction semantics and existing SQL constraints.
- [ ] Route a physical input to exactly one output using a revisioned routing snapshot. On destination change, stop that input's old dispatch and acknowledge release/neutralization before activating the new destination; stage events during this barrier. A failed release must not activate both routes.
- [ ] Call the service from UI and MCP adapters, preserving mapping/error text semantics and all existing status actions; stop the Elixir joystick owner before starting the Rust owner. Shadow mode may compute reports for comparison but must never acquire vJoy or publish output.
- [ ] Run `cargo test -p trenino-runtime --test joystick_routing` plus frontend adapter tests; exercise enable/cancel/cleanup/retry and mapping replacement from the UI. Commit only after shared routing owners review integration.

## Task 6: Packaging cutover and clean-machine acceptance

**Files:** Modify `tauri/src-tauri/tauri.windows.conf.json`, Windows hooks as needed, `.github/workflows/{ci,nightly,release}.yml`, staging scripts and existing `test/ci/virtual_joystick_workflow_test.exs` replacement; add `docs/testing/rust-joystick-windows.md` during implementation.

**Consumes:** All prior tasks; broader backend packaging cutover. **Produces:** Installer with one application executable plus existing verified driver/configurator/DLL resources, and recorded acceptance evidence.

- [ ] Change extracted-installer smoke tests to launch the installed application in worker mode. Remove `virtual_joystick` externalBin/download/build jobs only after this passes; retain library unit tests. Preserve pinned hashes, signer verification, x64 SDK ABI checks and third-party notices; non-Windows bundles must contain no vJoy payload.
- [ ] Preserve installer shared-driver rules documented above. Test app-created device versus foreign matching device, driver present without uninstall record, changed descriptor, additional vJoy devices, stale markers, silent uninstall, interactive retain/remove and upgrade. A failed cleanup must remain visible and must not erase the only ownership evidence needed for recovery.
- [ ] On clean patched Windows 11 x64 and the explicitly supported Windows 10 baseline, test installed release with Secure Boot/Memory Integrity enabled, no development tools and no preinstalled VC runtime/vJoy. Record exact OS build/security settings, install signature results, driver load state and any reboot requirement. Do not call packaging CI proof of real kernel compatibility.
- [ ] Use Windows controller enumeration and a DirectInput test consumer to verify exactly eight independent axes, endpoints/inversion, all 32 simultaneous button bits, no POV/FFB, no device while mode is off, and game-independent operation.
- [ ] Exercise USB unplug/replug, fast button press/release under analog load, calibration invalidation, worker crash/hang, app graceful exit/hard kill, suspend/resume, driver removal, UAC cancellation and another feeder owning device 1. Record whether hard termination releases/centers the pinned driver; any stuck-control failure blocks release until recovery behavior is established.
- [ ] Install over an existing Elixir-backed release, preserve mappings and requested state, then uninstall both silently and interactively. Verify unrelated vJoy devices and shared drivers survive; repeat under a non-admin user using alternate admin credentials.
- [ ] Run the full workspace checks required by the root migration, plus the existing Rust feeder suite and installer extraction checks. Only then remove dead Elixir joystick manager/bridge/configurator and standalone binary entry point, with equivalent UI/MCP tests retained. Commit the cutover with recorded Windows acceptance results.

## Dependencies and open evidence

- Shared calibration, source identity/generation, routing transaction and repository interfaces must be aligned with sibling plans before implementation. The platform plan proposes `rusqlite` on a dedicated database worker; destination replacement uses one immediate transaction. This plan owns joystick-specific modules only.
- Same-executable worker pipes in the actual Tauri release subsystem are a spike gate, not assumed complete. If unsupported by the current launcher arrangement, keep the existing sidecar temporarily; do not weaken native isolation to meet an artifact-count target.
- Exact pinned-driver hard-kill, Secure Boot/Memory Integrity and current signing-policy compatibility needs real OS evidence. No hardware/driver tests were run during planning.
- Ownership across Windows users is weaker than a durable machine-scoped device identity. Preserve existing markers for migration, reject ambiguous destructive operations, and use the clean-machine/multi-user tests to decide whether a narrowly scoped machine-wide creation record is required before release.
- Replacing `vJoyConfig.exe` itself with Rust is deferred: the program mutates driver configuration and re-enumeration state, beyond the feeder SDK contract. Keeping it as a fixed privileged tool removes application shell plumbing without inventing a driver-management subsystem.
