# Independent adversarial review: storage migration `63b1a1c`

Scope: reviewed the storage brief/report/diff, `migration.rs`, `storage/mod.rs`, migration-produced schema/fixture SQL, current Ecto migrations, and the Rust platform plan. I did not read the supervisor or other reviewer reports before forming these findings. The probes below used only new databases under `%TEMP%` loaded from the checked-in current fixture and a temporary Rust CLI calling the public `Database::migrate_legacy`; no app/user database or production process was opened. No implementation file was changed. Existing workspace tests were reported passing by the supervisor, so I did not rerun them.

## Findings

### P0 — A reserved SQLite journal filename can make migration report a backup that no longer exists

`migration.rs:186-197` rejects only an exact source pathname, and `:199-213` creates any other nonexistent backup name. In rollback-journal mode, `<source>.db-journal` is SQLite's live rollback file. A disposable current-schema fixture with `PRAGMA journal_mode=DELETE`, migrated with backup path `<source>.db-journal`, returned `Ok(MigrationReport { ... })` and printed `backup_exists=false`. The upgraded source had `user_version=2` and `PRAGMA integrity_check='ok'`; the requested recovery copy had been consumed/deleted by SQLite's journal lifecycle. The same probe accepted `<source>.db-wal` and `<source>.db-shm` in DELETE mode; these reserved names can collide with a later journal-mode change. A successful migration therefore violates the required recoverable, non-overwritten backup guarantee.

Regression requirement: reject source sidecar names (`-journal`, `-wal`, `-shm`, and relevant SQLite auxiliary names) including aliases/case variants before creating anything; take a backup only at a path whose SQLite auxiliary paths cannot alias the source or its sidecars; verify backup exists, passes `integrity_check`, and contains the pre-upgrade data before reporting success. Add a rollback-journal fixture test using `<source>-journal` and WAL/SHM reserved-path cases.

### P1 — Schema admission is stale after waiting for a concurrent writer

`migration.rs:147-154` fingerprints and checks migration versions before `BEGIN IMMEDIATE` at `:156-158`; it never repeats admission inside that transaction. I held a WAL writer with `BEGIN IMMEDIATE`, inserted future Ecto version `20269999000000` but did not commit, and started `migrate_legacy` against a disposable current fixture. The migration read the old committed version set, waited at the writer reservation, then proceeded after I committed. It returned `Ok`, set `user_version=2`, and retained the future `schema_migrations` row. This directly defeats the newer-schema refusal and can also admit an altered schema or data written during the wait. `validate_full_schema` at `:275-286` checks only the target object fingerprint, Rust ledger, and foreign keys, not the source Ecto ledger.

Regression requirement: acquire the writer reservation before admission, then read fingerprint, version ledger, and integrity checks under that reservation; or revalidate them after obtaining it and before backup/transformation. Test with a blocked WAL writer that commits a future migration row, and assert refusal with no backup and no source mutation.

### P1 — Malformed JSON migrates successfully

Admission at `migration.rs:252-272` checks DDL, Ecto version rows, and foreign keys; `apply_upgrade` at `:342-367` does not validate domain payloads. I set `scripts.triggers='{'` and `device_i2c_modules.params='{'` in a disposable current fixture. Migration returned `Ok`; both invalid JSON strings survived in the v2 database. The platform plan's storage acceptance list explicitly includes malformed JSON (`docs/superpowers/plans/2026-10-24-rust-platform.md:54`), and the review brief calls for malformed rejection without source writes.

Regression requirement: validate each JSON-bearing column against the intended domain representation before backup or source writes, with a named error for bad rows; add malformed triggers/I2C JSON fixture cases. If some fields intentionally allow arbitrary text, specify that exception and test the actual read path instead.

### P2 — SQLite sequence metadata is outside the fingerprint and can leave an unusable migrated DB

`schema_objects` at `migration.rs:302-317` excludes all `sqlite_*` objects, so admission and `validate_full_schema` ignore `sqlite_sequence` content. In a disposable current fixture I set the `trains` sequence to `9223372036854775807`. Migration returned `Ok`, preserved that value, and the next ordinary insert into `trains` failed `database or disk is full` (`SQLITE_FULL`) although the table had ample space. This is a malformed source metadata case rather than a normal upgrade failure, but it means the migration reports a usable full schema without checking ID allocation integrity.

Regression requirement: validate each AUTOINCREMENT sequence against table IDs and safe allocation bounds, or run a targeted transactional insert/rollback check before reporting success. Add a fixture with exhausted or malformed `sqlite_sequence` metadata. Do not reset legitimate high-water marks when checking them.

### P1 residual integration gap — no lifecycle ownership prevents old app writes

`Database::migrate_legacy` is a static path API (`migration.rs:117-125`) and only owns a SQLite IMMEDIATE transaction during the snapshot and transform. `Database::open` owns independent worker connections (`storage/mod.rs:149-183`, `:265-303`); no migration admission gate or app-level writer shutdown is part of this slice. An old process can resume writes after commit. The implementation report already calls this out as a scope limit, while the platform plan requires preventing concurrent old/new application writers (`docs/superpowers/plans/2026-10-24-rust-platform.md:50`). This is an integration release blocker, not a claim that the storage transaction alone can solve cross-process ownership.

Regression requirement: wire a single-owner lifecycle gate around migration and service startup, keep legacy writers quiesced through the switch, and test a second process attempting to write before/during/after migration. The storage API should express or enforce ownership rather than relying only on a caller convention.

## Checks that held, and limits

The exact `sqlite_master` object-map comparison includes named tables, indexes, triggers, and views, so extra/custom triggers and views are refused by the current admission check. The fixture-derived DDL fingerprints are strict. Existing backup paths use `create_new` and were observed to remain untouched by the supplied test; a normal backup includes WAL-committed data. The transformation is wrapped in a SQLite transaction and existing tests cover rollback on a rejected train identifier. The probes above do not establish behavior under power loss/full disk, backup-step errors, or active long-lived readers; those remain required fault and lifecycle gates before deployment. In particular, `create_backup` removes only the main destination on error (`migration.rs:240-249`), so fault-injected failure should verify auxiliary files and the source remain recoverable.
