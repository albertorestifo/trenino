# Guided cleanup ownership fix 2 rereview (2026-10-25)

## Verdict

The `cleanup_pending` cross-boundary fix addresses the residual finding from `tmp/ui-guided-fix1-review.md` for explicit Close, outer wizard X/backdrop, and Retry. A separate forced-unmount path still loses the retry owner after a failed cancellation. This is scoped source/test review; I did not rerun the reported 142 frontend and 17 Rust guided tests or a native WebView/simulator smoke test.

## Remaining Important finding: route unmount drops a failed cleanup retry

`tauri/ui/src/components/GuidedSimulatorSession.svelte:159-164` performs only `void cancelBackend(sessionId)` during `onDestroy`, even when `snapshot.cleanup_pending` is true. The result is unchecked, and the component with the retained ID is gone. `App.svelte` keys train editing by route path (`tauri/ui/src/app/App.svelte:395-398`), so hash navigation can unmount a train wizard independently of its acknowledged X/backdrop close. Repro: start control detection; navigate to another route while it is running (or after status reports `failed, cleanup_pending:true`); make the one unmount cancellation fail its unsubscribe. Rust retains `active=Some` with `cleanup_pending:true` (`crates/trenino-runtime/src/composition/sessions.rs:507-513,537-543`), but no UI owner remains to retry. Returning to the wizard and starting guidance gets Busy until app shutdown. The backend's abandoned-Start protection does not cover a successfully started session whose UI later unmounts.

Carry cleanup ownership above the component across route changes and retry failed cancellation, or guard route/navigation teardown with the same acknowledged `requestClose()` path. Add a test that unmounts an active/pending guided session, makes the first cancel fail, then verifies a later cleanup retry releases the Rust slot before new guidance starts. An unavoidable process/WebView termination can still be handled by the backend shutdown path; this finding concerns ordinary in-app navigation while the process remains active.

## Original residual finding: addressed on explicit UI paths

- Rust serializes a required `SessionSnapshot.cleanup_pending` bool (`composition/sessions.rs:60-88`). `cancel_active` sets it true when cleanup fails while retaining the active owner, and false after acknowledged cancellation (`:489-526`). `finish_active` does the same for post-detection cleanup (`:528-548`). The Rust regressions at `tests/guided_sessions.rs:294-375` check both failure sources and the false value after retry; a genuine terminal failed manual sequence has false (`:520-526`).
- The bridge requires the field (`tauri/ui/src/bridge/client.ts:92-94`). `GuidedSimulatorSession.svelte:62-94` retains the old ID on failed cleanup and retries cancellation before another Start. `:133-156` cancels a failed pending owner before invoking `onClose`; an error leaves the ID and visible UI intact. A clean terminal failure exits or retries without redundant cancellation. Tests at `tauri/ui/tests/guided-sessions.test.ts:128-179,335-360` model these paths.
- Lever and button wizard outer close handlers await `requestClose()` and only dismiss on true (`LeverSetupWizard.svelte:48-59`, `ButtonBindingWizard.svelte:57-68`). The prior ambiguous-selection, gapped-draft, resolver-revision and atomic-DTO findings remain addressed in this rereview and were not reopened.
