# Controls fix round 2 review

Date: 2026-10-24
Reviewed range: 3da5194..7eb3b68.
Worktree: C:/Users/Alberto/.codex/worktrees/rust-rewrite/tsw_io

## Acceptance

**Accepted for the delivered controls primitives, client, subscription service and FIFO writer.** All three issues from controls-fix1-review.md are resolved. Together with the nine dispositions already accepted in round 1, this closes the original 11 numbered review findings for this slice. No new actionable regression was found in the round-2 changes.

This acceptance does not imply full Rust train/controller migration, exhaustive Elixir differential parity, or readiness to drive live hardware/simulator state. The implementation report's explicit unfinished runtime/workflow scope remains in force.

## Per-issue disposition

1. **Full-inbox subscription shutdown — resolved.** The QueueTimeout branch now returns the admission error without joining a worker that never received Shutdown. The worker handle remains owned, closing admission persists, and a later shutdown/cleanup request remains allowed. The Closed-channel branch can still join a worker whose receiver has independently closed. Existing PendingCleanup reporting is preserved. The added test fills the inbox and verifies the first call returns an explicit QueueTimeout within its outer deadline, without relying on a rescuing second call.

   Supervisor recompiled and reran the exact previous local-HTTP reproduction against the current runtime library: after the gated request and all 64 queued Counts calls completed, `first shutdown finished after actor drained and became idle: true`; the first result was `Err(QueueTimeout)`. A subsequent shutdown returned `Ok(())` and drained the actual lease. Previously the first call stayed pending indefinitely and only that second call rescued it. This closes the original finding 1's remaining lifecycle defect.

2. **Raw float notation — resolved for the reviewed contract and boundaries.** The helper now reconstructs fixed and scientific spellings from the shortest significant decimal digits, retains a decimal marker for float mantissas, and chooses the shorter spelling with fixed notation on ties. Negative zero is preserved. The changed code bounds all constructed strings by finite f64 exponent/significand lengths; no input-derived unbounded numeric allocation or indexing hazard was found. Added fixtures cover the reported 1e15 case and nearby positive/negative fixed/scientific transitions, including values whose shortest notation differs from Rust Debug.

   The supervisor's previous compiled-core probe now renders 1000000000000000.0 as `1.0e15`, with the previously checked small values and exponents unchanged. An additional small installed-Elixir oracle check confirmed the selection rule on 10.0, 100.0, 1000.0, 10000.0, 1200.0, 12300.0, 1e23, the smallest positive subnormal and negative zero. These are focused boundary checks, not an exhaustive corpus.

3. **Integer/float output comparisons — resolved.** New Integer arms call an exact mixed comparison instead of converting the integer to f64. Comparison against the truncated finite float and its fractional direction is correct for positive and negative fractions; explicit signed-i128 range checks avoid a saturating boundary cast, and NaN yields no ordering. All numeric operators, including inclusive Between, use that comparison. Boolean-only operators remain unchanged.

   The supervisor's same compiled-core probe now returns Gt=true and Lte=false for integer 9007199254740993 versus threshold 9007199254740992.0, matching the installed Elixir oracle from round 1. Added fixtures cover the negative counterpart, Between and ordinary fractional thresholds. Source inspection also checked equality, negative zero, infinity and i128-range edge handling in the new helper. This completes original finding 8's integer integration along with the notation fix.

## Evidence and limits

- Coder reports failing reproductions before these changes, then controls_parity **21 passed**, simulator_lifecycle **24 passed**, both focused clippy invocations passing, formatting checks passing and git diff --check passing. The supervisor read the added regressions and did not repeat broad suites.
- Supervisor reran only the prior concrete core and shutdown probes against the compiled libraries, plus the small Elixir notation check described above. Probe sources remain outside the checkout at `C:/Users/Alberto/AppData/Local/Temp/controls-fix1-review-16c0cc0e-e81c-4733-a299-ee29bf56e608`; round-2 executable names are `core_probe_round2.exe` and `shutdown_probe_round2.exe`.
- Reviewed production/test paths have no diff from 7eb3b68. Runtime/UI ownership outside these paths was respected. No source/test edits, child reviewers, actual simulator, hardware or database access occurred.
- A caller receiving QueueTimeout or PendingCleanup from shutdown must retry or report failed cleanup; acceptance does not reinterpret those explicit errors as successful termination. The worker remains owned and recoverable as documented.
- Live controllers, per-lever coalescing/retry tokens, train detection/activation, OS keyboard ownership, polling/reconnect supervision, output/display runtime lifecycle, full persistence/calibration workflows and Lua remain separately tracked work. The writer is still a bounded sequential FIFO; these fixes do not make it a complete lever controller.

No further controls fix round is requested for this reviewed slice.
