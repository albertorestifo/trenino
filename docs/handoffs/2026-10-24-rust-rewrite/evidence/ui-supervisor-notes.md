# UI supervisor own-audit notes (not final acceptance)

Date: 2026-10-24. Scope: `1942935` + `f7c1c4c`, current UI plan and accepted packaging merge `914fc811` / plan alignment `f9cb3e2`. Static shell/DTO/bridge only; real AppServices/Tauri commands and retained-screen parity are not claimed. Two independent fresh Sol/high reviews remain pending capacity. No production source edits or real app/hardware actions.

## Evidence collected

- Read UI brief/report/review diff, current UI plan, all bridge/app/main sources, current tests, Rust UI/shared DTOs, relevant legacy consent/theme/navigation and accepted packaging scoped review.
- Inline Node probe imported the actual `TopicStream`: revision `18446744073709551614` to `18446744073709551615` applied losslessly; malformed `epoch: 'unknown'` threw `SyntaxError`; 10,000 pre-snapshot events left 10,000 buffered records. No source mutation.
- Root/implementer previously reported Rust UI 3, Vitest 10, check/build successful; audit 0 after Vitest 4.1.12; root Rust 70 tests passed. These were not rerun during this audit.

## Candidates for independent validation

1. `client.ts:65-74` catches rejected initial snapshot without retry or terminating the subscription; `stream.ts:11-13` subsequently only buffers every event while `current` is absent. A transient first fetch failure cannot recover through further events. Buffer is unbounded. Every gap/restart event also starts its own refresh with no single-flight coalescing.
2. `App.svelte:20-47`: route bootstrap errors are silently ignored and page loads continue with unknown consent. Rendering follows the requested route before bootstrap resolves. Only bootstrap compares current hash; downstream `load` completions share unguarded `loadError` and setters, so an old route response can clear/replace the current route's error and same-route revisit responses can replace newer data.
3. `client.ts:27-33`: every invoke rejection is replaced with generic retryable unavailable, losing a legitimate serialized UiFailure's code, fields and retryability. Confirm within accepted current contract.
4. `main.ts:5-16`: system preference is resolved once to explicit light/dark with no matchMedia change listener. Legacy root layout removes data-theme for system so CSS continues reacting to OS changes. Invalid local preference falls back to system; localStorage access itself is unguarded.
5. `ui.rs:162-181`: generation test writes to tracked declarations without comparison, so stale committed declarations can yield a passing Rust test. No current CI drift gate located. Current generated DTO fields match inspected serialization, including numeric positive i32 ConfigId and string EntityId/counters. Topic/error unions are currently correct but handwritten ts overrides must remain synchronized.
6. Subscription lifecycle contracts need validation: Promise<Unsubscribe> resolves only after startup snapshot; pending-start disposal has no direct handle, event callback lacks active guard, topic-scoped unsubscribe has no subscription identity or frontend reference count. Backend is not implemented, so distinguish demonstrated defects from future ownership-contract gates.
7. Epoch comparisons assume a globally monotonically increasing runtime epoch, while shared type/plan only promise a u64 runtime identity; no epoch generator exists yet. Do not assert random epochs are implemented. Either document monotonic persistent generation or reconcile identity changes before adapter integration.
8. Device menu Escape restores focus, but legacy click-away closure is absent. Unicode placeholders replace legacy icons. Treat precise visual parity and full dialog/keyboard forms as explicit pending gates, not proof of full UI retention.

## Scope decisions

- Do not demand missing real service commands or full screens as defects in this deliberately limited slice; record them as integration gates.
- Stable app updates stay in native Help → Check for Updates; do not request a duplicate legacy app banner. Firmware notices remain independent. Rust shutdown/quiescence integration remains a later platform gate.
- Stream gap-event dropping alone is not yet proven to lose final state if authoritative post-event snapshots always include those events. Independent reviewers should establish a concrete repro before classifying that as a defect.
- No arbitrary optimization requirement for ts-rs formatting feature; dependency/build weight is an observation unless a concrete problem is established.
