# Guided session host fix 1 re-review

Read-only review of findings 1–2 in `tmp/guided-mapping-distribution-review.md`, the new host changes and the three added tests. The handoff reports 14 `guided_sessions` tests and strict runtime-lib clippy passing; unchanged suites were not rerun. Atomic mapping, distribution and UI remain separate scopes.

## Original finding disposition

1. **ADDRESSED — closed owner watch.** `composition/sessions.rs:266-274` disables the `status.changed()` branch on its first `Err`, closes admission and attempts to cancel/join the active worker. The actor then remains able to service status and shutdown; a failed cleanup leaves `active` retained for a shutdown retry. The new owner-drop test observes cancelled status, unsubscribe, and bounded shutdown acknowledgement. The former biased hot spin is gone.
2. **ADDRESSED — expired or dropped queued Start.** `sessions.rs:278-281` skips a Start whose reply receiver is closed before admission, and if the receiver closes after spawn but before ACK delivery it cancels/joins the new worker. `RunSequence` also rejects a closed receiver before spawn (`:284-286`). The new blocked-cleanup test establishes that an abandoned queued Start cannot occupy the slot. A failed detection unsubscribe still retains the slot rather than silently acknowledging cleanup.

## New fix breakage / remaining Important findings

1. **An active abandoned manual sequence can issue later zero-delay PATCH writes before the 50 ms abandonment poll.** `sessions.rs:262,296-300` learns that the `sequence_reply` receiver was dropped only when its periodic timer fires. The sequence worker at `:396-411` has no caller-liveness check between successful commands. If a caller disappears while the first PATCH is in flight, the server answers it quickly, and the next command has zero delay, that second PATCH can start before the next timer tick. The added abandonment test uses a 60-second command delay (`tests/guided_sessions.rs:709-750`), which leaves ample time for the poll and misses this case. **Test:** hold the first PATCH response, drop the sequence caller just before releasing it, use a zero-delay second command, and assert no second PATCH is sent; a paused Tokio clock can make the polling gap deterministic. Give the worker a cancellation signal tied directly to caller closure and check it before each `set`, or select the reply's closed future against execution. An already accepted in-flight PATCH remains inherently non-retractable.

2. **Dropping the last host handle loses failed subscription cleanup ownership.** On `commands.recv() == None`, `sessions.rs:275-276` calls `cancel_active` once and then unconditionally breaks, ignoring its result. If subscription 99 unsubscribe fails or times out, `cancel_active` deliberately retains `active` for retry (`:433-451`), but the actor immediately drops that state and sets `finished=true` (`:301-302`). No caller can retry and the simulator subscription may remain installed. **Test:** start detection, inject a failed/held unsubscribe, drop every `SimulatorSessionHost` clone, and verify cleanup is retried or an owned supervisor retains/report its unresolved state instead of the actor terminating successfully. The normal `shutdown()` path correctly retains failed cleanup; mirror that contract when the command channel closes.

## Verdict

The two original defects are fixed. The active-sequence cancellation gap and last-handle cleanup loss still prevent claiming complete guided-session lifecycle behavior. No source files were changed in this review.
