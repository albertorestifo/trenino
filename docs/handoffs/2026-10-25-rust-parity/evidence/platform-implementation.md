# Platform parity recovery + simulator owner + upload ownership

Main started at 3ff7d38 with incomplete g4 WIP; recovered more complete g4 source/tests from sibling preserving original in tmp/migration-recovery. No user databases or live devices used.

Recovered storage/catalog/helper fixes: GitHub token auth, compatible release selection tests, filename registry detection helper, missing context helpers (ConfigId parse, sequence total duration, button elements, I2C address formatting), whitespace train/element validation, script trigger blank acceptance, display-binding grapheme length, manual scan failure-backoff bypass, executable discovery. Corrected recovered compile errors and invalid 101-grapheme acceptance fixture; manual scan must clear backoff after joining failed owner (not just before); test ignores legitimate Closed event.

Simulator connection owner: recovered sibling unfinished code but replaced detached independent timers/probes with owned single attempt + timer. Preserves 1s initial, 30s health/retry, 2s transient/3-failure semantics. Disconnect/reconfigure cancel/join attempt and fence late results (intentional safety correction vs oracle's stale async result). Initial deadline captured before spawn. Explicit shutdown clone-safe/idempotent and joins worker. Reliable latest watch supplements lossy compatibility telemetry; latest updates on silent reconfigure. SimulatorClient debug redacts URLs/key.

Firmware: old delayed rescan launched detached thread. Now executes on owned worker after history/events and before terminal acknowledgement; terminal ack may take 500ms longer, no detached scan after shutdown acknowledgement. Added optional UploadSerialOwnership prepare/finish around worker with its existing exclusive arbiter lease. finish precedes lease release; uncertain cleanup produces Failed history/event and retains lease for explicit retry_cleanup(). Added desktop nested helper runtime_upload.rs using Weak<HardwareRuntime>, exact live generation validation, confirmed/retained acquire/release HandoffOperationIds, bounded waits outside hardware lock, actual upload events and post-delay scan hooks. Composition agent wires helper in rust_ui.rs. Scanner refuses admission of new serial owners while any firmware reservation exists (existing unrelated connections continue), preventing a renamed bootloader port from being opened during avrdude ownership.

Hardware integration seam: backward-compatible dispatch_port_input default callback supplies source port; connected_ports snapshot exposes authoritative port/generation/config/device metadata. Existing service tests pass.

Fresh verification before latest portable error-kind change:
- cargo test -p trenino-runtime --test simulator_connection --test foundation: 17+11 passed (tmp/connection-foundation-final.log).
- cargo test -p trenino-runtime --test hardware_runtime --test firmware_upload: 33+34 passed (tmp/upload-handoff-final.log).
- hardware_service: 15 passed (tmp/hardware-bridge-tests.log).
- domain_bindings/trains/sequences/scripts and firmware_catalog passed in tmp/parity-fixes-tests.log before hardware test failed; hardware failures since fixed.
- red evidence bootloader-scan-red2.log: scanner wrongly opened changed COM99; green upload-handoff-final.log. connection-red2.log: disconnected late result became Connected; green final connection log. upload-ownership-green.log pins failed cleanup retains lease then retry releases.

Residuals: actual Windows compilation/driver behavior, physical flashing/simulator/installer acceptance unavailable. Windows configurator separate task; raw unflashed port reservation/inventory needed for firmware upload without already-discovered Trenino firmware. No whole-migration completion claim.

Fix1: fresh review tmp/platform-review.md found health HTTP non-preemptible and cancel_upload false clean ack. Added held-health response red test (health-cancel-red.log) then moved health to the same owned abortable probe as connect, and disconnect/reconfigure now await transition acknowledgement. All18 simulator tests passed. Cancellation now returns typed Timeout / CleanupIncomplete, has independent15s cleanup bound, and retains worker/lease until actual cleanup. Failed/blocked cleanup regressions pass (upload-cancel-final.log),35 original+new upload suite passed before latest timeout test. Platform fix1 rereview accepted both fixes (tmp/platform-fix1-review.md).

Additional integration cleanup: vJoy manager now stop_admission()/release_runtime(), preserving enabled preference, releasing only actuallyselectedowneddevices, retaining handles after failedneutralization so retry performs realwork. New2 tests plus23live+26manager passed. Reviewer composition noted this fixes nativehandleleak.

Fullworkspacecheckpoint found old simulator_detection::control_detection_times_out_after_thirty_seconds flaky underparallelload: observingserverrequestcount didnot prove HTTP responseprocessed/polltimerrearmed. Replaced arbitrary20ms settle in that test with FakeClock.pending_deadlines barrier (FakeClocktestutility only, actual SystemClock unchanged). All31 simulator_detection tests now pass inparallel2.4s.
