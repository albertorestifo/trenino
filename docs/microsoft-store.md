# Microsoft Store distribution

The selected distribution route is a free Microsoft Store individual developer
account and an MSIX package signed and delivered by Microsoft. It does not provide
a signing certificate for GitHub EXE/MSI downloads. Do not buy a certificate or
create Azure billing resources for this route.

## Account setup

Start at https://storedeveloper.microsoft.com (the supported free enrollment entry
point), choose **Individual developer**, and sign in with the publisher's personal
Microsoft account. The publisher completes government-ID/selfie verification and
reviews the profile and developer agreement. Do not put identity documents,
passwords or verification codes in the repository or CI.

The MSIX application **Trenino: Arduino + Train Simulator** was reserved in
Partner Center on 2026-10-24. It is a draft, not a published Store release.
The shorter name **Trenino** was unavailable.

Verified Product identity values (not signing credentials):

| Repository variable | Value |
| --- | --- |
| `STORE_IDENTITY_NAME` | `AlbertoRestifo.TreninoArduinoTrainSimulator` |
| `STORE_PUBLISHER` | `CN=EC281FB1-7935-4258-9308-D75635DA5F75` |
| `STORE_PUBLISHER_DISPLAY_NAME` | `Alberto Restifo` |
| `STORE_DISPLAY_NAME` | `Trenino: Arduino + Train Simulator` |

Store ID: `9NSR74FHGB70`. Package family:
`AlbertoRestifo.TreninoArduinoTrainSimulator_zm8cr2g7qzhva`.
Manage the draft at
https://partner.microsoft.com/en-US/dashboard/products/9NSR74FHGB70/overview.
The reservation page requires submission within three months to retain the name.
All four repository variables above were configured and read back successfully
in `albertorestifo/trenino` on 2026-10-24. No signing certificate or cloud signing
credentials were created. CI also builds a real unsigned Store package for review;
neither CI nor the release workflow submits it to Microsoft automatically.

## Building

Stage the same Windows binaries and resources as the desktop build, then build
the Store variant from the `tauri` directory:

```powershell
npm ci
npx tauri build --no-bundle --features microsoft-store
```

This feature tells the backend to disable GitHub app-update notifications; the
Microsoft Store owns application updates. Firmware updates are unaffected.

From the repository root, package with the actual Partner Center identity:

```powershell
./scripts/package-msix.ps1 `
  -IdentityName $env:STORE_IDENTITY_NAME `
  -Publisher $env:STORE_PUBLISHER `
  -PublisherDisplayName $env:STORE_PUBLISHER_DISPLAY_NAME `
  -DisplayName $env:STORE_DISPLAY_NAME `
  -Version '1.8.0.0' `
  -OutputDirectory 'tauri/src-tauri/target/store-submission-1.8.0.0'
```

The output directory must not exist. MakeAppx from the Windows SDK performs
manifest/package validation. Output is an **unsigned submission artifact**, not a
public sideload download. Upload it to Partner Center after the checks below.
Microsoft signs it only after the Store submission process succeeds.

Store package versions have four components, a nonzero first component and a zero
fourth component. Use `(application major + 1).minor.patch.0` for stable versions:
application 0.8.0 maps to Store 1.8.0.0. Do not submit nightly prereleases using a
stable package identity/version; flighting needs a separate release policy.

The release workflow builds this additional artifact when all four repository
variables above are configured from Partner Center. It rebuilds the Tauri launcher
with the Store feature after producing the normal downloads, then uploads a
separately named Actions artifact for review. It does not publish to the Store or
attach the unsigned MSIX to GitHub Releases. No signing secret is needed.

## Driver and certification constraints

The package includes vJoy user-mode helpers, including `vJoyInstall.dll`, which
`vJoyConfig.exe` imports. It excludes vJoySetup, VC++ setup, driver files and
uninstallers. VC++ runtime is a Store framework dependency. Existing installed
vJoy remains shared system state. Packaging does not repair or remove it.

**Store acceptance is not yet established.** Policy 10.2.4 generally excludes
third-party driver dependencies, with case-by-case consideration for WHCP-certified
drivers. Disclose the optional vJoy dependency and obtain a decision before
publishing. Do not offer a driver downloader/installer in the Store app. Existing
device-configuration elevation also needs certification review. If refused,
removing joystick functionality from the Store edition requires a product decision.

Draft certification note: Trenino connects serial hardware to a separately
installed Train Sim World game. Its HTTP/control/display functionality does not
install a kernel driver. Optional virtual-joystick output requires an independently
installed compatible vJoy driver. The MSIX does not install or uninstall that driver.
The full-trust capability is used for the Elixir backend and native serial,
firmware-flashing and input helper processes. Verify this note against the actual
submission and identify the precise driver's WHCP status before submitting it.

## Required verification before submission

Known runtime blocker from code review: the virtual-joystick system adapter's
`trusted_locations/0` currently searches the extracted Elixir application directory,
not `APP_PATH/resources`, where both desktop installers and this MSIX put helpers.
Correct and test that resolver before claiming virtual joystick works. Direct helper
probes and MakeAppx validation do not cover this behavior.

- Run `pwsh -File scripts/test-msix-packaging.ps1 -Pack` (fixture packaging only).
- Build the actual Store-feature executable and backend from the intended commit.
- Test the installed MSIX in a disposable Windows VM with WebView2 and the declared
  VCLibs framework. A valid package container does not prove runtime compatibility.
- Test Burrito extraction, localhost startup, serial discovery, flashing, simulator
  access, normal shutdown and optional joystick behavior under package identity.
- Test an update over a copied existing configuration and a previous MSIX version.
  MSIX virtualizes AppData/registry; verify database and ownership-marker behavior.
- Test clean Windows 10/11 prerequisites and run Windows App Certification Kit.
- Prepare screenshots, privacy policy, age rating, dependency disclosures and
  review notes. Review Store policies and the runFullTrust declaration.
- Reserve the actual identity, verify the package matches it, and review the final
  listing before submission. Do not publish automatically from a nightly build.

## Sources

- https://learn.microsoft.com/en-us/windows/apps/publish/whats-new-individual-developer
- https://learn.microsoft.com/en-us/windows/apps/publish/get-started
- https://learn.microsoft.com/en-us/windows/msix/desktop/desktop-to-uwp-manual-conversion
- https://learn.microsoft.com/en-us/windows/apps/publish/publish-your-app/package-version-numbering
- https://learn.microsoft.com/en-us/windows/apps/publish/store-policies
- https://learn.microsoft.com/en-us/windows/msix/desktop/flexible-virtualization
