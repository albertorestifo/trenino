# Calibration lease ownership repair — scoped adversarial review

## Verdict

**Original Important finding 4: ADDRESSED for lease ownership and truthful cleanup ACK.** The registry retains the exact `(session ID, token)` until `ResourceArbiter::release` succeeds, a failed resume permits only that token to retry, and cancel, terminal advance, firmware takeover, failed registration, and later admission all have a path to the retained owner. A repeated terminal advance returns its recorded result after release. The UI keeps its session ID and dialog on cancellation error and closes on `Ok(true)` or `Ok(false)`. No false success or wrong-token release was established in those paths.

**Integration verdict: changes still required.** One new Important partial-resume problem can actuate simulator controls while the calibration/firmware lease is still active. The physical output gate remains closed on a failed callback, but the lever and button workers do not share that final gate.

## Important finding

### A failed final resume can leave simulator lever/button effects active under a retained lease

`AppHardwareConsumers::resume_after_fresh_sample` in `tauri/src-tauri/src/rust_ui.rs:1044-1059` ACKs `lever.resume_port` and `buttons.resume_port` before calling `controls.hardware_resumed()`. The latter can return `Err` when `OutputController::devices_updated` or `DisplayController::invalidate_hardware` cannot enqueue (`crates/trenino-runtime/src/train/output_controller.rs:174-177`, `display_controller.rs:153-156`). `resume_suspended_port` correctly retains the physical output gate on that error (`rust_ui.rs:1063-1070`), and the arbiter retains the original lease/fail-closed state (`crates/trenino-runtime/src/resource.rs:355-371`). However, the two controller workers have already removed their own `suspended_ports` entries (`lever_controller.rs:620-622`, `button_controller.rs:786-788`). Subsequent hardware input is still forwarded to those workers even when `suspended && arbiter.is_suspended()` (`rust_ui.rs:1094-1138`); their sample handlers then accept the port (`lever_controller.rs:670-685`, `button_controller.rs:844-859`). These workers can issue simulator writes or native key effects independently of the physical output gate. A failed retry leaves the same exposure until the final callback succeeds.

**Reproduction/test idea:** With an active train and a mapped hardware lever/button, acquire a calibration lease, then fail only the final `hardware_resumed()` callback after both per-port resume ACKs (for example, make the output `try_send` return `Full` while the control runtime still runs). Assert that `arbiter.is_suspended()` remains true and a fresh input sample on that port produces no simulator write or native key event. The current call order and dispatch path permit those effects. Repeat while the failure persists and after a successful cleanup retry. A shared admission fence in `dispatch_port_input` or a compensating re-suspend of already resumed consumers needs to keep all effect paths closed until the aggregate resume ACK.

The same dispatch guard matters when initial suspension partially fails: `suspend_actuation` returns early on a lever ACK failure before suspending buttons (`rust_ui.rs:962-991`), while the arbiter fail-closes acquisition (`resource.rs:277-300`). A button worker that is still live can receive subsequent samples through the same unconditional dispatch path. This is an additional way to exercise the same missing consumer-wide fence.

## Other scoped checks

- `ResourceArbiter::release` rejects stale/wrong tokens before changing state and permits fail-closed retry only for `failed_resume == Some(token)` (`resource.rs:319-343`). New lease acquisition remains fenced during failure (`:212-220`).
- `release_calibration_lease` verifies the exact registry entry, calls `release`, and removes that same entry only after success (`hardware/service.rs:241-270`). Registration happens before session insertion, so a failed insertion with a failed release remains discoverable by ID (`:919-965`).
- `retry_terminal_calibration_cleanup` is run before new calibration or firmware admission and skips healthy nonterminal sessions (`hardware/service.rs:762-785`, `:919-949`). The public admission mutex serializes those two paths. The terminal advance path records its result before release and retries without persisting twice (`:976-1015`, `hardware/sessions.rs:357-375`).
- The wizard retains the same ID and shows **Retry cancel** after rejected/thrown cleanup; its duplicate close actions are ignored while cancellation is pending (`tauri/ui/src/components/calibration-wizard.svelte:97-120`, `:179-184`). On route destruction it makes a best-effort call; retained backend ownership plus later admission recovery handles an error after the listener disappears.

The owner's reported hardware 21, resource 7, upload 36, desktop fence 1, and UI 165 green checks were not rerun here. This was a source and diff review; no physical hardware or native output was exercised, and no source files were edited.
