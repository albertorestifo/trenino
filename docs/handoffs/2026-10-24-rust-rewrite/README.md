# Rust rewrite handoff

## Resume here

**Branch:** `codex/rust-rewrite` in `git@github.com:albertorestifo/trenino.git`.
**Status:** intentionally paused at the user's request. The rewrite is incomplete. The tip contains interrupted work and currently does **not compile**. Do not merge or release it as a completed rewrite.

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
| `48dd6b9` | **WIP:** interrupted hardware repository implementation; causes current compile errors. |

The subsequent handoff commit adds these documents and archived review evidence. Earlier accepted slices are bounded components, not proof of whole-application parity.

## Current verification and immediate blockers

At handoff, root ran `cargo test --workspace --quiet` on the full current tree. It failed during compilation (exit 1), before tests could run. Reported errors in `crates/trenino-runtime/src/storage/hardware.rs` include:

- Line 202: `#[derive(..., Partial)]` names a nonexistent derive macro.
- Lines 359, 435, 533: `StorageError::InvalidHardware` is referenced but not defined in `storage/mod.rs`.
- Line 435: `getrandom::fill` is referenced without a direct dependency.
- Line 519: a `query_map` temporary outlives its prepared statement (`E0597`).
- Unused `any::Any` import at line 8.

These are observed errors, not an exhaustive audit. Tests may expose further issues once compilation is restored. Preserve the WIP and finish it; do not blindly add dependencies or merely silence errors without reviewing the intended contracts. The storage tests and implementation were interrupted mid-edit and have never passed as a delivered slice.

`git diff --check` passed before checkpoint commits (only a CRLF normalization notice). This is not a build or test claim.

Earlier evidence, **not a claim about the current tip**:

- At `4ee4052`, root workspace tests passed 152 tests, strict workspace Clippy passed; formatting was normalized in `e9ef8d9`.
- Accepted AppServices fix round 2: 19 AppServices tests, 11 foundation tests, strict runtime Clippy and scoped formatting passed. Earlier desktop tests/builds passed with `rust-ui` alone and `rust-ui desktop-updater`.
- Firmware fix round 1: 7 compatibility tests and 21 catalog tests plus focused Clippy/formatting passed. Root subsequently ran the partial-file collision unit test: 1 passed. The supervisor still reproduced cache and compatibility defects.
- No final whole-workspace Clippy, frontend, desktop build or test run was performed after the interrupted WIP changes.

## Open tracks and exact next actions

### 1. Hardware repositories — interrupted initial implementation

Read [brief](evidence/storage-hardware-brief.md). Source: `crates/trenino-runtime/src/storage/hardware.rs`, `storage/mod.rs`, `tests/storage_hardware.rs`. There is no completed implementation report or supervisor review.

The writer inventoried device/input/output/matrix/I2C/calibration behavior from the Elixir source and began typed operations on the existing database thread. Complete source-derived validation, transactional matrix replacement/cascades, calibration writes, exact revision increments and rollback tests. Device deletion needs held runtime exclusion across check and commit, not a racy boolean callback. Do not expose a normal mutation API that bypasses the active-device guard.

The adapter to `HardwareRepository`/`ConfigurationRepository`/`CalibrationRepository` was deliberately deferred until the hardware runtime contracts settle. No database lock may span serial writes or ACK waits. Coordinate shared `storage/mod.rs` edits; do not create another connection pool. Original writer identity: `/root/storage_hardware_code`.

### 2. Hardware runtime — interrupted fix round 2

Read [fix round 1 review](evidence/hardware-runtime-fix1-review.md), [implementation report](evidence/hardware-runtime-report.md) and [brief](evidence/hardware-runtime-brief.md). The report describes the completed round-1 delivery; `c94900b` contains later unfinished changes, not a claimed completed round 2.

Round 2 must close nine scoped findings (six P1, three P2):

1. Configuration success must update dispatcher ConfigId/device/pin kinds together with route activation before success publication.
2. New connection generations must not inherit old revocation tombstones; revoked equal generations remain forbidden.
3. Shutdown must close all shared admission paths immediately, including sessions, leases and retained handles, even when cleanup times out.
4. Retain failed neutralization state, suspend reconnect actuation, retry cleanup and refuse false-success shutdown.
5. Own firmware authorization through queued handoff, port close, reservation lifetime and reservation release; block premature lease release.
6. Do not hold the repository mutex across ACK waits or block authoritative dispatch on repository lookup; fence asynchronous lookup results and isolate ACK ownership.
7. Coordinator-level discovery deadline must cover blocked native open/flush while retaining/quarantining unfinished owners.
8. Terminal calibration overflow/error must complete lease cleanup without a UI listener driving it.
9. Joined worker panic is distinct from unfinished timeout; retry must not unwrap a consumed join or drop unrelated owners.

Before interruption the writer reported a compile checkpoint, some R1/R2/R4 red/green work, repository lookup moved to owned workers, and narrower post-ACK persistence. These are progress statements, not acceptance. Run all covering tests and inspect every finding against the WIP before resuming Astra scoped review. Original identities: `/root/hardware_runtime_code`, `/root/hardware_runtime_supervisor`.

### 3. Firmware catalog — fix round 1 reviewed, round 2 not started

Read the **appended scoped fix1 section** of [supervisor report](evidence/firmware-catalog-supervisor-report.md), plus [implementation report](evidence/firmware-catalog-report.md). The supervisor wrote its verdict before its usage-limit failure. Seven original findings are addressed; original F1/F3/F4 remain open, with four exact fixes:

1. **P1:** A and B with the same version/environment return the same mutable path; downloading B changes bytes under A's retained result. Return immutable asset-specific content or hold an explicit replacement-preventing lease.
2. **P1:** Data and receipt are replaced separately. A receipt replacement failure can leave B bytes certified by A's old receipt. Make publication crash/failure-safe and retain valid existing entries. Reproduce with a Windows handle denying receipt replacement.
3. **P2:** Group-wide prerelease admission is wrong. Elixir rejects `1.2.3-rc.2` for `>= 1.0.0 and < 1.2.3`; current Rust accepts it. Preserve operator/conjunction semantics, including valid explicit prerelease bounds.
4. **P2:** Two-component pessimistic requirements with suffixes append `.0` in the wrong position: `~> 1.2+build.1` and `~> 1.2-rc.1` must parse and match according to the oracle.

Also correct the rejected-redirect test URL to preserve the listener's ephemeral port; its current non-contact assertion points at the wrong authority. Production redirect policy was accepted. Do not reopen all seven closed findings unnecessarily.

Legacy cache reuse is explicitly opt-in and typed `LegacyUnverified`; receipts prove metadata association, not cryptographic authenticity. Firmware persistence/startup/UI/flashing are still separate gates. Original identities: `/root/firmware_catalog_code`, `/root/firmware_catalog_supervisor`. The next dispatch is **fix round 2**, then scoped Astra review.

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
