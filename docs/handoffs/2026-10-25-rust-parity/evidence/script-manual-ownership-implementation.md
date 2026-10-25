# ScriptRunner manual-run caller ownership

## Change

`RunScript` now checks its oneshot reply before entering the VM. A queued manual command whose caller was cancelled or hit the 30-second ACK deadline is discarded without any VM state, effects, or timers. During an admitted manual run, the runner checks that reply before each collected effect and before sending the ACK. If the caller disappears, later effects are skipped and that run's schedule change is restored to its prior value. A reply-send failure also restores the prior schedule. Poll and already acknowledged scheduled executions retain their prior behavior.

## Regressions and verification

- The actual-source blocked-poll regression polls `run_script` once to enqueue it, drops the receiver while the poll port holds the host, then releases the port. RED: output 4 actuated. GREEN: no effects or orphan schedule. Dropping the receiver exercises the same host condition as a 30-second ACK timeout without a 30-second test delay.
- A gated output regression drops the caller while the first effect is in its synchronous port. RED: the second output also actuated. GREEN: only the already entered first output occurs; the run's schedule does not later fire. A later acknowledged run executes both outputs and its scheduled callback.
- `cargo test -p trenino-runtime --test script_runner -- --test-threads=1`: **13/13 passed**. The composition script activation/reload/disconnect/shutdown test passed. Strict runtime lib Clippy, scoped rustfmt and diff checks passed.

A synchronous physical effect already entered before caller disappearance may complete; the runner prevents subsequent effects and orphan manual timers but cannot undo the entered effect. No real hardware or simulator was used. No commit was created.
