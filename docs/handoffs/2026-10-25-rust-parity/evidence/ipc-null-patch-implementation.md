# IPC nullable patch and display metadata repair — 2026-10-25

## Wire semantics

Added `tauri/src-tauri/src/wire_patch.rs` with `NullableArg<T>`, a custom Tauri `CommandArg` implementation. It reads the actual InvokeBody key and distinguishes missing (`None`, preserve), JSON null (`Some(None)`, clear), and supplied value (`Some(Some(value))`, replace). It deliberately does not derive serde Deserialize, which would collapse missing/null again. Invalid supplied values continue through Tauri's InvalidArgs rejection.

All former top-level `Option<Option<T>>` arguments in rust_ui are replaced with this extractor: configuration/train description; lever count/index/type; all seven nullable notch numeric fields; output thresholds; display binding name. Bodies unwrap into the existing storage patch types. The command and publication return contracts remain unchanged. `publishing_command` and `publish_change` are now generic over Tauri Runtime solely to enable actual generated-handler tests with MockRuntime; root's canonical publication behavior is retained.

The button command also uses presence-aware endpoint, keystroke and on/off-sequence fields. New `AppServices::put_button_binding_patch` forwards the precise patch, rounds values, and retains existing atomic conflict/replacement behavior. Creation uses normal defaults for omitted nullable values. Existing non-IPC `put_button_binding` remains a compatible draft adapter. Omission leaves existing nullable fields unchanged; explicit null clears them. No blanket overwrite of omitted fields was introduced.

## I2C metadata and parameters

Create/update commands accept optional `params: Ht16k33ParamsView` with brightness, num_digits, display_type, has_dot, align_right and min_value. Explicit objects replace the full parameter object; `min_value:null` is a real clear. The Rust converter validates display_type as seven_segment/fourteen_segment; storage retains numeric/chip/address validation.

Update with absent/null params preserves stored parameters, including a stored null minimum. Metadata-only name/address edits no longer reset digit count/type/brightness/formatting. Create with absent/null params uses the verified Elixir `lib/trenino/hardware/ht16k33/params.ex` defaults: brightness 8, four digits, fourteen segment, no dot, right alignment, minimum 0.0. Explicit provided parameters are not replaced by defaults. Surface agent received the exact wire payload and completed its controls separately.

## Scoped desktop train deletion guard and error codes

At root's follow-up request, ui_delete_train now reads the live ControlRuntime train snapshot in its mutation job before deleting. It rejects the active ID with a typed conflict and rejects unavailable/stopping control state with unavailable, preserving the row. This is a desktop command guard; generic storage/MCP behavior is unchanged. **Limitation:** there is no transactional actor/DB deletion gate in the existing API; detection can change after this snapshot check. The implementation does not claim an atomic fence against that later transition.

The vJoy configurator timeout and manual-sequence deadline now use the existing supported `unavailable` UiFailure code with their original message/retryable flag. They no longer emit undeclared `timeout`, which the bridge discarded into a generic fallback.

## Executed evidence

Actual generated Tauri handlers were invoked through `tauri::test::get_ipc_response`, using snake_case payloads and disposable SQLite. These are not UiBridge return mocks.

- Configuration description clear was behaviorally RED: native handler returned success while SQLite retained `original`. Presence-aware extraction made missing preserve and explicit null clear for both configuration and train descriptions.
- Existing button off-sequence clear was behaviorally RED (old ID retained). Native command tests now cover omitted preservation and explicit clears of endpoint, keystroke and both sequence IDs while switching valid binding modes.
- I2C metadata-only edit was behaviorally RED (eight-digit/fourteen-segment parameters replaced by four-digit/seven-segment defaults). Native tests now verify preservation, explicit full replacement, min_value null, creation with explicit params, invalid brightness/type rejection, and metadata update with params:null.
- Legacy omitted-create defaults were separately RED, then GREEN after matching params.ex.
- Native delete invocation without control runtime was RED (record deleted), then GREEN (typed unavailable and record retained); pure guard tests reject the live active ID and allow other/no active profile.
- Remaining nullable commands are exercised through real Tauri dispatch: lever fields, every nullable notch field, both output thresholds and display binding name. Omitted fields retain values and unrelated required fields remain unchanged.
- Runtime control regression `clearing_stored_release_sequence_prevents_its_execution_after_reload` uses actual AppServices/storage, DbTrainConfigSource, ButtonController and scripted loopback simulator. It observes Open then Close before the patch, then only Open after the off-sequence clear and configuration reload: no old release PATCH executes.

Validation before final rerun: runtime app_services **19**, domain_bindings **26**, control_dispatch **32** passed; strict runtime library clippy passed. The targeted native wire suite **7** passed; desktop full-suite result after final assertions is recorded below. No source changes to the user database, no physical hardware activity, no commits, no subagents.

Final desktop validation: `cargo test --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui --lib --quiet` passed **30/30**, including seven new actual-wire/guard tests and root's preview/canonical-publication regressions. Runtime targeted suites and strict clippy above remain passing; the last runtime changes preceded those checks. Ready for independent review.

## Follow-up: atomic I2C omitted-parameter merge

Addressed the Important concurrency finding in `tmp/ipc-null-patch-review.md`. `AppServices::update_i2c_module` no longer reads `hardware_snapshot` and copies params into a later update. It passes the optional params unchanged and obtains the owning device from the committed mutation result. `storage::hardware::update_i2c_module` now reloads the current module row, merges omitted params, validates the resulting draft and writes it inside one `hardware_tx` transaction on the existing database worker. Explicit full replacements still replace all fields, including a null minimum; invalid replacements roll back without changing metadata or params.

Added `app::i2c_concurrency_tests::omitted_i2c_params_preserve_concurrent_committed_replacement`. A per-worker, `cfg(test)` pre-dispatch hook pauses the AppServices metadata update immediately before its update request. In the original implementation its separate snapshot had already captured old params. An explicit parameter replacement then commits through a clone of `services.database()` on the same real worker; resuming metadata save must preserve that newer replacement while updating name/address. This is not a second SQLite connection or independent database writer. One AppServices instance serializes its own mutations, so the test specifically models the shared database clients used by other production service paths such as MCP. The hook does not exist in production builds and does not hold the worker queue mutex while paused.

The new regression was behaviorally RED: old brightness 8/eight digits/fourteen-segment/minimum 0 overwrote the committed replacement. The unchanged interleaving is now GREEN with brightness 3/four digits/seven-segment/null minimum retained. It also asserts that an invalid explicit replacement leaves the complete stored record unchanged.

Scoped fresh validation:

- New barrier regression: **1 passed** (`tmp/ipc-i2c-concurrency-red.log`, `tmp/ipc-i2c-concurrency-green.log`).
- Runtime AppServices **19**, MCP storage wiring **12**, hardware storage **6** passed (`tmp/ipc-i2c-scoped-tests.log`).
- Strict runtime library clippy (`cargo clippy -p trenino-runtime --lib -- -D warnings`) passed (`tmp/ipc-i2c-clippy.log`).
- Actual generated desktop I2C handler tests passed, covering omitted legacy defaults, metadata preservation and explicit replacement (`tmp/ipc-i2c-desktop-tests.log`).

No UI changes, no commits, no subagents. Source is ready for fresh scoped review; this follow-up does not change the previously documented live train-deletion snapshot race.
