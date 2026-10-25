# Final UI parity chunk adversarial review (2026-10-25)

## Verdict

The new I²C payload wiring, live train ID display, in-page click scrolling, saved API-key feedback, and nullable firmware formatting are present. I found three concrete parity/behavior defects. This is source and test review; I did not rerun the reported 150 frontend tests or a physical display/native WebView smoke test.

## Important findings

### 1. Active-train delete guard fails open when status is unavailable

`tauri/ui/src/app/App.svelte:123-129` clears `simulatorStatus` after any failed `ui_get_simulator_status` poll. `TrainEdit.svelte:65,779-781,850-855` then derives `isActive=false` and enables Delete for the train that may still be active. The desktop delete command reaches `AppServices::delete_train_entry` and storage deletion without an active-train guard (`tauri/src-tauri/src/rust_ui.rs:2339-2342`, `crates/trenino-runtime/src/app.rs:1181-1190`, `storage/domain/trains.rs:837-849`). Repro: open active train, make one status IPC read fail, then delete before the next successful poll; the active configuration and cascaded elements/scripts can be removed. The same window exists before the first successful status read. Preserve a last authoritative active state and fail closed while status is unknown, with a backend active-train fence for the final deletion race. Add a failed-poll-after-active regression plus a direct delete guard test.

### 2. New display defaults differ from the retained Elixir display workflow

`i2c-module-form.svelte:17-24` starts a new HT16K33 module as `seven_segment`, `align_right=false`, and `min_value=null`; untouched Add sends those values (`:54-62`). The Rust omitted-create fallback repeats them (`tauri/src-tauri/src/rust_ui.rs:2171-2175`). The legacy embedded params default to `fourteen_segment`, `align_right=true`, and `min_value=0.0` (`lib/trenino/hardware/ht16k33/params.ex:20-29`), which the legacy form uses for a new module (`lib/trenino_web/live/components/i2c_module_form_component.ex:11-14`). Repro: add a display with untouched advanced settings. Letter-capable rendering becomes numeric-only, alignment flips, and negative values are no longer clamped to zero. Align both UI initialization and Rust create fallback with the retained defaults, then update the default-payload regression (`tauri/ui/tests/configuration-edit.test.ts:234-243`).

### 3. The I²C form rejects a valid unnamed module

`i2c-module-form.svelte:44-56` requires nonempty Name and returns before sending Save. Legacy `I2cModule.changeset` does not require `:name` (`lib/trenino/hardware/i2c_module.ex:44-52`), and Rust storage only limits a supplied name to 100 characters (`crates/trenino-runtime/src/storage/hardware.rs:1125-1129`). Thus an unnamed display that can be created or edited in the retained workflow cannot be created or cleared through the recovered UI. Send `name:null` for blank input and leave the field optional; add a create/edit regression for clearing a saved name.

## Reviewed paths without another finding

- `ConfigurationEdit.svelte:356-368` forwards the full typed params to create/update. `rust_ui.rs:2171-2195` maps the complete object and uses stored params when omitted on update (`app.rs:1079-1109`). A blank minimum explicitly becomes null, and a Rust validation error keeps the editor open. Tests at `configuration-edit.test.ts:261-298` cover six fields, clearing minimum, and failure retention.
- `App.svelte:375-383` marks list cards by the live `active_train_id` and shows an unmatched full detected identifier. `TrainEdit.svelte:65-66,171-176,418-427` uses the live ID for its active badge and identifier capture. Status prop changes do not reseed dirty header fields; `reloadTrain(true)` also preserves them. The fail-open delete path above is the exception.
- `TrainEdit.svelte:357-360,479-482` prevents a normal section-link click from changing the SPA hash and scrolls to the requested section. `SettingsEdit.svelte:50-66` updates the saved-key indicator from Rust's acknowledged snapshot and clears the secret. `Firmware.svelte:108-112,238-249,465-472` handles null file size and duration without showing `nullms`.
