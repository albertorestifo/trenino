# Runtime/UI integration report

Branch: `codex/rust-rewrite`
Worktree: `C:/Users/Alberto/.codex/worktrees/rust-rewrite/tsw_io`
Date: 2026-10-24

This report covers the AppServices and Tauri integration slice. It does not claim full application rewrite parity.

## Delivered

### Storage and AppServices

- `Database::open_full` creates canonical full-v2 only for a fresh empty path. Fresh databases receive the explicit `rust_schema_migrations` baseline row `(version=2, name='rust-full-v2-fresh')`.
- Full-v2 admission accepts either that fresh baseline with an empty Ecto `schema_migrations` ledger, or the existing migrated baseline `(version=1, name='ecto-full-to-rust-v1')` with the recognized current Ecto migration versions. Unknown or incomplete ledger metadata is rejected before epoch allocation or writes.
- Bootstrap-v1 data returns `BootstrapUpgradeRequired`. Recognized Ecto databases selected for the Rust runtime return `LegacyUpgradeRequired`. Neither is upgraded automatically; existing profile/settings data remains intact. The already reviewed explicit migration API and recoverable backup behavior remain separate.
- `AppServices::open_full` owns a canonicalized adjacent `.runtime.lock` file, and the shared `Database` worker holds an exclusive identity-keyed lock from writable admission until the connection closes. The database identity uses volume/file index on Windows and device/inode on Unix, so aliases share ownership even when their paths are in different directories. Legacy query-only readers release the identity lock after schema recognition.
- Startup advances a durable checked-u64 epoch in a single database transaction and resets topic revisions. Epoch exhaustion refuses startup. Consent, API-key and simulator-URL changes commit their setting and settings revision together; revision exhaustion rolls the setting change back.
- Settings, configuration and train snapshots read their database values and topic metadata through one serialized storage-worker request. Configuration rows validate the positive signed-32-bit `ConfigId`; train rows include stored identifiers and element counts.
- Simulator API key resolution honors an explicitly configured file path, otherwise checks TSW7 before TSW6 under the OS Documents directory. A stored manual key takes precedence over a file key. UI snapshots contain only the configured flag. Simulator URLs are validated as HTTP or HTTPS URLs without credentials, query strings, or fragments.

### Tauri Rust trial

- The default Cargo feature set and `tauri.conf.json` remain on the legacy distribution. The explicit `rust-ui` feature selects the static `tauri/ui/dist` frontend and removes legacy sidecar/resource requirements from that trial build configuration.
- The Rust trial selects `%APPLOCALDATA%`/the platform app-local data directory under `rust-trial/trenino.db`, or an absolute explicit `TRENINO_RUST_TRIAL_DB` override. It never selects the legacy database by default and does not start the BEAM backend.
- Registered commands: `ui_get_settings`, `ui_list_configurations`, `ui_list_trains`, `ui_set_consent({ value })`, `ui_subscribe({ topic, subscription_id })`, `ui_get_snapshot({ topic })`, and `ui_unsubscribe({ topic, subscription_id })`.
- Database commands run on Tauri’s blocking worker pool. Snapshots use the shared `UiSnapshot` DTO wire format and decimal-string epoch/revision fields. Settings, hardware/configuration-list and train snapshots are supported; bindings, scripts and firmware snapshots return a sanitized unavailable failure.
- Subscriptions are keyed by window label and observer ID, idempotent for the same topic, cannot be rebound to another topic, and are removed on window destruction. Events use `ui://change/{topic}` and are sent only to windows registered for that topic. Consent events publish after the storage transaction commits; listener failure does not cancel the write.
- The tracked Tauri ACL and desktop schema outputs were refreshed by the feature build for the existing optional updater/dialog plugins.

### Shutdown and updater

- Added `ShutdownCoordinator` with required participant methods for stop-admission, cancel/join producers, neutralize/release outputs, and close ports/network. There are no default-success methods. It calls the database-close callback only after all registered participants finish; failures preserve later resources and allow a retry with the same participants.
- Tauri stops new command admission, runs the coordinator, waits for in-flight commands, then drops AppServices and its database lock last. Exit is prevented on cleanup failure. The current AppServices integration has no hardware, network, or simulator producer registered, so it acknowledges only its real database resource.
- The signed native Help → Check for Updates path remains enabled through `desktop-updater`. For the Rust trial it still checks/downloads before quiescence and installs only after the Rust shutdown coordinator succeeds. The legacy default updater path is unchanged. No updater install was executed.

## Verification evidence

- `cargo test -p trenino-runtime` — passed: 3 unit tests and 96 integration tests across the shared runtime suite, including 13 AppServices tests for full-v2 creation/reopen, unknown-ledger refusal, legacy/bootstrap refusal, database-backed lists, revision/epoch overflow, DB-path ownership and concurrent consent revisions, plus 3 lifecycle order/failure/retry tests.
- `cargo test -p trenino-core` — passed: 45 tests, including generated UI DTO and shared core contract coverage.
- `cargo test --manifest-path tauri/src-tauri/Cargo.toml --features "rust-ui desktop-updater"` — passed: 11 tests, including UI adapter wire shape, subscription ownership, trial path selection, shutdown refusal/retry, and updater sequencing/failure.
- `cargo clippy -p trenino-runtime --all-targets -- -D warnings` — passed.
- `cargo clippy --manifest-path tauri/src-tauri/Cargo.toml --features "rust-ui desktop-updater" --all-targets -- -D warnings` — passed.
- `npm --prefix tauri/ui run check` — passed with zero diagnostics.
- `npm --prefix tauri/ui test` — passed: 35 tests across 5 files, including bridge fake-IPC, subscription startup/disposal, event recovery, and error redaction coverage.
- `npm --prefix tauri/ui run build` — passed; generated the static Vite frontend used by the trial build.
- `cargo build --manifest-path tauri/src-tauri/Cargo.toml --features "rust-ui desktop-updater"` — passed on Windows with the static frontend and no legacy backend executable.
- `cargo check --manifest-path tauri/src-tauri/Cargo.toml --no-default-features` — blocked by the absent pre-existing `binaries/trenino_backend-x86_64-pc-windows-msvc.exe` required by the unchanged legacy Tauri configuration. No placeholder executable was staged.

## Remaining gates

- No packaged WebView was launched. The frontend bridge has fake-IPC Vitest coverage and the Rust adapter has a wire-contract test, but no end-to-end IPC smoke test through a running WebView was performed.
- Hardware discovery, configuration confirmation and simulator control are not owned by `AppServices` in this slice. No real device, simulator, port, driver or hardware lifecycle was exercised. Future services must register real shutdown participants before they are exposed to Tauri.
- Configuration/train writes, editors, firmware workflows, bindings, scripts and later screens remain outside this slice. Their unsupported UI snapshot routes return unavailable errors rather than success-shaped placeholders.
- Bootstrap-v1 preservation-aware mapping has not been implemented. Ecto upgrade remains an explicit maintenance action with backup and exclusive startup ownership. No real user database was opened or migrated.
- Linux/macOS native builds, a packaged installer, updater installation, and running a Rust trial against any non-disposable database were not tested.

## Runtime/UI supervisor review round 1 (R1–R6)

The supervisor's six accepted findings were fixed in storage, settings, the Tauri build overlay and Rust trial startup. No other findings from the independent reviews were reopened.

- **R1 ownership:** writable admission now takes a shared OS lock keyed to the opened database file identity. Both `Database::open` and `Database::open_full` use this boundary, including existing full-v2 and bootstrap databases. An alias in another directory resolves to the same identity lock. The Windows implementation uses `GetFileInformationByHandle` from `windows-sys`; Unix uses `MetadataExt` device/inode. The lock handle remains owned by the worker until it drops the SQLite connection. A failed admission returns `AlreadyRunning` before epoch or revision changes. Legacy databases remain query-only and release the lock after recognizing their schema.
- **R2 metadata admission:** `allocate_epoch` permits the fully absent metadata set used by a fresh or migrated full-v2 database. Once any runtime key exists, startup requires the canonical epoch and all six known topic revisions, all encoded as canonical u64 decimal strings and an initialized nonzero epoch. Unknown, partial and malformed state is refused before writes. Tests cover missing epoch, missing revision, malformed epoch, malformed revision, and the existing epoch-overflow/reopen cases. Existing fresh/migrated schema ledger admission and legacy refusal behavior remain unchanged.
- **R3 setting boundary:** `Database::set` now refuses every full-v2 raw mutation, including known settings and reserved metadata. `Settings` named setters route through `set_user_setting`, which uses the validated setting-plus-revision transaction for full-v2 and retains the old bootstrap API. `set_with_revision` only accepts the known settings keys and `settings` topic, validates consent values, HTTP(S) simulator URLs and nonempty API keys, and rejects reserved keys. Tests confirm supported named settings increment revisions while raw, invalid and reserved writes leave the snapshot unchanged.
- **R4 build overlay:** the Rust trial merges its required `frontendDist`, `externalBin`, and `resources` fields into the caller's incoming `TAURI_CONFIG`. Both the Tauri build process and Rust compile environment receive the same merged overlay. A focused test preserves the caller identifier, updater endpoint, build command, bundle target and category while checking the three trial overrides.
- **R5 startup refusal:** database initialization errors no longer become a silent setup failure. Known legacy/bootstrap refusals show a sanitized native OK dialog with backup and explicit maintenance-upgrade guidance; other failures use safe generic text. The dialog uses the asynchronous `show` API from setup, then exits from its callback, so the main thread is not blocked and the normal main window is not created. A pending-dialog flag prevents an exit request from closing the app before the callback; the callback clears it and requests exit. The updater dialog plugin is registered once in each feature path. Injected-presenter tests cover legacy and bootstrap refusal text, and an empty-state shutdown test covers the no-services exit path. No migration runs automatically.
- **R6 portable fixture:** the override-path test now obtains both the default and override paths from `tempfile::tempdir`, retaining a separate relative-path rejection assertion.

Round-1 verification on Windows:

- Regression tests for R1–R3 first failed on the reported behavior. After the fixes, `cargo test -p trenino-runtime --test app_services` passed 17 tests, including same-path direct/full and generic constructor rejection, cross-directory hard-link rejection, metadata preservation, and full-v2 setting mutation guards.
- `cargo test -p trenino-runtime --test foundation` passed 11 tests, preserving bootstrap settings and legacy query-only inspection behavior.
- `cargo test -p trenino-runtime` passed all 121 tests, including migration and hardware/service integration coverage. The migrated full-v2 storage test now asserts raw mutation refusal leaves its value/revision intact, then checks the validated settings API advances exactly one revision.
- `cargo test --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui` passed 14 library tests and the build-overlay integration test.
- `cargo test --manifest-path tauri/src-tauri/Cargo.toml --features "rust-ui desktop-updater"` passed the same 14 library tests and build-overlay integration test. This exercises the updater-enabled registration path without contacting the updater.
- `cargo test --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui trial_database_override_must_be_absolute_and_never_falls_back` passed on Windows with the tempfile-derived paths.
- The R4 and R5 regression APIs were temporarily removed in red-check runs; the build test failed on the missing merge helper and the desktop test failed on the missing refusal dispatcher, respectively. Both were restored and their focused suites pass.
- `cargo clippy -p trenino-runtime --all-targets -- -D warnings` and both Tauri feature variants (`rust-ui`, `rust-ui desktop-updater`) passed strict Clippy.
- `cargo fmt --all --check` passed. `cargo build --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui` and the corresponding `rust-ui desktop-updater` build both passed on Windows.
- A `cargo check` of the Rust trial with a caller-supplied `TAURI_CONFIG` containing a custom identifier, updater endpoint and bundle target passed, exercising the merged overlay through Tauri build/code generation without network access.
- Tauri builds regenerated the untracked `gen/schemas/windows-schema.json`; it is generated build output and was removed after verifying it is not tracked. The final updater-enabled build left the tracked ACL and desktop schema files with no working-tree diff.

This does not close the existing WebView smoke, Linux/macOS verification, packaging, updater-install, hardware lifecycle or application parity gates listed above.

## Runtime/UI R1 fix round 2 — stable cross-process ownership

Fixed the remaining R1 P1 from supervisor re-review `807420e`. Removed the temporary-directory sidecar namespace. Writable admission now locks the opened database identity itself on Unix using `fs2` exclusive file locking (the lock is on the database inode, so hard links share it), and uses a Windows kernel mutex in the `Global\\TreninoRuntimeDb-{volume-serial}-{file-index}` namespace. The mutex name derives from the opened file identity and therefore does not depend on `TMP`, `TEMP`, or `TMPDIR`. On Windows the identity file handle and mutex remain owned by the database worker; on Unix the identity file descriptor owns the lock. Both are held through connection teardown. Legacy read-only recognition explicitly releases ownership after it opens query-only. Failed connection/schema admission drops the guard on the worker thread. Windows mutex acquisition treats `WAIT_ABANDONED` as ownership transfer, allowing the next process to recover after a crashed owner; timeout returns `AlreadyRunning`. Kernel object access follows the process default DACL; the tested desktop case uses two processes under the same user account.

Added `writable_database_owner_is_shared_across_processes_with_different_temp_dirs` and its child probe to `crates/trenino-runtime/tests/app_services.rs`. The test confirms the child process's actual `std::env::temp_dir()` is a different directory, then attempts both the identical DB path and a hard-link alias in another directory. Both child opens must return `AlreadyRunning`. The parent verifies its cached snapshot and SQLite epoch/revision remain at epoch 1/revision 1 after both attempts, then drops the owner and verifies a successor opens and advances to epoch 2. Existing direct-open and in-process hard-link regressions remain.

TDD evidence: before the storage change, the targeted subprocess regression failed because the child opened the DB under a different temporary-directory lock root; the test assertion reported that `Database::open_full` did not return `AlreadyRunning`. After the change, it passed and exercised both same-path and hard-link probes plus owner release/reopen.

Focused Windows verification:

- `cargo test -p trenino-runtime --test app_services` — passed, 19 tests (including same-path/direct-open/hard-link and cross-process TMP/TEMP/TMPDIR cases).
- `cargo test -p trenino-runtime --test foundation` — passed, 11 tests, including legacy query-only admission.
- `cargo clippy -p trenino-runtime --all-targets -- -D warnings` — passed.
- `rustfmt --edition 2021 --check crates/trenino-runtime/src/storage/mod.rs crates/trenino-runtime/tests/app_services.rs` — passed.
- `git diff --check -- crates/trenino-runtime/src/storage/mod.rs crates/trenino-runtime/tests/app_services.rs crates/trenino-runtime/Cargo.toml` — passed (Git emitted its existing CRLF-to-LF notice for Cargo.toml only).

A workspace-wide `cargo fmt --all --check` was attempted while sibling firmware files were changing; it reported formatting differences in the firmware-owned catalog/http/downloads files. I did not format those files in this round. No database migration, actual user database, GUI, hardware, installer, secrets, or commit was used. Unix runtime behavior is implemented using inode-scoped `flock` via `fs2`; this Windows-only environment did not execute the Unix branch, so Linux/macOS test coverage remains a platform gate.

R1 round-2 RED/GREEN command detail: `cargo test -p trenino-runtime --test app_services writable_database_owner_is_shared_across_processes_with_different_temp_dirs -- --exact --nocapture`. Before the ownership change, it exited 101 with the parent assertion `child probe failed`; the child test failed its `AlreadyRunning` assertion, demonstrating admission under the changed temp root. After the fix, the focused subprocess regression passed; the final complete `app_services` run passed 19/19, including the expanded hard-link and successor-owner assertions.
