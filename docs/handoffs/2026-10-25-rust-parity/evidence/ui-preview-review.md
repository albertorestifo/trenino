# UI recovery and Rust preview adversarial review — 2026-10-25

## Verdict

**Spec: not yet acceptable. Quality: not yet acceptable.** The typed Rust preview calculations and stale display/input reply guards are sound within the exercised cases, and the reported 105 frontend tests, 3 preview tests, 26 binding tests, zero Svelte warnings, and successful build/check are credible handoff evidence. They do not cover the persistence and manual-run cases below. This is a source review; I did not run the suites again or smoke an actual WebView.

### Important — editing a mapped lever clears its saved mapping before the user saves

- `tauri/ui/src/components/wizards/LeverSetupWizard.svelte:194-239` calls `saveNotches(leverConfigId, notchDrafts(null))` for both new and existing configurations. `notchDrafts(null)` sets every `input_min` and `input_max` to `null` (`:175-186`). This happens on Continue from the Define Notches step, before capture, preview, or the final Save Mapping (`:301-334`).
- Repro: open an existing mapped lever, pass the notch step, then close the modal, go Back, lose the hardware connection, or encounter a binding conflict. The old stored ranges have already been replaced by nulls. The train now loses its working lever mapping even though the user never saved a replacement. The legacy flow starts a mapping session and persists ranges on its explicit `save_mapping` action (`lib/trenino_web/live/components/lever_setup_wizard.ex:597-649`, `:473`); it does not need this premature null-range write.
- Keep edits and captured ranges in the wizard until one final persistence operation, or preserve existing ranges until replacement succeeds. Add a regression test that cancels or fails after Continue and verifies the old `input_min`/`input_max` remain persisted.

### Important — completing a child wizard discards unsaved train fields

- `tauri/ui/src/app/pages/trains/TrainEdit.svelte:316-326` calls `reloadTrain()` on every wizard completion. `reloadTrain()` blindly rewrites `name`, `description`, and `identifiers` from storage (`:125-139`).
- Repro: change the train name or identifiers without saving, then create/edit a button, lever, output, or display binding. When that wizard completes, the header form silently reverts to the stored fields. The child mutation does not depend on those header drafts.
- Refresh child data without resetting dirty header fields, or track the header revision/dirty state and merge only untouched fields. Test a dirty name and identifier surviving a child wizard completion.

### Important — manual script UI reports success for an unexecuted script

- `tauri/ui/src/app/pages/scripts/ScriptEdit.svelte:85-97` checks only `result.ok` and always sets `Saved script triggered`. The new `ScriptRunner::run_script` contract returns `Ok(false)` for an unknown, inactive, or noncompiled script (`crates/trenino-runtime/src/train/script/runner.rs:261-280`, `:396-412`).
- Repro: disable an otherwise saved script while the editor is open, or cause a reload/compile failure, then press Run. A successful IPC `false` response is displayed as a trigger even though no VM ran. Handle `result.value === false` as an actionable unavailable state and add a fake bridge test for that result. The desktop command must return the actual ACK; current `tauri/src-tauri/src/rust_ui.rs:3038-3044` discards it and returns true (owned by the composition integration chunk and reported to root).

### Important — notch-validation transport failure is treated as successful save

- `tauri/ui/src/components/wizards/LeverSetupWizard.svelte:326-332` handles only an `ok` response with `valid: false`; a failed `validateNotches` call falls through to `onComplete`, closes the wizard, and shows successful configuration. The prior `saveNotches` call may have persisted incomplete ranges.
- Repro: make `saveNotches` succeed and `validateNotches` return `{ok:false, error: ...}`. The UI announces success instead of retaining the draft and surfacing that the final check failed. Fail closed on `!validation.ok`; cover this two-call result sequence in the wizard tests.

### Important — the calibration ceiling is still guessed for an uncalibrated input

- `crates/trenino-runtime/src/preview.rs:41-49` reads `max_hardware_value` solely from a previous calibration and falls back to 1023 when none exists. `tauri/src-tauri/src/rust_ui.rs:2099-2120` overrides the caller's supplied ceiling with this value when starting a session. Thus a fresh 12-bit input or a previously cleared calibration is analyzed with a 10-bit ceiling; rollover detection and saved normalization can be wrong even though the command is Rust-owned.
- The retained Elixir session also defaults to 1023 (`lib/trenino/hardware.ex:678-697`), so this is a parity limitation exposed by claiming an authoritative ceiling, not a regression against its default. Resolve device-specific ceiling from connected hardware/configuration metadata when available, or require an explicit supported range and reject unknown hardware. Add a fresh uncalibrated 4095-range case, rather than only the existing persisted 4095 rollover case.

## Scope notes

- I did not count the separately planned Windows vJoy configurator and simulator endpoint explorer work as preview defects.
- The known connected-port inventory, bootloader handoff, and actual WebView IPC smoke gaps in `tmp/ui-implementation.md` remain integration gates. The defects above are in already implemented flows and can be exercised with fake bridges or disposable storage.
