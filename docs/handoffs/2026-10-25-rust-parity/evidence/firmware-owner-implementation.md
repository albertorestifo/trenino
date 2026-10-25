# Production firmware checker owner

Implemented the previously uninstantiated automatic firmware checking/notice/dismiss flow. This is firmware for connected devices, separate from NativeHelp's application updater. No real GitHub, serial, driver or hardware operations were performed for validation.

## Production ownership and IPC

- New `crates/trenino-runtime/src/firmware/owner.rs` starts one dedicated named OS thread with its own Tokio runtime. It owns the existing `FirmwareUpdateScheduler`, shared `FirmwareCatalog`/repository check port, timer, in-flight refresh, bounded command mailbox and manual-check replies.
- Production startup installs this owner in `RustAppState` and registers a `ShutdownParticipant`. Initial check waits 5 seconds; later ticks use 24 hours. Automatic checks obey the scheduler's persisted one-hour minimum interval. Manual checks force a new check, matching legacy `check_now`; they bypass cooldown but coalesce with an already active check. Manual requests during an active automatic/manual check join that same result; they do not create another HTTP request. At most 64 manual waiters and 64 queued commands are admitted.
- HTTP refresh has an overall 90-second deadline, in addition to the catalog's request deadline. Manual replies wait up to 95 seconds; status/dismiss replies wait up to 2 seconds. Storage ports remain synchronous, so a blocked database operation can delay the host; shutdown returns failure while retaining its join handle until retry succeeds. It does not claim cancellation of uninterruptible storage.
- Shutdown first fences admission and signals cancellation. It drops an active HTTP future, joins the owner before acknowledging cleanup, and therefore completes before application database closure or updater installation. The production participant uses a two-second join budget. A timeout retains ownership for retry. A panicked host produces a sticky cleanup error, including later shutdown attempts.
- Committed automatic checks publish the canonical Firmware snapshot. The callback holds a weak AppServices reference; owner storage is a clone of the existing single Database worker. There is no second SQLite owner and no strong AppServices reference cycle.
- `ui_check_firmware_updates` preserves its `UiSnapshot<FirmwareView>` response, now using this owner. Manual calls force a check (or join the currently active one); HTTP/persistence failure returns typed retryable `unavailable`.
- `ui_firmware_update_status()` and `ui_dismiss_firmware_update()` return:
  ```text
  { checking: bool, checked_at_ms: number|null, found_updates: bool,
    latest_version: string|null, error_message: string|null,
    notice: { version: string, outdated_devices: string[], outdated_ports: string[] }|null }
  ```
  Both handlers are registered. The surface agent has the contract and owns the separate firmware banner/status controls. Status is actor-backed and polled by the UI; it reports actual checking/error state, not a mock snapshot.

## Rules, persistence and discovery

- The existing scheduler owns rate limiting and notices. The real catalog check port compares the pre-refresh version set with the refreshed catalog to report `found_updates` only when releases are newly found, while selecting the latest compatible release for notices. No compatible release is reported as an explicit check error. HTTP errors and successful checks are persisted before completion/publication; storage errors remain visible in the live status.
- `DbFirmwareRepository.latest_check` now parses the stored UTC timestamp instead of setting `checked_at_ms` to zero. The parser accepts current ISO UTC and legacy SQLite/Ecto timestamps, including fractional seconds; invalid dates/times produce a repository error instead of silently bypassing the rate limit.
- Live notices use `HardwareCommandPort.connected_ports()`. Root added observed `firmware_version` metadata from the current discovery generation. Configured devices retain their real EntityId; unconfigured boards are represented by port, never a fabricated ID. Only connected boards with an older/unparseable known version are included.
- Extended scheduler notices/dismissal to include unconfigured ports. Dismissal persists the version plus sorted/deduplicated device IDs and port set; a different connected outdated set or a later version may show again. Existing persisted dismissal keys remain compatible when no unconfigured ports participate. The UI does not perform version comparisons.

## Executed verification

`cargo test -p trenino-runtime --test firmware_owner --test firmware_catalog --quiet` passed **5 owner tests + 28 firmware catalog/domain tests** (`tmp/firmware-owner-tests.log`). New owner tests use FakeClock, a controllable fake HTTP/check port and fake repository, without real network/hardware:

1. Five-second startup, 24-hour cadence, actual coalesced in-flight manual replies, committed publication callback, one-hour skip and persisted restart rate limit.
2. Configured/unconfigured notice contents, no notice for disconnected inventory, durable dismissal across owner restart, and notice reappearance for a newly connected port.
3. Persisted HTTP errors, visible storage failure, cancellation of a pending HTTP future, zero active requests after shutdown ACK, and rejection of later work.
4. Deliberately blocked synchronous persistence: short shutdown fails, retains the host, and succeeds only after unblocking/retry; no post-ACK storage change.
5. Host panic cannot turn into a false successful cleanup on a later retry.

The new real catalog-port test uses loopback fake HTTP responses and the existing fake repository. It verifies compatible version selection, newly discovered versus previously saved releases, and truthful no-compatible-release error. The initial assertion expected the fixture's raw `v` prefix; it was corrected to the catalog's established normalized `1.2.3` output, without changing production normalization.

`cargo test --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui --lib --quiet` passed **34/34** (`tmp/firmware-owner-desktop-tests.log`), including three new tests:

- Actual database check timestamp round trip and exact one-hour scheduler boundary after reconstruction (plus legacy/fractional parsing and malformed date rejection).
- Mapping discovery inventory into real configured IDs and unconfigured ports with their observed versions.
- Actual generated Tauri `ui_check_firmware_updates` invocation through MockRuntime, repeated twice: both sequential invocations execute a fake check through the same owner, the result is a Firmware snapshot, and the real shared database stores its result.

`cargo clippy -p trenino-runtime --lib -- -D warnings` passed (`tmp/firmware-owner-clippy.log`). Root independently tested the discovery firmware-version field; its report/log is separate. Earlier interrupted runs during root's hardware edit and the corrected bare-DB fixture are not counted as passing validation.

## Limits and handoff

Ready for fresh adversarial review. No real upstream availability or installed hardware acceptance is claimed. All production asynchronous network work is owned/cancellable; synchronous storage can still require a retryable shutdown wait rather than forced termination. UI changes are owned and reported by the surface agent. This chunk does not claim the entire migration complete. No commits or subagents were used.


## Review fix 1: manual force policy

The fresh review found the first owner implementation incorrectly applied the automatic one-hour cooldown to manual `ui_check_firmware_updates`. The legacy oracle is explicit: `handle_cast(:check_now)` calls `maybe_perform_check(state, true)`, while startup/periodic calls pass false. The original implementation and its old two-sequential-invocations/one-check test encoded the wrong policy; the report above now reflects the corrected behavior.

`FirmwareUpdateScheduler::begin_check_with_force` retains the in-progress guard but bypasses cooldown only for forced manual checks. The owner uses this for manual requests and retains ordinary `begin_check` for automatic ticks. Already active automatic/manual work still has a single HTTP future with coalesced replies.

Added a behavioral regression that lets an automatic check persist an HTTP failure, then immediately performs a successful manual retry without advancing FakeClock. It was RED with one HTTP call instead of two (`tmp/firmware-manual-force-red.log`). Updated the combined cadence/restart test to assert a second sequential manual check, but no automatic startup refresh within the persisted cooldown after owner restart. Updated the actual generated Tauri test to assert two sequential manual invokes produce two checks. The surface agent was notified to remove the cached-success assumption from manual feedback.

Fresh scoped results are recorded in `tmp/firmware-manual-force-green.log`, `tmp/firmware-manual-force-desktop.log`, and `tmp/firmware-manual-force-clippy.log`; validation completion will be noted below. Further fresh-review findings, if any, remain to be handled before closing this review round.

Manual-force fix validation completed: firmware owner **6** and catalog/domain **28** tests passed; actual desktop firmware module **3** tests passed; strict runtime library clippy passed. No source changes followed these checks.

## Review fix 2: preserve known notices through failed refreshes

Verified the legacy `handle_check_result({:error, ...}, state)` keeps its warm `latest_version` while updating last-check/checking; its persisted error history still has no latest version. The prior owner replaced warm state with the error history and hid a known outdated-device notice.

Added an explicit scheduler `record_failed_check` path: it commits the truthful supplied failure record first, then preserves only the previously known in-memory latest version. The owner uses this path for failed HTTP/catalog checks. Error status and the failed timestamp remain visible. Successful results use ordinary `record_check`, so a later newer release replaces the known version and a successful no-compatible result clears it. To preserve that distinction, the real catalog port returns a successful empty result for no compatible release; the owner persists its `No compatible firmware releases found.` status message without treating it as a transient failed refresh. Cold restart behavior from an error record is unchanged.

New owned fake-HTTP regression was RED (notice disappeared after failure) in `tmp/firmware-warm-notice-red.log`. It now checks good version 1.2.0 with notice → immediate forced HTTP failure with error and unchanged notice, persisted latest version null → successful 1.3.0 replacing the notice → successful no-compatible result clearing it. A separate pure scheduler test verifies warm-state preservation versus truthful stored failure and empty-success clearing.

Fresh results: firmware owner/scheduler **8** + catalog/domain **28** tests passed (`tmp/firmware-warm-notice-green.log`); desktop firmware tests **3** passed (`tmp/firmware-warm-notice-desktop.log`); strict runtime library clippy passed (`tmp/firmware-warm-notice-clippy.log`). No UI edits or real external network/hardware activity. Source is ready for fresh review; no commits/subagents.
