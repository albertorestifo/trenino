# Firmware owner/UI fix closing review — 2026-10-25

## Verdict

**Both scoped defects are closed:** manual checks again bypass the automatic cooldown, and a failed refresh preserves an already known live update notice. No new Important/Critical defect established. This closes the remaining firmware-owner issue in `tmp/firmware-owner-ui-review.md` plus the subsequently identified warm-notice regression. It does not close unrelated hardware lease work or native acceptance gates.

## Actual-source findings

- `FirmwareUpdateScheduler::begin_check_with_force` (`firmware/updates.rs:119`) always retains the in-progress guard and bypasses cooldown only when explicitly forced. `FirmwareUpdateOwner` uses it for `Command::Check` (`owner.rs:234`); automatic ticks still call ordinary `begin_check` (`:258`). An already active check remains shared by concurrent manual callers. The corrected cadence/restart test checks automatic startup suppression from the persisted last-check timestamp, rather than incorrectly requiring a second manual click to be suppressed.
- `record_failed_check` (`updates.rs:138`) commits the truthful failed history record before keeping the prior in-memory latest version. The owner selects this path only for failed check-port results (`owner.rs:248`). Failure timestamp/error stay visible, and stored history still has a null latest version; the warm notice retains its known version. A later successful version replaces it. A successful empty-compatible result uses ordinary `record_check`, clears the known version/notice, and reports the no-compatible-release status message. The real catalog port now represents that empty successful result separately from HTTP/repository failure (`owner.rs:29-47`). This matches the retained failure-versus-empty-success distinction without inventing a successful version.
- Firmware page feedback now says `Firmware list refreshed`; manual check admission in the page/navigation depends on actual pending/checking state, not a local cooldown. The prior mount/sequence and dismissal acknowledgement guards remain present. No further UI behavior change was needed for these backend policies.

## Fresh executed evidence

- Rebuilt the original `/tmp/trenino-firmware-manual-review.rs` against the current runtime and reran `review_manual_retry_must_refresh_after_a_failed_automatic_check`: **GREEN**. The formerly suppressed immediate manual retry now performs the second refresh and clears the stale error.
- `cargo test -p trenino-runtime --test firmware_owner manual`: **3 passed** — startup/cadence/coalescing and persisted automatic cooldown, immediate forced retry after failed automatic check, and good → failed refresh with retained notice → newer good version → successful empty result.
- Executed the freshly built owner test binary with `scheduler_failed_history_preserves_warm_latest_but_empty_success_clears_it`: **1 passed**, separately checking truthful persisted failure versus retained warm state and empty-success clearing.

Five targeted checks passed in this review. Full runtime/catalog/desktop/UI suites were not repeated; their reported results were inspected but are not presented as this reviewer's executions. No real GitHub, hardware, installed bundle or Windows operations. No production edits or subagents.
