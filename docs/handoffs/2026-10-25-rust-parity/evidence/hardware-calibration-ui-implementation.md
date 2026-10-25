# Hardware calibration cancel acknowledgment UI (2026-10-25)

## Change

- `tauri/ui/src/components/calibration-wizard.svelte` now waits for `cancelCalibration(sessionId)` to return `Ok`, including `Ok(false)` for an already-clean session, before dropping the ID and closing. A rejected or thrown cancellation keeps the dialog and original session ID, displays the error, resets the pending state, and offers “Retry cancel.” Duplicate Cancel, Close, and backdrop actions cannot close the dialog while cleanup acknowledgment is pending. The advance button is disabled during cancellation.
- The existing start-after-unmount fence and best-effort `onDestroy` cancellation remain in place. A start that resolves after unmount still sends cancellation for the returned session ID. The backend owns retained failed cleanup leases and subsequent resource admission recovery.

## Verification

- New regressions in `tauri/ui/tests/wizards.test.ts` prove a rejected cancellation retains the dialog and retries the same session, `Ok(false)` closes after acknowledgment, and duplicate close actions wait for an in-flight acknowledgment. The pre-existing start-after-unmount cancellation regression still passes.
- `npm --prefix tauri/ui run check`: 0 errors, 0 warnings.
- `npm --prefix tauri/ui test -- --reporter=dot`: 12 files, 165 passed after the subsequent manual firmware-check policy correction.
- `npm --prefix tauri/ui run build`: passed, 141 modules transformed.
- `git diff --check -- tauri/ui`: passed.

No real serial hardware or packaged WebView was exercised in this scoped UI change. No Rust files were edited and no commit was created.
