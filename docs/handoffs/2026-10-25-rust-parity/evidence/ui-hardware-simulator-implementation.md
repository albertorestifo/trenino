# Hardware and simulator UI integration, stage 1 (2026-10-25)

## Delivered

- `tauri/ui/src/bridge/client.ts` now has typed IPC methods for the authoritative serial inventory, explicit scan/disconnect, configuration apply start and status, simulator status/retry and endpoint inspection, plus manual output and display tests. Wire payloads follow the desktop commands' `snake_case` argument annotations.
- `tauri/ui/src/app/App.svelte` uses `ui_serial_ports` for active-device status and configuration input events. An input event is accepted only for a matching connected port, generation and config ID. Inventory loss, failure or generation replacement clears stale readings and revokes active UI. The Devices page exposes scan, disconnect, and port selection for each configuration. Apply keeps the selected generation, starts the backend operation, and polls until its real `complete`/`failed` status; no success is inferred from enqueue. Status failures remain visible. `Navigation.svelte` shows the actual simulator status and offers Retry.
- `tauri/ui/src/app/pages/firmware/Firmware.svelte` lets the user select from all inventoried serial ports, including an unconfigured board with generation 0. It retains the chosen port/generation through the download and rechecks the inventory immediately before upload. A changed generation stops the upload with an error.
- `tauri/ui/src/app/pages/configuration/ConfigurationEdit.svelte` exposes manual HIGH/LOW output actions and display text tests when the associated device is connected. It reports backend acknowledgements and errors, without inventing a current output level.
- `tauri/src-tauri/src/runtime_simulator.rs` adds `ui_list_simulator_endpoints` and `ui_get_simulator_value`. Both use the accepted `ControlRuntime.simulator` and its bounded `SimulatorPort` IO bridge, not a new HTTP client. Listing converts legacy `Nodes`/`Endpoints` to typed node paths (slash) and endpoint paths (dot). `runtime_composition` registered both commands in `rust_ui.rs`.
- `tauri/ui/src/components/EndpointBrowser.svelte` provides browse, search within a level, current-value preview and selection. It discards stale responses and keeps manual text entry available. It is used by lever, button, output and display wizards, script triggers, and sequence commands.

## Verification

- `npm --prefix tauri/ui run check`: 0 errors, 0 warnings.
- `npm --prefix tauri/ui test -- --reporter=dot`: 10 files, 121 passed. New cases cover scan/apply terminal status, failure, disconnect generation 0, inventory loss and generation replacement, simulator status/retry, endpoint browse/value/stale replies, firmware generation change across download, manual output/display calls and IPC payloads.
- `npm --prefix tauri/ui run build`: passed, 140 modules transformed.
- `cargo test --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui runtime_simulator --lib --quiet`: 1 passed, checking path construction against the legacy slash/dot rules.
- `cargo check --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui --quiet`: passed.
- `rustfmt --edition 2021 --check tauri/src-tauri/src/runtime_simulator.rs`: passed after formatting.

No physical device, running simulator, firmware upload, or packaged desktop smoke test was run. No commit was created. Shared unrelated work was preserved.

## Stage boundary and backend contract for guided sessions

Stage 1 delivers inventory/apply/firmware selection, status/retry, manual actuation and endpoint browsing. Guided control detection and automatic lever sweep still need a backend session host. The existing Rust services already contain the domain behavior: `simulator/services/control_detection.rs` discovers writable controls, subscribes to changes, reports ambiguous sets and times out after 30 seconds; `lever_analysis.rs` sweeps and classifies with `trenino_core::calibration::analysis`; `calibration.rs` implements the legacy automatic notch sweep and mapping checkpoints. The old UI exposes detection in `lib/trenino_web/live/components/auto_detect_component.ex` and `lever_setup_wizard.ex`, then offers automatic calibration with manual skip.

Suggested typed IPC, with session IDs retained by a desktop host rather than by Svelte:

1. `ui_start_control_detection() -> {session_id}`; `ui_control_detection_status(session_id) -> {state:'listening'|'detected'|'timed_out'|'failed'|'cancelled', changes:[{endpoint,control_name,previous_value,current_value}], ambiguous, remaining_ms, message}`; `ui_cancel_control_detection(session_id) -> bool`. Terminal results remain readable long enough for the UI to choose among multiple controls. The host owns subscription cleanup and cancellation when the accepted simulator connection changes.
2. `ui_start_lever_analysis(control_path, restore_position?) -> {session_id}`; `ui_lever_analysis_status(session_id) -> {state:'running'|'complete'|'failed'|'cancelled', result?:{lever_type,suggested_notches,...}, message?}`; `ui_cancel_lever_analysis(session_id) -> bool`. Rust derives candidate notches and fills draft fields; the UI only presents the result for review. The session must use the accepted `StatusSnapshot.client`, the existing clock and resource arbiter, and stop on connection replacement.
3. If the intended legacy behavior is the full automatic notch sweep, add `ui_start_lever_calibration(element_id,input_id,port,generation,endpoints) -> {session_id}`, status with `CalibrationProgress` and terminal `CompletedCalibration`, and cancel. This also needs a production `CalibrationStore` adapter and an explicit decision about when config/notch persistence commits. The UI should show progress, result and manual skip without calculating notch rules.

The current mapped lever Save in `LeverSetupWizard.svelte` calls `ui_preview_notch_mapping`, then `ui_create_lever` (if new), `ui_bind_lever`, `ui_save_notches`, `ui_update_lever` and `ui_validate_notches`. A later call can fail after earlier writes. Replace this with one Rust transaction command such as `ui_commit_lever_mapping({element_id,lever_config_id?,input_id,replace_binding,endpoints,notches,captured_ranges,auto_distribute}) -> {train_detail,validation}`. The backend should reload the persisted input calibration, recompute normalized ranges/inversion with the same Rust preview helper, validate conflicts and notch ranges, and commit lever creation/binding/notches/inversion as one DB transaction. The UI should call `onComplete` only after this command's terminal acknowledgement; invalid-but-saved gap behavior needs an explicit backend result policy.
