# Task 9 report: Windows vJoy packaging

## Result

Implemented the pinned Windows vJoy supply chain, sidecar packaging, NSIS
ownership/shared-state handling, and a hosted Windows packaging job that never
installs or mutates the driver.

## Reviewed release inputs

Primary sources reviewed on 2026-08-05:

- GitHub release and asset metadata:
  https://github.com/BrunnerInnovation/vJoy/releases/tag/v2.2.2.0
- Tagged installer source (files, silent installer behavior and uninstall key):
  https://github.com/BrunnerInnovation/vJoy/blob/v2.2.2.0/install/vJoyInstallerSigned_Brunner.iss
- Tagged configurator source (create/delete/report CLI contract):
  https://github.com/BrunnerInnovation/vJoy/blob/v2.2.2.0/apps/vJoyConf/vJoyConfig/vJoyConfig.cpp
- Tagged license text:
  https://github.com/BrunnerInnovation/vJoy/blob/v2.2.2.0/LICENSE.txt

The release assets were downloaded directly and hashed independently with
`shasum -a 256` on 2026-08-05:

| Input | SHA-256 |
| --- | --- |
| `vJoySetup_v2.2.2.0_Win10_Win11.exe` | `ef569a3105cd301b89580f18f60c66b339e95296acf2c0dfcaf4b4bbf8ab68fe` |
| `SDK.zip` | `0e796b185b66819d5fbeae645f3f038ecbfbbde837d3d3f06cba82ae1db07c67` |
| tagged `LICENSE.txt` | `7f0ed151caab68bbfd1a37727c8fe75c94be45aff98a88d63bc7e46e3fb0c5e1` |

The SDK archive was independently inspected and contains the expected x64
`SDK/lib/x64/vJoyInterface.dll`. The notices reproduce the tagged MIT license.

## Implementation notes

- `download-vjoy.ps1` accepts the specified pinned inputs. It downloads to a
  unique sibling temporary file, checks SHA-256 case-insensitively, and only
  then renames it over the destination. A mismatch removes only the temporary
  file. `-VerifyOnly` performs no network request or mutation.
- The Windows build stages the signed installer, SDK x64 DLL, configurator
  extracted from the installer, tagged license, notices, and the target-suffixed
  persistent sidecar. Temporary extraction uses a validated `mktemp` directory.
- Tauri declares the sidecar as `externalBin` and the Windows setup/runtime
  payload as resources. Pin metadata is also present in `Cargo.toml`.
- NSIS detects exact vJoy `2.2.2.0`. A compatible pre-existing installation is
  never claimed or altered. If Trenino installs vJoy, it records
  `VJoyInstalledByTrenino=1` and removes only that installation's default device.
- Uninstall removes device 1 only when the normalized `vJoyConfig -t 1 -c`
  report exactly matches Trenino's eight-axis/32-button/no-POV/no-FFB descriptor.
  The driver is removed only when Trenino owns it and devices 2 through 16 are
  absent; otherwise the detail log explains why shared state was retained.
- Ordinary Windows CI tests checksum failure/success/preservation, builds and
  tests both native crates, builds Burrito/Tauri, and inspects staged resources.
  It deliberately contains no driver install command.

## Verification

Passed locally on macOS:

- `cargo fmt --manifest-path tauri/virtual_joystick/Cargo.toml --check`
- `cargo test --manifest-path tauri/virtual_joystick/Cargo.toml` — 14 passed
- `jq empty tauri/src-tauri/tauri.conf.json`
- `bash -n scripts/build-desktop.sh`
- Ruby YAML parse of `.github/workflows/ci.yml`
- `git diff --check`

`cargo check --manifest-path tauri/src-tauri/Cargo.toml` reached Tauri's build
script and then stopped because the normal prebuilt external binary
`binaries/trenino_backend-aarch64-apple-darwin` was not staged. This is an
existing packaging prerequisite, not a Rust compilation error. PowerShell,
7-Zip/Inno extraction, NSIS compilation, the complete Windows package, and
driver lifecycle cannot be executed on this macOS host; the new Windows CI job
covers the non-mutating subset.

## Windows VM release checklist (not yet executed)

Use a disposable Windows 10/11 x86-64 VM and retain the installer detail log:

1. Confirm no compatible vJoy installation/device is present and install the
   generated Trenino NSIS package as administrator.
2. Record `vJoyConfig.exe -v` and `vJoyConfig.exe -t -c`; verify no device 1 is
   reported while virtual joystick mode is off.
3. Enable the mode and accept UAC. Run `vJoyConfig.exe -t 1 -c`; expect exactly
   `X Y Z Rx Ry Rz Sl0 Sl1`, 32 buttons, no POV and no FFB.
4. Disable the mode and verify `vJoyConfig.exe -t 1 -c` reports no device.
5. Enable once more, uninstall Trenino, and verify device 1 and the Trenino-owned
   vJoy driver are removed.
6. Repeat with a compatible pre-existing vJoy installation and another device;
   verify uninstall preserves both shared driver ownership and other devices.

These observations must be attached to the release checklist/CI log before a
Windows release is promoted.

## Fix Round 1

Packaging review identified two critical trust-boundary gaps and four related
ownership/verification gaps. All were addressed:

- The feeder no longer calls `LoadLibrary` with a bare DLL name. On Windows the
  Elixir bridge resolves `vJoyInterface.dll` through the existing trusted,
  reparse-safe packaged-resource resolver, passes it as the fixed
  `--vjoy-interface` argument, and Rust requires an absolute path with the exact
  DLL basename before loading that absolute path. CLI and bridge regressions
  cover missing, relative, renamed, extra-argument and trusted-path cases.
- vJoy resources and the sidecar moved from the base Tauri config to
  `tauri.windows.conf.json`. Tauri documents that this file is automatically
  merged only for Windows using JSON Merge Patch:
  https://v2.tauri.app/develop/configuration-files/#platform-specific-configuration
  The target-suffixed external binary follows Tauri's documented convention:
  https://v2.tauri.app/develop/sidecar/
- After the configurator has both exited successfully and device arrival is
  confirmed, Trenino writes the fixed current-user registry marker
  `VJoyDevice1CreatedByTrenino=1`. A normal confirmed delete clears it. Marker
  write failure is explicit, and creation timeout never writes ownership.
- NSIS now requires that persistent device marker as well as an exact normalized
  descriptor before deleting device 1. A matching shared device alone is never
  sufficient. Any remaining device, including a failed removal of device 1,
  prevents driver removal.
- Installer/uninstaller registry reads explicitly use the 64-bit view. An
  unrecognized pre-existing vJoy service is treated as shared and is not
  replaced or claimed. A prior Trenino driver marker survives upgrades. Driver
  removal additionally requires the exact pinned version; ambiguity fails safe.
- The installer validates Authenticode immediately before executing vJoy setup.
  CI independently checks `Valid` status and the BRUNNER certificate subject.
- Windows CI asserts the NSIS artifact exists, extracts it and its nested payload
  to verify actual bundled resources/sidecar, launches the staged sidecar with
  its absolute staged DLL for a JSON protocol hello, and uploads the installer.
  It still performs no driver mutation.

Fix-round verification on macOS:

- Focused Elixir bridge/configurator suite: 38 passed.
- Rust unit/integration suite: 16 passed, including two new CLI path tests.
- Both Tauri JSON files parse; static assertions confirm no vJoy item is in the
  base config and at least six vJoy/sidecar items are in the Windows overlay.
- CI YAML parses, desktop build shell syntax passes, and `git diff --check`
  passes.

PowerShell execution, Authenticode validation, NSIS compilation/extraction, and
the packaged Windows hello remain Windows CI checks and were not claimed as run
on this macOS host. Real driver lifecycle validation remains confined to the
disposable Windows VM checklist above.
