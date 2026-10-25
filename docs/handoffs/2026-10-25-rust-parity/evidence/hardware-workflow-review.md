# Hardware workflow backend adversarial review — 2026-10-25

## Verdict

**Backend packet/apply and raw-port handoff paths are substantially aligned; full desktop workflow is not yet reachable.** This is a source review of `hardware/plan.rs`, the service/scanner changes, `runtime_hardware.rs`, and `runtime_upload.rs`. I did not rerun the reported configuration-plan, hardware, and service suites or test physical serial devices. The frontend bridge and controls for the new commands are the next planned integration chunk, per root.

### Important — terminal configuration results permanently consume the operation capacity

- `crates/trenino-runtime/src/hardware/service.rs:923-930` refuses new configuration operations once `operation_results.len() >= MAX_OPERATIONS` (1024). A finished result is retained until `take_configuration_result` removes it (`:1082-1112`). The desktop `ui_configuration_status` calls the non-consuming `configuration_result` (`tauri/src-tauri/src/runtime_hardware.rs:41-52`), and no desktop path consumes or evicts a terminal result.
- Repro: complete and poll 1024 configuration applications in one process. Every later `ui_begin_apply_configuration` returns `configuration operation capacity reached`, even though all workers finished and each operation was reported complete/failed. The affected port need not be the same on every run.
- Keep a bounded terminal-history policy that preserves retryable status for a short period, or consume a terminal result only after desktop publication has succeeded and provide an idempotent short cache. Test repeated terminal polling and the 1025th operation.

## Checked implementation boundaries

- `hardware/plan.rs:9-38` takes the committed device `config_id`, uses only physical inputs for ConfigureAnalog/ConfigureButton packets, includes virtual matrix pins in resolver mappings, orders matrix row/column pins by persisted position, and delegates packet part numbering/validation to core `build_configuration`. The targeted plan test covers one physical button plus matrix virtual pins.
- `runtime_hardware.rs:26-36` validates the live port/generation again immediately before `begin_configuration`; `ui_configuration_status` reports `pending`, `complete`, or `failed` from the owned operation instead of equating queue acceptance with application success (`:39-57`). A DB snapshot error after completed application is surfaced, not silently treated as success.
- `hardware/service.rs:502-510` checks the shared atomic stop fence before and after taking the scanner lock. It does not reenter the admission mutex from resource-arbiter callbacks, avoiding the callback deadlock fixed in this chunk. Shutdown sets the atomic before scanner close (`:1115-1134`), and admitted sends hold the scanner lock until their bounded result.
- Manual disconnect checks the current connected generation and active lease, neutralizes the source, then requests an acknowledged scanner close (`hardware/service.rs:601-612`; `hardware/mod.rs:500-504`, `:807-823`). Wrong-generation calls fail without closing a newer owner. Failed close returns an error instead of success; scan/backoff still controls rediscovery.
- `runtime_upload.rs:89-113` accepts an explicitly enumerated generation-zero port. The scanner serializes handoff with owner changes: an open owner with a nonzero generation takes the mismatch branch; only a still-enumerated port with no scanner owner takes the generation-zero reservation path (`hardware/mod.rs:850-899`). Lease authorization is checked at handoff time. The upload adapter retains acquisition/release operation state for retry after timeouts (`runtime_upload.rs:115-180`).

## Pending desktop integration

- `ui_serial_ports`, `ui_scan_devices`, `ui_disconnect_device`, `ui_begin_apply_configuration`, and `ui_configuration_status` are registered in `rust_ui.rs:731-735`, but there are no matching methods in `tauri/ui/src/bridge/client.ts` or user controls yet. The next frontend wiring chunk must make these commands reachable and test apply/poll/disconnect through IPC.
- A raw board cannot emit the identified hardware input event that currently populates `App.svelte`'s `liveHardware` (`:126-130`). `Firmware.svelte:174-205,552` still requires that prop to enable Start Upload. It must select the generation-zero entry from `ui_serial_ports` for blank-board firmware recovery; the backend handoff alone does not make that workflow reachable.
