# Standard Tauri distribution

## Intent and chosen approach

The user chose Tauri's standard distribution route instead of the custom MSIX
route in draft PR #168. Use the existing NSIS/Windows installer pipeline and
Tauri's official updater plugin. Do not buy a certificate or signing service.

The alternatives discussed were custom MSIX with Microsoft Store signing and
Store-managed updates, versus built-in Tauri installers with app-managed updates.
The latter is the user's choice: less custom packaging, but Windows publisher
signing remains separate from free updater-artifact signatures.

## Scope

- Replace the MSIX-specific work in PR #168; preserve the missing vJoyInstall.dll
  packaging fix and its checks.
- Remove Store-only build/configuration/test paths and unused GitHub Store variables.
- Keep the reserved Microsoft Store product untouched; do not submit or publish it.
- Configure the official Tauri updater and GitHub release update metadata.
- Generate a dedicated updater key without printing its private content. Keep a
  local protected backup outside the repository and store the private key in
  GitHub Actions secrets; commit only the public verification key.
- Require signatures for updater artifacts. Do not claim these signatures provide
  Windows Authenticode publisher trust or eliminate Windows security warnings.

## Proposed update behavior (builder choices for approval)

- Stable installations check stable GitHub releases; nightly distribution stays
  separate and does not silently replace a stable installation.
- Ask before installing an update; no unexpected restart while simulator controls
  or firmware flashing may be active.
- Download and verify through Tauri's official updater. Coordinate backend/sidecar
  shutdown before installation, and report download/install failures without
  marking the update successful.
- Replace duplicate desktop GitHub-update notifications with the official updater
  flow; preserve existing behavior for non-desktop/server deployments.

## Verification and non-goals

Test updater eligibility, cancellation, failures, and shutdown sequencing; validate
release metadata/signatures and run CI plus a real Windows update smoke test.
Existing installations need one manual upgrade to an updater-enabled build.
Do not merge, publish a release, install a driver, or change the Store listing as
part of configuration. The user subsequently included the vJoy software fixes:
repair installed-helper lookup, include the missing loader DLL, and correct
misleading installer warnings. Mutating this PC's shared driver still requires
a separate decision about other applications that may depend on it.
