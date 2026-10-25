# Guided simulator and atomic mapping UI review (2026-10-25)

## Verdict

The stage 1 status and manual target fixes are present. Guided sessions use typed Rust IPC, poll with a local epoch, and copy analysis/sweep results into editable draft rows. The lever Save is a single `ui_commit_lever_mapping` call. Four UI defects remain, including an outer-modal cancellation bypass and a saved draft loss path. This is source review; I did not rerun the reported 133 frontend tests or run a live simulator/WebView.

## Important findings

### 1. Outer wizard close bypasses guided cancellation acknowledgement

`tauri/ui/src/components/wizards/WizardModal.svelte:14-25` calls the parent `onClose` directly from the backdrop and X while a guided session is running. In `GuidedSimulatorSession.svelte:108-113`, unmount only invokes `cancelBackend(sessionId)` without waiting for or checking its result. Repro: start an analysis or automatic sweep, click the wizard's top X, then have `ui_cancel_lever_*` return an IPC error or backend cleanup failure. The wizard vanishes, the error is lost, and the Rust session can keep occupying the sole active simulator slot or continuing a sweep. The guided component's own Close button correctly waits for a cancellation acknowledgement (`:78-104`), but users can bypass it. Route outer dismissal through that same acknowledged close operation (including late start) and keep a visible retry path on failure. Test outer X/backdrop during an active sweep with cancel failure then retry. This is distinct from the backend's separately tracked abandoned-start fix.

### 2. Editing after a gapped Save can finish without saving the revised mapping

`LeverSetupWizard.svelte:359-362` sets `savedWithGaps=true` after an atomic commit reports gaps. The user can press Back from Preview to Map Positions (`:393-397`), recapture or click Auto-distribute (`:309-325`), then return to Preview. Neither path clears `savedWithGaps`; `enterPreview` (`:304-307`) does not either. The next Save immediately calls `onComplete` at `:328-332` without sending `commitLeverMapping`, even though the draft mapping now differs from the saved one. Repro with a gapped result followed by Back → Auto-distribute → Save; the wizard closes and the DB retains the original gapped ranges. Invalidate the saved acknowledgement whenever mapping/notch/endpoint/input draft changes, and only use “Finish anyway” for the exact committed revision. Add this sequence to the wizard tests.

### 3. Ambiguous detection silently preselects the first control

`GuidedSimulatorSession.svelte:15,64,136-149` initializes `selectedIndex=0`, checks the first radio, and enables “Use control” whenever `changes.length>0`, even when `snapshot.ambiguous` is true. Repro: move two simulator controls within the detection window, then click Use without touching a radio. The first returned control is bound despite the prompt asking the user to choose; order is a backend result detail, not user intent. Start an ambiguous result with no selection and require a radio choice. Keep automatic selection for an unambiguous single result if desired. Test that Use is disabled until explicit choice in the ambiguous case.

### 4. A late endpoint resolver can overwrite manually edited fields

`LeverSetupWizard.svelte:111-129` awaits `resolveLeverEndpoints(selected.endpoint)` and checks only component liveness and `guidedMode` before replacing all five endpoint fields. The fields at `:472-525` remain editable while the request is pending. Repro: choose a detected lever, change its min/value endpoint manually while the Rust resolver is slow, then let the resolver complete. The newer manual draft is silently overwritten. Capture a draft revision when starting resolution and apply the response only if no endpoint edits occurred (or disable those fields with a clear pending state). Add a delayed resolver test.

## Verified scoped fixes and contracts

- **Apply status retry:** `App.svelte:191-209,368-370` now retains `state: 'pending'` on transport/status-read error, displays the error, and retries the same operation ID. This addresses the prior false terminal failure.
- **Manual target:** `ConfigurationEdit.svelte:332-351` captures port and generation at click time; `client.ts:439-440` sends exact snake_case arguments; `runtime_hardware.rs:192-318` checks the current config owner and dispatches with the selected generation. This addresses the prior wrong-board actuation path.
- **Atomic Save:** `LeverSetupWizard.svelte:328-368` uses one commit, handles conflict confirmation, and awaits terminal validation. The separate backend review's `calibrated_at` and post-commit snapshot/ACK issues are already under repair and are not duplicated here.
- **Session fencing:** `GuidedSimulatorSession.svelte:27-50,61-71` drops stale local poll replies and cancels a late successful start after unmount. Progress is displayed as `progress * 100`, matching the Rust 0–1 contract. Detection endpoint resolution stays in Rust (`runtime_sessions.rs:82-123`), and the five fields are copied only after a successful result. The four findings above are gaps around these guards.
