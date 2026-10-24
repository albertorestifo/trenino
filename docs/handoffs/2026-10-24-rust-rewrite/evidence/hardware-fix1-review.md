# Hardware fix round 1 review

Reviewed commit: 033cd0f (`fix: preserve hardware validation and display parity`)
Date: 2026-10-24
Worktree: C:/Users/Alberto/.codex/worktrees/rust-rewrite/tsw_io

## Verdict

Accepted for the bounded pure hardware slice. All three original actionable findings are ADDRESSED. No new breakage was found in the fix diff. This review does not extend acceptance to the deferred hardware runtime or physical-device parity.

## Original findings

| Finding | Status | Evidence |
| --- | --- | --- |
| Conflicting physical pins, I2C addresses, and generated matrix virtual pins | ADDRESSED | `build_configuration` now validates and records each assignment before constructing messages. Duplicate physical input pins and module addresses return errors. Each matrix is validated and every generated virtual pin is checked across matrices using the unchanged formula; overlaps return errors. Regression tests exercise all three rejection paths. The new configure golden test also verifies a valid mixed configuration retains its exact ordered bytes. |
| Legacy display alignment for fourteen-segment dots and Unicode graphemes | ADDRESSED | `encode_string` now uses extended grapheme clusters for alignment width, subtracts dot graphemes whenever `has_dot` is true, and retains the original scalar-based encoding/truncation step. This matches the legacy separation between `String.length`/`String.graphemes` for padding and `String.to_charlist` for encoding. New golden tests contain the exact bytes independently reproduced in the initial review for both `"1.2"` and decomposed `e` + U+0301 + `1`. The coordinated `unicode-segmentation` dependency and lockfile entry are present. |
| Empty matrix axes | ADDRESSED | `Matrix::validate` now rejects an empty row or column vector before maximum-size/product checks. The builder invokes this validator before generating virtual pins or messages. Separate tests exercise both empty-axis cases. |

## Fix-diff regression assessment

- Assignment sets are used only for membership, so their nondeterministic iteration order cannot change packet order. Existing input/module sorting and caller-supplied matrix/pin ordering remain intact.
- Matrix dimensions are validated before nested virtual-pin enumeration. Legal matrix size remains bounded to 128 generated pins, and the existing checked arithmetic remains in use.
- Rejecting multiple nonempty matrices follows the existing shared virtual-pin namespace and original finding; the fix introduces no new offsets or wire layout.
- Grapheme counting changes only alignment width. Segment tables, dot accumulation, encoding order, and output padding remain unchanged.
- Additional tests cover configure payload bytes, all two-chunk split points on a coalesced stream, empty delimiters plus malformed recovery, button changes/filter behavior, short sweeps, rollover thresholds, and midpoint boundaries. This is broader focused coverage, not a claim of exhaustive randomized or cross-runtime differential coverage.

## Verification evidence and scope

Read `hardware-fix1-review.diff`, the updated `hardware-report.md`, and commit 033cd0f's change summary. The implementation report records 20 passing hardware tests (7 protocol, 8 models, 5 calibration), passing core test clippy with warnings denied, and formatting of the owned files. Those recorded runs were not repeated for this scoped review. No source/test edits, child reviews, hardware access, or broad test runs were performed.

The checked shared ConfigId integration remains unchanged. The inherited unbounded frame buffer, future matrix-order adapter obligation, and deferred serial/session/persistence/firmware work remain documented follow-ups; none is newly introduced by this fix.
