# Closing review: simulator IO, manual Lua ownership, atomic I2C merge

2026-10-25. Read-only scoped review of final findings 1 and 3 in `tmp/final-rust-parity-adversarial-review.md` and the residual Important I2C finding in `tmp/ipc-null-patch-review.md`. Compared the implementation handoffs with actual production source and independently executed the targeted checks below. No production files edited; no real devices, simulator or native keyboard effects.

## Verdict

**All three scoped findings are closed. No new Important/Critical defect established in these fixes.** This does not close the separate firmware-notification and hardware-calibration-release findings, which remain assigned elsewhere.

## Finding dispositions

1. **Accepted-client IO lifetime: closed.** `composition/io.rs:101-146` wraps ordinary operations in `run_while_accepted`. The future checks Connected status and exact `Arc::ptr_eq` identity when it actually leaves the queue, races pending HTTP against watch changes, and checks identity again before returning a result. A closed status owner also rejects work. Thus a new client at the same URL is not mistaken for the accepted generation. Set/get/list and subscription creation/read all use this path. `Subscriptions::unsubscribe` intentionally retains the original client and uses the bounded plain IO call, permitting cleanup after disconnect/replacement. The existing queue deadline and IO shutdown remain in force.

   The original reviewer probe was rebuilt with current `io.rs` and the unchanged deterministic queue/disconnect assertion: `/tmp/trenino-final-io-fix-review.rs`, `queued_simulator_write_must_not_start_after_accepted_client_disconnects`, **GREEN**. Its prior RED observation was a PATCH begun only after disconnect. This time no PATCH reaches the loopback server.

2. **Manual Lua caller ownership: closed.** `train/script/runner.rs:401-432` rejects a closed response sender before entering the VM and saves the prior schedule. `execute_script_guarded` at approximately lines 790–825 checks the caller before each collected effect; cancelled runs stop processing later effects. The command restores its prior schedule both on observed closure and on failed acknowledgement delivery. Ordinary polls and already acknowledged scheduled callbacks still use the unguarded path, preserving their legitimate lifecycle. Restoration uses the previous absolute deadline, so cancellation does not delete a previously accepted timer.

   The original `/tmp/trenino-final-script-review.rs`, `review_abandoned_queued_manual_run_must_not_actuate`, was linked against the newly built actual runtime: **GREEN**, with no late HIGH. The focused active-run regression also passed: cancellation while the first physical effect is entered prevents the second effect and orphan timer; a later acknowledged run still executes both effects and its callback. An effect already entered before cancellation can complete; the implementation does not claim to undo it. Likewise the IO fence cannot undo a PATCH already accepted remotely.

3. **Concurrent metadata edit overwrites I2C params: closed.** `AppServices::update_i2c_module` (`app.rs:1087-1110`) forwards the caller's optional params without a prior hardware snapshot and obtains the device ID from the committed record. `storage/hardware.rs:1182-1194` reads the current module, merges omitted params, validates and writes inside the same `hardware_tx` transaction on the existing worker. An explicit supplied object still replaces the full parameter object, including a null minimum; invalid replacement rolls back. There is no second owner/connection or application-side stale merge.

   The deterministic `app::i2c_concurrency_tests::omitted_i2c_params_preserve_concurrent_committed_replacement` **passed**. Source inspection confirms its test-only per-worker hook pauses the metadata caller before dispatch, permits a cloned-Database writer to commit an explicit replacement through the same actual worker, and then checks that the metadata write preserves that replacement. It also checks full-record rollback after invalid brightness. The hook and hook field are `cfg(test)` and do not affect production.

## Fresh executed checks

- Original IO RED probe against current source: **1 passed**.
- Original abandoned-Lua RED probe against current runtime: **1 passed**.
- `cargo test -p trenino-runtime --lib composition::io::tests -- --test-threads=1`: **5 passed**, covering queued disconnect, same-URL different-Arc replacement, cancellation before a held response returns, old-client unsubscribe-only cleanup, and expired queued work/bounded shutdown.
- `cargo test -p trenino-runtime --test script_runner abandoned_active_manual_run_stops_later_effects_and_its_schedule -- --nocapture`: **1 passed**.
- `cargo test -p trenino-runtime --lib omitted_i2c_params_preserve_concurrent_committed_replacement -- --nocapture`: **1 passed**.

No full workspace/desktop/UI suite was repeated. Previously accepted guided-session work and remaining final-review findings were not expanded into this scope.
