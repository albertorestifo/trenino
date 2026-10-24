# Storage migration implementation report

## Delivered

- `Database::open` still creates/opens the existing small Rust bootstrap schema as version 1. It recognizes only exact migration-produced v0.7.4 and current Ecto fingerprints as query-only legacy databases; it never migrates implicitly.
- `Database::migrate_legacy(source, backup)` is an explicit upgrade API. It supports only the actual v0.7.4 baseline at migration 20260503114723 and the current baseline at 20260927000000. Admission checks the complete `sqlite_master` object set, exact Ecto migration version rows, zero `application_id`/`user_version`, and foreign-key integrity. Extra, missing, modified, incomplete, unknown, or newer schemas are refused before backup or writes.
- Migration takes an IMMEDIATE SQLite writer reservation, creates a non-overwriting SQLite Backup API snapshot from a separate read-only source connection (including WAL-committed content), then applies and validates the transformation in one transaction. The backup is retained if a data transformation fails; source changes roll back. Backup lock retries are bounded to 30 seconds.
- v0.7.4 train identifiers are trimmed into `train_identifiers`, blank values and trim collisions are refused, and existing train primary keys and related entity rows remain intact. The current source preserves existing train identifiers and all I2C/display/joystick data. Existing joystick configuration/mapping rows are copied into the target 1..16 device-index checks; the singleton config remains row 1 and no rows are seeded for devices 2..16. Partial axis/button uniqueness rules remain in place.
- The resulting full schema is version 2 and has a separate `rust_schema_migrations` ledger. Ecto `schema_migrations` rows remain intact; the five post-v0.7.4 migration versions are added when migrating that baseline.
- The old foundation read-only test now uses the migration-produced current fixture. Its separate malformed four-table test continues to confirm that a plausible-looking incomplete schema is rejected.

## Fixture provenance

`crates/trenino-runtime/tests/fixtures/storage/` contains the v0.7.4 and current SQL dumps plus a regeneration script. `generate.ps1` extracts the real tagged migration directory using `git archive`, then runs the 36 tag migrations and 41 current migrations into new `%TEMP%` databases. It inserts deterministic, representative linked data and exports data dumps and `sqlite_master` fingerprints. The current and v0.7.4 static schemas under `crates/trenino-runtime/src/storage/schema/` are thus derived from actual Ecto migration output, not reconstructed by hand. The generated tag data includes no I2C rows because those tables did not exist in v0.7.4.

## Scope limits

- No actual application database was opened or changed; all migration execution used uniquely named disposable databases.
- Only the exact v0.7.4 and current Ecto schemas are supported. Earlier intermediate Ecto migration versions, customized schemas, and future migration versions are intentionally refused.
- This slice migrates SQLite storage and keeps settings/profile compatibility queries only. It does not add full domain repositories or runtime service migration.
- The caller must invoke the explicit migration while application writers are quiesced. The SQLite reservation blocks concurrent writers during snapshot and transformation; this API does not coordinate app lifecycle processes on its own.

## Validation

Passed on the Windows worktree:

- `cargo test -p trenino-runtime --test storage_migration` — 7 tests.
- `cargo test -p trenino-runtime --test foundation` — 11 tests.
- `cargo test -p trenino-runtime --test storage_admission` — 4 tests.
- `tests/fixtures/storage/generate.ps1` — regenerated both fixture databases from the actual tag/worktree migration directories and reproduced SQL/schema exports.

The workspace has concurrent, unrelated core/runtime/joystick changes. Package-wide and workspace-wide checks were not used as a cleanliness claim for this isolated storage slice.

## Fix round 1 evidence (2026-10-24)

Closed all six supervisor findings in the storage migration slice:

- Backup paths are normalized against canonical parents (including an empty parent for bare filenames) and compared with the source plus `-journal`, `-wal`, and `-shm` names. Windows comparison folds case and trailing dot/space aliases before exclusive backup creation. Tests cover DELETE-journal source sidecars, relative backups, and relative source/sidecar aliases. The WAL backup test independently reopens the snapshot and reads both pre-upgrade domain data and a committed WAL setting.
- Schema/header/ledger/FK and migration-data admission now run only after acquiring `BEGIN IMMEDIATE`, before backup creation. Deterministic reservation-boundary tests commit a future Ecto ledger version and a separate settings write before the migration can acquire the reservation. The unknown inventory is refused without a backup; the data write appears in both upgraded source and backup.
- Current-schema trains without identifiers refuse before backup. Legacy blank/colliding identifiers also refuse pre-backup. JSON checks reject invalid/non-domain values in `scripts.triggers` and `device_i2c_modules.params` with typed `InvalidLegacyData` details naming only the field and row. SQL `NULL` remains valid for nullable I2C params; valid trigger arrays and structured params retain their exact text.
- An injected post-transformation failure test confirms the IMMEDIATE transaction rolls back the source and leaves a usable, independently openable pre-upgrade backup. Train IDs, related IDs, script fields/timestamps, I2C fields/timestamps, and a deleted train AUTOINCREMENT high-water mark (500, next allocated ID 501) are checked.
- `validate_full_schema` now enforces the exact retained current Ecto version inventory in addition to the Rust migration ledger, schema fingerprint, and FK check. Rustdoc states migration blocks the caller and requires exclusive startup before ordinary database workers/legacy writers, with no active `Database` handles.
- Two needless SQL argument borrows were removed.

Historical evidence now uses `generate_v074_pinned.ps1`: it archives the actual v0.7.4 `mix.lock` and 36 tagged migration modules, creates a minimal project under a unique temp directory, and uses isolated temp `MIX_DEPS_PATH`/`MIX_BUILD_PATH`. The run selected Ecto 3.13.5, Ecto SQL 3.13.5, ecto_sqlite3 0.22.0, exqlite 0.33.1, DBConnection 2.9.0, Decimal 2.3.0; it executed 36 migrations through `20260503114723`. `generate_fixtures.py` populated deterministic rows and exported the DDL. `git diff --exit-code -- crates/trenino-runtime/src/storage/schema/ecto-0.7.4.sql` passed, establishing byte-identical historical DDL. The dependency cache and build were isolated under `%TEMP%`; no application database was touched.

Fix-round validation on the Windows worktree:

- `cargo test -p trenino-runtime --lib storage::migration::tests` — 3 passed.
- `cargo test -p trenino-runtime --test storage_migration` — 12 passed.
- `cargo test -p trenino-runtime --test foundation` — 11 passed.
- `cargo clippy -p trenino-runtime --all-targets -- -D warnings` — passed.
- `rustfmt --edition 2021 crates/trenino-runtime/src/storage/migration.rs crates/trenino-runtime/tests/storage_migration.rs` — passed.

Remaining release gates from the original report still apply: bootstrap-v1 to full-v2 policy, domain repositories, lifecycle ownership and legacy-writer quiescence, crash/disk-full backup testing, and destination auxiliary-file cleanup under injected backup failures. This round does not claim those features.

## Fix round 2 evidence (2026-10-24)

Closed the symmetric backup-side sidecar collision found in `storage-migration-fix1-review.md`. Before opening a SQLite connection or creating any backup file, migration now builds normalized path families for both source and destination, each containing the main filename and its `-journal`, `-wal`, and `-shm` siblings. Every family member canonicalizes its parent and canonicalizes an existing member; Windows path keys fold case and trim trailing dots/spaces. Any intersection returns `InvalidBackupPath`.

The new public-API regression first failed on the prior guard, then passed after the fix. It places a valid DELETE-mode Ecto fixture at each of `backup.db-journal`, `backup.db-wal`, and `backup.db-shm`, and requests `backup.db` through a `.` parent alias. For every case it asserts `InvalidBackupPath`, absent destination, byte-identical source, successful `PRAGMA integrity_check`, and unchanged legacy `user_version`. A Windows-only case covers case-insensitive reverse collision (`BACKUP.DB-JOURNAL` source, `backup.db` destination); the Windows worktree executed this case. Existing forward source-sidecar, bare-relative, normal absolute/relative backup, backup reopening, and WAL snapshot tests remain.

Fix-round-2 validation:

- Red/green: `cargo test -p trenino-runtime --test storage_migration rejects_destination_sidecar_paths_that_alias_the_source` failed before implementation and passed afterward.
- `cargo test -p trenino-runtime --test storage_migration` — 13 passed.
- `cargo test -p trenino-runtime --lib storage::migration::tests` — 3 passed.
- `rustfmt --edition 2021 crates/trenino-runtime/src/storage/migration.rs crates/trenino-runtime/tests/storage_migration.rs` — passed.
- `cargo clippy -p trenino-runtime --all-targets -- -D warnings` — passed.
