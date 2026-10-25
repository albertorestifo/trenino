# Rust feature parity completion implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans. Parallel execution explicitly requested by the user; partition file ownership.

**Goal:** Finish the Rust port with the retained Elixir application's user-visible behavior, preserving prior OMP work.

**Architecture:** Continue the authorized Tauri + Svelte frontend / Rust services migration on `codex/rust-rewrite`. Recover unfinished sibling worktrees before implementing missing features. One SQLite owner, one input resolver and resource arbiter; desktop commands and MCP share live services.

**Tech Stack:** Rust, Tokio, rusqlite, mlua, reqwest, vendored vjoy, Tauri, Svelte/TypeScript.

**Spec:** `docs/superpowers/plans/2026-10-24-rust-rewrite.md` and its five subsystem contracts. Exact legacy behavior is defined by `lib/trenino/**`, `lib/trenino_web/**` and their tests. `docs/handoffs/2026-10-24-rust-rewrite/evidence/parity-audit.md` is a gap inventory, not a replacement spec.

## Global Constraints

- Keep Tauri and the existing appearance/workflows, with a small TypeScript frontend. All application rules and effects belong in Rust.
- Preserve existing IDs, migration data, firmware wire behavior and external API/MCP contracts.
- One bounded SQLite owner, one authoritative input resolver and one resource arbiter; no parallel database pool or competing route ownership.
- Retain desired versus active routing revisions, commit-before-publication, generation fences, explicit cancellation, and acknowledged cleanup before updater installation.
- Explicit vJoy selection IDs 1–16; do not acquire or remove unrelated devices. Use the vendored vjoy crate and signed driver.
- Preserve existing uncommitted changes, including sibling worktrees. No release/merge/publish or real user database/device mutation.
- Run fake-service/loopback tests; clearly distinguish these from physical hardware, simulator and Windows installer acceptance.

## Review Focus

- Service exists but has no production caller: prove desktop/MCP mutations and hardware events reach the real runtime.
- Profile changes/disconnect/shutdown race with pending polls, scripts or timers: prevent stale effects and acknowledge termination.
- Resource leases/source loss: release held keys, neutralize only affected vJoy controls and resume from fresh samples.
- Persisted edits while active: reconcile committed bindings/scripts and expose failure, never silent success.
- UI navigation/stale replies: preserve drafts/errors, use actual port/generation, clean subscriptions and keep every retained workflow reachable.

## Recovery inventory

Main HEAD at start: `3ff7d38`. Main checkout has incomplete g4 fixes (including firmware compile failure). `../trenino-g4-parity-smallfix` contains a more complete version with tests. `../trenino-g2-script-runner` and `../trenino-g3-sim-connection` contain unfinished runtime implementations. `../trenino-f2-ui-b` contains unfinished train/script/firmware/vJoy screens. Preserve originals; recover changes into this branch and review before acceptance. Current handoff README is stale: domain repositories, controllers, MCP and firmware upload primitives have since landed.

### Task 1: Recover and verify bounded parity fixes

**Files:** runtime firmware/{catalog,http,upload}.rs, hardware/mod.rs, executable.rs, keyboard.rs, storage/domain/{trains,sequences,scripts,bindings}.rs, storage/hardware.rs; associated tests; core/shared.rs.
**Interfaces:** Existing storage methods; add missing context helpers without alternate DB ownership.
- [x] Recover g4 changes plus untracked executable module, preserving initial main diff in `tmp/migration-recovery`.
- [x] Restore compilation; test GitHub auth headers/compatibility selection, manual scan bypass, schema-specific blank validation, grapheme length and helper functions against the oracle.
- [x] Inspect executable discovery trust and upload rescan lifecycle; repair regressions with focused failing tests.
- [x] Run workspace tests, fmt and strict clippy. Fresh adversarial review, fix and re-review findings.

### Task 2: vJoy live dispatch and lifecycle

**Files:** runtime vjoy/{manager,adapter,windows,store}.rs plus mapper/configurator modules as needed; tests/vjoy*.rs.
**Interfaces:** VjoyManager live input method consumes authoritative InputIdentity/InputEvent plus shared resolver/arbiter; no second mapping owner. Expose source loss/suspend/reload hooks for integration.
- [x] Test axis mapper against legacy eight-case oracle: uncalibrated/invalid range, clamp, inversion, reversed bounds, midpoint 16384.
- [x] Implement cached input while disabled, publish on activation, digital button dispatch, per-port disconnect safe values and mapping reload.
- [x] Implement bounded runtime-loss recovery and trusted installed helper lifecycle/ownership without touching unrelated IDs.
- [x] Validate selected-device isolation and lease/generation fencing. Scoped tests and adversarial review.

### Task 3: Script runner and simulator connection owners

**Files:** runtime train/script/runner.rs and mod.rs, train/button_controller.rs + sequence.rs only as needed to remove duplicate executor; simulator/connection_owner.rs + mod.rs; tests/script_runner.rs and simulator_connection.rs.
**Interfaces:** Recover existing ScriptRunner and SimulatorConnectionOwner contracts from sibling worktrees, keep injectable Clock and effect/subscription ports. Expose cloneable shutdown/reload/manual-run/log and connection retry/reconfigure/disconnect/subscribe APIs.
- [x] Recover unfinished code and add failing behavioral tests based on legacy runner/connection suites.
- [x] Complete 200ms change-only polling, 100-entry log ring, scheduled callbacks, ordered effects, failure containment and train/reload cleanup.
- [x] Complete 1s initial connect, 30s health/retry, 2s transient probes/three-failure tolerance and needs-config/error transitions.
- [x] Enforce generation barriers, bounded owned tasks, retryable acknowledged shutdown. Test reconfigure/disconnect during in-flight HTTP and no stale scheduled script effects.
- [x] Run focused suites and fresh adversarial review, fix/re-review findings.

### Task 4: Recover complete UI workflows

**Files:** tauri/ui/src/app/pages/{trains,scripts,firmware,virtual-joystick}, components/wizards, app/{App,hardware}, bridge/{client,route}, tests.
**Interfaces:** Existing typed Rust UI commands/DTOs; explicitly report missing live capabilities rather than fake success. Preserve configuration/settings editors already landed.
- [x] Recover f2 screens, bridge and route edits; merge App changes with current configuration/settings integration.
- [x] Make train creation/edit, element/binding/calibration/sequence/script flows, firmware and vJoy reachable with loading/error handling.
- [x] Replace fake hardware port/generation with authoritative event metadata; clean event listeners on unmount.
- [x] Run check/test/build and browser workflow smoke. Adversarial review against legacy workflows; repair gaps.

### Task 5: Production composition and shared domain effects

**Files:** runtime composition/adapters module, app.rs, mcp/storage_ports.rs, tauri/src-tauri/src/rust_ui.rs and commands; integration tests.
**Interfaces:** Use HardwareServiceHandle::{resolver,resource_arbiter}, TrainServiceHandle, output/display controllers, ScriptRunner, SimulatorConnectionOwner and VjoyManager from tasks 2/3. No Arc<AppServices> ownership cycles.
- [x] Instantiate controllers and real simulator/subscription/storage/hardware/keyboard adapters; forward every ordered input and connection/train event.
- [x] Connect output/display/script effects to hardware and share runtime state with MCP/UI. Publish status snapshots and proper error states.
- [x] After committed UI/MCP mutations reload/reconcile active routing and affected controllers/scripts; wire manual script execution/logs and simulator retry/reconfigure.
- [x] Register actual shutdown participants: stop admission, cancel/join all effect producers, release keys/vJoy/outputs, close network/serial, DB last. Uploads own hardware handoff/rescan hooks.
- [x] Test end-to-end fake-service train activation/input/effect/reload/disconnect/shutdown, including active mutations from MCP and UI.
- [x] Adversarial chunk review and fixes.

### Task 6: Reconcile parity inventory and distribution gates

**Files:** audit/handoff docs, appropriate packaging/CI manifests/scripts after parity gates.
- [x] Re-audit every GAP/PARTIAL in parity-audit.md and retained UI routes; implement remaining concrete behavior with oracle tests.
- [x] Run cargo test --workspace; cargo clippy --workspace --all-targets -- -D warnings; cargo fmt --all --check.
- [x] Run npm --prefix tauri/ui run check; npm --prefix tauri/ui test; npm --prefix tauri/ui run build.
- [x] Run desktop tests/build with rust-ui, and rust-ui desktop-updater; smoke actual WebView IPC and fake-service workflows.
- [x] Add explicit Rust packaging path; keep legacy release default pending Windows driver/installer/hardware acceptance. These native gates remain unverified here.
- [x] Whole-branch adversarial review, repair concrete findings, update durable evidence and remaining gates.

### Task 7: Restore legacy JSON HTTP API (newly discovered audit omission)

**Files:** runtime/http_api.rs, mcp/server.rs, storage/domain/scripts.rs timestamp accessor, tests/http_api.rs; desktop listener construction.
**Interfaces:** `CompatibilityApi::new(Arc<Database>,Arc<Ports>)`, optional coordinated shutdown callback; `McpServer::with_compatibility_api` mounts on the same external listener. Preserve numeric IDs and legacy JSON envelopes.
- [x] Port `/api/health`, POST `/api/shutdown`, GET `/api/trains`, `/api/trains/:id`, GET/POST `/api/trains/:id/scripts`, GET/PUT/PATCH/DELETE `/api/scripts/:id`, GET `/api/outputs`, `/api/simulator/endpoints`, `/api/simulator/value`.
- [x] Reuse shared storage/domain ports and mutation reload watcher; serialize script UTC timestamps, 404/422 errors, simulator 400/503/502 behavior; no second DB pool/listener.
- [x] Test actual HTTP requests over loopback, persistence after script mutations, numeric IDs, validation/unknown resources, simulator data pass-through and shutdown/admission behavior.
- [x] Adversarial review and wire production API using existing native coordinated exit path.

## Closing verification

Implementation, chunk/fix reviews, both calibration closing reviews and fresh aggregate verification are complete and recorded in the [completion handoff](../../handoffs/2026-10-25-rust-parity/README.md). Checkbox completion describes software delivery, not physical or native installer acceptance.
