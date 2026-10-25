# Final UI parity fix 1 scoped rereview (2026-10-25)

## Verdict

All three Important findings in `tmp/ui-final-parity-review.md` are addressed in the current source. The reviewed native command now checks live control-runtime state before deleting a train. One lower-severity status affordance gap remains during Retry. This is source and test review; I did not rerun the reported 155 frontend tests or native/physical smoke tests.

## Original findings

1. **Active-train delete guard — addressed.** `App.svelte:123-129` retains the last successful simulator status after a failed poll and sets `simulatorError`. `TrainEdit.svelte:65-68,217-222,779-793,844-864` disables Delete while status is absent, errored, or names this train as active; the confirmation button and handler also check the same condition after a modal is already open. `rust_ui.rs:2372-2411` independently rejects an active ID from the running control runtime and fails closed if that runtime is unavailable. `recovered-flows.test.ts:36-89` covers failed status after active, initial unknown, an already-open confirmation becoming stale, and dirty header preservation; `wire_patch.rs:514-552` covers the unavailable command and active-ID predicate. The active-runtime test exercises the predicate rather than an invoked command, but the production command calls that predicate immediately before mutation.
2. **HT16K33 create defaults — addressed.** `i2c-module-form.svelte:17-36,59-63` initializes an untouched new module to fourteen segment, four digits, brightness 8, no dot, right alignment, and minimum 0; `rust_ui.rs:2182-2195` has the same omitted-create fallback. Existing persisted `min_value:null` becomes a blank field and remains null on edit. `configuration-edit.test.ts:234-268` checks the untouched create payload and existing-null update.
3. **Unnamed I²C module — addressed.** `i2c-module-form.svelte:52-60,73-76` labels Name optional and sends `name:null` when blank; `ConfigurationEdit.svelte:356-368` forwards that typed value, and `rust_ui.rs:2217-2229` accepts `Option<String>` for create/update. `configuration-edit.test.ts:245-268` covers unnamed create and clearing a stored name.

## Minor remaining issue

**Retry briefly treats retained status as fresh.** `App.svelte:131-137` clears `simulatorError` at the start of `retrySimulator()`, before `retrySimulator()` and the subsequent `refreshSimulator()` return. After a failed status poll, the last successful status remains in `simulatorStatus`. If it named a different active train, `TrainEdit.svelte:65-67,779-784,856-860` reenables Delete during that in-flight interval even though activity is still unconfirmed. The Rust command's live active-ID guard prevents deletion of the currently active train, so this is a misleading transient affordance rather than the original destructive defect. Keep status marked stale until a successful new read (or include retry pending in `activityKnown`); add a pending-Retry UI regression if changed.

## Other requested paths

The live active ID and unknown full detected identifier remain projected in `App.svelte:375-397` and `TrainEdit.svelte:65-68,420-428`; the status-change regression keeps a dirty header at `recovered-flows.test.ts:36-73`. `TrainEdit.svelte:359-361,480-485` prevents the section link from changing the SPA hash and scrolls to the section; the regression checks both at `recovered-flows.test.ts:91-105`. `SettingsEdit.svelte:50-66` derives the saved-key indicator from the successful Rust snapshot and clears the secret; `shell.test.ts:84-99` covers it. Nullable firmware size and duration still have explicit display branches at `Firmware.svelte:108-112,238-249,465-472`.
