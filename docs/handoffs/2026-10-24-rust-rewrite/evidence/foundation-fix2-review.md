# Foundation fix round 2 scoped re-review

Reviewed commit: db68889
Scope: the remaining writable-schema admission finding and new breakage in this fix only.

## Verdict

**ADDRESSED.** Both round-one schema-admission bypasses are closed. No new actionable regression was found in this narrow diff. Together with the four findings accepted in foundation-fix1-review.md, all five initial foundation review findings are addressed for the explicitly bounded first slice.

| Remaining issue | Status | Evidence |
| --- | --- | --- |
| SQL normalization loses quote/token semantics | ADDRESSED | validate_rust_schema now compares preserved sqlite_master.sql directly to canonical DDL; normalize_schema is removed. The quoted type and collapsed-token fixtures now require UnsupportedSchema. |
| LIKE wildcard hides legal sqlitex objects | ADDRESSED | Both count_user_objects and validate_rust_schema use name NOT GLOB 'sqlite_*', where underscore is literal. Stamped and unstamped sqlitex_foreign fixtures require refusal; the unstamped test verifies the old row remains and no bootstrap table is created. |

Exact textual DDL acceptance is intentionally strict for this separate Rust bootstrap schema. Semantically similar externally rewritten DDL can be refused; this is consistent with the chosen supported-schema boundary. Existing canonical-schema reopen coverage preserves the intended supported path.

## Evidence and limits

Read the appended round-two foundation-report.md and foundation-fix2-review.diff. Regression coverage includes malformed constraints, quoted/collapsed types, unexpected user objects, refusal checks, and valid reopening. The coder records: focused storage_admission 4 tests passed; workspace 27 tests passed; fmt and clippy passed. These results were reviewed as reported evidence; no redundant suite reruns were performed.

No implementation edits, new reviewers, real database access, or hardware access occurred during this re-review. Previous migration, exhaustive Ecto fingerprint, startup/path creation, full repository/runtime, and automatic API-key discovery limitations remain deferred; this acceptance does not represent full rewrite completion.
