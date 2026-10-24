# Foundation fix round 1 scoped re-review

Reviewed commit: 605c577
Scope: the five prior findings and new breakage in the fix diff only. No implementation edits, no child reviewers, no real database/hardware access. Prior migration, path/startup, and automatic key-discovery caveats remain deferred.

## Verdict

**Changes requested: four findings ADDRESSED; writable schema admission NOT ADDRESSED.** The refactor substantially improves readability and the other contract fixes match their regression tests.

| Prior finding | Status | Evidence |
| --- | --- | --- |
| 1. Root workspace exclusions | ADDRESSED | Cargo.toml:3 explicitly excludes all three original manifests and vendor/vjoy; report records all metadata commands passing. |
| 2. Malformed Rust schema writable admission | NOT ADDRESSED | The new fingerprint has two concrete bypasses described below. |
| 3. Checked ConfigId deserialization | ADDRESSED | shared.rs:48 deserializes u32 then invokes ConfigId::new; foundation tests cover zero, negative, overflow, i32 upper-bound overflow, and valid endpoints. |
| 4. Duplicate hardware ConfigId | ADDRESSED | hardware/mod.rs:5 re-exports crate::ConfigId; shared_contracts.rs passes the root type directly to build_configuration and verifies its wire value. |
| 5. Structured worker errors | ADDRESSED | storage/mod.rs:87 transports StorageError; SQLite extended constraint codes map to Conflict/ForeignKey/Constraint, missing delete returns NotFound, and recovery tests exercise later successful writes. |

Readability request: ADDRESSED. Database opening, schema operations, request dispatch, and transactions are now conventional helpers instead of a minified closure.

## Remaining P1: schema fingerprint can accept a different schema

### A. Lossy SQL normalization erases constraint semantics

Location: crates/trenino-runtime/src/storage/mod.rs:311-316 (comparison at line 304).

normalize_schema removes all whitespace and double/backtick quoting, then uppercases. These two SQLite CREATE statements normalize to the same value:

    CREATE TABLE profiles(id INTEGER PRIMARY KEY,name TEXT NOT NULL UNIQUE)
    CREATE TABLE profiles(id INTEGER PRIMARY KEY,name "TEXT NOT NULL UNIQUE")

The second declaration treats TEXT NOT NULL UNIQUE as a quoted type name; it has neither constraint. A focused disposable in-memory SQLite probe confirmed:

- schema_normalization_equal: True
- PRAGMA table_info: name has declared type TEXT NOT NULL UNIQUE, notnull=0
- PRAGMA index_list(profiles): empty
- two duplicate names and a NULL insert all succeed

With the other two canonical tables and matching header, the fix's validation therefore accepts this malformed database as writable. Whitespace removal is itself lossy even without quotes: token boundaries must not be discarded.

Fix: for this deliberately exact bootstrap schema, compare preserved canonical SQL strictly, or validate schema structurally with table/index/FK metadata and a safe policy for unexpected objects. Do not remove SQL quote/token boundaries. Add quoted-type and collapsed-token fixtures to storage_admission.rs and verify refusal without mutation.

### B. Object filter mistakes an SQL wildcard for a literal underscore

Location: crates/trenino-runtime/src/storage/mod.rs:278 (and shared admission filter at line 259).

name NOT LIKE 'sqlite_%' excludes legal user object names such as sqlitex_foreign, because underscore matches any single character. A focused in-memory SQLite probe created CREATE TABLE sqlitex_foreign(payload TEXT); it appears in sqlite_master but the exact admission query returns no objects. A valid stamped schema with such an extra table or trigger bypasses the promised unexpected-object refusal. The same filter can treat a foreign unstamped database containing only such an object as empty.

Fix: match the literal sqlite_ prefix, for example with an appropriately escaped LIKE or a case-appropriate prefix comparison/GLOB; use the same correct predicate in fresh admission, existing schema validation, and test inspection. Add a legal sqlitex_foreign table or trigger regression, including refusal with unchanged schema/data.

## Verification boundary

Read foundation-report.md appended fix evidence and foundation-fix1-review.diff, plus current storage/shared/hardware sources. Existing report records 26 passing tests, fmt/clippy success, and standalone metadata success; no redundant broad reruns were performed. Only the two new in-memory SQLite semantic probes above were run. They used bundled Python sqlite3 and did not touch user data or repository source files.

After the narrow schema correction, rerun the new regression tests and appropriate workspace checks, then request a scoped admission re-review. No need to reopen the four accepted findings.
