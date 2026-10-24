# UI fix round 1 scoped review

Date: 2026-10-24. Reviewed `ca5c1dd..ebab5b1` and the updated UI report. **Verdict: changes requested — two P2 stream recovery defects remain.** The other six original corrections are accepted in this slice. No new child review, production edit, broad test rerun, user-app launch or hardware action was performed.

The new observer-specific `{ topic, subscription_id }` subscribe/unsubscribe contract is accepted as explicitly approved by the coordinator; runtime integration is implementing its matching window-scoped behavior. No finding requests a duplicate stable application-update banner or reopens unavailable full UI features.

## Remaining findings

### R1. P2 — Retiring an epoch does not remove its pending events

`tauri/ui/src/bridge/stream.ts:83,95,154-158`.

`retire` only records an epoch name. Previously buffered gap events from that epoch remain in `pending`, and `needsSnapshot` treats every different-epoch pending entry as unresolved even when the epoch was retired. Therefore a normal restart during gap recovery can keep fetching snapshots indefinitely after the new runtime is fully caught up.

Reproduced against the actual TypeScript source with an inline Node probe (no test/source file written):

1. Install `{ epoch: '9', revision: '4' }`.
2. Accept `{ epoch: '9', revision: '6' }`, leaving a gap event pending.
3. Install `{ epoch: '10', revision: '1' }`.
4. Install that current snapshot again.

Both installations in steps 3/4 return `resync`; `needsSnapshot()` stays `true` and `bufferedChangeCount` stays 1. The remaining event is from the retired epoch and can never replay. Purge retired-epoch pending entries/high-water metadata, or otherwise exclude and discard them during recovery. Add a regression with an old-epoch gap pending before restart, asserting the new snapshot settles and the bridge stops retrying.

### R2. P2 — Evicted different-epoch high-water marks no longer force resync

`tauri/ui/src/bridge/stream.ts:90-97,110-118`.

When the 128-entry bound evicts an event, its high-water mark is retained by epoch. However, `needsSnapshot` only reads `droppedHighWater` for the current epoch. If the last pending entry for a different, unretired epoch is evicted, a lagging current-epoch snapshot can be reported as fully applied despite the unresolved observed epoch.

Reproduced with the same inline probe:

1. Install epoch 9 / revision 4.
2. Observe epoch 10 / revision 10.
3. Receive epoch-9 gap events for revisions 6 through 135 (130 events), evicting the epoch-10 entry into high-water metadata.
4. Install a delayed epoch-9 / revision-134 snapshot.

Result: `applied` at epoch 9 / revision 135, `needsSnapshot() === false`, while the internal high-water metadata still contains `['10', 10n]`. No further event is guaranteed, so recovery may stop on the previous runtime. This is the same asynchronous/lagging-snapshot contract covered by original finding 5; it does not assume an existing backend implementation.

Keep resync required for unresolved unretired epochs as well as the current epoch, while clearing retired metadata under R1. If metadata bounds themselves evict unresolved information, retain an explicit resync condition rather than silently treating it as covered. Add a cross-epoch eviction test and a subsequent authoritative epoch-10 snapshot that settles recovery. The epoch reconciliation policy must distinguish covered/retired state from still-unresolved observations.

## Original finding dispositions

| Original finding | Disposition and evidence |
| --- | --- |
| 1. Structured errors | **Accepted.** `normalizeIpcFailure` validates known codes/shape, preserves safe message/fields/retryability, falls back for malformed/unknown failures, and redacts internal details. Tests cover validation, conflict, internal and malformed failures. Rust conversion also redacts internal message and fields. |
| 2. Stale route responses | **Accepted.** Every async route/resource/consent completion checks mount state, route generation and requested hash. Resource errors are separate; unmount invalidates generation. Tests cover a stale list failure, revisiting the same route, unmount and late consent completion. |
| 3. Consent gate | **Accepted.** Pending/unavailable/needs-consent states hide normal routes; failed bootstrap exposes retry and consent access without reading lists. Delayed/failing bootstrap is tested. |
| 4. Bounded retry/recovery | **Partially accepted; R1/R2 remain.** Pending values are capped at 128; startup no longer blocks access to the disposer; one snapshot fetch is in flight; retry timers back off and disposal clears timers/listeners with an active guard. Failed-first-fetch and hung-fetch burst/disposal tests cover the original failure. Epoch bookkeeping still prevents correct settling in R1/R2. |
| 5. Resync high-water mark | **Partially accepted; R1/R2 remain.** Same-epoch 4 → event 6 → snapshot 5 correctly replays through 6, and buffered gap changes survive replay. Cross-epoch metadata handling has the two reproduced holes above. |
| 6. Invalid envelopes | **Accepted.** Topic, plain object, presence of value, canonical decimal counters and full-u64 bounds are checked before arithmetic or installation; invalid results are surfaced/recovered without a raw BigInt exception. Exact-u64 tests remain. This validates the transport envelope, not every generic domain payload. |
| 7. System theme | **Accepted.** System mode removes `data-theme`, preserving DaisyUI OS-media behavior; explicit modes remain fixed; invalid saved values fall back to system. Focused theme tests cover these choices. |
| 8. Generated drift check | **Accepted.** Export goes into unique temp directories; byte/file-set comparison fails stale or unexpected checked-in declarations. The stale fixture test exercises failure without editing the real generated directory. `.gitattributes` enforces LF, so byte comparison has a consistent checkout format. No tracked generated files are rewritten by the check. |

## Additional scoped confirmations and validation limits

- Subscription IDs are unique per observer. Disposal is idempotent, suppresses callbacks, and releases again after a pending registration completes, preventing that late registration from surviving unmount. Matching backend ownership remains a runtime integration check.
- Opaque epoch equality replaces the former undocumented numeric ordering assumption. This direction is consistent with the current shared identity contract, but R1/R2 must be fixed before accepting its reconciliation behavior. No claim is made that all arbitrary delayed identities across unlimited restarts have been integrated/tested.
- The implementer reports Rust UI 6/6, focused Vitest 28/28, full Vitest 31/31, Svelte check/build and audit 0. Source inspection confirms those tests target the corrections; this scoped reviewer did not repeat them. The two new inline probes specifically establish missing edge coverage.
- Working-tree changes observed during review are sibling runtime/hardware integration changes. This review did not alter or validate those paths. There are no leftover review probe files.

After R1/R2 are corrected, rerun their focused stream/bridge regressions and obtain a scoped re-review. Full retained screens, live service consumption, firmware notification, packaged WebView/screenshots and runtime updater quiescence retain their previously documented integration gates.
