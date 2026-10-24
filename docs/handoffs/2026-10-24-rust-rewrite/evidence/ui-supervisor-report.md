# UI supervisor report

Date: 2026-10-24. **Verdict: changes requested for the shell/bridge slice. The two required independent reviews are complete.** This is not acceptance of full UI parity or desktop cutover.

## Scope and review independence

Reviewed UI commits `1942935` and `f7c1c4c`, the current UI plan, Rust/shared DTOs, legacy consent/theme/navigation sources, and the UI brief/report/diff. The accepted packaging merge `914fc811` and plan alignment `f9cb3e2` are the baseline: stable app updates remain native Help → Check for Updates, with no duplicate legacy application banner; firmware notification remains independent. Full Rust runtime shutdown integration is a later platform gate.

After an independent supervisor source audit, two fresh `gpt-6-sol` / `high` reviewers ran sequentially. Each received the same scope and requirements, without the supervisor notes or the other review:

- `ui-correctness-review.md`: structured failures, stale route requests, consent bootstrap and system theme.
- `ui-adversarial-review.md`: stream recovery/buffering, malformed envelopes, error handling and route races; separately identifies integration contracts.

The original reviewer priorities are retained in their reports. The supervisor classifies the actionable findings below as **P2** in this intentionally unintegrated static-shell slice. They should be corrected before treating this foundation as accepted; they do not demonstrate a current hardware fault or packaged-service failure. No production code, running user application, hardware, accounts or installed resources were modified. Only review artifacts and a removed isolated probe were written.

## Required corrections

### 1. P2 — Preserve structured Rust failures

`tauri/ui/src/bridge/client.ts:27-33`, also `59-74`.

Every rejected invoke becomes a fabricated retryable `unavailable` failure, even when Rust returned the agreed `UiFailure`. A failed consent save therefore loses its actual code, display message, field errors and retryability. Both independent reviewers identify this. Validate and preserve the known safe failure shape; use the generic fallback for unknown/transport rejections. Keep unknown exception details out of the UI. Add focused bridge tests for structured and malformed rejections.

### 2. P2 — Bind async completions to their owning route/request

`tauri/ui/src/app/App.svelte:20-65`.

Only the first settings bootstrap checks the current hash. Later resource loads mutate a shared `loadError` without a request generation or disposal guard. Concrete sequence: start slow configuration load → navigate to Trains → train load succeeds → old configuration load fails; the old failure hides the valid train list. An old success can also clear a newer consent/error message, and leaving/revisiting the same hash defeats a hash-only check. Guard all completions with request/lifecycle identity, keep resource errors separate as needed, and prevent late consent completion from forcing navigation after the user leaves. Verify delayed success/failure, same-route revisit and teardown with deferred promises.

### 3. P2 — Keep the consent gate closed until status is known

`tauri/ui/src/app/App.svelte:23-37` and the route-dependent rendering.

A failed settings bootstrap is ignored and the requested list is still fetched/rendered. An unset user can reach normal routes if the settings call fails while another command succeeds. The requested route is also rendered while its consent check is pending. Show a pending/unavailable gate with retry until Rust establishes the consent state; do not use an error as consent. Preserve access to the consent choice itself and the explicit unavailable state when no desktop host exists. Verify failed and delayed bootstrap behavior, not just the existing successful-unset redirect test.

### 4. P2 — Recover from initial snapshot failure with bounded work

`tauri/ui/src/bridge/client.ts:52-74`; `tauri/ui/src/bridge/stream.ts:8-13`.

When the first snapshot rejects, `refresh` only reports unavailability. The stream never receives a current snapshot, so later events only accumulate and cannot trigger recovery. Both supervisor and adversarial probes retained all 10,000 pre-snapshot records. Gap events can additionally start arbitrarily many concurrent fetches. Provide deliberate retry/resubscribe behavior, bounded buffering/coalescing with a resync marker, and at most bounded refresh work per subscription. Test failed-first-fetch recovery, a hung fetch/event burst, and cleanup during recovery without contacting a real backend.

### 5. P2 — Preserve the observed high-water mark during resync

`tauri/ui/src/bridge/stream.ts:20-25,39-44`.

The focused adversarial probe installs revision 4, receives revision 6, then installs a revision-5 snapshot; revision 6 was discarded and the result settles at 5. The same clearing occurs when buffered replay first encounters a gap. The demonstrated fact is loss inside the stream abstraction; no existing backend adapter is claimed to produce a lagging snapshot. However, the current contract does not guarantee that every asynchronous snapshot response includes all previously observed events. Retain bounded newer observations or a high-water mark and keep recovery pending until authoritative state covers it. Serialize/coalesce resync requests. Alternatively, a stronger backend guarantee would need to be explicit and tested before relying on it. Verify a lagging snapshot and a later successful catch-up, including epoch changes.

### 6. P2 — Validate stream envelopes before arithmetic/state installation

`tauri/ui/src/bridge/stream.ts:10-23,31-39`; `tauri/ui/src/bridge/client.ts:52-56`.

Malformed epoch/revision strings throw from `BigInt` through the event callback. Supervisor and adversarial probes independently reproduced `SyntaxError`. The first snapshot is installed without even the checks applied to later snapshots and can poison subsequent processing. Validate the expected topic and counter wire shape/range at the IPC boundary, reject malformed envelopes as a controlled stream fault, and recover without leaking a callback exception. This is transport validation, not moving domain rules into TypeScript. Preserve exact valid-u64 support: the supervisor verified that `18446744073709551614` → `18446744073709551615` applies losslessly.

### 7. P2 — Preserve live system-theme behavior

`tauri/ui/src/main.ts:5-16`.

System preference is resolved once to explicit light/dark. The app never listens for OS theme changes, so an open app stays on the old palette. Legacy `root.html.heex` removes `data-theme` in system mode and lets CSS media rules react. Restore that behavior or observe `matchMedia` changes only while preference is system. Confirm explicit light/dark remain stable and invalid saved values fall back consistently. This was independently identified by both reviewers and the supervisor.

### 8. P2 — Make generated declaration drift fail verification

`crates/trenino-core/src/ui.rs:162-181`; UI scripts/CI integration.

The purported generation test only exports into tracked source files. Stale committed declarations do not fail the test; they are silently replaced, while a standalone frontend build can consume the stale versions. Generate to a temporary location and compare against checked-in outputs, or provide an explicit generator plus a non-mutating check/CI gate. Verify that a deliberately stale fixture fails and the normal check leaves tracked files unchanged. Current fields match the inspected Rust wire types; this finding is about the missing drift check, not an observed type mismatch. No arbitrary ts-rs dependency optimization is required.

## Adjudicated integration contracts and nonblocking observations

- **Error redaction boundary:** the adversarial reviewer flags `From<AppError>` copying message/field strings. That is true, but no implemented command/provider currently constructs a secret-bearing AppError and sends it through this conversion. It is not evidence of a present secret leak. Before commands are wired, establish that AppError is already display-safe or classify/redact at the adapter; test secret-bearing internal errors. The settings DTO exposes only API-key configured status, not key material. Preserve safe failures while fixing item 1; do not expose arbitrary exception strings.
- **Epoch identity:** numeric ordering assumes epochs increase across restarts. No generator exists here and the plan only specifies changed runtime identity. Define/test monotonic restart-safe allocation or change reconciliation to work with opaque epoch identities. Do not claim random/lower epochs are already used by a backend.
- **Subscription ownership:** define per-window reference counting or explicit subscription IDs for multiple same-topic consumers. Topic-only unsubscribe must not detach another observer. Also settle early-unmount ownership while `subscribe()` is awaiting startup, idempotent teardown and suppression of callbacks after disposal. The backend is not implemented, so a concrete same-topic backend failure is not established by this slice. Unsubscribe correctly remains distinct from operation cancellation.
- **Presentation:** consent wording and palette were copied, and Escape returns focus from the device menu. Exact icons, click-away closure, all dialog focus/keyboard behavior, responsive/high-DPI appearance and screenshot parity still need the later retained-UI gate. The new shell uses placeholder glyphs and has no menu click-away handler; do not describe this as completed visual parity.
- **Types:** numeric positive-i32 ConfigId remains distinct from decimal-string EntityId and u64 counters. Current topic/error union overrides agree with Rust. Their handwritten `ts` overrides need coverage when the shared enums change.

## Verification and remaining delivery gates

The implementer/root previously reported Rust UI tests 3/3, Vitest 10/10, Svelte check/build successful, npm audit 0 after Vitest 4.1.12, and root Rust tests 70/70. The supervisor did not repeat those broad runs. The adversarial reviewer ran three isolated focused assertions reproducing gap-state loss, 10,000 buffered records and malformed-counter throw, then removed the probe; the supervisor independently checked valid-u64 handling, malformed epoch and unbounded bootstrap storage with Node. Final inspection found no leftover probe in `tauri/ui/tests` and no tracked working-tree changes at report time.

After corrections, run focused bridge/route/theme/generated-type regression checks and the normal UI check/test/build once. Real Tauri commands, AppServices snapshot publishing, live subscription consumption, service-backed screens/forms/wizards, runtime operation attachment, firmware notices, packaged static-asset loading and supported-WebView screenshots remain explicitly unimplemented integration gates. App currently does not subscribe, consistent with its declared static/read-only scope. Retain the native stable updater policy; verify acknowledged Rust quiescence and install sequencing in the platform integration, not by adding frontend update logic.
