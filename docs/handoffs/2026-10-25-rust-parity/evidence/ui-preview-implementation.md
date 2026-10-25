# Rust-owned UI preview implementation (2026-10-25)

## Implementation

- Added `crates/trenino-runtime/src/preview.rs` with read-only, typed input, notch, display and output previews. Input previews load `max_hardware_value` and calibration extremes from the single SQLite worker, then use `trenino_core::hardware::calibration` and the existing vJoy `axis_value` mapper. The configuration screen now shows calibrated travel units, matching `configuration_edit_live.ex`, rather than the sibling's 0–1023 approximation. VJoy preview uses the Rust axis mapper's 0–100 result.
- Notch previews require the Rust calibration service's `MIN_SAMPLE_COUNT` per captured range, validate calibrated bounds, and use the existing `detect_inversion`/`calibrated_to_normalized` helpers (made public narrowly in `simulator/services/calibration.rs`). The lever wizard saves the returned normalized ranges/inversion; it no longer computes them in TypeScript. Auto-distributed ranges continue to come from the persisted Rust repository result.
- Display previews load the selected persisted module's digit count, dot support and minimum value, then use core `clamp_to_min`, `validate_display_format_string` and `format_display`. Output condition previews call a shared `validate_output_condition` extracted from the persistence validator in `storage/domain/bindings.rs` and core `evaluate_output` for an example. The wizard save buttons wait for valid Rust responses, and output save rechecks the current draft before mutation.
- Added `tauri/src-tauri/src/runtime_preview.rs` with `ui_calibration_ceiling`, `ui_preview_input`, `ui_preview_notch_mapping`, `ui_preview_display`, `ui_preview_output_condition`; `runtime_composition` registered these in `rust_ui.rs`. That agent also changed `ui_start_calibration` to derive the ceiling server-side while retaining its wire argument. The UI requests the Rust ceiling before starting and no longer contains a 1023 ceiling constant.
- Removed TypeScript calibration math and display formatting/validation. `collectHardware` asks Rust whether saved analog calibration is usable before offering it. Async UI previews discard stale responses and show service errors. Fixed form label associations, keyboard capture focus warning and state initialized from reactive props, without warning suppressions or visual redesign.

## Verification

- `npm --prefix tauri/ui run check`: **0 errors, 0 warnings**.
- `npm --prefix tauri/ui test`: **9 files, 105 passed**. New cases cover server ceiling, delayed/stale input and display previews, preview unavailable state, and saving Rust notch ranges.
- `npm --prefix tauri/ui run build`: passed, 139 modules transformed.
- `cargo test -p trenino-runtime preview --lib --quiet`: **3 passed**, including persisted 4095 rollover calibration, sampled notch mapping, display minimum/dot/overflow, and condition validation.
- `cargo test -p trenino-runtime --test domain_bindings --quiet`: **26 passed** after shared validation extraction.
- `cargo check --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui --quiet`: passed. At the time of check a concurrent `rust_ui.rs:3042` unused `Result` warning was present; reported to `runtime_composition` owner.
- `rustfmt --edition 2021 --check` on owned/new preview and narrow shared helper files: passed. Whole-workspace `cargo fmt --all --check` currently reports unrelated unformatted concurrent WIP; no broad formatting was applied.

## Scope and remaining integration

- No physical device, simulator, WebView IPC, Windows vJoy, or packaged desktop acceptance was run. The UI tests use fake bridges and the Rust tests use a disposable SQLite database.
- The five Tauri commands are registered, but full desktop behavior depends on the concurrent composition work. Connected-device inventory and simulator status/retry commands now exist on that track and need a separate UI workflow integration pass.
- Each live input preview is a SQLite worker read. The UI discards stale answers, but high-rate hardware streams may warrant a backend cache or throttling after measured hardware acceptance.
- The explicit notebook/endpoint explorer and detection UX remains outside this preview chunk. `formatDecimals`/`decimalsFormat` remain in TypeScript solely to present the decimal selector; Rust validates and renders every format.

No commit was created. Existing unrelated uncommitted work was preserved.

## Round 1 review fixes

- Mapped lever Continue now reads binding state and moves to capture without writing the lever, binding, or saved notch ranges. Auto-distribution is also a read-only Rust preview; Save mapping performs the backend writes. Cancel, Back, conflict, preview failure, and automatic preview leave persisted ranges alone. The wizard now rechecks the Rust preview at Save and provides working “Finish anyway” behavior for backend-reported gaps.
- Completing an output or other child wizard reloads train detail while retaining unsaved name, description, and identifier edits in the parent train form.
- A successful `ui_run_script` transport response containing `false` now reports the script as unavailable; it does not announce that execution started or refresh the log.
- Failed `validateNotches` transport after saving retains the mapping draft and shows the error. The wizard remains open for retry; it never calls `onComplete` on that failure.
- Fresh calibration uses the legacy hardware default ceiling of 1023 in Rust (`FRESH_CALIBRATION_CEILING`), matching the old calibration start path. Persisted hardware metadata still overrides it, including 4095; the Rust oracle test covers both cases. The UI contains no ceiling default.

### Follow-up verification

- `npm --prefix tauri/ui run check`: 0 errors, 0 warnings.
- `npm --prefix tauri/ui test -- --reporter=dot`: 9 files, 111 passed. New regressions cover no writes before mapped lever Save (including conflict and auto-distribute), retained dirty train header, false script acknowledgement, validation transport failure and retry.
- `npm --prefix tauri/ui run build`: passed, 139 modules transformed.
- `cargo test -p trenino-runtime preview --lib --quiet`: 3 passed, including read-only auto-distribution and fresh/persisted calibration ceilings.
- `cargo check --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui --quiet`: currently blocked by a concurrent `runtime_hardware.rs:52` ambiguous `Result` error (`E0282`/`E0283`). Reported to the owning agent; no change was made to their file.

The mapped lever Save remains a sequence of backend calls, so a failure after binding can leave partial writes while the wizard stays open. An atomic backend operation would be needed to prevent that partial state; this review specifically verified that no persisted notch ranges change before Save mapping.
