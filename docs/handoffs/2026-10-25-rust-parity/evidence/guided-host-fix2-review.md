# Guided session host fix 2 re-review

Read-only scoped review of the two Important findings in `tmp/guided-host-fix1-review.md`. The owner reports 16 `guided_sessions` tests, strict runtime-lib clippy and desktop Rust UI check passing; unchanged suites were not rerun.

## Finding disposition

1. **ADDRESSED — abandoned zero-delay manual sequence.** `composition/sessions.rs:422-451` now keeps the reply sender with the sequence worker and uses a biased `select!` on `sender.closed()` against every simulator `set` and inter-command delay. A closed caller wins before a next zero-delay `set` begins, and an in-flight local request is dropped when closure wins. The 50 ms abandonment timer is gone. `tests/guided_sessions.rs:796-846` holds the first response, drops the caller, releases it, and observes only one PATCH. As in the initial handoff, a PATCH already accepted by the remote simulator cannot be rolled back.
2. **ADDRESSED — last-handle failed cleanup ownership.** `sessions.rs:282-290` closes command admission and attempts cancellation when the final sender disappears. On unsubscribe failure, `active` remains owned; `:265-269,311-315` retry at one-second intervals with missed ticks skipped, and break only after cleanup succeeds. The failed-then-successful unsubscribe test at `tests/guided_sessions.rs:849-909` confirms a second DELETE and no further retries. Normal `shutdown()` still returns an error while retaining the active cleanup slot for an explicit retry.

## Verdict

Both scoped Important findings are fixed. No new Important or Critical breakage was established in the changed paths. The guided host is suitable for integration under the reported fake-service verification; physical simulator behavior remains untested.
