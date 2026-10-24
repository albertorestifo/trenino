# Hardware runtime review supervision

Use the Astra supervisor role in C:/Users/Alberto/.codex/worktrees/rust-rewrite/tsw_io on codex/rust-rewrite. Read hardware-runtime-brief.md, hardware-runtime-report.md and hardware-runtime-review.diff here; root supplies commits. Review the actual serial adapter, owned discovery/per-port tasks, configuration acknowledgment, sessions, shared resolver/arbiter and frame bound. Full hardware GUI and database adapter integration are not claimed. The pure hardware predecessor was accepted; focus on this diff and its integration contracts.

Perform your own audit, then two fresh independent gpt-6-sol/high correctness/adversarial child reviews sequentially with fork_turns none. Do not share prior findings. Wait for root capacity if necessary. No production edits, commits, live ports, driver, simulator, flashing or user databases. Use fake clocks/transports/repositories/consumers for concrete probes; do not repeat reported broad tests blindly.

Binding contracts:
- Preserve legacy wire bytes, custom trailing-zero COBS and timings. Bound malformed frames and recover after the delimiter.
- One persistent owner per port. Fence discovery/read/write/cache/resolution/configuration acknowledgments by generation. Bounded queues must report overflow and preserve button edges and calibration samples.
- One shared resolver maps ConfigId/pin/generation to database identities; replacement invalidates before further effects. ConfigId 0 means unconfigured, not a valid persisted ConfigId. Persist configuration confirmation before success.
- Detection/calibration preserve source states, thresholds, sample order, save errors, timeout and cancellation. UI listener lifetime does not own the operation.
- One shared arbiter scopes calibration/flashing to the affected resource. Firmware takeover cancels affected calibration and awaits neutralization/source loss before port handoff. Leases survive caller/UI cancellation. Define unrelated-resource behavior. Failed release leaves routing suspended; resumption requires fresh current-generation input, never cached values.
- Native blocking I/O shutdown must join/release or report failure; a timeout cannot silently abandon a live owner. Preserve cross-platform source support and document build prerequisites.
- Database adapter, desktop wiring and physical-board acceptance remain explicit gates. Do not mistake trait declarations for required delivered task ownership.

Write hardware-runtime-supervisor-report.md with actionable findings, reproductions, priorities, fix requirements and spec/quality verdicts. Retain independent hardware-runtime-correctness-review.md and hardware-runtime-adversarial-review.md. Do not attribute sibling firmware/AppServices changes to this slice. Return a short result to root.
