# vJoy fix 1 re-review

Scope: the four Important findings in `tmp/vjoy-review.md`, the pre-existing disable neutralization error, and only new breakage from their fixes. Read-only review of the current checkout. The implementer reports 21 `vjoy_live` plus 24 `vjoy_manager` tests passing; unchanged suites were not rerun.

## Finding disposition

1. **ADDRESSED — lease-safe reload.** `manager.rs:557-562` accepts safe cleanup of deleted targets but returns before `publish_current_state` while the arbiter is suspended. Ports are marked suspended, and the new lease regression covers the cached button/axis case.
2. **ADDRESSED — deleted mapping after failed safe report.** `manager.rs:526-553` installs the committed DB snapshot before fallible native cleanup. Recovery now reads the new map, so it cannot replay the deleted route; the new recovery regression covers this.
3. **ADDRESSED — duplicate-config port suspension.** `manager.rs:643-689` tracks the actual reporting port, preserves a different supplier, and restores the latest surviving sample when the supplier goes away. The two new multi-port tests cover both directions.
4. **ADDRESSED — generation handover.** `manager.rs:612-641` removes the prior generation's provenance and reconciles its outputs before accepting the new generation. Both `observe_port` and `input_value` use it; the new generation regression covers the held target.
5. **ADDRESSED — disable neutralization error.** `manager.rs:263-283` persists requested-off and releases ownership, but returns the native error and records Error status/reason when neutralization fails. The fake-injected failure regression covers this path.

## New fix breakage

**Important — invalid samples can revoke a valid generation before validation.** `input_value` now calls `upsert_port` at `manager.rs:403-413` before checking the mapping's device, config and pin at `:414-420`. `upsert_port` treats a higher generation or different config as a handover and neutralizes the previous generation's targets (`:626-632`). Reproduce: report a mapped button pressed on COM1 generation 7; submit COM1 generation 8 with the same `input_id` but a wrong device ID or pin; the call returns `Ok(())` as an ignored invalid mapping, yet emits a button release and replaces generation 7. This breaks the method's stated safety check and prior behavior, where invalid samples were ignored before mutating the cache. **Test:** after a valid held report, send a mismatched identity/pin with a higher generation and assert no report, no generation replacement, and that the original generation can still update. Validate a mapped sample before the handover mutation; explicit `observe_port` can remain the authority for an otherwise unmapped new generation.

## Verdict

**Spec:** All original findings are fixed, but the new validation-order regression blocks acceptance of this fix set. **Quality:** The added tests cover the original counterexamples; add the invalid-sample generation test above before integration. Windows native behavior and the configurator remain the separately recorded scope.
