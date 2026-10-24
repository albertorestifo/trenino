# Storage migration fix round 2 review

Verdict: ACCEPTED for the bounded storage migration slice at commit 3da51945034b860ed0634324c9b53ff95a08ea15. The remaining symmetric backup-path P1 is closed. The five findings accepted in fix round 1 remain closed; they were not re-audited.

## Scoped disposition

Reviewed `storage-migration-fix2-review.diff` (235a544..3da5194), the appended round-2 evidence, and the prior fix-round report. `conflicts_with_source_or_sidecar` now compares complete source and destination path families. Each contains the main filename and `-journal`, `-wal`, and `-shm`; every member uses canonical-parent/existing-path normalization and the existing platform comparison key. Any intersection returns InvalidBackupPath before either SQLite connection is opened or any backup file is created. This addresses the previously demonstrated inverse collision as well as preserving the forward guard.

The new public-API regression covers source names `backup.db-journal`, `backup.db-wal`, and `backup.db-shm` against destination `backup.db`, including a `.` parent alias and Windows case variants. It asserts refusal, absent destination, byte-identical source, successful integrity_check, and retained legacy version. Existing normal/relative/WAL-backup tests remain in place. No further actionable regression was found in this narrow fix.

## Verification evidence

Supervisor reran the original destructive-case scratch probe against the rebuilt runtime using a newly generated tempfile fixture, with source `backup.db-journal` and destination `backup.db`. Actual output:

```
result=Err(InvalidBackupPath)
source_exists=true backup_exists=false
source_unchanged=true
source_integrity=Ok("ok")
source_version=Ok(0)
```

The same probe previously returned a backup failure after corrupting the source to SQLITE_NOTADB. This rerun confirms the repaired public behavior directly. The scratch executable is `storage-supervisor-probe/fix2_reverse.exe`; it reuses `fix1_reverse.rs` without implementation changes.

`git diff --check 235a544..3da5194` for the two storage files passed, and those files have no uncommitted modifications. Concurrent controls/UI edits elsewhere were left untouched. Coder-reported validation is 13 storage migration tests, 3 migration unit tests, and strict package clippy passing; these suites were not redundantly rerun by the supervisor.

## Acceptance boundary

All six original migration-review findings are now addressed, including the inverse collision discovered in fix round 1. Acceptance covers the explicit supported-Ecto migration primitive and its bounded evidence. Previously tracked release gates remain: fresh full-schema/bootstrap upgrade policy, domain repositories/routing, lifecycle ownership and legacy-writer exclusion, and crash/disk-full/process-level recovery. This is not authorization to migrate a real user database or a claim that those integration gates are complete.

No implementation edits, commits, child reviews, production/user database access, hardware, or installer execution during this review.
