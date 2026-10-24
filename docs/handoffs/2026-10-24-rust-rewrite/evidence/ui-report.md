# UI coding slice report

Implemented on `codex/rust-rewrite` in the assigned worktree. No commit was created.

## Delivered

- Added a static Svelte 5 + TypeScript + Vite frontend under `tauri/ui`, with Tailwind 4 and daisyUI. The app uses hash routes so static paths can reload without a server route fallback.
- Ported the existing light/dark palette and the max-width navigation shell. The navigation retains Devices, Trains, Joystick, Settings, the connected-device menu slot, and the simulator status slot. Escape closes the device menu and returns focus to its button. The existing `phx:theme` preference and system/light/dark presentation are retained.
- Added the existing consent copy and read-only settings, configuration-list, and train-list presentations. Saved list contents render only from the injected bridge. Production browser/no-command paths display unavailable messages rather than fixture values.
- Preserved `/`, `/trains`, `/settings`, `/consent`, `/firmware`, `/virtual-joystick`, numeric configuration IDs, train query parameters, and `/simulator/config` alias parsing. New, edit, firmware, joystick, and unregistered routes state that their service-backed screens are not integrated.
- Added `crates/trenino-core/src/ui.rs` serializable DTOs. `ts-rs 12.0.1` generates checked declarations under `tauri/ui/src/bridge/generated/`; database IDs and epoch/revision counters stay decimal strings, while checked `ConfigId` remains its shared numeric signed-32-bit type. Settings views include only whether an API key is configured, never its contents.
- Added the typed bridge wrapper and topic stream buffer. It listens before requesting the initial snapshot, buffers up to 128 changes, filters other topics, drops duplicates, requests a snapshot after gaps or epoch changes, retains bounded per-epoch high-water marks across lagging snapshots, and treats `ui_unsubscribe` as observation cleanup only. There is no operation-cancel action in this slice.
- Added route/request generation and component-lifecycle guards to prevent stale loads or late consent responses from changing the current route. Normal routes remain gated until consent is known; a failed bootstrap shows retry and consent choices instead of treating failure as consent.
- Added validated stream envelopes and structured IPC failure decoding. Malformed payloads trigger controlled resync; internal error details are replaced with a generic message. System theme keeps `data-theme` unset so OS theme changes remain live, while invalid saved preferences clear to system mode.
- Redacted internal Rust `AppError` messages and field details when converting them to the UI failure DTO; validation and other display-safe error codes keep their structured details.
- Added Vitest coverage for route aliases/query handling, test-injected shell data, first-run consent gating, read-only settings, consent errors, and buffered/duplicate/gap/restart subscription behavior.

## Tauri contract for the next integration slice

These names are proposed frontend contracts, not registered Tauri commands. The bridge currently receives command-unavailable errors in the desktop app until adapters backed by `AppServices` are registered.

| Command/event | Proposed request and response |
|---|---|
| `ui_get_settings` | `() -> UiSnapshot<SettingsView>` |
| `ui_list_configurations` | `() -> UiSnapshot<ConfigurationSummaryView[]>` with topic `hardware` |
| `ui_list_trains` | `() -> UiSnapshot<TrainSummaryView[]>` with topic `trains` |
| `ui_set_consent` | `{ value: "enabled" | "disabled" } -> UiSnapshot<SettingsView>` |
| `ui_subscribe` | `{ topic: Topic, subscription_id: string } -> Result<(), UiFailure>`; register this observer in this window for subsequent changes |
| `ui_get_snapshot` | `{ topic: Topic } -> Result<UiSnapshot<T>, UiFailure>`; the topic selects the concrete payload type |
| `ui_unsubscribe` | `{ topic: Topic, subscription_id: string } -> Result<(), UiFailure>`; releases only the matching observer, idempotently; it never cancels an operation |
| `ui://change/{topic}` | Event payload is `UiChange<T>` for one shared topic; revisions are contiguous within each topic |

`Topic`, `Epoch`, `Revision`, `ConfigId`, `EntityId`, and `AppError` originate in `trenino-core`; `UiSnapshot<T>`, `UiChange<T>`, summary/settings views, and the sanitized `UiFailure` are in `ui.rs`. `ConfigId` remains a JSON number in the positive signed-32-bit range; `EntityId`, `Epoch`, and `Revision` are decimal strings (the counters accept the full u64 range). The visible configuration list is currently carried as `UiSnapshot<ConfigurationSummaryView[]>` on the shared `hardware` topic. `ConnectedDeviceView` is generated but not currently consumed by this bridge. Future stateful commands must carry opaque operation/session IDs and expected revisions; a separate `ui_cancel_operation({ operation_id })` must stop an operation explicitly. Unsubscribe must never imply cancellation.

## Remaining integration gaps

- UI command adapters and snapshot/change publishers are being implemented in the parallel runtime integration slice; until those adapters are integrated, the proposed commands are not operational. The `tauri/src-tauri/tauri.conf.json` still points `frontendDist` at `../src`, so the normal Tauri package build has not been switched to `tauri/ui/dist`.
- Device scanning/disconnect, simulator status/retry, consent persistence, settings, profiles, train data, banners, MCP prompts, firmware, joystick and all editors/wizards remain unavailable without the later Rust service adapters. The settings page is read-only here; it does not save simulator fields.
- The real application release checker and firmware release checker are not represented by working banners in this slice. There is no packaged WebView smoke test, screenshot parity run, or real device/hardware interaction.
- Runtime settings currently expose API-key configured/not-configured status only; this DTO does not claim file-vs-manual source.

## Verification

- `cargo test -p trenino-core ui::tests` — 6 passed, including non-mutating TS drift comparison, stale-fixture detection, secret-bearing internal error redaction, and identity serialization.
- Focused `npm test -- tests/shell.test.ts tests/bridge.test.ts tests/stream.test.ts tests/theme.test.ts` — 28 tests passed.
- `npm run check` — passed with 0 errors and 0 warnings.
- `npm test` — 31 tests passed.
- `npm run build` — passed; Vite emitted a static `dist/index.html` and bundled CSS/JS.
- `npm audit` — 0 vulnerabilities.

The original install reported three dependency advisories (one moderate, two critical); the follow-up below resolves them.

## Dependency advisory follow-up (2026-10-24)

Replaced the ranged Vitest 3 dependency with exact `vitest: 4.1.12` and regenerated `package-lock.json`. The official [Vitest 4 migration guide](https://vitest.dev/guide/migration.html) requires Node.js 20+ and Vite 6+; this environment uses Node 25.2.1 and Vite 7.3.7. The existing configuration and tests use no APIs called out as removed in that guide. The [4.1.12 release notes](https://github.com/vitest-dev/vitest/releases/tag/v4.1.12) confirm the current fixed release includes the mocker hardening, and Vitest 4's documented pool rewrite removes the affected tinypool dependency.

After the upgrade, `npm run check` passed with 0 diagnostics, `npm test` passed all 31 tests, `npm run build` passed, and `npm audit` reported 0 vulnerabilities.

## Stream epoch recovery follow-up (2026-10-24)

Addressed the two remaining stream findings from `ui-fix1-review.md`:

- Retiring an epoch now purges that epoch's pending changes and dropped high-water mark. An authoritative snapshot from a new epoch no longer remains in a retry loop because of an unreplayable gap in the previous epoch.
- `needsSnapshot()` now considers unresolved high-water marks from every unretired epoch, not only the current epoch. If the bounded per-epoch metadata map evicts unresolved information, an explicit overflow generation keeps recovery required.
- The bridge captures a snapshot request token before invoking Rust and passes it to `installSnapshot`. A response that began before later observations or metadata overflow cannot clear those recovery obligations. A fresh response after observations settle can clear obsolete epoch metadata and cover the overflow marker. This relies on the runtime adapter's current committed-state snapshot read, not a cached snapshot.
- Added stream tests for R1 restart retirement, R2 cross-epoch buffer eviction and catch-up, and metadata-map overflow followed by stale-request rejection and fresh-snapshot recovery. Added a bridge test that verifies restart recovery stops retrying after the new epoch snapshot.

Verification for this follow-up:

- Before the implementation, the two R1/R2 focused stream regressions failed against the prior code with the reviewed outcomes (`resync` remained for the retired epoch; the delayed old-epoch snapshot incorrectly returned `applied`).
- `npm test -- tests/stream.test.ts tests/bridge.test.ts` — 19 tests passed.
- `npm run check` — passed with 0 errors and 0 warnings.
- `npm run build` — passed; Vite emitted the static frontend.
