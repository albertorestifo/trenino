# UI preview fix 1 rereview — 2026-10-25

## Verdict

**Four actionable UI findings addressed.** I checked the changed implementation and the new fake-bridge cases, without rerunning the reported 111 frontend tests, 3 preview tests, check, or build. An actual WebView IPC smoke remains a separate gate. The fresh 1023 ceiling is the retained Elixir/AVR default, as ruled by root; persisted 4095 calibration remains covered and is not a parity defect.

| Original finding | Result | Evidence |
| --- | --- | --- |
| Existing lever mapping wiped on Continue | **Addressed** | `LeverSetupWizard.svelte:195-239` now only reads bindings and enters mapping. Automatic distribution calls the read-only Rust preview at `:247-264`; `saveNotches` first occurs in Save Mapping at `:298`. `recovered-flows.test.ts:258-319` covers Cancel, conflict, and automatic preview without writes. |
| Child wizard completion loses train header draft | **Addressed** | `TrainEdit.svelte:125-140` supports `preserveHeaderDraft`; wizard completion calls `reloadTrain(true)` at `:320-328`. The reported test changes header fields then completes a child binding. |
| `Ok(false)` script run shown as success | **Addressed** | `ScriptEdit.svelte:85-103` treats false as unavailable and does not schedule log refresh. `rust_ui.rs:3071-3087` now returns `ScriptRunner::run_script`'s actual `Result<bool>` directly; the unbounded `get_script_log` preflight was removed. |
| Notch validation transport failure shown as successful save | **Addressed** | `LeverSetupWizard.svelte:311-321` returns with an error on `!validation.ok`; `recovered-flows.test.ts:321-355` checks retention and retry, including the distinct gap confirmation path. |

## Remaining scoped risk

The Save Mapping path is still a sequence of separate backend mutations (`LeverSetupWizard.svelte:281-321`). A bind may commit before notch persistence fails, and notch persistence may commit before inversion update or validation fails. The modal remains open with an error, but the old mapping can be partially replaced after the user explicitly presses Save. The implementation handoff identifies this limit. A transaction-backed single mapping save would be needed for atomicity; it is not a recurrence of the premature Continue wipe.
