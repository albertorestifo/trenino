# Standard Tauri distribution and updates

Use Tauri's built-in NSIS EXE / WiX MSI installers. The stable release workflow
enables `desktop-updater` and merges `tauri.updater.conf.json` to generate updater
signatures. `tauri-action` uploads signatures and `latest.json`, preferring NSIS
for Windows updates. Stable clients use the GitHub latest-release endpoint.

In a stable desktop build, choose **Help → Check for Updates**. Updates are
opt-in: stop simulator controls and finish any firmware flash before accepting.
Tauri downloads and verifies the artifact before requesting backend shutdown.
Installation is blocked unless the owned backend process reports termination.
No update path force-kills it. Windows closes the app to run the installer.
If installation fails after shutdown, close and reopen Trenino before retrying.
There is no background restart or scheduled update check.

Nightly/development builds do not enable this feature and do not require signing
secrets. Web/server deployments retain existing update notifications. Existing
users need a manual upgrade to the first updater-enabled stable release.

## Signing setup

`TAURI_SIGNING_PRIVATE_KEY` and `TAURI_SIGNING_PRIVATE_KEY_PASSWORD` are GitHub
Actions secrets. Only the public key is in `tauri.conf.json`. The key was tested
by signing a fixture, verifying it and rejecting a modified payload.

The Windows maintainer backup is outside the repository at
`%LOCALAPPDATA%/TreninoSigningSetup/tauri-updater/`:

- `trenino-release.key` and `.pub` are the active encrypted signing key pair.
- `trenino-release-password.xml` is protected using Windows DPAPI for the current
  user on this machine. It is not a portable backup of the password.
- The earlier `trenino.key` is unused; do not configure it for releases.

Keep a separately secured, recoverable backup of both active key and password
before the first public release. Losing them breaks updates for existing clients.
`scripts/setup-updater-signing.ps1` reuses the active files, validates signing,
and uploads secrets without printing private material. It requires npm dependencies
and an authenticated GitHub CLI. It refuses to upload a key whose public half
differs from the embedded verification key. Do not rotate the key casually after release.

These are **updater authenticity signatures**, not Windows Authenticode publisher
certificates. Windows may still show publisher/SmartScreen warnings. No paid
signing service is configured, and no release was published during setup.

## vJoy

Ship `vJoyInstall.dll` beside `vJoyConfig.exe`; the helper imports it at load time.
The runtime resolves helpers from the launcher's absolute `APP_PATH/resources`
as well as bundled backend resources, preserving link/reparse-point checks.
The installer keeps unowned shared drivers intact and describes version/state
mismatches without asserting that the installed driver is unsigned.

The original report involved an older signed vJoy 2.1.9 driver while this app pins
2.2.2.0. These code fixes alone do not upgrade or remove that shared system driver.
Driver upgrade/repair needs a separate explicit decision after checking other
applications that may depend on it.

## Verification before release

- Run the full CI suite, including `cargo test --features desktop-updater` after
  staging Windows resources and the installed-helper resolution tests.
- Build signed stable installer artifacts and inspect latest.json and signatures.
- In a disposable Windows VM, test initial install, a real version-to-version
  update, cancellation, bad signatures/network failures, backend shutdown, data
  retention, and driver-present/absent/older-version cases.
- Do not mistake local tests using previously installed sidecars for a full
  fresh backend release build or a real installed upgrade.

## Retained Store reservation

The abandoned custom MSIX path is removed. No Store identity variables remain in
GitHub. The reserved draft is untouched: **Trenino: Arduino + Train Simulator**,
Store ID `9NSR74FHGB70`, package identity
`AlbertoRestifo.TreninoArduinoTrainSimulator`, publisher
`CN=EC281FB1-7935-4258-9308-D75635DA5F75`, display name `Alberto Restifo`.
It is not a distribution or update channel for this implementation.

References: https://v2.tauri.app/distribute/windows-installer/ and
https://v2.tauri.app/plugin/updater/.
