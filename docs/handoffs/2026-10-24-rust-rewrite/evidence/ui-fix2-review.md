# UI fix round 2 scoped review

Date: 2026-10-24. Reviewed `ebab5b1..6c2d99b`, the stream follow-up in `ui-report.md`, and R1/R2 from `ui-fix1-review.md`. **Verdict: ACCEPTED for the scoped shell/DTO/bridge foundation. R1 and R2 are resolved; no blocking regression found in this narrow fix.** The other six original corrections retain their round-1 acceptance. This does not accept full retained-UI parity, runtime adapters or desktop cutover.

## Dispositions

- **R1 — Accepted.** `retire` now removes pending entries and dropped high-water metadata belonging to the retired epoch. Installing the new runtime snapshot therefore removes the unreplayable old gap and allows `needsSnapshot()` to become false. The added bridge regression checks that the current new-epoch snapshot stops the retry cycle, rather than merely checking the stream return value.
- **R2 — Accepted.** `needsSnapshot()` checks unresolved high-water marks from every unretired epoch. An event evicted from the 128-entry pending buffer remains a recovery obligation even when its epoch differs from the current snapshot. The new cross-epoch regression verifies the delayed old-epoch response remains `resync`, followed by successful new-epoch catch-up.
- **Metadata overflow — Accepted.** The high-water map remains bounded and increments an explicit overflow generation when unresolved epoch metadata is evicted. An old response cannot silently clear that obligation. A fresh authoritative response covers overflow and retires obsolete other-epoch observations.
- **Request timing — Accepted.** The actual bridge captures `stream.beginSnapshot()` immediately before invoking `ui_get_snapshot` and supplies that token to `installSnapshot`. Both observation and overflow generations must still match before the response can cover overflow and retire other observed epochs. Events arriving after request initiation therefore keep their recovery obligations. Existing single-flight fetching, retry backoff and active/disposal guards are unchanged.

## Verification

An inline Node probe imported the actual `TopicStream` source and asserted:

1. Original R1 sequence settles at epoch 10 / revision 1, with zero pending records and no resync requirement; a late retired-epoch event is ignored.
2. Original R2 sequence, using a token captured before the newer observation, remains in resync after the delayed epoch-9 snapshot and settles only after a fresh epoch-10 snapshot.
3. More than eight observed epochs overflow the metadata bound; the stale token preserves the recovery marker, pending values remain bounded, and a fresh authoritative current-state snapshot settles recovery.

All assertions passed. No probe file or production source was written. The four reviewed source/test files match commit `6c2d99b` without subsequent local changes.

The implementer reports the R1/R2 regressions failing before the fix, then 19 stream/bridge tests passing, plus Svelte check and production build passing. This focused review inspected the new tests and did not repeat the broad suite or build. No child review or real app/hardware operation was performed.

## Integration boundary retained

The retirement/overflow rule relies on the approved contract that `ui_get_snapshot` reads the runtime's current committed state, rather than returning cached historical snapshots. A request started after the relevant observations can then authoritatively establish the current epoch. The runtime writer is implementing that contract; its implementation and the separately reported successful desktop Cargo check were not reviewed here.

Observer IDs remain window-scoped and must match the accepted backend subscribe/unsubscribe contract. Full live screen consumption, operation workflows, firmware notices, packaged WebView/screenshot parity and acknowledged Rust updater quiescence remain separate integration gates. Stable app updates continue through native Help → Check for Updates, without a duplicate legacy app banner.
