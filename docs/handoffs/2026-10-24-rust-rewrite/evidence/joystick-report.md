# vJoy adapter implementation report

## Implementation

- The Windows sidecar uses the pinned `vjoy` 0.7.1 wrapper in `vendor/vjoy/`.
  It accepts an explicit absolute `vJoyInterface.dll` path, loads without
  acquiring devices, and then acquires only the selected device ID (1..=16;
  protocol hello defaults to 1 for compatibility). Device IDs are looked up by
  ID, so sparse selections such as 9 and 16 work without taking ownership of
  unrelated free devices.
- Before acquisition, the wrapper checks for exactly the eight required HID
  axes, rejects the eight supported extra axes, requires 32 buttons, rejects
  POV hats and enabled force feedback, validates signed POV counts and axis
  ranges, and preflights every DLL export used by this adapter. It repeats the
  descriptor check after acquisition to detect a configuration race; a change
  triggers a best-effort neutral update and one relinquish attempt.
- Successful updates alone replace the wrapper's cached device state. Reports
  map Slider 1 to `wSlider` and Slider 2 to `wDial`, encode all 32 buttons, and
  leave unused extended axes, velocities, buttons, and hats at zero.
- The sidecar tracks ownership immediately after successful acquisition. Every
  later exit attempts a centered, all-buttons-released report before release,
  and releases exactly once even if neutralization fails. Explicit shutdown
  reports cleanup failure rather than claiming `stopped`; output and input
  failures still clean up on session drop.
- The fake seams exercise the vendor crate's public acquire/update/relinquish
  APIs and the Windows `NativeVJoy` implementation through a real protocol
  session. No real driver was loaded or acquired.

## Native API limits

- vJoy's `IsDeviceFfb` returns a boolean that is false both for a device without
  force feedback and for some query failures. The wrapper cannot distinguish
  those cases; it rejects an affirmative result and documents the uncertainty
  of a false result.
- The native `RelinquishVJD` export returns `void`. The sidecar attempts release
  exactly once, but the native API cannot report whether the release succeeded.
  Protocol tests inject a release error to verify propagation where a backend
  can report one; this does not imply that the native SDK can report it.
- DLL-export preflight prevents the adapter's required function lookups from
  becoming generated-binding `expect` panics. It does not validate DLL identity
  or provenance; the caller still supplies the trusted absolute resource path.

## Provenance

`vendor/vjoy/` is vjoy 0.7.1 from
<https://github.com/ArrowMaxGithub/vjoy>, commit
`af2fe6665917e5b11fb453ee40bfe76510ef6baa`; the crates.io archive SHA-256 is
`367A5962FCD9A9524709C185280D6736BFFEDCA679392787B6272F72C90F5724`. The
upstream manifest author is Maximillian Pfeil and declares `MIT OR
Apache-2.0`. The exact upstream archive and commit tree had no license text
files. `LICENSE-MIT` and `LICENSE-APACHE` were added locally as canonical texts
for the declared licenses; no copyright owner or year was invented. See
`vendor/vjoy/VENDORED.md` for patch notes and the same provenance statement.

The wrapper's `vjoy-sys` dependency uses bindgen and therefore needs libclang
at build time. Local test commands used the task-local `LIBCLANG_PATH` supplied
for this work; libclang is not an end-user runtime requirement. CI provisioning
and clean packaging builds remain separate work.

## Verification

Using the task-local libclang path on Windows:

- `cargo fmt --manifest-path tauri/virtual_joystick/Cargo.toml --all -- --check` — passed.
- `cargo fmt --manifest-path vendor/vjoy/Cargo.toml --all -- --check` — passed
  before the final vendor test run; no vendor sources changed afterward.
- `cargo test --manifest-path vendor/vjoy/Cargo.toml --lib` — passed, 11 fake
  SDK tests. Coverage includes incompatible descriptors before acquisition,
  sparse IDs, a busy/acquire race, descriptor drift cleanup, signed POV errors,
  fake missing exports, failed-update cache retry, slider slots, unused fields,
  and all 32 buttons.
- `cargo test --manifest-path tauri/virtual_joystick/Cargo.toml` — passed:
  3 library tests (including the injectable Windows native API seam), 2 CLI
  tests, and 31 protocol tests. Protocol coverage includes non-1 selection,
  neutral-before-release and exactly-once cleanup on shutdown/drop/I/O/update
  failures, cleanup using cached verified ranges if later range queries fail,
  visible shutdown cleanup errors, framing boundaries, CRLF, invalid UTF-8, and
  write/flush failures.
- The test commands did not run the upstream hardware integration target or
  acquire a device. Real driver behavior and native relinquish outcome remain
  unverified.

## Deferred integration

Persisted selection, configuration UI, database/schema work, installer
ownership records, and new-client compatibility checks remain outside this
sidecar/vendor slice. Existing protocol clients continue to select device 1 by
default.
