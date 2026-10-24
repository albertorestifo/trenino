# Foundation coding slice report

Implemented in the `codex/rust-rewrite` worktree. No commit was created.

## Delivered

- Added the root Cargo workspace with only `crates/trenino-core` and `crates/trenino-runtime`; the existing Tauri, keystroke, and virtual joystick manifests remain outside the workspace. Added generated Rust `target` directories to `.gitignore`.
- Added shared DTOs in `trenino-core`: SQLite `EntityId` and operation/session/epoch/revision counters serialize as decimal strings; firmware `ConfigId` validates the positive signed-32-bit range; app errors and epoch/topic/revision snapshot/change envelopes are typed.
- Added runtime platform path resolution with injected environment values, preserving Windows `%APPDATA%/Trenino`, macOS Application Support, Linux XDG or `~/.local/share/trenino`, and `DATABASE_PATH` precedence.
- Added a bounded-channel, dedicated SQLite owner thread with owned results and joined shutdown. Its explicit Rust bootstrap schema has settings, typed profiles, and cascading profile settings; each mutation uses a transaction and foreign keys are enabled.
- Added guarded recognition of the exact latest Ecto migration version (`20260927000000`) with required `schema_migrations`, `app_settings(key,value)`, `devices(id,name)`, and `train_identifiers` tables. Recognized Ecto files open query-only; settings and individual device-profile reads work, writes fail explicitly. Unknown/newer and malformed schemas are refused without mutation.
- Added settings APIs for unset/enabled/disabled error-reporting consent, simulator URL default, API key override/file fallback, and a public snapshot that exposes only whether a key is configured.
- Added `foundation.rs` tests for lossless IDs, snapshots, consent and key redaction, path precedence, fresh schema and FK cascade, concurrent updates, unknown/newer refusal, legacy current-schema read-only access, and malformed-schema refusal.

## Verification

- `cargo test --workspace` passed: 21 tests across the foundation and concurrently developed hardware slice.
- `cargo fmt --all -- --check` passed.
- `cargo clippy --workspace --all-targets -- -D warnings` currently fails only in the sibling hardware code: `manual_is_multiple_of` in `hardware/calibration/mod.rs` and `derivable_impls` in `hardware/mod.rs`. I notified the hardware coder and did not edit their files.

## Remaining migration work

This is not full legacy migration support. The current Ecto schema recognition checks its latest migration marker and key table/column shape; it does not yet fingerprint every table/index/constraint. Ecto databases are intentionally read-only. Migrating current and v0.7.4 schemas, including data transforms, backup/rollback, full typed repositories, and preserving existing user DB writes, remains follow-up work. The bootstrap profile schema is marked as a separate Rust schema and does not claim Ecto compatibility.

## Supervisor fix round 1 (2026-10-24)

Addressed all five actionable findings from `foundation-supervisor-report.md`.

1. Added explicit root workspace exclusions for `tauri/src-tauri`, `tauri/keystroke`, `tauri/virtual_joystick`, and `vendor/vjoy`. Membership remains limited to core/runtime.
2. Replaced header-only writable admission with an exact Rust bootstrap schema fingerprint. Admission now checks all non-internal SQLite objects and normalized `CREATE TABLE` definitions for the settings/profile tables, including primary/unique keys, composite key, foreign key, cascade rule, and absence of unexpected objects. A mismatched stamped database returns `UnsupportedSchema` before writes.
3. Implemented checked `ConfigId` deserialization through `ConfigId::new`, rejecting zero, values above `i32::MAX`, negative input, and `u32` overflow. Valid endpoints round-trip.
4. Removed the duplicate hardware `ConfigId`; `hardware::ConfigId` now re-exports the shared root type. The shared-contract integration test passes the root type directly to `hardware::build_configuration`.
5. Changed worker replies to carry `Result<T, StorageError>` rather than strings. SQLite unique/primary-key conflicts, foreign-key failures, and other constraints retain typed categories; deleting a missing profile returns `NotFound`. Constraint errors display sanitized messages. Failed transactions leave no child data, and the worker accepts later successful requests.

Added regression tests in `crates/trenino-runtime/tests/storage_admission.rs` for malformed stamped schemas (missing table/column, unique key, FK, cascade, and unexpected object), unchanged schema plus row counts, typed error categories, transaction recovery, and no partial child write. Added `crates/trenino-core/tests/shared_contracts.rs` for the root-to-hardware type boundary and checked ConfigId serde cases in `foundation.rs`.

Exact verification commands and results:

- `cargo metadata --no-deps --format-version 1` — exit 0.
- `cargo metadata --manifest-path tauri/src-tauri/Cargo.toml --no-deps --format-version 1` — exit 0.
- `cargo metadata --manifest-path tauri/keystroke/Cargo.toml --no-deps --format-version 1` — exit 0.
- `cargo metadata --manifest-path tauri/virtual_joystick/Cargo.toml --no-deps --format-version 1` — exit 0.
- `cargo fmt --all` — completed; `cargo fmt --all -- --check` — exit 0.
- `cargo test --workspace` — exit 0; 26 tests passed.
- `cargo clippy --workspace --all-targets -- -D warnings` — exit 0.

No commit was created. Existing follow-up limits still apply: Rust-to-Ecto data migration and v0.7.4 support, exhaustive Ecto schema fingerprinting, full repositories, backup/rollback, and automatic Windows TSW7/TSW6 API-key discovery are incomplete. The current Ecto check remains read-only and the API-key file must be explicitly injected.

Additional regression: reopening a valid stamped Rust database retains its data and remains writable. This passed with the final 26-test workspace run.

## Supervisor fix round 2 (2026-10-24)

Fixed both schema-admission bypasses from `foundation-fix1-review.md`:

- Bootstrap schema validation now compares the preserved `sqlite_master.sql` text directly with the exact canonical DDL. It no longer strips quoting or whitespace, so quoted type names and concatenated tokens cannot erase constraints during comparison.
- User-object inventory now uses `name NOT GLOB 'sqlite_*'`. GLOB treats `_` literally, so legal `sqlitex_*` names remain visible. The same predicate is used when deciding whether an unstamped database is empty, validating a stamped Rust schema, and checking test fixtures for mutation.

Added regression fixtures for a quoted type declaration, a concatenated type token, stamped `sqlitex_foreign` extra table, and an unstamped database containing only `sqlitex_foreign`. The refusal cases verify unchanged schema and row counts; the unstamped case verifies its existing row remains and no bootstrap table is created. Existing valid-schema reopen coverage confirms canonical Rust DDL remains writable after restart.

Exact verification:

- `cargo test -p trenino-runtime --test storage_admission` — exit 0; 4 tests passed.
- `cargo fmt --all -- --check` — exit 0.
- `cargo test --workspace` — exit 0; 27 tests passed.
- `cargo clippy --workspace --all-targets -- -D warnings` — exit 0.

No commit was created. No blocker remains for the two round-two findings; the broader migration limitations from the original report are unchanged.
