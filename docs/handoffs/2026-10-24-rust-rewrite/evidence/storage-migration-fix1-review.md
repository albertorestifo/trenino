# Storage migration fix round 1 review

Verdict: CHANGES REQUESTED — five of the six original findings are addressed, but the backup-path protection remains incomplete and can corrupt the source on failure.

Reviewed storage changes in 418de17..235a544, HEAD 235a544de225a3c54a3edc535037265d4993ba2b. This was a scoped fix review; no new child reviews, implementation edits, or commits. No user/application database, hardware, simulator, or installer was accessed. The only new execution was a disposable-fixture probe for the modified backup path guard. Root's 96 passing workspace tests, strict workspace clippy, and fmt are accepted as supplied integration evidence; they were not redundantly rerun here.

## Remaining actionable finding

**P1 — Check backup-side auxiliary paths as well as source-side auxiliary paths.** `crates/trenino-runtime/src/storage/migration.rs:237-250` compares the destination only against the source and its three sidecars. It never checks whether the destination's own journal/WAL/SHM filename aliases the source or a source sidecar.

Concrete public-API probe on the current fix, using only a new tempfile current fixture in DELETE mode:

- source: `<temp>/backup.db-journal` (a valid, populated source SQLite database)
- backup destination: `<temp>/backup.db` (initially nonexistent)
- result: `Err(Backup { detail: "database error: not an error" })`
- source still exists, but its bytes changed; destination was removed by backup-error cleanup
- reopening the source and running either PRAGMA integrity_check or PRAGMA user_version returns SQLITE_NOTADB ("file is not a database")

The backup operation uses `<destination>-journal`, which is the source file in this case. This is the inverse of the original journal-name defect and directly concerns the incomplete fix to finding 1. It breaks the stronger failure guarantee: the source is corrupted and no backup survives.

**Required repair:** Before opening/creating backup-related files, build normalized, platform-aware path sets for both databases: each main path plus `-journal`, `-wal`, and `-shm`. Refuse any intersection, applying the existing canonical-parent/case/alias handling in both directions. Do not rely on a SQLite error to protect the source.

**Required regression:** Create a valid current fixture at `backup.db-journal`, request `backup.db`, and require InvalidBackupPath with byte-identical source, no destination, successful source integrity_check, and legacy user_version. Add reverse `-wal` and `-shm` cases and case/canonical-directory aliases where supported; retain the forward-sidecar, relative-path, and normal-backup tests. Probe source retained at `.superpowers/sdd/2026-10-24-rust-rewrite/storage-supervisor-probe/fix1_reverse.rs`.

## Per-finding disposition

1. **Backup/source sidecar collisions — partially fixed, remains blocked by P1 above.** The original forward `source.db` -> `source.db-journal` case is rejected before mutation, along with WAL/SHM and Windows case variants. `create_new` still protects existing destinations. The symmetric collision must also be refused.

2. **Pre-reservation schema admission race — addressed.** The IMMEDIATE transaction is now acquired at migration.rs:174 before reading header, exact schema/version inventories, FK checks, or domain data; snapshot creation follows these checks. `validate_full_schema` also now enforces the retained Ecto inventory. The deterministic unit hooks exercise a writer's committed future ledger row before reservation, refusal without backup, and an ordinary committed setting appearing in source and backup. The hooks deliberately bracket the reservation boundary rather than assert actual scheduler timing while waiting inside SQLite. Source inspection establishes that all admission reads are under the reservation.

3. **Bare relative backup filenames — addressed.** Empty parents are mapped to '.', then canonicalized. The normalized destination is used for creation and alias checks. The public regression covers successful bare-relative migration and refusal of relative source/sidecar aliases. The remaining symmetric issue is accounted for solely under finding 1.

4. **Historical fixture toolchain provenance — addressed.** `generate_v074_pinned.ps1` extracts both tagged mix.lock and migration sources into a unique temp project; dependencies and build are isolated. Its Ecto helper requires exactly 36 migrations ending 20260503114723. I inspected the retained successful run at `C:/Users/Alberto/AppData/Local/Temp/trenino-v074-pinned-e84ef28ddfbb41aea5b5ae83f9bf83ef`: compiled application metadata records Ecto/Ecto SQL 3.13.5, ecto_sqlite3 0.22.0, and exqlite 0.33.1. That run's ecto-v074.sql is byte-identical to the committed fixture (SHA256 A3CDEE3C8F08ECFFDFC075679D63AFD2CDB2FF338FD0204ECC1CA0859CB78127; no-index diff exited 0). The historical schema fingerprint has no diff across the reviewed commits. Together with the generator execution evidence, this closes the original exact-DDL compatibility gap. Timestamp normalization affects disposable fixture rows only.

5. **Current trains missing their last identifier — addressed for migration admission.** `validate_legacy_data` checks NOT EXISTS of identifiers under the reservation, returning InvalidLegacyData before backup or mutation. The regression removes the current fixture's sole identifier and asserts refusal/no backup/no invented identifier. Future typed train repositories must still enforce the invariant on ordinary edits; that is the already-tracked integration work.

6. **Malformed JSON — addressed at the requested admission boundary.** Under the same transaction, scripts.triggers is parsed as a JSON array of strings, and non-NULL I2C params as a JSON object. SQL NULL remains accepted for nullable params, payload strings are not rewritten, and errors identify table/column/row without echoing contents. This matches the relevant stored representations in the legacy TriggersType and I2C polymorphic embed. Tests cover malformed text refusal/no backup/payload redaction and valid nullable/array preservation. This is syntax/top-level-shape validation, not a claim that all future typed domain field validation exists.

## Other requested fixes and regression coverage

- Both needless SQL borrows were removed; root's strict workspace clippy passes.
- Rustdoc now states that migration blocks, must run on an exclusive startup owner before ordinary workers/legacy writers, and requires no active Database handles.
- Moving identifier rejection ahead of backup no longer masquerades as the rollback test: a separate injected post-upgrade failure now checks full source fingerprint rollback and an independently openable original backup.
- Added assertions preserve script code/triggers/timestamps, I2C metadata/timestamps, related IDs, and a legitimate deleted AUTOINCREMENT high-water mark of 500 followed by allocation of 501.
- The original bounded-slice limits remain unchanged: fresh full-schema creation/bootstrap upgrade, full repositories and routing transactions, lifecycle integration, and crash/disk-full/process-level recovery are still release gates.

Return the remaining symmetric-path P1 to the cheap storage coder for a narrow follow-up and regression test. Re-review that fix before accepting the migration slice. Do not repeat pinned fixture generation or the five closed investigations unless the follow-up changes them.
