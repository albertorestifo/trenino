# Guided simulator and atomic mapping UI (2026-10-25)

## Delivered

- Fixed the two stage 1 review findings in `tmp/ui-hardware-simulator-review.md`. An intermittent `ui_configuration_status` error leaves the same apply operation pending, shows the read error, and retries. Manual HIGH/LOW and display tests capture and send the selected port and generation from the click; they cannot silently move to another device connection. The bridge uses the backend's exact snake_case parameters.
- Replaced the lever wizard's create/bind/save/update/validate write chain with one `ui_commit_lever_mapping` request. It sends the reviewed endpoints, notch drafts, captured physical ranges or auto-distribute choice, and the explicit replacement decision. Rust recomputes calibrated ranges and returns the saved train detail plus validation. The UI retains the existing gap acknowledgement and shows conflict confirmation before retrying the atomic request. Continue and preview remain read only.
- Added typed guided session IPC methods in `tauri/ui/src/bridge/client.ts` and the shared `GuidedSimulatorSession.svelte`. It starts, polls, displays countdown and Rust analysis/sweep progress, handles ambiguous detections with an explicit choice, and shows timeout, failure, and transient status errors. Close waits for a cancellation acknowledgement; an error keeps the session visible for retry. Unmount and a late successful start request cancellation, and stale replies cannot update the current session.
- The button binding wizard can auto-detect its simulator endpoint and still accepts a browsed or manually entered endpoint. Fixed its missing Continue action from the simulator endpoint step so configuration is reachable.
- The lever wizard can auto-detect a simulator control, then asks `ui_resolve_lever_endpoints` to fill the five endpoint fields. It can run Rust lever analysis or the full automatic notch sweep with the chosen endpoint override, then copies returned notches into editable draft fields. The result is never saved until the user reviews it and invokes the atomic Save. Manual entry, manual notch definition, and the existing mapping capture path remain reachable.

The backend contracts are supplied by `runtime_sessions.rs`, `composition/sessions.rs`, `runtime_mapping.rs`, and the exact target manual hardware commands owned by the other agents. The simulator sessions use the accepted live connection and serialize active work. The sweep uses `calibrate_draft`, so guided suggestions are not persisted before explicit Save. `CalibrationProgress.progress` is a 0–1 fraction; the UI converts it to a percentage for display only.

## Verification

- `npm --prefix tauri/ui run check`: 0 errors, 0 warnings.
- `npm --prefix tauri/ui test -- --reporter=dot`: 11 files, 133 passed. New regressions cover retrying an apply status error; preserving original manual port/generation, including generation 0; atomic mapping and conflict retry; ambiguous detection choice; timeout/retry; transient guided status error and progress; cancel acknowledgement, failed cancel/retry, and late start after unmount; detected button and lever paths; Rust-resolved lever endpoints; reviewed analysis and full sweep drafts.
- `npm --prefix tauri/ui run build`: passed, 141 modules transformed.
- `cargo check --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui --quiet`: passed with current concurrent backend wiring.

No physical hardware, live simulator, or packaged WebView test was run. UI tests use fake bridges. No commit was created; unrelated shared work was preserved.

## Review boundary

This report supersedes the earlier stage 1 report's proposed guided and atomic backend contracts. The commands now exist and are invoked by the UI. An independent review should focus on asynchronous session ownership/cancellation, draft semantics after automatic sweep, and the exact target generation fence at the Rust transport boundary. Real simulator/device acceptance remains separate from these automated checks.

## Round 1 guided UI review fixes

The four Important findings in `tmp/ui-guided-review.md` are addressed:

- The lever and button wizard backdrop/X now use the guided session's acknowledged `requestClose()`. The outer close is disabled while cleanup runs; a rejected cancellation stays visible and allows retry. A late successful start is cancelled before the wizard dismisses. Successful cancellation is recorded before child unmount so teardown does not issue a duplicate command.
- Ambiguous detection starts with no radio selected, and Use remains disabled until the user chooses a control. A single unambiguous result selects its sole control.
- A gapped commit records the submitted draft signature. “Finish anyway” applies only to that exact committed draft; changing the input, endpoints, notches, captured ranges, distribution choice, lever type, or replacement choice requires another atomic Save. The old saved gaps and unsaved current draft are identified separately.
- The lever resolver captures an endpoint edit revision. Manual typing or browser selection during its request keeps those edits and discards the late resolver result with a visible message.

The UI now uses the backend's updated atomic mapping DTO. It sends `calibration_completed: true` only while the accepted full automatic sweep's endpoint/notch draft remains unchanged; analysis and manual definitions send false. On success it uses explicit `lever_config_id` and `inverted` fields and accepts `train_detail: null`. A `refresh_required` acknowledgement says the mapping was saved and the train details need refreshing; it does not treat a post-commit snapshot failure as a failed save or retry creation. The train page's existing `reloadTrain(true)` preserves dirty header fields.

Verification after these fixes:

- `npm --prefix tauri/ui run check`: 0 errors, 0 warnings.
- `npm --prefix tauri/ui test -- --reporter=dot`: 11 files, 139 passed. Added outer close failure/retry for lever and button, late start acknowledgement, ambiguous selection, slow resolver/manual edit, gapped Save → Back → new distribution → second commit, automatic sweep metadata, and null snapshot saved acknowledgement.
- `npm --prefix tauri/ui run build`: passed, 141 modules transformed.
- `cargo check --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui --quiet`: passed when run after the UI build. One concurrent build/check attempt raced Vite's replacement of `ui/dist`, producing missing generated asset errors; the sequential rerun passed.
- `git diff --check -- tauri/ui`: passed.

## Round 2 cleanup-owner review fix

The remaining Important finding in `tmp/ui-guided-fix1-review.md` is addressed with the backend's new required `SessionSnapshot.cleanup_pending` flag. A failed snapshot with `cleanup_pending: true` retains its session ID. Close, including outer wizard X/backdrop, calls cancel and waits for acknowledgement. A failed cancel leaves the wizard and ID in place with a visible error; another Close can retry. “Try again” first acknowledges cleanup of that old ID and starts a new session only after success. A failed snapshot with `cleanup_pending: false` can close or retry without a redundant cancel. Unmount cleanup also treats a failed pending snapshot as owned.

Regression tests model the backend's retained failed owner, an unsubscribe failure on the first retry, successful retry and new start ordering, failed outer dismissal, and the already-cleaned failure case. The required bool is serialized by `crates/trenino-runtime/src/composition/sessions.rs`; `script_recon` reported its guided runtime suite passing 16/16.

Final verification for this round:

- `npm --prefix tauri/ui run check`: 0 errors, 0 warnings.
- `npm --prefix tauri/ui test -- --reporter=dot`: 11 files, 142 passed.
- `npm --prefix tauri/ui run build`: passed, 141 modules transformed.
- `cargo check --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui --quiet`: passed after the UI build.
- `git diff --check -- tauri/ui`: passed.
