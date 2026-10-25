# Calibration lease ownership repair (final adversary finding 4)

Root fixed the actual source-loss cleanup owner, not only the UI symptom.

- Calibration registry entries are read as exact `(session_id, token)` capabilities and removed only after `ResourceArbiter.release` ACK. Cancel, completed advance, and coordinated firmware/shutdown cancellation share that helper; no early removal or hidden false ACK.
- Failed resume retains the exact active token and records `failed_resume`. New leases remain fenced; only the matching owner may retry that resume. Unrelated fail-closed states, failed neutralization and wrong/stale tokens remain blocked. A successful retry clears ownership/fence.
- Repeating final Advance after cleanup failure returns the already-persisted terminal calibration, without re-running analysis/persistence or returning InvalidStep. Persistence errors remain errors.
- The lease is registered before session insertion. Failed insertion followed by failed cleanup therefore retains a retry owner even when no session was admitted; cancel by ID can still settle it.
- Later calibration or firmware admission retries terminal calibration cleanup first, including another port. This recovers a failed one-shot route-unmount cancellation after its listener/session ID disappears; healthy live calibrations are not cancelled by this retry path.
- Desktop physical-output admission remains suspended until all consumer resume callbacks ACK. Failed resume cannot reopen manual output/display effects.
- ConnectedPort now exposes the observed IdentityResponse major/minor/patch as firmware_version for the real firmware notice owner, including unconfigured boards. No inferred/fake device ID or port is introduced.

Evidence: two initial tests RED on old cancellation/advance behavior (`tmp/calibration-owner-red.log`); separate failed-registration RED (`tmp/calibration-registration-red.log`); listener-abandoned future-admission RED (`tmp/calibration-abandoned-admission-red.log`). Current `tmp/calibration-final-ownership-green.log`: hardware_service21, resource_arbiter7, firmware_upload36 pass. Desktop resume-fence regression1 passes (`tmp/calibration-desktop-resume-fence2.log`). Runtime strict lib clippy passed before the last helper extraction; final broad checks will rerun. Metadata suite effect7+hardware17 passed before added ownership cases.

The corresponding hardware calibration wizard now retains its dialog/session/error after a failed cancel ACK and permits retry; only success or already-clean false closes. See `tmp/hardware-calibration-ui-implementation.md` (UI165 total after firmware wording correction).

No physical hardware, user calibration database or native key/driver operation was used. The prior final workspace failure was a test ordering race: it waited for resolver invalidation, which precedes consumer ACK, then asserted arbiter state. The test now waits for the actual failure/clear barrier; hardware21 is green. This is distinct from the lease-owner product defects above.
