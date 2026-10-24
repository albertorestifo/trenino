# Rust rewrite handoff

## Resume here

**Branch:** `codex/rust-rewrite` in `git@github.com:albertorestifo/trenino.git`.
**Status:** continued on 2026-10-24 (macOS continuation session). The interrupted WIP was finished: the workspace compiles and all three open tracks below are closed with regression tests. Full current gates green: `cargo test --workspace`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo fmt --all --check`, svelte-check (0 errors), 35 frontend tests, frontend production build, and trial desktop test/build with `rust-ui` and `rust-ui desktop-updater` (see commit map continuation). The overall rewrite remains incomplete — see [remaining work](evidence/remaining-work.md); do not merge or release as a completed rewrite.

The user requested this handoff and a push of all work for later continuation. All subagents stopped with a usage-limit error. No agent remains running. Their unfinished source changes were preserved, not discarded or presented as reviewed delivery.

Local workspace: `C:/Users/Alberto/.codex/worktrees/rust-rewrite/tsw_io`. Original checkout `C:/Users/Alberto/Documents/tsw_io` was left on its original branch. Keep the managed worktree; no cleanup or archive is intended. A fresh checkout of this remote branch plus this directory is sufficient to recover the plans, review findings and source work.

Start with this document, then [remaining work](evidence/remaining-work.md), the [coordinated plan](../../superpowers/plans/2026-10-24-rust-rewrite.md), and the track-specific reports linked below. This document supersedes stale status lines in historical reports.

## User decisions to preserve

- Keep Tauri and the existing appearance/workflows, with a small TypeScript frontend. All application rules and effects belong in Rust. LiveView/Phoenix cannot remain the frontend implementation.
- Use the `vjoy` crate and retain the signed vJoy driver. Device 1 is not a requirement: explicitly select IDs 1–16, and do not acquire unrelated devices.
- Use concurrent inexpensive code writers (`gpt-6-luna`, high), Astra supervisors (`gpt-6-astra`, high), and two fresh independent correctness/adversarial reviewers (`gpt-6-sol`, high) per new track. Scoped fix re-reviews do not restart the full review.
- Work on this branch. The latest request authorizes pushing the checkpoint, not merging to master, releasing, or publishing an installer. No PR is required by this request.
- Preserve existing IDs, migration data, firmware wire behavior and external API/MCP contracts. One bounded SQLite owner, one authoritative input resolver and one resource arbiter; no parallel database pool or competing route ownership.
- Retain desired versus active routing revisions, commit-before-publication, generation fences, explicit cancellation, and acknowledged cleanup before updater installation.

## Commit map

| Commit | Meaning |
| --- | --- |
| `914fc811` | Local merge incorporating upstream Windows packaging PR 169 (`b32443901c5f63e5c7f6b6cb5224eb4ae1b0b91f`). |
| `f9cb3e2` | Packaging alignment and standalone signature-verifier workspace exclusion. |
| `3da5194` | Accepted supported legacy database migration fixes. |
| `7eb3b68` | Accepted controls primitives/client/subscription fixes. |
| `6c2d99b` | Accepted UI shell/bridge fix series. |
| `8723455` | Initial hardware runtime delivery, not accepted. |
| `f79f41e` | Initial firmware catalog delivery, not accepted. |
| `4ee4052` | Initial AppServices/Tauri integration. |
| `6b20a81` | Hardware fix round 1; further findings remain. |
| `807420e`, `535b58b` | AppServices/startup fixes, accepted after round 2. |
| `5eb754c` | Firmware fix round 1; scoped re-review requires further fixes. |
| `72438d5` | Documented accepted bounded desktop checkpoint. |
| `c94900b` | **WIP:** interrupted hardware runtime fix round 2. No completed verification/re-review. |
| `48dd6b9` | **WIP:** interrupted hardware repository implementation; caused the handoff compile errors. |
| `242e608` | Continuation: compilation restored (storage hardware finished, tuple snapshot contract, `InvalidHardware` variant, getrandom dep) + macOS database-ownership fix (Darwin aliases flock with SQLite fcntl locks; inode-keyed `/var/tmp` sidecar on macOS, inode-flocked DB file kept on Linux, Windows named mutex unchanged). |
| `c2dabf1` | Matrix pin validation aligned with the Elixir oracle (repeated pin values legal; only positions unique). |
| `91d518e`, `272432a` | Firmware catalog fix round 2: immutable asset-keyed cache paths, crash-safe publication, exact prerelease/pessimistic oracle semantics (42-case executed Elixir matrix), corrected redirect fixture. Merged. |
| `e9ca5d0`, `4120266` | Hardware runtime fix round 2: all nine findings closed with red/green regression tests, guarded device deletion fence, atomic fenced configuration confirmation. Merged. |
| `dcd3a89` | `DatabaseHardwareRepository` storage-backed adapter implementing the hardware runtime repository contracts; strict workspace clippy clean. |

The subsequent handoff commit adds these documents and archived review evidence. Earlier accepted slices are bounded components, not proof of whole-application parity.

## Current verification (after continuation)

All of the following were run on macOS (arm64, Rust 1.91.1, Node 25) at `dcd3a89` and passed:

- `cargo test --workspace` — all suites green (storage_hardware 6, hardware_runtime 30, hardware_service 15, firmware_catalog 22, app_services 19, foundation 11, plus core/lib suites; 0 failures).
- `cargo clippy --workspace --all-targets -- -D warnings` — clean. `cargo fmt --all --check` — clean.
- `npm --prefix tauri/ui run check` — 344 files, 0 errors/warnings. `npm --prefix tauri/ui test` — 35/35. `npm --prefix tauri/ui run build` — ok.
- `cargo test --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui` and `cargo build` with `--features "rust-ui desktop-updater"` — ok.

Historical handoff blockers (compile errors in `storage/hardware.rs`, calibration upsert against a non-unique index, matrix pin-repeat divergence) are all resolved; see commit map. A platform defect found and fixed during continuation: on macOS the unix ownership flock on the database file deadlocked SQLite (Darwin implements flock on the same lock manager as fcntl); Linux behavior is unchanged and Windows was never affected.

Still unperformed gates (unchanged): actual WebView IPC smoke, Linux/Windows clean-machine execution of this continuation, physical hardware/simulator/signed-installer acceptance. Firmware runtime ownership, Lua, HTTP/MCP compatibility and remaining UI flows remain open per the delivery map.

## Closed by the 2026-10-24 continuation (formerly open tracks)

### 1. Hardware repositories — CLOSED (`242e608`, `c2dabf1`, `dcd3a89`)

`storage/hardware.rs` completed on the existing bounded database worker: typed device/input/output/matrix/I2C/calibration mutations, source-derived validation, transactional matrix replacement with binding cascades, one revision bump per committed mutation, rollback on invalid input, guarded `delete_device_unchecked` (pub(crate), no public bypass). Matrix pin validation matches the Elixir oracle exactly. `DatabaseHardwareRepository` (`src/hardware/repository.rs`) now implements the runtime's `HardwareRepository`/`ConfigurationRepository`/`CalibrationRepository` contracts: identity-resolved lookup, atomic fenced confirmation, calibration persistence, guarded deletion. Suite: `tests/storage_hardware.rs` (6 tests) plus adapter unit tests.

### 2. Hardware runtime fix round 2 — CLOSED (`e9ca5d0`, merged `4120266`)

All nine findings closed with per-finding regression tests (30 hardware_runtime + 15 hardware_service tests). Red/green was demonstrated by fix reversion for R1, R2, R7, R8; R3/R4/R5/R6/R9 tests encode the supervisor's reproduced defects. Additionally implemented: held device-deletion exclusion fence enforced atomically with activation, and post-ACK atomic `confirm_configuration` persistence behind generation fences (never across a serial wait). Scoped Astra-style re-review by a fresh reviewer has **not** been re-run in this continuation; the per-finding test map is in the agent report summarized in the commit.

### 3. Firmware catalog fix round 2 — CLOSED (`91d518e`, merged `272432a`)

All four findings closed: asset-keyed immutable cache destinations (FNV-1a-64 over receipt provenance; receipt equality still gates reuse), crash-safe data+receipt publication at one asset-bound destination, prerelease admission ported exactly from the executed Elixir 1.20 `Requirement.match_op?` (42-case oracle matrix), two-component pessimistic suffix parsing per oracle, and the redirect fixture now contacts the listener's ephemeral port. Suite: 22 firmware_catalog tests + core compatibility tests. Scoped re-review by a fresh reviewer has **not** been re-run in this continuation; the finding → symbol → test map is appended to `evidence/firmware-catalog-report.md`.

Next open work is tracked in [remaining work](evidence/remaining-work.md): train/script/binding/firmware-record repositories, desired/active routing reconciliation, AppServices registration of the real hardware service + UI flows, controls runtime, simulator calibration, vJoy manager, avrdude flashing, Lua, HTTP/MCP compatibility, packaging cutover, final branch review.

## Accepted bounded slices

- Foundation: typed IDs, dedicated bounded SQLite owner, strict schema admission and bootstrap behavior.
- Pure hardware: protocol/custom COBS, configuration validation, calibration/detection helpers, HT16K33 encoding.
- vJoy adapter: vendored `vjoy` 0.7.1 / `vjoy-sys` 0.5.2, explicit selected-device acquisition, descriptor/DLL checks, neutralize/release behavior. App manager/UI integration remains undone.
- Migration: supported Ecto v0.7.4/current fixtures, exact schema/ledger recognition, backup/path safety and data transforms; actual user database untouched.
- Controls primitives: mapping/formatting, simulator HTTP client, owned subscriptions, FIFO and generation fences; live controllers/OS keyboard/Lua remain undone.
- UI shell/DTO/bridge: static Svelte/TypeScript shell, consent/read-only lists, subscription recovery, redaction and theme behavior; editors/wizards remain incomplete.
- AppServices/Tauri startup: isolated full-v2 trial database, alias/cross-process ownership, complete runtime metadata, validated settings revisions, merged TAURI_CONFIG, visible native startup refusals, subscription commands and retryable shutdown coordinator. All six accepted review findings closed through `535b58b`.

See archived reports for exact scopes. A no-hardware AppServices shutdown acknowledgement currently covers its real database only; every future service needs a real participant before exposure.

## Windows packaging change already incorporated

The requested review of the newly merged Windows release change is complete. Read [merge review](evidence/packaging-merge-review.md), [sync report](evidence/packaging-sync-report.md), and [sync acceptance](evidence/packaging-sync-review.md).

Preserve native stable Help → Check for Updates, signed Tauri updater/NSIS metadata and public-key continuity. Verify/download before Rust shutdown acknowledgement; install only after successful cleanup, and refuse ordinary updater shutdown during active flashing. No duplicate stable app-version banner; firmware notifications remain separate. Nightly/development policy differs.

Package `vJoyInstall.dll` beside `vJoyConfig.exe`; use trusted absolute installed resource paths without PATH/CWD/reparse fallback. Preserve explicit IDs 1–16. Keep signature-verifier helper outside the root workspace. NSIS and MSI prerequisite behavior is not interchangeable. No signing secret, installer, real updater installation or publication was used.

## Work beyond these immediate fixes

Follow [remaining-work.md](evidence/remaining-work.md) and the six committed plans. Major outstanding work includes full train/binding/firmware/script repositories; desired/active routing reconciliation; actual train controllers and keyboard ownership; simulator exploration/calibration; vJoy app manager/configurator; avrdude flash ownership/history; Lua compatibility and bounded execution; HTTP/MCP compatibility; all retained UI flows; real service lifecycle registration; CI/packaging cutover and final branch review.

Ready but **not dispatched**: [controls runtime brief](evidence/controls-runtime-brief.md), waiting for stable hardware contracts; [Lua compatibility spike brief](evidence/script-compatibility-spike-brief.md). Do not enable a candidate Lua engine until executable compatibility and failed-call state/termination semantics are resolved.

## Development and verification notes

- Windows environment used PowerShell, Rust 1.91.1 and Node 25.2.1 with mise. Keep explicit workdir; all agents share files.
- Root workspace: `cargo test --workspace`, `cargo clippy --workspace --all-targets -- -D warnings`, `cargo fmt --all --check` after restoring compilation.
- Frontend: `npm --prefix tauri/ui ci`, `npm --prefix tauri/ui run check`, `npm --prefix tauri/ui test`, `npm --prefix tauri/ui run build`.
- Trial desktop: `cargo test/build --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui` and separately `--features "rust-ui desktop-updater"` (use actual `cargo test` or `cargo build`, not literal `test/build`). Static frontend must be built first.
- Default legacy desktop still expects the genuine `binaries/trenino_backend-x86_64-pc-windows-msvc.exe`, absent here. Do not stage a fake executable. Legacy stays default until parity gates pass.
- vJoy build requires libclang at build time. This machine used ignored `.superpowers/sdd/2026-10-24-rust-rewrite/build-tools/clang/native/libclang.dll` with `LIBCLANG_PATH` pointing to that directory. Provision locally on another machine; do not commit downloaded build binaries. Vendor tests must use `--lib`; upstream integration tests can touch real hardware.
- Use disposable databases, loopback fake HTTP, fake serial/key/vJoy adapters. No real user DB, physical board/COM port, driver mutation, simulator, OS key injection, flash, installer or signing was exercised.
- Actual WebView IPC smoke, Linux/macOS execution, clean-machine installation/update/rollback and physical hardware/simulator acceptance remain unperformed gates.

## Evidence archive

`evidence/` copies all Markdown briefs/reports/progress from the ignored local SDD directory so they survive a clone. It also preserves hardware supervisor Rust probes and the firmware fix1 harness source/manifest/lockfile. Historical absolute paths and `.superpowers` links describe the original session; map same-named Markdown files to this archive. Probe `#[path]` and Cargo path references may need adapting on another checkout. Harness tests asserting defects reproduce failures; their passing is **not** product acceptance.

Generated `.diff` bundles are omitted because commits preserve their changes; reconstruct with the ranges in the reports. Build outputs, `.exe`/`.pdb`, downloaded toolchains, `target`, node_modules, disposable databases and generated local schemas are deliberately not repository content. All tracked/untracked source work at pause is committed. The archived `progress.md` ends just before this handoff; this README is the final checkpoint authority.

When resuming, do not repeat accepted planning/reviews. Restore compilation, finish the three open tracks above, then continue the remaining implementation with the requested model/review structure. Keep this checkpoint unmerged until the full acceptance gates are actually met.
