# Joystick fix1 scoped re-review

**Disposition: the five required findings are ADDRESSED. No new blocking defect found in the fix diff.** Reviewed commits `0ef1f4b` and `da113c7`, the saved `joystick-fix1-review.diff`, updated implementation report, and corresponding source/tests. The current sidecar/vendor paths match `da113c7`; unrelated concurrent workspace changes were excluded. No reviewer children were dispatched.

| Original finding | Status | Evidence |
|---|---|---|
| P1 extra axes accepted / unused report fields nonzero | **ADDRESSED** | `vendor/vjoy/src/vjoy.rs:10-11,521-619` requires the eight standard axes and rejects all eight supported extras. `position_for_device` at line 639 initializes unused fields to zero. Tests at lines 866 and 982 cover every extra usage, both slider slots, all 32 button bits, and unused report fields. |
| P1 cleanup without neutralization | **ADDRESSED** | `tauri/virtual_joystick/src/protocol.rs:331-354` attempts neutral output before one relinquish, then clears selection. Shutdown at line 174 reports `shutdown_failed`; operation failure includes cleanup diagnostics through line 467; Drop uses the same cleanup path. Ownership is recorded immediately after successful acquisition. Tests cover nonneutral shutdown/direct drop, EOF, input/write/flush failure, failed initial/later updates, and failed cleanup. |
| P1 missing exports panic after load/acquisition | **ADDRESSED** | `vendor/vjoy/src/vjoy.rs:12-25,411-433` validates all 12 exports used by the native adapter, including `RelinquishVJD`, before constructing the generated binding or making SDK calls. Preflight and binding use the same loaded `Library`. Missing-export tests at lines 1022 and 1037 cover early/late symbols and a complete export table. |
| P2 descriptor validation after acquisition | **ADDRESSED** | `vendor/vjoy/src/vjoy.rs:622-637` inspects first, acquires only after success, then rechecks. An incompatible post-acquisition descriptor triggers best-effort neutral output using pre-acquisition verified centers and one relinquish without caching ownership. Tests at lines 866, 880, and 920 cover rejection before acquisition and descriptor drift cleanup; the acquisition-race test preserves foreign ownership. |
| P2 negative POV errors accepted as zero; FFB error claims | **ADDRESSED** | Raw signed counts are retained; lines 580-595 reject independent discrete/continuous query failures. Tests at line 899 cover both. The updated report and `VENDORED.md` explicitly acknowledge that `IsDeviceFfb` cannot distinguish false from some query failures. This native API uncertainty is no longer presented as detected failure. |

The follow-up commit `da113c7` is correct: once a session has validated its shared axis range, teardown builds the neutral report from that stored range (`protocol.rs:337-340`) rather than introducing a new SDK-query failure dependency. `protocol_test.rs:576` proves cleanup still publishes neutral when subsequent range queries fail. If hello never established a valid range, the fallback still attempts per-axis neutralization, relinquishes regardless, and reports cleanup failure when range queries prevent a report; it does not claim success.

Additional requested fixes are also **ADDRESSED**:

- **Cache consistency:** `vendor/vjoy/src/vjoy.rs:231-252` writes to the SDK before replacing the cached device. The failure/retry test at line 952 preserves the last successful state and proves a later retry can commit.
- **Provenance honesty:** `VENDORED.md` and the implementation report now state that the exact upstream archive/tree had no license text files, identify the locally added canonical texts, preserve manifest author attribution, and avoid inventing a copyright year/holder. The MIT template placeholders remain transparent; packaging notices remain the previously agreed integration work.
- **Build prerequisite:** `docs/development.md:64-67` separately documents build-time `libclang.dll` and `LIBCLANG_PATH`, explicitly distinguishing it from an end-user dependency. CI provisioning and packaging acceptance are deferred as directed.
- **Selected device contract:** ID 1 remains the optional legacy default; explicit IDs 1..=16, sparse lookup, busy-device rejection, request/session identity, and slider mapping remain intact.

## Nonblocking notes and remaining evidence limits

The added tests exercise the real protocol session and the vendor public ownership/update methods through fake seams. The missing-export test exercises the shared validation function with a fake export set; it does not actually load an incomplete fake DLL. The adapter-side fake replaces `CrateNativeApi`, so it does not execute that native FFI implementation end to end. Source inspection supports the wiring, but these tests should not be described as real loader/driver validation.

One minor documentation mismatch remains: `VENDORED.md` says the legacy constructor retains its "original all-free-devices behavior." It still loops IDs 1..16, but the shared `acquire_device` path now accepts only the Trenino descriptor (eight axes, 32 buttons, no POV/FFB). The sidecar uses only the no-acquire constructor, so this has no active sidecar impact; narrow that wording when next updating vendor documentation.

Native FFB false-result ambiguity, void relinquish outcome, DLL resource trust, kernel/hard-kill behavior, and distribution/CI gates remain explicitly unverified. No hardware calls or driver loading were performed during this re-review. No test suites were rerun: the implementation report records **36 sidecar tests** (3 library + 2 CLI + 31 protocol) and **11 vendor fake library tests** passing, and inspection found no concrete novel probe warranting a broad rerun. No implementation files were changed by the reviewer.

The scoped repair review is complete; the slice can proceed to integration under the stated native and packaging limitations.
