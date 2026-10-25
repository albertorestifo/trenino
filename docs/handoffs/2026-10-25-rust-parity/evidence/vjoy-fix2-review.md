# vJoy fix 2 re-review

Read-only review of the single Important validation-order regression in `tmp/vjoy-fix1-review.md`. Handoff reports 23 `vjoy_live` and 24 `vjoy_manager` tests passing; unchanged suites were not rerun.

**ADDRESSED — invalid samples no longer revoke the current generation.** `manager.rs:397-420` looks up the mapping and rejects mismatched device, config or pin before `upsert_port` can replace a port generation and reconcile held targets. The new wrong-device and wrong-pin higher-generation tests in `tests/vjoy_live.rs` cover the exact counterexamples; explicit `observe_port` remains the authority for an otherwise unmapped generation. No new breakage found in the changed ordering.

**Spec and quality verdict:** This scoped fix is suitable for integration. Windows configurator and real-device acceptance remain separately tracked.
