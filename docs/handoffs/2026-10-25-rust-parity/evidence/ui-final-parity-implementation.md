# Final UI parity pass (2026-10-25)

## Delivered

- Restored editable HT16K33 parameters in `tauri/ui/src/components/i2c-module-form.svelte`: 7/14 segment display, 4/8 digits, brightness on the device's 0–15 scale, decimal point, right alignment, and optional minimum value. New modules display the Rust defaults (brightness 8, four digits, seven segment, no dot, left aligned, no minimum). Both create and edit send the complete typed `Ht16k33ParamsView`; a blank minimum sends `null` to explicitly clear it. Local parsing checks only that a supplied minimum is numeric; Rust owns display parameter validation. A Rust validation failure leaves the form and draft open.
- `UiBridge` create/update I2C methods now accept optional params, matching the backend command contract. `ConfigurationEdit.saveI2cModule` forwards the full form fields. The sibling `runtime_composition` updated `ui_create_i2c_module` and `ui_update_i2c_module`: omitted create params use defaults, omitted update params preserve stored settings, and an explicit object replaces all settings. Existing `updateConfiguration` was already declared as `UiSnapshot<ConfigurationSummaryView[]>`, matching Rust, so it needed no change.
- Train list active state now compares each saved ID with `SimulatorRuntimeStatus.active_train_id` rather than the stored summary's hardcoded `active` flag. The list shows the live detected simulator identifier even when no train matches. `App.svelte` passes the existing polled status into `TrainEdit.svelte`; its active delete guard and “Use current train ID” use the live active ID and `detected_identifier`. The latter accepts an unknown full simulator ID, not a stored prefix. Status prop updates leave name, description, and identifier drafts intact. The unused train summary subscription was removed from this page.
- The TrainEdit section links retain real fragment `href` values for keyboard/accessibility semantics, but click scrolling now prevents the hash router from interpreting `#automation`, `#controls`, or `#displays-lights` as a new route. This fixes the native WebView smoke finding. The settings form now shows “A key is saved” immediately from the successful Rust `setApiKey` snapshot and clears the entered secret; it no longer waits for a remount.

## Verification

- `npm --prefix tauri/ui run check`: 0 errors, 0 warnings.
- `npm --prefix tauri/ui test -- --reporter=dot`: 11 files, 150 passed. Added create defaults, edited six-field payload, explicit minimum clearing after a saved value, backend validation error retention, active ID projection despite contradictory stored flags, unknown live ID capture, dirty header preservation across status changes, section-link hash stability, and immediate API-key status.
- `npm --prefix tauri/ui run build`: passed, 141 modules transformed.
- `cargo check --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui --quiet`: passed against the updated desktop I2C command signatures.
- `git diff --check -- tauri/ui`: passed.

## Generated nullable wire types

Root regenerated several ts-rs declarations to match Rust's nullable JSON fields. The resulting UI check identified three firmware presentation assumptions. `Firmware.svelte` now displays “Size unknown” for a null file size and treats a null upload duration as unknown in the history and success message; it no longer renders `nullms`. A firmware regression uses a null file size. No generated declaration was edited manually. After regeneration, the full UI check again reported 0 errors and 0 warnings, all 150 tests passed, the 141-module build passed, desktop `cargo check` passed, and `git diff --check -- tauri/ui` passed.

## Review 1 fixes

The three Important findings in `tmp/ui-final-parity-review.md` are addressed:

- A transient simulator status read error keeps the last successful status, so active train cards and the detected ID remain visible. `TrainEdit` treats a missing status or any current status read error as unknown activity: Delete and modal confirmation are disabled, and `deleteTrain()` also checks the guard before invoking IPC. The current-ID action is disabled while the status is stale and labelled last known. The desktop owner added an independent live-runtime guard in `ui_delete_train`, including a real command test proving unavailable runtime cannot delete a database row and a live-active-ID conflict test.
- New HT16K33 forms now use the retained embedded defaults: fourteen segment, right aligned, minimum 0.0, brightness 8, four digits, no dot. The Rust omitted-create fallback uses the same defaults. An existing module with a persisted null minimum keeps its blank field and sends null on metadata edit; new defaults are applied only to creation.
- Name is labelled optional. Blank create or clearing an existing name sends `name: null`, matching the retained changeset and Rust storage validation.

Regression coverage includes an untouched new display payload, unnamed create, cleared name with an existing null minimum, failed status after an active train, unknown status before any successful read, blocked delete confirmation after status becomes stale, and dirty train header preservation. Final verification: `npm --prefix tauri/ui run check` 0 errors/0 warnings; `npm --prefix tauri/ui test -- --reporter=dot` 11 files/155 passed; UI build 141 modules; desktop `cargo check --features rust-ui` passed; `git diff --check -- tauri/ui` passed.

No real display, simulator, or packaged WebView interaction was run by this agent. Root reported separate native smoke coverage for simulator connection, detected identifier, train creation, and Lua persistence. No commit was created; concurrent backend work was preserved.
