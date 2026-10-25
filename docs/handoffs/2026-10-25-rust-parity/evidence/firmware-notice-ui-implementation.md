# Firmware update notice UI (2026-10-25)

## Implemented

- Added typed `FirmwareUpdateStatus` and bridge calls for `ui_firmware_update_status` and `ui_dismiss_firmware_update`. The wire shape includes connected outdated configured device IDs and unconfigured serial ports. The frontend does not compare firmware versions or manufacture notice recipients.
- The app shell reads status after the consent gate opens and every two seconds thereafter. Sequence and mount guards prevent older responses from replacing newer status or updating an unmounted shell. A failed status read keeps the last known notice and exposes the read error in the device menu.
- Restored the retained firmware notice banner in the existing navigation style with version, affected device IDs/ports, a `#/firmware` link, and dismissal. Dismissal keeps the notice visible while pending and on persistence failure; only the returned backend status can clear it. The connected-device menu offers a manual check, shows the backend `checking` state and last check error, and displays manual IPC failures.
- The firmware page uses the same backend status to disable duplicate checks and show automatic check errors. A successful manual call says “Firmware list refreshed” after the backend's forced upstream check completes. Manual checks bypass the one-hour automatic cooldown and share an in-flight check; the frontend does not apply a separate cooldown. The page refreshes the open catalog when the persisted check timestamp changes; the backend also publishes the canonical firmware topic after an automatic check.

## Tests and verification

- New `tauri/ui/tests/firmware-notice.test.ts`: configured and unconfigured notice recipients, successful and failed dismiss ACK, persistence across remount, new-device notice, notice removal and version change, stale and post-unmount status responses, backend checking, manual error, manual retry after a recent failed automatic check, automatic catalog refresh, completed manual check feedback, and exact IPC command names.
- `npm --prefix tauri/ui run check`: 0 errors, 0 warnings.
- `npm --prefix tauri/ui test -- --reporter=dot`: 12 files, 165 passed after the subsequent calibration cancel UI fix and manual-check policy correction.
- `npm --prefix tauri/ui run build`: passed, 141 modules transformed.
- `cargo check --manifest-path tauri/src-tauri/Cargo.toml --features rust-ui --quiet`: passed with sibling-owned firmware handlers registered.
- `git diff --check -- tauri/ui`: passed.

No real firmware service, serial hardware, or packaged WebView was exercised by this agent. Backend owner reports that the automatic/manual shared checker, persisted rate limit, command handlers, and canonical firmware publication are implemented; this report's verification covers the frontend and desktop compile only. No commit was created.
