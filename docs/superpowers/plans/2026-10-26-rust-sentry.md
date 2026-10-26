# Rust Sentry completion plan

Continue the interrupted Sentry task on `codex/rust-rewrite` in the existing
checkout. Contract: the approved [consent design](../specs/2026-05-03-error-reporting-consent-design.md)
and [feature corpus](../../feature-reference/desktop-and-operations.md).

- [x] Inspect draft, persistence/IPC consent path, and Sentry SDK 0.49.3 sources.
- [x] Complete SDK initialization, error logging, consent gating and exit drain.
- [x] Test real SDK event delivery with an in-memory transport: unset, declined,
  enabled, revoked/re-enabled consent; error-only logs; panic capture; invalid DSN.
- [x] Run workspace and desktop gates; document behavior and verification;
  review, commit and push the task on its existing feature branch.

The draft did not compile: `release_name!()` was wrapped in an extra `Some`,
and `Event::take()` does not exist. Its tests checked only an atomic flag.

Implementation decisions: retain the supplied public project DSN as the default,
with a runtime `SENTRY_DSN` override (empty disables). Keep default PII collection
disabled to honor the existing anonymous-report consent contract. Enable only
backtraces, panic capture, error-log integration and HTTPS transport; omit SDK
logs, metrics, sessions and machine contexts. Ignore info/warn breadcrumbs. Read
persisted consent before starting runtime services; update the gate only after a
successful consent save. Keep the guard alive until Tauri's final Exit event,
then drop it to drain with a bounded timeout. SDK 0.49.3's panic handler itself
flushes, including with the existing release `panic = "abort"` profile.

Verification uses a replacement test transport; no synthetic event is sent to
production. Cross-platform CI and actual Sentry dashboard receipt remain outside
local verification.

Review: a fresh reviewer confirmed core SDK setup, consent wiring and exit drain.
It identified SDK 0.49.3's default log destination panicking on `flush`; a failing
regression test reproduced it, then a safe local destination fixed it. The consent command is generic over Tauri Runtime
so its real IPC path can be exercised with MockRuntime. Mutation verification:
removing its gate update makes the consent IPC regression fail after enabling.

Gate investigation: the workspace suite exposed a pre-existing macOS fixture bug
in `composition::io::tests::in_flight_read_is_cancelled_when_accepted_client_disconnects`:
accepted sockets inherited nonblocking mode, so blocking `read_line` failed with
WouldBlock and cleanup panicked. Normalize accepted test sockets to blocking mode.
The hardware-service test `calibration_overflow_completes_lease_cleanup_without_listener`
also failed once during concurrent builds, then passed in isolation.

Final local verification (2026-10-26):
- Workspace formatting and all-target clippy with warnings denied: pass.
- `cargo test --workspace -- --test-threads=1`: 857 passed, 0 failed.
- Desktop formatting, all-target clippy with warnings denied, and `cargo check`
  with `rust-ui desktop-updater`: pass.
- Desktop full test suite with both features: 47 passed (44 library + 3 build
  configuration), 0 failed. Includes six SDK tests and one consent IPC test.
- UI `check`: zero errors/warnings; 166 tests pass; production build passes.
- Fresh review's logger-flush finding reproduced RED, fixed GREEN; no deferred
  review findings. No live Sentry event or dashboard receipt was tested.
