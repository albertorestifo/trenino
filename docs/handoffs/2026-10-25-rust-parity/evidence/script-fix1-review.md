# Script fix 1 re-review

Scope: the five findings in `tmp/script-review.md`, plus the new button/lever port suspension seams. Read-only review of the current checkout.

## Finding disposition

1. **ADDRESSED — stale schedule at a simultaneous poll.** `runner.rs:438-455` rechecks the snapshotted deadline after the poll and skips a replaced timer. The new collision regression exercises that ordering.
2. **ADDRESSED — fractional schedule busy loop.** `runner.rs:770-781` rejects the `ms == 0` effect, clears any prior schedule, and writes an error log. This is a deliberate boundedness deviation from the legacy truncation behavior; the regression checks no immediate spin.
3. **ADDRESSED — subscription ID overrun.** `runner.rs:541-550` rejects more than 1000 unique endpoints before subscribing, keeping all IDs in 2000-2999. Manual execution remains available; the overflow regression tests zero subscriptions.
4. **ADDRESSED — sequence owner loss during HTTP.** `sequence.rs:146-155` selects owner closure against the in-flight `set_async` future, dropping that future when the owner dies. The new pending-future regression covers this case.
5. **ADDRESSED at the runner API boundary — blocked synchronous port during shutdown.** `runner.rs:277-315` bounds a shutdown attempt to 1 second, returns a typed timeout, retains the join handle and admitted shutdown request, and permits a later retry. It accurately reports the host as still owned rather than claiming completion. Actual synchronous port operations remain cooperative and require deadlines in their adapter; that is the integration requirement already recorded in `tmp/script-implementation.md`.

## Port suspension extension

The new button and lever APIs queue an acknowledged port command with a 1-second caller timeout. The control branches fence the port before removing its pending work, abort tracked sequence/writer tasks, wait up to 500 ms for settlement, and preserve other ports (`button_controller.rs:627-667`, `lever_controller.rs:501-529`). Input checks the fence before resolving (`button_controller.rs:720-746`, `lever_controller.rs:567-590`). Inline button HTTP calls cannot be canceled through that branch while the worker is awaiting them; the caller gets an error on timeout and the arbiter must fail closed, as documented. `resume_port` trusts the caller's fresh-sample barrier; it does not prove freshness itself. No new fix-breakage was found in these paths.

## Verdict

**Spec:** All five review findings are addressed within the stated chunk contracts. **Quality:** The new regressions cover the counterexamples and the reported focused suite passes (10 script runner, 30 output/display, 30 control dispatch). Suitable to integrate with bounded production port adapters and the documented fail-closed hardware callback wiring.
