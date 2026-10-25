# Guided UI fix 1 rereview (2026-10-25)

## Verdict

Three of the four original Important findings are addressed. The outer modal now routes normal X/backdrop dismissal through the guided component's acknowledgement path, but a real backend cleanup-failure status still bypasses that path. The new atomic commit DTO is consumed correctly for the reviewed success and nullable-snapshot paths. This is a scoped source/test review; I did not rerun the reported 139 frontend tests or a native simulator/WebView smoke test.

## Remaining Important finding

### A `failed` status can still hide an active session that needs cleanup retry

`GuidedSimulatorSession.svelte:29-31` classifies every `failed` snapshot as terminal. Its `close()` at `:121-135` skips `cancelBackend` for a terminal snapshot, and its `start()` at `:63-70` drops the old `sessionId` before starting another one. Rust deliberately sets `SessionState::Failed` while retaining `active=Some` when cancellation or detection cleanup fails (`crates/trenino-runtime/src/composition/sessions.rs:487-510,523-537`). Repro: start control detection, make unsubscribe fail after detection or after the user's first Close; poll reports `failed` with cleanup error. Clicking outer X/backdrop now calls `requestClose()`, but the component sees terminal `failed`, skips the needed retry, and dismisses the wizard. Clicking Try again first forgets the old ID and gets Busy from the retained active slot. The backend's retryable ownership is unreachable from the UI. Keep the session ID until cleanup is acknowledged and call `cancelBackend` when closing or restarting a failed session; a completed/reaped session can safely answer `Ok(false)`. Add a test with a `failed` snapshot produced by cleanup failure, then verify outer dismissal retries cancellation and remains visible if that retry fails.

## Original findings and DTO check

1. **Outer modal dismissal: partially addressed.** `LeverSetupWizard.svelte:48-59` and `ButtonBindingWizard.svelte:57-68` await the bound `requestClose()` before parent dismissal. `WizardModal.svelte:17-30` blocks repeat backdrop/X clicks while that request runs. Tests at `guided-sessions.test.ts:225-300` cover cleanup failure/retry for a `running` snapshot and a late successful start. The `failed` retained-owner case above remains.
2. **Gapped Save revision: addressed.** `LeverSetupWizard.svelte:123-131,375-425,803-856` records the submitted mapping signature and offers “Finish anyway” only if the current draft still matches. Back → new distribution triggers another atomic commit; `recovered-flows.test.ts:399-432` covers the sequence.
3. **Ambiguous detection: addressed.** `GuidedSimulatorSession.svelte:19,55,70,175-185` starts with no selected radio and only preselects an unambiguous sole result. The Use button stays disabled until an ambiguous result is explicitly chosen; `guided-sessions.test.ts:23-40` covers it.
4. **Slow resolver versus manual edits: addressed.** `LeverSetupWizard.svelte:43,148-172,537-588` advances an edit revision on typing and browser selection and discards a late resolver reply after any edit. `guided-sessions.test.ts:302-322` covers this.

The frontend sends `calibration_completed` only while the accepted sweep endpoint/notch draft matches (`LeverSetupWizard.svelte:123-125,190-203,384-400`). On `Ok`, it uses the explicit `lever_config_id` and `inverted`, accepts `train_detail: null`, and treats `refresh_required` as a saved mapping needing a refresh (`:405-422`), matching `runtime_mapping.rs:37-43,89-100`. `TrainEdit.svelte:318-329` then calls `reloadTrain(true)`, whose `:125-140` preserves dirty header fields. `recovered-flows.test.ts:434-452` covers null train snapshot acknowledgement. I found no second concrete DTO or parent-draft regression in this scope.
