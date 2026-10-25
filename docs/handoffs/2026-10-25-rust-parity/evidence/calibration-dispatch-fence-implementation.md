# Calibration input dispatch fence repair

Addressed the Important integration finding from `tmp/calibration-lease-ownership-review.md`: an aggregate hardware resume may fail after lever/button resume ACKs, leaving the real resource lease and physical output fence retained while those two workers are already resumed. Previously, AppHardwareConsumers forwarded subsequent samples as ordinary actuation and consulted global arbiter suspension only for its resume attempt.

## Production changes

- New shared `composition/input.rs` implements the actual desktop ingress choice. `port_is_fenced` checks the named port's shared suspended set, `ResourceArbiter::port_is_leased(port)` and `port_neutralization_failed(port)`. It deliberately does not use global `is_suspended`, so a lease/failure on COM1 does not block COM2.
- `AppHardwareConsumers::dispatch_port_input` uses that gate and shared dispatch helper. A failed aggregate resume no longer returns before caching the sample: it retains the error, forwards the authoritative sample in cache-only mode, publishes the usual hardware input event, and then returns the truthful error. Explicit retained leases continue to require their owner's release/retry path.
- LeverController and ButtonController expose `try_observe`. Cache-only intent travels in the bounded queue with the sample, independent of current worker suspend/resume flags. A later resume cannot convert an already queued observed sample into actuation. Queue overflow/closure remains explicit; dispatch attempts both controller queues and reports either/both failures instead of skipping the second queue because the first failed.
- Each worker keeps the latest observed raw value, source port and generation for its bound inputs. Observed/suspended samples become baselines, not pending simulator writes or deferred button edges. After successful release, an unchanged level does not replay; a subsequent changed physical level can act normally. Baselines clear with routing activation/release and are keyed by real input identity, with generation/port checks.
- Extracted the existing per-port suspend cleanup into reusable worker helpers. Cache-only processing cancels that port's pending lever writes/retries and button repeats/sequences, and releases held keys. A valid sample for a different kind of binding on the same port still triggers port cleanup (a lever pin can therefore clean a held button key after an earlier suspension failure). No unrelated port's work is removed. Failed cleanup stays visible through the existing retained task/key state; cache ingress itself remains queue admission, not a synchronous cleanup acknowledgement.

Root's ResourceArbiter/HardwareService lease ownership changes were not edited. The desktop hardware output gate and its existing full-resume acknowledgement ordering remain intact.

## Behavioral evidence

`retained_lease_caches_samples_after_partial_resume_without_blocking_other_ports` uses the actual ResourceArbiter, real lever/button workers, FakeClock, a loopback scripted simulator and fake keystrokes. Its fake aggregate consumer ACKs both worker resumes and then fails the final resume callback, exactly reproducing the reported ordering.

The test was behaviorally **RED** with the extracted previous unconditional dispatch policy: a simulator throttle write occurred on the still-leased port (`tmp/calibration-dispatch-fence-red.log`). It is now **GREEN** and verifies:

- The failed release retains the actual lease even though both workers resumed.
- The retained lease independently fences input when the shared suspended-set entry is temporarily absent.
- Multiple leased values/edges update baselines without throttle writes or key presses, including after advancing FakeClock.
- COM2 still sends simulator/key actions while COM1 remains leased and the arbiter is globally suspended.
- Successful cleanup retry releases the same lease; repeated cached levels do not replay, while a later changed lever value and new button edge act.

`cache_only_input_cleans_port_work_even_when_initial_suspension_never_reached_buttons` starts with a held key, fails the arbiter's initial suspension before button suspension, and routes a cache-only sample from a lever pin. It verifies the existing held button key is released and subsequent leased button samples cannot press it again. No fabricated hardware ID or native key action is used.

The pure gate regression verifies a recorded source-neutralization failure and shared-set suspension each fence only their own port. The older button suspension test previously expected an unchanged held level to be replayed on resume. It was updated to the requested baseline behavior: unchanged level stays quiet, then a fresh release/press edge acts. Its first run timed out waiting for the now-forbidden replay; no production workaround was added to preserve that unsafe expectation.

## Fresh scoped validation

- `cargo test -p trenino-runtime --test control_dispatch --quiet`: **34/34 passed**, including the two new integration regressions (`tmp/calibration-dispatch-controllers-green.log`).
- `cargo test -p trenino-runtime --lib source_failure_and_shared_fences_are_port_scoped --quiet`: **1 passed** (`tmp/calibration-dispatch-gate-green.log`).
- `cargo clippy -p trenino-runtime --lib -- -D warnings`: passed (`tmp/calibration-dispatch-clippy.log`).
- `cargo test --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui --lib --quiet`: **34/34 passed** (`tmp/calibration-dispatch-desktop-tests.log`).
- Earlier focused retained-lease GREEN and intermediate compile logs remain in `tmp/calibration-dispatch-fence-green.log` and `tmp/calibration-dispatch-fence-check.log`.

Source freeze was sent before final validation so root can run aggregate checks. No real hardware/driver/keyboard calls, user database changes, UI edits, commits or subagents. Ready for fresh adversarial review; no claim that broader migration acceptance is complete.
