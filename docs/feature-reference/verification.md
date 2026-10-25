# Documentation verification

Source reviewed: `master` commit `188f35e4108733358730e92ebd98f1912af5173a`, 2026-10-25. Publication destination: `codex/rust-rewrite`. These are different roles: the destination code was not inspected or evaluated.

The final machine-readable result is [coverage/verification.json](coverage/verification.json).

## Checks performed for this documentation change

- Pulled the original checkout from origin with fast-forward-only policy; already current at the reviewed SHA.
- Three domain subagents reviewed disjoint scopes of 88, 68 and 105 files; the primary reviewer covered the 269-file platform/support scope. [Coverage levels](coverage/README.md) distinguish source/test review from historical outline, generated/dependency and binary/vendor inventory.
- Cross-reviewed architecture/data/desktop/joystick/rewrite chapters against domain sources. Corrected overbroad claims about heartbeat fields, Configure outputs, session ownership, Lua trigger types, lever coalescing, disconnect cleanup, consent failures, UI acknowledgment filtering and initial joystick-enable failures.
- Checked every baseline path appears exactly once in combined coverage, each scope matches its review, and all assigned feature documents exist.
- Verified committed source blob identifiers and SHA-256 for all 530 baseline paths. Concurrent unrelated source edits and untracked work were excluded from this snapshot.
- Checked local Markdown links and anchors, and baseline-pinned source links against tracked paths. External URLs were not fetched: immutable source URLs were validated against local Git objects, not live browsing.
- Counted 125 unique user stories, 32 feature catalogue entries, 27 current schema declarations (26 persistent plus one embedded), all 41 migrations, and 47 MCP tool declarations against the corresponding source inventories.
- Checked the candidate commit's changed paths are confined to `docs/feature-reference/`, with no deletions, application changes or unrelated untracked files included; publication uses the requested branch without switching this checkout or inspecting that branch's code.

## What this verification does not claim

No application code was changed by this task. Application test suites were read as evidence but were not rerun for this documentation-only change. No firmware was flashed, serial hardware operated, simulator controls changed, keys injected, drivers installed/configured, installer executed, secrets uploaded or app update installed. A cited existing test is not a newly passing run. Physical integration and release-certification checks remain distinct from documentation integrity.

Some current tests use fake adapters, locally reproduced comparator logic or context-only checks despite runtime-sounding filenames. The relevant chapters call these out. Source-derived gaps are described as observations, not newly reproduced defects. Historical release-readiness reports keep their original date/context and do not certify the destination rewrite.
