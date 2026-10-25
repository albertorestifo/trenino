# Rust parity completion

Continuation of the OMP migration on `codex/rust-rewrite`, starting at `3ff7d38`. This report supersedes the open-work inventory in the October 24 handoff. Prior sibling worktrees were preserved and their unfinished implementation recovered into this checkout.

## Delivered scope

- Full train, element, lever, button, sequence, output, display, Lua, firmware and vJoy workflows in the Svelte desktop, backed by Rust services and typed IPC.
- Production composition of simulator connection, train detection, subscriptions, controllers, native keyboard, scripts, serial effects and vJoy, sharing one SQLite owner, input resolver and resource arbiter with MCP and the legacy JSON HTTP API.
- Guided simulator detection/analysis/calibration with owned cancellation and explicit draft save; transactional lever mapping commits with rollback and truthful post-commit acknowledgement.
- Firmware catalog/download/upload/history plus automatic checks, persisted notices and dismissal, real observed board versions, exclusive serial handoff and retryable cleanup.
- vJoy mapping/recovery and an explicit selected-device Windows configurator with ownership markers, bounded elevated workers and process Job ownership.
- Committed-edit reconciliation, generation fencing, stale connection/caller cancellation, retained failed-cleanup owners, per-port effect neutralization and coordinated shutdown with the database closed last.
- Rust-specific desktop packaging overlays and build wrapper retaining required native helpers, plus macOS/Linux/Windows CI verification. The legacy release path remains the default until native distribution acceptance.

The [audit resolution map](parity-resolution.md) accounts for the prior numbered gaps and intentional architecture differences. The [implementation plan](../../superpowers/plans/2026-10-25-rust-parity-completion.md) records the recovery and task boundaries. [Verification](verification.md) distinguishes executed checks from native acceptance still requiring equipment or another OS.

## Adversarial review

Independent chunk reviews and scoped fix reviews are archived in [evidence](evidence/). Initial findings are historical defect reports, not remaining-work lists. Follow each fix review for its disposition.

The whole-branch [adversarial review](evidence/final-rust-parity-adversarial-review.md) found four additional gaps: queued stale simulator work, missing automatic firmware checks/notices, abandoned manual Lua runs, and lost calibration cleanup ownership. These were implemented and reviewed. The calibration closing review also identified partial controller resume under a retained lease; the final dispatch fix caches samples without effects and preserves fresh-edge behavior after release. Both the [original reviewer](evidence/calibration-dispatch-fence-fix-review.md) and an [independent closing reviewer](evidence/calibration-dispatch-fence-review.md) accepted it; the latter reran 12 focused checks, including the original failure probe. No Important/Critical finding remains open in these completed review scopes.

The actual WebView audit found a configuration-create response mismatch and section anchors breaking SPA navigation, which mocked frontend tests had missed. Both were repaired. A subsequent audit checked 101 IPC commands and added actual generated-handler invocation tests for snake_case arguments, omitted/null patch semantics and publication payloads. I2C metadata updates now merge atomically with committed parameters instead of overwriting concurrent edits.

## Scope and remaining acceptance

Software parity is implemented against the retained Elixir source and tests; fake-service tests cannot establish physical or installer acceptance. No release, merge, push, signing, real simulator use, key injection, board flashing or driver mutation was performed.

Native Windows UAC/Job/driver behavior, clean-machine Linux/Windows installation and updater rollback, real serial firmware flashing, physical controls and real simulator acceptance remain gates before changing the default release path. The macOS Windows-source typecheck is evidence of compilation only; it does not replace running Windows. The full Windows target crosscheck on macOS requires missing Windows SDK headers.

The Rust build wrapper intentionally refuses packaging when the required avrdude binary/config is absent; no placeholder helper was staged. The configured CI matrix has not been executed by this local session.

One documented compatibility boundary remains: active-train deletion uses a live status check before the database mutation, as the retained interface does; it is not an atomic simulator-actor/database transaction.

Keep this checkout and sibling worktrees. Development artifacts, fixture databases, raw logs and binaries remain ignored under `tmp/`; source changes and Markdown review evidence are the durable deliverable.
