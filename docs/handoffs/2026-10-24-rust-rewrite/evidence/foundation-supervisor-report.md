# Foundation supervisor review

Date: 2026-10-24
Reviewed foundation commit: c67a519
Adjacent hardware commit: 5c8b358
Worktree: C:/Users/Alberto/.codex/worktrees/rust-rewrite/tsw_io

## Verdict

Changes requested. This is a bounded first foundation/storage slice, not the completed rewrite. The explicit read-only Ecto support and separate Rust bootstrap schema are acceptable partial-scope choices, but workspace compatibility, writable-schema admission, and shared ID contracts need fixes before the slice is accepted.

Two independent child reviews completed sequentially: correctness_review and adversarial_review, both requested as gpt-6-sol / high with fork_turns none. Both read the brief, report, diff, and relevant implementation/original sources. Neither reviewer nor the supervisor edited implementation code or accessed a real user database or hardware.

## Actionable findings

1. **P1 — Root workspace breaks existing standalone crates.** Cargo.toml:1-3 omits the brief's required workspace.exclude entries. Supervisor ran cargo metadata --manifest-path <manifest> --no-deps --format-version 1 for tauri/src-tauri/Cargo.toml, tauri/keystroke/Cargo.toml, and tauri/virtual_joystick/Cargo.toml; all initially exited 1 with “current package believes it is in a workspace when it is not.” The concurrent joystick work subsequently added its own nested workspace, but desktop and keystroke still fail. Add the three explicit root exclusions and verify all three commands. Merely limiting workspace.members is insufficient. The foundation report's claim that the existing manifests remain outside the workspace needs correction after verification.

2. **P1 — Existing Rust databases are admitted as writable solely from header values.** crates/trenino-runtime/src/storage/mod.rs:103 returns writable when application_id=0x54524E52 and user_version=1 without validating any table, column, index, constraint, FK, or unexpected object. A stamped database lacking tables therefore passes open and fails only on use; one with matching foreign app_settings can be mutated. Validate the supported Rust schema fingerprint before admitting writes and return UnsupportedSchema for malformed/foreign shape. Add disposable fixtures for missing table/column, missing unique/FK/cascade constraints, and unexpected schema objects; verify refusal without schema/data mutation. Both independent reviewers identified this; adversarial assessed P1.

3. **P2 — ConfigId serde bypasses the constructor invariant.** crates/trenino-core/src/shared.rs:28-30 derives Deserialize directly for the private u32 field. JSON 0 and 2147483648 deserialize although ConfigId::new rejects them. Deserialize through checked construction and test 0, i32::MAX+1, negative/overflow values, and valid endpoints. The separate hardware ConfigId at crates/trenino-core/src/hardware/mod.rs:7-8 has the same bypass; coordinate its repair with the hardware owner.

4. **P2 — Foundation and hardware expose different types for the same configuration ID.** crates/trenino-core/src/shared.rs:30 exports trenino_core::ConfigId, while hardware/mod.rs:8 defines another ConfigId accepted by build_configuration at lines 144-146. A shared ConfigId cannot be passed to that public hardware API. Consolidate around the shared checked type, optionally re-export it from hardware to preserve that path, and add one integration use of the root-exported type in hardware configuration building. This spans the two delivered slices and requires coordination rather than independent duplicate fixes.

5. **P2 — Worker transport discards typed error categories.** crates/trenino-runtime/src/storage/mod.rs:53 uses Result<T, String>; request handlers at lines 108-115 stringify SQLite failures and request at line 178 wraps them in DatabaseFailure. delete_profile's missing-row case at line 113 never returns the declared StorageError::NotFound. Preserve owned structured categories through the reply channel, including NotFound and enough conflict/FK classification for callers to handle failures without parsing strings. Test missing deletion, duplicate profile creation, invalid profile child write, rollback/no partial mutation, and successful operations after a failed request. Keep external-facing errors sanitized when adapters are added.

## Verification and review coverage

- Supervisor directly verified standalone manifest metadata failures listed above.
- Correctness reviewer ran cargo test -p trenino-runtime: all 10 foundation tests passed.
- Correctness reviewer inspected root cargo metadata: only core/runtime are workspace members; membership did not prove nested exclusion.
- Source review covered storage admission and transactions, worker lifecycle, public settings/key redaction, lossless numeric-string serde, existing path/settings behavior, and shared/hardware integration.
- The adversarial reviewer found no supported claim of secret leakage or a worker leak in this bounded review.
- Existing tests exercise happy paths and one malformed Ecto shape but do not catch the stamped Rust-schema, unchecked ConfigId, type integration, or typed-error defects.

## Scope and remaining work

Do not treat the broader platform plan as delivered by this slice. Current and v0.7.4 migration, backup/rollback, full Ecto fingerprinting, full repositories, subscriptions, cancellation/outcome reconciliation, and runtime shell/startup remain incomplete. Ecto access is intentionally read-only.

Settings currently supports one injected API key file, not automatic Windows USERPROFILE / TSW7 then TSW6 discovery. Mark that platform parity follow-up explicitly rather than claiming full API-key discovery. Path resolution is pure and does not create first-run data directories; the future startup owner must do so before opening a fresh database. Neither is a separate blocker for the explicitly bounded shell-free foundation slice, but both need tracked completion before cutover.

## Recommended fix ownership

Relay findings 1, 2, 3 (shared half), and 5 to the original foundation coder. Coordinate finding 4 and hardware's unchecked deserializer with the original hardware coder. Supervisor/reviewers remain read-only with respect to implementation. After fixes, rerun workspace tests/fmt/clippy and all three standalone metadata checks; review the new diff and focused regression tests before acceptance.


## Fix implementation and exact test targets

- Expand the minified Database::open worker closure and request match in crates/trenino-runtime/src/storage/mod.rs:88-117 into conventional readable helper functions/blocks while fixing admission and error transport. This is a reviewability request from the coordinator: cargo fmt currently leaves substantial transactional and migration logic on long single lines. Preserve behavior except for reviewed fixes.
- Add foundation regression tests to crates/trenino-runtime/tests/foundation.rs (or split into clearly named storage/contract integration test modules in the same tests directory): malformed stamped Rust schema refusal with no mutation; missing/wrong constraints and unexpected objects; structured NotFound/duplicate/FK failures; subsequent success and no partial write after each failure; shared ConfigId serde rejection/valid-boundary roundtrip.
- Add the shared-ID hardware integration regression to crates/trenino-core/tests/hardware.rs if that suite exists, otherwise a dedicated crates/trenino-core/tests/shared_contracts.rs. It must pass trenino_core::ConfigId directly to hardware::build_configuration so the type boundary is compile-checked; test checked hardware-path deserialization if retaining a re-export.
- Do not add tests that merely mirror implementation. Exercise externally observable refusal, data integrity, and shared API behavior. Standalone Cargo metadata checks are the direct verification for exclusions.
