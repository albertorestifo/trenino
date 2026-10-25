# Stage 1 hardware and simulator UI adversarial review (2026-10-25)

## Verdict

Stage 1 is substantially wired to the owned Rust services: serial inventory and input events are gated by config/port/generation, apply waits for an operation result, firmware exposes generation-zero ports and checks inventory after download, simulator browsing uses the accepted client, and manual hardware tests return transport results. I found two actionable Important defects. This is a code review, not a physical WebView/device/simulator smoke test; I did not rerun the reported suites.

## Important findings

### 1. A transient apply-status read error becomes a terminal UI failure

`tauri/ui/src/app/App.svelte:191-203` sets an operation's state to `failed` whenever `configurationStatus` returns an IPC error. The poller then skips every non-`pending` operation at line 193. This is different from a backend terminal `state: 'failed'`: the Rust operation may still be running or may already have succeeded. For example, start apply, have `ui_configuration_status` fail once because its `list_configurations()` snapshot fails after the hardware worker completed (`tauri/src-tauri/src/runtime_hardware.rs:44-56`), and restore the DB. The UI permanently shows failure, enables another Apply, and never reads the original terminal result. A one-off IPC/DB error while the worker is pending has the same effect. Keep the operation pending with a visible status-read error and retry its ID; only the backend's terminal state should end polling. Add a test where the first status call errors and the next returns `complete`.

### 2. Manual output/display actions do not bind to the connection shown when clicked

`tauri/ui/src/app/pages/configuration/ConfigurationEdit.svelte:332-345` only sends an output/module ID; `activePort` and `activeGeneration` only enable the controls at lines 587 and 618. The desktop commands in `tauri/src-tauri/src/runtime_hardware.rs:65-91` reread the saved config and resolve whichever port currently owns its config ID, without accepting or checking the port/generation shown to the user. Reproduction: show configuration C active on board A, click HIGH (or Test display), and have A disappear while C is activated on board B before the Rust task resolves the port. The command can acknowledge after actuating B even though the click was on A's view. The transport fences a generation once chosen, but it cannot recover the user's original target. Pass the selected port/generation through IPC, verify that exact live owner still has the expected configuration before dispatch, and reject stale actions. Test a config moving to another port between UI click and command handling. The legacy LiveView used its displayed `active_port` for manual output/display dispatch (`lib/trenino_web/live/configuration_edit_live.ex:391-398,452-457`).

## Scoped backend fix checks

- **Operation history:** `crates/trenino-runtime/src/hardware/service.rs:919-949` reaps finished workers and evicts the oldest terminal, unowned result before admitting more operations. It does not evict pending or still-owned work. The new 1026-operation regression at `crates/trenino-runtime/tests/hardware_service.rs:2195-2208` covers the former lifetime admission cap. The 1024-entry result retention is bounded; an old terminal ID can expire, which is compatible with a recent-history policy.
- **Database close:** `crates/trenino-runtime/src/storage/mod.rs:226-254` closes shared admission under `tx` lock, leaves already queued requests to drain, and retains the join handle on timeout so a clone can retry. Requests hold `tx` only through the bounded-queue send (`:435-445`), so a queued request can still finish after admission closes. The timeout/retry regression at `:1225-1250` checks retained ownership, clone rejection, queued commit, and reopen. No new concrete close defect found.

## Other reviewed paths and boundary

`Firmware.svelte:177-220` retains its port/generation through download and refuses a changed inventory generation before upload; the Rust upload request carries the same generation. `EndpointBrowser.svelte:18-49` fences overlapping local list/value replies and surfaces bridge errors; on component unmount a late promise only updates the abandoned component state and cannot call `onSelect`. `runtime_simulator.rs:100-129` uses the accepted `LiveSimulator`/bounded IO bridge; its slash node and dot endpoint paths match the legacy explorer. Guided detection, sweep, and atomic lever mapping are explicitly the next chunk, not stage 1 regressions.
